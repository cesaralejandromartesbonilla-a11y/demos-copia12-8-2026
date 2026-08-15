# demos-copia12-8-2026

Colección de proyectos demo hechos con **Godot 4.6** (renderizador Forward Plus). El repositorio agrupa varios prototipos de juegos independientes, junto con copias/respaldos con fecha de algunos de ellos.

## Proyectos principales

### creaturas-of-sonaria-for-godot
El proyecto más grande del repositorio. Juego de criaturas inspirado en *Creatures of Sonaria*, con soporte de C# además de GDScript (`.csproj`/`.sln`). Por sus carpetas y scripts incluye:
- Criaturas (`creatures`), habilidades (`habilidades`), efectos e ítems.
- Sistemas globales tipo manager: clima (`WeatherManager.gd`), inventario (`inventory_manager.gd`), cultivos y su guardado (`CropSimulationManager.gd`, `CropSaveManager.gd`), ítems (`ItemSaveManager.gd`), lógica general (`LogicManager.gd`) y energía (`PowerManager.gd`).
- Sistema de cuerdas (`rope_system`), pruebas de slime (`slime_test`) y scripts de vehículos (`scripts_car`).
- Documentos de diseño: `plan de creaturas of sonaria.txt` y `plan de slime modular.txt`.

### snowrunner-godot-
Prototipo de conducción todoterreno inspirado en *SnowRunner*: vehículos, remolques, mapas, edificaciones, superficies y materiales físicos. Incluye un gestor de garaje (`garage_manager.gd`), datos globales (`global_data.gd`) y el plan de diseño `plan de snowrunner vtemu.txt`.

### bloons-td-temu-edition
Juego de tipo *tower defense* inspirado en *Bloons TD*. Estructura organizada en `src`, `scenes` y `resources`, con documentación de scripts en `script_docs_txt` y el plan `plan_de_td6.txt`.

### hill-climbing-temu
Prototipo de conducción estilo *Hill Climb Racing*. Contiene `scenes`, `scripts`, `resources` y hojas de ruta (`ROADMAP.md`, `ROADMAP_CONTENT.md`).

### nuevo-proyecto-2
Proyecto sandbox/experimental 3D con muchos sistemas mezclados: terreno voxel (`voxel_lod_terrain.gd`, `voxel_manager.gd`), vehículos (`auto.gd`, `bulldozer.gd`), gancho tipo grappling hook (`grappling-hook-3d-main`), agua con shaders (`water.gdshader`), inventario e ítems (`ItemData.gd`, `pickable_item.gd`, `slot.gd`), guardado (`SaveGame.gd`) y ajustes gráficos 3D.

### test-locomocion
Proyecto de pruebas de locomoción de personajes: personajes, modelos, escenas y scripts, con una escena de esqueleto/armature (`armature.tscn`).

## Copias de respaldo

Las carpetas con sufijo `- copia (N)fecha` son respaldos con fecha de los proyectos principales:
- `creaturas-of-sonaria-for-godot - copia (1)6.24` … `copia (16)8.5` — 16 respaldos de *creaturas of sonaria* (de junio a agosto).
- `snowrunner-godot- - copia (1)5.16` … `copia (3)7.13` — 3 respaldos de *snowrunner* (de mayo a julio).

## Notas sueltas

- `dato importante.txt` — apuntes técnicos (escalado automático con `get_aabb()`, prioridades de física con `process_physics_priority`).
- `segundo plan creaturas of sonaria.txt` — segundo plan de diseño de *creaturas of sonaria*: guardado/persistencia, inventario de criaturas, agricultura data-driven y la reestructuración de componentes de las criaturas.

## Cómo abrir los proyectos

Cada carpeta de proyecto contiene su propio `project.godot`. Para abrir uno, importa esa carpeta desde el gestor de proyectos de **Godot 4.6** (para *creaturas of sonaria* se necesita la versión de Godot con soporte .NET/C#).
