## Virtual base class for all states.
## Extend this class and override its methods to implement a state.
class_name PlayerState extends State

const RUNNER = "StateRunner"
const GHOST = "StateGhost"
const SPECTATOR = "StateSpectator"

var player : Player

func _ready() -> void:
	await owner.ready
	player = owner as Player
	assert(player != null, "The PlayerState state type must be used only in the player scene. It needs the owner to be a Player node.")
