extends PanelContainer
## Raw game values, an independent scale and a fixed Knight reference.
@export var attribute_label: String = ""
@export var icon: Texture2D
@export var unit: String = ""
@export var precision: int = 0
@export var accent: Color = Color(0.72,0.59,0.36,1)
var raw_value: float = 0.0
var reference_value: float = 0.0
var _description := ""

func _ready() -> void:
	%AttributeLabel.text = attribute_label
	%AttributeIcon.texture = icon
	%Unit.text = unit
	%Unit.visible = not unit.is_empty()
	%AttributeIcon.self_modulate = accent.lightened(0.15)
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	%ComparisonBar.add_theme_stylebox_override("fill",fill)
	_description = tooltip_text
	%Meter.resized.connect(_update_reference_marker)

func set_stat(value: float, maximum: float, reference: float) -> void:
	raw_value = value
	reference_value = reference
	%Value.text = _format(value)
	%DisplayRange.text = "0–" + _format(maximum)
	%ComparisonBar.max_value = maximum
	%ComparisonBar.value = value
	var difference := value-reference
	%ComparisonLabel.text = "与旅人相同" if is_zero_approx(difference) else "较旅人 %s%s" % ["+" if difference > 0 else "−",_format(absf(difference))]
	%ComparisonLabel.add_theme_color_override("font_color",Color(0.65,0.73,0.56) if difference > 0.0001 else Color(0.79,0.54,0.43) if difference < -0.0001 else Color(0.57,0.59,0.57))
	tooltip_text = "%s\n显示区间：0–%s %s\n白线为初始旅人基准：%s %s" % [_description,_format(maximum),unit,_format(reference),unit]
	_update_reference_marker()

func get_value() -> String:
	return %Value.text

func _format(value: float) -> String:
	return ("%.*f" % [precision,value])

func _update_reference_marker() -> void:
	var width: float = %Meter.size.x
	%ReferenceMarker.position.x = clampf(reference_value/%ComparisonBar.max_value*width,0.0,maxf(0.0,width-2.0))
