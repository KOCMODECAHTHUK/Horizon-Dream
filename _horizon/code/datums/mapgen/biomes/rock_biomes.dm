/**
 * ROCK BIOMES
 * Used by rock planet generator
 */

// ========================================
// SURFACE BIOMES
// ========================================

/// Base rock biome - barren rocky terrain
/datum/biome/rock
	open_turf_type = /turf/open/misc/asteroid/basalt
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/rock = 20,
		/obj/structure/flora/rock/pile = 20,
		/obj/structure/flora/grass/both = 10,
		/obj/structure/flora/bush = 40,
	)
	fauna_density = 2
	fauna_types = list(
		/mob/living/basic/mining/watcher = 30,
		/mob/living/basic/mining/watcher = 30,
		/mob/living/basic/spider/giant = 20,
		/mob/living/basic/mining/watcher = 30,
		/mob/living/basic/mining/goliath = 50,
	)
	feature_density = 0.3
	feature_types = list(
		/obj/structure/geyser/random = 2,
	)

/// Rock wetlands - damp rocky areas
/datum/biome/rock/wetlands
	open_turf_type = /turf/open/misc/asteroid/basalt
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/rock = 15,
		/obj/structure/flora/rock/pile = 15,
		/obj/structure/flora/grass/both = 10,
		/obj/structure/flora/bush = 40,
	)

/// Rock ice cap - frozen rocky areas
/datum/biome/rock/icecap
	open_turf_type = /turf/open/misc/asteroid/snow
	flora_density = 1
	fauna_density = 2
	flora_types = list(
		/obj/structure/flora/rock/icy = 5,
		/obj/structure/flora/rock/pile/icy = 5,
		/obj/structure/flora/rock = 2,
	)

// ========================================
// CAVE BIOMES
// ========================================

/// Rock cave - cracked rocky underground
/datum/biome/cave/rock
	closed_turf_type = /turf/closed/mineral/random/jungle
	open_turf_type = /turf/open/misc/asteroid/basalt
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/rock = 15,
		/obj/structure/flora/rock/pile = 15,
		/obj/structure/flora/bush = 40,
	)
	feature_density = 0.5
	feature_types = list(
	)
	fauna_density = 2
	fauna_types = list(
		/mob/living/basic/mining/watcher = 30,
		/mob/living/basic/mining/watcher = 30,
		/mob/living/basic/spider/giant = 20,
		/mob/living/basic/mining/watcher = 30,
	)

/// Wet rock cave - damp underground chambers
/datum/biome/cave/rock/wet
	open_turf_type = /turf/open/misc/asteroid/basalt
	flora_density = 4
	flora_types = list(
		/obj/structure/flora/rock = 10,
		/obj/structure/flora/rock/pile = 10,
		/obj/structure/flora/bush = 50,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/bush = 10,
	)
