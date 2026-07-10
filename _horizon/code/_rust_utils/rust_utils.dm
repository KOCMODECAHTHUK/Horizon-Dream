#ifndef RUST_UTILS

/* This comment bypasses grep checks */ /var/__rust_utils

/proc/__detect_rust_utils()
	if(world.system_type == UNIX)
		if(fexists("./rust_utils.so"))
			// No need for LD_LIBRARY_PATH badness.
			return __rust_utils = "./rust_utils.so"
		else
			// It's not in the current directory, so try others
			return __rust_utils = "rust_utils.so"
	else
		return __rust_utils = "rust_utils"

#define RUST_UTILS (__rust_utils || __detect_rust_utils())
#endif

// Handle 515 call() -> call_ext() changes
#if DM_VERSION >= 515
#define RUST_UTILS_CALL call_ext
#else
#define RUST_UTILS_CALL call
#endif

/// Gets the version of rust_utils
/proc/rust_utils_get_version() return RUST_UTILS_CALL(RUST_UTILS, "get_version")()


/**
 * Generates a planet map as a valid DMM (TGM-format) string using cellular automata.
 *
 * Returns a complete DMM string that can be parsed by /datum/parsed_map.
 * The string contains two tile types (wall "a" and floor "b") arranged
 * using CA-smoothed cave generation.
 *
 * Arguments:
 * * width - Map width in turfs
 * * height - Map height in turfs
 * * seed - u64 seed for deterministic generation
 * * biome_type - Biome name (unused by Rust, reserved for future biome-specific turf selection)
 * * cave_chance - 0.0–1.0, probability of a cell starting as floor before CA smoothing
 * * wall_turf_path - Full DM path for wall turfs, e.g. "/turf/closed/wall/rock"
 * * floor_turf_path - Full DM path for floor turfs, e.g. "/turf/open/misc/asteroid/basalt"
 * * area_path - Full DM path for the area, e.g. "/area/planet/lava"
 */
#define rustg_planet_generator_generate_dmm(width, height, seed, planet_type, mountain_height, perlin_zoom, ca_closed_chance, ca_iterations, ca_birth_limit, ca_death_limit) \
	RUST_UTILS_CALL(RUST_UTILS, "planet_generator_generate_dmm")(width, height, seed, planet_type, mountain_height, perlin_zoom, ca_closed_chance, ca_iterations, ca_birth_limit, ca_death_limit)
