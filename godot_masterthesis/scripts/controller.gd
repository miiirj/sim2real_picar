extends AIController3D

var movement_history = []
var history_length = 5 * 4
var previous = [0, 0]

@onready var picar = get_parent()
@onready var main = get_parent().get_parent()

func _ready():
  movement_history.resize(history_length)
  movement_history.fill(0.0)

func get_obs() -> Dictionary:
  var obs = []
  movement_history.append_array([_player.left_wheel, _player.right_wheel, snapped(picar.get_raycast_distance() / 3.702, 0.001), picar.get_dr_distance_to_target() / picar.best_goal_distance])
  while (movement_history.size() > history_length):
    movement_history.pop_front()
  obs.append_array(movement_history)
  return {"obs": obs}

func get_reward() -> float:
  var current_reward = reward
  reward = 0
  return current_reward

func get_action_space() -> Dictionary:
  return {
    "left_wheel": {"size": 1, "action_type": "continuous"},
    "right_wheel": {"size": 1, "action_type": "continuous"}
  }

func set_action(action) -> void:
  _player.left_wheel = clamp(action["left_wheel"][0], -1.0, 1.0)
  _player.right_wheel = clamp(action["right_wheel"][0], -1.0, 1.0)
