/**
 * # Planet Generator
 *
 * Basic planet generation system integrated with the supercruise system.
 */

/datum/map_generator/planet_generator
	// === BIOME TABLES ===
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

	// === DMM GENERATION (rust-g) ===
	/// When TRUE, uses rust-g DMM generation instead of DM-side perlin/biome terrain.
	/// DMM generation is significantly faster: all Perlin noise, CA, biome selection,
	/// turf placement, and flora spawning happens in Rust.
	var/use_dmm_generation = TRUE
	/// Planet type key passed to rust-g. Selects biome configs hardcoded in Rust.
	/// Must match a key in rust-g's get_planet_config() match block.
	/// Valid: "rock", "ice", "lava", "jungle", "desert", "beach", "grassland", "wasteland"
	var/biome_key = "rock"
	/// Seed for DMM generation. If 0, a random seed is generated in New().
	var/dmm_seed = 0

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

	// Initialize DMM seed if not set
	if(!dmm_seed)
		dmm_seed = rand(0, 999999)

	// Create NEW area instances for this planet (don't reuse global instances)
	// Each planet needs its own area instance to avoid conflicts when multiple planets exist
	primary_area = new primary_area_type
	cave_area = new cave_area_type

	// Generate cellular automata for caves if mountain_height < 1
	// Only needed for legacy (non-DMM) generation path
	if(mountain_height < 1 && !use_dmm_generation)
		// This generates the cave layout using cellular automata
		// The string represents a 2D grid where '0' = open space, '1' = wall
		string_gen = rustg_cnoise_generate("[initial_closed_chance]", "[smoothing_iterations]", "[birth_limit]", "[death_limit]", "[world.maxx]", "[world.maxy]")

	// Initialize caches
	turf_biome_cache = list()

/**
 * Generates a planet level using the virtual level system.
 *
 * When use_dmm_generation is TRUE (default), all terrain is generated in Rust
 * via rust-g's planet_generator_generate_dmm and loaded through /datum/parsed_map.
 * This is significantly faster than DM-side perlin/biome iteration.
 *
 * The legacy path (perlin noise + biome tables) is still available by setting
 * use_dmm_generation = FALSE on the generator subtype.
 *
 * Arguments:
 * * planet_name - Name of the planet
 * * planet_size - Size of the planet (default 100x100)
 * * baseturf - The base turf type for this planet
 * * mapzone - Optional existing mapzone to use
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

	// Get the bottom-left turf of the unreserved area (where we load the DMM)
	var/turf/load_turf = vlevel.get_unreserved_bottom_left_turf()
	if(!load_turf)
		log_world("ERROR: No unreserved turfs available for [planet_name]")
		generating = FALSE
		return null

	log_world("Generating planet [planet_name] ([planet_size]x[planet_size])...")

	if(use_dmm_generation)
		// === DMM GENERATION PATH (fast: all CA + turf placement in Rust) ===
		if(!generate_planet_dmm(planet_name, planet_size, load_turf))
			generating = FALSE
			return null
	else
		// === LEGACY GENERATION PATH (DM-side perlin + biome iteration) ===
		var/list/turf/turfs_to_generate = list()
		var/turf/top_right = vlevel.get_unreserved_top_right_turf()
		for(var/turf/T as anything in block(load_turf, top_right))
			turfs_to_generate += T

		if(!length(turfs_to_generate))
			log_world("ERROR: No turfs available for generation in [planet_name]")
			generating = FALSE
			return null

		// Generate the terrain using biome tables
		generate_terrain(turfs_to_generate, null)

		// Override atmospheres on all generated turfs to use breathable air
		override_turf_atmospheres(turfs_to_generate)

		// Populate with flora/fauna
		populate_terrain(turfs_to_generate, null)

		// Smooth all generated turfs to fix borders and transitions
		smooth_generated_turfs(turfs_to_generate, vlevel.z_value)

	log_world("Planet [planet_name] generation complete with [length(docking_ports)] docking ports!")

	// Clear generating flag - planet generation is complete
	generating = FALSE

	return list(vlevel, docking_ports)

/**
 * Generates terrain via rust-g DMM and loads it at the target turf.
 *
 * Calls rust-g to produce a complete TGM-format DMM string using cellular
 * automata, then parses and loads it through /datum/parsed_map.
 * All heavy computation (CA, DMM formatting) happens in Rust; DM only
 * handles map parsing and atom initialization.
 *
 * Arguments:
 * * planet_name - Name for logging
 * * planet_size - Width/height of the generated map
 * * load_turf - Bottom-left turf where the map is placed
 *
 * Returns: TRUE on success, FALSE on failure
 */
/datum/map_generator/planet_generator/proc/generate_planet_dmm(planet_name, planet_size, turf/load_turf)
	// Call rust-g to generate the complete DMM string with full procedural generation.
	// All biome configs (turfs, flora, areas) are hardcoded in Rust, looked up by biome_key.
	var/dmm_string = rustg_planet_generator_generate_dmm("[planet_size]", "[planet_size]", "[dmm_seed]", biome_key, "[mountain_height]", "[perlin_zoom]", "[initial_closed_chance]", "[smoothing_iterations]", "[birth_limit]", "[death_limit]")

	if(!dmm_string)
		log_world("ERROR: rust-g returned empty DMM string for [planet_name]")
		return FALSE

	// Parse the DMM string directly (no file I/O needed)
	var/datum/parsed_map/parsed = new(dmm_string)
	if(!parsed || !parsed.bounds)
		log_world("ERROR: Failed to parse DMM string for [planet_name]")
		return FALSE

	// Load the parsed map into the world at the target turf.
	// parsed.load() returns TRUE/FALSE (not bounds); actual bounds are in parsed.bounds.
	var/load_success = parsed.load(
		load_turf.x,
		load_turf.y,
		load_turf.z,
		crop_map = TRUE,
		no_changeturf = (SSatoms.initialized == INITIALIZATION_INSSATOMS),
	)
	if(!load_success)
		log_world("ERROR: DMM load failed for [planet_name]")
		return FALSE

	// Initialize atoms in the loaded area (turfs, areas, movables)
	var/datum/map_template/dummy = new()
	dummy.name = "planet_dmm_[planet_name]"
	dummy.initTemplateBounds(parsed.bounds)

	// Post-generation: smooth turfs and apply atmosphere
	var/list/turf/turfs_to_smooth = block(
		parsed.bounds[MAP_MINX], parsed.bounds[MAP_MINY], parsed.bounds[MAP_MINZ],
		parsed.bounds[MAP_MAXX], parsed.bounds[MAP_MAXY], parsed.bounds[MAP_MAXZ]
	)
	smooth_generated_turfs(turfs_to_smooth, load_turf.z)
	override_turf_atmospheres(turfs_to_smooth)

	log_world("DMM planet [planet_name] loaded at [load_turf.x],[load_turf.y],[load_turf.z]")
	return TRUE

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
