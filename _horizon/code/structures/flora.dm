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
/* // TODO: Сделать при рубке листву
	RegisterSignal(src, COMSIG_ATOM_TAKE_DAMAGE, PROC_REF(fall_leaves))

/obj/structure/flora/tree/cherry/proc/fall_leaves()
	var/turf/T = get_turf(src)
	if(!T)
		return

	new /obj/effect/abstract/particle_holder(T, leaves_hit_particle_type, PARTICLE_FADEOUT|PARTICLE_FLICK)
	//shake_act(1)
*/
