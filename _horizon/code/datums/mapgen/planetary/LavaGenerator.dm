/**
 * Lava Planet Generator
 * Creates a volcanic hellscape with extensive magma tunnel systems
 * Lava planets are VERY cave-heavy due to volcanic activity creating underground networks
 */
/datum/map_generator/planet_generator/lava
	primary_area_type = /area/planet/lava
	cave_area_type = /area/planet/cave/lava
	mountain_height = 0.45
	perlin_zoom = 65
	biome_key = "lava"

/datum/map_generator/planet_generator/lava/New()
	. = ..()

	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/lavaland/forest,
			BIOME_LOW_HUMIDITY = /datum/biome/lavaland/plains/dense/mixed,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/lavaland/forest/rocky,
			BIOME_HIGH_HUMIDITY = /datum/biome/lavaland/outback,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/lavaland/plains/dense,
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/lavaland/plains,
			BIOME_LOW_HUMIDITY = /datum/biome/lavaland/outback,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/lavaland/plains/dense,
			BIOME_HIGH_HUMIDITY = /datum/biome/lavaland/plains/dense/mixed,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/lavaland,
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/lavaland,
			BIOME_LOW_HUMIDITY = /datum/biome/lavaland/lush,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/lavaland/forest,
			BIOME_HIGH_HUMIDITY = /datum/biome/lavaland,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/lavaland/lava,
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/lavaland/outback,
			BIOME_LOW_HUMIDITY = /datum/biome/lavaland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/lavaland/forest,
			BIOME_HIGH_HUMIDITY = /datum/biome/lavaland/lava,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/lavaland/nearlava,
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/lavaland/plains,
			BIOME_LOW_HUMIDITY = /datum/biome/lavaland/nearlava,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/lavaland,
			BIOME_HIGH_HUMIDITY = /datum/biome/lavaland/nearlava,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/lavaland/lava,
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/lavaland/forest/rocky,
			BIOME_LOW_HUMIDITY = /datum/biome/lavaland/outback,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/lavaland,
			BIOME_HIGH_HUMIDITY = /datum/biome/lavaland/nearlava,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/lavaland/lava,
		),
	)

	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/lavaland/rocky,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/lavaland/rocky,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/lavaland,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/lavaland,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/lavaland/mossy,
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/lavaland/rocky,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/lavaland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/lavaland/lava,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/lavaland,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/lavaland/lava,
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/lavaland/rocky,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/lavaland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/lavaland/mossy,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/lavaland/obsidian,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/lavaland/lava,
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/lavaland/rocky,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/lavaland/mossy,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/lavaland/obsidian,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/lavaland/lava,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/lavaland/lava,
		),
	)
