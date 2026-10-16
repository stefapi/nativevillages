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
-- (a variant is only added when it is actually registered). The
-- littoral suffixes (_shore/_ocean/_dunes/_beach) are reserved to the
-- water categories (see land_cats below): a land category claiming a
-- shore or ocean biome used to accept its sandy node_top as ground,
-- which pulled land buildings onto sea coasts (grassland_ocean
-- node_top being default:sand). Explicitly DECLARED names in the
-- fallback/known_mods tables below (mangrove_shore, mesa_beach ...)
-- keep being honoured: only the automatic expansion is restricted
local variants = {"_shore", "_ocean", "_under", "_dunes", "_beach"}

-- Categories whose buildings stand on dry land: for them the automatic
-- littoral expansion of add_with_variants AND the generic biome scan
-- below are disabled, so a land category can never claim a
-- _shore/_ocean/_dunes/_beach biome. lake keeps them by design
-- (minetest_game has no dedicated lake biome, its lake buildings spawn
-- on ocean shores), swamp hosts stilt houses on flooded shores, and
-- the arctic fallback still declares icesheet_ocean/tundra_ocean
-- explicitly: their frozen surface (snowblock node_top) is walkable
-- land for the sledges, not open water
local land_cats = {
    grassland = true, forest = true, jungle = true,
    savanna = true, desert = true, arctic = true,
}

-- True when a (lowercase) biome name ends with a littoral variant suffix
local function ends_with_littoral(lower)
    for v = 1, #variants do
        local suffix = variants[v]
        if lower:sub(-#suffix) == suffix then
            return true
        end
    end
    return false
end

-- Layer 0: guaranteed minetest_game fallbacks. Always kept, never replaced:
-- the mod works even without any optional biome mod installed.
local fallback = {
    -- grassland_dunes deliberately absent: a coastal dunes biome is a
    -- sand shore, grassland buildings have no business there (the
    -- deciduous_forest/savanna shores are covered by the lake category)
    grassland = {"grassland", "snowy_grassland"},
    forest = {"deciduous_forest"},
    jungle = {"rainforest", "rainforest_swamp"},
    savanna = {"savanna"},
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
        -- _dunes/_beach declinations. The littoral expansion is applied
        -- to the water categories only: a land category (land_cats)
        -- takes its declared biomes as is, so grassland, savanna, ...
        -- can never claim grassland_ocean, savanna_shore and friends
        local expand_littoral = not land_cats[cat]
        local function add_with_variants(root)
            add(root)
            if not expand_littoral then
                return
            end
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

        -- Layer 2: generic scan of all registered biomes. The littoral
        -- suffixed names are skipped for the land categories here too:
        -- grassland_ocean contains "grass" and would otherwise be
        -- scanned straight back into the grassland category
        local littoral_ok = not land_cats[cat]
        for name in pairs(registered) do
            local lower = string.lower(name)
            if littoral_ok or not ends_with_littoral(lower) then
                for p = 1, #scan_patterns do
                    if string.find(lower, scan_patterns[p][1], 1, true) then
                        if scan_patterns[p][2] == cat then
                            add(name)
                        end
                        break -- first matching pattern classifies the biome
                    end
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
