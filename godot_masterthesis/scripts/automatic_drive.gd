extends Node

var last_X_distances = []
var last_X_collisions = []
var last_few_moves = [[0, 0]]
var deal_with_collision = 5
var collision_distance = 1.6

var move = [1, 1]

func drivePiCar(distance_to_collision, distance_to_target):
    last_X_collisions.append(distance_to_collision)
    last_X_distances.append(distance_to_target)

    while last_X_collisions.size() > 5:
        last_X_collisions.pop_front()
        last_X_distances.pop_front()
    print("Look ma, no hands ", distance_to_collision, " ", distance_to_target)

    if last_X_collisions.any(func(number): return number < collision_distance):
        move = [1, - 1]
        last_few_moves.append(move)
        return move

    # compare first and last element
    if last_X_distances[0] - last_X_distances[- 1] > 1:
        move = [0.5, 0.5] # Slight left
    elif last_few_moves[- 1][0] == - 1 and last_few_moves[- 1][1] == - 1:
        move = [0.5, 0.5] # Slight left
    elif distance_to_collision < collision_distance:
        move = [- 1, - 1] # Brake
    else:
        move = [1, 1] # Forward

    last_few_moves.append(move)
    return move

var rng = RandomNumberGenerator.new()
func null_policy(distance_to_collision):
    if distance_to_collision < collision_distance:
        return [- 1, 1] # Turn

    var left = clampf(rng.randfn(0.5, 1), -1, 1)
    var right = clampf(rng.randfn(0.5, 1), -1, 1)
    return [left, right]
