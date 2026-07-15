/**
 * SNOW/ICE BIOMES
 * Used by ice planet generator
 */

// ========================================
// MARK: SURFACE BIOMES
// ========================================

/// Base snow biome - snowy plains
/datum/biome/snow
	open_turf_type = /turf/open/misc/asteroid/snow
	flora_types = list(
		/obj/structure/flora/tree/pine = 4,
		/obj/structure/flora/rock/icy = 4,
		/obj/structure/flora/rock/pile/icy = 4,
		/obj/structure/flora/grass/both = 12,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
	)
	flora_density = 10
	fauna_density = 1
	fauna_types = list(
		/mob/living/basic/mining/ice_demon = 30,
		/mob/living/basic/mining/wolf = 25,
		/mob/living/basic/bear = 10,
		/mob/living/basic/mining/wolf = 5,
		/mob/living/basic/mining/wolf = 5,
		/mob/living/basic/bear = 10,
	)
	feature_density = 0.1
	feature_types = list(
	)

/// Snow biome with lush vegetation
/datum/biome/snow/lush
	open_turf_type = /turf/open/misc/asteroid/snow
	flora_types = list(
		/obj/structure/flora/tree/pine = 20,
		/obj/structure/flora/grass/both = 10,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/tree/dead = 3,
	)
	flora_density = 30

/// Thawed snow biome - melting ice with temperate plants
/datum/biome/snow/thawed
	open_turf_type = /turf/open/misc/asteroid/snow/ice
	flora_density = 40
	flora_types = list(
		/obj/structure/flora/bush = 50,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/grass/both = 10,
		/obj/structure/flora/rock/icy = 3,
		/obj/structure/flora/rock/pile/icy = 2,
	)

/// Snow forest - pine trees and grass
/datum/biome/snow/forest
	flora_density = 15
	flora_types = list(
		/obj/structure/flora/tree/pine = 20,
		/obj/structure/flora/tree/dead = 6,
		/obj/structure/flora/grass/both = 8,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/rock/icy = 3,
	)

/// Dense snow forest - heavy pine coverage
/datum/biome/snow/forest/dense
	flora_density = 30
	flora_types = list(
		/obj/structure/flora/tree/pine = 25,
		/obj/structure/flora/grass/both = 10,
		/obj/structure/flora/tree/dead = 5,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
	)

/// Arctic biome - extreme cold with ice creatures
/datum/biome/arctic
	open_turf_type = /turf/open/misc/asteroid/snow
	feature_density = 0.1
	feature_types = list(
		/obj/structure/statue/snow/snowman = 3,
		/obj/structure/statue/snow/snowlegion = 1,
	)
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/rock/icy = 10,
		/obj/structure/flora/rock/pile/icy = 10,
		/obj/structure/flora/grass/both = 5,
		/obj/structure/flora/bush = 20,
	)
	fauna_density = 1

/// Rocky arctic variant - more rocks, less vegetation
/datum/biome/arctic/rocky
	flora_density = 10
	flora_types = list(
		/obj/structure/flora/rock/icy = 15,
		/obj/structure/flora/rock/pile/icy = 15,
		/obj/structure/flora/bush = 10,
	)

/// Iceberg biome - massive ice formations
/datum/biome/iceberg
	open_turf_type = /turf/open/misc/asteroid/snow/ice
	closed_turf_type = /turf/closed/mineral/random/snow
	fauna_density = 2
	fauna_types = list(
		/mob/living/basic/mining/ice_demon = 30,
		/mob/living/basic/mining/wolf = 25,
		/mob/living/basic/bear = 10,
		/mob/living/simple_animal/hostile/megafauna/dragon = 1,
		/mob/living/simple_animal/hostile/megafauna/dragon = 1,
		/mob/living/basic/mining/wolf = 5,
	)
	feature_density = 0.3
	feature_types = list(
	)

/// Iceberg with frozen lake
/datum/biome/iceberg/lake
	open_turf_type = /turf/open/floor/plating/icemoon

/// Plasma ice biome - exotic frozen plasma
/datum/biome/plasma
	open_turf_type = /turf/open/lava/plasma/ice_moon

// ========================================
// MARK: CAVE BIOMES
// ========================================

/// Snow cave - icy underground chambers
/datum/biome/cave/snow
	open_turf_type = /turf/open/misc/asteroid/snow/ice
	closed_turf_type = /turf/closed/mineral/random/snow
	flora_density = 4
	flora_types = list(
		/obj/structure/flora/grass/both = 10,
		/obj/structure/flora/rock/pile/icy = 5,
		/obj/structure/flora/rock/icy = 5,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/bush = 10,
	)
	fauna_density = 2
	fauna_types = list(
		/mob/living/basic/mining/ice_demon = 30,
		/mob/living/basic/mining/wolf = 25,
		/mob/living/basic/bear = 10,
		/mob/living/simple_animal/hostile/megafauna/dragon = 1,
		/mob/living/simple_animal/hostile/megafauna/dragon = 1,
		/mob/living/basic/bear = 10,
	)
	feature_density = 1
	feature_types = list(
	)

/// Thawed snow cave - cracked ice floors
/datum/biome/cave/snow/thawed
	open_turf_type = /turf/open/misc/asteroid/snow/ice
	closed_turf_type = /turf/closed/mineral/random/snow

/// Ice cave - pure ice floors
/datum/biome/cave/snow/ice
	open_turf_type = /turf/open/misc/asteroid/snow/ice
	closed_turf_type = /turf/closed/mineral/random/snow
/// Volcanic cave under ice - hot basalt under frozen surface
/datum/biome/cave/volcanic
	open_turf_type = /turf/open/misc/asteroid/basalt
	closed_turf_type = /turf/closed/mineral/random/snow
	fauna_density = 2
	fauna_types = list(
		/mob/living/basic/mining/ice_demon = 30,
		/mob/living/basic/mining/wolf = 25,
		/mob/living/basic/bear = 10,
		/mob/living/simple_animal/hostile/megafauna/dragon = 1,
		/mob/living/simple_animal/hostile/megafauna/dragon = 1,
		/mob/living/basic/bear = 10,
	)
	flora_density = 3
	flora_types = list(
		/obj/structure/flora/bush,
		/obj/structure/flora/bush,
		/obj/structure/flora/bush,
	)
	feature_density = 0.2

/// Volcanic cave with lava pockets
/datum/biome/cave/volcanic/lava
	open_turf_type = /turf/open/lava/smooth

/// Volcanic cave with full lava
/datum/biome/cave/volcanic/lava/total
	open_turf_type = /turf/open/lava/smooth

/// Volcanic cave with plasma lava
/datum/biome/cave/volcanic/lava/plasma
	open_turf_type = /turf/open/lava/plasma
