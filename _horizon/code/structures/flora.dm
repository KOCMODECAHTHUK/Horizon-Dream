/obj/structure/flora/tree/cherry
	name = "cherry tree"
	desc = "A cherry tree that has been bio-engineered to keep its pink flowers year-round."
	icon = '_horizon/icons/obj/flora/cherry.dmi'
	icon_state = "cherry"
	pixel_x = -68
	pixel_y = -20

	var/leaves_particle_type = /particles/leaves/cherry
	var/leaves_hit_particle_type = /particles/leaves/cherry/hit

/obj/structure/flora/cherry_leaf
	name = "cherry leaf"
	desc = "The beautiful pink leaves of a cherry tree."
	icon = '_horizon/icons/obj/flora/cherry.dmi'
	icon_state = "cherry_leaf"
	plane = FLOOR_PLANE
	layer = TURF_DECAL_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	pixel_x = -68
	pixel_y = -20

// Lazy method rotate and pixel shifting
/obj/structure/flora/tree/cherry/Initialize(mapload)
	. = ..()
	var/obj/structure/flora/cherry_leaf/leaf = new(loc)
	if(dir > SOUTH)
		pixel_x = -28
		leaf.pixel_x = -28
		leaf.setDir(dir)

	new /obj/effect/abstract/particle_holder(src, leaves_particle_type, PARTICLE_FADEOUT)

	var/atom/movable/tree_shadow/shadow = new(null, src)
	shadow.icon = icon
	vis_contents += shadow

/atom/movable/tree_shadow
	name = "shadow"
	icon_state = "shadow"
	anchored = TRUE
	plane = WALL_PLANE
	layer = BELOW_CLOSED_TURF_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	vis_flags = VIS_INHERIT_DIR
	var/parent

/atom/movable/tree_shadow/Initialize(mapload, parent)
	. = ..()
	src.parent = parent
	RegisterSignal(parent, COMSIG_QDELETING, PROC_REF(parent_destroy))

/atom/movable/tree_shadow/proc/parent_destroy()
    Destroy()
