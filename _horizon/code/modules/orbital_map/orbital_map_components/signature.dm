// orbital_signature.dm
/datum/orbital_signature
	var/base_visibility = 10   // базовая дальность обнаружения
	var/stealth_rating = 0	 // 0-100
	var/transponder_code = null // "Nanotrasen | NTV-Charon"
	var/thermal_output = 1.0   // множитель заметности от двигателей

/datum/orbital_signature/proc/get_effective_visibility(datum/orbital_object/shuttle/observer)
	. = base_visibility * (1 - stealth_rating / 100)

	// Если включены двигатели — шаттл заметнее
	if(istype(observer) && observer.thrust_power > 0)
		. *= 1 + (observer.thrust_power / 100)

// orbital_sensor.dm
/datum/orbital_sensor
	var/name = "Standard Radar"
	var/sensor_range = 200
	var/scan_resolution = 1.0 // 1.0 = полные данные, 0.5 = позиция+скорость
	var/active = TRUE

/datum/orbital_sensor/proc/can_detect(datum/orbital_object/shuttle/ship, datum/orbital_object/target)
	if(!active || !ship || !target || target == ship) return FALSE
	// Планеты, звезды, станции — всегда на карте
	if(istype(target, /datum/orbital_object/planet) || istype(target, /datum/orbital_object/star) || istype(target, /datum/orbital_object/station))
		return TRUE

	var/dist = ship.position.DistanceTo(target.position)
	var/vis = target.signature ? target.signature.get_effective_visibility(ship) : 10
	var/eff_range = sensor_range * scan_resolution

	if(dist > eff_range + vis) return FALSE
	var/chance = 1 - clamp((dist - vis) / max(eff_range, 1), 0, 1)
	return prob(chance * 100)
