extends Node

@onready var state: GameState = $GameState
@onready var sound: SoundManager = $SoundManager
@onready var world: SalonWorld = $SalonWorld
@onready var ui: MainUI = $CanvasLayer/MainUI
@onready var minigame: GroomingMinigame = $CanvasLayer/GroomingMinigame

func _ready() -> void:
	world.setup(state, sound)
	minigame.setup(state, sound)
	ui.setup(state, sound, world, minigame)
