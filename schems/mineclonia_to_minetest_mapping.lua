-- =================================================================================
-- MAPPING MINECOLONIA → MINETEST pour Native Villages
-- Version organisée et optimisée pour les mods installés
-- =================================================================================
-- MODS UTILISÉS :
-- - moretrees : bois variés et spécialisés (13 types d'arbres)
-- - moreblocks : formes avancées (escaliers, dalles, panneaux)
-- - cottages : éléments de village authentiques
-- - flowerpot : pots de fleurs décoratifs
-- - beds : lits colorés
-- - nether : blocs du Nether authentiques
-- - ocean : corail et éléments océaniques
-- - itemframes : cadres et présentoirs
-- - walls : murs décoratifs
-- - xpanes : vitres et panneaux
-- - anvil, bell, tnt : éléments fonctionnels
-- =================================================================================

local mineclonia_mapping = {

    -- ===========================================
    -- BLOCS DE BASE - Respectent les biomes Minetest
    -- ===========================================
    ["mcl_core:stone"] = "default:stone",
    ["mcl_core:cobble"] = "default:cobble",
    ["mcl_core:stonebrick"] = "default:stonebrick",
    ["mcl_core:stonebrickcarved"] = "default:stonebrick",
    ["mcl_core:stonebrickcracked"] = "default:stonebrick",
    ["mcl_core:stonebrickmossy"] = "default:mossycobble",
    ["mcl_core:stone_smooth"] = "default:stone_block",
    ["mcl_core:andesite_smooth"] = "default:stone_block",
    ["mcl_core:diorite_smooth"] = "default:stone_block",
    ["mcl_core:granite_smooth"] = "default:stone_block",
    ["mcl_core:mossycobble"] = "default:mossycobble",
    ["mcl_core:obsidian"] = "default:obsidian",
    ["mcl_core:crying_obsidian"] = "default:obsidian",
    ["mcl_core:bedrock"] = "default:stone",

    -- ===========================================
    -- BLOCS DE BASE - Sable et argile
    -- ===========================================
    ["mcl_core:sand"] = "default:sand",
    ["mcl_core:sandstone"] = "default:sandstone",
    ["mcl_core:sandstonesmooth"] = "default:sandstone_block",
    ["mcl_core:sandstonesmooth2"] = "default:sandstone_block",
    ["mcl_core:sandstonecarved"] = "default:sandstone_block",
    ["mcl_core:gravel"] = "default:gravel",
    ["mcl_core:coarse_dirt"] = "default:dirt",
    ["mcl_colorblocks:hardened_clay"] = "bakedclay:terracotta_natural",
    ["mcl_colorblocks:hardened_clay_orange"] = "bakedclay:terracotta_orange",
    ["mcl_colorblocks:hardened_clay_red"] = "bakedclay:terracotta_red",
    ["mcl_colorblocks:hardened_clay_yellow"] = "bakedclay:terracotta_yellow",

    -- ===========================================
    -- BOIS - Utilise moretrees pour variété (fallback default)
    -- ===========================================
    ["mcl_core:tree"] = "moretrees:oak_trunk",  -- chêne moretrees
    ["mcl_core:wood"] = "moretrees:oak_planks",  -- planches chêne moretrees
    ["mcl_trees:wood_oak"] = "moretrees:oak_planks",
    ["mcl_trees:wood_birch"] = "moretrees:birch_planks",
    ["mcl_trees:wood_dark_oak"] = "moretrees:oak_planks",  -- approximation
    ["mcl_core:birchwood"] = "moretrees:birch_planks",
    ["mcl_core:darkwood"] = "moretrees:oak_planks",
    ["mcl_core:junglewood"] = "moretrees:junglewood_planks",
    ["mcl_core:sprucewood"] = "moretrees:spruce_planks",
    ["mcl_trees:tree_oak"] = "moretrees:oak_trunk",
    ["mcl_trees:tree_dark_oak"] = "moretrees:oak_trunk",
    ["mcl_trees:tree_spruce"] = "moretrees:spruce_trunk",
    ["mcl_trees:bark_dark_oak"] = "moretrees:oak_trunk",
    ["mcl_trees:stripped_dark_oak"] = "moretrees:oak_planks",
    ["mcl_trees:stripped_oak"] = "moretrees:oak_planks",
    ["mcl_trees:stripped_spruce"] = "moretrees:spruce_planks",
    ["mcl_trees:stripped_spruce_bark"] = "moretrees:spruce_planks",
    ["mcl_trees:sapling_dark_oak"] = "default:sapling",  -- jeune pousse chêne sombre

    -- ===========================================
    -- BLOCS DE BASE - Métaux et minéraux
    -- ===========================================
    ["mcl_core:ironblock"] = "default:steelblock",
    ["mcl_core:goldblock"] = "default:goldblock",
    ["mcl_core:diamondblock"] = "default:diamondblock",
    ["mcl_core:emeraldblock"] = "default:diamondblock",
    ["mcl_raw_ores:raw_iron_block"] = "default:steelblock",
    ["mcl_raw_ores:raw_gold_block"] = "default:goldblock",

    -- ===========================================
    -- BLOCS DE BASE - Terre et végétation
    -- ===========================================
    ["mcl_core:dirt"] = "default:dirt",
    ["mcl_core:dirt_with_grass"] = "default:dirt_with_grass",
    ["mcl_core:leaves"] = "moretrees:oak_leaves",  -- feuilles chêne moretrees
    ["mcl_trees:leaves_oak"] = "moretrees:oak_leaves",
    ["mcl_trees:leaves_dark_oak"] = "moretrees:oak_leaves",
    ["mcl_core:jungleleaves"] = "moretrees:jungleleaves",  -- feuilles jungle moretrees
    ["mcl_core:vine"] = "default:vine",
    ["mcl_core:deadbush"] = "default:dry_shrub",
    ["mcl_core:reeds"] = "default:papyrus",

    -- ===========================================
    -- BLOCS DE BASE - Liquides
    -- ===========================================
    ["mcl_core:water_source"] = "default:water_source",
    ["mcl_core:water_flowing"] = "default:water_flowing",
    ["mcl_core:lava_source"] = "default:lava_source",
    ["mcl_core:lava_flowing"] = "default:lava_flowing",

    -- ===========================================
    -- BLOCS DE BASE - Divers (verre coloré)
    -- ===========================================
    ["mcl_core:glass"] = "stained_glass:clear",  -- verre transparent
    ["mcl_core:glass_black"] = "stained_glass:black",
    ["mcl_core:glass_blue"] = "stained_glass:blue",
    ["mcl_core:glass_green"] = "stained_glass:green",
    ["mcl_core:glass_light_blue"] = "stained_glass:light_blue",
    ["mcl_core:glass_magenta"] = "stained_glass:magenta",
    ["mcl_core:glass_purple"] = "stained_glass:purple",
    ["mcl_core:cobweb"] = "default:cobweb",
    ["mcl_core:ladder"] = "default:ladder",
    ["mcl_core:snowblock"] = "default:snowblock",
    ["mcl_core:packed_ice"] = "default:ice",

    -- ===========================================
    -- BLOCS DE CONSTRUCTION - Briques et matériaux spécialisés
    -- ===========================================
    ["mcl_core:brick_block"] = "moreblocks:brick",  -- briques standard améliorées
    ["mcl_nether:nether_brick"] = "nether:nether_brick",  -- briques du nether authentiques
    ["mcl_nether:red_nether_brick"] = "nether:red_nether_brick",
    ["mcl_end:end_bricks"] = "moreblocks:stonebrick",  -- briques de l'End
    ["mcl_end:end_stone"] = "moreblocks:stone",  -- pierre de l'End
    ["mcl_end:purpur_block"] = "moreblocks:stonebrick",  -- bloc de purpur
    ["mcl_end:purpur_pillar"] = "moreblocks:stonebrick",  -- pilier de purpur

    -- ===========================================
    -- BLOCS DE CONSTRUCTION - Laine
    -- ===========================================
    ["mcl_wool:white"] = "wool:white",
    ["mcl_wool:black"] = "wool:black",
    ["mcl_wool:blue"] = "wool:blue",
    ["mcl_wool:brown"] = "wool:brown",
    ["mcl_wool:cyan"] = "wool:cyan",
    ["mcl_wool:grey"] = "wool:grey",
    ["mcl_wool:green"] = "wool:green",
    ["mcl_wool:light_blue"] = "wool:white",  -- approximation
    ["mcl_wool:lime"] = "wool:green",
    ["mcl_wool:orange"] = "wool:orange",
    ["mcl_wool:pink"] = "wool:pink",
    ["mcl_wool:purple"] = "wool:violet",
    ["mcl_wool:red"] = "wool:red",
    ["mcl_wool:silver"] = "wool:grey",
    ["mcl_wool:yellow"] = "wool:yellow",

    -- ===========================================
    -- BLOCS DE CONSTRUCTION - Tapis (mod carpets spécialisé)
    -- ===========================================
    -- Utilise le mod carpets pour des tapis spécialisés
    ["mcl_wool:white_carpet"] = "carpets:carpet_white",
    ["mcl_wool:black_carpet"] = "carpets:carpet_black",
    ["mcl_wool:blue_carpet"] = "carpets:carpet_blue",
    ["mcl_wool:brown_carpet"] = "carpets:carpet_brown",
    ["mcl_wool:cyan_carpet"] = "carpets:carpet_cyan",
    ["mcl_wool:grey_carpet"] = "carpets:carpet_grey",
    ["mcl_wool:green_carpet"] = "carpets:carpet_green",
    ["mcl_wool:light_blue_carpet"] = "carpets:carpet_white",  -- approximation
    ["mcl_wool:lime_carpet"] = "carpets:carpet_green",
    ["mcl_wool:orange_carpet"] = "carpets:carpet_orange",
    ["mcl_wool:pink_carpet"] = "carpets:carpet_pink",
    ["mcl_wool:purple_carpet"] = "carpets:carpet_violet",
    ["mcl_wool:red_carpet"] = "carpets:carpet_red",
    ["mcl_wool:silver_carpet"] = "carpets:carpet_grey",
    ["mcl_wool:yellow_carpet"] = "carpets:carpet_yellow",

    -- ===========================================
    -- BLOCS DE CONSTRUCTION - Béton (approximation)
    -- ===========================================
    ["mcl_colorblocks:concrete_grey"] = "default:stone",
    ["mcl_colorblocks:concrete_light_blue"] = "default:stone",
    ["mcl_colorblocks:concrete_orange"] = "default:stone",
    ["mcl_colorblocks:concrete_red"] = "default:stone",
    ["mcl_colorblocks:concrete_silver"] = "default:stone",
    ["mcl_colorblocks:concrete_white"] = "default:stone",

    -- ===========================================
    -- BLOCS DE CONSTRUCTION - Terrecuite (bakedclay mod)
    -- ===========================================
    ["mcl_colorblocks:glazed_terracotta_purple"] = "bakedclay:terracotta_natural",

    -- ===========================================
    -- PORTES ET FENÊTRES - Utilisent moretrees pour bois variés
    -- ===========================================
    -- Portes en bois de moretrees pour variété
    ["mcl_doors:wooden_door_b_1"] = "moretrees:oak_door_b",  -- porte chêne moretrees
    ["mcl_doors:wooden_door_t_1"] = "moretrees:oak_door_t",
    ["mcl_doors:door_oak_b_1"] = "moretrees:oak_door_b",
    ["mcl_doors:door_oak_t_1"] = "moretrees:oak_door_t",
    ["mcl_doors:door_oak_b_2"] = "moretrees:oak_door_b",
    ["mcl_doors:door_oak_t_2"] = "moretrees:oak_door_t",
    ["mcl_doors:door_birch_b_1"] = "moretrees:birch_door_b",  -- porte bouleau moretrees
    ["mcl_doors:door_birch_t_1"] = "moretrees:birch_door_t",
    ["mcl_doors:iron_door_b_1"] = "doors:door_steel_b",  -- portes acier standard
    ["mcl_doors:iron_door_t_1"] = "doors:door_steel_t",
    ["mcl_doors:dark_oak_door_b_1"] = "moretrees:oak_door_b",  -- approximation chêne
    ["mcl_doors:dark_oak_door_t_1"] = "moretrees:oak_door_t",
    ["mcl_doors:spruce_door_b_2"] = "moretrees:spruce_door_b",  -- porte épicéa moretrees
    ["mcl_doors:spruce_door_t_2"] = "moretrees:spruce_door_t",

    -- Trapdoors en bois de moretrees pour variété
    ["mcl_doors:trapdoor"] = "moretrees:oak_trapdoor",  -- trappe chêne moretrees
    ["mcl_doors:trapdoor_oak_open"] = "moretrees:oak_trapdoor_open",
    ["mcl_doors:trapdoor_open"] = "moretrees:oak_trapdoor_open",
    ["mcl_doors:trapdoor_spruce_open"] = "moretrees:spruce_trapdoor_open",
    ["mcl_doors:iron_trapdoor_open"] = "doors:trapdoor_steel_open",
    ["mcl_doors:jungle_trapdoor_open"] = "moretrees:junglewood_trapdoor_open",
    ["mcl_doors:dark_oak_trapdoor_open"] = "moretrees:oak_trapdoor_open",
    ["mcl_doors:spruce_trapdoor"] = "moretrees:spruce_trapdoor",
    ["mcl_doors:spruce_trapdoor_open"] = "moretrees:spruce_trapdoor_open",

    -- ===========================================
    -- LITS - Utilisent colorful beds pour variété
    -- ===========================================
    -- Utilise le mod colorful beds pour des lits colorés
    ["mcl_beds:bed_red_bottom"] = "beds:bed_bottom_red",
    ["mcl_beds:bed_red_top"] = "beds:bed_top_red",
    ["mcl_beds:bed_white_bottom"] = "beds:bed_bottom_white",
    ["mcl_beds:bed_white_top"] = "beds:bed_top_white",
    ["mcl_beds:bed_light_blue_bottom"] = "beds:bed_bottom_blue",
    ["mcl_beds:bed_light_blue_top"] = "beds:bed_top_blue",
    ["mcl_beds:bed_lime_bottom"] = "beds:bed_bottom_green",
    ["mcl_beds:bed_lime_top"] = "beds:bed_top_green",
    ["mcl_beds:bed_pink_bottom"] = "beds:bed_bottom_pink",
    ["mcl_beds:bed_pink_top"] = "beds:bed_top_pink",
    ["mcl_beds:bed_yellow_bottom"] = "beds:bed_bottom_yellow",
    ["mcl_beds:bed_yellow_top"] = "beds:bed_top_yellow",
    ["mcl_beds:bed_brown_bottom"] = "beds:bed_bottom_brown",
    ["mcl_beds:bed_brown_top"] = "beds:bed_top_brown",

    -- ===========================================
    -- BLOCS FONCTIONNELS - Éclairage
    -- ===========================================
    ["mcl_torches:torch"] = "default:torch",
    ["mcl_torches:torch_wall"] = "default:torch_wall",
    ["mcl_lanterns:lantern_floor"] = "default:torch",
    ["mcl_lanterns:lantern_ceiling"] = "default:torch",
    ["mcl_lanterns:chain"] = "cottages:chain",
    ["mcl_lanterns:soul_lantern_ceiling"] = "default:torch",
    ["mcl_blackstone:soul_torch"] = "default:torch",

    -- ===========================================
    -- BLOCS FONCTIONNELS - Stockage (cottages)
    -- ===========================================
    ["mcl_chests:chest"] = "cottages:shelf",
    ["mcl_chests:chest_left"] = "cottages:shelf",
    ["mcl_chests:chest_right"] = "cottages:shelf",
    ["mcl_chests:chest_small"] = "cottages:shelf",
    ["mcl_chests:ender_chest_small"] = "cottages:shelf",
    ["mcl_chests:trapped_chest_small"] = "cottages:shelf",
    ["mcl_barrels:barrel_closed"] = "cottages:barrel",

    -- ===========================================
    -- BLOCS FONCTIONNELS - Artisanat (mods spécialisés)
    -- ===========================================
    ["mcl_crafting_table:crafting_table"] = "cottages:workbench",
    ["mcl_furnaces:furnace"] = "default:furnace",
    ["mcl_anvils:anvil"] = "anvil:anvil",
    ["mcl_anvils:anvil_damage_1"] = "anvil:anvil",
    ["mcl_anvils:anvil_damage_2"] = "anvil:anvil",
    ["mcl_books:bookshelf"] = "cottages:bookshelf",
    ["mcl_lectern:lectern"] = "cottages:bookshelf",
    ["mcl_cartography_table:cartography_table"] = "cottages:workbench",
    ["mcl_fletching_table:fletching_table"] = "cottages:workbench",
    ["mcl_smithing_table:table"] = "cottages:workbench",
    ["mcl_stonecutter:stonecutter"] = "xdecor:stonecutter",  -- tailleur de pierre spécialisé

    -- ===========================================
    -- AGRICULTURE
    -- ===========================================
    ["mcl_farming:soil_wet"] = "farming:soil_wet",
    ["mcl_farming:wheat"] = "farming:wheat_8",
    ["mcl_farming:wheat_1"] = "farming:wheat_1",
    ["mcl_farming:wheat_3"] = "farming:wheat_3",
    ["mcl_farming:wheat_5"] = "farming:wheat_5",
    ["mcl_farming:wheat_7"] = "farming:wheat_7",
    ["mcl_farming:carrot"] = "farming:carrot_8",
    ["mcl_farming:potato"] = "farming:potato_8",
    ["mcl_farming:hay_block"] = "farming:straw",
    ["mcl_composters:composter"] = "cottages:barrel",

    -- ===========================================
    -- ESCALIERS - Utilisent moreblocks et moretrees pour précision maximale
    -- ===========================================
    -- Pierres et minéraux - moreblocks pour variété avancée
    ["mcl_stairs:stair_cobble"] = "moreblocks:stair_cobble",
    ["mcl_stairs:stair_cobble_inner"] = "moreblocks:stair_cobble_inner",
    ["mcl_stairs:stair_cobble_outer"] = "moreblocks:stair_cobble_outer",
    ["mcl_stairs:stair_stone"] = "moreblocks:stair_stone",
    ["mcl_stairs:stair_stonebrick"] = "moreblocks:stair_stonebrick",
    ["mcl_stairs:stair_stonebrick_inner"] = "moreblocks:stair_stonebrick_inner",
    ["mcl_stairs:stair_stonebrick_outer"] = "moreblocks:stair_stonebrick_outer",
    ["mcl_stairs:stair_stonebrickcracked"] = "moreblocks:stair_stonebrick",
    ["mcl_stairs:stair_stonebrickcracked_inner"] = "moreblocks:stair_stonebrick_inner",
    ["mcl_stairs:stair_stonebrickmossy"] = "moreblocks:stair_stonebrick",
    ["mcl_stairs:stair_sandstone"] = "moreblocks:stair_sandstone",
    ["mcl_stairs:stair_sandstone_outer"] = "moreblocks:stair_sandstone_outer",
    ["mcl_stairs:stair_sandstonesmooth2"] = "moreblocks:stair_sandstone",
    ["mcl_stairs:stair_sandstonesmooth2_outer"] = "moreblocks:stair_sandstone_outer",
    ["mcl_stairs:stair_andesite_smooth"] = "moreblocks:stair_stone",
    ["mcl_stairs:stair_andesite_smooth_outer"] = "moreblocks:stair_stone_outer",
    ["mcl_stairs:stair_blackstone_chiseled_polished"] = "moreblocks:stair_stone",
    ["mcl_stairs:stair_blackstone_chiseled_polished_outer"] = "moreblocks:stair_stone_outer",
    ["mcl_stairs:stair_blackstone_polished"] = "moreblocks:stair_stone",
    ["mcl_stairs:stair_blackstone_polished_outer"] = "moreblocks:stair_stone_outer",
    ["mcl_stairs:stair_deepslate_bricks"] = "moreblocks:stair_stonebrick",
    ["mcl_stairs:stair_deepslate_tiles"] = "moreblocks:stair_stonebrick",
    ["mcl_stairs:stair_prismarine_brick"] = "moreblocks:stair_stonebrick",
    ["mcl_stairs:stair_prismarine_brick_outer"] = "moreblocks:stair_stonebrick_outer",
    ["mcl_stairs:stair_purpur_block"] = "moreblocks:stair_stonebrick",
    ["mcl_stairs:stair_purpur_block_outer"] = "moreblocks:stair_stonebrick_outer",

    -- Bois - moretrees pour précision maximale par essence
    ["mcl_stairs:stair_wood"] = "moreblocks:stair_wood",
    ["mcl_stairs:stair_wood_inner"] = "moreblocks:stair_wood_inner",
    ["mcl_stairs:stair_wood_outer"] = "moreblocks:stair_wood_outer",
    ["mcl_stairs:stair_oak"] = "moretrees:stair_oak_planks",
    ["mcl_stairs:stair_oak_inner"] = "moretrees:stair_oak_planks_inner",
    ["mcl_stairs:stair_oak_outer"] = "moretrees:stair_oak_planks_outer",
    ["mcl_stairs:stair_oak_bark"] = "moretrees:stair_oak_planks",
    ["mcl_stairs:stair_oak_bark_outer"] = "moretrees:stair_oak_planks_outer",
    ["mcl_stairs:stair_birch"] = "moretrees:stair_birch_planks",
    ["mcl_stairs:stair_birch_inner"] = "moretrees:stair_birch_planks_inner",
    ["mcl_stairs:stair_dark_oak"] = "moretrees:stair_oak_planks",  -- approximation chêne
    ["mcl_stairs:stair_dark_oak_outer"] = "moretrees:stair_oak_planks_outer",
    ["mcl_stairs:stair_dark_oak_bark"] = "moretrees:stair_oak_planks",
    ["mcl_stairs:stair_darktree_bark"] = "moretrees:stair_oak_planks",
    ["mcl_stairs:stair_darkwood"] = "moretrees:stair_oak_planks",
    ["mcl_stairs:stair_sprucewood"] = "moretrees:stair_spruce_planks",
    ["mcl_stairs:stair_sprucewood_inner"] = "moretrees:stair_spruce_planks_inner",
    ["mcl_stairs:stair_sprucewood_outer"] = "moretrees:stair_spruce_planks_outer",
    ["mcl_stairs:stair_spruce_bark"] = "moretrees:stair_spruce_planks",
    ["mcl_stairs:stair_sprucetree_bark"] = "moretrees:stair_spruce_planks",

    -- Métaux et spécialisés - moreblocks pour formes avancées
    ["mcl_stairs:stair_nether_brick"] = "moreblocks:stair_brick",
    ["mcl_stairs:stair_nether_brick_outer"] = "moreblocks:stair_brick_outer",
    ["mcl_stairs:stair_goldblock"] = "moreblocks:stair_goldblock",
    ["mcl_stairs:stair_ironblock"] = "moreblocks:stair_steelblock",
    ["mcl_stairs:stair_ironblock_outer"] = "moreblocks:stair_steelblock_outer",
    ["mcl_stairs:stair_mossycobble"] = "moreblocks:stair_mossycobble",

    -- ===========================================
    -- DALLES - Utilisent moreblocks et moretrees pour précision maximale
    -- ===========================================
    -- Pierres et minéraux - moreblocks pour variété avancée
    ["mcl_stairs:slab_cobble"] = "moreblocks:slab_cobble",
    ["mcl_stairs:slab_cobble_double"] = "moreblocks:cobble",
    ["mcl_stairs:slab_stone"] = "moreblocks:slab_stone",
    ["mcl_stairs:slab_stone_double"] = "moreblocks:stone",
    ["mcl_stairs:slab_stonebrick"] = "moreblocks:slab_stonebrick",
    ["mcl_stairs:slab_stonebrick_double"] = "moreblocks:stonebrick",
    ["mcl_stairs:slab_stonebrick_top"] = "moreblocks:slab_stonebrick",
    ["mcl_stairs:slab_stonebrickcracked"] = "moreblocks:slab_stonebrick",
    ["mcl_stairs:slab_sandstone"] = "moreblocks:slab_sandstone",
    ["mcl_stairs:slab_sandstonesmooth2"] = "moreblocks:slab_sandstone",
    ["mcl_stairs:slab_sandstonesmooth2_top"] = "moreblocks:slab_sandstone",
    ["mcl_stairs:slab_diorite_smooth"] = "moreblocks:slab_stone",
    ["mcl_stairs:slab_prismarine_dark"] = "moreblocks:slab_stonebrick",
    ["mcl_stairs:slab_purpur_block"] = "moreblocks:slab_stonebrick",
    ["mcl_stairs:slab_purpur_block_top"] = "moreblocks:slab_stonebrick",

    -- Bois - moretrees pour précision maximale par essence
    ["mcl_stairs:slab_wood"] = "moreblocks:slab_wood",
    ["mcl_stairs:slab_wood_double"] = "moreblocks:wood",
    ["mcl_stairs:slab_wood_top"] = "moreblocks:slab_wood",
    ["mcl_stairs:slab_oak"] = "moretrees:slab_oak_planks",
    ["mcl_stairs:slab_oak_double"] = "moretrees:oak_planks",
    ["mcl_stairs:slab_oak_top"] = "moretrees:slab_oak_planks",
    ["mcl_stairs:slab_birch"] = "moretrees:slab_birch_planks",
    ["mcl_stairs:slab_birch_double"] = "moretrees:birch_planks",
    ["mcl_stairs:slab_birch_top"] = "moretrees:slab_birch_planks",
    ["mcl_stairs:slab_birchwood_top"] = "moretrees:slab_birch_planks",
    ["mcl_stairs:slab_dark_oak"] = "moretrees:slab_oak_planks",  -- approximation chêne
    ["mcl_stairs:slab_dark_oak_double"] = "moretrees:oak_planks",
    ["mcl_stairs:slab_dark_oak_top"] = "moretrees:slab_oak_planks",
    ["mcl_stairs:slab_dark_oak_bark_top"] = "moretrees:slab_oak_planks",
    ["mcl_stairs:slab_darktree_bark_top"] = "moretrees:slab_oak_planks",
    ["mcl_stairs:slab_darkwood"] = "moretrees:slab_oak_planks",
    ["mcl_stairs:slab_darkwood_double"] = "moretrees:oak_planks",
    ["mcl_stairs:slab_darkwood_top"] = "moretrees:slab_oak_planks",
    ["mcl_stairs:slab_sprucewood"] = "moretrees:slab_spruce_planks",
    ["mcl_stairs:slab_sprucewood_top"] = "moretrees:slab_spruce_planks",

    -- Métaux et spécialisés - moreblocks pour formes avancées
    ["mcl_stairs:slab_nether_brick"] = "moreblocks:slab_brick",

    -- ===========================================
    -- MURS (walls mod)
    -- ===========================================
    ["mcl_walls:cobble_0"] = "walls:cobble",
    ["mcl_walls:cobble_1"] = "walls:cobble",
    ["mcl_walls:cobble_2"] = "walls:cobble",
    ["mcl_walls:cobble_3"] = "walls:cobble",
    ["mcl_walls:cobble_4"] = "walls:cobble",
    ["mcl_walls:cobble_5"] = "walls:cobble",
    ["mcl_walls:cobble_6"] = "walls:cobble",
    ["mcl_walls:cobble_7"] = "walls:cobble",
    ["mcl_walls:cobble_8"] = "walls:cobble",
    ["mcl_walls:cobble_9"] = "walls:cobble",
    ["mcl_walls:cobble_10"] = "walls:cobble",
    ["mcl_walls:cobble_11"] = "walls:cobble",
    ["mcl_walls:cobble_12"] = "walls:cobble",
    ["mcl_walls:cobble_13"] = "walls:cobble",
    ["mcl_walls:cobble_14"] = "walls:cobble",
    ["mcl_walls:cobble_21"] = "walls:cobble",
    ["mcl_walls:stonebrick_0"] = "walls:stonebrick",
    ["mcl_walls:stonebrick_1"] = "walls:stonebrick",
    ["mcl_walls:stonebrick_3"] = "walls:stonebrick",
    ["mcl_walls:stonebrick_6"] = "walls:stonebrick",
    ["mcl_walls:stonebrick_9"] = "walls:stonebrick",
    ["mcl_walls:stonebrick_12"] = "walls:stonebrick",
    ["mcl_walls:mossycobble_0"] = "walls:mossycobble",
    ["mcl_walls:mossycobble_1"] = "walls:mossycobble",
    ["mcl_walls:mossycobble_2"] = "walls:mossycobble",
    ["mcl_walls:mossycobble_3"] = "walls:mossycobble",
    ["mcl_walls:mossycobble_4"] = "walls:mossycobble",
    ["mcl_walls:mossycobble_5"] = "walls:mossycobble",
    ["mcl_walls:mossycobble_10"] = "walls:mossycobble",
    ["mcl_walls:mossycobble_12"] = "walls:mossycobble",
    ["mcl_walls:endbricks_0"] = "walls:stonebrick",
    ["mcl_walls:endbricks_1"] = "walls:stonebrick",
    ["mcl_walls:endbricks_2"] = "walls:stonebrick",
    ["mcl_walls:endbricks_3"] = "walls:stonebrick",
    ["mcl_walls:endbricks_4"] = "walls:stonebrick",
    ["mcl_walls:endbricks_5"] = "walls:stonebrick",
    ["mcl_walls:endbricks_6"] = "walls:stonebrick",
    ["mcl_walls:endbricks_7"] = "walls:stonebrick",
    ["mcl_walls:endbricks_8"] = "walls:stonebrick",
    ["mcl_walls:endbricks_9"] = "walls:stonebrick",
    ["mcl_walls:endbricks_10"] = "walls:stonebrick",
    ["mcl_walls:endbricks_12"] = "walls:stonebrick",
    ["mcl_walls:endbricks_13"] = "walls:stonebrick",
    ["mcl_walls:endbricks_16"] = "walls:stonebrick",
    ["mcl_walls:prismarine_0"] = "walls:stonebrick",
    ["mcl_walls:prismarine_3"] = "walls:stonebrick",
    ["mcl_walls:prismarine_4"] = "walls:stonebrick",
    ["mcl_walls:stonebrick"] = "walls:stonebrick",

    -- ===========================================
    -- BLOCS DÉCORATIFS - Utilisent mods spécialisés
    -- ===========================================
    ["mcl_flowers:tallgrass"] = "default:grass_1",
    ["mcl_flowers:waterlily"] = "flowers:waterlily",
    ["mcl_flowerpots:flower_pot"] = "flowerpot:empty",
    ["mcl_flowerpots:flower_pot_blue_orchid"] = "flowerpot:blue_orchid",
    ["mcl_flowerpots:flower_pot_poppy"] = "flowerpot:poppy",
    ["mcl_flowerpots:flower_pot_dandelion"] = "flowerpot:dandelion",
    ["mcl_flowerpots:flower_pot_oxeye_daisy"] = "flowerpot:oxeye_daisy",
    ["mcl_flowerpots:flower_pot_tulip_orange"] = "flowerpot:tulip_orange",
    ["mcl_flowerpots:flower_pot_tulip_pink"] = "flowerpot:tulip_pink",
    ["mcl_flowerpots:flower_pot_tulip_red"] = "flowerpot:tulip_red",
    ["mcl_flowerpots:flower_pot_tulip_white"] = "flowerpot:tulip_white",
    ["mcl_flowerpots:flower_pot_azure_bluet"] = "flowerpot:azure_bluet",
    ["mcl_flowerpots:flower_pot_allium"] = "flowerpot:allium",
    ["mcl_flowerpots:flower_pot_cornflower"] = "flowerpot:cornflower",
    ["mcl_flowerpots:flower_pot_lily_of_the_valley"] = "flowerpot:lily_of_the_valley",
    ["mcl_flowerpots:flower_pot_wither_rose"] = "flowerpot:wither_rose",
    ["mcl_flowerpots:flower_pot_fern"] = "flowerpot:fern",
    ["mcl_flowerpots:flower_pot_cactus"] = "flowerpot:cactus",
    ["mcl_flowerpots:flower_pot_sapling_birch"] = "flowerpot:sapling_birch",
    ["mcl_flowerpots:flower_pot_sapling_dark_oak"] = "flowerpot:sapling_dark_oak",
    ["mcl_flowerpots:flower_pot_sprucesapling"] = "flowerpot:sprucesapling",

    -- ===========================================
    -- BLOCS SPÉCIALISÉS - Nether/End/Deepslate (utilisant mods appropriés)
    -- ===========================================
    -- Nether - utilise le mod nether pour authenticité
    ["mcl_nether:magma"] = "nether:magma",
    ["mcl_nether:netherrack"] = "nether:netherrack",
    ["mcl_nether:soul_sand"] = "nether:soul_sand",
    ["mcl_nether:soul_soil"] = "nether:soul_soil",
    ["mcl_nether:glowstone"] = "nether:glowstone",
    ["mcl_nether:quartz_ore"] = "nether:quartz_ore",
    ["mcl_nether:nether_gold_ore"] = "nether:nether_gold_ore",
    ["mcl_nether:ancient_debris"] = "nether:ancient_debris",
    ["mcl_nether:blackstone"] = "nether:blackstone",
    ["mcl_nether:basalt"] = "nether:basalt",
    ["mcl_nether:polished_basalt"] = "nether:polished_basalt",
    ["mcl_nether:smooth_basalt"] = "nether:smooth_basalt",
    ["mcl_nether:netherite_block"] = "nether:netherite_block",
    ["mcl_nether:crimson_nylium"] = "nether:crimson_nylium",
    ["mcl_nether:warped_nylium"] = "nether:warped_nylium",
    ["mcl_nether:crimson_stem"] = "nether:crimson_stem",
    ["mcl_nether:warped_stem"] = "nether:warped_stem",
    ["mcl_nether:shroomlight"] = "nether:shroomlight",
    ["mcl_nether:warped_wart_block"] = "nether:warped_wart_block",
    ["mcl_nether:target"] = "nether:target",
    ["mcl_nether:crying_obsidian"] = "nether:crying_obsidian",
    ["mcl_nether:respawn_anchor"] = "nether:respawn_anchor",

    -- Blackstone - utilise le mod nether pour cohérence
    ["mcl_blackstone:blackstone_chiseled_polished"] = "nether:blackstone_chiseled_polished",
    ["mcl_blackstone:nether_gold"] = "nether:nether_gold",
    ["mcl_blackstone:quartz_brick"] = "nether:quartz_brick",
    ["mcl_blackstone:blackstone_polished"] = "nether:blackstone_polished",
    ["mcl_blackstone:blackstone_gilded"] = "nether:blackstone_gilded",

    -- End - blocs simplifiés (pas de mod end spécifique détecté)
    ["mcl_end:end_rod"] = "default:torch",
    ["mcl_end:end_stone_brick"] = "default:stonebrick",
    ["mcl_end:end_stone_brick_silverfish"] = "default:stonebrick",

    -- Deepslate - blocs spécialisés (simplifiés)
    ["mcl_deepslate:deepslate"] = "default:stone",
    ["mcl_deepslate:deepslate_cobbled"] = "default:cobble",
    ["mcl_deepslate:deepslate_polished"] = "default:stone_block",
    ["mcl_deepslate:deepslate_bricks"] = "default:stonebrick",
    ["mcl_deepslate:deepslate_bricks_cracked"] = "default:stonebrick",
    ["mcl_deepslate:deepslate_chiseled"] = "default:stonebrick",
    ["mcl_deepslate:deepslate_tiles"] = "default:stonebrick",
    ["mcl_deepslate:deepslate_tiles_cracked"] = "default:stonebrick",
    ["mcl_deepslate:deepslate_reinforced"] = "default:stone",
    ["mcl_deepslate:deepslate_with_coal"] = "default:stone_with_coal",
    ["mcl_deepslate:deepslate_with_copper"] = "default:stone_with_copper",
    ["mcl_deepslate:deepslate_with_diamond"] = "default:stone_with_diamond",
    ["mcl_deepslate:deepslate_with_gold"] = "default:stone_with_gold",
    ["mcl_deepslate:deepslate_with_iron"] = "default:stone_with_iron",
    ["mcl_deepslate:deepslate_with_redstone"] = "default:stone_with_redstone",
    ["mcl_deepslate:tuff"] = "default:stone",

    -- ===========================================
    -- BLOCS SPÉCIALISÉS - Ocean (utilisant le mod ocean)
    -- ===========================================
    ["mcl_ocean:brain_coral"] = "ocean:brain_coral",
    ["mcl_ocean:brain_coral_block"] = "ocean:brain_coral_block",
    ["mcl_ocean:brain_coral_fan"] = "ocean:brain_coral_fan",
    ["mcl_ocean:bubble_coral"] = "ocean:bubble_coral",
    ["mcl_ocean:bubble_coral_block"] = "ocean:bubble_coral_block",
    ["mcl_ocean:bubble_coral_fan"] = "ocean:bubble_coral_fan",
    ["mcl_ocean:fire_coral"] = "ocean:fire_coral",
    ["mcl_ocean:fire_coral_block"] = "ocean:fire_coral_block",
    ["mcl_ocean:fire_coral_fan"] = "ocean:fire_coral_fan",
    ["mcl_ocean:horn_coral"] = "ocean:horn_coral",
    ["mcl_ocean:horn_coral_block"] = "ocean:horn_coral_block",
    ["mcl_ocean:horn_coral_fan"] = "ocean:horn_coral_fan",
    ["mcl_ocean:tube_coral"] = "ocean:tube_coral",
    ["mcl_ocean:tube_coral_block"] = "ocean:tube_coral_block",
    ["mcl_ocean:tube_coral_fan"] = "ocean:tube_coral_fan",
    ["mcl_ocean:prismarine"] = "ocean:prismarine",
    ["mcl_ocean:prismarine_brick"] = "ocean:prismarine_brick",
    ["mcl_ocean:sea_lantern"] = "ocean:sea_lantern",

    -- ===========================================
    -- BLOCS SPÉCIALISÉS - Village (simplifiés)
    -- ===========================================
    ["mcl_villages:no_paths"] = "default:dirt",
    ["mcl_villages:path_endpoint"] = "default:dirt",
    ["mcl_villages:stonebrickcarved"] = "default:stonebrick",
    ["mcl_villages:crop_flower_1"] = "flowers:rose",
    ["mcl_villages:crop_flower_2"] = "flowers:tulip",
    ["mcl_villages:crop_flower_3"] = "flowers:dandelion_yellow",
    ["mcl_villages:crop_flower_4"] = "flowers:geranium",
    ["mcl_villages:crop_flower_8"] = "flowers:viola",
    ["mcl_villages:crop_gourd_1"] = "default:dirt",
    ["mcl_villages:crop_gourd_2"] = "default:dirt",
    ["mcl_villages:crop_grain_1"] = "farming:wheat_1",
    ["mcl_villages:crop_grain_2"] = "farming:wheat_2",
    ["mcl_villages:crop_grain_3"] = "farming:wheat_3",
    ["mcl_villages:crop_root_1"] = "farming:carrot_1",
    ["mcl_villages:crop_root_2"] = "farming:carrot_2",
    ["mcl_villages:crop_root_3"] = "farming:carrot_3",

    -- ===========================================
    -- BLOCS SPÉCIALISÉS - Divers (mods spécialisés)
    -- ===========================================
    ["mcl_armor_stand:armor_stand"] = "itemframes:pedestal",
    ["mcl_banners:hanging_banner"] = "cottages:banner",
    ["mcl_bells:bell"] = "bell:bell",
    ["mcl_brewing:stand_000"] = "xdecor:brewing_stand",  -- alambic spécialisé
    ["mcl_campfires:campfire"] = "cottages:stove",
    ["mcl_campfires:campfire_lit"] = "cottages:stove",
    ["mcl_campfires:soul_campfire_lit"] = "cottages:stove",
    ["mcl_cauldrons:cauldron"] = "cottages:washbowl",
    ["mcl_cauldrons:cauldron_2"] = "cottages:washbowl",
    ["mcl_cauldrons:cauldron_3"] = "cottages:washbowl",
    ["mcl_fire:fire"] = "fire:basic_flame",
    ["mcl_grindstone:grindstone"] = "xdecor:grindstone",  -- meule spécialisée
    ["mcl_heads:wither_skeleton"] = "itemframes:pedestal",
    ["mcl_itemframes:frame"] = "itemframes:frame",
    ["mcl_itemframes:glow_item_frame"] = "itemframes:glow_frame",
    ["mcl_itemframes:item_frame"] = "itemframes:frame",
    ["mcl_jukebox:jukebox"] = "cottages:shelf",
    ["mcl_lever:lever_off"] = "cottages:lever",
    ["mcl_loom:loom"] = "cottages:loom",
    ["mcl_minecarts:rail"] = "carts:rail",
    ["mcl_mobspawners:spawner"] = "cottages:barrel",
    ["mcl_monster_eggs:monster_egg_cobble"] = "default:cobble",
    ["mcl_monster_eggs:monster_egg_stonebrick"] = "default:stonebrick",
    ["mcl_monster_eggs:monster_egg_stonebrickcarved"] = "default:stonebrick",
    ["mcl_mushrooms:mushroom_red"] = "flowers:mushroom_red",
    ["mcl_portals:end_portal_frame"] = "default:obsidian",
    ["mcl_portals:portal"] = "default:obsidian",
    ["mcl_portals:portal_end"] = "default:obsidian",
    ["mcl_portals:portal_gateway"] = "default:obsidian",
    ["mcl_pressureplates:pressure_plate_oak_off"] = "cottages:pressure_plate",
    ["mcl_redstone:wire_05"] = "cottages:barrel",
    ["mcl_redstone:wire_0a"] = "cottages:barrel",
    ["mcl_redstone:wire_0c"] = "cottages:barrel",
    ["mcl_sculk:catalyst"] = "default:stone",
    ["mcl_sculk:sculk"] = "default:stone",
    ["mcl_sculk:vein"] = "default:vine",
    ["mcl_signs:standing_sign"] = "default:sign_wall_wood",
    ["mcl_smithing_table:table"] = "cottages:workbench",
    ["mcl_smoker:smoker"] = "cottages:stove",
    ["mcl_sponges:sponge_wet"] = "cottages:barrel",
    ["mcl_tnt:tnt"] = "tnt:tnt",

    -- ===========================================
    -- BLOCS MANQUANTS - Ajouts pour compléter le mapping
    -- ===========================================

    -- Blocs d'os et spécialisés
    ["mcl_core:bone_block"] = "default:stone",

    -- Bois supplémentaires et écorces
    ["mcl_core:darktree"] = "moretrees:oak_trunk",
    ["mcl_core:sprucetree"] = "moretrees:spruce_trunk",
    ["mcl_core:stripped_dark_oak"] = "moretrees:oak_planks",
    ["mcl_core:stripped_oak"] = "moretrees:oak_planks",
    ["mcl_core:stripped_spruce"] = "moretrees:spruce_planks",

    -- Clôtures - utilisation du mod fences si disponible, sinon default
    ["mcl_fences:fence"] = "default:fence_wood",
    ["mcl_fences:oak_fence"] = "default:fence_wood",
    ["mcl_fences:birch_fence"] = "default:fence_wood",
    ["mcl_fences:spruce_fence"] = "default:fence_wood",
    ["mcl_fences:dark_oak_fence"] = "default:fence_wood",
    ["mcl_fences:nether_brick_fence"] = "default:fence_wood",

    -- Vitres et panneaux
    ["mcl_panes:pane_natural_flat"] = "xpanes:pane_flat",
    ["mcl_panes:bar_flat"] = "xpanes:bar_flat",
    ["mcl_panes:pane_light_blue_flat"] = "xpanes:pane_flat",
    ["mcl_panes:bar"] = "xpanes:bar_flat",
    ["mcl_panes:pane_white_flat"] = "xpanes:pane_flat",
    ["mcl_panes:pane_red_flat"] = "xpanes:pane_flat",
    ["mcl_panes:pane_purple_flat"] = "xpanes:pane_flat",
    ["mcl_panes:pane_orange_flat"] = "xpanes:pane_flat",
    ["mcl_panes:pane_magenta_flat"] = "xpanes:pane_flat",
    ["mcl_panes:pane_blue_flat"] = "xpanes:pane_flat",

    -- Agriculture - citrouilles et pastèques
    ["mcl_farming:pumpkin"] = "default:pumpkin",
    ["mcl_farming:melon"] = "default:watermelon",
    ["mcl_farming:pumpkintige_linked_l"] = "default:pumpkin_1",
    ["mcl_farming:pumpkintige_linked_r"] = "default:pumpkin_1",
    ["mcl_farming:pumpkintige_linked_t"] = "default:pumpkin_1",
    ["mcl_farming:melontige_linked_l"] = "default:watermelon_1",
    ["mcl_farming:melontige_linked_r"] = "default:watermelon_1",
    ["mcl_farming:melontige_linked_t"] = "default:watermelon_1",

    -- Escaliers - dalle supérieure en pierre
    ["mcl_stairs:slab_stone_top"] = "moreblocks:slab_stone",

    -- Portails de clôture
    ["mcl_fences:dark_oak_fence_gate"] = "default:fence_gate_wood",

    -- Murs en briques de deepslate (approximations)
    ["mcl_deepslate:deepslatebrickswall_0"] = "walls:stonebrick",
    ["mcl_deepslate:deepslatebrickswall_1"] = "walls:stonebrick",
    ["mcl_deepslate:deepslatebrickswall_2"] = "walls:stonebrick",
    ["mcl_deepslate:deepslatebrickswall_3"] = "walls:stonebrick",
    ["mcl_deepslate:deepslatebrickswall_4"] = "walls:stonebrick",
    ["mcl_deepslate:deepslatebrickswall_5"] = "walls:stonebrick",
    ["mcl_deepslate:deepslatebrickswall_6"] = "walls:stonebrick",
    ["mcl_deepslate:deepslatebrickswall_7"] = "walls:stonebrick",
    ["mcl_deepslate:deepslatebrickswall_8"] = "walls:stonebrick",
    ["mcl_deepslate:deepslatebrickswall_9"] = "walls:stonebrick",
    ["mcl_deepslate:deepslatebrickswall_10"] = "walls:stonebrick",
    ["mcl_deepslate:deepslatebrickswall_11"] = "walls:stonebrick",
    ["mcl_deepslate:deepslatebrickswall_12"] = "walls:stonebrick",
    ["mcl_deepslate:deepslatebrickswall_13"] = "walls:stonebrick",
    ["mcl_deepslate:deepslatebrickswall_14"] = "walls:stonebrick",
    ["mcl_deepslate:deepslatebrickswall_15"] = "walls:stonebrick",

    -- ===========================================
    -- BLOCS MANQUANTS - Ajouts finaux pour conversion complète
    -- ===========================================

    -- Haut-fourneau (blast furnace)
    ["mcl_blast_furnace:blast_furnace"] = "default:furnace",

    -- Bois écorcé supplémentaire
    ["mcl_core:stripped_spruce_bark"] = "moretrees:spruce_planks",

    -- Agriculture - citrouilles avec visage
    ["mcl_farming:pumpkin_7"] = "default:pumpkin",
    ["mcl_farming:pumpkin_face"] = "default:pumpkin",
    ["mcl_farming:pumpkin_face_light"] = "default:pumpkin",

    -- Clôtures - portails
    ["mcl_fences:fence_gate"] = "default:fence_gate_wood",

    -- Pots de fleurs - jeunes pousses d'épicéa
    ["mcl_flowerpots:flower_pot_sapling_spruce"] = "flowerpot:sprucesapling",

    -- Vitres colorées - jaune
    ["mcl_panes:pane_yellow_flat"] = "xpanes:pane_flat",

    -- ===========================================
    -- BLOCS AVEC PANNES - Approximation par défaut
    -- ===========================================
    -- Tous les blocs non mappés ci-dessus seront remplacés par default:stone
}

-- Fonction de conversion
function convert_mineclonia_block(block_name)
    return mineclonia_mapping[block_name] or "default:bad"
end

return mineclonia_mapping
