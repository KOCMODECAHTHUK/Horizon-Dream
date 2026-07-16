/**
 * # Planet DMM Loader
 *
 * Standalone utility procs for generating and loading planet maps via rust-g.
 * The main planet generation path goes through /datum/map_generator/planet_generator,
 * but these procs are useful for testing and ad-hoc planet creation.
 *
 * All biome configs are serialized from DM-side biome tables into a JSON string
 * and passed to Rust — nothing is hardcoded in the library.
 */

// ─── Map Template Subtype ──────────────────────────────────────────────────────

/// A /datum/map_template that loads from a raw DMM string instead of a file.
/// /datum/parsed_map accepts raw text in New(), so we bypass the file system entirely.
/datum/map_template/planet_dmm
	/// Keep the parsed map cached so we can load the same template multiple times.
	keep_cached_map = TRUE

/datum/map_template/planet_dmm/New(dmm_string, map_name = "Generated Planet")
	. = ..()
	name = map_name
	// /datum/parsed_map/New() accepts raw text — if the argument is not a file
	// and not null, it is treated as the map text directly.
	cached_map = new /datum/parsed_map(dmm_string)
	var/list/bounds = cached_map?.bounds
	if(bounds)
		width = bounds[MAP_MAXX]
		height = bounds[MAP_MAXY]

// ─── Public API ────────────────────────────────────────────────────────────────

/**
 * Generate a planet map using a planet generator datum and load it into the
 * world at a target turf.
 *
 * All Perlin noise, CA, biome selection, turf placement, and flora spawning
 * is done in Rust. DM serializes the biome tables to JSON and passes it.
 *
 * Arguments:
 * * generator - The /datum/map_generator/planet_generator (or subtype) with biome tables set
 * * width - Map width in turfs
 * * height - Map height in turfs
 * * seed - Numeric seed for deterministic generation
 * * target_turf - The bottom-left turf where the map will be placed
 *
 * Returns: /datum/map_template/planet_dmm if successful, null otherwise
 */
/proc/generate_and_load_planet_dmm(datum/map_generator/planet_generator/generator, width, height, seed, turf/target_turf)
	if(!target_turf)
		CRASH("generate_and_load_planet_dmm: target_turf is null")
	if(!generator)
		CRASH("generate_and_load_planet_dmm: generator is null")

	// Build JSON config from the generator's biome tables
	var/config_json = generator.build_biome_config_json(width, height, seed)

	// Call rust-g to generate the complete DMM string
	var/dmm_string = rustg_planet_generator_generate_dmm(config_json)

	if(!dmm_string)
		CRASH("generate_and_load_planet_dmm: rust-g returned empty string")

	// Create a map template directly from the DMM string (no file I/O needed)
	var/datum/map_template/planet_dmm/template = new(dmm_string, "Planet [generator.type] #[seed]")

	if(!template.cached_map || !template.cached_map.bounds)
		CRASH("generate_and_load_planet_dmm: failed to parse DMM string")

	// Load the template at the target turf — this places all turfs/areas/objects
	var/result = template.load(target_turf)
	if(!result)
		CRASH("generate_and_load_planet_dmm: template.load() failed")

	log_game("Planet DMM loaded: [generator.type] [width]x[height] at [target_turf.x],[target_turf.y],[target_turf.z]")
	return template

/**
 * Generate a planet map and load it into a new virtual level.
 *
 * Creates a new map_zone and virtual_level, then loads the generated DMM map
 * into the unreserved area of that level. Useful for creating standalone planet
 * Z-levels (e.g. for supercruise arrival).
 *
 * Arguments:
 * * generator - The /datum/map_generator/planet_generator (or subtype) with biome tables set
 * * planet_name - Name for the planet (used for zone/vlevel naming)
 * * width - Map width in turfs
 * * height - Map height in turfs
 * * seed - Numeric seed for deterministic generation
 *
 * Returns: list(vlevel, template) if successful, null otherwise
 */
/proc/generate_planet_on_new_level(datum/map_generator/planet_generator/generator, planet_name = "Planet", width = 50, height = 50, seed)
	if(!generator)
		CRASH("generate_planet_on_new_level: generator is null")

	// Create a map zone and virtual level for this planet
	var/datum/map_zone/mapzone = SSmapping.create_map_zone("[planet_name] Zone")
	if(!mapzone)
		CRASH("generate_planet_on_new_level: failed to create map zone")

	var/total_size = width + 2 // margin for borders
	var/datum/virtual_level/vlevel = SSmapping.create_planet_vlevel(
		planet_name,
		list(ZTRAIT_MINING = TRUE, ZTRAIT_BASETURF = /turf/open/space/basic),
		mapzone,
		total_size,
		total_size
	)
	if(!vlevel)
		CRASH("generate_planet_on_new_level: failed to create virtual level")

	// Reserve a 1-tile margin for indestructible borders
	vlevel.reserve_margin(1)

	// Get the bottom-left turf of the unreserved area
	var/turf/load_turf = vlevel.get_unreserved_bottom_left_turf()
	if(!load_turf)
		CRASH("generate_planet_on_new_level: no unreserved turfs available")

	// Generate and load the planet DMM at the target turf
	var/datum/map_template/planet_dmm/template = generate_and_load_planet_dmm(generator, width, height, seed, load_turf)

	if(!template)
		CRASH("generate_planet_on_new_level: planet DMM generation failed")

	log_game("Planet [planet_name] created on new virtual level [vlevel.id] at [load_turf.x],[load_turf.y],[vlevel.z_value]")
	return list(vlevel, template)
