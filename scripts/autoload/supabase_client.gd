extends Node

## HTTP-based Supabase client for Auth and REST.
## Uses a single-flight queue so concurrent service calls do not ERR_BUSY.

signal request_completed(result: Dictionary)
signal request_failed(error: String)

var _http: HTTPRequest
var _queue: Array = []
var _busy: bool = false


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)


func is_configured() -> bool:
	var key := SecretsConfig.get_api_key()
	return SecretsConfig.SUPABASE_URL.find("YOUR_PROJECT") == -1 \
		and not key.is_empty() \
		and key != "sb_publishable_YOUR_KEY_HERE" \
		and key != "YOUR_PUBLISHABLE_KEY"


func sign_up(email: String, password: String, display_name: String) -> void:
	var body := JSON.stringify({
		"email": email,
		"password": password,
		"data": {"display_name": display_name},
	})
	_enqueue("POST", "/auth/v1/signup", body, false)


func sign_in(email: String, password: String) -> void:
	var body := JSON.stringify({"email": email, "password": password})
	_enqueue("POST", "/auth/v1/token?grant_type=password", body, false)


func refresh_session() -> void:
	if GameState.refresh_token.is_empty():
		return
	var body := JSON.stringify({"refresh_token": GameState.refresh_token})
	_enqueue("POST", "/auth/v1/token?grant_type=refresh_token", body, false)


func select(table: String, query: String = "*", filters: String = "") -> void:
	var path := "/rest/v1/%s?select=%s%s" % [table, query, filters]
	_enqueue("GET", path, "", true)


func insert(table: String, payload: Dictionary) -> void:
	var path := "/rest/v1/%s" % table
	_enqueue("POST", path, JSON.stringify(payload), true, {"Prefer": "return=representation"})


func update(table: String, filters: String, payload: Dictionary) -> void:
	var path := "/rest/v1/%s?%s" % [table, filters]
	_enqueue("PATCH", path, JSON.stringify(payload), true, {"Prefer": "return=representation"})


func call_rpc(function_name: String, payload: Dictionary = {}) -> void:
	var path := "/rest/v1/rpc/%s" % function_name
	_enqueue("POST", path, JSON.stringify(payload), true)


func _enqueue(
	method: String,
	path: String,
	body: String,
	use_auth: bool,
	extra_headers: Dictionary = {}
) -> void:
	if not is_configured():
		request_failed.emit("Supabase not configured. Copy secrets.gd.example to secrets.gd.")
		return
	_queue.append({
		"method": method,
		"path": path,
		"body": body,
		"use_auth": use_auth,
		"extra_headers": extra_headers,
	})
	if not _busy:
		_send_next()


func _send_next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var entry: Dictionary = _queue.pop_front()
	_send_request(entry)


func _send_request(entry: Dictionary) -> void:
	var method: String = entry.get("method", "GET")
	var path: String = entry.get("path", "")
	var body: String = entry.get("body", "")
	var use_auth: bool = entry.get("use_auth", false)
	var extra_headers: Dictionary = entry.get("extra_headers", {})

	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"apikey: %s" % SecretsConfig.get_api_key(),
	]
	if use_auth and not GameState.access_token.is_empty():
		headers.append("Authorization: Bearer %s" % GameState.access_token)

	for key in extra_headers.keys():
		headers.append("%s: %s" % [key, extra_headers[key]])

	var url := "%s%s" % [SecretsConfig.SUPABASE_URL, path]
	var http_method := HTTPClient.METHOD_GET
	match method:
		"POST":
			http_method = HTTPClient.METHOD_POST
		"PATCH":
			http_method = HTTPClient.METHOD_PATCH
		"DELETE":
			http_method = HTTPClient.METHOD_DELETE

	var err := _http.request(url, headers, http_method, body)
	if err != OK:
		request_failed.emit("HTTP request failed to start: %s" % err)
		_send_next()


func _on_http_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		GameState.set_online(false)
		request_failed.emit("Network error: %s" % result)
		_send_next()
		return

	GameState.set_online(true)
	var text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)

	if response_code >= 400:
		var message := text
		if typeof(parsed) == TYPE_DICTIONARY:
			message = String(parsed.get("message", parsed.get("error_description", text)))
		request_failed.emit("HTTP %d: %s" % [response_code, message])
		_send_next()
		return

	if typeof(parsed) == TYPE_DICTIONARY:
		_apply_auth_session(parsed)

	request_completed.emit({
		"code": response_code,
		"data": parsed,
		"raw": text,
	})
	_send_next()


func _apply_auth_session(parsed: Dictionary) -> void:
	var token := String(parsed.get("access_token", ""))
	if token.is_empty():
		return
	var refresh := String(parsed.get("refresh_token", ""))
	var user_id := ""
	var user_variant: Variant = parsed.get("user", {})
	if typeof(user_variant) == TYPE_DICTIONARY:
		user_id = String(user_variant.get("id", ""))
	if user_id.is_empty():
		user_id = String(parsed.get("id", ""))
	GameState.set_session(token, refresh, user_id)
