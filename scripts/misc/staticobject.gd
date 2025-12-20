extends Node2D

@onready var depth_marker: Marker2D = $DepthMarker

func _process(_delta):
	z_index = int(depth_marker.global_position.y)
