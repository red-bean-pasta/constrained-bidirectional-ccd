@tool
extends MeshInstance3D
class_name BiCcdSegment


signal transform_changed()

@export var _min_flex_degree: float = NAN
@export var _max_flex_degree: float = NAN
## Default to the average of min and max flex degrees
@export var _rest_flex_degree: float = NAN
## Default to negative max yaw degree
@export var _min_yaw_degree: float = NAN
@export var _max_yaw_degree: float = 0.0
## Default to the average of min and max yaw degrees
@export var _rest_yaw_degree: float = NAN
var joint: BiCcdJoint

@export var index: int
@export var antecedent: BiCcdSegment
@export var subsequent: BiCcdSegment

var flexible: bool:
	get: return joint.flexible
var yawable: bool:
	get: return joint.yawable
## Can be yawed or flexed
var movable: bool:
	get: return flexible or yawable

var _current_flex_cache: TransformCache = TransformCache.new(_get_flex_rad)
var _current_yaw_cache: TransformCache = TransformCache.new(_get_yaw_rad)
var current_flex_rad: float:
	get: return _current_flex_cache.value
var current_yaw_rad: float:
	get: return _current_yaw_cache.value

var length: float:
	get: return get_aabb().size.z
var end_position: Vector3:
	get: return transform * Vector3(0, 0, -length)
## In parent's local space
var prev_basis: Basis:
	get: return antecedent.basis if antecedent else Basis.IDENTITY


func _ready() -> void:
	_validate_fields()
	_validate_origin()
	
	_register_transform_notification()
	
	var rest_flex_degree := _rest_flex_degree if not is_nan(_rest_flex_degree) else (_min_flex_degree + _max_flex_degree) * 0.5
	var flex_spec := BiCcdHingeLimits.create_from_deg(
		_min_flex_degree,
		_max_flex_degree,
		rest_flex_degree,
	)
	var min_yaw_degree := _min_yaw_degree if not is_nan(_min_yaw_degree) else -_max_yaw_degree
	var rest_yaw_degree := _rest_yaw_degree if not is_nan(_rest_yaw_degree) else (min_yaw_degree + _max_yaw_degree) * 0.5
	var yaw_spec := BiCcdHingeLimits.create_from_deg(
		min_yaw_degree,
		_max_yaw_degree,
		rest_yaw_degree,
	)
	joint = BiCcdJoint.new(flex_spec, yaw_spec)
	
	if not antecedent: 
		antecedent = BiCcdUtils.get_previous_sibling(self, BiCcdSegment)
	if not subsequent:
		subsequent = BiCcdUtils.get_next_sibling(self, BiCcdSegment)
	
	await get_tree().process_frame # Wait for other segments to finish sibling finding
	if antecedent:
		assert(antecedent.get_parent() == get_parent())
		assert(antecedent.subsequent == self)
		assert(antecedent.index == index - 1)
	if subsequent:
		assert(subsequent.get_parent() == get_parent())
		assert(subsequent.antecedent == self)
		assert(subsequent.index == index + 1)

func _register_transform_notification() -> void:
	set_notify_transform(true)
	transform_changed.connect(_current_flex_cache.mark_dirty)
	transform_changed.connect(_current_yaw_cache.mark_dirty)

func _validate_origin() -> void:
	if not OS.is_debug_build():
		return
	var aabb := get_aabb()
	assert(is_zero_approx(aabb.position.x + aabb.size.x * 0.5),
		"Origin not centered on X")
	assert(is_zero_approx(aabb.position.y + aabb.size.y),
		"Origin is not at top of Y")
	assert(is_zero_approx(aabb.position.z + aabb.size.z),
		"Origin is not at start of Z")
		
func _validate_fields() -> void:
	assert(not is_nan(_min_flex_degree))
	assert(not is_nan(_max_flex_degree))
	assert(not is_nan(_max_yaw_degree))
	

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		transform_changed.emit()
	

func _get_flex_rad() -> float:
	if not joint.flexible:
		return joint.flex.rest_rad
	var current_up := basis.orthonormalized().y
	var prev_up := prev_basis.orthonormalized().y
	var flex_axis := prev_basis.orthonormalized().x
	var rad := prev_up.signed_angle_to(current_up, flex_axis) + PI # Layout of ->-> actually correspond to the flex of PI instead of 0
	return BiCcdUtils.wrap_rad(rad, joint.flex.min_rad, joint.flex.max_rad)

func _get_yaw_rad() -> float:
	if not joint.yawable:
		return joint.yaw.rest_rad
	
	var only_flex_basis := Basis(Vector3.RIGHT, current_flex_rad - PI)
	var zero_yaw_basis := prev_basis.orthonormalized() * only_flex_basis

	var zero_yaw_forward := zero_yaw_basis.z
	var actual_forward := basis.orthonormalized().z
	var yaw_axis := zero_yaw_basis.y
	
	var rad := zero_yaw_forward.signed_angle_to(actual_forward, yaw_axis)
	return BiCcdUtils.wrap_rad(rad, joint.yaw.min_rad, joint.yaw.max_rad)


func yaw_by(rad: float) -> void:
	if is_zero_approx(fmod(rad, TAU)):
		return
	_ripple_on_transform_method(_transform_yaw_by, rad)
	
func yaw_to(rad: float) -> void:
	var delta := rad - current_yaw_rad
	yaw_by(delta)

func _transform_yaw_by(rad: float) -> void:
	if not joint.yawable:
		push_warning("Trying to yaw unyawable seg: %s" % get_path())
		return
	var clamped := _clamp_yaw_delta(rad)
	var yaw_axis := basis.orthonormalized().y
	rotate(yaw_axis, clamped)

		
func flex_by(rad: float) -> void:
	if is_zero_approx(fmod(rad, TAU)):
		return
	_ripple_on_transform_method(_transform_flex_by, rad)
	
func flex_to(rad: float) -> void:
	var delta := rad - current_flex_rad
	flex_by(delta)

func _transform_flex_by(rad: float) -> void:
	if not joint.flexible:
		push_warning("Trying to flex inflexible seg: %s" % get_path())
		return
	var clamped := _clamp_flex_delta(rad)
	rotate(prev_basis.orthonormalized().x, clamped)


func _ripple_on_transform_method(callable: Callable, arg: Variant) -> void:
	var old := transform
	
	callable.call(arg)
	
	var new := transform
	if not subsequent:
		return
	if new.is_equal_approx(old):
		return
		
	assert(get_parent() == subsequent.get_parent())
	var delta_basis := (new.basis * old.basis.inverse()).orthonormalized()
	var delta := Transform3D(
		delta_basis,
		new.origin - delta_basis * old.origin
	)
	subsequent._ripple_transform(delta)
	
func _ripple_transform(delta: Transform3D) -> void:
	transform = delta * transform
	if subsequent:
		subsequent._ripple_transform(delta)
	

func _clamp_flex_delta(rad: float) -> float:
	var current := current_flex_rad
	var total := current + rad
	var clamped := _clamp_flex(total)
	return clamped - current
	
func _clamp_flex(rad: float) -> float:
	if not joint.flexible:
		return joint.flex.rest_rad
	return joint.flex.clamp(rad)

func _clamp_yaw_delta(rad: float) -> float:
	var current := current_yaw_rad
	var total := current + rad
	var clamped := _clamp_yaw(total)
	return clamped - current

func _clamp_yaw(rad: float) -> float:
	if not joint.yawable:
		return joint.yaw.rest_rad
	return joint.yaw.clamp(rad)


class TransformCache:
	var _dirty: bool = true
	var _refresher: Callable
	var value: Variant = null:
		get: 
			if _dirty:
				value = _refresher.call()
				_dirty = false
			return value
	
	func _init(value_getter: Callable) -> void:
		_refresher = value_getter
	
	func mark_dirty() -> void:
		_dirty = true