// DCS - Signal (code/__DEFINES/dcs/signals/mapping.dm)
/// Sent when an atom's virtual_z changes : (new_virtual_z, old_virtual_z)
#define COMSIG_ATOM_VIRTUAL_Z_CHANGE "atom_virtual_z_change"


#define DEFAULT_SPACE_RUIN_LEVELS 0
#define DEFAULT_SPACE_EMPTY_LEVELS 0

// Heat categories for surface biomes (6 levels)
#define BIOME_COLDEST "coldest"        // 0.0-0.20
#define BIOME_COLD "cold"              // 0.20-0.40
#define BIOME_WARM "warm"              // 0.40-0.60
#define BIOME_TEMPERATE "temperate"    // 0.60-0.65
#define BIOME_HOT "hot"                // 0.65-0.80
#define BIOME_HOTTEST "hottest"        // 0.80-1.0

// Heat categories for cave biomes (4 levels)
#define BIOME_COLDEST_CAVE "coldest_cave"  // 0.0-0.25
#define BIOME_COLD_CAVE "cold_cave"        // 0.25-0.50
#define BIOME_WARM_CAVE "warm_cave"        // 0.50-0.75
#define BIOME_HOT_CAVE "hot_cave"          // 0.75-1.0

// Humidity categories (5 levels)
#define BIOME_LOWEST_HUMIDITY "lowest_humidity"     // 0.0-0.20
#define BIOME_LOW_HUMIDITY "low_humidity"           // 0.20-0.40
#define BIOME_MEDIUM_HUMIDITY "medium_humidity"     // 0.40-0.60
#define BIOME_HIGH_HUMIDITY "high_humidity"         // 0.60-0.80
#define BIOME_HIGHEST_HUMIDITY "highest_humidity"   // 0.80-1.0

// Virtual z-level allocation types
/// Free allocation - places virtual levels anywhere there's free space
#define ALLOCATION_FREE "free"
/// Quadrant allocation - divides physical z-levels into 4 quadrants
#define ALLOCATION_QUADRANT "quadrant"
/// Octant allocation - divides physical z-levels into 8 sections
#define ALLOCATION_OCTODRANT "octodrant"

// Virtual z-level allocation sizes
/// Default allocation jump size
#define DEFAULT_ALLOC_JUMP 5
/// Size of quadrant splitting
#define QUADRANT_MAP_SIZE 127
/// Border size for quadrant maps
#define QUADRANT_SIZE_BORDER 10
/// Size of octodrant maps
#define OCTODRANT_MAP_SIZE 63
