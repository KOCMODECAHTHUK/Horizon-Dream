/**
 * # Planet Generator
 */

/datum/map_generator/planet_generator
	var/list/biome_table
	var/list/cave_biome_table
	var/height_seed
	var/heat_seed
	var/humidity_seed
	var/mountain_height = 0.80
	var/perlin_zoom = 65
	var/generating = FALSE
	var/initial_closed_chance = 45
	var/smoothing_iterations = 20
	var/birth_limit = 4
	var/death_limit = 3
	var/area/primary_area_type = /area/planet
	var/area/primary_area
	var/area/cave_area_type = /area/planet/cave
	var/area/cave_area
	var/use_dmm_generation = TRUE
	var/dmm_seed = 0
	var/string_gen
	var/list/turf_biome_cache
	var/list/created_features
	var/list/created_mobs

/datum/map_generator/planet_generator/New()
	. = ..()
	height_seed = rand(0, 50000)
	heat_seed = rand(0, 50000)
	humidity_seed = rand(0, 50000)
	if(!dmm_seed)
		dmm_seed = rand(0, 999999)
	primary_area = new primary_area_type
	cave_area = new cave_area_type
	turf_biome_cache = list()

/datum/map_generator/planet_generator/proc/generate_planet_level(planet_name = "Planet", planet_size = 100, baseturf = /turf/closed/void, datum/map_zone/mapzone = null)
	log_world("MAPGEN: Starting generation for [planet_name] ([planet_size]x[planet_size])")
	generating = TRUE

	for(var/datum/map_zone/existing_zone as anything in SSmapping.map_zones)
		if(existing_zone.name == "[planet_name] Zone")
			log_world("MAPGEN: Planet [planet_name] already exists! Skipping regeneration.")
			generating = FALSE
			if(length(existing_zone.virtual_levels))
				var/datum/virtual_level/existing_vlevel = existing_zone.virtual_levels[1]
				var/list/existing_docks = list()
				for(var/obj/docking_port/stationary/dock in SSshuttle.stationary_docking_ports)
					if(dock.z == existing_vlevel.z_value)
						existing_docks += dock
				return list(existing_vlevel, existing_docks, existing_zone.virtual_levels.Copy())
			return null

	if(!mapzone)
		log_world("MAPGEN: Creating map zone for [planet_name]...")
		mapzone = SSmapping.create_map_zone("[planet_name] Zone")
		if(!mapzone)
			log_world("MAPGEN ERROR: Failed to create map zone for [planet_name]")
			generating = FALSE
			return null

	var/total_size = planet_size + 2

	var/list/level_definitions = list(
		list("name" = "[planet_name] Dungeon", "baseturf" = /turf/closed/void, "generate_terrain" = TRUE),
		list("name" = "[planet_name] Deep Caves", "baseturf" = /turf/open/openspace/airless/planetary, "generate_terrain" = TRUE),
		list("name" = "[planet_name] Caves", "baseturf" = /turf/open/openspace/airless/planetary, "generate_terrain" = TRUE),
		list("name" = "[planet_name] Surface", "baseturf" = /turf/open/openspace/airless/planetary, "generate_terrain" = TRUE),
		list("name" = "[planet_name] Second Floor", "baseturf" = /turf/open/openspace, "generate_terrain" = FALSE)
	)

	var/list/datum/virtual_level/created_levels = list()
	var/datum/virtual_level/surface_vlevel = null

	log_world("MAPGEN: Creating [length(level_definitions)] virtual levels...")
	for(var/i in 1 to length(level_definitions))
		var/list/def = level_definitions[i]
		var/level_name = def["name"]
		var/level_baseturf = def["baseturf"]

		var/list/traits = list(
			ZTRAIT_MINING = TRUE,
			ZTRAIT_BASETURF = level_baseturf
		)
		if(i < length(level_definitions))
			traits[ZTRAIT_UP] = TRUE
		if(i > 1)
			traits[ZTRAIT_DOWN] = TRUE

		var/datum/virtual_level/new_vlevel = SSmapping.create_planet_vlevel(
			level_name,
			traits,
			mapzone,
			total_size,
			total_size
		)

		if(!new_vlevel)
			log_world("MAPGEN ERROR: Failed to create virtual level [level_name]")
			generating = FALSE
			return null

		new_vlevel.reserve_margin(1)
		created_levels += new_vlevel

	surface_vlevel = created_levels[4]

	var/list/docking_ports = create_docking_ports(surface_vlevel, planet_name)
	var/turf/load_turf = created_levels[1].get_unreserved_bottom_left_turf() // Берем нижний левый турф ПЕРВОГО (самого нижнего) уровня!

	if(!load_turf)
		log_world("MAPGEN ERROR: No unreserved turfs available")
		generating = FALSE
		return null

	var/levels_to_generate = 4
	if(use_dmm_generation)
		log_world("MAPGEN: Generating Multi-Z DMM for [planet_name]...")
		if(!generate_planet_dmm(planet_name, planet_size, load_turf, levels_to_generate))
			log_world("MAPGEN ERROR: generate_planet_dmm failed for [planet_name]")
			generating = FALSE
			return null
	else
		// Легаси путь (постепенная генерация)
		for(var/i in 1 to length(created_levels))
			var/datum/virtual_level/vlevel = created_levels[i]
			var/list/def = level_definitions[i]
			var/generate_terrain_flag = def["generate_terrain"]

			if(generate_terrain_flag)
				var/turf/bottom_left = vlevel.get_unreserved_bottom_left_turf()
				var/turf/top_right = vlevel.get_unreserved_top_right_turf()
				var/list/turf/turfs_to_generate = block(bottom_left, top_right)
				if(length(turfs_to_generate))
					generate_terrain(turfs_to_generate, null)
					override_turf_atmospheres(turfs_to_generate)
					populate_terrain(turfs_to_generate, null)
					smooth_generated_turfs(turfs_to_generate, vlevel.z_value)

	log_world("MAPGEN: Filling 5th level with openspace...")
	created_levels[5].fill_in(/turf/open/openspace)

	log_world("MAPGEN: Planet [planet_name] generation complete!")
	generating = FALSE
	return list(surface_vlevel, docking_ports, created_levels)

/**
 * Generates terrain via rust-g DMM and loads it at the target turf.
 * Serializes the biome tables into JSON, passes it to rust-g which performs
 * all Perlin noise, CA, biome selection, and flora/fauna placement, generating
 * a single Multi-Z DMM file. Then loads it through /datum/map_template.
 */
/datum/map_generator/planet_generator/proc/generate_planet_dmm(planet_name, planet_size, turf/load_turf, z_levels_count = 1)
	log_world("MAPGEN_DMM: Building JSON config for [planet_name] (Z-Levels: [z_levels_count])...")
	var/config_json = build_biome_config_json(planet_size, planet_size, dmm_seed, z_levels_count)

	var/file_name = "data/tmp/planet_[dmm_seed]_multiz.dmm"
	if(fexists(file_name))
		fdel(file_name)

	log_world("MAPGEN_DMM: Calling rust-g to save DMM to [file_name]...")
	var/result = rustg_planet_generator_save_dmm(config_json, file_name)
	if(result != "1")
		log_world("MAPGEN_DMM ERROR: rust-g failed: [result]")
		return FALSE

	log_world("MAPGEN_DMM: Setting up map_template...")
	var/datum/map_template/template = new()
	template.name = "planet_[planet_name]"
	template.mappath = file_name
	template.should_place_on_top = FALSE // НЕ ЗАБЫТЬ УБРАТЬ

	log_world("MAPGEN_DMM: Preloading template size...")
	if(!template.preload_size(template.mappath, TRUE))
		log_world("MAPGEN_DMM ERROR: Failed to preload template.")
		fdel(file_name)
		return FALSE

	log_world("MAPGEN_DMM: Loading template into world at [load_turf.x],[load_turf.y],[load_turf.z]...")
	var/list/bounds = template.load(load_turf, centered = FALSE)

	//fdel(file_name) // НЕ ЗАБЫТЬ УБРАТЬ

	if(!bounds)
		log_world("MAPGEN_DMM ERROR: Template.load() failed.")
		return FALSE

	log_world("MAPGEN_DMM: Post-processing turfs (smoothing & atmos)...")
	var/list/turf/turfs_to_smooth = block(
		bounds[MAP_MINX], bounds[MAP_MINY], bounds[MAP_MINZ],
		bounds[MAP_MAXX], bounds[MAP_MAXY], bounds[MAP_MAXZ]
	)
	smooth_generated_turfs(turfs_to_smooth, load_turf.z)
	override_turf_atmospheres(turfs_to_smooth)

	log_world("MAPGEN_DMM: Success for [planet_name]")
	return TRUE

/**
 * Builds a JSON config string containing all generation parameters and biome
 * configurations, to be passed to rust-g's planet_generator_save_dmm.
 */
/datum/map_generator/planet_generator/proc/build_biome_config_json(width, height, seed, z_levels = 1)
	// 1. Collect unique biome types from both tables
	var/list/biome_type_to_index = list()
	var/list/biome_defs = list()

	var/list/tables_to_scan = list(biome_table, cave_biome_table)
	for(var/list/table in tables_to_scan)
		if(!table)
			continue
		for(var/heat_key in table)
			var/list/humidity_map = table[heat_key]
			if(!humidity_map)
				continue
			for(var/humidity_key in humidity_map)
				var/biome_path = humidity_map[humidity_key]
				if(!biome_path || (biome_path in biome_type_to_index))
					continue
				biome_type_to_index[biome_path] = biome_defs.len // 0-indexed
				biome_defs += list(get_biome_def_json(biome_path))

	// 2. Build surface table (6 heat × 5 humidity)
	var/list/surface_indices = list()
	var/list/heat_keys_surface = list(
		BIOME_COLDEST, BIOME_COLD, BIOME_WARM,
		BIOME_TEMPERATE, BIOME_HOT, BIOME_HOTTEST,
	)
	var/list/humidity_keys = list(
		BIOME_LOWEST_HUMIDITY, BIOME_LOW_HUMIDITY, BIOME_MEDIUM_HUMIDITY,
		BIOME_HIGH_HUMIDITY, BIOME_HIGHEST_HUMIDITY,
	)
	for(var/heat_key in heat_keys_surface)
		var/list/row = list()
		for(var/humidity_key in humidity_keys)
			var/biome_path = biome_table?[heat_key]?[humidity_key]
			row += biome_type_to_index[biome_path] || 0
		surface_indices += list(row)

	// 3. Build cave table (4 heat × 5 humidity)
	var/list/cave_indices = list()
	var/list/heat_keys_cave = list(
		BIOME_COLDEST_CAVE, BIOME_COLD_CAVE, BIOME_WARM_CAVE, BIOME_HOT_CAVE,
	)
	for(var/heat_key in heat_keys_cave)
		var/list/row = list()
		for(var/humidity_key in humidity_keys)
			var/biome_path = cave_biome_table?[heat_key]?[humidity_key]
			row += biome_type_to_index[biome_path] || 0
		cave_indices += list(row)

	// 4. Build final config and encode as JSON
	var/list/config = list(
		"width" = width,
		"height" = height,
		"seed" = seed,
		"mountain_height" = mountain_height,
		"perlin_zoom" = perlin_zoom,
		"ca_closed_chance" = initial_closed_chance,
		"ca_iterations" = smoothing_iterations,
		"ca_birth_limit" = birth_limit,
		"ca_death_limit" = death_limit,
		"surface_area" = "[primary_area_type]",
		"cave_area" = "[cave_area_type]",
		"biome_defs" = biome_defs,
		"surface_table" = surface_indices,
		"cave_table" = cave_indices,
		"z_levels" = z_levels,
	)
	return json_encode(config)

/**
 * Reads a biome type's definition and returns it as an associative list
 * suitable for JSON encoding.
 */
/datum/map_generator/planet_generator/proc/get_biome_def_json(biome_path)
	var/datum/biome/B = new biome_path

	var/list/flora_json = weights_from_expanded(B.flora_types)
	var/list/feature_json = weights_from_expanded(B.feature_types)
	var/list/fauna_json = weights_from_expanded(B.fauna_types)

	var/open_turf = B.open_turf_type
	var/closed_turf = B.closed_turf_type

	qdel(B)

	return list(
		"open_turf" = open_turf ? "[open_turf]" : "",
		"closed_turf" = closed_turf ? "[closed_turf]" : "",
		"flora_chance" = B.flora_density,
		"flora" = flora_json,
		"feature_chance" = B.feature_density,
		"features" = feature_json,
		"fauna_chance" = B.fauna_density,
		"fauna" = fauna_json,
		"mob_exclusion_radius" = B.mob_exclusion_radius,
		"feature_exclusion_radius" = B.feature_exclusion_radius,
	)

/**
 * Takes an expanded flat list (output of expand_weights) and reconstructs
 * a list of (path, weight) pairs by counting occurrences of each entry.
 */
/datum/map_generator/planet_generator/proc/weights_from_expanded(list/expanded)
	var/list/result = list()
	if(!length(expanded))
		return result

	var/list/path_counts = list()
	for(var/entry in expanded)
		path_counts[entry] = (path_counts[entry] || 0) + 1

	for(var/entry in path_counts)
		result += list(list(
			"path" = "[entry]",
			"weight" = path_counts[entry],
		))
	return result

/**
 * Creates docking ports for ship landing
 */
/datum/map_generator/planet_generator/proc/create_docking_ports(datum/virtual_level/vlevel, planet_name)
	var/list/docking_ports = list()

	#define LANDING_ZONE_WIDTH 20
	#define LANDING_ZONE_HEIGHT 20
	#define LANDING_ZONE_PADDING 5
	#define SHUTTLE_BOTTOM_CLEARANCE 5

	var/unreserved_start_x = vlevel.low_x + vlevel.reserved_margin
	var/unreserved_start_y = vlevel.low_y + vlevel.reserved_margin

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
	primary_dock.adjust_dock_for_landing = TRUE
	primary_dock.planet_generator = src
	docking_ports += primary_dock

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
	secondary_dock.adjust_dock_for_landing = TRUE
	secondary_dock.planet_generator = src
	docking_ports += secondary_dock

	if(vlevel.x_distance >= 150)
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
		tertiary_dock.adjust_dock_for_landing = TRUE
		tertiary_dock.planet_generator = src
		docking_ports += tertiary_dock

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
		quaternary_dock.adjust_dock_for_landing = TRUE
		quaternary_dock.planet_generator = src
		docking_ports += quaternary_dock

	#undef LANDING_ZONE_WIDTH
	#undef LANDING_ZONE_HEIGHT
	#undef LANDING_ZONE_PADDING
	#undef SHUTTLE_BOTTOM_CLEARANCE

	return docking_ports

/**
 * Get the appropriate biome for a turf based on perlin noise values
 */
/datum/map_generator/planet_generator/proc/get_biome(turf/target_turf)
	if(turf_biome_cache[target_turf])
		return turf_biome_cache[target_turf]

	var/drift_x = (target_turf.x + rand(-1, 1)) / perlin_zoom
	var/drift_y = (target_turf.y + rand(-1, 1)) / perlin_zoom

	var/height = text2num(rustg_noise_get_at_coordinates("[height_seed]", "[drift_x]", "[drift_y]"))
	var/heat = text2num(rustg_noise_get_at_coordinates("[heat_seed]", "[drift_x]", "[drift_y]"))
	var/humidity = text2num(rustg_noise_get_at_coordinates("[humidity_seed]", "[drift_x]", "[drift_y]"))

	var/is_cave = (mountain_height < 1) && (height > mountain_height)

	var/list/selected_table = is_cave ? cave_biome_table : biome_table
	if(!selected_table)
		log_world("ERROR: No biome table found for planet generator!")
		return null

	var/heat_level
	if(is_cave)
		if(heat < 0.25)
			heat_level = BIOME_COLDEST_CAVE
		else if(heat < 0.50)
			heat_level = BIOME_COLD_CAVE
		else if(heat < 0.75)
			heat_level = BIOME_WARM_CAVE
		else
			heat_level = BIOME_HOT_CAVE
	else
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

	var/biome_type = selected_table[heat_level]?[humidity_level]
	if(!biome_type)
		log_world("ERROR: No biome found for heat=[heat_level], humidity=[humidity_level]")
		return null

	var/datum/biome/selected_biome = new biome_type
	turf_biome_cache[target_turf] = selected_biome

	return selected_biome

/**
 * Override generate_terrain from parent class
 */
/datum/map_generator/planet_generator/generate_terrain(list/turfs, area/generate_in)
	if(!biome_table)
		log_world("ERROR: No biome table set for planet generator!")
		return

	var/list/biome_to_turfs = list()
	var/list/turf/surface_turfs = list()
	var/list/turf/cave_turfs = list()

	log_world("MAPGEN: Beginning biome selection for [length(turfs)] turfs...")

	for(var/turf/T as anything in turfs)
		var/datum/biome/selected_biome = get_biome(T)
		if(!selected_biome)
			continue

		var/drift_x = (T.x + rand(-1, 1)) / perlin_zoom
		var/drift_y = (T.y + rand(-1, 1)) / perlin_zoom
		var/height = text2num(rustg_noise_get_at_coordinates("[height_seed]", "[drift_x]", "[drift_y]"))

		if(mountain_height < 1 && height > mountain_height)
			cave_turfs += T
		else
			surface_turfs += T

		if(!biome_to_turfs[selected_biome])
			biome_to_turfs[selected_biome] = list()
		biome_to_turfs[selected_biome] += T

		CHECK_TICK

	log_world("MAPGEN: Found [length(biome_to_turfs)] unique biomes. Surface: [length(surface_turfs)], Caves: [length(cave_turfs)]")

	for(var/datum/biome/current_biome as anything in biome_to_turfs)
		var/list/turf/biome_turfs = biome_to_turfs[current_biome]
		log_world("MAPGEN: Generating [length(biome_turfs)] turfs for biome [current_biome.type]...")

		var/use_string = (istype(current_biome, /datum/biome/cave) && string_gen) ? string_gen : null
		var/list/turf/generated_turfs = current_biome.generate_turfs_for_terrain(biome_turfs, use_string)

		for(var/turf/new_turf as anything in generated_turfs)
			if(new_turf in cave_turfs)
				cave_area.contents += new_turf
			else
				primary_area.contents += new_turf
			CHECK_TICK

	log_world("MAPGEN: Terrain generation complete!")

/**
 * Override populate_terrain from parent class
 */
/datum/map_generator/planet_generator/populate_terrain(list/turfs, area/generate_in)
	var/flora_allowed = TRUE
	var/features_allowed = TRUE
	var/fauna_allowed = TRUE

	log_world("MAPGEN: Beginning population of [length(turfs)] turfs...")

	for(var/turf/target_turf as anything in turfs)
		var/datum/biome/turf_biome = turf_biome_cache[target_turf]
		if(!turf_biome)
			continue

		if(isclosedturf(target_turf))
			turf_biome.populate_turfs(target_turf, FALSE, features_allowed, FALSE)
			CHECK_TICK
			continue

		turf_biome.populate_turfs(target_turf, flora_allowed, features_allowed, fauna_allowed)
		CHECK_TICK

	log_world("MAPGEN: Population complete!")

/**
 * Smooth all generated turfs to fix borders and transitions
 */
/datum/map_generator/planet_generator/proc/smooth_generated_turfs(list/turf/turfs, z_level)
	log_world("MAPGEN: Beginning smoothing pass for [length(turfs)] turfs...")

	var/smoothed_count = 0
	for(var/turf/T as anything in turfs)
		if(T.smoothing_flags & (SMOOTH_BITMASK | SMOOTH_DIAGONAL_CORNERS))
			T.smooth_icon()
			smoothed_count++

			for(var/turf/adjacent in orange(1, T))
				if(adjacent.smoothing_flags & (SMOOTH_BITMASK | SMOOTH_DIAGONAL_CORNERS))
					adjacent.smooth_icon()

		CHECK_TICK

	log_world("MAPGEN: Smoothing complete! Smoothed [smoothed_count] turfs.")

// ============================================================================
// ATMOSPHERIC PROCESSING
// ============================================================================

#define PLANET_DEFAULT_ATMOS "o2=22;n2=82;TEMP=293.15"

/datum/map_generator/planet_generator/proc/override_turf_atmospheres(list/turf/turfs_to_process)
	if(!length(turfs_to_process))
		return

	for(var/turf/open/target_turf as anything in turfs_to_process)
		if(!istype(target_turf))
			continue

		if(!target_turf.planetary_atmos)
			continue

		target_turf.initial_gas_mix = PLANET_DEFAULT_ATMOS

		if(target_turf.air)
			target_turf.air = target_turf.create_gas_mixture()
