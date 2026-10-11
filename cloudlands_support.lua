-- Optional cloudlands integration for nativevillages.
--
-- When the optional cloudlands mod is installed, a small set of tents
-- and houses of this mod also spawns on its floating islands (the
-- "Hallelujah Mountains" of the NORMAL world, around y = 160..270 with
-- the default altitude settings). Without cloudlands, or when the
-- master setting is disabled, this module is a complete silent no-op,
-- the dimension_support.lua convention: only the installed flag is
-- probed at load time, the cloudlands TABLE itself is resolved lazily
-- in register_on_mods_loaded because the mod load order is not
-- guaranteed.
--
-- Core principle (cloned from dimension_support.lua): NOTHING is
-- decided synchronously on the voxelmanip of the on_generated
-- callback. cloudlands writes its islands from its own
-- register_on_generated callback, whose order relative to ours is not
-- guaranteed either, so a fragment carrying an island is routed
-- ENTIRELY to a deferred path:
--     minetest.after(0)
--       -> emerge_area of the fragment extended by 24 nodes on XZ
--          (Y unchanged)
--       -> re-read of the COMMITTED map through a manual VoxelManip
--       -> the very scatter and village slot flows of the surface
--          engine, replayed through the P._try_at internal of
--          placement.lua
-- By the emerge callback the island terrain is committed whatever the
-- callback order was, so the sites land on the REAL island surface.
-- Unlike the dimension routing, the surface flow of placement.lua is
-- NOT cut short here: this module registers its OWN on_generated
-- callback, and the surface one keeps running on the same fragments,
-- where its draws die on the historical altitude bands (an island
-- surface around y = 200 sits far above every y_max of the ground
-- anchored buildings, even relaxed).
--
-- Island eligibility: every island core returned by the PUBLIC
-- cloudlands API (get_island_details, no map access, deterministic)
-- whose disk intersects the fragment and whose radius is at least
-- MIN_RADIUS carries its own pseudo dimension config (dimcfg):
--   * an absolute altitude window of surface +/- SURFACE_BAND nodes
--     around the island surface height at its centre
--     (cloudlands.get_height_at, islands without land at their centre
--     or with a pond there are skipped), which replaces the historical
--     band of the drawings exactly like a dimension fragment;
--   * the categories "cloudlands" (every island) and
--     "cloudlands_large" (depth >= LARGE_DEPTH AND radius >=
--     LARGE_RADIUS: the 30 node foundations of the small houses fit
--     inside such islands, the leftover spilling under a smaller one
--     being an assumed stilt effect), plus the logical biome category
--     derived from the REAL biome at the island top through the very
--     ground node heuristic of dimension_support.lua;
--   * the NUMERIC content ids of the node_top and node_filler of that
--     biome: the cloudlands terrain is built from the very nodes of
--     the biome it samples, so those ids are the ground of the island.
--
-- Building eligibility, or why the island buildings are NOT registered
-- through P.register_building: the ground test of placement.lua draws
-- the acceptable nodes of a drawing from the ground_ids category sets,
-- which are only filled for the categories of the REGISTERED
-- buildings, and there is no injection hook for an outside module
-- (dimension_support.lua has one because placement.lua calls
-- Dim.inject_ground itself). The island drawings are therefore private
-- definitions kept in cloudlandsbuildings.lua, replayed through
-- ctx.defs as a shallow per island copy whose ground_set is PRE-FILLED
-- with the dimcfg ids (the ground_set_of cache of placement.lua
-- returns a def.ground_set as is when it is already there). The
-- private definitions never enter the global registry, so the surface
-- and dimension flows of the engine can never draw them (no leak, no
-- duplicate of the historical decorations in the legacy mode), and the
-- pool of a fragment is exactly what this module selects: tents on
-- every island, tents plus the small foundation houses on the large
-- deep ones.
--
-- Village plans are salted by a dedicated constant (V.plan(cx, cz,
-- SALT) in village_zones.lua): the island villages are independent of
-- the surface and dimension ones, and the lone house suppression of
-- the scattered sites consults the salted plans coherently. The civic
-- preference of the core slots is NOT replayed here: no island drawing
-- is civic, and filtering the global civic registry on the island
-- categories (which carry the biome category of the island) would leak
-- the surface wells and markets onto the islands.

nativevillages = nativevillages or {}

local C = {}
C.enabled = false -- flipped by resolve() below, cheap guard for the hook
nativevillages.cloudlands = C

local B = nativevillages.biomes

-- Inert probe (dimension_support.lua convention): the global table is
-- NOT read here, cloudlands may load after this file
local installed = minetest.get_modpath("cloudlands") ~= nil

-- Settings, with fallbacks on the defaults documented in settingtypes.txt
local enabled = minetest.settings:get_bool(
    "nativevillages.cloudlands_villages", true)

-- Mirrors of the placement.lua settings this module needs on its own
-- deferred path (placement.lua keeps them local; duplicating the read
-- is cheaper than widening its interface for an optional module, the
-- dimension_support.lua convention). Same defaults and clamps, so both
-- flows stay in tune. use_new_placement is mirrored too: the deferred
-- island path replays the engine internals, it must not run when the
-- engine itself is disabled (historical decorations mode)
local engine_use_new = minetest.settings:get_bool(
    "nativevillages.use_new_placement", true)
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

-- Island filter constants (see the header):
--   SALT          dedicated integer salt of the island village plans
--                (0 is the surface, the dim_y values belong to the
--                dimensions; the seed arithmetic of V.plan needs an
--                integer to stay exact in Lua numbers)
--   MIN_RADIUS    islands below this radius keep their sky pristine
--   LARGE_DEPTH / LARGE_RADIUS  thresholds of the "cloudlands_large"
--                category: a 30 node foundation fits inside an island
--                at least LARGE_DEPTH deep, and a ~13x13 house inside
--                a disk of radius LARGE_RADIUS
--   SURFACE_BAND  absolute altitude window (surface at the island
--                centre +/- this many nodes) replacing the historical
--                bands of the drawings on the island flow
--   OWNER_MARGIN  slack added to an island radius when looking for the
--                island owning a village slot point
local SALT = 90210
local MIN_RADIUS = 12
local LARGE_DEPTH = 28
local LARGE_RADIUS = 20
local SURFACE_BAND = 10
local OWNER_MARGIN = 8

-- Heuristic mapping the REAL ground node of the island top biome to a
-- logical biome category of this mod: exact matches first (the very
-- tables of dimension_support.lua, the inversion of ground_base in
-- biomes.lua), then substrings in a fixed order
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

local api = nil          -- the cloudlands table, resolved once
local resolved = false
-- Mirrors of the cloudlands altitude settings (cloudlands.lua reads
-- them the same way at its own load): ALTITUDE and ALTITUDE_AMPLITUDE
-- drive the island heights, and the guard window below is the EXACT
-- early-out of cloudlands' own on_generated, so this module never
-- wastes a deferred fragment where cloudlands itself generates nothing
local altitude = 200
local amplitude = 40
local lowland_biomes = false -- cloudlands samples island biomes at y=10 when true
local guard_hi = math.huge
local guard_lo = -math.huge

-- One shot resolution, from register_on_mods_loaded: by then the
-- cloudlands global exists (whatever the load order was) and its
-- settings have been applied
local function resolve()
    if resolved then
        return
    end
    resolved = true
    api = installed and cloudlands or nil
    if api == nil then
        minetest.log("action", "[nativevillages] cloudlands support "
            .. "DISABLED (cloudlands not installed)")
        return
    end
    if not enabled then
        minetest.log("action", "[nativevillages] cloudlands support "
            .. "DISABLED (cloudlands_villages=false)")
        return
    end
    if not engine_use_new then
        minetest.log("action", "[nativevillages] cloudlands support "
            .. "DISABLED (use_new_placement=false, historical "
            .. "decorations in use)")
        return
    end
    -- defensive: the whole deferred path hangs on these two entry
    -- points, a cloudlands update changing their shape must degrade
    -- into a logged no-op, never a crash
    if type(api.get_island_details) ~= "function"
        or type(api.get_height_at) ~= "function" then
        api = nil
        minetest.log("action", "[nativevillages] cloudlands support "
            .. "DISABLED (cloudlands API not recognised)")
        return
    end
    altitude = tonumber(minetest.settings:get("cloudlands_altitude")
        or "") or 200
    amplitude = tonumber(minetest.settings:get(
        "cloudlands_altitude_amplitude") or "") or 40
    -- same lowland rule as cloudlands.lua: ethereal has an alpine
    -- biome above altitude 40, so the island biomes are sampled at the
    -- lowland altitude instead of the island top (keeping this mirror
    -- in tune is what makes the node_top/node_filler derived ground
    -- match the nodes cloudlands actually writes)
    lowland_biomes = minetest.settings:get_bool(
        "cloudlands_use_lowland_biomes",
        minetest.get_modpath("ethereal") ~= nil)
    -- guard window: the arithmetic of the early-out of the cloudlands
    -- on_generated (cloudlands.lua), computed once from the largest
    -- core type it declares
    local largest = type(api.coreTypes) == "table" and api.coreTypes[1]
        or {}
    local max_core_thickness = tonumber(largest.thicknessMax) or 8
    local max_core_depth = (tonumber(largest.radiusMax) or 96) * 3 / 2
    local max_surface_rise = 3 * (max_core_thickness + 1)
    guard_hi = altitude + (amplitude + max_surface_rise + 10)
    guard_lo = altitude - (amplitude + max_core_thickness
        + max_core_depth + 10)
    minetest.log("action", "[nativevillages] cloudlands support ACTIVE "
        .. "(altitude=" .. altitude .. " amplitude=" .. amplitude
        .. ", islands y " .. guard_lo .. ".." .. guard_hi .. ")")
    C.enabled = true
end

minetest.register_on_mods_loaded(resolve)

-- True when the disk of a core intersects the XZ rectangle of the
-- fragment (get_island_details already widens its search by the core
-- type radiusMax, so the list carries cores whose island does not
-- touch the fragment at all: those must not route a deferred job)
local function core_intersects(core, minp, maxp)
    local cx = math.max(minp.x, math.min(core.x, maxp.x))
    local cz = math.max(minp.z, math.min(core.z, maxp.z))
    local dx, dz = core.x - cx, core.z - cz
    return dx * dx + dz * dz <= core.radius * core.radius
end

-- dimcfg of one island core, nil when the island must be skipped (no
-- readable land at its centre, or a pond there). Every field is
-- derived from the PUBLIC cloudlands API and the real biome data at
-- runtime, nothing is hardcoded beyond the thresholds above
local function build_dimcfg(core, cores)
    local ok, surf, is_water = pcall(api.get_height_at, core.x, core.z,
        cores)
    if not ok or type(surf) ~= "number" or is_water then
        return nil
    end
    -- biome really used by cloudlands for this island (setCoreBiomeData
    -- samples the very same position): its node_top and node_filler are
    -- the nodes the island surface is built from
    local sy = lowland_biomes and 10
        or altitude + (tonumber(core.y) or 0)
    local bdata = minetest.get_biome_data({x = core.x, y = sy, z = core.z})
    local bname = bdata and minetest.get_biome_name
        and minetest.get_biome_name(bdata.biome) or nil
    local bdef = bname and minetest.registered_biomes[bname] or nil
    local top = (bdef and bdef.node_top) or "default:dirt_with_grass"
    local filler = (bdef and bdef.node_filler) or "default:dirt"
    local ground_ids = {}
    local function add_ground(name)
        if name and name ~= "" and minetest.registered_nodes[name] then
            ground_ids[minetest.get_content_id(name)] = true
        end
    end
    add_ground(top)
    add_ground(filler)
    if next(ground_ids) == nil then
        -- neither node resolves (exotic game): fall back on the plain
        -- minetest_game ground rather than an empty, never matching set
        add_ground("default:dirt_with_grass")
        add_ground("default:dirt")
    end
    -- logical biome category of the island: the ground node heuristic
    -- of dimension_support.lua on the node_top, with the reverse biome
    -- index of biomes.lua as a last resort
    local cat = EXACT_GROUND[top]
    if not cat then
        for _, rule in ipairs(SUBSTRING_GROUND) do
            if top:find(rule[1], 1, true) then
                cat = rule[2]
                break
            end
        end
    end
    if not cat and bname and B and B.category_of then
        cat = B.category_of(bname)
    end
    local categories = {cloudlands = true}
    if cat then
        categories[cat] = true
    end
    if (tonumber(core.depth) or 0) >= LARGE_DEPTH
        and (tonumber(core.radius) or 0) >= LARGE_RADIUS then
        categories.cloudlands_large = true
    end
    return {
        core = core,
        salt = SALT, -- unique stable salt of the island village plans
        label = "<cloudlands:r" .. math.floor(tonumber(core.radius) or 0)
            .. ">", -- pseudo biome, logs only
        y_lo = surf - SURFACE_BAND - 0.5, -- gy + 0.5 comparison of the
        y_hi = surf + SURFACE_BAND + 0.5, -- engine: whole nodes inside
        categories = categories,
        ground_ids = ground_ids,
    }
end

-- Drawing pool of one island: a shallow per island copy of every
-- template of cloudlandsbuildings.lua sharing at least one category
-- with the dimcfg, in declaration order (deterministic drawing), with
-- the recomputed total weight. The copy carries the PRE-FILLED
-- ground_set of the island (the ground_set_of cache of placement.lua
-- returns it as is), which is what makes the private, unregistered
-- drawings pass the ground test of the engine without any injection
-- hook. The tables shared with the template (categories) are read
-- only by the engine
local function island_pool(dimcfg, templates)
    local defs, weight = {}, 0
    for _, tmpl in ipairs(templates) do
        local shared = false
        for cat in pairs(tmpl.categories) do
            if dimcfg.categories[cat] then
                shared = true
                break
            end
        end
        if shared then
            defs[#defs + 1] = {
                name = tmpl.name,
                schematic = tmpl.schematic,
                anchor = tmpl.anchor,
                offset = tmpl.offset,
                y_min = tmpl.y_min,
                y_max = tmpl.y_max,
                fill_ratio = tmpl.fill_ratio,
                categories = tmpl.categories,
                ground_set = dimcfg.ground_ids,
            }
            weight = weight + tmpl.fill_ratio
        end
    end
    return defs, weight
end

-- dimcfg owning a village slot POINT: the nearest core whose widened
-- disk covers the point, nil when the point falls in the open sky (or
-- on an island skipped at dimcfg build time)
local function owner_cfg(x, z, cores, cfg_of_core)
    local best, best_d = nil, nil
    for _, core in ipairs(cores) do
        local r = (tonumber(core.radius) or 0) + OWNER_MARGIN
        local dx, dz = x - core.x, z - core.z
        local d2 = dx * dx + dz * dz
        if d2 <= r * r and (best_d == nil or d2 < best_d) then
            best, best_d = core, d2
        end
    end
    return best and cfg_of_core[best] or nil
end

-- Deferred routing of a fragment carrying islands (see the header).
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
local function process_fragment(minp, maxp, blockseed, cores)
    local P = nativevillages.placement
    if not P or type(P._try_at) ~= "function" then
        return
    end
    local CB = nativevillages.cloudlands_buildings
    if not CB or type(CB.list) ~= "table" or #CB.list == 0 then
        minetest.log("action", "[nativevillages] cloudlands fragment ("
            .. minp.x .. "," .. minp.z .. ") skipped: no island "
            .. "building registered")
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

            -- one dimcfg per island, in the stable core order of
            -- get_island_details (the PRNG below is consumed island
            -- after island, so the whole fragment stays deterministic
            -- per blockseed)
            local dimcfgs = {}
            local cfg_of_core = {}
            for _, core in ipairs(cores) do
                local cfg = build_dimcfg(core, cores)
                if cfg then
                    dimcfgs[#dimcfgs + 1] = cfg
                    cfg_of_core[core] = cfg
                end
            end
            if #dimcfgs == 0 then
                minetest.log("action", "[nativevillages] cloudlands "
                    .. "fragment (" .. minp.x .. "," .. minp.z
                    .. ") skipped: no eligible island")
                return
            end

            local prng = PcgRandom(blockseed)

            local stats = {
                accepted = 0,
                no_match = 0, not_flat = 0, collision = 0, too_wide = 0,
                draw_ground = 0, draw_biome = 0, draw_alt = 0,
                draw_water = 0, deferred = 0,
            }
            local vstats = {
                hosted = 0, tried = 0, accepted = 0, not_flat = 0,
                collision = 0, no_match = 0, too_wide = 0, deferred = 0,
                draw_ground = 0, draw_biome = 0, draw_alt = 0,
                draw_water = 0,
            }

            -- Scattered sites: the very target formula of the surface
            -- flow (density * fragment area, stochastic rounding, hard
            -- cap), the containment staying on the ORIGINAL fragment.
            -- The budget is split evenly between the islands of the
            -- fragment, each pass drawing its points inside the whole
            -- fragment: a point falling on another island than the
            -- pass owner is anchored, flattened and collision tested
            -- against the REAL map anyway, so at worst it lands
            -- correctly or is rejected by the altitude band of its
            -- pass, never misplaced
            local csize = maxp.x - minp.x + 1
            local area = csize * (maxp.z - minp.z + 1)
            local per_island = density * area / #dimcfgs
            local tries_total = 0
            for _, dimcfg in ipairs(dimcfgs) do
                local defs, weight = island_pool(dimcfg, CB.list)
                if #defs > 0 then
                    local target = per_island
                    local tries = math.floor(target)
                    if prng:next(0, 999999)
                        < (target - tries) * 1000000 then
                        tries = tries + 1
                    end
                    if tries > max_tries_per_chunk then
                        tries = max_tries_per_chunk
                    end
                    tries_total = tries_total + tries
                    local scatter_ctx = {
                        va = va, data = data, yfloor = e1.y, top = e2.y,
                        eminx = e1.x, eminz = e1.z,
                        emaxx = e2.x, emaxz = e2.z,
                        minp = minp, maxp = maxp,
                        stats = stats, queue = nil, rng = prng,
                        defs = defs, weight = weight, slot = nil,
                        defer = nil, place_now = true, dim = dimcfg,
                        tag = " (cloudlands)",
                    }
                    for _ = 1, tries do
                        P._try_at(scatter_ctx)
                    end
                end
            end

            -- Village slots: mirror of the surface flow of the
            -- on_generated callback, the plans being salted by the
            -- dedicated island salt so the island villages draw their
            -- own layouts from the same cells, deterministically and
            -- whatever the chunk order. Every slot POINT hosted by this
            -- fragment is offered to the pool of the island owning it
            -- (a slot falling in the open sky between islands is
            -- simply never tried). The civic preference of the core
            -- slots is deliberately not replayed, see the header
            local Vv = nativevillages.village
            if Vv and Vv.enabled and type(Vv.plan) == "function"
                and type(Vv.cells_overlapping) == "function" then
                local tag = " (village slot <cloudlands>)"
                for _, cell in ipairs(Vv.cells_overlapping(minp, maxp)) do
                    local plan = Vv.plan(cell.cx, cell.cz, SALT)
                    if plan then
                        for i, slot in ipairs(plan.slots) do
                            if slot.x >= minp.x and slot.x <= maxp.x
                                and slot.z >= minp.z
                                and slot.z <= maxp.z then
                                vstats.hosted = vstats.hosted + 1
                                vstats.tried = vstats.tried + 1
                                local dimcfg = owner_cfg(slot.x, slot.z,
                                    cores, cfg_of_core)
                                if dimcfg then
                                    local defs, weight = island_pool(
                                        dimcfg, CB.list)
                                    if #defs > 0 then
                                        local srng = PcgRandom(plan.seed,
                                            plan.seq + i)
                                        local ctx = {
                                            va = va, data = data,
                                            yfloor = e1.y, top = e2.y,
                                            eminx = e1.x, eminz = e1.z,
                                            emaxx = e2.x, emaxz = e2.z,
                                            stats = vstats, queue = nil,
                                            rng = srng, defs = defs,
                                            weight = weight, slot = slot,
                                            tag = tag, defer = nil,
                                            place_now = true,
                                            dim = dimcfg,
                                        }
                                        P._try_at(ctx)
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- debug recap, same counters and format as the surface
            -- chunk recap, with the island count of the fragment
            if debug_placement then
                minetest.log("action", "[nativevillages] cloudlands "
                    .. "chunk (" .. minp.x .. "," .. minp.z .. ") y="
                    .. minp.y .. " islands=" .. #dimcfgs
                    .. ": sites tried=" .. tries_total
                    .. " accepted=" .. stats.accepted
                    .. " | site rejections: no_drawing=" .. stats.no_match
                    .. " not_flat=" .. stats.not_flat
                    .. " collision=" .. stats.collision
                    .. " too_wide=" .. stats.too_wide
                    .. " | failed draws: ground=" .. stats.draw_ground
                    .. " biome=" .. stats.draw_biome
                    .. " altitude=" .. stats.draw_alt
                    .. " open_water=" .. stats.draw_water)
                minetest.log("action", "[nativevillages] cloudlands "
                    .. "chunk (" .. minp.x .. "," .. minp.z .. ") y="
                    .. minp.y .. " village slots: hosted="
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

-- Own mapgen hook: registered ONLY when the cloudlands mod is
-- installed (the module is otherwise a dead file), everything else is
-- guarded by the lazy resolution above. The fragment keeps flowing
-- through the surface callback of placement.lua in parallel; the early
-- outs below only decide whether THIS module routes a deferred island
-- job for it
if installed then
    minetest.register_on_generated(function(minp, maxp, blockseed)
        if not C.enabled or api == nil then
            return
        end
        -- exact cloudlands guard: outside this Y window cloudlands
        -- itself generates no island, there is nothing to route
        if minp.y > guard_hi or maxp.y < guard_lo then
            return
        end
        local ok, cores = pcall(api.get_island_details, minp, maxp)
        if not ok or type(cores) ~= "table" then
            return
        end
        local useful = {}
        for _, core in ipairs(cores) do
            if type(core) == "table"
                and (tonumber(core.radius) or 0) >= MIN_RADIUS
                and core_intersects(core, minp, maxp) then
                useful[#useful + 1] = core
            end
        end
        if #useful == 0 then
            return
        end
        process_fragment(minp, maxp, blockseed, useful)
    end)
end
