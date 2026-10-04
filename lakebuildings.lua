local S = minetest.get_translator("nativevillages")

minetest.register_decoration({
    name = "nativevillages:lakehouse1",
    deco_type = "schematic",
    place_on = nativevillages.biomes.get_ground("lake"),
    place_offset_y = 0,
    sidelen = 16,
    fill_ratio = 0.00005,
    biomes = nativevillages.biomes.get("lake"),
    y_max = -0.5,
    y_min = -0.5,
    schematic = minetest.get_modpath("nativevillages").."/schematics/lakehouse1_0_0.mts",
    flags = "force_placement",
    rotation = "random",
})

minetest.register_decoration({
    name = "nativevillages:lakehouse2",
    deco_type = "schematic",
    place_on = nativevillages.biomes.get_ground("lake"),
    place_offset_y = 0,
    sidelen = 16,
    fill_ratio = 0.00005,
    biomes = nativevillages.biomes.get("lake"),
    y_max = -0.5,
    y_min = -0.5,
    schematic = minetest.get_modpath("nativevillages").."/schematics/lakehouse2_0_0.mts",
    flags = "force_placement",
    rotation = "random",
})

minetest.register_decoration({
    name = "nativevillages:lakehouse3",
    deco_type = "schematic",
    place_on = nativevillages.biomes.get_ground("lake"),
    place_offset_y = 0,
    sidelen = 16,
    fill_ratio = 0.00005,
    biomes = nativevillages.biomes.get("lake"),
    y_max = -0.5,
    y_min = -0.5,
    schematic = minetest.get_modpath("nativevillages").."/schematics/lakehouse3_0_0.mts",
    flags = "force_placement",
    rotation = "random",
})

minetest.register_decoration({
    name = "nativevillages:lakehouse4",
    deco_type = "schematic",
    place_on = nativevillages.biomes.get_ground("lake"),
    place_offset_y = 0,
    sidelen = 16,
    fill_ratio = 0.00005,
    biomes = nativevillages.biomes.get("lake"),
    y_max = -0.5,
    y_min = -0.5,
    schematic = minetest.get_modpath("nativevillages").."/schematics/lakehouse4_0_0.mts",
    flags = "force_placement",
    rotation = "random",
})

minetest.register_decoration({
    name = "nativevillages:lakefishtrap",
    deco_type = "schematic",
    place_on = nativevillages.biomes.get_ground("lake", "swamp"),
    place_offset_y = 0,
    sidelen = 16,
    fill_ratio = 0.00003,
    biomes = nativevillages.biomes.get("lake", "swamp"),
    y_max = -0.5,
    y_min = -0.5,
    schematic = minetest.get_modpath("nativevillages").."/schematics/lakefishtrap_0_0.mts",
    flags = "force_placement",
    rotation = "random",
})

minetest.register_decoration({
    name = "nativevillages:lakeharbour",
    deco_type = "schematic",
    place_on = nativevillages.biomes.get_ground("lake", "swamp"),
    place_offset_y = 0,
    sidelen = 16,
    fill_ratio = 0.00003,
    biomes = nativevillages.biomes.get("lake", "swamp"),
    y_max = -0.5,
    y_min = -0.5,
    schematic = minetest.get_modpath("nativevillages").."/schematics/lakeharbour_0_0.mts",
    flags = "force_placement",
    rotation = "random",
})
