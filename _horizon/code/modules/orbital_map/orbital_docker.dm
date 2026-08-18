/**
 * # Orbital Shuttle Docker
 *
 * Camera-based docking console for visual landing spot selection.
 * Created dynamically when a shuttle attempts to land on a planet.
 */
/obj/machinery/computer/camera_advanced/shuttle_docker/orbital
	name = "orbital navigation computer"
	desc = "Used to designate a precise landing location on a planet."
	lock_override = NONE
	designate_time = 0 // Убрано время ожидания, которое вызывало прерывание
	zlink_range = 0
	shuttlePortName = "landing zone"
	should_supress_view_changes = FALSE
	add_usb_port = FALSE
	see_hidden = TRUE
	locked_traits = list(ZTRAIT_CENTCOM) // Разрешаем посадку на Z-уровнях планет (которые могут иметь RESERVED)

	var/obj/machinery/computer/shuttle_flight/flight_console
	var/datum/orbital_object/target_orbital_object
	var/docking_initiated = FALSE

// Мы полностью переопределяем Initialize базового shuttle_docker,
// чтобы избежать вызова SSshuttle.get_containing_shuttle(src), который вызывает рантайм null.z,
// так как камера создается в nullspace.
/obj/machinery/computer/camera_advanced/shuttle_docker/orbital/Initialize(mapload)
	// Вызываем Initialize родителя camera_advanced, минуя shuttle_docker
	. = ..()
	actions += new /datum/action/innate/shuttledocker_rotate(src)
	actions += new /datum/action/innate/shuttledocker_place(src)
	AddElement(/datum/element/nav_computer_icon, 'icons/effects/nav_computer_indicators.dmi', "computer", FALSE)
	whitelist_turfs = typecacheof(list(/turf/open, /turf/closed))

/obj/machinery/computer/camera_advanced/shuttle_docker/orbital/Destroy()
	flight_console = null
	target_orbital_object = null
	return ..()

/obj/machinery/computer/camera_advanced/shuttle_docker/orbital/can_use(mob/living/user)
	if(!user?.client)
		return FALSE
	if(user.stat)
		return FALSE
	if(!flight_console || QDELETED(flight_console) || !flight_console.controlled_shuttle)
		return FALSE
	if(!target_orbital_object || QDELETED(target_orbital_object))
		return FALSE
	return TRUE

// Переопределяем CreateEye, чтобы использовать наш кастомный глаз камеры, который не вылетает за края
/obj/machinery/computer/camera_advanced/shuttle_docker/orbital/CreateEye()
	shuttle_port = SSshuttle.getShuttle(shuttleId)
	if(QDELETED(shuttle_port))
		shuttle_port = null
		return

	eyeobj = new /mob/eye/camera/remote/shuttle_docker/orbital(null, src)
	var/mob/eye/camera/remote/shuttle_docker/the_eye = eyeobj
	the_eye.setDir(shuttle_port.dir)
	var/turf/origin = locate(shuttle_port.x + x_offset, shuttle_port.y + y_offset, shuttle_port.z)
	for(var/area/shuttle_area as anything in shuttle_port.shuttle_areas)
		for (var/list/zlevel_turfs as anything in shuttle_area.get_zlevel_turf_lists())
			for(var/turf/shuttle_turf as anything in zlevel_turfs)
				if(shuttle_turf.z != origin.z)
					continue
				var/image/I = image('icons/effects/alphacolors.dmi', origin, "red")
				var/x_off = shuttle_turf.x - origin.x
				var/y_off = shuttle_turf.y - origin.y
				I.loc = locate(origin.x + x_off, origin.y + y_off, origin.z)
				I.layer = ABOVE_NORMAL_TURF_LAYER
				SET_PLANE(I, ABOVE_GAME_PLANE, shuttle_turf)
				I.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
				the_eye.placement_images[I] = list(x_off, y_off)
	gatherNavComputerIcons()

	return TRUE

/obj/machinery/computer/camera_advanced/shuttle_docker/orbital/checkLandingTurf(turf/T, list/overlappers)
	if(!T || T.x <= 10 || T.y <= 10 || T.x >= world.maxx - 10 || T.y >= world.maxy - 10)
		return SHUTTLE_DOCKER_BLOCKED

	// Жестко блокируем посадку на неразрушимый край карты
	if(istype(T, /turf/closed/indestructible/edge))
		return SHUTTLE_DOCKER_BLOCKED

	if(shuttle_port?.shuttle_areas[T.loc])
		return SHUTTLE_DOCKER_LANDING_CLEAR

	var/on_target_z = FALSE

	if(istype(target_orbital_object, /datum/orbital_object/planet))
		var/datum/orbital_object/planet/planet = target_orbital_object
		var/planet_z = planet.planet_level?.z_value
		if(!planet_z && planet.reserve_docks?.len)
			planet_z = planet.reserve_docks[1].z
		if(T.z == planet_z)
			on_target_z = TRUE

	// Проверяем пересечения с другими доками
	for(var/i in 1 to overlappers.len)
		var/obj/docking_port/port = overlappers[i]
		if(port == my_port)
			continue
		var/list/overlap = overlappers[port]
		var/list/xs = overlap[1]
		var/list/ys = overlap[2]
		if(xs["[T.x]"] && ys["[T.y]"])
			var/port_hidden = !see_hidden && port.hidden
			if(port_hidden)
				return SHUTTLE_DOCKER_BLOCKED_BY_HIDDEN_PORT
			return SHUTTLE_DOCKER_BLOCKED

	if(on_target_z)
		return SHUTTLE_DOCKER_LANDING_CLEAR

	if(length(whitelist_turfs) && !is_type_in_typecache(T.type, whitelist_turfs))
		return SHUTTLE_DOCKER_BLOCKED

	return SHUTTLE_DOCKER_LANDING_CLEAR

/obj/machinery/computer/camera_advanced/shuttle_docker/orbital/placeLandingSpot()
	. = ..()
	if(!.)
		return

	var/mob/user = current_user
	if(!user || docking_initiated || !my_port)
		return

	var/datum/orbital_object/shuttle/orbital_shuttle = flight_console?.controlled_shuttle
	if(!orbital_shuttle?.shuttle_port)
		to_chat(user, span_warning("ERROR: Shuttle connection lost!"))
		return

	if(orbital_shuttle.shuttle_port.mode != SHUTTLE_IDLE)
		to_chat(user, span_warning("Shuttle is in transit! Cannot land right now."))
		return

	to_chat(user, span_notice("Initiating landing at designated coordinates..."))

	var/docking_result = orbital_shuttle.shuttle_port.initiate_docking(my_port)

	if(docking_result != DOCKING_SUCCESS)
		to_chat(user, span_warning("ERROR: Landing failed! Error code: [docking_result]"))
		QDEL_NULL(my_port)
		return

	docking_initiated = TRUE

	orbital_shuttle.docked_at = target_orbital_object
	orbital_shuttle.docked_offset = orbital_shuttle.position.Subtract(target_orbital_object.position)
	orbital_shuttle.kill_thrust()
	orbital_shuttle.velocity.Set(0, 0, 0)
	orbital_shuttle.autopilot_enabled = FALSE

	to_chat(user, span_boldnotice("Landing successful! Welcome to [target_orbital_object.name]."))
	remove_eye_control(user)

/obj/machinery/computer/camera_advanced/shuttle_docker/orbital/remove_eye_control(mob/living/user)
	. = ..()
	if(!docking_initiated && user)
		to_chat(user, span_notice("Landing procedure cancelled."))

	if(flight_console && !QDELETED(flight_console) && user?.client)
		flight_console.ui_interact(user)

	QDEL_IN(src, 1 SECONDS)

/obj/machinery/computer/camera_advanced/shuttle_docker/orbital/proc/launch(mob/user, obj/machinery/computer/shuttle_flight/console, datum/orbital_object/target)
	if(!user || !console?.controlled_shuttle?.shuttle_port)
		return FALSE

	flight_console = console
	target_orbital_object = target
	shuttle_port = console.controlled_shuttle.shuttle_port
	shuttleId = shuttle_port.shuttle_id
	shuttlePortId = "[shuttleId]_orbital_landing"

	z_lock = list()

	var/datum/orbital_object/planet/planet_target = null

	if(istype(target, /datum/orbital_object/planet))
		planet_target = target
		if(!planet_target.landable)
			to_chat(user, span_warning("[planet_target.name] is not suitable for landing. [planet_target.description]"))
			return FALSE

		if(!planet_target.planet_level)
			to_chat(user, span_notice("Generating planet surface..."))
			if(!planet_target.generate_level())
				log_world("ORBITAL DOCKER: generate_level() failed for [planet_target.name]!")
				to_chat(user, span_warning("ERROR: Failed to generate planet surface! Check server logs."))
				return FALSE
			to_chat(user, span_boldnotice("Planet surface generated!"))

		var/planet_z = planet_target.planet_level?.z_value
		if(!planet_z && planet_target.reserve_docks?.len)
			planet_z = planet_target.reserve_docks[1].z

		if(planet_z)
			z_lock = list(planet_z)

		for(var/obj/docking_port/stationary/dock in planet_target.reserve_docks)
			if(dock.shuttle_id)
				add_jumpable_port(dock.shuttle_id)
	else
		to_chat(user, span_warning("Navigation camera is only available for planets."))
		return FALSE

	if(!length(z_lock))
		to_chat(user, span_warning("ERROR: Unable to determine landing zone Z-level."))
		return FALSE

	SStgui.close_user_uis(user, console)

	if(!CreateEye())
		to_chat(user, span_warning("ERROR: Failed to initialize navigation camera!"))
		return FALSE

	var/turf/start_loc = null

	if(planet_target?.reserve_docks?.len)
		start_loc = get_turf(planet_target.reserve_docks[1])

	if(!start_loc && length(z_lock))
		start_loc = locate(round(world.maxx * 0.5), round(world.maxy * 0.5), z_lock[1])

	if(!start_loc)
		to_chat(user, span_warning("ERROR: Could not find valid camera starting location!"))
		return FALSE

	give_eye_control(user)
	eyeobj.setLoc(start_loc, TRUE)

	to_chat(user, span_notice("Navigation camera active over [target.name]."))
	to_chat(user, span_info("Use the Place action to designate a landing zone."))
	to_chat(user, span_info("Green = clear, Red = blocked. Use Rotate to align your shuttle."))

	return TRUE

// Кастомный глаз камеры, который блокирует выход за края карты
/mob/eye/camera/remote/shuttle_docker/orbital
	use_visibility = FALSE

/mob/eye/camera/remote/shuttle_docker/orbital/setLoc(turf/destination, force_update = FALSE)
	if(istype(destination, /turf/closed/indestructible/edge))
		return FALSE
	return ..()
