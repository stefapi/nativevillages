local S = minetest.get_translator("nativevillages")

-- Data driven definitions of the savanna buildings. Every entry is
-- passed to nativevillages.placement.register_building() (placement.lua),
-- which decides how the building is actually placed.

local buildings = {
    {
        name = "savannahouse1",
        schematic = "savannahouse1_30_0.mts",
        biomes = {"savanna"},
        offset = -29,
        y_max = 15.5,
        y_min = 10.5,
        fill_ratio = 0.00005,
    },
    {
        name = "savannahouse2",
        schematic = "savannahouse2_30_0.mts",
        biomes = {"savanna"},
        offset = -29,
        y_max = 15.5,
        y_min = 10.5,
        fill_ratio = 0.00005,
    },
    {
        name = "savannahouse3",
        schematic = "savannahouse3_30_0.mts",
        biomes = {"savanna"},
        offset = -29,
        y_max = 15.5,
        y_min = 10.5,
        fill_ratio = 0.00005,
    },
    {
        name = "savannawitchhouse",
        schematic = "savannawitchhouse_30_0.mts",
        biomes = {"savanna"},
        offset = -29,
        y_max = 15.5,
        y_min = 10.5,
        fill_ratio = 0.00003,
    },
    {
        name = "savannawell",
        schematic = "savannawell_30_180.mts",
        biomes = {"savanna"},
        offset = -29,
        y_max = 15.5,
        y_min = 10.5,
        fill_ratio = 0.00003,
    },
    {
        name = "savannastable",
        schematic = "savannastable_30_180.mts",
        biomes = {"savanna"},
        offset = -29,
        y_max = 15.5,
        y_min = 10.5,
        fill_ratio = 0.00003,
    },
    {
        name = "savannapond",
        schematic = "savannapond_30_180.mts",
        biomes = {"savanna"},
        offset = -29,
        y_max = 15.5,
        y_min = 10.5,
        fill_ratio = 0.00003,
    },
    {
        name = "savannalogs",
        schematic = "savannalogs_30_180.mts",
        biomes = {"savanna"},
        offset = -29,
        y_max = 15.5,
        y_min = 10.5,
        fill_ratio = 0.00003,
    },
}

for _, def in ipairs(buildings) do
    nativevillages.placement.register_building(def)
end
