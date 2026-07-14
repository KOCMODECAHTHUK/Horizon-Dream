/**
 * Wasteland Planet Generator
 * Creates a toxic wasteland with industrial ruins
 */
/datum/map_generator/planet_generator/wasteland
	primary_area_type = /area/planet/wasteland
	cave_area_type = /area/planet/cave/wasteland
	mountain_height = 0.78

/datum/map_generator/planet_generator/wasteland/New()
	. = ..()

	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/waste/crater,
			BIOME_LOW_HUMIDITY = /datum/biome/waste/crater,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/waste/clearing,
			BIOME_HIGH_HUMIDITY = /datum/biome/waste/clearing/mushroom,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/waste/metal/rust,
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/waste,
			BIOME_LOW_HUMIDITY = /datum/biome/waste/crater,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/waste/clearing,
			BIOME_HIGH_HUMIDITY = /datum/biome/waste/clearing,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/waste/metal/rust,
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/waste,
			BIOME_LOW_HUMIDITY = /datum/biome/waste,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/waste/metal/rust,
			BIOME_HIGH_HUMIDITY = /datum/biome/waste/clearing/mushroom,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/waste/tar_bed,
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/waste,
			BIOME_LOW_HUMIDITY = /datum/biome/waste/clearing,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/waste,
			BIOME_HIGH_HUMIDITY = /datum/biome/waste/tar_bed,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/waste/tar_bed/total,
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/waste,
			BIOME_LOW_HUMIDITY = /datum/biome/waste,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/waste/metal,
			BIOME_HIGH_HUMIDITY = /datum/biome/waste/tar_bed,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/waste/tar_bed/total,
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/waste/crater,
			BIOME_LOW_HUMIDITY = /datum/biome/waste/metal,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/waste/metal/rust,
			BIOME_HIGH_HUMIDITY = /datum/biome/waste/tar_bed,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/waste/tar_bed/total,
		),
	)

	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/waste,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/waste/rad,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/waste/conc,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/waste/tar_bed,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/waste/tar_bed/full,
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/waste,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/waste/rad,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/waste/conc,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/waste/conc,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/waste/conc,
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/waste,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/waste,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/waste/metal,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/waste/metal,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/waste/tar_bed,
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/waste/metal/hivebot,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/waste/metal/hivebot,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/waste/metal/hivebot,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/waste/metal,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/waste/metal,
		),
	)
