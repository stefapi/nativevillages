-- Centralised spawning layer of nativevillages.
--
-- Two complementary population channels share this module:
--   * deterministic population (Spawn.populate): called by the deferred
--     placement jobs of placement.lua right after a schematic is
--     committed to the map, it scans the placed footprint for beds,
--     native trigger nodes and anvils and adds one matching entity per
--     detected node (male/female alternated, capped per building).
--     This is what makes bed-only houses inhabited even though beds
--     were never statistical spawn neighbours.
--   * statistical neighbours (Spawn.neighbors_for): enriches the
--     mobs:spawn neighbours lists of the *creatures.lua files with every
--     bed node of the running game, resolved dynamically once all mods
--     are loaded, so the historical ABM channel also fills bed-only
--     houses (including the buildings placed by the historical
--     register_decoration fallback, which the deterministic channel
--     cannot see).
--
-- Bed detection is deliberately DYNAMIC: the bed nodes differ per game
-- (dreambuilder_game registers beds:bed_bottom/top and
-- beds:fancy_bed_bottom/top, mineclonia only aliases beds:bed_* to
-- mcl_beds:bed_red_* and offers mcl_beds:bed_<colour>_* variants,
-- colorful_beds registers colorful_beds:<colour>_{,fancy_}bed_*), so
-- the list is built at register_on_mods_loaded time by walking
-- minetest.registered_nodes (known bed mod prefixes or a bed group)
-- instead of a frozen node list. A bare "_bottom"/"_top" suffix is NOT
-- a sufficient criterion: doors, double plants and growing crops share
-- it. Anvils are detected by name ("anvil" substring, covering
-- anvil:anvil and mcl_anvils:anvil_damage_*).
--
-- populate() is purely additive: it returns silently when the
-- nativevillages.deterministic_spawn setting is disabled, when the job
-- carries no footprint box, when the area is not emerged or when the
-- building category is unknown, so disabling it restores the exact
-- historical behaviour.

nativevillages = nativevillages or {}

local Spawn = {}
nativevillages.spawn = Spawn

-- Cap of entities deterministically added per placed building (beds
-- first, then native trigger nodes, then anvils; raise or lower this
-- local to tune the village liveliness)
local max_entities_per_building = 8

-- Minimum Manhattan distance, in nodes, enforced between two entities
-- added by populate() to the same building (anti stacking net)
local min_spawn_distance = 1

local deterministic_spawn = minetest.settings:get_bool(
    "nativevillages.deterministic_spawn", true)
local debug_spawn = minetest.settings:get_bool(
    "nativevillages.debug_placement", false)

-- Dynamic node lists, filled once every mod has registered its nodes
Spawn.bed_nodes = {}   -- sorted list, for the statistical neighbours
Spawn.anvil_nodes = {} -- sorted list, for the deterministic scan
local bed_set = {}     -- O(1) lookup companion of Spawn.bed_nodes

-- Static bed mod prefixes, used both as the runtime detection
-- criterion and as the fallback before register_on_mods_loaded ran
local bed_prefixes = {"beds:", "mcl_beds:", "colorful_beds:", "bed:"}

function Spawn.is_bed(name)
	if bed_set[name] then
		return true
	end
	for _, prefix in ipairs(bed_prefixes) do
		if name:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

function Spawn.is_anvil(name)
	return name:find("anvil", 1, true) ~= nil
end

-- Biome category of a building, from its registered name prefix
-- (grasslandhouse1, deserthouse2, savannawitchhouse, lakeharbour,
-- icehouse3, junglehouse1: the jungle buildings carry historical
-- cannibal* schematic file names but jungle* registered names)
local building_prefixes = {
	grassland = "grassland",
	desert = "desert",
	savanna = "savanna",
	lake = "lake",
	ice = "arctic",
	jungle = "jungle",
	cannibal = "jungle",
}

function Spawn.building_biome(building_name)
	for prefix, category in pairs(building_prefixes) do
		if building_name:sub(1, #prefix) == prefix then
			return category
		end
	end
	return nil
end

-- Trigger node -> mobs of the mod, mirroring the historical mobs:spawn
-- associations of the *creatures.lua files. Extend at will: every node
-- listed here gets one mob per occurrence when populate() scans a
-- placed building (alternated when several mobs are listed)
Spawn.trigger_mobs = {
	["nativevillages:grasslandbarrel"] = {
		"nativevillages:grasslandfemale", "nativevillages:grasslandmale"},
	["nativevillages:cowdropping"] = {"nativevillages:grasslandcow"},
	["nativevillages:grasslandaltar"] = {"nativevillages:grasslandwitch"},
	["nativevillages:desertcrpet"] = {
		"nativevillages:desertvillagermale", "nativevillages:desertvillagerfemale"},
	["nativevillages:hookah"] = {
		"nativevillages:desertranger", "nativevillages:desertraider"},
	["nativevillages:desertcage"] = {"nativevillages:desertslavetrader"},
	["nativevillages:desertseeds"] = {"nativevillages:desertchicken"},
	["nativevillages:savannavessels"] = {
		"nativevillages:savannamale", "nativevillages:savannafemale"},
	["nativevillages:savannathrone"] = {
		"nativevillages:savannaking", "nativevillages:savannaqueen"},
	["nativevillages:savannavshrine"] = {"nativevillages:savannadoctor"},
	["nativevillages:savannacorpse"] = {
		"nativevillages:malelion", "nativevillages:femalelion"},
	["nativevillages:hangingfish"] = {
		"nativevillages:lakevillagerfemale", "nativevillages:lakevillagermale"},
	["nativevillages:fishtrap"] = {"nativevillages:lakevillagerfisher"},
	["nativevillages:blanket"] = {
		"nativevillages:icevillagerfemale", "nativevillages:icevillagermale"},
	["nativevillages:sledge"] = {
		"nativevillages:icedog", "nativevillages:icesledgetrader"},
	["nativevillages:cannibalshrine"] = {
		"nativevillages:cannibalking", "nativevillages:cannibalarcher"},
	["nativevillages:driedpeople"] = {
		"nativevillages:cannibalmurderer", "nativevillages:cannibalchild"},
}

-- Bed inhabitants per biome category, male/female alternated by
-- populate() (extend at will)
Spawn.bed_mobs = {
	grassland = {"nativevillages:grasslandmale", "nativevillages:grasslandfemale"},
	desert = {"nativevillages:desertvillagermale", "nativevillages:desertvillagerfemale"},
	savanna = {"nativevillages:savannamale", "nativevillages:savannafemale"},
	lake = {"nativevillages:lakevillagermale", "nativevillages:lakevillagerfemale"},
	arctic = {"nativevillages:icevillagermale", "nativevillages:icevillagerfemale"},
	jungle = {"nativevillages:cannibalmurderer", "nativevillages:cannibalchild"},
}

-- Anvil worker per biome category: the generic male villager of the
-- biome (the jungle forges get a cannibalarcher, its guard)
Spawn.anvil_mobs = {
	grassland = "nativevillages:grasslandmale",
	desert = "nativevillages:desertvillagermale",
	savanna = "nativevillages:savannamale",
	lake = "nativevillages:lakevillagermale",
	arctic = "nativevillages:icevillagermale",
	jungle = "nativevillages:cannibalarcher",
}

-- Neighbours list for the statistical mobs:spawn calls of the
-- *creatures.lua files: the historical native trigger plus every bed
-- node of the running game, so bed-only houses can also trigger the
-- statistical channel. Called from inside register_on_mods_loaded
-- callbacks of those files (Spawn.bed_nodes is final by then, because
-- the callback below is registered first); degrades to the historical
-- single trigger list on games without any registered bed.
function Spawn.neighbors_for(trigger)
	local list = {trigger}
	for _, bed in ipairs(Spawn.bed_nodes) do
		list[#list + 1] = bed
	end
	return list
end

-- Resolve the dynamic bed and anvil node lists once every mod (hence
-- every game specific bed implementation) has registered its nodes.
-- This callback is registered before the ones the *creatures.lua files
-- wrap around their mobs:spawn calls, so Spawn.bed_nodes is already
-- final when their neighbours lists are built.
minetest.register_on_mods_loaded(function()
	for name, def in pairs(minetest.registered_nodes) do
		local groups = def.groups or {}
		local is_bed_node = (groups.bed and groups.bed > 0)
			or Spawn.is_bed(name)
		if is_bed_node and not bed_set[name] then
			bed_set[name] = true
			Spawn.bed_nodes[#Spawn.bed_nodes + 1] = name
		end
		if Spawn.is_anvil(name) then
			Spawn.anvil_nodes[#Spawn.anvil_nodes + 1] = name
		end
	end
	table.sort(Spawn.bed_nodes)
	table.sort(Spawn.anvil_nodes)
	if debug_spawn then
		minetest.log("action", "[nativevillages] spawn layer: "
			.. #Spawn.bed_nodes .. " bed nodes, "
			.. #Spawn.anvil_nodes .. " anvil nodes detected")
	end
end)

-- Deterministic population of one placed building, called from the
-- deferred placement queue of placement.lua (minetest.after(0), once
-- the schematic is committed to the map). Purely additive: silent
-- no-op on disabled setting, missing job box, un-emerged area or
-- unknown building category.
function Spawn.populate(job)
	if not deterministic_spawn then
		return
	end
	if not job or not job.box or not job.name then
		return
	end
	local category = Spawn.building_biome(job.name)
	if not category then
		return
	end
	local box = job.box

	-- un-emerged footprints are skipped silently (get_node answers
	-- "ignore" there and the scan could not run)
	if minetest.get_node({x = box.x1, y = box.y1, z = box.z1}).name == "ignore"
			or minetest.get_node({x = box.x2, y = box.y2, z = box.z2}).name == "ignore" then
		return
	end

	-- every node populate() cares about, in one grouped scan
	local search = {}
	for _, name in ipairs(Spawn.bed_nodes) do
		search[#search + 1] = name
	end
	for _, name in ipairs(Spawn.anvil_nodes) do
		search[#search + 1] = name
	end
	for name in pairs(Spawn.trigger_mobs) do
		search[#search + 1] = name
	end
	if #search == 0 then
		return
	end

	local ok, found = pcall(minetest.find_nodes_in_area,
		{x = box.x1, y = box.y1, z = box.z1},
		{x = box.x2, y = box.y2, z = box.z2},
		search, true)
	if not ok or type(found) ~= "table" then
		return
	end

	local placed_positions = {}
	local placed_count = 0
	local flip = 0 -- male/female alternation, shared by every pass

	-- a free standing spot around a node: one of the four sides, or on
	-- top as the fallback, with an air-like node and a walkable floor
	local function standing_spot(pos)
		local candidates = {
			{x = pos.x + 1, y = pos.y, z = pos.z},
			{x = pos.x - 1, y = pos.y, z = pos.z},
			{x = pos.x, y = pos.y, z = pos.z + 1},
			{x = pos.x, y = pos.y, z = pos.z - 1},
			{x = pos.x, y = pos.y + 1, z = pos.z},
		}
		for _, p in ipairs(candidates) do
			local node = minetest.get_node(p)
			local def = minetest.registered_nodes[node.name]
			-- unknown nodes are treated as blocking (conservative)
			if def and not def.walkable then
				local floor = minetest.get_node(
					{x = p.x, y = p.y - 1, z = p.z})
				local fdef = minetest.registered_nodes[floor.name]
				if fdef and fdef.walkable then
					return p
				end
			end
		end
		return nil
	end

	-- anti stacking net: keep at least min_spawn_distance nodes of
	-- Manhattan distance between two entities of the same building
	local function far_enough(pos)
		for _, p in ipairs(placed_positions) do
			if math.abs(p.x - pos.x) + math.abs(p.y - pos.y)
					+ math.abs(p.z - pos.z) <= min_spawn_distance then
				return false
			end
		end
		return true
	end

	local function add_mob(spot, mob_name)
		local entity = minetest.add_entity(
			{x = spot.x + 0.5, y = spot.y, z = spot.z + 0.5}, mob_name)
		if entity then
			placed_positions[#placed_positions + 1] = spot
			placed_count = placed_count + 1
			return true
		end
		return false
	end

	local function alternate(list)
		flip = flip + 1
		return list[(flip % #list) + 1]
	end

	-- beds are counted by their foot half only, so a two node bed adds
	-- a single inhabitant (single node beds count as their own foot)
	local function is_bed_foot(name)
		if not Spawn.is_bed(name) then
			return false
		end
		if name:sub(-4) == "_top" then
			return false
		end
		return true
	end

	-- 1) beds: one inhabitant per bed, male/female alternated
	local bed_mobs = Spawn.bed_mobs[category]
	if bed_mobs then
		for name, positions in pairs(found) do
			if is_bed_foot(name) then
				for _, pos in ipairs(positions) do
					if placed_count >= max_entities_per_building then
						break
					end
					local spot = standing_spot(pos)
					if spot and far_enough(spot) then
						add_mob(spot, alternate(bed_mobs))
					end
				end
			end
		end
	end

	-- 2) native trigger nodes: one mob per occurrence, alternating
	-- when the trigger lists several mobs
	for name, positions in pairs(found) do
		local mob_list = Spawn.trigger_mobs[name]
		if mob_list then
			for _, pos in ipairs(positions) do
				if placed_count >= max_entities_per_building then
					break
				end
				local spot = standing_spot(pos)
				if spot and far_enough(spot) then
					add_mob(spot, alternate(mob_list))
				end
			end
		end
	end

	-- 3) anvils: one generic villager of the biome per anvil
	local anvil_mob = Spawn.anvil_mobs[category]
	if anvil_mob then
		for name, positions in pairs(found) do
			if Spawn.is_anvil(name) then
				for _, pos in ipairs(positions) do
					if placed_count >= max_entities_per_building then
						break
					end
					local spot = standing_spot(pos)
					if spot and far_enough(spot) then
						add_mob(spot, anvil_mob)
					end
				end
			end
		end
	end

	if debug_spawn and placed_count > 0 then
		minetest.log("action", "[nativevillages] populated " .. job.name
			.. " with " .. placed_count .. " entit"
			.. (placed_count == 1 and "y" or "ies"))
	end
end
