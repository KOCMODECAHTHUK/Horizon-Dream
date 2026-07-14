/**
 * BEACH/OCEAN BIOMES
 * Used by beach planet generator
 */

// ========================================
// SURFACE BIOMES
// ========================================

/// Base beach biome - sandy shores
/datum/biome/beach
	open_turf_type = /turf/open/misc/beach/sand
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/tree/palm = 1,
		/obj/structure/flora/rock = 2,
		/obj/structure/flora/rock/pile = 3,
		/obj/structure/flora/bush,
		/obj/structure/flora/bush,
	)
	fauna_density = 2
	fauna_types = list(
		/mob/living/basic/carp = 10,
		/mob/living/basic/carp = 5,
	)

/// Dense beach - heavier sand coverage
/datum/biome/beach/dense
	open_turf_type = /turf/open/misc/beach/sand
	flora_density = 3
	flora_types = list(
		/obj/structure/flora/rock = 2,
		/obj/structure/flora/rock/pile = 2,
	)

/// Beach jungle - tropical coastal vegetation
/datum/biome/beach_jungle
	flora_density = 70
	open_turf_type = /turf/open/misc/dirt
	flora_types = list(
		/obj/structure/flora/grass/jungle = 10,
		/obj/structure/flora/grass/jungle/b = 10,
		/obj/structure/flora/tree/jungle = 20,
		/obj/structure/flora/rock/pile/jungle = 5,
		/obj/structure/flora/bush/jungle = 50,
		/obj/structure/flora/bush/jungle = 40,
		/obj/structure/flora/bush/jungle = 35,
		/obj/structure/flora/bush/jungle = 10,
		/obj/structure/spacevine = 20,
		/obj/structure/flora/bush = 40,
	)

/// Grass biome - grassy coastal areas
/datum/biome/grass
	open_turf_type = /turf/open/floor/grass
	flora_density = 40
	flora_types = list(
		/obj/structure/flora/bush = 50,
		/obj/structure/flora/bush = 45,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/bush = 30,
		/obj/structure/flora/bush = 10,
		/obj/structure/flora/tree/palm = 5,
	)

/// Dense grass - heavy grass coverage
/datum/biome/grass/dense
	flora_density = 70
	flora_types = list(
		/obj/structure/flora/bush = 50,
		/obj/structure/flora/bush = 45,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/bush = 30,
		/obj/structure/flora/bush = 10,
		/obj/structure/flora/tree/palm = 10,
	)

/// Ocean biome - shallow water
/datum/biome/ocean
	open_turf_type = /turf/open/water/jungle
	flora_density = 0
	fauna_density = 1
	fauna_types = list(
		/mob/living/basic/carp = 10,
		/mob/living/basic/carp = 5,
	)

/// Deep ocean - deep water areas
/datum/biome/ocean/deep
	open_turf_type = /turf/open/water/jungle
	flora_density = 0
	fauna_density = 1.4
	fauna_types = list(
		/mob/living/basic/carp = 10,
		/mob/living/simple_animal/hostile/megafauna/dragon = 2,
	)

// ========================================
// CAVE BIOMES
// ========================================

/// Beach cave - sandy underground chambers
/datum/biome/cave/beach
	open_turf_type = /turf/open/misc/beach/sand
	closed_turf_type = /turf/closed/mineral/random/jungle
	flora_density = 4
	flora_types = list(
		/obj/structure/flora/rock = 15,
		/obj/structure/flora/rock = 10,
		/obj/structure/flora/bush = 40,
	)
	fauna_density = 1
	fauna_types = list(
		/mob/living/basic/carp = 5,
		/mob/living/simple_animal/hostile/megafauna/dragon = 1,
	)

/// Beach cove - coastal cave formations
/datum/biome/cave/beach/cove
	open_turf_type = /turf/open/misc/beach/sand
	flora_types = list(
		/obj/structure/flora/tree/pine = 10,
		/obj/structure/flora/rock = 10,
		/obj/structure/flora/tree/dead = 15,
		/obj/structure/flora/tree/dead = 10,
		/obj/structure/flora/bush = 40,
	)
	flora_density = 20

/// Magical beach cave - enchanted underground
/datum/biome/cave/beach/magical
	open_turf_type = /turf/open/misc/dirt/jungle
	flora_density = 20
	flora_types = list(
		/obj/structure/flora/bush = 50,
		/obj/structure/flora/bush = 45,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/bush = 30,
		/obj/structure/flora/bush = 10,
	)
