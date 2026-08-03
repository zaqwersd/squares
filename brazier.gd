class_name IslandBrazier
extends StaticBody2D

const SEALED_OUTER_COLORS := [Color("#00646E99"), Color("#008895B5"), Color("#0AA8AC8C")]
const SEALED_INNER_COLORS := [Color("#39CDBBA0"), Color("#74F3D0C8"), Color("#B0FFE2A0")]

@onready var outer_flame: GPUParticles2D = $OuterFlameEmitter
@onready var inner_flame: GPUParticles2D = $InnerFlameEmitter
var _normal_outer_material: ParticleProcessMaterial
var _normal_inner_material: ParticleProcessMaterial

func _ready() -> void:
	_normal_outer_material = outer_flame.process_material as ParticleProcessMaterial
	_normal_inner_material = inner_flame.process_material as ParticleProcessMaterial

func set_sealed(enabled: bool) -> void:
	if not enabled:
		outer_flame.process_material = _normal_outer_material
		inner_flame.process_material = _normal_inner_material
		return
	outer_flame.process_material = _make_colored_material(_normal_outer_material, SEALED_OUTER_COLORS)
	inner_flame.process_material = _make_colored_material(_normal_inner_material, SEALED_INNER_COLORS)

func _make_colored_material(source: ParticleProcessMaterial, colors: Array) -> ParticleProcessMaterial:
	var material := source.duplicate() as ParticleProcessMaterial
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray(colors)
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	material.color_initial_ramp = ramp
	return material
