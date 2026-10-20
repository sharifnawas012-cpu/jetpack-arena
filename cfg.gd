extends Node
## Global config: constants, weapons (config/weapons.json), maps, saved preferences.

const VERSION := "1.0"
const PORT := 47770
const DISC_PORT := 47771
const MAX_FIGHTERS := 12
const TEAM_COLORS := [Color("e8504a"), Color("4a90e8"), Color("4ae08a"), Color("e8c84a")]
const TEAM_NAMES := ["Red", "Blue", "Green", "Gold"]
const FFA_COLORS := [Color("e8504a"), Color("4a90e8"), Color("4ae08a"), Color("e8c84a"), Color("c070f0"), Color("40d8d8"),
	Color("f08a3a"), Color("f070b0"), Color("a0d040"), Color("8090a8"), Color("d8d8d8"), Color("a06040")]
const KIND_BULLET := 0
const KIND_ROCKET := 1
const KIND_GRENADE := 2
const KIND_FLAME := 3

var weapons: Array = []
var maps: Array = []
var prefs: Dictionary = {"name": "Player", "volume": 0.8, "ui_scale": 1.0, "touch": 0, "fps": 60,
	"last_ip": "", "touch_opacity": 0.75, "zoom_w": 1600.0}

func _ready() -> void:
	_load_weapons()
	_build_maps()
	load_prefs()
	Engine.max_fps = int(prefs.fps)

func default_settings() -> Dictionary:
	return {"mode": "ffa", "map": 0, "duration": 300, "kill_limit": 20, "respawn": 3.0, "health": 100,
		"dmg_mult": 1.0, "max_players": 12, "bots": 4, "bot_diff": 1, "teams": 2, "friendly_fire": false,
		"unl_ammo": true, "no_reload": true, "unl_nades": true, "unl_jet": true, "gas_damage": true,
		"gas_immune": false, "self_damage": true, "throw_power": 1.0, "code": ""}

func load_prefs() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://prefs.cfg") == OK:
		for k in prefs.keys():
			prefs[k] = cf.get_value("prefs", k, prefs[k])

func save_prefs() -> void:
	var cf := ConfigFile.new()
	for k in prefs.keys():
		cf.set_value("prefs", k, prefs[k])
	cf.save("user://prefs.cfg")
	Engine.max_fps = int(prefs.fps)

func _load_weapons() -> void:
	var f := FileAccess.open("res://config/weapons.json", FileAccess.READ)
	if f == null:
		push_error("weapons.json missing")
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_ARRAY:
		push_error("weapons.json invalid")
		return
	for w in data:
		var d: Dictionary = w
		match String(d.kind):
			"rocket": d["k"] = KIND_ROCKET
			"grenade": d["k"] = KIND_GRENADE
			"flame": d["k"] = KIND_FLAME
			_: d["k"] = KIND_BULLET
		d["color"] = Color(String(d.col))
		weapons.append(d)

# ---------------------------------------------------------------- maps
func _mk(nm: String, cols: Array, grav: float, decor: int, full: Array, half: Array, sp: Array, cr: Array, gas: Array = []) -> void:
	var w := 2400.0
	var h := 1200.0
	var walls: Array = [Rect2(-120, -120, w + 240, 120), Rect2(-120, h, w + 240, 120),
		Rect2(-120, -120, 120, h + 240), Rect2(w, -120, 120, h + 240)]
	var plats: Array = []
	for r in full:
		plats.append(Rect2(r[0], r[1], r[2], r[3]))
	for r in half:
		plats.append(Rect2(r[0], r[1], r[2], r[3]))
		plats.append(Rect2(w - r[0] - r[2], r[1], r[2], r[3]))
	var spawns: Array = []
	for p in sp:
		spawns.append(Vector2(p[0], p[1]))
		spawns.append(Vector2(w - p[0], p[1]))
	var crates: Array = []
	for p in cr:
		crates.append(Vector2(p[0], p[1]))
		crates.append(Vector2(w - p[0], p[1]))
	var gz: Array = []
	for g in gas:
		gz.append(Rect2(g[0], g[1], g[2], g[3]))
	maps.append({"name": nm, "w": w, "h": h, "cols": cols, "grav": grav, "decor": decor, "plats": plats,
		"solids": walls + plats, "spawns": spawns, "crates": crates, "gas": gz})

func _build_maps() -> void:
	var floor_r := [0, 1120, 2400, 80]
	_mk("Military Training Base", [Color("5b7fa6"), Color("c9d9e6"), Color("4a5560"), Color("8aa0b4")], 1.0, 0,
		[floor_r, [1000, 860, 400, 28]],
		[[120, 900, 320, 28], [520, 690, 320, 28], [160, 470, 300, 28], [760, 1020, 70, 100], [880, 520, 240, 28]],
		[[260, 860], [680, 650], [300, 430], [150, 1080], [980, 480]],
		[[300, 884], [700, 674], [1000, 504]])
	_mk("Desert Battlefield", [Color("e8b26a"), Color("f6dca0"), Color("b9803f"), Color("e6b46a")], 1.0, 1,
		[floor_r, [900, 720, 600, 28]],
		[[0, 1000, 300, 120], [300, 900, 260, 220], [560, 800, 240, 320], [160, 640, 260, 28], [620, 540, 260, 28], [330, 380, 240, 28]],
		[[150, 960], [420, 860], [680, 760], [290, 600], [720, 500]],
		[[200, 984], [690, 784], [750, 524]])
	_mk("Jungle Outpost", [Color("1f4d2c"), Color("5aa05a"), Color("5c3d22"), Color("6fb35f")], 1.0, 2,
		[floor_r, [1000, 760, 400, 26]],
		[[100, 950, 260, 26], [450, 820, 240, 26], [130, 660, 260, 26], [500, 560, 240, 26], [240, 400, 300, 26], [800, 950, 200, 26]],
		[[230, 910], [570, 780], [250, 620], [620, 520], [380, 360]],
		[[230, 934], [570, 804], [380, 384]],
		[[850, 1000, 700, 120]])
	_mk("Industrial Factory", [Color("3a3f47"), Color("6b625a"), Color("2b2f35"), Color("e0a030")], 1.0, 3,
		[floor_r, [700, 900, 1000, 26], [700, 640, 1000, 26]],
		[[0, 780, 500, 26], [0, 480, 500, 26], [520, 560, 30, 240], [550, 300, 300, 26], [600, 1000, 90, 120]],
		[[200, 740], [250, 440], [800, 860], [780, 600], [700, 260]],
		[[100, 764], [220, 464], [1000, 884]],
		[[900, 1060, 600, 60]])
	_mk("Underground Bunker", [Color("14181c"), Color("2b343a"), Color("3b454d"), Color("7b8a94")], 1.0, 4,
		[floor_r, [0, 0, 2400, 130]],
		[[0, 620, 900, 30], [300, 880, 30, 240], [550, 130, 40, 260], [200, 380, 300, 26]],
		[[150, 1080], [450, 576], [200, 336], [700, 1080]],
		[[100, 1104], [500, 604], [350, 364]])
	_mk("Futuristic Space Station", [Color("05061a"), Color("20144a"), Color("2a3458"), Color("5fd0ff")], 0.55, 5,
		[floor_r, [1000, 640, 400, 26], [1050, 900, 300, 26]],
		[[100, 1000, 300, 26], [400, 800, 260, 26], [120, 600, 300, 26], [500, 430, 260, 26], [800, 260, 300, 26], [750, 1000, 26, 120]],
		[[250, 960], [530, 760], [270, 560], [630, 390], [950, 220]],
		[[250, 984], [530, 784], [950, 244]])
	_mk("Snow Base", [Color("9fc4e8"), Color("e8f2fa"), Color("6b7f94"), Color("dfefff")], 1.0, 6,
		[floor_r, [900, 800, 600, 28], [1000, 520, 400, 26]],
		[[100, 950, 300, 28], [450, 820, 260, 28], [80, 640, 280, 28], [420, 500, 300, 28], [150, 340, 300, 28], [760, 1000, 60, 120]],
		[[250, 910], [580, 780], [220, 600], [560, 460], [300, 300]],
		[[230, 934], [580, 804], [300, 324]])
	_mk("Island Battlefield", [Color("2a8fd0"), Color("bfe8f5"), Color("c9a96a"), Color("f2e2b0")], 0.9, 7,
		[floor_r, [950, 900, 500, 28], [1000, 650, 400, 26]],
		[[60, 1000, 360, 120], [500, 880, 240, 240], [150, 760, 260, 26], [560, 640, 260, 26], [120, 480, 300, 26], [540, 380, 260, 26]],
		[[200, 960], [620, 840], [280, 720], [690, 600], [260, 440]],
		[[200, 984], [620, 864], [260, 464]])
