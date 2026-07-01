/**
 * SAND/DESERT BIOMES
 * Based on PentestSS13's sand/desert biome definitions
 * Used by desert planet generator
 */

// ========================================
// SURFACE BIOMES
// ========================================

/// Base sand biome - white sand dunes
/datum/biome/sand
	open_turf_type = /turf/open/misc/beach/sand
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/rock/pile = 10,
		/obj/structure/flora/rock = 10,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/tree/dead = 5,
		/obj/structure/flora/ash/cacti = 3,
	)
	feature_density = 0.5
	feature_types = list(
	)
	fauna_density = 1
	fauna_types = list(
		/mob/living/basic/spider/giant = 100,
		/mob/living/basic/snake = 20,
		/mob/living/simple_animal/hostile/megafauna/dragon = 10,
	)

/// Wasteland sand - degraded sandy areas
/datum/biome/sand/wasteland
	open_turf_type = /turf/open/misc/beach/sand
	flora_density = 20
	flora_types = list(
		/obj/structure/flora/bush = 50,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/tree/dead = 10,
		/obj/effect/decal/remains/human = 4,
		/obj/effect/spawner/random/maintenance = 40,
	)

/// Riverbed - dried river channels
/datum/biome/sand/riverbed
	open_turf_type = /turf/open/misc/beach/sand
	flora_density = 0
	fauna_types = list(
	)

/// Grassy dead areas - dead vegetation on sand
/datum/biome/sand/grass/dead
	open_turf_type = /turf/open/misc/beach/sand
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/bush = 50,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/tree/dead = 10,
		/obj/structure/flora/rock = 8,
		/obj/structure/flora/rock/pile = 8,
	)

/// Ice cap on sand - cold desert
/datum/biome/sand/icecap
	open_turf_type = /turf/open/misc/asteroid/snow
	flora_density = 4
	fauna_density = 1
	flora_types = list(
		/obj/structure/flora/bush,
		/obj/structure/flora/bush,
		/obj/structure/flora/bush,
		/obj/structure/flora/rock = 3,
		/obj/structure/flora/rock/pile = 3,
	)

/// Sulfur plains - hot volcanic sand
/datum/biome/sand/sulfur_plains
	open_turf_type = /turf/open/misc/beach/sand
	flora_density = 1
	flora_types = list(
		/obj/structure/flora/bush,
		/obj/structure/flora/rock = 2,
		/obj/structure/flora/rock/pile = 2,
	)
	feature_density = 1
	feature_types = list(
		/obj/structure/geyser/random = 1,
	)

// ========================================
// CAVE BIOMES
// ========================================

/// Desert cave - sandy underground
/datum/biome/cave/sand
	open_turf_type = /turf/open/misc/beach/sand
	closed_turf_type = /turf/closed/mineral/random/jungle
	flora_density = 4
	flora_types = list(
		/obj/structure/flora/rock/pile = 10,
		/obj/structure/flora/rock = 15,
		/obj/structure/flora/bush = 40,
	)
	fauna_density = 1
	fauna_types = list(
		/mob/living/basic/carp = 30,
		/mob/living/simple_animal/hostile/megafauna/dragon = 10,
	)

/// Deep sand cave
/datum/biome/cave/sand/deep
	open_turf_type = /turf/open/misc/beach/sand
	closed_turf_type = /turf/closed/mineral/random/jungle
	flora_density = 4
	flora_types = list(
		/obj/structure/flora/rock/pile = 10,
		/obj/structure/flora/rock = 20,
		/obj/structure/flora/bush = 40,
	)

/// Volcanic sand cave - hot underground
/datum/biome/cave/sand/volcanic
	open_turf_type = /turf/open/misc/asteroid/basalt
	closed_turf_type = /turf/closed/mineral/random/jungle
	flora_density = 2
	flora_types = list(/obj/structure/flora/rock/pile = 1, /obj/structure/flora/rock = 2)

/// Volcanic sand cave with lava
/datum/biome/cave/sand/volcanic/lava
	open_turf_type = /turf/open/lava/smooth

/// Acidic volcanic cave
/datum/biome/cave/sand/volcanic/acidic
	open_turf_type = /turf/open/misc/beach/sand
	flora_density = 0
