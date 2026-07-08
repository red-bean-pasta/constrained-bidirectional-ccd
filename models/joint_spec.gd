@tool
## An object model to specify segment rotations constraints with convenient initialization methods
class_name BiCcdJointSpec

var flex: BiCcdHingeLimits
var yaw: BiCcdHingeLimits

func _init(
	p_flex: BiCcdHingeLimits,
	p_yaw: BiCcdHingeLimits,
) -> void:
	flex = p_flex
	yaw = p_yaw

func apply_to_segment(seg: BiCcdSegment) -> void:
	seg._min_flex_degree = flex.min_deg
	seg._max_flex_degree = flex.max_deg
	seg._rest_flex_degree = flex.rest_deg
	seg._min_yaw_degree = yaw.min_deg
	seg._max_yaw_degree = yaw.max_deg
	seg._rest_yaw_degree = yaw.rest_deg


## [rest_yaw_degree]: If NaN, default to the average of min and max yaw degrees 
static func create_inflexible(
	rest_flex_degree: float,
	min_yaw_degree: float,
	max_yaw_degree: float,
	rest_yaw_degree: float = NAN,
) -> BiCcdJointSpec:
	return BiCcdJointSpec.new(
		create_fixed_flex(rest_flex_degree),
		BiCcdHingeLimits.create_from_deg(min_yaw_degree, max_yaw_degree, rest_yaw_degree)
	)

## [rest_yaw_degree]: If NaN, default to the average of min and max yaw degrees 
static func create_unyawable(
	rest_yaw_degree: float,
	min_flex_degree: float,
	max_flex_degree: float,
	rest_flex_degree: float = NAN
) -> BiCcdJointSpec:
	return BiCcdJointSpec.new(
		BiCcdHingeLimits.create_from_deg(min_flex_degree, max_flex_degree, rest_flex_degree),
		create_fixed_yaw(rest_yaw_degree)
	)
	
static func create_inflexible_unyawable(
	rest_flex_degree: float,
	rest_yaw_degree: float,
) -> BiCcdJointSpec:
	return BiCcdJointSpec.new(
		create_fixed_flex(rest_flex_degree),
		create_fixed_yaw(rest_yaw_degree)
	)


static func create_symmetrical_yawable(
	pos_yaw_degree: float,
	min_flex_degree: float,
	max_flex_degree: float,
	rest_flex_degree: float = NAN,
) -> BiCcdJointSpec:
	return BiCcdJointSpec.new(
		BiCcdHingeLimits.create_from_deg(min_flex_degree, max_flex_degree, rest_flex_degree),
		create_symmetrical_yaw(pos_yaw_degree)
	)
	
static func create_symmetrical_yawable_inflexible(
	pos_yaw_degree: float,
	rest_flex_degree: float,
) -> BiCcdJointSpec:
	return BiCcdJointSpec.new(
		create_fixed_flex(rest_flex_degree),
		create_symmetrical_yaw(pos_yaw_degree)
	)
	
static func create_unfold_symmetrical_flexible(
	flex_delta: float,
	min_yaw_degree: float,
	max_yaw_degree: float,
	rest_yaw_degree: float = NAN,
) -> BiCcdJointSpec:
	return BiCcdJointSpec.new(
		create_unfold_symmetrical_flex(flex_delta),
		BiCcdHingeLimits.create_from_deg(min_yaw_degree, max_yaw_degree, rest_yaw_degree)
	)
	
static func create_unfold_symmetrical_flexible_unyawable(
	flex_delta: float,
	rest_yaw_degree: float,
) -> BiCcdJointSpec:
	return BiCcdJointSpec.new(
		create_unfold_symmetrical_flex(flex_delta),
		create_fixed_yaw(rest_yaw_degree)
	)


static func create_fixed_yaw(rest_degree: float) -> BiCcdHingeLimits:
	return BiCcdHingeLimits.create_unrotatable_from_deg(rest_degree)

static func create_fixed_flex(rest_degree: float) -> BiCcdHingeLimits:
	return BiCcdHingeLimits.create_unrotatable_from_deg(rest_degree)


static func create_symmetrical_yaw(
	positive_degree: float
) -> BiCcdHingeLimits:
	assert(positive_degree > 0)
	return BiCcdHingeLimits.create_from_deg(
		-positive_degree,
		positive_degree,
	)

static func create_unfold_symmetrical_flex(
	flex_degree_delta: float
) -> BiCcdHingeLimits:
	assert(not is_zero_approx(flex_degree_delta))
	if flex_degree_delta < 0:
		flex_degree_delta = -flex_degree_delta
	return BiCcdHingeLimits.create_from_deg(
		180 - flex_degree_delta,
		180 + flex_degree_delta,
	)