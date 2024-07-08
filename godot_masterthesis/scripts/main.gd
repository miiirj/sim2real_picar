extends Node3D

@export var obstacles: Vector2 = Vector2(2, 7)
var environment: GridMap;
var occupied_cells: Array[Vector3i] = []

var reached_goal = 0
var average_distance_to_goal = 0
var tries = -1
var back_collisions := 0.0
var front_collisions := 0.0
var list_of_back_collisions = []

var collision_distance = 1.6

func _ready():
  reset()

func _spawn_picar():
  while true:
    var cell = environment.get_used_cells_by_item(0).pick_random()
    if cell not in occupied_cells:
      occupied_cells.append(cell)
      var new_pos = environment.local_to_map(cell * 4)
      $PiCar.position = Vector3(new_pos.x, 1, new_pos.z)
      break

func _spawn_obstacles():
  for n in $Obstacles.get_children():
    $Obstacles.remove_child(n)
    n.queue_free()

  var number_of_obstacles = range(obstacles.x, obstacles.y).pick_random()
  for i in range(number_of_obstacles):
    #print("Spawning obstacle: ", i)
    while true:
      var cell = environment.get_used_cells_by_item(0).pick_random()
      if cell not in occupied_cells:
        occupied_cells.append(cell)
        _spawn_box(environment.local_to_map(cell * 4))
        break

func _spawn_box(pos):
  var box = load("res://scenes/box.tscn").instantiate()
  box.position = Vector3(pos.x, 0.45, pos.z)
  $Obstacles.add_child(box)

func _move_target():
  while true:
    var cell = environment.get_used_cells_by_item(0).pick_random()
    if cell not in occupied_cells:
      occupied_cells.append(cell)
      $Spot.visible = true
      var new_pos = environment.local_to_map(cell * 4)
      $Spot.position = Vector3(new_pos.x, 0.15, new_pos.z)
      break

func _choose_random_world(number=null):
  var selected_map;
  if (number in range($Maps.get_children().size())):
    print("Using map ", number)
    selected_map = number
  else:
    selected_map = range($Maps.get_children().size()).pick_random()
  for i in range($Maps.get_children().size()):
    if (i != selected_map):
      $Maps.get_children()[i].collision_layer = 0
      $Maps.get_children()[i].visible = false
    else:
      $Maps.get_children()[i].collision_layer = 1
      environment = $Maps.get_children()[i]
      environment.visible = true

func _fill_all_cells():
  for cell in environment.get_used_cells_by_item(0):
    var new_pos = environment.local_to_map(cell * 4)
    var new_spot = load("res://scenes/spot.tscn").instantiate()
    new_spot.position = Vector3(new_pos.x, 0.15, new_pos.z)
    $Spots.add_child(new_spot)

func _get_position_ignore_y(pos):
  return Vector2(pos.x, pos.z)

var average_back_collisions = 0
var average_front_collisions = 0

func reset(goal=false):
  if tries > 0:
    average_distance_to_goal = ((average_distance_to_goal * (tries - 1)) + $PiCar.get_distance_to_target()) / (tries)
    list_of_back_collisions.append(back_collisions)
    average_back_collisions = ((average_back_collisions * (tries - 1)) + back_collisions) / (tries)
    average_front_collisions = ((average_front_collisions * (tries - 1)) + front_collisions) / (tries)
  if goal:
    reached_goal += 1

  print_stats()
  udpate_stats()
  $PiCar.ai_controller.reset()
  $PiCar.left_wheel = 0.0
  $PiCar.right_wheel = 0.0

  occupied_cells = []
  _choose_random_world()
  _spawn_picar()
  _move_target()
  _spawn_obstacles()
  $PiCar.best_goal_distance = $PiCar.get_distance_to_target()

func udpate_stats():
  occupied_cells = []
  front_collisions = 0
  back_collisions = 0
  tries += 1

func print_stats():
  print("======== STATS ========", name)
  print("Reached Goal: ", reached_goal)
  print("Average Distance ", average_distance_to_goal)
  print("Total tries ", tries)
  print("Collisions back (average) ", average_back_collisions, " ", back_collisions)
  print("Collisions front (average) ", average_front_collisions, " ", front_collisions)
  print(reached_goal, ",", average_distance_to_goal, ",", tries, ",", average_back_collisions, ",", average_front_collisions)
