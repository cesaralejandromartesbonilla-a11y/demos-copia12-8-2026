# Ensamblador Mecánico — esqueleto

Ecosistema nuevo para acoplar motor, engranaje y rueda sobre un larguero
con joints reales. Construido sobre lo que ya tenías — `ModuloSuspension.gd`
como base de suspensión y `ControladorVehiculo_V1.gd` como controlador de
input — sin modificar ninguno de los dos archivos.

## Por qué no hay ningún Generic6DOFJoint3D acá

No hace falta. El larguero es el único cuerpo "estructural" del MVP: motor,
engranaje y rueda cuelgan de él, cada uno con su propio `HingeJoint3D` (el
mismo nodo que ya usás con confianza en los tres archivos de vehículo). No
existe ninguna conexión rígida-contra-rígida en este alcance, así que el
problema ni se presenta todavía.

Si más adelante necesitás pegar un segundo larguero al primero, la
respuesta no es "usar Generic6DOFJoint3D" — es no usar ningún Joint:
agregás el `CollisionShape3D` / `MeshInstance3D` del segundo larguero como
hijos del PRIMER `RigidBody3D`, en vez de crear un `RigidBody3D` nuevo. Es
más robusto que cualquier joint (no hay ningún constraint que el solver
tenga que resolver) y es la misma técnica que usan juegos como Brick Rigs
para sus partes puramente estructurales.

## Jerarquía de escena esperada

```
Construccion (Node3D)                 <- el larguero NO es la raíz de la escena
├── Larguero (RigidBody3D, script Larguero.gd)
│   ├── CollisionShape3D + MeshInstance3D   (tu malla/colisión del chasis)
│   ├── SocketMotor       (SocketMecanico)
│   ├── SocketEngranaje   (SocketMecanico)
│   └── SocketRueda       (SocketMecanico)
├── EnsambladorMecanico (Node, script EnsambladorMecanico.gd)
│   └── larguero  -> arrastrá el nodo Larguero de arriba
└── EnsambladorMecanicoUI (Node3D, script EnsambladorMecanicoUI.gd)
	├── camera       -> tu Camera3D
	└── ensamblador  -> el nodo EnsambladorMecanico de arriba
```

Cada `SocketMecanico`: orientá el nodo en el editor para que su eje **+Z
local** apunte en la dirección de giro que querés para la pieza que se
acople ahí — mismo criterio que `global_transform.basis.z` en
`ModuloSuspension.gd`. Asignale también un `collision_layer` propio (por
ejemplo la capa 10): el raycast de `EnsambladorMecanicoUI` necesita
`collide_with_areas = true` para encontrarlo, y si tenés más Area3D en el
proyecto conviene restringir con `collision_mask` para no chocar con otras.

## Las 3 escenas de pieza (las armás vos en el editor)

Para Motor, Engranaje y Rueda: raíz `RigidBody3D` con el script
correspondiente (`PiezaMotor.gd` / `PiezaEngranaje.gd` / `PiezaRueda.gd`),
más un `CollisionShape3D` + `MeshInstance3D` hijos — podés arrancar con una
caja o un cilindro simple, no hace falta arte final todavía. Guardá cada
una como `.tscn` y asignala al `part_scene` de un `DatosPiezaMecanica.tres`
que crees en el Inspector (uno por pieza, con su `display_name` y
`part_type`).

## Un solo paso en tu ControladorVehiculo_V1 existente

Seleccioná el nodo que tiene `ControladorVehiculo_V1.gd` y agregalo al
grupo **`controlador_vehiculo`** (panel Node → Groups, abajo a la derecha
del editor). `PiezaMotor.gd` se registra solo en `joints_traccion` apenas
se monta — no hace falta tocar una sola línea de `ControladorVehiculo_V1.gd`.

## Para probar

1. Con código o un botón temporal: `ensamblador_ui.set_selected_part(datos_motor)`,
   apuntá con el mouse a `SocketMotor`, clic izquierdo.
2. Repetí con `datos_engranaje` sobre `SocketEngranaje`, y con `datos_rueda`
   sobre `SocketRueda` — probá montar la rueda ANTES del engranaje también,
   para confirmar que `EnsambladorMecanico` la recablea sola cuando el
   engranaje llega después.
3. Dale al acelerador de `ControladorVehiculo_V1`: el motor gira, el
   engranaje sigue su `ratio`, la rueda sigue al engranaje (o al motor
   directo, si todavía no montaste ningún engranaje).

## Si te cuesta armar la jerarquía a mano: `EnsambladorBootstrapper.gd`

Mismo problema que ya tuviste con el constructor de criaturas — acá la
solución es la misma que ya te funcionó: generar la jerarquía por código.
Poné `EnsambladorBootstrapper.gd` en una escena vacía (raíz `Node3D`) y
dale a jugar. Te arma, sin tocar el árbol a mano:

- El `Larguero` con sus 3 `SocketMecanico` ya posicionados.
- `EnsambladorMecanico` y `EnsambladorMecanicoUI` ya cableados entre sí.
- `datos_motor` / `datos_engranaje` / `datos_rueda`: tres `DatosPiezaMecanica`
  con escenas placeholder (una caja de color por pieza) generadas por
  código — no hace falta guardar un solo `.tscn` a mano para la primera
  prueba.

Cuando estés conforme con el resultado, seleccioná el nodo
`EnsambladorBootstrapper` en el árbol remoto (mientras la escena corre) y
usá "Guardar rama como escena" para tener un `.tscn` de verdad — el mismo
flujo de "generar y después reconstruir a mano" que ya usaste antes.

## Modo orbital de tu CameraController.gd

Le agregué un modo nuevo (`enter_orbital_mode` / `exit_orbital_mode`) para
que la misma cámara global orbite el `Larguero` en vez de pelear con una
segunda cámara. Un solo paso de tu lado: agregá el nodo que tiene
`CameraController.gd` al grupo **`camara_principal`** (panel Node >
Groups) — `EnsambladorBootstrapper` lo busca por ese grupo y activa el
modo orbital solo.

Diferencia a propósito con los otros modos: la rotación del modo orbital
NO se apaga con `is_build_mode` (los otros dos sí) — si lo hiciera, no
podrías mirar alrededor mientras construís, que es todo el punto.

## Lo que queda afuera del esqueleto, a propósito

- HUD con pestañas/categorías (como `ChimeraBuilderHUD`) — el punto de
  entrada real es `set_selected_part()`, tres botones alcanzan por ahora.
- Romper/desacoplar piezas (el "explosive physics" de Screw Drivers).
- Ratio de Engranaje calculado desde `dientes` en vez de puesto a mano —
  el campo ya está, solo falta la fórmula el día que la quieras.
