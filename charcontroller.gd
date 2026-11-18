extends CharacterBody3D

const CAM_MAX_X = 60.0

@export_category("speed")
@export var move_speed = 5.0
@export var jump_velocity = 5.0
@export var cam_sens_joy_min = 90.0
@export var cam_sens_joy_max = 270.0
@export var cam_sens_mouse = 6.0

@export_category("smoothing")
@export var move_smooth = 8.0
@export var rotation_speed = 1080.0
@export var cam_pos_smooth = 12.0
@export var cam_accell_smooth = 8.0
@export var cam_decell_smooth = 24.0
@export var cam_reset_smooth = 12.0

@export_category("cam reset")
@export var cam_reset_time = 0.25

var _wish_dir: Vector3
var _move_input: Vector3
var _wish_xz_vel: Vector3
var _cam_sens_joy: float
var _cam_velocity: Vector3

var _reset_cam_timer: SceneTreeTimer
var _cam_resetting: bool
var _cam_reset_y: float

func get_move_dir() -> void:
	# WASD / Stick movement.
	_move_input.z = Input.get_axis("moveForward", "moveBackward")
	_move_input.x = Input.get_axis("moveLeft", "moveRight")
	
	# Making sure you cannot go above max speed when moving diagonally.
	if (_move_input.length() > 1):
		_move_input = _move_input.normalized()
	
	# Rotate movement input by the direction the camera is facing.
	_wish_dir = _move_input.rotated(Vector3.UP, %CameraPivot.global_basis.get_euler().y)

func move_player(delta: float) -> void:
	# This is our desired movement speed.
	_wish_xz_vel = _wish_dir * move_speed
	
	# Copy the velocity vector from last move_and_slide() call. 
	# We clear Y so that we can seperate jumping/falling from our movement input.
	var target_vel = velocity
	target_vel.y = 0
	
	# Interpolate towards desired movement speed.
	target_vel = Math.exp_decay_vec3(target_vel, _wish_xz_vel, move_smooth, delta)
	
	# Reintroduce Y velocity, applying gravity while we're at it. 
	target_vel.y = velocity.y + get_gravity().y * delta
	
	# Basic jump.
	if (Input.is_action_just_pressed("jump") && is_on_floor()):
		target_vel.y = jump_velocity
	
	# Set our velocity and simulate movement.
	velocity = target_vel
	move_and_slide()

func rotate_player_model(delta: float) -> void:
	# Assign our rotation target using look_at. The node will be rotated in the direction we are moving. 
	if (_move_input.length() > 0):
		var xz_vel = velocity
		xz_vel.y = 0
		%RotationTarget.look_at(%RotationTarget.global_position + xz_vel)
		
	# Smoothly rotate the model in the direction we're heading.
	%CharacterModel.rotation.y = rotate_toward(%CharacterModel.rotation.y, %RotationTarget.rotation.y, deg_to_rad(rotation_speed * delta))
	
func move_camera(delta: float) -> void:
	# Camera rotation is locked during reset.
	if(_reset_cam_timer.time_left <= 0):
		# Get joypad stick vector.
		var cam_input: Vector3
		cam_input.x = Input.get_axis("camDown", "camUp")
		cam_input.y = Input.get_axis("camRight", "camLeft")
		
		# Apply smoothing to camera speed when using joypad. 
		if (cam_input.length() != 0):
			_cam_sens_joy = Math.exp_decay(clamp(_cam_sens_joy, cam_sens_joy_min, cam_sens_joy_max), cam_sens_joy_max, cam_accell_smooth, delta)
			_cam_velocity = cam_input * _cam_sens_joy * delta
			
			# Once the timer runs out, this will make it so the camera stops trying to reset.
			_cam_resetting = false 
		else:
			_cam_velocity = Math.exp_decay_vec3(_cam_velocity, Vector3.ZERO, cam_decell_smooth, delta)
			_cam_sens_joy = cam_sens_joy_min
		
		# Rotate the camera.
		%CameraPivot.rotation_degrees += _cam_velocity
		
		# Stop the camera going too far up or down, otherwise we'll go upside down or under the ground!
		%CameraPivot.rotation_degrees.x = clamp(%CameraPivot.rotation_degrees.x, -CAM_MAX_X, CAM_MAX_X)
	
	# Smoothly move the camera towards the player position. This makes camera movement feel more dynamic.
	%CameraPivot.global_position = Math.exp_decay_vec3(%CameraPivot.global_position, %BoundingCapsule.global_position, cam_pos_smooth, delta)
	
	# Set variables for camera reset operation.
	if (Input.is_action_just_pressed("resetCamera")):
		_reset_cam_timer = get_tree().create_timer(cam_reset_time)
		_cam_resetting = true
		_cam_reset_y = %CharacterModel.global_rotation.y
		
	# Move the camera to where the player is facing, at a neutral height.
	if (_cam_resetting):
		var angle_diff = angle_difference(%CameraPivot.global_rotation.y, _cam_reset_y);
		%CameraPivot.global_rotation.y = Math.exp_decay(%CameraPivot.global_rotation.y, %CameraPivot.global_rotation.y + angle_diff, cam_reset_smooth, delta)
		%CameraPivot.global_rotation.x = Math.exp_decay(%CameraPivot.global_rotation.x, 0, cam_reset_smooth, delta)
		

func _input(input: InputEvent) -> void:
	# Mouse look.
	if (input is InputEventMouseMotion && Input.mouse_mode == Input.MOUSE_MODE_CAPTURED && _reset_cam_timer.time_left <= 0):
		var motion = input as InputEventMouseMotion
		
		# Move the camera relative to mouse movement.
		%CameraPivot.rotation_degrees.x -= (motion.screen_relative.y / 90) * cam_sens_mouse
		%CameraPivot.rotation_degrees.y -= (motion.screen_relative.x / 90) * cam_sens_mouse
		
		# Stop the camera going too far up or down, otherwise we'll go upside down or under the ground!
		%CameraPivot.rotation_degrees.x = clamp(%CameraPivot.rotation_degrees.x, -CAM_MAX_X, CAM_MAX_X)
		
		# Once the timer runs out, this will make it so the camera stops trying to reset.
		_cam_resetting = false

# Basic setup.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Hides the mouse and keeps it in the middle of the game screen.
	_reset_cam_timer = get_tree().create_timer(0) # Initialises the camera timer, the timer immediately finishes so we can move the camera.

# This will run each physics frame, or 60 times a second.
func _physics_process(delta: float) -> void:
	get_move_dir()
	move_player(delta)
	rotate_player_model(delta)
	move_camera(delta)
	
	# This just lets us uncapture the mouse so that we are not trapped inside the game.
	if (Input.is_action_just_pressed("escape")):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
