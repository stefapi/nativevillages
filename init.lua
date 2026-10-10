
-- Initialize nativevillages namespace
nativevillages = {}

local path = minetest.get_modpath(minetest.get_current_modname()) .. "/"

local S = minetest.get_translator("nativevillages")


-- Check for custom mob spawn file (custom_spawn.lua; the mod's own
-- spawn.lua is the centralised spawning layer, NOT an override)
local input = io.open(path .. "custom_spawn.lua", "r")

if input then
	mobs.custom_spawn_nativevillages = true
	input:close()
	input = nil
end


-- Biome resolution layer (must load before the buildings files so that
-- nativevillages.biomes.get() / get_ground() are available)
dofile(path .. "biomes.lua") --

-- Soil adaptation of the placed schematics to the anchor biome (must load
-- after biomes.lua, which it consumes, and before placement.lua, which
-- consumes nativevillages.soil in turn)
dofile(path .. "soil_replacement.lua") --

-- Furniture variation of the placed houses (must load after
-- soil_replacement.lua, whose pattern it mirrors, and before
-- placement.lua, which consumes nativevillages.deco in turn)
dofile(path .. "deco_replacement.lua") --

-- Placement engine and building factory (must load before the buildings
-- files so that nativevillages.placement.register_building() is available)
dofile(path .. "placement.lua") --

-- Deterministic village zones (must load after placement.lua, whose
-- on_generated consumes nativevillages.village, and before the
-- *buildings.lua files it counts the civic drawings of)
dofile(path .. "village_zones.lua") --

-- Centralised spawning layer (must load after placement.lua, whose
-- deferred jobs call nativevillages.spawn.populate(), and before the
-- *creatures.lua files, whose mobs:spawn calls use
-- nativevillages.spawn.neighbors_for() inside register_on_mods_loaded)
dofile(path .. "spawn.lua") --

-- Hidden randungeon entrances under the village houses (must load
-- after placement.lua, whose run_job calls
-- nativevillages.dungeon.maybe_place_hidden_entrance(); its randungeon
-- global probe is lazy, randungeon itself loads after this mod)
dofile(path .. "dungeon_entrances.lua") --

-- Buildings


dofile(path .. "cannibalblocks.lua") --
dofile(path .. "savannablocks.lua") --
dofile(path .. "arcticblocks.lua") --
dofile(path .. "grasslandblocks.lua") --
dofile(path .. "lakeblocks.lua") --
dofile(path .. "desertblocks.lua") --
dofile(path .. "junglebuildings.lua") --
dofile(path .. "icebuildings.lua") --
dofile(path .. "grasslandbuildings.lua") --
dofile(path .. "lakebuildings.lua") --
dofile(path .. "desertbuildings.lua") --
dofile(path .. "savannabuildings.lua") --
dofile(path .. "grasslandcreatures.lua") --
dofile(path .. "junglecreatures.lua") --
dofile(path .. "arcticcreatures.lua") --
dofile(path .. "savannacreatures.lua") --
dofile(path .. "lakecreatures.lua") --
dofile(path .. "desertcreatures.lua") --
dofile(path .. "slavecreatures.lua") --
dofile(path .. "buyablestuff.lua") --
dofile(path .. "explodingtoad.lua") --
dofile(path .. "hunger.lua") --


-- Load custom spawning
if mobs.custom_spawn_nativevillages then
	dofile(path .. "custom_spawn.lua")
end



print (S("[MOD] Buildings loaded"))
