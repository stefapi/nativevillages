-- Central biome resolution layer for nativevillages.
-- Maps logical categories (grassland, forest, jungle, savanna, desert,
-- arctic, lake, swamp) onto the biomes actually registered in-game so that
-- buildings (and later creatures) appear in every compatible biome,
-- including those added by optional biome mods.
-- Reference design: plans/compatibilite-biomes-architecture.md

nativevillages = nativevillages or {}

local B = {}
nativevillages.biomes = B

-- Logical categories in stable priority order (a biome claimed by several
-- categories is reported as the earliest one by category_of)
local categories = {
    "grassland", "forest", "jungle", "savanna", "desert", "arctic", "lake", "swamp",
}

-- Variant suffixes automatically appended to every declared root biome
-- (a variant is only added when it is actually registered)
local variants = {"_shore", "_ocean", "_under", "_dunes", "_beach"}

-- Layer 0: guaranteed minetest_game fallbacks. Always kept, never replaced:
-- the mod works even without any optional biome mod installed.
local fallback = {
    grassland = {"grassland", "grassland_dunes", "snowy_grassland"},
    forest = {"deciduous_forest"}, -- + _shore/_ocean via variant expansion
    jungle = {"rainforest", "rainforest_swamp"},
    savanna = {"savanna"}, -- + _shore via variant expansion
    desert = {"desert", "sandstone_desert", "cold_desert"},
    arctic = {"icesheet", "icesheet_ocean", "tundra", "tundra_ocean", "tundra_highland"},
    lake = {"deciduous_forest_ocean", "deciduous_forest_shore", "coniferous_forest_ocean", "grassland_ocean"},
    swamp = {}, -- none in pure minetest_game, optional mods only
}

-- Layer 1: static tables per known optional biome mod, only applied when the
-- mod is installed (minetest.get_modpath). Names follow the architecture plan.
local known_mods = {
    ethereal = {
        grassland = {"grassytwo", "prairie", "plains", "jumble", "mediterranean", "grove"},
        forest = {"deciduous_forest", "tawny_woods", "magical_forest", "coniferous_forest"},
        jungle = {"bamboo", "mangrove", "mangrove_shore"},
        savanna = {"savanna_shore"}, -- "savanna" itself is re-registered by ethereal
        desert = {"mesa", "mesa_beach", "fiery", "fiery_beach", "sandstone_desert", "cold_desert"},
        arctic = {"frost", "frost_floatland", "glacier", "snowy_grassland"}, -- icesheet* already in fallback
        swamp = {"swamp", "swamp_beach", "grayness"},
    },
    ebiomes = {
        grassland = {"grassland_arid", "grassland_arid_cool", "grassland_coldish", "grassland_warm", "steppe", "warm_steppe", "cold_steppe", "mediterranean"},
        forest = {"deciduous_forest_cold", "deciduous_forest_warm", "deciduous_forest_fruity", "deciduous_forest_woody", "temperate_rainforest", "japanese_rainforest"},
        jungle = {"japanese_rainforest", "jungle_savanna"},
        savanna = {"humid_savanna", "jungle_savanna"},
        arctic = {"snowy_grassland"},
        swamp = {"swamp", "bog"},
    },
    naturalbiomes = {
        grassland = {"naturalbiomes:bushland", "naturalbiomes:heath", "naturalbiomes:outback", "naturalbiomes:mediterranean"},
        forest = {"naturalbiomes:alpine"},
        jungle = {"bambooforest"},
        savanna = {"naturalbiomes:wetsavanna"},
        swamp = {"naturalbiomes:alderswamp"},
        lake = {"naturalbiomes:palmbeach"}, -- beach/shore biome, classified lake (not desert)
    },
    biomes = { -- modpack: also detected through its registered biome names
        grassland = {"prairie", "nightshade", "dorwinion"},
        jungle = {"bamboo_forest", "japanese_forest"},
        arctic = {"frost_land"},
        desert = {"badland", "terracotta"},
    },
    badlands = {
        desert = {"badlands"},
    },
    swamp = {
        swamp = {"swamp"},
    },
    swaz = {
        swamp = {"swaz"},
    },
}

-- Layer 2: generic name-pattern scan over all registered biomes, for biome
-- mods that are not covered above. Order matters: the first matching
-- pattern classifies the biome.
local scan_patterns = {
    {"sand", "desert"},
    {"desert", "desert"}, -- complements "sand" for names like cold_desert
    {"savanna", "savanna"},
    {"snow", "arctic"},
    {"ice", "arctic"},
    {"frost", "arctic"},
    {"tundra", "arctic"},
    {"glacier", "arctic"},
    {"arctic", "arctic"},
    {"swamp", "swamp"},
    {"bog", "swamp"},
    {"marsh", "swamp"},
    {"mangrove", "swamp"},
    {"rainforest", "jungle"},
    {"jungle", "jungle"},
    {"grass", "grassland"},
    {"plain", "grassland"},
    {"prairie", "grassland"},
    {"meadow", "grassland"},
    {"steppe", "grassland"},
    {"forest", "forest"},
    {"woods", "forest"},
}

-- Ground nodes always accepted for each category; the node_top of every
-- resolved registered biome is added on top of these by get_ground()
local ground_base = {
    grassland = {"default:dirt_with_grass"},
    forest = {"default:dirt_with_grass"},
    jungle = {"default:dirt_with_rainforest_litter"},
    savanna = {"default:dry_dirt_with_dry_grass"},
    desert = {"default:desert_sand"},
    arctic = {"default:snowblock", "default:ice", "default:permafrost"},
    lake = {"default:dirt", "default:sand"},
    swamp = {"default:dirt", "default:dirt_with_grass"},
}

local biome_cache = {}   -- category -> list of biome names
local ground_cache = {}  -- category -> list of ground node names
local reverse_index = {} -- biome name -> category
local resolved = false

local function mod_is_active(mod, tbl)
    if minetest.get_modpath(mod) then
        return true
    end
    -- the "biomes" modpack has no loadable mod entry of its own, so also
    -- detect it through any of its biome names already registered
    if mod == "biomes" then
        for _, names in pairs(tbl) do
            for _, name in ipairs(names) do
                if minetest.registered_biomes[name] then
                    return true
                end
            end
        end
    end
    return false
end

-- Lazy one-shot resolution (three layers, union, deduplicated)
local function resolve()
    if resolved then
        return
    end
    resolved = true

    local registered = minetest.registered_biomes or {}

    for c = 1, #categories do
        local cat = categories[c]
        local set, list = {}, {}

        local function add(name)
            if name and name ~= "" and not set[name] then
                set[name] = true
                list[#list + 1] = name
            end
        end

        -- a declared root biome plus its registered _shore/_ocean/_under/
        -- _dunes/_beach declinations
        local function add_with_variants(root)
            add(root)
            for v = 1, #variants do
                local name = root .. variants[v]
                if registered[name] then
                    add(name)
                end
            end
        end

        -- Layer 0: guaranteed minetest_game fallback
        for _, root in ipairs(fallback[cat] or {}) do
            add_with_variants(root)
        end

        -- Layer 1: static tables of the known optional mods
        for mod, tbl in pairs(known_mods) do
            if tbl[cat] and mod_is_active(mod, tbl) then
                for _, root in ipairs(tbl[cat]) do
                    add_with_variants(root)
                end
            end
        end

        -- Layer 2: generic scan of all registered biomes
        for name in pairs(registered) do
            local lower = string.lower(name)
            for p = 1, #scan_patterns do
                if string.find(lower, scan_patterns[p][1], 1, true) then
                    if scan_patterns[p][2] == cat then
                        add(name)
                    end
                    break -- first matching pattern classifies the biome
                end
            end
        end

        if #list == 0 then
            minetest.log("info", "[nativevillages] biome category '" .. cat
                .. "' is empty (no compatible biome registered)")
        end

        biome_cache[cat] = list
    end

    -- reverse index, earliest category wins
    for c = 1, #categories do
        local cat = categories[c]
        for _, name in ipairs(biome_cache[cat]) do
            if reverse_index[name] == nil then
                reverse_index[name] = cat
            end
        end
    end
end

-- Ground nodes of a category: base nodes plus the node_top of every
-- resolved biome actually registered (robust against unknown mods)
local function ground_of(cat)
    if not ground_cache[cat] then
        local set, list = {}, {}

        local function add(node)
            if node and node ~= "" and node ~= "air" and not set[node] then
                set[node] = true
                list[#list + 1] = node
            end
        end

        for _, node in ipairs(ground_base[cat] or {}) do
            add(node)
        end

        for _, name in ipairs(biome_cache[cat] or {}) do
            local def = minetest.registered_biomes[name]
            if def and def.node_top then
                add(def.node_top)
            end
        end

        ground_cache[cat] = list
    end
    return ground_cache[cat]
end

-- Union (deduplicated) of the resolved biomes of one or more categories.
-- Never empty for the categories used by the buildings thanks to the
-- minetest_game fallbacks of layer 0.
function B.get(...)
    resolve()
    local set, list = {}, {}
    for i = 1, select("#", ...) do
        for _, name in ipairs(biome_cache[select(i, ...)] or {}) do
            if not set[name] then
                set[name] = true
                list[#list + 1] = name
            end
        end
    end
    if #list == 0 then
        local asked = {}
        for i = 1, select("#", ...) do
            asked[#asked + 1] = tostring(select(i, ...))
        end
        minetest.log("warning", "[nativevillages] biomes.get(" .. table.concat(asked, ", ")
            .. ") resolved an empty biome list")
    end
    return list
end

-- Union (deduplicated) of the ground nodes of one or more categories,
-- for place_on / mobs:spawn nodes
function B.get_ground(...)
    resolve()
    local set, list = {}, {}
    for i = 1, select("#", ...) do
        for _, node in ipairs(ground_of(select(i, ...))) do
            if not set[node] then
                set[node] = true
                list[#list + 1] = node
            end
        end
    end
    return list
end

-- Reverse lookup: logical category of a real biome name (nil if unknown)
function B.category_of(name)
    resolve()
    return reverse_index[name]
end

-- Log every resolution (called automatically once all mods are loaded when
-- the nativevillages.debug_biomes setting is enabled)
function B.debug()
    resolve()
    for c = 1, #categories do
        local cat = categories[c]
        minetest.log("action", "[nativevillages] biomes." .. cat .. ": "
            .. table.concat(biome_cache[cat], ", "))
        minetest.log("action", "[nativevillages] grounds." .. cat .. ": "
            .. table.concat(ground_of(cat), ", "))
    end
end

minetest.register_on_mods_loaded(function()
    if minetest.settings:get_bool("nativevillages.debug_biomes", false) then
        B.debug()
    end
end)
