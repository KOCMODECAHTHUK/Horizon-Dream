/datum/orbital_object/planet/rocky
	supercruise_color = "#8B7355"  // Brown
	description = "A barren rocky world with a thin, cold atmosphere and scattered rocks."
	map_generator_type = /datum/map_generator/planet_generator/rocky
	planet_size = 100
	baseturf_type = /turf/open/misc/asteroid

/datum/orbital_object/planet/ice
	supercruise_color = "#B0E0E6"  // Light blue
	description = "A frozen ice world with an extremely cold atmosphere and ice formations."
	map_generator_type = /datum/map_generator/planet_generator/ice
	planet_size = 100
	baseturf_type = /turf/open/space/basic

/datum/orbital_object/planet/gas
	supercruise_color = "#FFA07A"  // Light orange
	description = "A massive gas giant. Landing is impossible."
	landable = FALSE
	map_generator_type = null // No landing

/datum/orbital_object/planet/lava
	supercruise_color = "#FF4500"  // Red-orange
	description = "A volcanic hellscape with extreme heat, toxic fumes, and flowing lava."
	map_generator_type = /datum/map_generator/planet_generator/lava
	planet_size = 100
	baseturf_type = /turf/open/lava/smooth

/datum/orbital_object/planet/oceanic
	supercruise_color = "#4682B4"  // Steel blue
	description = "A world covered in vast oceans with sandy beaches and a breathable atmosphere."
	map_generator_type = /datum/map_generator/planet_generator/beach
	planet_size = 100
	baseturf_type = /turf/open/space/basic

/datum/orbital_object/planet/desert
	supercruise_color = "#DEB887"  // Burlywood
	description = "An arid desert planet with scorching heat, dry air, and endless sand dunes."
	map_generator_type = /datum/map_generator/planet_generator/desert
	planet_size = 100
	baseturf_type = /turf/open/misc/asteroid

/datum/orbital_object/planet/forest
	supercruise_color = "#228B22"  // Forest green
	description = "A lush green world with dense jungle vegetation, exotic flora, and humid air."
	map_generator_type = /datum/map_generator/planet_generator/jungle
	planet_size = 100
	baseturf_type = /turf/open/misc/grass

/datum/orbital_object/planet/toxic
	supercruise_color = "#9B59B6"  // Purple
	description = "A toxic wasteland filled with hazardous gases, radiation, and industrial ruins."
	map_generator_type = /datum/map_generator/planet_generator/wasteland
	planet_size = 100
	baseturf_type = /turf/open/misc/asteroid
