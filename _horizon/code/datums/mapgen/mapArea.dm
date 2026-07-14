
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
