/**
 * # Planetary Biomes
 * Diverse biome types for planet generation
 */

// ============================================================================
// ASTEROID/ROCKY BIOME
// ============================================================================

/datum/biome/planet_asteroid
	open_turf_type = /turf/open/misc/asteroid
	flora_density = 5
	fauna_density = 0  // Disabled for now
	feature_density = 1

	flora_types = list(
		/obj/structure/flora/rock = 3,
		/obj/structure/flora/rock/pile = 1,
	)

	fauna_types = list()
	feature_types = list()

// ============================================================================
// ICE BIOME
// ============================================================================

/datum/biome/planet_ice
	open_turf_type = /turf/open/misc/asteroid/snow/icemoon
	flora_density = 8
	fauna_density = 0
	feature_density = 2

	flora_types = list(
		/obj/structure/flora/rock = 2,
		/obj/structure/flora/rock/pile = 2,
		/obj/structure/flora/grass/brown = 1,
		/obj/structure/flora/grass/both = 1,
	)

	fauna_types = list()
	feature_types = list()

// ============================================================================
// LAVA/VOLCANIC BIOME
// ============================================================================

/datum/biome/planet_lava
	open_turf_type = /turf/open/misc/asteroid/basalt/lava_land_surface
	flora_density = 10
	fauna_density = 0
	feature_density = 3

	flora_types = list(
		/obj/structure/flora/rock = 3,
		/obj/structure/flora/rock/pile = 2,
		/obj/structure/flora/bush = 2,
	)

	fauna_types = list()
	feature_types = list()

// ============================================================================
// JUNGLE BIOME
// ============================================================================

/datum/biome/planet_jungle
	open_turf_type = /turf/open/floor/grass
	flora_density = 20
	fauna_density = 0
	feature_density = 5

	flora_types = list(
		/obj/structure/flora/tree/jungle = 5,
		/obj/structure/flora/bush = 4,
		/obj/structure/flora/grass/jungle = 3,
		/obj/structure/flora/grass/jungle/b = 3,
		/obj/structure/flora/rock = 1,
	)

	fauna_types = list()
	feature_types = list()

// ============================================================================
// DESERT BIOME
// ============================================================================

/datum/biome/planet_desert
	open_turf_type = /turf/open/misc/beach/sand
	flora_density = 3
	fauna_density = 0
	feature_density = 1

	flora_types = list(
		/obj/structure/flora/rock = 3,
		/obj/structure/flora/rock/pile = 2,
		/obj/structure/flora/bush/grassy = 1,
	)

	fauna_types = list()
	feature_types = list()

// ============================================================================
// SAND BIOME (White Sand)
// ============================================================================

/datum/biome/planet_sand
	open_turf_type = /turf/open/misc/beach/sand
	flora_density = 4
	fauna_density = 0
	feature_density = 2

	flora_types = list(
		/obj/structure/flora/rock = 4,
		/obj/structure/flora/rock/pile = 3,
		/obj/structure/flora/bush/grassy = 1,
	)

	fauna_types = list()
	feature_types = list()

// ============================================================================
// WASTELAND/TOXIC BIOME
// ============================================================================

/datum/biome/planet_wasteland
	open_turf_type = /turf/open/misc/asteroid
	flora_density = 15
	fauna_density = 0
	feature_density = 8

	flora_types = list(
		/obj/structure/flora/rock = 3,
		/obj/structure/flora/rock/pile = 2,
		/obj/structure/girder/displaced = 1,
	)

	fauna_types = list()
	feature_types = list()

// ============================================================================
// BEACH BIOME
// ============================================================================

/datum/biome/planet_beach
	open_turf_type = /turf/open/misc/beach/sand
	flora_density = 6
	fauna_density = 0
	feature_density = 2

	flora_types = list(
		/obj/structure/flora/tree/palm = 1,
		/obj/structure/flora/bush/grassy = 2,
		/obj/structure/flora/rock = 3,
		/obj/structure/flora/grass/both = 2,
	)

	fauna_types = list()
	feature_types = list()

// ============================================================================
// MIXED GRASS BIOME (for oceanic planets)
// ============================================================================

/datum/biome/planet_grassland
	open_turf_type = /turf/open/floor/grass
	flora_density = 12
	fauna_density = 0
	feature_density = 3

	flora_types = list(
		/obj/structure/flora/grass/jungle = 3,
		/obj/structure/flora/grass/jungle/b = 3,
		/obj/structure/flora/bush = 2,
		/obj/structure/flora/bush/grassy = 2,
		/obj/structure/flora/tree/jungle = 1,
		/obj/structure/flora/rock = 1,
	)

	fauna_types = list()
	feature_types = list()
