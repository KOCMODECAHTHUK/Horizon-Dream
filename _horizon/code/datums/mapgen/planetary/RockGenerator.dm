/**
 * Rocky Planet Generator
 * Creates a simple rocky/asteroid-like planet with mineral-rich caves
 */
/datum/map_generator/planet_generator/rocky
	primary_area_type = /area/planet/rocky
	cave_area_type = /area/planet/cave/rocky
	mountain_height = 0.80
	biome_key = "rock"

/datum/map_generator/planet_generator/rocky/New()
	. = ..()

	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/planet_asteroid,
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/planet_asteroid,
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/planet_asteroid,
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/planet_asteroid,
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/planet_asteroid,
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/planet_asteroid,
		),
	)

	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
		),
	)
