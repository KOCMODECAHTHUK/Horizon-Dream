/obj/effect/temp_visual/shockwave
	icon = '_horizon/icons/effect/shockwave.dmi'
	icon_state = "shockwave"
	plane = DISPLACEMENT_PLANE
	pixel_x = -496
	pixel_y = -496
	randomdir = FALSE

/obj/effect/temp_visual/shockwave/Initialize(mapload, radius, speed, y_offset, x_offset)
	. = ..()
	if(!speed)
		speed = 1
	if(y_offset)
		pixel_y += y_offset
	if(x_offset)
		pixel_x += x_offset
	var/turf/T = get_turf(src)
	if(T)
		var/offset = GET_TURF_PLANE_OFFSET(T)
		ADD_TRAIT(GLOB, TRAIT_DISTORTION_IN_USE(offset), ref(src))
	// The base Initialize sets a generic duration timer; override it with the radius-driven one.
	deltimer(timerid)
	timerid = QDEL_IN_STOPPABLE(src, 0.5 * radius)
	transform = matrix().Scale(32 / 1024, 32 / 1024)
	animate(src, time = 0.5 * radius * speed, transform = matrix().Scale((32 / 1024) * radius * 1.5, (32 / 1024) * radius * 1.5))

/obj/effect/temp_visual/shockwave/Destroy()
	var/turf/T = get_turf(src)
	if(T)
		var/offset = GET_TURF_PLANE_OFFSET(T)
		REMOVE_TRAIT(GLOB, TRAIT_DISTORTION_IN_USE(offset), ref(src))
	return ..()

/*
// CM
/obj/effect/shockwave
	icon = '_horizon/icons/effects/shockwave.dmi'
	icon_state = "shockwave"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	plane = DISPLACEMENT_PLATE_RENDER_LAYER
	pixel_x = -496
	pixel_y = -496
	vis_flags = 0

/obj/effect/shockwave/Initialize(mapload, radius, speed, easing_type = LINEAR_EASING, y_offset, x_offset)
	. = ..()
	if(!speed)
		speed = 1
	if(y_offset)
		pixel_y += y_offset
	if(x_offset)
		pixel_x += x_offset
	AddElement(/datum/element/temporary, 0.5 * radius * speed)
	transform = matrix().Scale(32 / 1024, 32 / 1024)
	animate(src, time = 0.5 * radius * speed, transform=matrix().Scale((32 / 1024) * radius * 1.5, (32 / 1024) * radius * 1.5), easing = easing_type)
*/
