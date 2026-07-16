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
	fauna_density = 1
	flora_density = 10
	feature_density = 0.1
	fauna_types = list(
		/mob/living/basic/mining/wolf = 30,
		/mob/living/basic/bear/snow = 15,
		/mob/living/basic/mining/legion/snow = 50,
		/mob/living/basic/mining/goldgrub = 10,
		/mob/living/basic/mining/ice_whelp = 20,
		/obj/structure/spawner/ice_moon = 3,
		/obj/structure/spawner/ice_moon/polarbear = 3,
	)
	flora_types = list(
		/obj/structure/flora/tree/pine = 2,
		/obj/structure/flora/rock/icy = 2,
		/obj/structure/flora/rock/pile/icy = 2,
		/obj/structure/flora/grass/both = 6,
		/obj/structure/flora/ash/chilly = 2,
	)
	feature_types = list(
		/obj/structure/spawner/ice_moon/demonic_portal = 1,
		/obj/structure/spawner/ice_moon/demonic_portal/ice_whelp = 1,
		/obj/structure/spawner/ice_moon/demonic_portal/snowlegion = 1,
	)

/// Snow biome with lush vegetation
/datum/biome/snow/lush
	open_turf_type = /turf/open/misc/asteroid/snow
	flora_density = 30
	flora_types = list(
		/obj/structure/flora/grass/both = 1,
	)

/// Thawed snow biome - melting ice with temperate plants
/datum/biome/snow/thawed
	open_turf_type = /turf/open/misc/dirt/jungle/dark
	flora_density = 40
	flora_types = list(
		/obj/structure/flora/bush/fullgrass = 1,
		/obj/structure/flora/bush/sparsegrass = 1,
		/obj/structure/flora/bush = 1,
		/obj/structure/flora/bush/flowers_pp = 1,
		/obj/structure/flora/bush/lavendergrass = 1
	)

/// Snow forest - pine trees and grass
/datum/biome/snow/forest
	flora_density = 15
	flora_types = list(
		/obj/structure/flora/tree/pine = 10,
		/obj/structure/flora/tree/dead = 3,
		/obj/structure/flora/grass/both = 4
	)

/// Dense snow forest - heavy pine coverage
/datum/biome/snow/forest/dense
	flora_density = 25
	flora_types = list(
		/obj/structure/flora/tree/pine = 20,
		/obj/structure/flora/grass/both = 6,
		/obj/structure/flora/tree/dead = 3,
	)

/// Arctic biome - extreme cold with ice creatures
/datum/biome/arctic
	open_turf_type = /turf/open/misc/asteroid/snow
	fauna_density = 1
	flora_density = 5
	feature_density = 0.1
	flora_types = list(
		/obj/structure/flora/rock/icy = 10,
		/obj/structure/flora/rock/pile/icy = 10,
		/obj/structure/flora/grass/both = 5,
		/obj/structure/flora/bush = 20,
	)
	flora_types = list(
		/mob/living/basic/mining/wolf = 30,
		/mob/living/basic/bear/snow = 15,
		/mob/living/basic/mining/legion/snow = 50,
		/mob/living/basic/mining/goldgrub = 10,
		/mob/living/basic/mining/ice_whelp = 15,
		/obj/structure/spawner/ice_moon = 3,
		/obj/structure/spawner/ice_moon/polarbear = 3,
	)
	feature_types = list(
		/obj/structure/statue/snow/snowman = 3,
		/obj/structure/statue/snow/snowlegion = 1,
	)

/// Rocky arctic variant - more rocks, less vegetation
/datum/biome/arctic/rocky
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/rock/icy = 2,
		/obj/structure/flora/rock/pile/icy = 2,
	)

/// Iceberg biome - massive ice formations
/datum/biome/iceberg
	open_turf_type = /turf/open/misc/asteroid/snow/ice
	closed_turf_type = /turf/closed/mineral/random/snow
	fauna_density = 2
	feature_density = 0.2
	fauna_types = list(
		/mob/living/basic/mining/ice_demon = 30,
		/mob/living/basic/mining/wolf = 25,
		/mob/living/basic/bear = 10,
		/mob/living/basic/mining/wolf = 5,
		/mob/living/simple_animal/hostile/megafauna/dragon = 1,
		/mob/living/simple_animal/hostile/megafauna/dragon = 1,
	)
	feature_types = list(
		/obj/structure/spawner/ice_moon/demonic_portal = 1,
		/obj/structure/spawner/ice_moon/demonic_portal/ice_whelp = 1,
		/obj/structure/spawner/ice_moon/demonic_portal/snowlegion = 1,
	)

/// Iceberg with frozen lake
/datum/biome/iceberg/lake
	open_turf_type = /turf/open/misc/ice

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
	fauna_density = 2
	flora_density = 6
	feature_density = 0.1
	fauna_types = list(
		/mob/living/basic/mining/wolf = 30,
		/mob/living/basic/bear/snow = 15,
		/mob/living/basic/mining/legion/snow = 50,
		/mob/living/basic/mining/goldgrub = 10,
		/mob/living/basic/mining/ice_whelp = 15,
		/obj/structure/spawner/ice_moon = 3,
		/obj/structure/spawner/ice_moon/polarbear = 3,
	)
	flora_types = list(
		/obj/structure/flora/grass/both = 5,
		/obj/structure/flora/rock/pile = 1,
		///obj/structure/flora/rock/snow = 1,
		/obj/structure/flora/ash/leaf_shroom = 1,
		/obj/structure/flora/ash/cap_shroom = 1,
		/obj/structure/flora/ash/stem_shroom = 1,
		///obj/structure/flora/ash/whitesands/puce = 1,
	)
	feature_types = list(
		/obj/structure/spawner/ice_moon/demonic_portal = 1,
		/obj/structure/spawner/ice_moon/demonic_portal/ice_whelp = 1,
		/obj/structure/spawner/ice_moon/demonic_portal/snowlegion = 1,
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
	flora_density = 3
	feature_density = 0.1
	fauna_types = list(
		/mob/living/basic/mining/wolf = 30,
		/mob/living/basic/bear/snow = 15,
		/mob/living/basic/mining/legion/snow = 50,
		/mob/living/basic/mining/goldgrub = 10,
		/mob/living/basic/mining/ice_whelp = 15,
		/obj/structure/spawner/ice_moon = 3,
		/obj/structure/spawner/ice_moon/polarbear = 3,
	)
	flora_types = list(
		/obj/structure/flora/ash/leaf_shroom = 1,
		/obj/structure/flora/ash/cap_shroom = 1,
		/obj/structure/flora/ash/stem_shroom = 1,
	)
	feature_types = list(
		/obj/structure/spawner/ice_moon/demonic_portal = 1,
		/obj/structure/spawner/ice_moon/demonic_portal/ice_whelp = 1,
		/obj/structure/spawner/ice_moon/demonic_portal/snowlegion = 1,
	)

/// Volcanic cave with lava pockets
/datum/biome/cave/volcanic/lava
	open_turf_type = /turf/open/lava/smooth

/// Volcanic cave with full lava
/datum/biome/cave/volcanic/lava/total
	open_turf_type = /turf/open/lava/smooth

/// Volcanic cave with plasma lava
/datum/biome/cave/volcanic/lava/plasma
	open_turf_type = /turf/open/lava/plasma
