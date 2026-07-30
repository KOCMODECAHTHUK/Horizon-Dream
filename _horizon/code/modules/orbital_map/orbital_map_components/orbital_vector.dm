//Orbital vectors
//I hate that some of these modify src and the others just return a valid
// - bacon

/datum/orbital_vector
	var/x = 0
	var/y = 0
	var/z = 0

/datum/orbital_vector/New(_x = 0, _y = 0, _z = 0)
	. = ..()
	x = _x
	y = _y
	z = _z

/datum/orbital_vector/proc/Copy()
	return new /datum/orbital_vector(x, y, z)

/datum/orbital_vector/proc/Set(_x = 0, _y = 0, _z = 0)
	x = _x
	y = _y
	z = _z
	return src

//Returns a new vector equal to the current vector + other
/datum/orbital_vector/proc/Add(datum/orbital_vector/other)
	return new /datum/orbital_vector(x + other.x, y + other.y, z + other.z)

//Returns a new vector equal to the current vector * scalar_amount
/datum/orbital_vector/proc/Scale(scalar_amount)
	return new /datum/orbital_vector(x * scalar_amount, y * scalar_amount, z * scalar_amount)

//Adds the other vector to our current vector.
/datum/orbital_vector/proc/AddSelf(datum/orbital_vector/other)
	src.x += other.x
	src.y += other.y
	src.z += other.z
	return src

//Scales our current vector by a scalar amount
/datum/orbital_vector/proc/ScaleSelf(scalar_amount)
	x *= scalar_amount
	y *= scalar_amount
	z *= scalar_amount
	return src

//Returns magnitude of the vector
/datum/orbital_vector/proc/Length()
	return sqrt(x * x + y * y + z * z)

//Returns distanace between 2 positional vectors
/datum/orbital_vector/proc/DistanceTo(datum/orbital_vector/other)
	var/delta_x = other.x - x
	var/delta_y = other.y - y
	var/delta_z = other.z - z
	return sqrt(delta_x * delta_x + delta_y * delta_y + delta_z * delta_z)

//Assuming we are a position vector
//Takes in position and direction of a line.
/datum/orbital_vector/proc/ShortestDistanceToLine(datum/orbital_vector/position, datum/orbital_vector/direction)
	if(!direction.x && !direction.y && !direction.z)
		return INFINITY
	if(!x && !y && !z)
		x = 1
		y = 1
	var/lambda = (x * x + y * y - position.x * x - position.y * y) / (direction.x * x + direction.y * y)
	var/datum/orbital_vector/closestPoint = new(position.x + direction.x * lambda, position.y + direction.y * lambda)
	return closestPoint.DistanceTo(src)

/datum/orbital_vector/proc/Subtract(datum/orbital_vector/other)
	return new /datum/orbital_vector(x - other.x, y - other.y, z - other.z)

/datum/orbital_vector/proc/Dot(datum/orbital_vector/other)
	return (x * other.x) + (y * other.y) + (z * other.z)

/datum/orbital_vector/proc/Cross(datum/orbital_vector/other)
	return new /datum/orbital_vector(
		(y * other.z) - (z * other.y),
		(z * other.x) - (x * other.z),
		(x * other.y) - (y * other.x)
	)

/datum/orbital_vector/proc/GetNormalized()
	var/len = Length()
	if(!len)
		return new /datum/orbital_vector()
	return new /datum/orbital_vector(x / len, y / len, z / len)

/datum/orbital_vector/proc/Reflect(datum/orbital_vector/normal)
	var/dp = Dot(normal) * 2
	return Subtract(normal.Scale(dp))

/datum/orbital_vector/proc/Project(datum/orbital_vector/onto)
	var/len_sq = onto.Dot(onto)
	if(len_sq < 0.0001) return new /datum/orbital_vector()
	return onto.Scale(Dot(onto) / len_sq)

/datum/orbital_vector/proc/Reject(datum/orbital_vector/from)
	var/datum/orbital_vector/proj = Project(from)
	return Subtract(proj)

/datum/orbital_vector/proc/AngleBetween(datum/orbital_vector/other)
	var/len_prod = Length() * other.Length()
	if(len_prod < 0.0001) return 0
	return arccos(clamp(Dot(other) / len_prod, -1, 1))

/datum/orbital_vector/proc/Lerp(datum/orbital_vector/target, t)
	var/inv = 1 - t
	return new /datum/orbital_vector(x * inv + target.x * t, y * inv + target.y * t, z * inv + target.z * t)

/datum/orbital_vector/proc/IsZero()
	return abs(x) < 0.0001 && abs(y) < 0.0001 && abs(z) < 0.0001
