/**
 * Jungle Planet Generator
 * Creates a lush jungle world with root-filled caverns
 */
/datum/map_generator/planet_generator/jungle
	primary_area_type = /area/planet/jungle
	cave_area_type = /area/planet/cave/jungle
	mountain_height = 0.85

	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/jungle,
			BIOME_LOW_HUMIDITY = /datum/biome/jungle,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/jungle/dense,
			BIOME_HIGH_HUMIDITY = /datum/biome/mudlands,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/mudlands,
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/jungle,
			BIOME_LOW_HUMIDITY = /datum/biome/jungle/dense,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/mudlands,
			BIOME_HIGH_HUMIDITY = /datum/biome/mudlands,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/mudlands,
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/jungle,
			BIOME_LOW_HUMIDITY = /datum/biome/jungle,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/mudlands,
			BIOME_HIGH_HUMIDITY = /datum/biome/mudlands,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/jungle,
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/jungle/dense,
			BIOME_LOW_HUMIDITY = /datum/biome/mudlands,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/jungle/water,
			BIOME_HIGH_HUMIDITY = /datum/biome/jungle/water,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/jungle/water,
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/jungle/dense,
			BIOME_LOW_HUMIDITY = /datum/biome/jungle,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/mudlands,
			BIOME_HIGH_HUMIDITY = /datum/biome/jungle/water,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/jungle,
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/jungle,
			BIOME_LOW_HUMIDITY = /datum/biome/jungle,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/jungle/dense,
			BIOME_HIGH_HUMIDITY = /datum/biome/jungle,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/jungle/water,
		),
	)

	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/jungle/dirt,
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/jungle/dirt,
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/jungle,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/jungle,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/jungle,
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/jungle,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/lush,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/lush/bright,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/lush/bright,
		),
	)
