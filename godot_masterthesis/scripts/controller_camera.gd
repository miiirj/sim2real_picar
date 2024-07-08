extends AIController3D

var left_wheel: float = 0.0
var right_wheel: float = 0.0
var previous_distance_to_goal = 0
var factor = 10

var camera_history = []
var distance_history = []
var history_length = 3
var other_history = 4

@onready var picar = get_parent()
@onready var main = get_parent().get_parent()

func _ready():
  previous_distance_to_goal = picar.get_distance_to_target()
  distance_history.resize(history_length * other_history)
  distance_history.fill(0)

func get_obs() -> Dictionary:
  var obs = []

  while (camera_history.size() < history_length):
    camera_history.append(picar.virtual_cam.get_camera_pixel_encoding())
  camera_history.append(picar.virtual_cam.get_camera_pixel_encoding())
  while (camera_history.size() > history_length):
    camera_history.pop_front()
  distance_history.append_array([_player.left_wheel, _player.right_wheel, picar.get_distance_to_target() / picar.best_goal_distance])

  while (distance_history.size() > history_length * other_history):
    distance_history.pop_front()

  #print("test", PackedInt32Array(camera_history).hex_encode())
  return {"camera_2d": camera_history, "obs": distance_history}

func get_obs_space():
  # types of obs space: box, discrete, repeated
  var new_size = [history_length]
  new_size.append_array(picar.virtual_cam.get_camera_shape())
  return {
    "camera_2d": {"size": new_size, "space": "box"},
    "obs": {"size": [history_length * other_history],"space": "box"}
  }

func get_reward() -> float:
  var current_reward = reward
  reward = 0

  #print("reward: ", current_reward)
  return current_reward

func get_action_space() -> Dictionary:
  return {
    "left_wheel": {"size": 1, "action_type": "continuous"},
    "right_wheel": {"size": 1, "action_type": "continuous"}
  }

func set_action(action) -> void:
  _player.left_wheel = clamp(action["left_wheel"][0], -1.0, 1.0)
  _player.right_wheel = clamp(action["right_wheel"][0], -1.0, 1.0)
