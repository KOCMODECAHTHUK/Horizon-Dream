/**
 * LAVALAND BIOMES
 * Used by lava planet generator
 */

// ========================================
// SURFACE BIOMES
// ========================================

/// Base lavaland biome - rocky basalt surface
/datum/biome/lavaland
	open_turf_type = /turf/open/misc/asteroid/basalt/lava_land_surface
	flora_density = 1
	flora_types = list(
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/ash/fireblossom = 1,
		/obj/structure/flora/ash/seraka = 5,
	)
	feature_density = 0.3
	feature_types = list(
		/obj/structure/flora/rock/pile = 20,
		/obj/structure/geyser/random = 4,
		/obj/structure/flora/rock/pile = 14,
	)
	fauna_density = 1
	fauna_types = list(
		/mob/living/basic/mining/goliath = 50,
		/mob/living/basic/mining/watcher = 40,
		/mob/living/basic/mining/basilisk = 30,
		/mob/living/basic/mining/hivelord = 10,
		/mob/living/basic/mining/lobstrosity = 1,
	)

/// Lavaland forest - dead trees and dense grass
/datum/biome/lavaland/forest
	open_turf_type = /turf/open/misc/asteroid/basalt
	flora_types = list(
		/obj/structure/flora/tree/dead = 10,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 20,
		/obj/structure/flora/ash/fireblossom = 4,
	)
	flora_density = 80

/// Lavaland rocky forest - forest with more rocks
/datum/biome/lavaland/forest/rocky
	flora_types = list(
		/obj/structure/flora/rock/pile = 5,
		/obj/structure/flora/rock/pile = 4,
		/obj/structure/flora/tree/dead = 10,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 20,
		/obj/structure/flora/ash/fireblossom = 4,
	)
	flora_density = 75

/// Lavaland plains - grassy areas
/datum/biome/lavaland/plains
	open_turf_type = /turf/open/misc/dirt
	flora_types = list(
		/obj/structure/flora/bush = 50,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/bush = 1,
	)
	flora_density = 15

/// Lavaland dense plains - heavily vegetated
/datum/biome/lavaland/plains/dense
	flora_density = 85
	open_turf_type = /turf/open/misc/dirt
	feature_density = 5
	feature_types = list(
		/obj/structure/flora/tree/dead = 50,
		/obj/structure/flora/tree/dead = 45,
	)

/// Lavaland mixed dense plains - grass and moss mix
/datum/biome/lavaland/plains/dense/mixed
	flora_density = 50
	open_turf_type = /turf/open/misc/dirt

/// Lavaland outback - sparse vegetation
/datum/biome/lavaland/outback
	open_turf_type = /turf/open/misc/dirt
	flora_types = list(
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/tree/dead = 3,
		/obj/structure/flora/rock/pile = 2,
		/obj/structure/flora/ash/cacti = 1,
	)
	flora_density = 2

/// Lavaland lush - dense vegetation with crimson grass
/datum/biome/lavaland/lush
	open_turf_type = /turf/open/misc/dirt
	flora_types = list(
		/obj/structure/flora/bush,
		/obj/structure/flora/tree/dead = 1,
		/obj/structure/flora/bush,
		/obj/structure/flora/bush,
		/obj/structure/flora/bush,
		/obj/structure/flora/bush,
		/obj/structure/flora/bush,
		/obj/structure/flora/bush,
		/obj/structure/flora/bush,
		/obj/structure/flora/bush = 3
	)
	flora_density = 30

/// Lavaland lava - active lava flows
/datum/biome/lavaland/lava
	open_turf_type = /turf/open/lava/smooth/lava_land_surface
	flora_types = list(
		/obj/structure/flora/rock/pile = 1,
		/obj/structure/flora/rock/pile = 1
	)
	flora_density = 2
	feature_density = 0

/// Lavaland near-lava - obsidian areas near lava
/datum/biome/lavaland/nearlava
	open_turf_type = /turf/open/misc/asteroid/basalt
	flora_types = list(
		/obj/structure/flora/rock/pile = 1,
		/obj/structure/flora/rock/pile = 1
	)
	flora_density = 2

// ========================================
// CAVE BIOMES
// ========================================

/// Base lavaland cave biome
/datum/biome/cave/lavaland
	open_turf_type = /turf/open/misc/asteroid/basalt/lava_land_surface
	closed_turf_type = /turf/closed/mineral/random/volcanic
	fauna_density = 4
	fauna_types = list(
		/mob/living/basic/mining/goliath = 50,
		/mob/living/basic/mining/watcher = 40,
		/mob/living/basic/mining/basilisk = 30,
		/mob/living/basic/mining/hivelord = 10,
	)
	flora_density = 2
	flora_types = list(
		/obj/structure/flora/rock/pile = 4,
		/obj/structure/flora/rock/pile = 4,
		/obj/structure/flora/bush = 10,
		/obj/structure/flora/bush = 5,
		/obj/structure/flora/ash/leaf_shroom = 1,
		/obj/structure/flora/ash/cap_shroom = 2,
		/obj/structure/flora/ash/stem_shroom = 2,
		/obj/structure/flora/ash/cacti = 1,
		/obj/structure/flora/ash/tall_shroom = 2,
	)
	feature_density = 1
	feature_types = list(
	)

/// Lavaland cave - obsidian floor
/datum/biome/cave/lavaland/obsidian
	open_turf_type = /turf/open/misc/asteroid/basalt

/// Lavaland cave - rocky purple floor
/datum/biome/cave/lavaland/rocky
	open_turf_type = /turf/open/misc/asteroid/basalt
	flora_types = list(
		/obj/structure/flora/rock/pile = 6,
		/obj/structure/flora/rock/pile = 6,
	)
	flora_density = 5

/// Lavaland cave - mossy underground
/datum/biome/cave/lavaland/mossy
	open_turf_type = /turf/open/floor/grass
	flora_density = 80
	flora_types = list(
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 10,
		/obj/structure/flora/bush = 5,
		/obj/structure/flora/ash/leaf_shroom = 3,
		/obj/structure/flora/ash/cap_shroom = 3,
		/obj/structure/flora/ash/stem_shroom = 3,
		/obj/structure/flora/ash/cacti = 1,
		/obj/structure/flora/ash/tall_shroom = 2,
	)

/// Lavaland cave - underground lava
/datum/biome/cave/lavaland/lava
	open_turf_type = /turf/open/lava/smooth/lava_land_surface
	feature_density = 1
	feature_types = list(/obj/structure/flora/rock/pile = 1)
