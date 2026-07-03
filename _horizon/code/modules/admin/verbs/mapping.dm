#define SUB_ZONE_INFO_FULL(virtual_level) "[virtual_level.parent_map_zone.id]. [virtual_level.id]. [virtual_level.name]"
#define MAP_ZONE_INFO(map_zone) "[map_zone.id]. [map_zone.name]"

ADMIN_VERB_VISIBILITY(map_zones_info, ADMIN_VERB_VISIBLITY_FLAG_MAPPING_DEBUG)
ADMIN_VERB(map_zones_info, R_DEBUG, "Map-Zones Info", "Displays information about all map zones and virtual levels.", ADMIN_CATEGORY_MAPPING)
	var/list/dat = list()
	for(var/datum/map_zone/map_zone as anything in SSmapping.map_zones)
		dat += "[MAP_ZONE_INFO(map_zone)]:"
		for(var/datum/virtual_level/virtual_level as anything in map_zone.virtual_levels)
			dat += "<BR> - [MAP_ZONE_INFO(virtual_level)]:"
			var/turf/low_bound = locate(virtual_level.low_x, virtual_level.low_y, virtual_level.z_value)
			var/turf/high_bound = locate(virtual_level.high_x, virtual_level.high_y, virtual_level.z_value)
			dat += "<BR> -- Low bounds: [ADMIN_JMP(low_bound)], High bounds: [ADMIN_JMP(high_bound)]"
			dat += "<BR> -- Reservation: LowX: [virtual_level.low_x], LowY: [virtual_level.low_y], HighX: [virtual_level.high_x], HighY: [virtual_level.high_y]"
			dat += "<BR> -- Reserved Margin: [virtual_level.reserved_margin]"
			dat += "<BR> -- Traits: [json_encode(virtual_level.traits)]"
			if(length(virtual_level.crosslinked))
				dat += "<BR> -- Crosslinkage: (map zone ID, zone ID, name)"
				for(var/dir in virtual_level.crosslinked)
					var/datum/virtual_level/linked_zone = virtual_level.crosslinked[dir]
					var/dir_string
					//precompiler cant handle those for a switch
					if(dir == "[NORTH]")
						dir_string = "North"
					else if(dir == "[SOUTH]")
						dir_string = "South"
					else if(dir == "[WEST]")
						dir_string = "West"
					else if(dir == "[EAST]")
						dir_string = "East"
					var/zone_string
					if(linked_zone == virtual_level)
						zone_string = "SELF LINKED"
					else
						zone_string = SUB_ZONE_INFO_FULL(linked_zone)
					dat += "<BR> --- [dir_string]: [zone_string]"
			if(virtual_level.up_linkage)
				dat += "<BR> -- Up-linkage: [SUB_ZONE_INFO_FULL(virtual_level.up_linkage)]"
			if(virtual_level.down_linkage)
				dat += "<BR> -- Down-linkage: [SUB_ZONE_INFO_FULL(virtual_level.down_linkage)]"
		dat += "<HR>"
	dat += "Physical map dimensions: [world.maxx], [world.maxy], [world.maxz]"
	dat += "<BR>Physical levels:"
	for(var/z in 1 to SSmapping.z_list.len)
		var/datum/space_level/space_level = SSmapping.z_list[z]
		dat += "<BR> - [z]. [space_level.name]"
		if(length(space_level.virtual_levels))
			dat += "<BR> -- Contained virtual level reservations:"
			for(var/datum/virtual_level/virtual_level as anything in space_level.virtual_levels)
				dat += "<BR> --- [SUB_ZONE_INFO_FULL(virtual_level)]"
	var/datum/browser/popup = new(user.mob, "map zone debug", "Map-Zones info", 600, 600)
	popup.set_content(dat.Join())
	popup.open()

#undef SUB_ZONE_INFO_FULL
#undef MAP_ZONE_INFO
