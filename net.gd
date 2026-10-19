extends Node
## Networking: ENet host/client (host-authoritative), UDP LAN discovery, lobby, match start.
## Solo play uses the same game code with no peers (host = local machine).

signal lobby_changed
signal host_lost(reason: String)
signal join_failed(reason: String)
signal joined
signal player_left(id: int)

var online := false
var is_host := false
var in_match := false
var players: Dictionary = {}      # peer id -> {name, team}
var settings: Dictionary = {}
var match_settings: Dictionary = {}
var roster: Array = []            # [{id,name,team,bot}]
var game: Node = null
var menu_start := "main"
var last_msg := ""
var join_code := ""
var found: Dictionary = {}        # ip -> announce info

var _peer: ENetMultiplayerPeer
var _bc: PacketPeerUDP
var _ls: PacketPeerUDP
var _bc_t := 0.0

func _ready() -> void:
	settings = Cfg.default_settings()
	multiplayer.peer_disconnected.connect(_on_peer_disc)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_conn_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)

func team_count() -> int:
	match String(settings.mode):
		"team": return 2
		"custom": return clampi(int(settings.teams), 2, 4)
	return 1

func local_ips() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		var s := String(a)
		if s.count(".") == 3 and not s.begins_with("127.") and not s.begins_with("169.254."):
			out.append(s)
	return out

# ------------------------------------------------------------- hosting / joining
func host_game() -> int:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(Cfg.PORT, Cfg.MAX_FIGHTERS - 1)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	online = true
	is_host = true
	players = {1: {"name": String(Cfg.prefs.name), "team": 0}}
	_bc = PacketPeerUDP.new()
	_bc.set_broadcast_enabled(true)
	return OK

func join_game(ip: String) -> int:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(ip, Cfg.PORT)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	online = true
	is_host = false
	return OK

func leave() -> void:
	online = false
	is_host = false
	in_match = false
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {}
	_bc = null

func start_solo() -> void:
	leave()
	players = {1: {"name": String(Cfg.prefs.name), "team": 0}}
	is_host = true
	start_match_host()

func _on_connected() -> void:
	rpc_id(1, "srv_hello", String(Cfg.prefs.name), join_code, Cfg.VERSION)

func _on_conn_failed() -> void:
	leave()
	join_failed.emit("Could not connect. Check the IP address, Wi-Fi and hotspot settings.")

func _on_server_gone() -> void:
	if not online or is_host:
		return
	leave()
	last_msg = "The host disconnected."
	host_lost.emit(last_msg)

func _on_peer_disc(id: int) -> void:
	if not is_host:
		return
	if players.has(id):
		players.erase(id)
	player_left.emit(id)
	push_lobby()

func _unique_name(nm: String) -> String:
	var base := nm.strip_edges().left(14)
	if base == "":
		base = "Player"
	var n := base
	var k := 2
	var taken := true
	while taken:
		taken = false
		for p in players.values():
			if p.name == n:
				taken = true
		if taken:
			n = "%s%d" % [base, k]
			k += 1
	return n

func _smallest_team() -> int:
	var tc := team_count()
	var counts: Array = []
	for i in tc:
		counts.append(0)
	for p in players.values():
		if int(p.team) < tc:
			counts[int(p.team)] += 1
	var best := 0
	for i in tc:
		if counts[i] < counts[best]:
			best = i
	return best

func push_lobby() -> void:
	var tc := team_count()
	for p in players.values():
		if int(p.team) >= tc:
			p.team = int(p.team) % tc
	if online and is_host:
		rpc("cli_lobby", players, settings)
	lobby_changed.emit()

func set_team(id: int, t: int) -> void:
	if is_host and players.has(id):
		players[id].team = t % maxi(1, team_count())
		push_lobby()

# ------------------------------------------------------------- RPCs: lobby
@rpc("any_peer", "call_remote", "reliable")
func srv_hello(pname: String, code: String, ver: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	var reason := ""
	if ver != Cfg.VERSION:
		reason = "Version mismatch (host %s, you %s)" % [Cfg.VERSION, ver]
	elif in_match:
		reason = "A match is already in progress"
	elif players.size() >= int(settings.max_players):
		reason = "The room is full"
	elif String(settings.code) != "" and String(settings.code) != code:
		reason = "Wrong room code"
	if reason != "":
		rpc_id(id, "cli_reject", reason)
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if _peer != null:
				_peer.disconnect_peer(id))
		return
	players[id] = {"name": _unique_name(pname), "team": _smallest_team()}
	rpc_id(id, "cli_accept")
	push_lobby()

@rpc("authority", "call_remote", "reliable")
func cli_reject(reason: String) -> void:
	leave()
	join_failed.emit(reason)

@rpc("authority", "call_remote", "reliable")
func cli_accept() -> void:
	joined.emit()

@rpc("authority", "call_remote", "reliable")
func cli_lobby(p: Dictionary, s: Dictionary) -> void:
	players = p
	settings = s
	lobby_changed.emit()

@rpc("any_peer", "call_remote", "reliable")
func srv_team(t: int) -> void:
	if is_host:
		set_team(multiplayer.get_remote_sender_id(), t)

# ------------------------------------------------------------- match start / end
func start_match_host() -> void:
	var team_mode := String(settings.mode) != "ffa"
	var tc := team_count()
	roster = []
	var counts: Array = [0, 0, 0, 0]
	for id in players.keys():
		var t: int = int(players[id].team) % tc if team_mode else roster.size()
		if team_mode:
			counts[t] += 1
		roster.append({"id": id, "name": players[id].name, "team": t, "bot": false})
	var nbots := mini(int(settings.bots), Cfg.MAX_FIGHTERS - roster.size())
	for i in maxi(0, nbots):
		var t := roster.size()
		if team_mode:
			t = 0
			for k in tc:
				if counts[k] < counts[t]:
					t = k
			counts[t] += 1
		roster.append({"id": -(i + 1), "name": "Bot %d" % (i + 1), "team": t, "bot": true})
	match_settings = settings.duplicate(true)
	in_match = true
	if online:
		rpc("cli_start", roster, match_settings)
	_enter_game()

@rpc("authority", "call_remote", "reliable")
func cli_start(r: Array, s: Dictionary) -> void:
	roster = r
	match_settings = s
	in_match = true
	_enter_game()

func _enter_game() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")

func back_to_lobby_or_menu() -> void:
	in_match = false
	if online:
		menu_start = "lobby"
		if is_host:
			push_lobby()
	else:
		menu_start = "main"
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")

func quit_to_menu(msg: String = "") -> void:
	leave()
	menu_start = "main"
	last_msg = msg
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")

# ------------------------------------------------------------- RPCs: gameplay
@rpc("any_peer", "call_remote", "unreliable_ordered")
func srv_input(mx: float, my: float, jet: bool, fire: bool, aim: float) -> void:
	if is_host and game != null:
		game.on_input(multiplayer.get_remote_sender_id(), mx, my, jet, fire, aim)

@rpc("any_peer", "call_remote", "reliable")
func srv_act(kind: int) -> void:
	if is_host and game != null:
		game.on_act(multiplayer.get_remote_sender_id(), kind)

@rpc("authority", "call_remote", "unreliable_ordered")
func cli_snap(fs: PackedFloat64Array, bs: PackedFloat32Array, cs: PackedInt32Array) -> void:
	if game != null:
		game.apply_snapshot(fs, bs, cs)

@rpc("authority", "call_remote", "reliable")
func cli_boom(x: float, y: float, r: float) -> void:
	if game != null:
		game.fx.boom(Vector2(x, y), r)
		Sfx.play("boom", Vector2(x, y))

@rpc("authority", "call_remote", "unreliable")
func cli_hit(x: float, y: float) -> void:
	if game != null:
		game.fx.spark(Vector2(x, y), Color(1, 0.9, 0.5), 4)

@rpc("authority", "call_remote", "reliable")
func cli_kill(killer: int, victim: int, wi: int) -> void:
	if game != null:
		game.show_kill(killer, victim, wi)

@rpc("authority", "call_remote", "unreliable_ordered")
func cli_state(tl: float, kd: PackedInt32Array, ts: PackedInt32Array) -> void:
	if game != null:
		game.apply_state(tl, kd, ts)

@rpc("authority", "call_remote", "reliable")
func cli_end(results: Array, winner: String) -> void:
	if game != null:
		game.show_results(results, winner)

@rpc("authority", "call_remote", "reliable")
func cli_left(id: int) -> void:
	if game != null:
		game.remove_fighter(id)

@rpc("authority", "call_remote", "reliable")
func cli_pickup(x: float, y: float) -> void:
	Sfx.play("pick", Vector2(x, y))

# ------------------------------------------------------------- LAN discovery
func start_listen() -> void:
	if _ls != null:
		return
	_ls = PacketPeerUDP.new()
	if _ls.bind(Cfg.DISC_PORT) != OK:
		_ls = null

func stop_listen() -> void:
	if _ls != null:
		_ls.close()
	_ls = null
	found.clear()

func _announce() -> void:
	var info := {"g": "jetarena", "name": String(players.get(1, {}).get("name", "Host")), "n": players.size(),
		"max": int(settings.max_players), "mode": String(settings.mode),
		"map": String(Cfg.maps[int(settings.map)].name), "lock": String(settings.code) != "", "ver": Cfg.VERSION}
	var pkt := JSON.stringify(info).to_utf8_buffer()
	var dests: Array = ["255.255.255.255"]
	for ip in local_ips():
		var parts := String(ip).split(".")
		dests.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	for d in dests:
		_bc.set_dest_address(d, Cfg.DISC_PORT)
		_bc.put_packet(pkt)

func _process(dt: float) -> void:
	if _bc != null and online and is_host and not in_match:
		_bc_t -= dt
		if _bc_t <= 0.0:
			_bc_t = 1.0
			_announce()
	if _ls != null:
		while _ls.get_available_packet_count() > 0:
			var txt := _ls.get_packet().get_string_from_utf8()
			var ip := _ls.get_packet_ip()
			var j = JSON.parse_string(txt)
			if typeof(j) == TYPE_DICTIONARY and j.get("g", "") == "jetarena":
				j["t"] = Time.get_ticks_msec()
				found[ip] = j
		var now := Time.get_ticks_msec()
		for ip in found.keys():
			if now - int(found[ip].t) > 4000:
				found.erase(ip)
