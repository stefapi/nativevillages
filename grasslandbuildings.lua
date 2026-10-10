local S = minetest.get_translator("nativevillages")

-- Data driven definitions of the grassland buildings. Every entry is
-- passed to nativevillages.placement.register_building() (placement.lua),
-- which decides how the building is actually placed.

local buildings = {
    {
        name = "grasslandblot",
        schematic = "grasslandblot_30_180.mts",
        biomes = {"grassland", "forest"},
        offset = -29,
        y_max = 20.5,
        y_min = 15.5,
        fill_ratio = 0.00004,
    },
    {
        name = "grasslandchurch1",
        schematic = "church1.mts",
        biomes = {"grassland", "forest"},
        offset = -29,
        y_max = 20.5,
        y_min = 15.5,
        fill_ratio = 0.00004,
    },
    {
        name = "grasslandchurch2",
        schematic = "church2.mts",
        biomes = {"grassland", "forest"},
        offset = -29,
        y_max = 20.5,
        y_min = 15.5,
        fill_ratio = 0.00004,
    },
    {
        name = "grasslandhouse1",
        schematic = "grasslandhouse1_30_0.mts",
        biomes = {"grassland", "forest"},
        offset = -29,
        y_max = 20.5,
        y_min = 15.5,
        fill_ratio = 0.00005,
    },
    {
        name = "grasslandhouse2",
        schematic = "grasslandhouse2_30_0.mts",
        biomes = {"grassland", "forest"},
        offset = -29,
        y_max = 20.5,
        y_min = 15.5,
        fill_ratio = 0.00005,
    },
    {
        name = "grasslandhouse3",
        schematic = "grasslandhouse3_30_0.mts",
        biomes = {"grassland", "forest"},
        offset = -29,
        y_max = 20.5,
        y_min = 15.5,
        fill_ratio = 0.00005,
    },
    {
        name = "grasslandhouse4",
        schematic = "grasslandhouse4_30_0.mts",
        biomes = {"grassland", "forest"},
        offset = -29,
        y_max = 20.5,
        y_min = 15.5,
        fill_ratio = 0.00005,
    },
    {
        name = "grasslandhouse5",
        schematic = "grasslandhouse5_30_180.mts",
        biomes = {"grassland", "forest"},
        offset = -29,
        y_max = 20.5,
        y_min = 15.5,
        fill_ratio = 0.00005,
    },
    {
        name = "grasslandpond",
        schematic = "grasslandpond_30_180.mts",
        biomes = {"grassland", "forest"},
        offset = -29,
        y_max = 20.5,
        y_min = 15.5,
        fill_ratio = 0.00004,
    },
    {
        name = "grasslandstable",
        schematic = "grasslandstable_30_180.mts",
        biomes = {"grassland", "forest"},
        offset = -29,
        y_max = 20.5,
        y_min = 15.5,
        fill_ratio = 0.00004,
    },
}

for _, def in ipairs(buildings) do
    nativevillages.placement.register_building(def)
end

-- Swamp extension: the swamp category (swamp, swampz, alderswamp, bog,
-- mangrove, ... resolved by biomes.lua) otherwise has NO ground anchored
-- building at all -- only the two water anchored lake structures whose
-- bed must sit at y = -1 exactly, which never matches the terrestrial
-- swamps of the biome mods (swampz y 1-7, ethereal swamp y 1-7,
-- alderswamp y 0-5, ebiomes swamp y 1-8, swamp mod y -20..10). The
-- grassland family is re-registered for the swamps under its own
-- altitude band (0.5..10.5, the union of the swamp mod bands), so the
-- historical grassland/forest band 15.5..20.5 and its behaviour stay
-- untouched. The schematic ground is adapted to the swamp surface by
-- soil_replacement.lua (node_top of the actual biome: swamp grass,
-- silt, litter, ...), same as every other biome.
for _, def in ipairs(buildings) do
    -- register_building() rewrites def.schematic into an absolute path
    -- on the first pass above, so re-extract the bare file name here
    -- (it contains no "/" itself) to avoid prefixing the path twice
    nativevillages.placement.register_building({
        name = def.name .. "_swamp",
        schematic = def.schematic:match("[^/]+$"),
        biomes = {"swamp"},
        offset = def.offset,
        y_max = 10.5,
        y_min = 0.5,
        fill_ratio = def.fill_ratio,
    })
end
