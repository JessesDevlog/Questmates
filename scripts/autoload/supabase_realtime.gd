extends Node

## Supabase Realtime WebSocket client for household and dungeon channels.

signal channel_message(channel: String, payload: Dictionary)
signal realtime_connected
signal realtime_disconnected

var _peer: WebSocketPeer = WebSocketPeer.new()
var _channel: String = ""
var _ref_counter: int = 0
var _heartbeat_timer: float = 0.0
var _connected: bool = false


func connect_household_channel(household_id: String) -> void:
	_channel = "household:%s" % household_id
	_connect_realtime()


func connect_dungeon_channel(run_id: String) -> void:
	_channel = "dungeon:%s" % run_id
	_connect_realtime()


func disconnect_channel() -> void:
	if _connected:
		_peer.close()
	_connected = false
	_channel = ""


func send_broadcast(event_type: String, payload: Dictionary) -> void:
	if not _connected:
		return
	var message := {
		"topic": "realtime:public",
		"event": "broadcast",
		"payload": {
			"type": "broadcast",
			"event": event_type,
			"payload": payload,
		},
		"ref": str(_ref_counter),
	}
	_ref_counter += 1
	_peer.send_text(JSON.stringify(message))


func _connect_realtime() -> void:
	if not SupabaseClient.is_configured():
		return
	var ws_url := SecretsConfig.SUPABASE_URL.replace("https://", "wss://") + "/realtime/v1/websocket"
	var params := "apikey=%s&vsn=1.0.0" % SecretsConfig.get_api_key()
	if not GameState.access_token.is_empty():
		params += "&access_token=%s" % GameState.access_token
	_peer.connect_to_url("%s?%s" % [ws_url, params])


func _process(delta: float) -> void:
	_peer.poll()
	var state := _peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_connected = true
			realtime_connected.emit()
		while _peer.get_available_packet_count() > 0:
			var packet := _peer.get_packet()
			var text := packet.get_string_from_utf8()
			var parsed: Variant = JSON.parse_string(text)
			if typeof(parsed) == TYPE_DICTIONARY:
				_handle_message(parsed)
		_heartbeat_timer += delta
		if _heartbeat_timer >= 25.0:
			_heartbeat_timer = 0.0
			_peer.send_text(JSON.stringify({"topic": "phoenix", "event": "heartbeat", "payload": {}, "ref": str(_ref_counter)}))
			_ref_counter += 1
	elif state == WebSocketPeer.STATE_CLOSED and _connected:
		_connected = false
		realtime_disconnected.emit()


func _handle_message(message: Dictionary) -> void:
	var event: String = String(message.get("event", ""))
	if event == "broadcast":
		var payload_variant: Variant = message.get("payload", {})
		var payload: Dictionary = payload_variant if payload_variant is Dictionary else {}
		channel_message.emit(_channel, payload)
	elif event == "postgres_changes":
		var change_variant: Variant = message.get("payload", {})
		var payload: Dictionary = change_variant if change_variant is Dictionary else {}
		channel_message.emit(_channel, {"type": "db_change", "data": payload})
