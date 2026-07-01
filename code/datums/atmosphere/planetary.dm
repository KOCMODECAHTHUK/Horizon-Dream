// Atmos types used for planetary airs
// Based on PentestSS13's planetary atmosphere system

/**
 * # Breathable Atmosphere (Earth-like)
 * Safe for humans, standard oxygen/nitrogen mix
 */
/datum/atmosphere/breathable
	id = "breathable"

	base_gases = list(
		/datum/gas/oxygen=21,
		/datum/gas/nitrogen=79,
	)
	normal_gases = list(
		/datum/gas/oxygen=1,
		/datum/gas/nitrogen=4,
		/datum/gas/carbon_dioxide=0.1,
	)
	restricted_gases = list(
		/datum/gas/water_vapor=0.5,
	)
	restricted_chance = 10

	minimum_pressure = ONE_ATMOSPHERE - 10
	maximum_pressure = ONE_ATMOSPHERE + 20

	minimum_temp = T20C - 10
	maximum_temp = T20C + 20

/**
 * # Hot Volcanic Atmosphere
 * High temperature, toxic gases, dangerous for unprotected humans
 */
/datum/atmosphere/lavaland
	id = LAVALAND_DEFAULT_ATMOS

	base_gases = list(
		/datum/gas/oxygen=5,
		/datum/gas/nitrogen=10,
		/datum/gas/carbon_dioxide=5,
	)
	normal_gases = list(
		/datum/gas/oxygen=5,
		/datum/gas/nitrogen=10,
		/datum/gas/carbon_dioxide=10,
	)
	restricted_gases = list(
		/datum/gas/plasma=0.5,
		/datum/gas/bz=0.2,
		/datum/gas/miasma=1.0,
		/datum/gas/water_vapor=0.1,
	)
	restricted_chance = 40

	minimum_pressure = HAZARD_LOW_PRESSURE + 10
	maximum_pressure = LAVALAND_EQUIPMENT_EFFECT_PRESSURE - 1

	minimum_temp = T20C + 60  // Hot but not instantly lethal
	maximum_temp = LAVALAND_MAX_TEMPERATURE

/**
 * # Frozen Ice World Atmosphere
 * Extremely cold, thin atmosphere
 */
/datum/atmosphere/icemoon
	id = ICEMOON_DEFAULT_ATMOS

	base_gases = list(
		/datum/gas/oxygen=5,
		/datum/gas/nitrogen=10,
	)
	normal_gases = list(
		/datum/gas/oxygen=10,
		/datum/gas/nitrogen=10,
		/datum/gas/carbon_dioxide=5,
	)
	restricted_gases = list(
		/datum/gas/plasma=0.1,
		/datum/gas/water_vapor=0.1,
		/datum/gas/miasma=0.5,
	)
	restricted_chance = 20

	minimum_pressure = HAZARD_LOW_PRESSURE + 10
	maximum_pressure = LAVALAND_EQUIPMENT_EFFECT_PRESSURE - 1

	minimum_temp = ICEBOX_MIN_TEMPERATURE - 100
	maximum_temp = BODYTEMP_COLD_DAMAGE_LIMIT - 20

/**
 * # Thin Rocky Planet Atmosphere
 * Low pressure, barely breathable, cold
 */
/datum/atmosphere/rocky
	id = "rocky_planet"

	base_gases = list(
		/datum/gas/oxygen=7,
		/datum/gas/nitrogen=15,
		/datum/gas/carbon_dioxide=3,
	)
	normal_gases = list(
		/datum/gas/oxygen=2,
		/datum/gas/nitrogen=5,
		/datum/gas/carbon_dioxide=2,
	)
	restricted_gases = list(
		/datum/gas/plasma=0.1,
	)
	restricted_chance = 15

	minimum_pressure = HAZARD_LOW_PRESSURE + 5
	maximum_pressure = ONE_ATMOSPHERE - 20

	minimum_temp = T20C - 40
	maximum_temp = T20C

/**
 * # Toxic Waste Atmosphere
 * Highly oxygenated but full of toxins and radiation
 */
/datum/atmosphere/toxic
	id = "toxic_waste"

	base_gases = list(
		/datum/gas/oxygen=15,
		/datum/gas/nitrogen=10,
	)
	normal_gases = list(
		/datum/gas/oxygen=10,
		/datum/gas/carbon_dioxide=5,
		/datum/gas/miasma=3,
	)
	restricted_gases = list(
		/datum/gas/plasma=1.0,
		/datum/gas/bz=0.5,
	)
	restricted_chance = 60

	minimum_pressure = ONE_ATMOSPHERE - 5
	maximum_pressure = ONE_ATMOSPHERE + 30

	minimum_temp = T20C - 20
	maximum_temp = T20C + 15

/**
 * # Hot Desert Atmosphere
 * Very hot, dry, low humidity
 */
/datum/atmosphere/desert
	id = "desert_hot"

	base_gases = list(
		/datum/gas/oxygen=18,
		/datum/gas/nitrogen=75,
	)
	normal_gases = list(
		/datum/gas/oxygen=2,
		/datum/gas/nitrogen=5,
		/datum/gas/carbon_dioxide=1,
	)
	restricted_gases = list(
		/datum/gas/water_vapor=0.05,  // Very dry
		/datum/gas/carbon_dioxide=0.5,  // Extra CO2
	)
	restricted_chance = 10

	minimum_pressure = ONE_ATMOSPHERE - 15
	maximum_pressure = ONE_ATMOSPHERE + 10

	minimum_temp = T20C + 30
	maximum_temp = T20C + 60

/**
 * # Jungle Planet Atmosphere
 * Humid, warm, high oxygen content
 */
/datum/atmosphere/jungle
	id = "jungle_humid"

	base_gases = list(
		/datum/gas/oxygen=23,
		/datum/gas/nitrogen=70,
		/datum/gas/carbon_dioxide=2,
	)
	normal_gases = list(
		/datum/gas/oxygen=2,
		/datum/gas/nitrogen=3,
		/datum/gas/carbon_dioxide=1,
	)
	restricted_gases = list(
		/datum/gas/water_vapor=2.0,  // Very humid
	)
	restricted_chance = 40

	minimum_pressure = ONE_ATMOSPHERE + 5
	maximum_pressure = ONE_ATMOSPHERE + 25

	minimum_temp = T20C + 10
	maximum_temp = T20C + 30

/**
 * # No Atmosphere (Airless)
 * Vacuum or near-vacuum conditions
 */
/datum/atmosphere/airless
	id = "airless"

	base_gases = list()
	normal_gases = list(
		/datum/gas/oxygen=0.01,  // Trace amounts
	)
	restricted_gases = list()
	restricted_chance = 0

	minimum_pressure = 0.1  // Near-vacuum, not true zero
	maximum_pressure = HAZARD_LOW_PRESSURE

	minimum_temp = TCMB  // Cosmic background temperature
	maximum_temp = T20C - 50
