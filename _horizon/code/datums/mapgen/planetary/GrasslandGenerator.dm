/**
 * Grassland Planet Generator
 * Creates a temperate grassland world with limestone caves
 */
/datum/map_generator/planet_generator/grassland
	primary_area_type = /area/planet/grassland
	cave_area_type = /area/planet/cave/grassland
	mountain_height = 0.80
	biome_key = "grassland"

/datum/map_generator/planet_generator/grassland/New()
	. = ..()

	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/rock/icecap,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/rock/icecap,
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/rock/icecap,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/rock/icecap,
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/rock/wetlands,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/rock/wetlands,
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/rock/wetlands,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/rock,
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/rock/wetlands,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/rock/wetlands,
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/rock,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/rock,
		),
	)

	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/rock,
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/rock,
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/rock,
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/rock,
		),
	)
