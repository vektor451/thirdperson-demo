class_name Math

static func exp_decay(a:float, b:float, d:float, dt:float) -> float:
	return b+(a-b)*exp(-d*dt)

static func exp_decay_vec2(a:Vector2, b:Vector2, d:float, dt:float) -> Vector2:
	return Vector2(
	exp_decay(a.x, b.x, d, dt),
	exp_decay(a.y, b.y, d, dt))

static func exp_decay_vec3(a:Vector3, b:Vector3, d:float, dt:float) -> Vector3:
	return Vector3(
	exp_decay(a.x, b.x, d, dt),
	exp_decay(a.y, b.y, d, dt),
	exp_decay(a.z, b.z, d, dt))
