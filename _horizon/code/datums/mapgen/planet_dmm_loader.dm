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

	var/config_json = generator.build_biome_config_json(width, height, seed)
	var/file_name = "data/tmp/planet_[seed].dmm"
	if(fexists(file_name))
		fdel(file_name)

	var/result = rustg_planet_generator_save_dmm(config_json, file_name)
	if(result != "1")
		CRASH("generate_and_load_planet_dmm: rust-g failed to save DMM file: [result]")

	var/datum/map_template/template = new()
	template.name = "Planet [generator.type] #[seed]"
	template.mappath = file_name

	//template.should_place_on_top = FALSE
	if(!template.preload_size(template.mappath, TRUE))
		CRASH("generate_and_load_planet_dmm: failed to preload DMM file")

	var/list/bounds = template.load(target_turf, centered = FALSE)

	fdel(file_name)

	if(!bounds)
		CRASH("generate_and_load_planet_dmm: template.load() failed")

	var/list/turf/turfs_to_smooth = block(
		bounds[MAP_MINX], bounds[MAP_MINY], bounds[MAP_MINZ],
		bounds[MAP_MAXX], bounds[MAP_MAXY], bounds[MAP_MAXZ]
	)
	generator.smooth_generated_turfs(turfs_to_smooth, target_turf.z)
	generator.override_turf_atmospheres(turfs_to_smooth)

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
		list(ZTRAIT_MINING = TRUE, ZTRAIT_BASETURF = /turf/closed/void),
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

// MARK: Planet Debug

// ============================================================================
// PLANET GENERATION DEBUG TOOLS
// Генерирует Multi-Z DMM через Rust и корректно сохраняет в TGM формате.
// ============================================================================
/client/proc/debug_planet_generation()
	set name = "Debug Planet Generation"
	set category = "Debug"
	set desc = "Generate a planet DMM via Rust and save it to a file."

	if(!holder)
		return

	var/list/planet_types = list(
		"Lava" = /datum/map_generator/planet_generator/lava,
		"Ice" = /datum/map_generator/planet_generator/ice,
		"Jungle" = /datum/map_generator/planet_generator/jungle,
		"Rocky" = /datum/map_generator/planet_generator/rocky,
		"Desert" = /datum/map_generator/planet_generator/desert,
		"Beach" = /datum/map_generator/planet_generator/beach,
		"Grassland" = /datum/map_generator/planet_generator/grassland,
		"Wasteland" = /datum/map_generator/planet_generator/wasteland,
	)

	var/choice = input(src, "Выберите тип планеты:", "Debug Planet Gen") as null|anything in planet_types
	if(!choice) return

	var/planet_type = planet_types[choice]
	var/datum/map_generator/planet_generator/generator = new planet_type

	var/size = input(src, "Введите размер (ширина=высота):", "Debug Planet Gen", 50) as num
	if(!size || size < 10) return

	var/seed = input(src, "Введите сид (0 для случайного):", "Debug Planet Gen", 0) as num
	if(seed == 0) seed = rand(1, 999999)

	generator.dmm_seed = seed

	to_chat(src, "<span class='notice'>Генерация [size]x[size] (Сид: [seed])...</span>")
	var/config_json = generator.build_biome_config_json(size, size, seed)
	var/file_name = "data/debug_planet_[choice]_[seed].dmm"
	var/result = rustg_planet_generator_save_dmm(config_json, file_name)

	if(result == "1")
		to_chat(src, "<span class='green'>Успех! Карта сохранена: [file_name]</span>")
	else
		to_chat(src, "<span class='danger'>ОШИБКА: [result]</span>")

// MARK: Admin Verb

ADMIN_VERB(debug_planet_generation_admin, R_DEBUG, "Debug Planet Gen", "Generate a planet DMM via Rust, save to file, and load for preview.", ADMIN_CATEGORY_DEBUG)
	user.debug_planet_generation()
