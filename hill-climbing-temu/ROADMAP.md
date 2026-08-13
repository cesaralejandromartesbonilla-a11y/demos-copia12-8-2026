# Hoja de ruta — Hill Climbing MVP (Godot 4.6)

## Visión del MVP

Recrear la experiencia central de **Hill Climb Racing**: conducir un vehículo por terreno irregular en 2D, gestionar combustible, recolectar monedas y tratar de superar tu distancia máxima. Sin metajuego complejo, sin múltiples vehículos ni mapas temáticos en la primera versión jugable.

**Criterio de éxito del MVP:** una sola partida es divertida durante 2–5 minutos, el jugador entiende los controles en menos de 10 segundos, y quiere reintentar para batir su récord de distancia.

---

## Alcance: qué entra y qué queda fuera

| En el MVP | Fuera del MVP (post-MVP) |
|-----------|--------------------------|
| 1 vehículo (jeep/camioneta básica) | Múltiples vehículos (moto, tanque, etc.) |
| 1 mapa procedural infinito | Mapas temáticos (luna, nieve, desierto) |
| Gas + freno (2 botones) | Garaje, skins, cosméticos |
| Control en el aire (rotación) | Sistema de logros |
| Combustible limitado + bidones | Diamantes / moneda premium |
| Monedas en el terreno | Tienda con muchas mejoras |
| 2–3 mejoras básicas | Docenas de niveles por mapa |
| Game over: sin gas / cabeza rota | Multijugador, leaderboards online |
| HUD: distancia, gasolina, monedas | Sonido completo / música |
| Menú simple: jugar + récord local | Monetización, ads, IAP |

---

## Pilares de diseño (referencia del original)

1. **Física expresiva** — El vehículo se siente pesado, las ruedas patinan, los saltos requieren aterrizar bien.
2. **Controles mínimos** — Solo acelerar y frenar; en el aire, rotan el cuerpo del vehículo.
3. **Tensión de recursos** — El combustible obliga a tomar riesgos para llegar a los bidones.
4. **Loop de “una más”** — Distancia como métrica principal; récord guardado localmente.

---

## Arquitectura propuesta en Godot 4.6

> **Nota:** Hill Climbing es un juego **2D**. Usar `RigidBody2D`, `PinJoint2D`/`GrooveJoint2D` o un sistema de ruedas con `RayCast2D`. El proyecto tiene Jolt configurado para 3D; el MVP vivirá en escenas 2D con el motor de física 2D integrado.

```
res://
├── scenes/
│   ├── main.tscn              # Punto de entrada
│   ├── game/
│   │   ├── game_world.tscn    # Nivel + cámara + UI
│   │   ├── vehicle.tscn        # Cuerpo + ruedas + conductor
│   │   └── terrain_chunk.tscn  # Segmento de terreno reutilizable
│   └── ui/
│       ├── hud.tscn
│       ├── game_over.tscn
│       └── main_menu.tscn
├── scripts/
│   ├── autoload/
│   │   ├── game_state.gd      # Monedas, récord, mejoras
│   │   └── event_bus.gd       # Señales globales (opcional)
│   ├── vehicle/
│   │   ├── vehicle_controller.gd
│   │   ├── wheel.gd
│   │   └── driver.gd          # Detección de muerte por cabeza
│   ├── terrain/
│   │   ├── terrain_generator.gd
│   │   └── terrain_chunk.gd
│   ├── pickups/
│   │   ├── coin.gd
│   │   └── fuel_can.gd
│   └── ui/
│       └── hud.gd
├── resources/
│   ├── vehicle_stats.tres     # Resource: motor, grip, suspensión, tanque
│   └── upgrade_defs.tres
└── assets/
	├── sprites/
	├── audio/                 # Post-MVP
	└── fonts/
```

### Decisiones técnicas clave

| Tema | Recomendación MVP |
|------|-------------------|
| Terreno | `StaticBody2D` + `CollisionPolygon2D` generado por puntos (noise/simplex) |
| Vehículo | `RigidBody2D` chasis + 2 ruedas (`RigidBody2D` con `PinJoint2D` o raycast wheels) |
| Cámara | `Camera2D` con seguimiento suave en X, Y con límites |
| Terreno infinito | Chunks de ~2000px; reciclar chunks al salir de pantalla |
| Input | Touch: 2 botones en pantalla / Teclado: `→` gas, `←` freno |
| Persistencia | `ConfigFile` o JSON en `user://save.json` |

---

## Fases de desarrollo

### Fase 0 — Fundamentos del proyecto (0.5–1 día)
**Objetivo:** Esqueleto jugable vacío.

- [ ] Configurar resolución base (ej. 1280×720) y stretch mode para móvil
- [ ] Crear escena `main.tscn` con flujo: Menú → Juego → Game Over
- [ ] Autoload `GameState` (récord, monedas totales)
- [ ] Placeholder art: rectángulos de colores para chasis, ruedas, suelo
- [ ] Input map: `gas`, `brake`

**Entregable:** Presionar "Jugar" carga una escena vacía con cámara.

---

### Fase 1 — Física del vehículo (2–3 días)
**Objetivo:** El coche se mueve y se siente como Hill Climbing.

- [ ] Chasis `RigidBody2D` con masa y centro de masa ajustados
- [ ] Dos ruedas con tracción (torque al motor) y fricción configurable
- [ ] Input gas/freno aplica torque a ruedas en contacto con suelo
- [ ] **Control aéreo:** sin contacto de ruedas → gas/freno aplican torque al chasis
- [ ] Suspensión básica (amortiguación en joints o raycast spring)
- [ ] Evitar que el vehículo se voltee infinitamente (límites de angular velocity opcionales)

**Entregable:** Vehículo sobre un plano inclinado de prueba; se puede subir, bajar y saltar.

**Métricas de feel:**
- Aceleración perceptible en 1–2 s
- Salto controlable en el aire
- Aterrizaje estable si el ángulo es razonable

---

### Fase 2 — Terreno procedural (2–3 días)
**Objetivo:** Camino infinito con colinas variadas.

- [ ] Generador de perfil de terreno (altura por X usando noise o funciones senoidales combinadas)
- [ ] `CollisionPolygon2D` + `Polygon2D` por chunk
- [ ] Sistema de chunks: generar adelante, destruir atrás
- [ ] Sincronizar dificultad suave (pendientes más pronunciadas con la distancia)
- [ ] Decoración mínima (línea de suelo + cielo con `ColorRect` o `ParallaxBackground`)

**Entregable:** Conducir indefinidamente por colinas sin caer al vacío.

---

### Fase 3 — Combustible y game over (1–2 días)
**Objetivo:** Tensión de supervivencia.

- [ ] Barra/tanque de combustible que decrece con el tiempo (más rápido al acelerar)
- [ ] Bidones de gasolina espaciados proceduralmente en el terreno
- [ ] Recoger bidón restaura % de combustible
- [ ] Game over por combustible agotado
- [ ] Conductor con hitbox de cabeza → colisión violenta = muerte (umbral de velocidad/angular)

**Entregable:** Es posible perder por gas o por crash; pantalla de game over con distancia.

---

### Fase 4 — Monedas y economía básica (1–2 días)
**Objetivo:** Recompensa y razón para reintentar.

- [ ] Monedas spawneadas en el terreno (algunas en el aire para incentivar saltos)
- [ ] Contador de monedas en partida + total persistente
- [ ] Bonus por acrobacias simples (tiempo en el aire, flip 360°) — opcional pero alto impacto
- [ ] Pantalla post-partida: distancia, monedas ganadas, récord

**Entregable:** Las monedas persisten entre partidas.

---

### Fase 5 — Mejoras y meta-progresión mínima (1–2 días)
**Objetivo:** 2–3 upgrades que cambien el gameplay.

| Mejora | Efecto |
|--------|--------|
| Motor | Más torque / aceleración |
| Suspensión | Mejor absorción de impactos |
| Tanque | Más capacidad de combustible |

- [ ] Menú simple de mejoras (3 filas con precio en monedas)
- [ ] `VehicleStats` resource aplicado al vehículo al iniciar partida
- [ ] Costos crecientes por nivel (ej. nivel 1–5 por mejora)

**Entregable:** Gastar monedas mejora el coche de forma notable.

---

### Fase 6 — UI, pulido y juice (2–3 días)
**Objetivo:** Sensación de producto terminado (aunque sea MVP).

- [ ] HUD: distancia (m), combustible, monedas de la run
- [ ] Botones táctiles grandes (gas / freno) con feedback visual
- [ ] Cámara: lookahead hacia adelante según velocidad
- [ ] Partículas simples: polvo al aterrizar, chispas al crash
- [ ] Screen shake leve en impactos fuertes
- [ ] Sonido placeholder (motor loop, moneda, crash) — si hay tiempo
- [ ] Main menu: Jugar, Mejoras, récord personal

**Entregable:** Build jugable de punta a punta en PC; preparado para export Android.

---

## Post-MVP — Garaje y contenido

- [x] Menú **Garaje** con pestañas: Vehículos, Mapas, Mejoras por vehículo
- [x] Sistema de desbloqueo con monedas
- [x] Récord por mapa
- [ ] Ver [`ROADMAP_CONTENT.md`](ROADMAP_CONTENT.md) para vehículos y mapas con mecánicas únicas

---

## Cronograma estimado

| Fase | Duración | Acumulado |
|------|----------|-----------|
| 0 — Fundamentos | 0.5–1 día | 1 día |
| 1 — Vehículo | 2–3 días | 4 días |
| 2 — Terreno | 2–3 días | 7 días |
| 3 — Combustible | 1–2 días | 9 días |
| 4 — Monedas | 1–2 días | 11 días |
| 5 — Mejoras | 1–2 días | 13 días |
| 6 — Pulido | 2–3 días | **~15 días** |

*Estimación para 1 desarrollador a tiempo parcial (~3–4 h/día). En tiempo completo: ~1–1.5 semanas.*

---

## Orden de prioridad si hay que recortar

Si el tiempo aprieta, conservar en este orden:

1. Física del vehículo + control aéreo
2. Terreno infinito
3. Combustible + game over
4. Distancia + récord
5. Monedas (sin tienda)
6. Mejoras
7. Juice visual/audio

---

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Física inestable (explosiones, jitter) | Empezar con valores conservadores; `PhysicsMaterial` con fricción alta; sub-steps si hace falta |
| Terreno con colisiones rotas | Generar polígonos convexos por segmento; evitar ángulos de 90° en vértices |
| Sensación "flotante" | Ajustar gravedad (980), masa del chasis, y damping angular |
| Rendimiento en móvil | Pocos chunks activos; sprites simples; sin partículas pesadas en MVP |
| Scope creep | Congelar features al terminar Fase 5; pulido solo en Fase 6 |

---

## Próximo paso inmediato

**Empezar Fase 0 + prototipo de Fase 1 en paralelo:**

1. Crear `vehicle.tscn` con chasis y 2 ruedas
2. Plano de prueba inclinado
3. Iterar hasta que acelerar, frenar y rotar en el aire se sientan bien

Cuando la física del vehículo sea satisfactoria, el resto del MVP es contenido y sistemas encima de esa base.

---

## Referencia rápida de mecánicas (Hill Climb original)

- **Gas:** torque a ruedas (suelo) / rotación nose-down (aire)
- **Freno:** torque inverso (suelo) / rotación nose-up (aire)
- **Muerte:** cuello del conductor + combustible a 0
- **Progresión:** distancia + monedas → mejoras → más distancia
