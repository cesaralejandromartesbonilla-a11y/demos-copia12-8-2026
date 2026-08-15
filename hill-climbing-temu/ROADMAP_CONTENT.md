# Hoja de ruta — Contenido post-MVP

> **Estado actual:** MVP completo + **Garaje** (vehículos, mapas, mejoras por vehículo).  
> Big Finger y Ártico aparecen en el garaje como contenido bloqueado ("Próximamente").

---

## Visión

Expandir Hill Climbing Temu con **vehículos con mecánicas únicas** y **mapas con reglas de superficie distintas**, manteniendo el núcleo de gas/freno + física 2D.

**Principio de diseño:** cada vehículo resuelve (o sufre) mapas de forma distinta. Un mapa debe premiar el vehículo adecuado y castigar el equipamiento incorrecto.

---

## Arquitectura de contenido (ya implementada)

```
resources/content/
├── vehicles/          # VehicleDef (.tres)
└── maps/              # MapDef (.tres)

scripts/content/
├── vehicle_def.gd
└── map_def.gd

scripts/autoload/
└── content_registry.gd   # Catálogo en runtime

scripts/ui/
└── garage_menu.gd        # Hub: Vehículos | Mapas | Mejoras
```

### Extensión futura recomendada

| Sistema | Propósito |
|---------|-----------|
| `SurfaceProfile` resource | Fricción, grip, deformación por tipo de suelo |
| `VehicleModule` | Comportamiento especial por vehículo (neumáticos deformables, 4WD…) |
| `MapMechanic` | Reglas por mapa (hielo, lagos, gravedad baja…) |
| `TerrainFeature` | Valles → lago, pendientes → hielo, etc. |

---

## Fase A — Sistema de superficies (prerrequisito)

**Objetivo:** el terreno y las ruedas hablan el mismo idioma de fricción.

**Duración estimada:** 3–5 días

### Tareas

- [ ] Crear `SurfaceType` enum: `GRASS`, `DIRT`, `ICE`, `FROZEN_LAKE`, `ROCK`
- [ ] Crear `SurfaceProfile` resource: `friction`, `lateral_grip`, `drive_multiplier`, `visual_color`
- [ ] En `TerrainChunk`, generar segmentos con tipo de superficie (no solo color)
- [ ] En `VehicleWheel.update_physics()`, leer superficie bajo el raycast
- [ ] Añadir `tire_grip_ice` / `tire_grip_default` en `VehicleStats` o `VehicleDef`
- [ ] HUD opcional: icono de superficie bajo las ruedas

### Entregable

El Jeep patina en hielo simulado aunque el mapa Ártico aún no exista como escena jugable.

---

## Fase B — Mapa Ártico

**Objetivo:** mapa con hielo resbaladizo y lagos congelados en depresiones del terreno.

**Duración estimada:** 5–7 días

### Mecánicas

| Mecánica | Descripción |
|----------|-------------|
| **Hielo global** | Toda la superficie usa `SurfaceProfile` ICE (fricción ~0.15–0.25) |
| **Neumáticos inadecuados** | Vehículos sin `ice_grip` pierden tracción; patinaje extremo en subidas |
| **Lagos congelados** | Si el terreno baja más de `lake_depth_threshold` (ej. 45 px bajo media local), rellenar con segmento plano de `FROZEN_LAKE` |
| **Bordes de lago** | Transición suave hielo → lago (menos fricción aún en bordes mojados) |
| **Visual** | Parallax azul/gris, suelo blanco-azul, lagos con tinte cian semitransparente |

### Generación procedural de lagos

```
1. Generar perfil de altura base (noise + suavizado)
2. Calcular media móvil local en ventana de ~400 px
3. Donde height < local_mean - threshold:
   - Aplanar a altura del valle
   - Marcar segmento como FROZEN_LAKE
   - Ancho mínimo del lago: ~200 px (evitar charcos)
4. Suavizar bordes del lago (blend 80 px)
```

### Progresión / balance

- Desbloqueo: **350 monedas** (ya definido en `arctic.tres`)
- Bidones más espaciados (+15%) — más riesgo de quedarse sin gas
- Monedas ligeramente más frecuentes (+10%) — compensación

### Mejoras específicas del mapa (opcional)

- **Cadenas** (upgrade de mapa): +grip en hielo para el vehículo equipado
- **Patas de goma árticas**: upgrade de vehículo con tag `ice_tires`

### Entregable

Mapa Ártico jugable en garaje; sin neumáticos adecuados es casi imposible superar 500 m.

---

## Fase C — Big Finger (neumáticos deformables)

**Objetivo:** vehículo pesado cuyo agarre depende de la deformación visual/física del neumático.

**Duración estimada:** 7–10 días

### Referencia (Hill Climb original)

Monster truck grande, ruedas blandas que se aplastan al contacto, excelente en terreno irregular pero inestable en lago/hielo.

### Mecánicas propuestas

| Mecánica | Implementación |
|----------|----------------|
| **Neumático deformable** | `DeformableWheel` extiende `VehicleWheel`; `compression` visual escala el sprite en Y |
| **Contact patch** | A mayor compresión → mayor área de contacto → más grip (hasta un máximo) |
| **Rebote lento** | Amortiguación baja en eje visual; el neumático "late" al salir de un bache |
| **Masa alta** | Chasis ~120–150 kg; más inercia, volcaduras más violentas |
| **4 ruedas** | 2 ejes; tracción repartida 25% por rueda |
| **Control aéreo lento** | `air_torque` reducido vs Jeep |

### Fórmula de grip deformable (borrador)

```gdscript
var compression_ratio = clamp(compression / rest_length, 0.0, 1.0)
var deform_grip = lerp(base_grip, max_grip, compression_ratio * 0.8)
# En hielo: deform_grip *= ice_penalty (0.3)
```

### Escena

- `scenes/game/vehicles/big_finger.tscn`
- `scripts/vehicle/deformable_wheel.gd`
- `resources/vehicles/big_finger_stats.tres`

### Mejoras individuales (Big Finger)

| Mejora | Efecto |
|--------|--------|
| Motor V8 | +torque |
| Neumáticos blandos | +deformación máxima, +grip en barro |
| Suspensión reforzada | Menos cabeceo en saltos |

### Entregable

Big Finger desbloqueable (500 monedas), dominante en Campo, terrible en Ártico sin upgrades.

---

## Fase D — Más vehículos (backlog)

| Vehículo | Mecánica clave | Mapa ideal |
|----------|----------------|------------|
| **Motocross** | Ligera, volcaduras fáciles, gran control aéreo | Campo / Colinas |
| **Tanque** | Orugas (sin ruedas), grip constante, no patina en hielo moderado | Ártico / Desierto |
| **Monociclo** | 1 rueda, equilibrio activo | Desafío / modo experto |
| **Lunar Rover** | Gravedad reducida, suspensión larga | Luna (mapa futuro) |

---

## Fase E — Más mapas (backlog)

| Mapa | Mecánica clave | Requiere |
|------|----------------|----------|
| **Desierto** | Arena (drag alto, grip bajo en subidas) | Neumáticos anchos |
| **Montaña** | Pendientes extremas, acantilados | Motor + suspensión |
| **Luna** | Gravedad 0.4×, saltos largos | Lunar Rover |
| **Autopista** | Tramos planos + obstáculos | Velocidad pura |

---

## Orden de implementación recomendado

```
A. Sistema de superficies     ← base para todo
B. Mapa Ártico                ← valida superficies + lagos
C. Big Finger                 ← valida ruedas deformables
D/E. Contenido adicional      ← según feedback de juego
```

**Cronograma total estimado:** 3–4 semanas a tiempo parcial.

---

## Criterios de aceptación por hito

### Ártico
- [ ] Patinaje visible sin neumáticos de hielo
- [ ] Lagos aparecen en valles profundos, no en colinas
- [ ] Se puede completar una run de 2+ min con el vehículo correcto
- [ ] Récord por mapa guardado en `map_best_distances`

### Big Finger
- [ ] Neumáticos se deforman visualmente al comprimirse
- [ ] Grip escala con deformación de forma perceptible
- [ ] Se siente distinto al Jeep en la misma colina
- [ ] Mejoras individuales solo afectan a Big Finger

---

## Riesgos

| Riesgo | Mitigación |
|--------|------------|
| Lag frozen lakes rompen colisión | Generar polígonos convexos por segmento; lagos como rectángulos simples |
| Big Finger inestable (física) | Empezar con 4 ruedas raycast; masa y damping conservadores |
| Demasiados upgrades | Máx. 3 por vehículo; costes escalados |
| Scope creep | Un vehículo + un mapa por sprint |

---

## Próximo paso inmediato

**Fase A — Prototipo de superficies:**

1. Añadir `SurfaceProfile` y tag en chunks de terreno
2. Probar fricción 0.2 en un tramo manual del mapa Campo
3. Verificar que el Jeep patina de forma clara

Cuando A esté estable, activar `available = true` en `arctic.tres` e implementar lagos.
