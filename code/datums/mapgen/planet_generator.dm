/**
 * # Planet Generator
 *
 * Basic planet generation system integrated with the supercruise system.
 */

/datum/map_generator/planet_generator
	// === BIOME TABLES (PentestSS13 approach) ===
	/// 2D associative list: biome_table[heat_level][humidity_level] = biome_type
	/// Heat levels: BIOME_COLDEST, BIOME_COLD, BIOME_WARM, BIOME_TEMPERATE, BIOME_HOT, BIOME_HOTTEST
	/// Humidity levels: BIOME_LOWEST_HUMIDITY, BIOME_LOW_HUMIDITY, BIOME_MEDIUM_HUMIDITY, BIOME_HIGH_HUMIDITY, BIOME_HIGHEST_HUMIDITY
	var/list/biome_table

	/// 2D associative list for cave biomes: cave_biome_table[heat_level][humidity_level] = cave_biome_type
	/// Heat levels: BIOME_COLDEST_CAVE, BIOME_COLD_CAVE, BIOME_WARM_CAVE, BIOME_HOT_CAVE
	/// Humidity levels: same as surface
	var/list/cave_biome_table

	// === PERLIN NOISE SEEDS ===
	/// Random seed for height perlin noise (determines cave vs surface)
	var/height_seed
	/// Random seed for heat/temperature perlin noise
	var/heat_seed
	/// Random seed for humidity perlin noise
	var/humidity_seed

	// === TERRAIN PARAMETERS ===
	/// If a turf's perlin-calculated "height" is above this value, a cave will be generated
	/// Lower values = more caves. Values: 0.45 (55% caves) to 0.95 (5% caves). 1.0 = no caves
	var/mountain_height = 0.80
	/// Higher values create larger biome zones and cave systems
	var/perlin_zoom = 65
	/// TRUE when planet is actively generating, used to block docking during generation
	var/generating = FALSE

	// === CELLULAR AUTOMATA (for organic cave shapes) ===
	/// Chance for a cell in the cave cellular automaton to start closed (wall)
	var/initial_closed_chance = 45
	/// Number of smoothing iterations for cave generation
	var/smoothing_iterations = 20
	/// If an open cell has more than this many closed neighbors, it becomes closed
	var/birth_limit = 4
	/// If a closed cell has fewer than this many closed neighbors, it becomes open
	var/death_limit = 3

	// === AREAS ===
	/// The area type to use for the planet surface
	var/area/primary_area_type = /area/planet
	/// The area instance for the surface
	var/area/primary_area
	/// The area type to use for caves
	var/area/cave_area_type = /area/planet/cave
	/// The area instance for caves
	var/area/cave_area

	// === INTERNAL ===
	/// Stored CA string for cave generation
	var/string_gen
	/// Cache mapping turfs to their selected biomes (to avoid recalculation)
	var/list/turf_biome_cache
	/// Temporary lists for feature/mob spawning
	var/list/created_features
	var/list/created_mobs

/datum/map_generator/planet_generator/New()
	. = ..()

	// Initialize random perlin seeds
	height_seed = rand(0, 50000)
	heat_seed = rand(0, 50000)
	humidity_seed = rand(0, 50000)

	// Create NEW area instances for this planet (don't reuse global instances)
	// Each planet needs its own area instance to avoid conflicts when multiple planets exist
	primary_area = new primary_area_type
	cave_area = new cave_area_type

	// Generate cellular automata for caves if mountain_height < 1
	if(mountain_height < 1)
		// This generates the cave layout using cellular automata
		// The string represents a 2D grid where '0' = open space, '1' = wall
		string_gen = rustg_cnoise_generate("[initial_closed_chance]", "[smoothing_iterations]", "[birth_limit]", "[death_limit]", "[world.maxx]", "[world.maxy]")

	// Initialize caches
	turf_biome_cache = list()

/**
 * Generates a planet level using the virtual level system
 *
 * Arguments:
 * * planet_name - Name of the planet
 * * planet_size - Size of the planet (default 100x100)
 * * baseturf - The base turf type for this planet
 * * mapzone - Optional existing mapzone to use
 * * atmosphere - Optional atmosphere datum to apply to the planet
 *
 * Returns: A list containing [vlevel, list of docking_ports], or null if planet already exists
 */
/datum/map_generator/planet_generator/proc/generate_planet_level(planet_name = "Planet", planet_size = 100, baseturf = /turf/open/space/basic, datum/map_zone/mapzone = null)
	// Set generating flag to prevent docking during planet generation
	generating = TRUE

	// Check if a planet with this name already exists to prevent regeneration
	for(var/datum/map_zone/existing_zone as anything in SSmapping.map_zones)
		if(existing_zone.name == "[planet_name] Zone")
			log_world("WARNING: Planet [planet_name] already exists! Skipping regeneration.")
			// Clear generating flag before returning
			generating = FALSE
			// Find the existing virtual level and docking ports
			if(length(existing_zone.virtual_levels))
				var/datum/virtual_level/existing_vlevel = existing_zone.virtual_levels[1]
				var/list/existing_docks = list()
				// Find docking ports in this z-level
				for(var/obj/docking_port/stationary/dock in SSshuttle.stationary_docking_ports)
					if(dock.z == existing_vlevel.z_value)
						existing_docks += dock
				return list(existing_vlevel, existing_docks)
			return null

	// Create a map zone for this planet if not provided
	if(!mapzone)
		mapzone = SSmapping.create_map_zone("[planet_name] Zone")
		if(!mapzone)
			log_world("ERROR: Failed to create map zone for [planet_name]")
			generating = FALSE
			return null

	// Add extra space for the 1-tile border on each side
	var/total_size = planet_size + 2

	// Create a virtual level for the planet
	var/datum/virtual_level/vlevel = SSmapping.create_virtual_level(
		planet_name,
		list(ZTRAIT_MINING = TRUE, ZTRAIT_BASETURF = baseturf),
		mapzone,
		total_size,
		total_size,
		ALLOCATION_FREE,
		DEFAULT_ALLOC_JUMP
	)

	if(!vlevel)
		log_world("ERROR: Failed to create virtual level for [planet_name]")
		generating = FALSE
		return null

	// Reserve a 1-tile margin to create indestructible borders
	vlevel.reserve_margin(1)

	// Create docking ports for ship landing
	var/list/docking_ports = create_docking_ports(vlevel, planet_name)

	// Get the turfs to generate (excluding the border)
	var/list/turf/turfs_to_generate = list()
	var/turf/bottom_left = vlevel.get_unreserved_bottom_left_turf()
	var/turf/top_right = vlevel.get_unreserved_top_right_turf()

	for(var/turf/T as anything in block(bottom_left, top_right))
		turfs_to_generate += T

	if(!length(turfs_to_generate))
		log_world("ERROR: No turfs available for generation in [planet_name]")
		generating = FALSE
		return null

	log_world("Generating planet [planet_name] with [length(turfs_to_generate)] turfs...")

	// Generate the terrain using parent implementation
	generate_terrain(turfs_to_generate, null)

	// Override atmospheres on all generated turfs to use breathable air
	override_turf_atmospheres(turfs_to_generate)

	// Populate with flora/fauna using parent implementation
	populate_terrain(turfs_to_generate, null)

	// Smooth all generated turfs to fix borders and transitions
	smooth_generated_turfs(turfs_to_generate, vlevel.z_value)

	log_world("Planet [planet_name] generation complete with [length(docking_ports)] docking ports!")

	// Clear generating flag - planet generation is complete
	generating = FALSE

	return list(vlevel, docking_ports)

/**
 * Creates docking ports for ship landing
 * Creates multiple adjustable docking ports at different locations on the planet
 *
 * Arguments:
 * * vlevel - The virtual level to create docking ports in
 * * planet_name - Name of the planet for labeling docking ports
 *
 * Returns: A list of created docking ports
 */
/datum/map_generator/planet_generator/proc/create_docking_ports(datum/virtual_level/vlevel, planet_name)
	var/list/docking_ports = list()

	// Landing zone dimensions - using adjust_dock_for_landing to auto-fit shuttles
	// These define the maximum bounds that docks can adjust within
	#define LANDING_ZONE_WIDTH 20   // Max width for landing zones
	#define LANDING_ZONE_HEIGHT 20  // Max height for landing zones
	#define LANDING_ZONE_PADDING 5
	#define SHUTTLE_BOTTOM_CLEARANCE 5  // Tiles from bottom of map to bottom of shuttle

	// Calculate positions for 4 docking ports spread across the planet
	// Position them within the unreserved area, accounting for clearance

	var/unreserved_start_x = vlevel.low_x + vlevel.reserved_margin
	var/unreserved_start_y = vlevel.low_y + vlevel.reserved_margin

	// Primary dock - positioned so shuttle bottom is SHUTTLE_BOTTOM_CLEARANCE tiles from map edge
	// With dir=NORTH and dheight=0, the docking port IS the shuttle bottom
	var/turf/primary_turf = locate(
		unreserved_start_x + LANDING_ZONE_PADDING,
		unreserved_start_y + SHUTTLE_BOTTOM_CLEARANCE,
		vlevel.z_value
	)

	var/obj/docking_port/stationary/primary_dock = new(primary_turf)
	primary_dock.dir = NORTH
	primary_dock.name = "[planet_name] Landing Zone #1"
	primary_dock.height = LANDING_ZONE_HEIGHT
	primary_dock.width = LANDING_ZONE_WIDTH
	primary_dock.dheight = 0
	primary_dock.dwidth = 0
	primary_dock.adjust_dock_for_landing = TRUE  // Auto-adjust to fit incoming shuttles
	primary_dock.planet_generator = src  // Store reference to check generation status
	docking_ports += primary_dock

	// Secondary dock - offset to the right
	var/turf/secondary_turf = locate(
		primary_turf.x + LANDING_ZONE_WIDTH + LANDING_ZONE_PADDING,
		primary_turf.y,
		vlevel.z_value
	)

	var/obj/docking_port/stationary/secondary_dock = new(secondary_turf)
	secondary_dock.dir = NORTH
	secondary_dock.name = "[planet_name] Landing Zone #2"
	secondary_dock.height = LANDING_ZONE_HEIGHT
	secondary_dock.width = LANDING_ZONE_WIDTH
	secondary_dock.dheight = 0
	secondary_dock.dwidth = 0
	secondary_dock.adjust_dock_for_landing = TRUE  // Auto-adjust to fit incoming shuttles
	secondary_dock.planet_generator = src  // Store reference to check generation status
	docking_ports += secondary_dock

	// For planets 100x100 or smaller, only create 2 landing zones
	// For larger planets, create 4 landing zones
	if(vlevel.x_distance >= 150)
		// Tertiary dock - offset upward from primary
		var/turf/tertiary_turf = locate(
			primary_turf.x,
			primary_turf.y + LANDING_ZONE_HEIGHT + LANDING_ZONE_PADDING,
			vlevel.z_value
		)

		var/obj/docking_port/stationary/tertiary_dock = new(tertiary_turf)
		tertiary_dock.dir = NORTH
		tertiary_dock.name = "[planet_name] Landing Zone #3"
		tertiary_dock.height = LANDING_ZONE_HEIGHT
		tertiary_dock.width = LANDING_ZONE_WIDTH
		tertiary_dock.dheight = 0
		tertiary_dock.dwidth = 0
		tertiary_dock.adjust_dock_for_landing = TRUE  // Auto-adjust to fit incoming shuttles
		tertiary_dock.planet_generator = src  // Store reference to check generation status
		docking_ports += tertiary_dock

		// Quaternary dock - offset upward from secondary
		var/turf/quaternary_turf = locate(
			secondary_turf.x,
			secondary_turf.y + LANDING_ZONE_HEIGHT + LANDING_ZONE_PADDING,
			vlevel.z_value
		)

		var/obj/docking_port/stationary/quaternary_dock = new(quaternary_turf)
		quaternary_dock.dir = NORTH
		quaternary_dock.name = "[planet_name] Landing Zone #4"
		quaternary_dock.height = LANDING_ZONE_HEIGHT
		quaternary_dock.width = LANDING_ZONE_WIDTH
		quaternary_dock.dheight = 0
		quaternary_dock.dwidth = 0
		quaternary_dock.adjust_dock_for_landing = TRUE  // Auto-adjust to fit incoming shuttles
		quaternary_dock.planet_generator = src  // Store reference to check generation status
		docking_ports += quaternary_dock

	#undef LANDING_ZONE_WIDTH
	#undef LANDING_ZONE_HEIGHT
	#undef LANDING_ZONE_PADDING
	#undef SHUTTLE_BOTTOM_CLEARANCE

	return docking_ports

/**
 * Get the appropriate biome for a turf based on perlin noise values
 * This implements the PentestSS13 biome table selection system
 *
 * Arguments:
 * * target_turf - The turf to get a biome for
 *
 * Returns:
 * * The selected biome datum, or null if none found
 */
/datum/map_generator/planet_generator/proc/get_biome(turf/target_turf)
	// Check cache first
	if(turf_biome_cache[target_turf])
		return turf_biome_cache[target_turf]

	// Calculate perlin coordinates with zoom and slight drift
	var/drift_x = (target_turf.x + rand(-1, 1)) / perlin_zoom
	var/drift_y = (target_turf.y + rand(-1, 1)) / perlin_zoom

	// Get three perlin noise values: height, heat, and humidity
	var/height = text2num(rustg_noise_get_at_coordinates("[height_seed]", "[drift_x]", "[drift_y]"))
	var/heat = text2num(rustg_noise_get_at_coordinates("[heat_seed]", "[drift_x]", "[drift_y]"))
	var/humidity = text2num(rustg_noise_get_at_coordinates("[humidity_seed]", "[drift_x]", "[drift_y]"))

	// Determine if this is a cave or surface based on height
	var/is_cave = (mountain_height < 1) && (height > mountain_height)

	// Select the appropriate biome table
	var/list/selected_table = is_cave ? cave_biome_table : biome_table
	if(!selected_table)
		log_world("ERROR: No biome table found for planet generator!")
		return null

	// Determine heat category
	var/heat_level
	if(is_cave)
		// Cave heat categories (4 levels)
		if(heat < 0.25)
			heat_level = BIOME_COLDEST_CAVE
		else if(heat < 0.50)
			heat_level = BIOME_COLD_CAVE
		else if(heat < 0.75)
			heat_level = BIOME_WARM_CAVE
		else
			heat_level = BIOME_HOT_CAVE
	else
		// Surface heat categories (6 levels)
		if(heat < 0.20)
			heat_level = BIOME_COLDEST
		else if(heat < 0.40)
			heat_level = BIOME_COLD
		else if(heat < 0.60)
			heat_level = BIOME_WARM
		else if(heat < 0.65)
			heat_level = BIOME_TEMPERATE
		else if(heat < 0.80)
			heat_level = BIOME_HOT
		else
			heat_level = BIOME_HOTTEST

	// Determine humidity category (5 levels for both surface and cave)
	var/humidity_level
	if(humidity < 0.20)
		humidity_level = BIOME_LOWEST_HUMIDITY
	else if(humidity < 0.40)
		humidity_level = BIOME_LOW_HUMIDITY
	else if(humidity < 0.60)
		humidity_level = BIOME_MEDIUM_HUMIDITY
	else if(humidity < 0.80)
		humidity_level = BIOME_HIGH_HUMIDITY
	else
		humidity_level = BIOME_HIGHEST_HUMIDITY

	// Look up biome from table
	var/biome_type = selected_table[heat_level]?[humidity_level]
	if(!biome_type)
		log_world("ERROR: No biome found for heat=[heat_level], humidity=[humidity_level]")
		return null

	// Instantiate and cache the biome
	var/datum/biome/selected_biome = new biome_type
	turf_biome_cache[target_turf] = selected_biome

	return selected_biome

/**
 * Override generate_terrain from parent class
 * Generate turfs for the planet, including caves
 * Uses biome tables with heat/humidity variation
 */
/datum/map_generator/planet_generator/generate_terrain(list/turfs, area/generate_in)
	if(!biome_table)
		log_world("ERROR: No biome table set for planet generator!")
		return

	// Group turfs by biome for efficient generation
	var/list/biome_to_turfs = list()
	var/list/turf/surface_turfs = list()
	var/list/turf/cave_turfs = list()

	log_world("MAPGEN: Beginning biome selection for [length(turfs)] turfs...")

	// First pass: determine biome for each turf and group them
	for(var/turf/T as anything in turfs)
		var/datum/biome/selected_biome = get_biome(T)
		if(!selected_biome)
			continue

		// Track surface vs cave for area assignment
		var/drift_x = (T.x + rand(-1, 1)) / perlin_zoom
		var/drift_y = (T.y + rand(-1, 1)) / perlin_zoom
		var/height = text2num(rustg_noise_get_at_coordinates("[height_seed]", "[drift_x]", "[drift_y]"))

		if(mountain_height < 1 && height > mountain_height)
			cave_turfs += T
		else
			surface_turfs += T

		// Group turfs by their biome for batch processing
		if(!biome_to_turfs[selected_biome])
			biome_to_turfs[selected_biome] = list()
		biome_to_turfs[selected_biome] += T

		CHECK_TICK

	log_world("MAPGEN: Found [length(biome_to_turfs)] unique biomes. Surface: [length(surface_turfs)], Caves: [length(cave_turfs)]")

	// Second pass: generate turfs for each biome group
	for(var/datum/biome/current_biome as anything in biome_to_turfs)
		var/list/turf/biome_turfs = biome_to_turfs[current_biome]
		log_world("MAPGEN: Generating [length(biome_turfs)] turfs for biome [current_biome.type]...")

		// Use cave string_gen if this is a cave biome
		var/use_string = (istype(current_biome, /datum/biome/cave) && string_gen) ? string_gen : null
		var/list/turf/generated_turfs = current_biome.generate_turfs_for_terrain(biome_turfs, use_string)

		// Assign generated turfs to appropriate areas
		for(var/turf/new_turf as anything in generated_turfs)
			if(new_turf in cave_turfs)
				cave_area.contents += new_turf
			else
				primary_area.contents += new_turf
			CHECK_TICK

	log_world("MAPGEN: Terrain generation complete!")

/**
 * Override populate_terrain from parent class
 * Populate turfs with flora, fauna, and features using cached biomes
 */
/datum/map_generator/planet_generator/populate_terrain(list/turfs, area/generate_in)
	var/flora_allowed = TRUE
	var/features_allowed = TRUE
	var/fauna_allowed = TRUE

	log_world("MAPGEN: Beginning population of [length(turfs)] turfs...")

	for(var/turf/target_turf as anything in turfs)
		// Get the biome from cache
		var/datum/biome/turf_biome = turf_biome_cache[target_turf]
		if(!turf_biome)
			continue

		// Don't spawn mobs/flora inside closed turfs (walls)
		if(isclosedturf(target_turf))
			// Only generate terrain features for closed turfs, no fauna/flora
			turf_biome.populate_turfs(target_turf, FALSE, features_allowed, FALSE)
			CHECK_TICK
			continue

		// Populate using the turf's specific biome (normal open turfs)
		turf_biome.populate_turfs(target_turf, flora_allowed, features_allowed, fauna_allowed)
		CHECK_TICK

	log_world("MAPGEN: Population complete!")

/**
 * Smooth all generated turfs to fix borders and transitions
 * This ensures proper turf smoothing after generation, especially for multi-z transitions
 *
 * Arguments:
 * * turfs - List of turfs to smooth
 * * z_level - The z-level where smoothing should occur
 */
/datum/map_generator/planet_generator/proc/smooth_generated_turfs(list/turf/turfs, z_level)
	log_world("MAPGEN: Beginning smoothing pass for [length(turfs)] turfs...")

	var/smoothed_count = 0
	for(var/turf/T as anything in turfs)
		// Only smooth turfs that have smoothing flags
		if(T.smoothing_flags & (SMOOTH_BITMASK | SMOOTH_DIAGONAL_CORNERS))
			T.smooth_icon()
			smoothed_count++

			// Also smooth adjacent turfs to handle borders properly
			for(var/turf/adjacent in orange(1, T))
				if(adjacent.smoothing_flags & (SMOOTH_BITMASK | SMOOTH_DIAGONAL_CORNERS))
					adjacent.smooth_icon()

		CHECK_TICK

	log_world("MAPGEN: Smoothing complete! Smoothed [smoothed_count] turfs.")


// ============================================================================
// SPECIFIC PLANET TYPES
// ============================================================================

/**
 * Rocky Planet Generator
 * Creates a simple rocky/asteroid-like planet with mineral-rich caves
 */
/datum/map_generator/planet_generator/rocky
	primary_area_type = /area/planet/rocky
	cave_area_type = /area/planet/cave/rocky
	mountain_height = 0.80  // Moderate amount of caves

/datum/map_generator/planet_generator/rocky/New()
	. = ..()

	// Surface biome table - using planet_asteroid as placeholder for all combinations
	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/planet_asteroid,
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/planet_asteroid,
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/planet_asteroid,
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/planet_asteroid,
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/planet_asteroid,
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/planet_asteroid,
		),
	)

	// Cave biome table
	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/planet_asteroid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/planet_asteroid,
		),
	)

/**
 * Ice Planet Generator
 * Creates a frozen ice world with icy caves
 */
/datum/map_generator/planet_generator/ice
	primary_area_type = /area/planet/ice
	cave_area_type = /area/planet/cave/ice
	mountain_height = 0.75  // More caves due to ice fracturing

/datum/map_generator/planet_generator/ice/New()
	. = ..()

	// Surface biome table from PentestSS13 - uses snow biome variants
	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/arctic/rocky,
			BIOME_LOW_HUMIDITY = /datum/biome/snow,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/iceberg/lake,
			BIOME_HIGH_HUMIDITY = /datum/biome/iceberg,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/iceberg,
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/arctic,
			BIOME_LOW_HUMIDITY = /datum/biome/arctic/rocky,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/snow/lush,
			BIOME_HIGH_HUMIDITY = /datum/biome/snow,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/iceberg,
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/snow/thawed,
			BIOME_LOW_HUMIDITY = /datum/biome/snow/forest,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/snow,
			BIOME_HIGH_HUMIDITY = /datum/biome/snow/lush,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/iceberg,
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/snow/lush,
			BIOME_LOW_HUMIDITY = /datum/biome/snow/forest,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/snow/thawed,
			BIOME_HIGH_HUMIDITY = /datum/biome/snow,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/snow/lush,
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/snow/forest,
			BIOME_LOW_HUMIDITY = /datum/biome/snow/lush,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/snow/thawed,
			BIOME_HIGH_HUMIDITY = /datum/biome/snow,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/snow/lush,
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/snow/thawed,
			BIOME_LOW_HUMIDITY = /datum/biome/snow/forest,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/snow/thawed,
			BIOME_HIGH_HUMIDITY = /datum/biome/snow/forest/dense,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/snow/thawed,
		),
	)

	// Cave biome table from PentestSS13 - ice caves with volcanic hotspots
	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/snow,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/snow,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/snow,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/snow,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/snow/ice,
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/snow,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/snow,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/snow,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/snow/ice,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/snow/ice,
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/snow,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/snow,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/snow/thawed,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/snow/thawed,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/snow,
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/snow/thawed,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/snow/thawed,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/volcanic/lava/plasma,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/volcanic/lava,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/volcanic/lava/total,
		),
	)

/**
 * Lava Planet Generator
 * Creates a volcanic hellscape with extensive magma tunnel systems
 * Lava planets are VERY cave-heavy due to volcanic activity creating underground networks
 */
/datum/map_generator/planet_generator/lava
	primary_area_type = /area/planet/lava
	cave_area_type = /area/planet/cave/lava
	mountain_height = 0.45  // 55% caves! Extensive lava tube networks like PentestSS13
	perlin_zoom = 65  // Same as PentestSS13 lava planets

/datum/map_generator/planet_generator/lava/New()
	. = ..()

	// Surface biome table from PentestSS13 - uses lavaland biome variants for variety
	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/lavaland/forest,
			BIOME_LOW_HUMIDITY = /datum/biome/lavaland/plains/dense/mixed,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/lavaland/forest/rocky,
			BIOME_HIGH_HUMIDITY = /datum/biome/lavaland/outback,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/lavaland/plains/dense,
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/lavaland/plains,
			BIOME_LOW_HUMIDITY = /datum/biome/lavaland/outback,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/lavaland/plains/dense,
			BIOME_HIGH_HUMIDITY = /datum/biome/lavaland/plains/dense/mixed,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/lavaland,
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/lavaland,
			BIOME_LOW_HUMIDITY = /datum/biome/lavaland/lush,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/lavaland/forest,
			BIOME_HIGH_HUMIDITY = /datum/biome/lavaland,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/lavaland/lava,
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/lavaland/outback,
			BIOME_LOW_HUMIDITY = /datum/biome/lavaland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/lavaland/forest,
			BIOME_HIGH_HUMIDITY = /datum/biome/lavaland/lava,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/lavaland/nearlava,
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/lavaland/plains,
			BIOME_LOW_HUMIDITY = /datum/biome/lavaland/nearlava,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/lavaland,
			BIOME_HIGH_HUMIDITY = /datum/biome/lavaland/nearlava,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/lavaland/lava,
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/lavaland/forest/rocky,
			BIOME_LOW_HUMIDITY = /datum/biome/lavaland/outback,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/lavaland,
			BIOME_HIGH_HUMIDITY = /datum/biome/lavaland/nearlava,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/lavaland/lava,
		),
	)

	// Cave biome table from PentestSS13 - extensive lava tubes and obsidian formations
	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/lavaland/rocky,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/lavaland/rocky,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/lavaland,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/lavaland,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/lavaland/mossy,
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/lavaland/rocky,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/lavaland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/lavaland/lava,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/lavaland,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/lavaland/lava,
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/lavaland/rocky,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/lavaland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/lavaland/mossy,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/lavaland/obsidian,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/lavaland/lava,
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/lavaland/rocky,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/lavaland/mossy,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/lavaland/obsidian,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/lavaland/lava,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/lavaland/lava,
		),
	)


/**
 * Jungle Planet Generator
 * Creates a lush jungle world with root-filled caverns
 */
/datum/map_generator/planet_generator/jungle
	primary_area_type = /area/planet/jungle
	cave_area_type = /area/planet/cave/jungle
	mountain_height = 0.85  // Fewer caves, dense surface vegetation

/datum/map_generator/planet_generator/jungle/New()
	. = ..()

	// Surface biome table from PentestSS13 - dense jungle with mudlands and water areas
	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/jungle,
			BIOME_LOW_HUMIDITY = /datum/biome/jungle,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/jungle/dense,
			BIOME_HIGH_HUMIDITY = /datum/biome/mudlands,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/mudlands,
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/jungle,
			BIOME_LOW_HUMIDITY = /datum/biome/jungle/dense,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/mudlands,
			BIOME_HIGH_HUMIDITY = /datum/biome/mudlands,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/mudlands,
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/jungle,
			BIOME_LOW_HUMIDITY = /datum/biome/jungle,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/mudlands,
			BIOME_HIGH_HUMIDITY = /datum/biome/mudlands,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/jungle,
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/jungle/dense,
			BIOME_LOW_HUMIDITY = /datum/biome/mudlands,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/jungle/water,
			BIOME_HIGH_HUMIDITY = /datum/biome/jungle/water,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/jungle/water,
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/jungle/dense,
			BIOME_LOW_HUMIDITY = /datum/biome/jungle,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/mudlands,
			BIOME_HIGH_HUMIDITY = /datum/biome/jungle/water,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/jungle,
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/jungle,
			BIOME_LOW_HUMIDITY = /datum/biome/jungle,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/jungle/dense,
			BIOME_HIGH_HUMIDITY = /datum/biome/jungle,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/jungle/water,
		),
	)

	// Cave biome table from PentestSS13 - lush caves and dirt caves
	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/jungle/dirt,
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/jungle/dirt,
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/jungle,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/jungle,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/jungle,
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/jungle,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/jungle/dirt,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/lush,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/lush/bright,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/lush/bright,
		),
	)

/**
 * Desert Planet Generator
 * Creates a hot, dry desert world with carved canyons
 */
/datum/map_generator/planet_generator/desert
	primary_area_type = /area/planet/desert
	cave_area_type = /area/planet/cave/desert
	mountain_height = 0.82  // Wind-carved caves

/datum/map_generator/planet_generator/desert/New()
	. = ..()

	// Surface biome table from PentestSS13 - sand biomes with wasteland and riverbed variations
	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/sand,
			BIOME_LOW_HUMIDITY = /datum/biome/sand,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/sand/grass/dead,
			BIOME_HIGH_HUMIDITY = /datum/biome/sand/icecap,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/sand/icecap,
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/sand,
			BIOME_LOW_HUMIDITY = /datum/biome/sand/riverbed,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/sand/wasteland,
			BIOME_HIGH_HUMIDITY = /datum/biome/sand/wasteland,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/sand/icecap,
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/sand,
			BIOME_LOW_HUMIDITY = /datum/biome/sand,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/sand/riverbed,
			BIOME_HIGH_HUMIDITY = /datum/biome/sand,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/sand,
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/sand,
			BIOME_LOW_HUMIDITY = /datum/biome/sand/grass/dead,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/sand/riverbed,
			BIOME_HIGH_HUMIDITY = /datum/biome/sand/grass/dead,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/sand,
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/sand,
			BIOME_LOW_HUMIDITY = /datum/biome/sand,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/sand,
			BIOME_HIGH_HUMIDITY = /datum/biome/sand/riverbed,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/sand,
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/sand,
			BIOME_LOW_HUMIDITY = /datum/biome/sand,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/sand/sulfur_plains,
			BIOME_HIGH_HUMIDITY = /datum/biome/sand/sulfur_plains,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/sand,
		),
	)

	// Cave biome table from PentestSS13 - underground sand caverns, some volcanic
	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/sand/volcanic/acidic,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/sand/deep,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/sand/deep,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/sand,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/sand,
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/sand/volcanic/lava,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/sand,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/sand/deep,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/sand,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/sand,
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/sand/volcanic,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/sand,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/sand,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/sand/deep,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/sand,
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/sand/volcanic/lava,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/sand/volcanic,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/sand/volcanic,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/sand/deep,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/sand,
		),
	)

/**
 * Beach/Oceanic Planet Generator
 * Creates a water world with underwater grottos
 */
/datum/map_generator/planet_generator/beach
	primary_area_type = /area/planet/beach
	cave_area_type = /area/planet/cave/beach
	mountain_height = 0.88  // Few caves, mostly coastal

/datum/map_generator/planet_generator/beach/New()
	. = ..()

	// Surface biome table from PentestSS13 - ocean planet with beaches and jungle areas
	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/ocean/deep,
			BIOME_LOW_HUMIDITY = /datum/biome/ocean,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/beach,
			BIOME_HIGH_HUMIDITY = /datum/biome/beach,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/grass,
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/ocean/deep,
			BIOME_LOW_HUMIDITY = /datum/biome/ocean,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/beach,
			BIOME_HIGH_HUMIDITY = /datum/biome/grass/dense,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/beach_jungle,
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/ocean/deep,
			BIOME_LOW_HUMIDITY = /datum/biome/ocean,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/beach,
			BIOME_HIGH_HUMIDITY = /datum/biome/grass/dense,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/grass,
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/ocean/deep,
			BIOME_LOW_HUMIDITY = /datum/biome/ocean,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/beach/dense,
			BIOME_HIGH_HUMIDITY = /datum/biome/beach,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/grass,
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/ocean,
			BIOME_LOW_HUMIDITY = /datum/biome/beach,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/beach,
			BIOME_HIGH_HUMIDITY = /datum/biome/grass,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/grass/dense,
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/ocean/deep,
			BIOME_LOW_HUMIDITY = /datum/biome/beach/dense,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/beach,
			BIOME_HIGH_HUMIDITY = /datum/biome/grass,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/beach_jungle,
		),
	)

	// Cave biome table from PentestSS13 - sandy caves and coves
	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/beach/cove,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/beach,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/beach/magical,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/beach,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/beach,
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/beach,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/beach,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/beach,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/beach/magical,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/beach,
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/beach,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/beach,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/beach,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/beach,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/beach,
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/beach,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/beach/magical,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/beach,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/beach,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/beach,
		),
	)

/**
 * Grassland Planet Generator
 * Creates a temperate grassland world with limestone caves
 */
/datum/map_generator/planet_generator/grassland
	primary_area_type = /area/planet/grassland
	cave_area_type = /area/planet/cave/grassland
	mountain_height = 0.80  // Moderate cave systems

/datum/map_generator/planet_generator/grassland/New()
	. = ..()

	// Surface biome table from PentestSS13 - rock planet with icecaps and wetlands
	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/rock/icecap,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/rock/icecap,
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/rock/icecap,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/rock/icecap,
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/rock/wetlands,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/rock/wetlands,
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/rock/wetlands,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/rock,
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/rock/wetlands,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/rock/wetlands,
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/rock,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/rock,
		),
	)

	// Cave biome table from PentestSS13 - simple rock caves, some wet
	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/rock,
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/rock,
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/rock,
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/rock,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/rock,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/rock,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/rock,
		),
	)

/**
 * Wasteland Planet Generator
 * Creates a toxic wasteland with industrial ruins
 */
/datum/map_generator/planet_generator/wasteland
	primary_area_type = /area/planet/wasteland
	cave_area_type = /area/planet/cave/wasteland
	mountain_height = 0.78  // Many collapsed structures and tunnels

/datum/map_generator/planet_generator/wasteland/New()
	. = ..()

	// Surface biome table from PentestSS13 - toxic waste with craters, metal ruins, tar beds
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

	// Cave biome table from PentestSS13 - underground waste, concrete ruins, tar pits
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


// ============================================================================
// ATMOSPHERIC PROCESSING
// ============================================================================

// Define a simple breathable atmosphere for all generated planets
// This is the same as OPENTURF_DEFAULT_ATMOS (breathable air)
#define PLANET_DEFAULT_ATMOS "o2=22;n2=82;TEMP=293.15"

/**
 * Overrides the atmosphere on all generated turfs to use breathable air
 * This replaces any hazardous atmospheres (like LAVALAND_ATMOS with plasma)
 * with a safe, breathable oxygen/nitrogen mix
 *
 * Arguments:
 * * turfs_to_process - List of turfs to override atmospheres for
 */
/datum/map_generator/planet_generator/proc/override_turf_atmospheres(list/turf/turfs_to_process)
	if(!length(turfs_to_process))
		return

	var/turfs_modified = 0

	for(var/turf/open/target_turf as anything in turfs_to_process)
		if(!istype(target_turf))
			continue

		// Only override turfs that have planetary atmospheres
		if(!target_turf.planetary_atmos)
			continue

		// Replace the initial_gas_mix with breathable air
		target_turf.initial_gas_mix = PLANET_DEFAULT_ATMOS

		// Recreate the gas mixture with the new atmosphere
		if(target_turf.air)
			target_turf.air = target_turf.create_gas_mixture()

		turfs_modified++

// ============================================================================
// AREAS
// ============================================================================

/area/planet
	name = "Planet Surface"
	icon_state = "yellow"
	default_gravity = STANDARD_GRAVITY
	area_flags = CAVES_ALLOWED | FLORA_ALLOWED | MOB_SPAWN_ALLOWED
	// Make planet surfaces bright (like outside stations)
	static_lighting = TRUE
	base_lighting_alpha = 255
	base_lighting_color = COLOR_WHITE

/area/planet/rocky
	name = "Rocky Planet Surface"
	icon_state = "dark"

/area/planet/ice
	name = "Ice Planet Surface"
	icon_state = "blue"

/area/planet/lava
	name = "Lava Planet Surface"
	icon_state = "red"

/area/planet/jungle
	name = "Jungle Planet Surface"
	icon_state = "green"

/area/planet/desert
	name = "Desert Planet Surface"
	icon_state = "yellow"

/area/planet/beach
	name = "Beach Planet Surface"
	icon_state = "purple"

/area/planet/grassland
	name = "Grassland Planet Surface"
	icon_state = "green"

/area/planet/wasteland
	name = "Wasteland Planet Surface"
	icon_state = "orange"

// ============================================================================
// CAVE AREAS (darker lighting, underground feel)
// ============================================================================

/area/planet/cave
	name = "Planet Cave"
	icon_state = "cave"
	// Darker lighting for caves
	base_lighting_alpha = 180
	base_lighting_color = "#B0B0B0"

/area/planet/cave/rocky
	name = "Rocky Planet Cave"

/area/planet/cave/ice
	name = "Ice Planet Cave"

/area/planet/cave/lava
	name = "Lava Planet Cave"

/area/planet/cave/jungle
	name = "Jungle Planet Cave"

/area/planet/cave/desert
	name = "Desert Planet Cave"

/area/planet/cave/beach
	name = "Beach Planet Cave"

/area/planet/cave/grassland
	name = "Grassland Planet Cave"

/area/planet/cave/wasteland
	name = "Wasteland Planet Cave"
