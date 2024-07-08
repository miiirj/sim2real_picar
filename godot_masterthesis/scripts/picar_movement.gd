extends CharacterBody3D

@export var SPEED = 3
@export var DRIVESPEED = 3
@export var cast: RayCast3D
@export var rays: Node3D
@export var spot: Node3D
@export var manualDrive = true
@export var cameraMode = false

@onready var ai_controller
@onready var virtual_cam = $VirtualCamera
@onready var main = get_parent()

var last_few_moves = []

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var left_wheel := 0.0
var right_wheel := 0.0

var best_goal_distance
var calculated_linear_velocity = 0
var calculated_angular_velocity = 0
var COLLISION_DISTANCE = 1.5
var inital_distance
var old_distance

func _ready():
  if cameraMode:
    ai_controller = $AIController3DCamera
    $AIController3D.set_process(false)
    $AIController3D.remove_from_group("AGENT")
  else:
    ai_controller = $AIController3D
    virtual_cam.deactivate_preview()
    $AIController3DCamera.set_process(false)
    $AIController3DCamera.remove_from_group("AGENT")
    virtual_cam.set_process(false)

  print("distance ", get_raycast_distance())
  ai_controller.init(self)

func _physics_process(delta):
  if not is_on_floor():
    position.y -= gravity * delta

  # reset 
  if ai_controller.needs_reset: # and not ai_controller.heuristic == "human":
    main.reset()
    return

  if ai_controller.heuristic == "human":
    if manualDrive:
      move_car_player(delta)
      get_distance_to_target()

    else:
      var wheels = $AutomaticDriver.null_policy(get_raycast_distance())
      move_car(wheels[0], wheels[1])
  else:
    # MOVEMENT PUNISHMENT/REWARDS
    move_car(left_wheel, right_wheel)
    wheel_based_encouragement()
    #punish_backwards()
    #punish_similar_moves_old()
    #punish_similar_moves_count()
    #encourage_forwards()
    #punish_circles()

    update_reward()

func move_car_player(delta):
  var left_fwd = Input.get_action_strength("left_fwd");
  var right_fwd = Input.get_action_strength("right_fwd");
  var left_bwd = Input.get_action_strength("left_bwd");
  var right_bwd = Input.get_action_strength("right_bwd");
  var forward = clamp((left_fwd + right_fwd - (left_bwd + right_bwd)), -1.0, 1.0); # think about /2
  var left = clamp((left_bwd + right_fwd - (left_fwd + right_bwd)), -1.0, 1.0);
  rotate_y(left * SPEED / 2 * delta)
  velocity = (transform.basis * Vector3(0, 0, forward)).normalized() * SPEED
  move_and_slide()

func move_car(speed_left, speed_right):
  speed_left *= 0.5
  speed_right *= 0.5
  var forward = clamp((speed_left + speed_right) / 2, -1.0, 1.0)
  var left = clamp(( - speed_left + speed_right) / 2, -1.0, 1.0);
  calculated_linear_velocity = sqrt(pow(forward, 2) + pow(left, 2)) * (1 if forward < 0 else - 1)
  calculated_angular_velocity = sqrt(pow(forward, 2) + pow(left, 2)) * (1 if left < 0 else - 1)

  rotate_y(left * SPEED * get_physics_process_delta_time())
  velocity = (transform.basis * Vector3(0, 0, forward)).normalized() * SPEED
  move_and_slide()

func get_raycast_distance():
  var distances = [3.702]
  for ray in rays.get_children():
    var distance = 0
    if ray.is_colliding():
      distance = ray.global_position.distance_to(ray.get_collision_point())
      distances.append(distance)
  return distances.min()

func get_raycast_absolute_measure():
  var distance = 0
  if cast.is_colliding():
    distance = cast.global_position.distance_to(cast.get_collision_point())
  
  if distance < 0.5:
    return - 2
  if distance < 0.9:
    return - 1
  if distance < 1.5:
    return 0
  if distance < 2.5:
    return 1
  return 2

func get_distance_to_target(): #
  var distance = 0
  if spot != null:
    distance = max(position.distance_to(spot.position) - spot.get_node("MeshInstance3D").get_aabb().size[0], 0)
  return distance

func get_hot_cold_distance():
  var distance = get_distance_to_target()

  distance = snapped(distance, 0.01)
  var hot_cold = 0
  if old_distance != null:
    if old_distance > distance:
      hot_cold = 1
    if old_distance < distance:
      hot_cold = -1
  old_distance = distance
  return hot_cold

var rng = RandomNumberGenerator.new()
func get_dr_distance_to_target():
  var distance = get_distance_to_target()
  var val = rng.randfn(distance, 4.5)
  return val

# region movement_punishment
func punish_similar_moves_count():
  var left = -left_wheel + right_wheel;

  last_few_moves.push_back(1 if left > 0.4 else ( - 1 if left < - 0.4 else 0))
  if last_few_moves.size() > 50:
    last_few_moves.pop_front()

  if last_few_moves.count(1) >= 50 or last_few_moves.count( - 1) >= 50:
    ai_controller.reward -= 10
    print("he is doign circles again")

func wheel_based_encouragement():
  var encourage = clampf((left_wheel + right_wheel), -2.0, 1)
  #print(left_wheel, right_wheel)
  ai_controller.reward += encourage

func punish_backwards():
  if left_wheel < 0 and right_wheel < 0 and get_raycast_distance() > 1.5:
    ai_controller.reward -= 1

func sum(accum, number):
  return accum + number

func punish_circles():
  var direction_penalty = abs(left_wheel - right_wheel) * 5 # Scale the penalty
  ai_controller.reward -= direction_penalty

func encourage_forwards():
  if left_wheel > 0 and left_wheel == right_wheel:
    ai_controller.reward += 1
# endregion

#region Collision stats
func _on_back_collision_body_entered(_body):
  main.back_collisions += 1
  ai_controller.reward -= 10

func _on_front_collision_body_entered(_body):
  main.front_collisions += 1
#endregion

func update_reward():
  ai_controller.reward -= 0.01 # step penalty
  ai_controller.reward += shaping_reward()

func shaping_reward():
  var current_reward = 0
  #if get_raycast_distance() < COLLISION_DISTANCE:
    #current_reward -= (COLLISION_DISTANCE - get_raycast_distance()) * 10 # more punishment the closer to target
  current_reward += get_raycast_absolute_measure()

  current_reward -= (get_distance_to_target() / best_goal_distance if best_goal_distance > 0 else 0.1)
  
  if get_distance_to_target() == 0:
    current_reward += 1000
    ai_controller.done = true
    main.reset(true)

  return current_reward