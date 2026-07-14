#include "beach_biomes.dm"
#include "jungle_biomes.dm"
#include "lavaland_biomes.dm"
#include "planetary_biomes.dm"
#include "rock_biomes.dm"
#include "sand_biomes.dm"
#include "snow_biomes.dm"
#include "waste_biomes.dm"

// ============================================================================
// PLANETARY BIOMES FOR SUPERCRUISE PLANET GENERATION
// ============================================================================
// NOTE: These simple biomes are ONLY used for visual representation in supercruise.
// Actual planet generation uses detailed biomes from the individual biome files
// ============================================================================

/datum/biome/planet_asteroid
	open_turf_type = /turf/open/misc/asteroid
	closed_turf_type = /turf/closed/mineral/random
	flora_density = 5
	fauna_density = 0
	feature_density = 1
	flora_types = list(
		/obj/structure/flora/rock = 3,
		/obj/structure/flora/rock/pile = 1,
	)

/datum/biome/planet_ice
	open_turf_type = /turf/open/misc/asteroid/snow/icemoon
	closed_turf_type = /turf/closed/mineral/random
	flora_density = 8
	fauna_density = 0
	feature_density = 2
	flora_types = list(
		/obj/structure/flora/rock = 2,
		/obj/structure/flora/rock/pile = 2,
		/obj/structure/flora/grass/brown = 1,
		/obj/structure/flora/grass/both = 1,
	)

/datum/biome/planet_lava
	open_turf_type = /turf/open/misc/asteroid/basalt/lava_land_surface
	closed_turf_type = /turf/closed/mineral/volcanic
	flora_density = 10
	fauna_density = 0
	feature_density = 3
	flora_types = list(
		/obj/structure/flora/rock = 3,
		/obj/structure/flora/rock/pile = 2,
		/obj/structure/flora/bush = 2,
	)

/datum/biome/planet_jungle
	open_turf_type = /turf/open/floor/grass
	closed_turf_type = /turf/closed/mineral/random/jungle
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

/datum/biome/planet_desert
	open_turf_type = /turf/open/misc/beach/sand
	closed_turf_type = /turf/closed/mineral/random
	flora_density = 3
	fauna_density = 0
	feature_density = 1
	flora_types = list(
		/obj/structure/flora/rock = 3,
		/obj/structure/flora/rock/pile = 2,
		/obj/structure/flora/bush/grassy = 1,
	)

/datum/biome/planet_beach
	open_turf_type = /turf/open/misc/beach/sand
	closed_turf_type = /turf/closed/mineral/random
	flora_density = 6
	fauna_density = 0
	feature_density = 2
	flora_types = list(
		/obj/structure/flora/tree/palm = 1,
		/obj/structure/flora/bush/grassy = 2,
		/obj/structure/flora/rock = 3,
		/obj/structure/flora/grass/both = 2,
	)

/datum/biome/planet_grassland
	open_turf_type = /turf/open/floor/grass
	closed_turf_type = /turf/closed/mineral/random
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

/datum/biome/planet_wasteland
	open_turf_type = /turf/open/misc/asteroid
	closed_turf_type = /turf/closed/mineral/random
	flora_density = 15
	fauna_density = 0
	feature_density = 8
	flora_types = list(
		/obj/structure/flora/rock = 3,
		/obj/structure/flora/rock/pile = 2,
		/obj/structure/girder/displaced = 1,
	)

// ============================================================================
// CAVE BIOME BASE CLASS
// ============================================================================

/**
 * Cave biomes are special biomes that use cellular automata to create
 * natural cave systems with walls and floors.
 * The closed flag in gen_turfs[turf] determines if it's a wall or floor.
 */
/datum/biome/cave

/datum/biome/cave/planet_asteroid
	open_turf_type = /turf/open/misc/asteroid
	closed_turf_type = /turf/closed/mineral/random
	flora_density = 8
	fauna_density = 0
	feature_density = 2
	flora_types = list(
		/obj/structure/flora/rock = 4,
		/obj/structure/flora/rock/pile = 3,
	)

/datum/biome/cave/planet_ice
	open_turf_type = /turf/open/misc/asteroid/snow/icemoon
	closed_turf_type = /turf/closed/mineral/random
	flora_density = 10
	fauna_density = 0
	feature_density = 3
	flora_types = list(
		/obj/structure/flora/rock = 3,
		/obj/structure/flora/rock/pile = 3,
		/obj/structure/flora/grass/both = 2,
	)

/datum/biome/cave/planet_lava
	open_turf_type = /turf/open/misc/asteroid/basalt/lava_land_surface
	closed_turf_type = /turf/closed/mineral/volcanic
	flora_density = 12
	fauna_density = 0
	feature_density = 5
	flora_types = list(
		/obj/structure/flora/rock = 5,
		/obj/structure/flora/rock/pile = 4,
	)

/datum/biome/cave/planet_jungle
	open_turf_type = /turf/open/misc/dirt
	closed_turf_type = /turf/closed/mineral/random/jungle
	flora_density = 25
	fauna_density = 0
	feature_density = 8
	flora_types = list(
		/obj/structure/flora/bush = 5,
		/obj/structure/flora/grass/jungle = 4,
		/obj/structure/flora/grass/jungle/b = 4,
		/obj/structure/flora/rock = 2,
	)

/datum/biome/cave/planet_desert
	open_turf_type = /turf/open/misc/beach/sand
	closed_turf_type = /turf/closed/mineral/random
	flora_density = 5
	fauna_density = 0
	feature_density = 2
	flora_types = list(
		/obj/structure/flora/rock = 4,
		/obj/structure/flora/rock/pile = 3,
	)

/datum/biome/cave/planet_beach
	open_turf_type = /turf/open/misc/beach/sand
	closed_turf_type = /turf/closed/mineral/random
	flora_density = 8
	fauna_density = 0
	feature_density = 3
	flora_types = list(
		/obj/structure/flora/rock = 4,
		/obj/structure/flora/rock/pile = 2,
		/obj/structure/flora/grass/both = 2,
	)

/datum/biome/cave/planet_grassland
	open_turf_type = /turf/open/misc/dirt
	closed_turf_type = /turf/closed/mineral/random
	flora_density = 15
	fauna_density = 0
	feature_density = 4
	flora_types = list(
		/obj/structure/flora/grass/jungle = 3,
		/obj/structure/flora/grass/jungle/b = 3,
		/obj/structure/flora/rock = 3,
		/obj/structure/flora/bush = 2,
	)

/datum/biome/cave/planet_wasteland
	open_turf_type = /turf/open/misc/asteroid
	closed_turf_type = /turf/closed/mineral/random
	flora_density = 20
	fauna_density = 0
	feature_density = 10
	flora_types = list(
		/obj/structure/flora/rock = 3,
		/obj/structure/flora/rock/pile = 2,
		/obj/structure/girder/displaced = 2,
	)
