-- Optional multidimensions integration for nativevillages.
--
-- When the optional multidimensions mod is installed, the villages and
-- scattered houses of this mod also generate inside the eligible
-- dimensions (whitelist CONFIG below, plus a ground node heuristic for
-- third party dimensions). Without multidimensions, or when the master
-- setting is disabled, this module is a complete silent no-op, the
-- dungeon_entrances.lua convention: only the installed flag is probed
-- at load time, the multidimensions TABLE itself is resolved lazily in
-- register_on_mods_loaded because the mod load order is not guaranteed.
--
-- Core principle: in a dimension, NOTHING is decided synchronously on
-- the voxelmanip of the on_generated callback. multidimensions writes
-- its own terrain from its own register_on_generated callback, whose
-- order relative to ours is not guaranteed either, so a dimension
-- fragment is routed ENTIRELY to a deferred path:
--     minetest.after(0)
--       -> emerge_area of the fragment extended by 24 nodes on XZ
--          (Y unchanged)
--       -> re-read of the COMMITTED map through a manual VoxelManip
--       -> the very scatter and village slot flows of the surface
--          engine, replayed through the P._try_at / P._civic_registry
--          internals of placement.lua
-- By the emerge callback the dimension terrain is committed whatever
-- the callback order was.
--
-- Building eligibility: the NUMERIC content ids of the dimension
-- ground nodes are injected into the ground_ids category sets of
-- placement.lua (Dim.inject_ground, called at the end of init_ids), so
-- the ground test of the engine accepts them. That injection is the
-- FUNCTIONAL gate: a building whose categories share nothing with the
-- dimension never sees the dimension ground in its ground_set. The
-- pool filtering of process_fragment below is only a drawing
-- optimisation on top of it. In a dimension fragment the biome test is
-- short circuited (a dimension has no biome of its own: the engine
-- would answer the surface biome of the column) and the altitude band
-- becomes an absolute window derived from the dimension itself, which
-- neutralises relax_altitude there.
--
-- Village plans are salted by dim_y (V.plan(cx, cz, dim) in
-- village_zones.lua): salt 0 is the surface, so the surface plans stay
-- bit for bit identical to the historical ones, while every dimension
-- draws its own independent plans from the same cells.

nativevillages = nativevillages or {}

local Dim = {}
Dim.enabled = false -- flipped by resolve() below, cheap guard for the hooks
nativevillages.dimensions = Dim

-- Inert probe (dungeon_entrances.lua convention): the global table is
-- NOT read here, multidimensions may load after this file
local installed = minetest.get_modpath("multidimensions") ~= nil

-- Settings, with fallbacks on the defaults documented in settingtypes.txt
local enabled = minetest.settings:get_bool(
    "nativevillages.use_dimensions", true)

-- User blacklist, parsed once at load: exact dimension names, trimmed
-- and lowercased, wins over everything (CONFIG and heuristic included)
local blacklist = {}
do
    local raw = minetest.settings:get("nativevillages.dimensions_blacklist")
        or "hot,water,floatandlike"
    for entry in raw:gmatch("[^,]+") do
        entry = entry:lower():match("^%s*(.-)%s*$")
        if entry ~= "" then
            blacklist[entry] = true
        end
    end
end

local api = nil          -- the multidimensions table, resolved once
local resolved = false
local configs = {}       -- dimension name -> dimcfg
local order = {}         -- eligible dimension names, STABLE order

-- Whitelist of the default multidimensions dimensions: name -> logical
-- biome categories of the buildings allowed there. lake and swamp are
-- never targeted (their buildings anchor on real water bodies the
-- dimension terrains do not provide). hot, water and floatandlike are
-- excluded through the DEFAULT blacklist of the setting, not here: the
-- user can re-enable them by emptying it
local CONFIG = {
    earthlike1 = {"grassland", "forest"},
    earthlike2 = {"grassland", "forest"},
    savana = {"savanna"},
    cold = {"arctic"},
    desert = {"desert"},
    sandstone = {"desert"},
    flatland = {"grassland"},
}

-- Heuristic fallback for a third party dimension (name absent from
-- CONFIG and not blacklisted): its REAL ground node decides. Exact
-- matches first (the inversion of ground_base, biomes.lua), then
-- substrings in a fixed order
local EXACT_GROUND = {
    ["default:dirt_with_grass"] = "grassland",
    ["default:dry_dirt_with_dry_grass"] = "savanna",
    ["default:desert_sand"] = "desert",
    ["default:snowblock"] = "arctic",
    ["default:ice"] = "arctic",
    ["default:permafrost"] = "arctic",
    ["default:dirt_with_rainforest_litter"] = "jungle",
}

local SUBSTRING_GROUND = {
    {"dry_grass", "savanna"},
    {"dry_dirt", "savanna"},
    {"desert", "desert"},
    {"sandstone", "desert"},
    {"snow", "arctic"},
    {"ice", "arctic"},
    {"frost", "arctic"},
    {"permafrost", "arctic"},
    {"rainforest", "jungle"},
    {"jungle", "jungle"},
    {"dirt_with_", "grassland"},
    {"grass", "grassland"},
}

-- Categories of one dimension, nil when it must be excluded. CONFIG
-- first, heuristic second, logged exclusion when nothing matches
local function categorize(name, d)
    if type(d) ~= "table" or type(d.self) ~= "table"
        or type(d.self.grass) ~= "number" then
        -- defensive: without the grass content id there is neither a
        -- heuristic to run nor a ground to inject
        minetest.log("action", "[nativevillages] dimension '" .. name
            .. "' excluded: no readable ground node")
        return nil
    end
    local configured = CONFIG[name]
    if configured then
        return configured
    end
    local top = minetest.get_name_from_content_id(d.self.grass)
    local cat = EXACT_GROUND[top]
    if not cat then
        for _, rule in ipairs(SUBSTRING_GROUND) do
            if top:find(rule[1], 1, true) then
                cat = rule[2]
                break
            end
        end
    end
    if not cat then
        minetest.log("action", "[nativevillages] dimension '" .. name
            .. "' excluded: unrecognised ground node '" .. top .. "'")
        return nil
    end
    return {cat}
end

-- Resolved per dimension table, cached for the whole session. Every
-- field is derived from registered_dimensions AT RUNTIME, no Y is ever
-- hardcoded: on the default dimensions self.dirt_start = dim_y + 501
-- and ground_limit = dim_y + 530, hence y_lo ~ dim_y + 469 and y_hi ~
-- dim_y + 546, but a custom dimension keeps its own window. d.self.
-- grass and d.self.sand are already NUMERIC content ids; d.self.dirt
-- is NOT injected (it is the foundation filler of the schematics, see
-- soil_replacement.lua)
local function build_dimcfg(name, d, cats)
    local categories = {}
    for _, cat in ipairs(cats) do
        categories[cat] = true
    end
    local ground_ids = {}
    ground_ids[d.self.grass] = true
    if type(d.self.sand) == "number" then
        ground_ids[d.self.sand] = true
    end
    local dim_y = d.dim_y or 0
    local dirt_start = d.self.dirt_start or (dim_y + 501)
    local ground_limit = d.ground_limit or (dim_y + 530)
    return {
        name = name,
        salt = dim_y, -- unique stable salt of the village plans
        label = "<dimension:" .. name .. ">", -- pseudo biome, logs only
        y_lo = dirt_start - 32,
        y_hi = ground_limit + 16,
        categories = categories,
        ground_ids = ground_ids,
    }
end

-- One shot resolution, from register_on_mods_loaded: by then the
-- multidimensions global exists (whatever the load order was) and
-- every dimension is registered
local function resolve()
    if resolved then
        return
    end
    resolved = true
    api = installed and multidimensions or nil
    if api == nil then
        minetest.log("action", "[nativevillages] dimension support "
            .. "DISABLED (multidimensions not installed)")
        return
    end
    if not enabled then
        minetest.log("action", "[nativevillages] dimension support "
            .. "DISABLED (use_dimensions=false)")
        return
    end
    -- stable iteration order whatever the hash order of the table
    local names = {}
    if type(api.registered_dimensions) == "table" then
        for name in pairs(api.registered_dimensions) do
            names[#names + 1] = name
        end
    end
    table.sort(names)
    for _, name in ipairs(names) do
        -- names are lowercased for the test: the setting documents a case
        -- insensitive blacklist, a third party dimension may carry capitals
        if blacklist[name:lower()] then
            minetest.log("action", "[nativevillages] dimension '"
                .. name .. "' excluded: blacklisted")
        else
            local cats = categorize(name, api.registered_dimensions[name])
            if cats then
                configs[name] = build_dimcfg(name,
                    api.registered_dimensions[name], cats)
                order[#order + 1] = name
            end
        end
    end
    if #order == 0 then
        minetest.log("action", "[nativevillages] dimension support "
            .. "DISABLED (multidimensions found but no eligible dimension)")
        return
    end
    minetest.log("action", "[nativevillages] dimension support ACTIVE "
        .. "(multidimensions found, " .. #order .. " eligible: "
        .. table.concat(order, ",") .. ")")
    Dim.enabled = true
end

minetest.register_on_mods_loaded(resolve)

-- dimcfg of the dimension owning the WHOLE fragment, nil when the
-- fragment belongs to no dimension. Exact multidimensions rule: a
-- fragment straddling a dimension boundary belongs to no dimension at
-- all. A nil return (absent, excluded, border straddling, below the
-- first dimension) drops the caller back into the normal surface
-- flow, where the draws die on the biome/ground tests exactly as
-- before, at no cost
function Dim.fragment(minp, maxp)
    if not Dim.enabled or api == nil then
        return nil
    end
    for _, name in ipairs(order) do
        local d = api.registered_dimensions[name]
        if d and type(d.dim_y) == "number" then
            if minp.y >= d.dim_y
                and maxp.y <= d.dim_y + (d.dim_height or 0) then
                return configs[name]
            end
        end
    end
    return nil
end

-- Merge the ground content ids of every eligible dimension into the
-- ground_ids category sets of placement.lua. Called at the very end of
-- init_ids(): a building sharing a category with the dimension then
-- accepts the dimension ground as its own ground node
function Dim.inject_ground(ground_ids)
    for _, name in ipairs(order) do
        local cfg = configs[name]
        for cat in pairs(cfg.categories) do
            local set = ground_ids[cat]
            if not set then
                set = {}
                ground_ids[cat] = set
            end
            for id in pairs(cfg.ground_ids) do
                set[id] = true
            end
        end
    end
end

-- Mirrors of the placement.lua settings this module needs on its own
-- deferred path (placement.lua keeps them local; duplicating the read
-- is cheaper than widening its interface for an optional module).
-- Same defaults and clamps, so both flows stay in tune
local density = tonumber(minetest.settings:get(
    "nativevillages.placement_density") or "") or 0.00035
if density < 0.000001 then
    density = 0.000001
elseif density > 1.0 then
    density = 1.0
end
local max_tries_per_chunk = 64
local debug_placement = minetest.settings:get_bool(
    "nativevillages.debug_placement", false)

-- Drawing pool restricted to the buildings sharing at least one
-- category with the dimension, in registration order (deterministic
-- drawing), with the recomputed total weight
local function pool_for(dimcfg, registry)
    local defs, weight = {}, 0
    for _, def in ipairs(registry) do
        for cat in pairs(def.categories) do
            if dimcfg.categories[cat] then
                defs[#defs + 1] = def
                weight = weight + def.fill_ratio
                break
            end
        end
    end
    return defs, weight
end

-- Deferred routing of a whole dimension fragment (see the header).
-- place_now = true: an accepted site is dispatched directly, the
-- vertical containment of dispatch_job still emerging a spilling
-- footprint first; defer = nil: a footprint crossing the readable
-- window is dropped, the XZ containment being provided by the +/-24
-- nodes margin of the emerge itself (the counterpart of defer_slot in
-- the surface flow). The extra on_generated calls the emerge triggers
-- for the freshly generated border mapblocks are rerouted here too,
-- which is harmless: deterministic draws per blockseed plus the
-- anti-collision registry, exactly like the deferrals of the surface
-- flow
function Dim.process_fragment(minp, maxp, blockseed, dimcfg, registry,
    total_weight)
    -- total_weight is kept for signature parity only: the pool is
    -- re-filtered per dimension below
    local P = nativevillages.placement
    if not P or type(P._try_at) ~= "function" then
        return
    end
    local m = 24
    local p1 = {x = minp.x - m, y = minp.y, z = minp.z - m}
    local p2 = {x = maxp.x + m, y = maxp.y, z = maxp.z + m}
    minetest.after(0, function()
        minetest.emerge_area(p1, p2, function(_, _, remaining)
            if remaining > 0 then
                return
            end
            local vm2 = minetest.get_voxel_manip()
            local e1, e2 = vm2:read_from_map(p1, p2)
            if not e1 then
                return
            end
            local va = VoxelArea:new({MinEdge = e1, MaxEdge = e2})
            local data = vm2:get_data()

            local defs, weight = pool_for(dimcfg, registry)
            if #defs == 0 then
                minetest.log("action", "[nativevillages] dimension "
                    .. dimcfg.label .. ": no eligible building, fragment ("
                    .. minp.x .. "," .. minp.z .. ") skipped")
                return
            end

            local prng = PcgRandom(blockseed)

            -- Scattered sites: the very target formula of the surface
            -- flow (density * fragment area, stochastic rounding, hard
            -- cap), the containment staying on the ORIGINAL fragment
            local csize = maxp.x - minp.x + 1
            local area = csize * (maxp.z - minp.z + 1)
            local target = density * area
            local tries = math.floor(target)
            if prng:next(0, 999999) < (target - tries) * 1000000 then
                tries = tries + 1
            end
            if tries > max_tries_per_chunk then
                tries = max_tries_per_chunk
            end
            local stats = {
                accepted = 0,
                no_match = 0, not_flat = 0, collision = 0, too_wide = 0,
                draw_ground = 0, draw_biome = 0, draw_alt = 0,
                draw_water = 0, deferred = 0,
            }
            local scatter_ctx = {
                va = va, data = data, yfloor = e1.y, top = e2.y,
                eminx = e1.x, eminz = e1.z, emaxx = e2.x, emaxz = e2.z,
                minp = minp, maxp = maxp,
                stats = stats, queue = nil, rng = prng,
                defs = defs, weight = weight, slot = nil,
                defer = nil, place_now = true, dim = dimcfg,
            }
            for _ = 1, tries do
                P._try_at(scatter_ctx)
            end

            -- Village slots: mirror of the surface flow of the
            -- on_generated callback, the plans being salted by dim_y
            -- so every dimension draws its own villages from the same
            -- cells, deterministically and whatever the chunk order
            local vstats = {
                hosted = 0, tried = 0, accepted = 0, not_flat = 0,
                collision = 0, no_match = 0, too_wide = 0, deferred = 0,
                draw_ground = 0, draw_biome = 0, draw_alt = 0,
                draw_water = 0,
            }
            local Vv = nativevillages.village
            if Vv and Vv.enabled and type(Vv.plan) == "function"
                and type(Vv.cells_overlapping) == "function" then
                local tag = " (village slot " .. dimcfg.label .. ")"
                -- civic preference of the core slots, filtered on the
                -- dimension categories (civic_total recomputed)
                local cdefs, ctotal = {}, 0
                local civic_defs = (type(P._civic_registry) == "function")
                    and P._civic_registry() or {}
                for _, def in ipairs(civic_defs or {}) do
                    for cat in pairs(def.categories) do
                        if dimcfg.categories[cat] then
                            cdefs[#cdefs + 1] = def
                            ctotal = ctotal + def.fill_ratio
                            break
                        end
                    end
                end
                for _, cell in ipairs(Vv.cells_overlapping(minp, maxp)) do
                    local plan = Vv.plan(cell.cx, cell.cz, dimcfg.salt)
                    if plan then
                        for i, slot in ipairs(plan.slots) do
                            if slot.x >= minp.x and slot.x <= maxp.x
                                and slot.z >= minp.z
                                and slot.z <= maxp.z then
                                vstats.hosted = vstats.hosted + 1
                                vstats.tried = vstats.tried + 1
                                local srng = PcgRandom(plan.seed,
                                    plan.seq + i)
                                local function mkctx(dfs, wgt)
                                    return {
                                        va = va, data = data,
                                        yfloor = e1.y, top = e2.y,
                                        eminx = e1.x, eminz = e1.z,
                                        emaxx = e2.x, emaxz = e2.z,
                                        stats = vstats, queue = nil,
                                        rng = srng, defs = dfs,
                                        weight = wgt, slot = slot,
                                        tag = tag, defer = nil,
                                        place_now = true, dim = dimcfg,
                                    }
                                end
                                local done = false
                                if slot.civic and ctotal > 0 then
                                    done = P._try_at(mkctx(cdefs, ctotal))
                                end
                                if not done then
                                    P._try_at(mkctx(defs, weight))
                                end
                            end
                        end
                    end
                end
            end

            -- debug recap, same counters and format as the surface
            -- chunk recap, with the readable dimension tag
            if debug_placement then
                minetest.log("action", "[nativevillages] dimension "
                    .. dimcfg.label .. " chunk (" .. minp.x .. "," .. minp.z
                    .. ") y=" .. minp.y .. ": sites tried=" .. tries
                    .. " accepted=" .. stats.accepted
                    .. " | site rejections: no_drawing=" .. stats.no_match
                    .. " not_flat=" .. stats.not_flat
                    .. " collision=" .. stats.collision
                    .. " too_wide=" .. stats.too_wide
                    .. " | failed draws: ground=" .. stats.draw_ground
                    .. " biome=" .. stats.draw_biome
                    .. " altitude=" .. stats.draw_alt
                    .. " open_water=" .. stats.draw_water)
                minetest.log("action", "[nativevillages] dimension "
                    .. dimcfg.label .. " chunk (" .. minp.x .. "," .. minp.z
                    .. ") y=" .. minp.y .. " village slots: hosted="
                    .. vstats.hosted .. " tried=" .. vstats.tried
                    .. " accepted=" .. vstats.accepted
                    .. " | slot rejections: no_drawing=" .. vstats.no_match
                    .. " not_flat=" .. vstats.not_flat
                    .. " collision=" .. vstats.collision
                    .. " too_wide=" .. vstats.too_wide
                    .. " | failed draws: ground=" .. vstats.draw_ground
                    .. " biome=" .. vstats.draw_biome
                    .. " altitude=" .. vstats.draw_alt
                    .. " open_water=" .. vstats.draw_water)
            end
        end)
    end)
end
