/**
  * ### Ion Engines
  * Engines that convert electricity to thrust. Yes, I know that's not how it works, it needs a propellant, but this is a video game.
  */
/obj/machinery/power/shuttle_engine/ship/electric
	name = "ion thruster"
	desc = "A thruster that expels charged particles to generate thrust."
	icon_state = "burst"
	circuit = /obj/item/circuitboard/machine/engine/electric
	engine_power = 10

	icon_state_off = "burst_off"
	icon_state_closed = "burst"
	icon_state_open = "burst_open"

	///Amount, in kilojoules, needed for a full burn.
	var/power_per_burn = 50000

/obj/machinery/power/shuttle_engine/ship/electric/Initialize()
	. = ..()

	if(anchored)
		connect_to_network()

/obj/machinery/power/shuttle_engine/ship/electric/update_engine()
	. = ..()
	if(!.)
		return FALSE
	thruster_active = !!powernet
	return thruster_active

/obj/machinery/power/shuttle_engine/ship/electric/on_construction()
	. = ..()
	connect_to_network()

/obj/machinery/power/shuttle_engine/ship/electric/burn_engine(percentage = 100)
	. = ..()
	var/true_percentage = min(newavail() / power_per_burn, percentage / 100)
	add_delayedload(power_per_burn * true_percentage)
	return engine_power * true_percentage

/obj/machinery/power/shuttle_engine/ship/electric/return_fuel()
	for(var/obj/machinery/power/smes/shuttle/engine_smes in powernet?.nodes)
		return engine_smes.get_charge()
	return newavail()

/obj/machinery/power/shuttle_engine/ship/electric/return_fuel_cap()
	for(var/obj/machinery/power/smes/shuttle/engine_smes in powernet.nodes)
		return engine_smes.get_capacity()
	return power_per_burn

/**
  * Проверяет, подключен ли движок к шаттловому СМЕСу.
  */
/obj/machinery/power/shuttle_engine/ship/electric/proc/has_smes()
	if(!powernet)
		return FALSE
	for(var/obj/machinery/power/smes/shuttle/engine_smes in powernet.nodes)
		return TRUE
	return FALSE

/**
  * ### Ion Engines
  * Engines that convert electricity to thrust. Yes, I know that's not how it works, it needs a propellant, but this is a video game.
  */

/obj/machinery/power/smes/shuttle
	name = "electric engine precharger"
	desc = "A medium-capacity, high transfer superconducting magnetic energy storage unit specially made for use with shuttle engines."
	icon = '_horizon/code/modules/shuttle/icons/smes_precharger.dmi'
	input_level_max = 50 KILO WATTS
	output_level = 10 KILO WATTS
	output_level_max = 50 KILO WATTS
	circuit = /obj/item/circuitboard/machine/smes/shuttle

/obj/machinery/power/smes/shuttle/precharged
	charge = 50 * STANDARD_BATTERY_CHARGE

/obj/item/circuitboard/machine/smes/shuttle
	name = "SMES"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/power/smes/shuttle
	req_components = list(
		/obj/item/stack/cable_coil = 5,
		/obj/item/stock_parts/power_store/battery = 5,
		/datum/stock_part/capacitor = 1)
	def_components = list(/obj/item/stock_parts/power_store/battery = /obj/item/stock_parts/power_store/battery/high/empty)

/obj/machinery/power/smes/shuttle/proc/get_charge()
	SHOULD_BE_PURE(TRUE)
	return total_charge()

/obj/machinery/power/smes/shuttle/proc/get_capacity()
	SHOULD_BE_PURE(TRUE)
	return total_capacity
