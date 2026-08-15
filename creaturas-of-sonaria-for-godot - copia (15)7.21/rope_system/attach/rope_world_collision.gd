class_name RopeWorldCollision
extends RefCounted
## Colisión de reposo por segmento (cápsula orientada) + CCD por
## partícula. Todo lo que consulta PhysicsDirectSpaceState3D vive acá.
##
## PASO 1 de Fase 4: además de corregir posición, ahora REGISTRA el
## contacto sostenido por segmento (state.had_contact_this_frame,
## last_contact_point, last_contact_normal) — insumo que RopeEdgeWrapping
## usa para decidir cuándo insertar un wrap-anchor. También respeta
## partículas pinneadas: no las corrige (ya están en su lugar correcto).

var rope_radius: float = 0.03
var collision_mask: int = 1
var exclude_rids: Array[RID] = []
var collision_reaction_strength: float = 1.0 # cuánto empuja la cuerda a los RigidBody3D que toca (0 = no reacciona)

var _capsule_shape: CapsuleShape3D = CapsuleShape3D.new()
var _ccd_sphere_shape: SphereShape3D = SphereShape3D.new()
var _capsule_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _ccd_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()

func resolve_world_collisions(state: RopeState, space_state: PhysicsDirectSpaceState3D) -> void:
	for i in range(state.pos.size() - 1):
		var a := state.pos[i]
		var b := state.pos[i + 1]
		var segment_vec := b - a
		var length := segment_vec.length()
		if length < 0.001:
			continue
		var direction := segment_vec / length
		var mid := (a + b) * 0.5

		_capsule_shape.radius = rope_radius
		_capsule_shape.height = max(length - rope_radius * 2.0, 0.001)

		var xform := Transform3D()
		xform.basis = Basis(Quaternion(Vector3.UP, direction))
		xform.origin = mid

		var query := _capsule_query
		query.shape = _capsule_shape
		query.transform = xform
		query.collision_mask = collision_mask
		query.exclude = exclude_rids
		query.margin = 0.01

		var result := space_state.get_rest_info(query)
		if result.is_empty():
			continue

		var normal: Vector3 = result.get("normal", Vector3.ZERO)
		var point: Vector3 = result.get("point", mid)
		if normal == Vector3.ZERO:
			continue

		# Registramos el contacto para el sistema de envolvimiento,
		# independientemente de si el segmento está pinneado o no —
		# incluso un segmento pinneado puede "seguir tocando" algo.
		state.had_contact_this_frame[i] = 1
		state.last_contact_point[i] = point
		state.last_contact_normal[i] = normal

		var depth := rope_radius - (mid - point).dot(normal)
		if depth <= 0.0:
			continue

		var correction := normal * depth
		if not state.pinned[i]:
			state.pos[i] += correction
		if not state.pinned[i + 1]:
			state.pos[i + 1] += correction

		if collision_reaction_strength > 0.0:
			var collider_id: int = result.get("collider_id", 0)
			if collider_id != 0:
				var collider := instance_from_id(collider_id)
				if collider is RigidBody3D:
					var reaction := -normal * depth * collision_reaction_strength
					collider.apply_impulse(reaction, point - collider.global_position)

func resolve_continuous_collision(state: RopeState, space_state: PhysicsDirectSpaceState3D) -> void:
	_ccd_sphere_shape.radius = rope_radius

	for i in range(state.pos.size()):
		if state.pinned[i]:
			continue
		var from_pos := state.pos_old[i]
		var to_pos := state.pos[i]
		var motion := to_pos - from_pos
		if motion.length() < 0.0005:
			continue

		var query := _ccd_query
		query.shape = _ccd_sphere_shape
		query.transform = Transform3D(Basis(), from_pos)
		query.motion = motion
		query.collision_mask = collision_mask
		query.exclude = exclude_rids
		query.margin = 0.01

		var result := space_state.cast_motion(query)
		if result.size() < 2:
			continue

		var safe_fraction: float = result[0]
		if safe_fraction < 1.0:
			state.pos[i] = from_pos + motion * safe_fraction
			state.pos_old[i] = state.pos[i]
