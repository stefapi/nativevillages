## Brief overview
Règles spécifiques au développement du mod nativevillages pour Minetest, un projet Lua ajoutant villages, créatures et structures en génération procédurale. Ces directives couvrent les bonnes pratiques de code, l'utilisation de l'API Minetest et les patterns de génération du monde.

## Structure du mod
- Organiser le code en modules logiques par biomes (grassland, desert, savanna, arctic, lake, jungle)
- Utiliser des namespaces appropriés pour éviter les conflits (ex: nativevillages:villager_female)
- Séparer la logique de génération de contenu de la logique de jeu
- Utiliser des tables locales pour structurer les données de configuration

## Utilisation de l'API Minetest
- Enregistrer les nœuds avec minetest.register_node() en spécifiant tous les paramètres requis
- Utiliser minetest.register_entity() pour les créatures mobiles avec propriétés physiques appropriées
- Implémenter les callbacks d'entité (on_activate, on_step, on_punch) pour le comportement
- Utiliser minetest.register_craftitem() pour les objets craftables
- Gérer les schématiques avec minetest.place_schematic() et minetest.register_decoration()

## Bonnes pratiques de code
- Préférer les variables locales aux globales pour éviter la pollution de l'espace de noms
- Utiliser des fonctions anonymes dans les callbacks pour encapsuler la logique
- Implémenter une gestion d'erreur robuste avec pcall() pour les opérations critiques
- Optimiser les performances en limitant les calculs dans les boucles on_step
- Documenter les fonctions complexes avec des commentaires détaillés

## Mécanismes de génération du monde
- Utiliser minetest.register_decoration() pour placer schématiques et structures lors de la génération
- Configurer les paramètres de décoration : biomes, hauteur (y_min/y_max), ratio de remplissage, rotation
- Villages complets : place_offset_y proche de 0, fill_ratio élevé (~0.0001)
- Bâtiments individuels : place_offset_y négatif (-29), fill_ratio faible (~0.00004), rotation aléatoire
- Créatures : utiliser l'API mobs avec mobs:spawn() pour génération naturelle conditionnelle

## Patterns de code courants
- Pattern de fabrique pour créer des variantes d'entités similaires
- Utilisation de métatables pour partager des comportements entre entités
- Séparation des données de configuration dans des tables dédiées
- Utilisation de l'héritage via setmetatable pour étendre les entités de base

## Pratiques de développement
- Utiliser des noms de variables et fonctions descriptifs
- Ajouter des commentaires pour la logique complexe
- Éviter les variables globales autant que possible
- Gérer les erreurs de manière élégante
- Garder les performances à l'esprit pour les entités et structures de jeu
