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

/// Gets the version of rust_utils
/proc/rust_utils_get_version() return RUSTG_CALL(RUST_UTILS, "get_version")()


/**
 * Generates a planet map as a valid DMM (TGM-format) string using full
 * procedural generation: Perlin noise, cellular automata, biome selection,
 * flora/feature/fauna placement with exclusion radiuses.
 * All biome configs are passed as JSON from DM.
 *
 * Arguments:
 * * config_json - JSON string with all generation params and biome configs.
 *                 See /datum/map_generator/planet_generator/proc/build_biome_config_json()
 */
#define rustg_planet_generator_save_dmm(config_json, file_path) \
	RUSTG_CALL(RUST_UTILS, "planet_generator_save_dmm")(config_json, file_path)
