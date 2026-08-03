extends Control

@onready var email_input: LineEdit = %EmailInput
@onready var password_input: LineEdit = %PasswordInput
@onready var status_label: Label = %StatusLabel

var _pending: String = ""


func _ready() -> void:
	%SignInButton.pressed.connect(_on_sign_in)
	%SignUpButton.pressed.connect(_on_sign_up)
	SupabaseClient.request_completed.connect(_on_request_completed)
	SupabaseClient.request_failed.connect(_on_auth_failed)

	if GameState.access_token and not GameState.user_id.is_empty():
		_begin_profile_load()
	elif GameState.access_token:
		status_label.text = "Session invalid. Sign in again."


func _on_sign_in() -> void:
	status_label.text = "Signing in..."
	_pending = "auth"
	SupabaseClient.sign_in(email_input.text.strip_edges(), password_input.text)


func _on_sign_up() -> void:
	status_label.text = "Creating account..."
	_pending = "auth"
	SupabaseClient.sign_up(
		email_input.text.strip_edges(),
		password_input.text,
		""
	)


func _begin_profile_load() -> void:
	if GameState.user_id.is_empty():
		status_label.text = "Auth succeeded but user id is missing."
		return
	_pending = "profile"
	SupabaseClient.select("profiles", "*", "&auth_user_id=eq.%s" % GameState.user_id)


func _on_request_completed(result: Dictionary) -> void:
	match _pending:
		"auth":
			if GameState.access_token.is_empty():
				status_label.text = "Sign up may require email confirmation. Disable it in Supabase Auth settings, or confirm your email."
				_pending = ""
				return
			_begin_profile_load()
			return
		"profile":
			var data: Variant = result.get("data", [])
			if typeof(data) == TYPE_ARRAY and not data.is_empty():
				var row_variant: Variant = data[0]
				if row_variant is Dictionary:
					GameState.set_profile_data(row_variant)
				if GameState.profile_id.is_empty():
					status_label.text = "Profile missing. Run migration 009 and sign up again."
					_pending = ""
					return
				_pending = ""
				_route_after_profile()
			else:
				status_label.text = "Profile missing. Run migration 009, then sign up again."
				_pending = ""
			return


func _route_after_profile() -> void:
	if GameState.is_onboarding_complete():
		status_label.text = "Loading..."
		HomesteadService.load_session_context(_enter_main_menu)
	else:
		_enter_onboarding()


func _on_auth_failed(error: String) -> void:
	if _pending.is_empty():
		return
	status_label.text = error
	_pending = ""


func _enter_onboarding() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/character_select.tscn")


func _enter_main_menu() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/main_menu.tscn")
