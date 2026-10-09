-- Deterministic village zones for the placement engine (see
-- plans/proposition-villages-groupement.md). This module holds NO map
-- access: a village plan is a PURE function of (cell coordinates, world
-- seed, settings), so the chunks a village spans can be generated in
-- any order and each of them rediscovers the exact same plan alone,
-- with no cross chunk coordination and no persistence.
-- Path boost (optional pathv7): villages keep standing ANYWHERE (the
-- core stays uniformly drawn), but when pathv7 is enabled the plan can
-- probe "is there a path near the core?" by recomputing pathv7's own
-- noises (pure functions of the world seed and the position, no map
-- read), and a village whose core lies within
-- nativevillages.village_path_range of a path GROWS: bonus slots on a
-- wider disk (a market town along the road versus a hamlet in the
-- wilds). The core itself is never moved, keeping the plan pure and
-- deterministic. Without pathv7 nothing changes at all.
--
-- Grid: the world is cut into REGION x REGION square cells. A cell
-- draws (from PcgRandom(world_seed, cell sequence)) whether it carries
-- a village and where its core sits, uniform with a R_MAX +
-- EDGE_MARGIN margin, so a whole village disk [core ± R_MAX] always
-- stays inside its own cell: two villages are at least 2 * EDGE_MARGIN
-- apart and a fragment only ever has to inspect its own cell and its 8
-- neighbours (see cells_overlapping).
--
-- Plan: SLOTS building slots on a uniform disk R_MIN..R_MAX around the
-- core (no artificial rings). The slots are OVERPROVISIONED: every one
-- still has to pass the ground/biome/altitude/flatness tests of
-- placement.lua, so the village FOLLOWS THE TOPOGRAPHY -- a ravine, a
-- river or a lake simply punches holes in the plan, and a hilly
-- village keeps fewer buildings than a plains one. Two slots closer
-- than SLOT_MIN_DIST nodes are redrawn (bounded attempts), so two
-- footprints rarely fight for the same ground; what remains is
-- settled by the anti-collision registry as usual.
--
-- Nothing here decides WHICH building stands on a slot: the actual
-- ground of the slot does, through the weighted redraws of the engine
-- (a grass slot elects a grassland drawing, a shallow water slot a
-- stilt lake house, both coexist on a shore). Slots closer than
-- CIVIC_RADIUS to the core merely PREFER the civic drawings (wells,
-- markets, ponds, stables, harbours...) listed below by name.
--
-- Known limits, on purpose: the plans depend on the settings (change a
-- radius and the not yet generated chunks redraw different villages,
-- exactly like placement_density), and the cells are evaluated from
-- the world seed alone, so a village can elect a spot whose ground
-- will reject every slot (underwater core, cliff): the village then
-- simply does not materialise, which costs nothing.

nativevillages = nativevillages or {}

local V = {}
nativevillages.village = V

local function clamp(n, lo, hi)
    if n < lo then
        return lo
    end
    if n > hi then
        return hi
    end
    return n
end

local function setting_int(name, default, lo, hi)
    return clamp(tonumber(minetest.settings:get(name) or "") or default, lo, hi)
end

-- Settings, with fallbacks on the defaults documented in settingtypes.txt
local enabled = minetest.settings:get_bool("nativevillages.use_villages", true)
local REGION = setting_int("nativevillages.village_region", 512, 320, 2560)
-- Path affinity (pathv7): attract the village cores to the paths
local prefer_paths = minetest.settings:get_bool(
    "nativevillages.villages_prefer_paths", true)
local PATH_RANGE = setting_int("nativevillages.village_path_range", 96, 24, 400)
-- Growth of a path boosted village: bonus slots and wider disk. The
-- boosted radius is clamped inside V.plan so the widened disk never
-- leaves the shrunk cell
local PATH_BONUS_SLOTS = setting_int(
    "nativevillages.village_path_bonus_slots", 8, 0, 28)
local CHANCE = clamp(tonumber(minetest.settings:get(
    "nativevillages.village_chance") or "") or 0.08, 0.01, 1.0)
local R_MIN = setting_int("nativevillages.village_radius_min", 20, 8, 128)
local R_MAX = setting_int("nativevillages.village_radius_max", 56, 24, 256)
-- keep a sane ring width whatever the user typed
if R_MIN > R_MAX - 8 then
    R_MIN = R_MAX - 8
end
local SLOTS = setting_int("nativevillages.village_slots", 12, 2, 40)
local CIVIC_RADIUS = setting_int("nativevillages.village_civic_radius", 18, 0, 64)

-- Core margin from the cell borders (see the header): the whole
-- village disk stays inside its cell shrunk by EDGE_MARGIN
local EDGE_MARGIN = 24

-- Minimum XZ distance between two drawn slots of one plan (the
-- footprints are up to ~20 nodes wide; 16 plus min_spacing keeps the
-- collision rejections rare and the plan reproducible)
local SLOT_MIN_DIST = 16

-- World seed, read once at load: part of the plan key. A precision
-- loss past 2^53 (Lua numbers) would be CONSTANT for a given world,
-- so the plans stay deterministic; only two different worlds could
-- theoretically collide, without any consequence
local SEED = tonumber(minetest.get_mapgen_setting("seed") or "") or 0

-- Path detector of the optional pathv7 mod. pathv7 paints its paths
-- wherever one of four 2D Perlin noises changes sign between two
-- adjacent columns; the noises are pure functions of (world seed,
-- position), so recomputing them here reproduces the path network with
-- no map access. The parameter tables are copied verbatim from
-- pathv7/init.lua (any change there changes the paths and this
-- detector must follow). minetest.get_perlin(key) creates a perlin
-- object from a full noise parameter table INCLUDING its own seed
-- field, and the world seed only enters through the seed offset
-- param, exactly like a register_decoration noise. When pathv7 is not
-- installed the probe stays nil and every affinity code path is dead.
local path_noise = nil
if minetest.get_modpath("pathv7") and minetest.get_perlin then
    local seed = tonumber(minetest.get_mapgen_setting("seed") or "") or 0
    path_noise = {}
    for _, np in ipairs({
        {offset = 0, scale = 1, spread = {x = 1024, y = 1024, z = 1024},
            seed = 11711, octaves = 3, persist = 0.4},
        {offset = 0, scale = 1, spread = {x = 2048, y = 2048, z = 2048},
            seed = -8017, octaves = 4, persist = 0.4},
        {offset = 0, scale = 1, spread = {x = 4096, y = 4096, z = 4096},
            seed = 300707, octaves = 5, persist = 0.4},
        {offset = 0, scale = 1, spread = {x = 8192, y = 8192, z = 8192},
            seed = -80033, octaves = 6, persist = 0.4},
    }) do
        -- get_perlin(np, seed) derives a world specific perlin; the
        -- per-node get2d calls are the expensive part, one per probe
        path_noise[#path_noise + 1] = minetest.get_perlin(np, seed)
    end
end

-- True when a pathv7 path crosses the column (x, z) or one of its 4
-- neighbours, mirroring the sign change detection of pathv7 itself
-- (it paints where a noise changes sign between (x,z) and (x+1,z) or
-- (x,z) and (x,z+1), so the painted brush spans up to 2 nodes around
-- the crossing). Cheap enough for a coarse scan: 4 noises x a handful
-- of nodes
local function path_at(x, z)
    if not path_noise then
        return false
    end
    for _, n in ipairs(path_noise) do
        local c = n:get2d({x = x, y = z})
        if c * n:get2d({x = x + 1, y = z}) <= 0 then
            return true
        end
        if c * n:get2d({x = x, y = z + 1}) <= 0 then
            return true
        end
    end
    return false
end

-- Nearest path point around (x, z) within radius (nil when none);
-- only the EXISTENCE matters (the village grows when a path runs
-- near, the core is not moved). A pathv7 path is a zero crossing
-- CURVE of one of the noises; the half wavelengths are 512 nodes and
-- up, so between two probes spaced 8 nodes a sign change of a noise
-- means a crossing inside the segment. The scan walks the rows then
-- the columns of the square window on a step 8 grid, detects the sign
-- changes between consecutive probes and takes the segment midpoint
-- as the path point. Bounded work: 2 * (2r/8 + 1)^2 probes per noise,
-- once per village cell and per session
local function nearest_path(x, z, radius)
    if not path_noise then
        return nil
    end
    local best, bd = nil, radius * radius + 1
    local function consider(px, pz)
        local dd = (px - x) * (px - x) + (pz - z) * (pz - z)
        if dd < bd then
            best, bd = {px, pz}, dd
        end
    end
    for _, n in ipairs(path_noise) do
        -- rows (z fixed), scanning x probe by probe
        for rz = z - radius, z + radius, 8 do
            local prev = n:get2d({x = x - radius, y = rz})
            for px = x - radius + 8, x + radius, 8 do
                local cur = n:get2d({x = px, y = rz})
                if prev * cur <= 0 then
                    consider(px - 4, rz)
                end
                prev = cur
            end
        end
        -- columns (x fixed), scanning z probe by probe
        for px = x - radius, x + radius, 8 do
            local prev = n:get2d({x = px, y = z - radius})
            for pz = z - radius + 8, z + radius, 8 do
                local cur = n:get2d({x = px, y = pz})
                if prev * cur <= 0 then
                    consider(px, pz - 4)
                end
                prev = cur
            end
        end
    end
    return best
end

-- Civic drawings (registered building names, see the *buildings.lua
-- data files): preferred, never forced, for the slots close to the
-- core. Extensible at will without touching the data files.
V.civic = {
    desertwell = true, desertmarket = true, deserstable = true,
    grasslandpond = true, grasslandstable = true,
    savannawell = true, savannapond = true, savannastable = true,
    savannalogs = true,
    lakeharbour = true, lakefishtrap = true,
    icelogs = true, icepelts = true, icesledge = true,
}

-- In-memory plan cache, one entry per visited cell and session. The
-- plans are tiny (a dozen slots); a mapgen chunk is only generated
-- once, so there is nothing to invalidate and no eviction needed
local plans = {}

-- Cell coordinates -> sequence for PcgRandom(seed, sequence): the
-- offsets keep it positive and under 2^32 over the whole playable
-- world (±31000 nodes = ±61 cells of 512 at the smallest grid), so no
-- Lua precision loss can desynchronise two chunks of one village
local function cell_sequence(cx, cz)
    return (cx + 32768) * 65536 + (cz + 32768)
end

-- Village plan of one cell: false when the cell carries no village,
-- otherwise { nx = ..., nz = ..., slots = { {x, z, rot, civic}, ... } }
-- in a stable draw order. PURE and cached: two fragments of the same
-- village read the exact same table, whatever their generation order.
function V.plan(cx, cz)
    local key = cx .. "," .. cz
    if plans[key] ~= nil then
        return plans[key]
    end
    local rng = PcgRandom(SEED, cell_sequence(cx, cz))
    local plan
    -- integer comparison: village when the draw falls strictly below
    -- chance * 1e6, so chance = 1 really elects EVERY cell (a float
    -- division could round 999999/999999 to exactly 1.0 and reject)
    if rng:next(0, 999999) >= CHANCE * 1000000 then
        plan = false
    else
        local m = R_MAX + EDGE_MARGIN
        local nx = cx * REGION + m + rng:next(0, REGION - 2 * m)
        local nz = cz * REGION + m + rng:next(0, REGION - 2 * m)
        -- Path boost (pathv7): the core KEEPS its uniform position
        -- (villages stand anywhere), but when a path runs within
        -- PATH_RANGE of it the village GROWS: bonus slots spread on a
        -- wider disk, a market town along the road versus a hamlet in
        -- the wilds. The widened disk stays inside the shrunk cell
        -- thanks to the EDGE_MARGIN reserved around the core (the
        -- margin is sized on R_MAX, and the boosted radius is
        -- clamped below R_MAX + EDGE_MARGIN / 2 so the disk plus its
        -- slots never crosses the cell borders). Slots drawn ON the
        -- path are still rejected by the ground test of placement.lua
        -- (path wood is not a ground node): the road stays clear, the
        -- houses grow AROUND it
        local near_path = prefer_paths
            and nearest_path(nx, nz, PATH_RANGE) ~= nil
        local n_slots = SLOTS
        local r_min, r_max = R_MIN, R_MAX
        if near_path then
            n_slots = SLOTS + PATH_BONUS_SLOTS
            r_max = math.min(R_MAX + EDGE_MARGIN / 2,
                REGION / 2 - EDGE_MARGIN)
        end
        local slots = {}
        for i = 1, n_slots do
            local x, z, dist
            -- bounded redraws so two slots of one plan keep
            -- SLOT_MIN_DIST between them; after the bound the last
            -- draw stands (better a possibly close slot than an empty
            -- village, the anti-collision settles the rest)
            for _ = 1, 16 do
                local u = rng:next(0, 999999) / 999999
                local a = rng:next(0, 999999) / 999999 * 2 * math.pi
                dist = r_min + (r_max - r_min) * math.sqrt(u)
                x = nx + math.floor(dist * math.cos(a) + 0.5)
                z = nz + math.floor(dist * math.sin(a) + 0.5)
                local far = true
                for j = 1, i - 1 do
                    if math.abs(slots[j].x - x) + math.abs(slots[j].z - z)
                        < SLOT_MIN_DIST then
                        far = false
                        break
                    end
                end
                if far then
                    break
                end
            end
            slots[i] = {
                x = x,
                z = z,
                rot = rng:next(0, 3) * 90,
                civic = dist < CIVIC_RADIUS,
            }
        end
        plan = {
            nx = nx, nz = nz, slots = slots,
            -- plan identity for the per slot PRNG of placement.lua:
            -- PcgRandom(plan.seed, plan.seq + slot index)
            seed = SEED,
            seq = cell_sequence(cx, cz),
            near_path = near_path, -- debug: village boosted by a pathv7 path
        }
    end
    plans[key] = plan
    return plan
end

-- Cells whose village zone can touch the XZ rectangle of a generated
-- fragment. A village disk never leaves its own cell (see EDGE_MARGIN),
-- so the candidates are the cell of each fragment corner plus the
-- neighbours, filtered by an exact rectangle overlap test. The caller
-- only keeps the slots whose POINT falls inside its own fragment: this
-- gives every slot exactly one host fragment, whatever the generation
-- order of the chunks, with no double placement and no orphan.
function V.cells_overlapping(minp, maxp)
    local out = {}
    for cx = math.floor(minp.x / REGION) - 1, math.floor(maxp.x / REGION) + 1 do
        for cz = math.floor(minp.z / REGION) - 1, math.floor(maxp.z / REGION) + 1 do
            local x1 = cx * REGION + EDGE_MARGIN
            local z1 = cz * REGION + EDGE_MARGIN
            local x2 = (cx + 1) * REGION - EDGE_MARGIN
            local z2 = (cz + 1) * REGION - EDGE_MARGIN
            if x1 <= maxp.x and x2 >= minp.x
                and z1 <= maxp.z and z2 >= minp.z then
                out[#out + 1] = { cx = cx, cz = cz }
            end
        end
    end
    return out
end

-- Consumed by placement.lua (startup log, scatter scaling, host tests)
V.enabled = enabled
V.region = REGION
-- Path boost flag, exposed for the placement engine logs
V.prefer_paths = prefer_paths
