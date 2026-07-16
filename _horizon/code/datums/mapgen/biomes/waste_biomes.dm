/**
 * WASTE BIOMES
 * Used by wasteland planet generator
 */

// ========================================
// MARK: SURFACE BIOMES
// ========================================

/// Base waste biome - industrial wasteland
/datum/biome/waste
	open_turf_type = /turf/open/misc/ashplanet/rocky
	fauna_density = 3
	flora_density = 25
	feature_density = 0.5
	fauna_types = list(
		/mob/living/basic/migo = 30,
		/mob/living/basic/faithless = 20,
		/mob/living/basic/blankbody = 40,
	)
	flora_types = list(
		/obj/structure/flora/rock/pile = 15,
		/obj/structure/flora/bush = 50,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/ash/tall_shroom = 5,
	)
	feature_types = list(
	)

/// Waste crater - impact craters
/datum/biome/waste/crater
	open_turf_type = /turf/open/misc/ashplanet
	flora_density = 0
	flora_types = list(
		/obj/structure/flora/rock/pile = 5,
		/obj/structure/flora/bush = 40,
	)

/// Waste clearing - cleared industrial areas
/datum/biome/waste/clearing
	open_turf_type = /turf/open/misc/ashplanet/rocky
	flora_density = 25
	flora_types = list(
		/obj/structure/flora/rock/pile = 10,
		/obj/structure/flora/bush = 50,
		/obj/structure/flora/bush = 45,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/ash/tall_shroom = 5,
	)

/// Mushroom clearing - areas with heavy fungal growth
/datum/biome/waste/clearing/mushroom
	flora_density = 30
	flora_types = list(
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/bush = 30,
		/obj/structure/flora/ash/tall_shroom = 20,
		/obj/structure/flora/ash/leaf_shroom = 10,
		/obj/structure/flora/ash/cap_shroom = 10,
	)

/// Metal waste - rusted metal floors
/datum/biome/waste/metal
	open_turf_type = /turf/open/misc/ashplanet/rocky
	flora_density = 1
	feature_density = 2
	flora_types = list(
		/obj/structure/girder/displaced = 3,
		/obj/structure/grille/broken = 2,
	)
	feature_types = list(
		/obj/structure/girder/displaced = 5,
		/obj/structure/grille/broken = 3,
		/obj/effect/spawner/random/structure/crate_abandoned = 1,
	)

/// Rusty metal waste - heavily corroded metal
/datum/biome/waste/metal/rust
	open_turf_type = /turf/open/floor/plating/rust
	flora_density = 3
	flora_types = list(
		/obj/structure/girder/displaced = 4,
		/obj/structure/grille/broken = 3,
		/obj/structure/flora/bush,
	)

/// Tar bed - sticky tar patches
/datum/biome/waste/tar_bed
	open_turf_type = /turf/open/misc/ashplanet/rocky
	flora_density = 1
	flora_types = list(
		/obj/structure/flora/rock/pile = 3,
	)

/// Total tar bed - pure tar coverage
/datum/biome/waste/tar_bed/total
	open_turf_type = /turf/open/lava
	flora_density = 0

// ========================================
// MARK: MARK: CAVE BIOMES
// ========================================

/// Waste cave - industrial underground tunnels
/datum/biome/cave/waste
	open_turf_type = /turf/open/misc/ashplanet/rocky
	closed_turf_type = /turf/closed/mineral/random/jungle
	fauna_density = 2
	flora_density = 30
	fauna_types = list(
		/mob/living/basic/migo = 30,
		/mob/living/basic/faithless = 20,
		/mob/living/basic/blankbody = 40,
	)
	flora_types = list(
		/obj/structure/flora/rock/pile = 10,
		/obj/structure/flora/bush = 50,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/ash/tall_shroom = 10,
	)

/// Concrete waste cave - concrete tunnels
/datum/biome/cave/waste/conc
	open_turf_type = /turf/open/misc/ashplanet
	closed_turf_type = /turf/closed/mineral/random/jungle
	flora_density = 30
	flora_types = list(
		/obj/structure/flora/bush = 50,
		/obj/structure/flora/bush = 40,
		/obj/structure/flora/bush = 35,
		/obj/structure/flora/ash/tall_shroom = 10,
	)

/// Metal waste cave - metal underground structures
/datum/biome/cave/waste/metal
	open_turf_type = /turf/open/misc/ashplanet/rocky
	closed_turf_type = /turf/closed/mineral/random/jungle
	flora_density = 5
	flora_types = list(
		/obj/structure/girder/displaced = 10,
		/obj/structure/grille/broken = 8,
		/obj/structure/flora/bush = 40,
	)

/// Hivebot metal cave - active hivebot areas
/datum/biome/cave/waste/metal/hivebot
	fauna_density = 8
	flora_density = 30
	fauna_types = list(
		/mob/living/basic/morph = 100,
		/mob/living/basic/migo = 30,
		/mob/living/basic/faithless = 20,
	)
	flora_types = list(
		/obj/structure/girder/displaced = 5,
		/obj/structure/grille/broken = 5,
		/obj/structure/flora/bush = 50,
		/obj/structure/flora/bush = 40,
	)

/// Radioactive waste cave - contaminated underground
/datum/biome/cave/waste/rad
	open_turf_type = /turf/open/misc/ashplanet/rocky
	closed_turf_type = /turf/closed/mineral/random/jungle
	flora_density = 15
	flora_types = list(
		/obj/structure/flora/bush,
		/obj/structure/flora/bush,
		/obj/structure/flora/bush,
		/obj/structure/flora/bush,
	)

/// Tar bed cave - underground tar pools
/datum/biome/cave/waste/tar_bed
	open_turf_type = /turf/open/misc/ashplanet/rocky
	closed_turf_type = /turf/closed/mineral/random/jungle
	flora_density = 2

/// Full tar cave - completely filled with tar
/datum/biome/cave/waste/tar_bed/full
	open_turf_type = /turf/open/lava
	flora_density = 0
