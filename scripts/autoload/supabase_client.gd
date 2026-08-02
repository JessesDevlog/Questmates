extends Node

## HTTP-based Supabase client for Auth and REST.

signal request_completed(result: Dictionary)
signal request_failed(error: String)

var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func is_configured() -> bool:
	return SecretsConfig.SUPABASE_URL.find("YOUR_PROJECT") == -1


func sign_up(email: String, password: String, display_name: String) -> void:
	var body := JSON.stringify({
		"email": email,
		"password": password,
		"data": {"display_name": display_name},
	})
	_request("POST", "/auth/v1/signup", body, false)


func sign_in(email: String, password: String) -> void:
	var body := JSON.stringify({"email": email, "password": password})
	_request("POST", "/auth/v1/token?grant_type=password", body, false)


func refresh_session() -> void:
	if GameState.refresh_token.is_empty():
		return
	var body := JSON.stringify({"refresh_token": GameState.refresh_token})
	_request("POST", "/auth/v1/token?grant_type=refresh_token", body, false)


func select(table: String, query: String = "*", filters: String = "") -> void:
	var path := "/rest/v1/%s?select=%s%s" % [table, query, filters]
	_request("GET", path, "", true)


func insert(table: String, payload: Dictionary) -> void:
	var path := "/rest/v1/%s" % table
	_request("POST", path, JSON.stringify(payload), true, {"Prefer": "return=representation"})


func update(table: String, filters: String, payload: Dictionary) -> void:
	var path := "/rest/v1/%s?%s" % [table, filters]
	_request("PATCH", path, JSON.stringify(payload), true, {"Prefer": "return=representation"})


func call_rpc(function_name: String, payload: Dictionary = {}) -> void:
	var path := "/rest/v1/rpc/%s" % function_name
	_request("POST", path, JSON.stringify(payload), true)


func _request(
	method: String,
	path: String,
	body: String,
	use_auth: bool,
	extra_headers: Dictionary = {}
) -> void:
	if not is_configured():
		request_failed.emit("Supabase not configured. Copy secrets.gd.example to secrets.gd.")
		return

	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"apikey: %s" % SecretsConfig.SUPABASE_ANON_KEY,
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


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		GameState.set_online(false)
		request_failed.emit("Network error: %s" % result)
		return

	GameState.set_online(true)
	var text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)

	if response_code >= 400:
		var message := text
		if typeof(parsed) == TYPE_DICTIONARY:
			message = parsed.get("message", parsed.get("error_description", text))
		request_failed.emit("HTTP %d: %s" % [response_code, message])
		return

	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("access_token"):
		GameState.set_session(
			parsed.get("access_token", ""),
			parsed.get("refresh_token", ""),
			parsed.get("user", {}).get("id", "")
		)

	request_completed.emit({
		"code": response_code,
		"data": parsed,
		"raw": text,
	})
