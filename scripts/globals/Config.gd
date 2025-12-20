extends Node

# prod/local enviro toggle
const USE_PRODUCTION: bool = false


# Server cfg
const WS_URL_PRODUCTION: String = "wss://deaddreamers.com/ws"
const WS_URL_LOCAL: String = "ws://127.0.0.1:9090"
const HTTP_URL_PRODUCTION: String = "https://deaddreamers.com"
const HTTP_URL_LOCAL: String = "http://127.0.0.1:5000"

func get_ws_url() -> String:
	return WS_URL_PRODUCTION if USE_PRODUCTION else WS_URL_LOCAL

func get_http_url() -> String:
	return HTTP_URL_PRODUCTION if USE_PRODUCTION else HTTP_URL_LOCAL


# network
const CONNECTION_TIMEOUT: float = 10.0
const MAX_RECONNECT_ATTEMPTS: int = 3
const RECONNECT_DELAY: float = 2.0
const UPDATE_INTERVAL: float = 0.05  # How often to send player updates in seconds
const MAX_MESSAGE_SIZE: int = 3000  # Max bytes for a chat message
const MAX_MESSAGE_LENGTH: int = 255  # Max characters for chat input


# Player Movement
const PLAYER_BASE_SPEED: float = 150.0
const PLAYER_ARRIVAL_THRESHOLD: float = 5.0


# Player visual const
const KNEEL_Y_OFFSET: float = 25.0

const FRAME_TORSO_FRONT: int = 0
const FRAME_TORSO_BACK: int = 1
const FRAME_KNEEL_FRONT: int = 2
const FRAME_KNEEL_BACK: int = 3
const FRAME_STAND_FRONT: int = 4
const FRAME_STAND_BACK: int = 5
const FRAME_WALK_LEG_1: int = 6
const FRAME_WALK_LEG_2: int = 7
const FRAME_WALK_LEG_3: int = 8
const FRAME_WALK_LEG_4: int = 9
const LEG_FRAME_TIME: float = 0.12


# Player interaction
const CARRY_OFFSET: Vector2 = Vector2(0, -40)  # Where carried player appears relative to carrier
const THROW_DURATION: float = 0.6  # How long throw animation takes
const THROW_PEAK_HEIGHT: float = 80.0  # Arc height for throw animation


# Remote player sync
const INTERPOLATION_SPEED: float = 15.0  # How smoothly remote players lerp to target position
const POSITION_THRESHOLD: float = 5.0  # Snap to position if within this distance
const TELEPORT_THRESHOLD: float = 200.0  # Instant teleport if further than this


# Player prefs / user settings
const DEFAULT_SPEED_MULTIPLIER: float = 1.0
const MIN_SPEED_MULTIPLIER: float = 0.5
const MAX_SPEED_MULTIPLIER: float = 2.0
const DEFAULT_HUE_SHIFT: float = 0.0


# Map cfg
const MAP_SCALE: float = 1.0
const EDGE_CLEARANCE: float = 60.0  # Spawn distance from edge on map transition
const DEFAULT_MAP_WIDTH: float = 1536.0
const DEFAULT_MAP_HEIGHT: float = 1536.0


# Chat system
const MAX_CHAT_LOG_MESSAGES: int = 100  # Max messages in chat log before trimming

# Chat bubble configuration
const MAX_CHAT_BUBBLE_MESSAGES: int = 3
const BUBBLE_OFFSET: Vector2 = Vector2(10, -80)
const BUBBLE_WIDTH: int = 135
const MESSAGE_PADDING: int = 2
const USERNAME_PADDING: int = 4
const CORNER_RADIUS: int = 6
const MESSAGE_SPACING: int = 2
const USERNAME_FONT_SIZE: int = 10
const MESSAGE_FONT_SIZE: int = 13
const LINE_HEIGHT_MULTIPLIER: float = 1.2

# Chat bubble colors
const MESSAGE_BG_COLOR: Color = Color(1, 1, 1, 1)  # White
const MESSAGE_BORDER_COLOR: Color = Color(0.545, 0.451, 0.333, 1)  # Brown
const MESSAGE_TEXT_COLOR: Color = Color(0.176, 0.141, 0.086, 1)  # Dark brown
const USERNAME_BG_COLOR: Color = Color(0.961, 0.902, 0.827, 1)  # Light beige
const DIVIDER_COLOR: Color = Color(0.7, 0.6, 0.5, 1)  # Medium brown


# Avatar cfg
const FALLBACK_AVATAR: String = "res://assets/fallback_avatar.png"
const FALLBACK_AVATAR_FOLDER: String = "res://assets/fallbackAvatar/"
const ALLOWED_AVATAR_DOMAINS: Array[String] = [
	"a1cdn.gaiaonline.com"
]


# UI cfg
const MAX_USERNAME_LENGTH: int = 32

# Camera cfg
const CAMERA_ZOOM: Vector2 = Vector2(1.4, 1.4)
const CAMERA_SMOOTHING_SPEED: float = 10.0


# Helper funcs
# Get chat bubble lifetime based on message length
func get_bubble_lifetime(text: String) -> float:
	var char_count = text.length()
	if char_count <= 20:
		return 4.0
	elif char_count <= 40:
		return 6.0
	elif char_count <= 80:
		return 8.0
	else:
		return 10.0

# Convert avatar URL to strip format
func to_strip_url(url: String) -> String:
	if url.is_empty() or url.begins_with("res://"):
		return url
	
	var base_url: String = url.split("?")[0]
	
	if base_url.ends_with("_flip.png"):
		base_url = base_url.replace("_flip.png", "_strip.png")
	elif base_url.ends_with(".png") and not base_url.ends_with("_strip.png"):
		base_url = base_url.replace(".png", "_strip.png")
	
	return base_url

# Check if avatar URL is from allowed domain
func is_valid_avatar_url(url: String) -> bool:
	if url.is_empty():
		return false
	
	if url.begins_with("res://"):
		return true
	
	for domain in ALLOWED_AVATAR_DOMAINS:
		if domain in url:
			return true
	
	return false
