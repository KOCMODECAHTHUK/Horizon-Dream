/**
 * Desert Planet Generator
 * Creates a hot, dry desert world with carved canyons
 */
/datum/map_generator/planet_generator/desert
	primary_area_type = /area/planet/desert
	cave_area_type = /area/planet/cave/desert
	mountain_height = 0.82

	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/sand,
			BIOME_LOW_HUMIDITY = /datum/biome/sand,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/sand/grass/dead,
			BIOME_HIGH_HUMIDITY = /datum/biome/sand/icecap,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/sand/icecap,
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/sand,
			BIOME_LOW_HUMIDITY = /datum/biome/sand/riverbed,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/sand/wasteland,
			BIOME_HIGH_HUMIDITY = /datum/biome/sand/wasteland,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/sand/icecap,
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/sand,
			BIOME_LOW_HUMIDITY = /datum/biome/sand,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/sand/riverbed,
			BIOME_HIGH_HUMIDITY = /datum/biome/sand,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/sand,
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/sand,
			BIOME_LOW_HUMIDITY = /datum/biome/sand/grass/dead,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/sand/riverbed,
			BIOME_HIGH_HUMIDITY = /datum/biome/sand/grass/dead,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/sand,
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/sand,
			BIOME_LOW_HUMIDITY = /datum/biome/sand,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/sand,
			BIOME_HIGH_HUMIDITY = /datum/biome/sand/riverbed,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/sand,
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/sand,
			BIOME_LOW_HUMIDITY = /datum/biome/sand,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/sand/sulfur_plains,
			BIOME_HIGH_HUMIDITY = /datum/biome/sand/sulfur_plains,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/sand,
		),
	)

	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/sand/volcanic/acidic,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/sand/deep,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/sand/deep,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/sand,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/sand,
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/sand/volcanic/lava,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/sand,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/sand/deep,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/sand,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/sand,
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/sand/volcanic,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/sand,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/sand,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/sand/deep,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/sand,
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/sand/volcanic/lava,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/sand/volcanic,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/sand/volcanic,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/sand/deep,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/sand,
		),
	)
