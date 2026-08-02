extends Control

@onready var email_input: LineEdit = %EmailInput
@onready var password_input: LineEdit = %PasswordInput
@onready var name_input: LineEdit = %NameInput
@onready var status_label: Label = %StatusLabel

var _pending: String = ""


func _ready() -> void:
	%SignInButton.pressed.connect(_on_sign_in)
	%SignUpButton.pressed.connect(_on_sign_up)
	SupabaseClient.request_completed.connect(_on_request_completed)
	SupabaseClient.request_failed.connect(_on_auth_failed)
	SpiritSystem.apply_penalty_on_open()

	if GameState.access_token and not GameState.profile_id.is_empty():
		_enter_hub()
	elif GameState.access_token:
		_pending = "profile"
		SupabaseClient.select("profiles", "*", "&auth_user_id=eq.%s" % GameState.user_id)


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
		name_input.text.strip_edges()
	)


func _on_request_completed(result: Dictionary) -> void:
	match _pending:
		"auth":
			if not GameState.access_token.is_empty():
				_pending = "profile"
				SupabaseClient.select("profiles", "*", "&auth_user_id=eq.%s" % GameState.user_id)
		"profile":
			var data: Variant = result.get("data", [])
			if typeof(data) == TYPE_ARRAY and not data.is_empty():
				GameState.set_profile_data(data[0])
				_pending = "household"
				SupabaseClient.select("households", "*", "&id=eq.%s" % GameState.household_id)
			else:
				status_label.text = "Profile missing. Run Supabase onboarding SQL or sign up again."
		"household":
			var data: Variant = result.get("data", [])
			if typeof(data) == TYPE_ARRAY and not data.is_empty():
				GameState.set_household_data(data[0])
			_pending = "partner"
			var filters := "&household_id=eq.%s&neq.id,%s" % [GameState.household_id, GameState.profile_id]
			SupabaseClient.select("profiles", "*", filters)
		"partner":
			var data: Variant = result.get("data", [])
			if typeof(data) == TYPE_ARRAY and not data.is_empty():
				GameState.set_partner_profile(data[0])
			_pending = "children"
			SupabaseClient.select("child_profiles", "*", "&household_id=eq.%s" % GameState.household_id)
		"children":
			var data: Variant = result.get("data", [])
			if typeof(data) == TYPE_ARRAY:
				GameState.set_child_profiles(data)
			ContentService.fetch_remote_content()
			SupabaseRealtime.connect_household_channel(GameState.household_id)
			_enter_hub()
	_pending = ""


func _on_auth_failed(error: String) -> void:
	status_label.text = error
	_pending = ""


func _enter_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/hub_screen.tscn")
