@tool
class_name BiCcdHingeLimits


var min_rad: float
var min_deg: float:
	get: return rad_to_deg(min_rad)
	set(value): min_rad = deg_to_rad(value)
	
var max_rad: float
var max_deg: float:
	get: return rad_to_deg(max_rad)
	set(value): max_rad = deg_to_rad(value)
	
var rest_rad: float
var rest_deg: float:
	get: return rad_to_deg(rest_rad)
	set(value): rest_rad = deg_to_rad(value)

var rotatable: bool:
	get: return not is_equal_approx(min_rad, max_rad)
	

func _init(
	p_min_rad: float, 
	p_max_rad: float,
	p_rest_rad: float = NAN,
) -> void:
	assert(not is_nan(p_min_rad) and not is_nan(p_max_rad))
	assert(p_min_rad <= p_max_rad)
	min_rad = p_min_rad
	max_rad = p_max_rad
	rest_rad = p_rest_rad if not is_nan(p_rest_rad) else (p_min_rad + p_max_rad) * 0.5
	BiCcdUtils.assert_range(rest_rad, min_rad, max_rad)
	
static func create_from_deg(
	p_min_deg: float, 
	p_max_deg: float,
	p_rest_deg: float = NAN,
) -> BiCcdHingeLimits:
	return BiCcdHingeLimits.new(
		deg_to_rad(p_min_deg),
		deg_to_rad(p_max_deg),
		deg_to_rad(p_rest_deg),
	)

static func create_unrotatable(p_rest_rad: float) -> BiCcdHingeLimits:
	return BiCcdHingeLimits.new(p_rest_rad, p_rest_rad, p_rest_rad)

static func create_unrotatable_from_deg(p_rest_deg: float) -> BiCcdHingeLimits:
	return create_from_deg(p_rest_deg, p_rest_deg, p_rest_deg)
	
	
func clamp(rad: float) -> float:
	return BiCcdUtils.wrap_clamp_rad(rad, min_rad, max_rad)
	
func check_within_range(rad: float) -> bool:
	var wrapped := BiCcdUtils.wrap_rad(rad, min_rad, max_rad)
	return min_rad <= wrapped and wrapped <= max_rad