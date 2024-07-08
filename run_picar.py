import time
import onnxruntime as ort
import numpy as np


from bluepy.btle import Scanner
from adafruit_pca9685 import PCA9685
import busio
from board import SCL, SDA
import RPi.GPIO as GPIO


ONNX_PATH = 'onnx/hot_and_cold.onnx'
OBS = [0]*20
HISTORY_LENGTH = 20
state_ins = np.zeros((1,), dtype=np.float32)
last_distance = None


# region PiCar Driving (https://osoyoo.com/driver/picar/picar-obstacle-avoid.py)
i2c_bus = busio.I2C(SCL, SDA)

GPIO.setmode(GPIO.BCM)
GPIO.setwarnings(False)
pwm = PCA9685(i2c_bus)

# Define GPIO to use on Pi
GPIO_TRIGGER = 20
GPIO_ECHO = 21

# Set frequency to 50hz, good for servos.
pwm.frequency = 50
# Alternatively specify a different address and/or bus:
base_speed = 0x7FFF  # Max pulse length out of 4096

GPIO.setmode(GPIO.BCM)  # GPIO number  in BCM mode
GPIO.setwarnings(False)
# define L298N(Model-Pi motor drive board) GPIO pins
LBW = 23  # left motor direction pin
LFW = 24  # left motor direction pin // left forward
RBW = 27  # right motor direction pin
RFW = 22  # right motor direction pin // right forward
ENA = 0  # left motor speed PCA9685 port 0
ENB = 1  # right motor speed PCA9685 port 1

# Define motor control  pins as output
GPIO.setup(GPIO_TRIGGER, GPIO.OUT)  # Trigger
GPIO.setup(GPIO_ECHO, GPIO.IN)      # Echo
GPIO.setup(LBW, GPIO.OUT)
GPIO.setup(LFW, GPIO.OUT)
GPIO.setup(RBW, GPIO.OUT)
GPIO.setup(RFW, GPIO.OUT)


def changespeed(left_speed, right_speed):
    pwm.channels[ENB].duty_cycle = int(base_speed * abs(left_speed))
    pwm.channels[ENA].duty_cycle = int(base_speed * abs(right_speed))


def stopcar():
    GPIO.output(LBW, GPIO.LOW)
    GPIO.output(LFW, GPIO.LOW)
    GPIO.output(RBW, GPIO.LOW)
    GPIO.output(RFW, GPIO.LOW)
    changespeed(0, 0)


def move_car(speed_left, speed_right):
    # works for forward and backward
    GPIO.output(LBW, GPIO.HIGH if speed_left < 0 else GPIO.LOW)
    GPIO.output(LFW, GPIO.HIGH if speed_left >= 0 else GPIO.LOW)
    GPIO.output(RBW, GPIO.HIGH if speed_right < 0 else GPIO.LOW)
    GPIO.output(RFW, GPIO.HIGH if speed_right >= 0 else GPIO.LOW)
    print("Left backward", "high" if speed_left < 0 else "low")
    print("Left fwd", "high" if speed_left >= 0 else "low")
    print("Right backward", "high" if speed_right < 0 else "low")
    print("Right fwd", "high" if speed_right >= 0 else "low")
    changespeed(speed_left, speed_right)


def clamp(number, min_nr=-1, max_nr=1):
    return max(min(number, max_nr), min_nr)


def measure():
    # This function measures a distance
    last_distances = []
    for i in range(10):
        GPIO.output(GPIO_TRIGGER, True)
        time.sleep(0.00001)
        GPIO.output(GPIO_TRIGGER, False)
        start = time.time()
        while GPIO.input(GPIO_ECHO) == 0:
            start = time.time()
        while GPIO.input(GPIO_ECHO) == 1:
            stop = time.time()
        elapsed = stop-start
        distance = (elapsed * 34300)/2
        last_distances.append(distance)
        time.sleep(0.1)
    median_val = np.median(last_distances)
    print(median_val)
    # if median_val > 1000:
    # return 0
    return median_val
# endregion


def start_scan():
    last_scans = []
    for _ in range(20):
        try:
            ble_list = Scanner().scan(0.05)
            for dev in ble_list:
                if dev.addr == "54:6c:0e:b7:53:86":
                    last_scans.append(dev.rssi)
        except:
            raise Exception("Error occured")
    return abs(np.median(last_scans))  # because rssi is negative


def build_observations(*args):
    global OBS
    assert len(args) == (HISTORY_LENGTH/5)
    OBS += args

    list_length = len(OBS)
    if list_length > HISTORY_LENGTH:
        cull = list_length - HISTORY_LENGTH
        del OBS[0:cull]


def normalize_target_distance(curr, min, max):
    # return (curr - min)/(max - min)
    global last_distance

    hot_cold = 0
    if not last_distance is None:
        if last_distance > curr:
            hot_cold = 1
        if last_distance < curr:
            hot_cold = -1
    last_distance = curr
    return hot_cold


def normalize_raycast_distance(curr, base):
    return clamp((curr-10)/(40-10), 0, 1)
    # return min(curr / base, 1)


def get_actions(actions):
    left, right = actions[0]
    return clamp(left), clamp(right)


def main():
    global OBS
    i = 0
    command = input("Starting the Car, please place car on top of sensor and confirm afterwards ")
    if (command == "x"):
        return
    zero_val = start_scan()
    input(f"Scanning done: {zero_val} RSSI. \n Please place vehicle in starting spot and confirm afterwards ")
    if (command == "x"):
        return
    base_val = start_scan()
    input(f"Scanning done: {base_val} RSSI. \n Starting the program once you confirm ")
    if (command == "x"):
        return

    ort_sess = ort.InferenceSession(ONNX_PATH)
    base_raycast = measure()
    print(f"BASE RAYCAST: {base_raycast}")
    build_observations(0, 0, normalize_raycast_distance(base_raycast, base_raycast), normalize_target_distance(base_val, zero_val, base_val))
    stopcar()

    while i < 50:
        try:
            i += 1
            inputs = {
                "obs": np.reshape(OBS, (1, HISTORY_LENGTH)).astype(np.float32),
                "state_ins": state_ins
            }
            print("Getting actions")
            actions, values = ort_sess.run(None, inputs)
            left, right = get_actions(actions)
            move_car(left, right)
            print("Actions received", actions, left, right)
            time.sleep(0.5)
            stopcar()
            new_target_distance = int(input("Hot & Cold Input: "))  # normalize_target_distance(start_scan(), zero_val, base_val)
            new_raycast_distance = normalize_raycast_distance(measure(), base_raycast)

            print(f"Timestep {i} passed: Target={new_target_distance}, Collision={new_raycast_distance}")
            build_observations(left, right, new_raycast_distance, new_target_distance)

        except KeyboardInterrupt:
            print("### Stopping ###")
            stopcar()
            break


if __name__ == "__main__":
    main()
