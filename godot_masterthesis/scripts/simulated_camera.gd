extends Node3D
var camera_pixels = null
var steps = 0

@onready var camera_texture := $Control/TextureRect/CameraTexture as Sprite2D
@onready var sub_viewport := $SubViewport as SubViewport

var flattened = []

func deactivate_preview():
    $Control.visible = false

func get_camera_pixel_encoding():
    var encoded = camera_texture.get_texture().get_image().get_data()

    return encoded

func get_camera_shape() -> Array:
    if sub_viewport.transparent_bg:
        return [4, sub_viewport.size.y, sub_viewport.size.x]
    else:
        return [3, sub_viewport.size.y, sub_viewport.size.x]

func _physics_process(delta):
    steps += 1
    if steps == 1:
        print(get_camera_shape())
