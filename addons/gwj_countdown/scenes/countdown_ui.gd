@tool
extends Control

const PROJECT_SETTINGS_PATH = "gwj_countdown/"
const TARGET_WEEKDAY : = 5
const TARGET_WEEKDAY_OCCURRENCE : int = 2
const TARGET_HOUR := 21
const JAM_DAYS = 9
const VOTING_DAYS = 7
const SECONDS_PER_DAY = 86400
const SECONDS_PER_HOUR = 3600
const SECONDS_PER_MINUTE = 60
const DAYS_IN_FOUR_WEEKS = 28

const DEFAULT_STAGE_STRING = "Jam Begins"
const VOTING_STAGE_STRING = "Voting Ends"
const JAM_STAGE_STRING = "Jam Ends"

const JAM_LINK_PREFIX = "https://itch.io/jam/godot-wild-jam-"
const JAM_FIRST_MONTH = 9
const JAM_FIRST_YEAR = 2018

@export_range(1, 3) var default_precision : int = 2

@export var jam_extension : int = 0
@export var voting_extension :  int = 0

@export_group("Debug")
@export var adjust_days : int = 0
@export var adjust_hours : int = 0
@export_tool_button("Refresh text") var refresh_text_action = refresh_text

@onready var stage_label = %StageLabel
@onready var stage_label_2 = %StageLabel2
@onready var countdown_button = %CountdownButton
@onready var countdown_label = %CountdownLabel
@onready var confirmation_dialog = $ConfirmationDialog
@onready var stage_option = %StageOption
@onready var day_adjustment = %DayAdjustment

var _prev_jam_extension : int
var _prev_voting_extension : int

func _get_2nd_friday(day : int, weekday : int) -> int:
	var weekday_diff := weekday - TARGET_WEEKDAY
	var target_relative_day := (day - weekday_diff)
	var target_first_day := target_relative_day % 7
	if target_first_day == 0:
		target_first_day = 7
	var target_day = target_first_day + (7 * (TARGET_WEEKDAY_OCCURRENCE - 1))
	return target_day

func get_jam_time() -> int:
	return (JAM_DAYS + jam_extension) * SECONDS_PER_DAY

func get_voting_time() -> int:
	return (VOTING_DAYS + voting_extension) * SECONDS_PER_DAY

func adjust_datetime_dict(datetime_dict : Dictionary) -> Dictionary:
	var _adjust_days := adjust_days
	if adjust_hours:
		datetime_dict["hour"] += adjust_hours
		if datetime_dict["hour"] >= 24:
			_adjust_days += 1
		datetime_dict["hour"] %= 24
	if adjust_days:
		datetime_dict["day"] += _adjust_days
		datetime_dict["weekday"] += _adjust_days
		datetime_dict["weekday"] += 1
		datetime_dict["weekday"] %= 7
		datetime_dict["weekday"] -= 1
	return datetime_dict

func _update_dict_to_months_jam(datetime_dict : Dictionary) -> Dictionary:
	var jam_start_day := _get_2nd_friday(datetime_dict["day"], datetime_dict["weekday"])
	datetime_dict["day"] = jam_start_day
	datetime_dict["weekday"] = TARGET_WEEKDAY
	datetime_dict["hour"] = TARGET_HOUR
	if datetime_dict["dst"]:
		datetime_dict["hour"] -= 1
	datetime_dict["minute"] = 0
	datetime_dict["second"] = 0
	return datetime_dict

func _get_delta_time_until_next_month_jam() -> int:
	var current_time_dict := Time.get_datetime_dict_from_system(true)
	current_time_dict = adjust_datetime_dict(current_time_dict)
	var current_time_unix := int(Time.get_unix_time_from_datetime_dict(current_time_dict))
	var next_month_unix = current_time_unix + (DAYS_IN_FOUR_WEEKS * SECONDS_PER_DAY)
	var next_month_dict := Time.get_datetime_dict_from_unix_time(next_month_unix)
	next_month_dict = _update_dict_to_months_jam(next_month_dict)
	var jam_time_unix := Time.get_unix_time_from_datetime_dict(next_month_dict)
	return jam_time_unix - current_time_unix

func _get_delta_time_until_jam() -> int:
	var current_time_dict := Time.get_datetime_dict_from_system(true)
	current_time_dict = adjust_datetime_dict(current_time_dict)
	var current_time_unix := Time.get_unix_time_from_datetime_dict(current_time_dict)
	var jam_time_dict = current_time_dict.duplicate()
	jam_time_dict = _update_dict_to_months_jam(jam_time_dict)
	var jam_time_unix := Time.get_unix_time_from_datetime_dict(jam_time_dict)
	return jam_time_unix - current_time_unix

func _get_countdown_array(delta_time) -> Array[int] :
	var countdown_array : Array[int]
	countdown_array.append(delta_time / SECONDS_PER_DAY)
	countdown_array.append((delta_time % SECONDS_PER_DAY ) / SECONDS_PER_HOUR)
	countdown_array.append((delta_time % SECONDS_PER_DAY % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)
	countdown_array.append(delta_time % SECONDS_PER_DAY % SECONDS_PER_HOUR % SECONDS_PER_MINUTE)
	return countdown_array

func _get_countdown_string(delta_time : int, precision : int = default_precision) -> String:
	var countdown_string : String = ""
	var countdown_array := _get_countdown_array(delta_time)
	var iter := -1
	var displayed_count := 0
	for countdown_value in countdown_array:
		iter += 1
		if countdown_value == 0: 
			continue
		countdown_string += "%d " % countdown_value
		match(iter):
			0:
				countdown_string += "Day"
			1:
				countdown_string += "Hour"
			2:
				countdown_string += "Minute"
			3:
				countdown_string += "Second"
		if countdown_value > 1:
			countdown_string += "s"
		countdown_string += " "
		displayed_count += 1
		if displayed_count >= precision:
			break
	return countdown_string

func _get_countdown_clock(delta_time : int) -> String:
	var countdown_clock : String = ""
	var countdown_array := _get_countdown_array(delta_time)
	var iter := -1
	for countdown_value in countdown_array:
		iter += 1
		match(iter):
			0:
				if countdown_value == 0: 
					continue
				countdown_clock += "%d Day" % countdown_value
				if countdown_value > 1:
					countdown_clock += "s"
				countdown_clock += " :"
			1, 2:
				countdown_clock += "%02d :" % countdown_value
			3:
				countdown_clock += "%02d" % countdown_value
		countdown_clock += " "
	return countdown_clock

func _unix_is_after_jam(unix_time : int) -> bool:
	return unix_time > get_jam_time() + get_voting_time()

func _unix_is_voting_period(unix_time : int) -> bool:
	return unix_time > get_jam_time() and unix_time <= get_jam_time() + get_voting_time()

func _unix_is_jam_period(unix_time : int) -> bool:
	return unix_time > 0 and unix_time <= get_jam_time()

func _append_adjusted_flag(stage_idx : int) -> String:
	match stage_idx:
		0:
			if jam_extension > 0: return "(+)"
		1:
			if jam_extension + voting_extension > 0: return "(+)"
	return ""

func get_current_stage() -> int:
	var time_until_jam := _get_delta_time_until_jam()
	if _unix_is_after_jam(-time_until_jam):
		return 2
	if _unix_is_voting_period(-time_until_jam):
		return 1
	elif _unix_is_jam_period(-time_until_jam):
		return 0
	return -1

func set_stage_labels(text : String) -> void:
	stage_label.text = text
	stage_label_2.text = text

func set_countdown_text(delta_time_unix : int, suffix : String = "") -> void:
	countdown_button.text = _get_countdown_string(delta_time_unix) + suffix
	countdown_label.text = _get_countdown_clock(delta_time_unix) + suffix

func refresh_text() -> void:
	var delta_time_unix := _get_delta_time_until_jam()
	var stage := get_current_stage()
	match(stage):
		0:
			set_stage_labels(JAM_STAGE_STRING)
			delta_time_unix += get_jam_time()
		1:
			set_stage_labels(VOTING_STAGE_STRING)
			delta_time_unix += get_jam_time() + get_voting_time()
		2:
			# Today is passed the current month's jam. Get next months jam.
			delta_time_unix = _get_delta_time_until_next_month_jam()
			set_stage_labels(DEFAULT_STAGE_STRING)
		_:
			set_stage_labels(DEFAULT_STAGE_STRING)
	set_countdown_text(delta_time_unix, _append_adjusted_flag(stage))

func _open_current_jam_page() -> void:
	var current_time_dict := Time.get_datetime_dict_from_system(true)
	var month_diff = current_time_dict["month"] - JAM_FIRST_MONTH
	var year_diff = current_time_dict["year"] - JAM_FIRST_YEAR
	var current_jam_index = month_diff + (year_diff * 12) + 1
	var _err = OS.shell_open("%s%d" % [JAM_LINK_PREFIX, current_jam_index])

func _on_timer_timeout() -> void:
	refresh_text()

func _on_jam_icon_button_pressed() -> void:
	_open_current_jam_page()

func _ready() -> void:
	refresh_text()

func _on_confirmation_dialog_canceled():
		jam_extension = _prev_jam_extension
		voting_extension = _prev_voting_extension

func _reset_day_adjustment_value(stage_idx: int = 0) -> void:
	match stage_idx:
		0:
			day_adjustment.value = jam_extension
			day_adjustment.editable = true
		1:
			day_adjustment.value = voting_extension
			day_adjustment.editable = true

func _on_countdown_button_pressed() -> void:
	_prev_jam_extension = jam_extension
	_prev_voting_extension = voting_extension
	stage_option.selected = get_current_stage()
	_reset_day_adjustment_value(stage_option.selected)
	confirmation_dialog.show()

func _on_confirmation_dialog_confirmed() -> void:
	match stage_option.selected:
		0:
			jam_extension = day_adjustment.value
		1:
			voting_extension = day_adjustment.value

func _on_day_adjustment_value_changed(value):
	match stage_option.selected:
		0:
			jam_extension = day_adjustment.value
		1:
			voting_extension = day_adjustment.value

func _on_stage_option_item_selected(index) -> void:
	_reset_day_adjustment_value(index)

func _enter_tree() -> void:
	jam_extension = ProjectSettings.get_setting(PROJECT_SETTINGS_PATH + 'jam_extension', 0)
	voting_extension = ProjectSettings.get_setting(PROJECT_SETTINGS_PATH + 'voting_extension', 0)

func _exit_tree() -> void:
	ProjectSettings.set_setting(PROJECT_SETTINGS_PATH + 'jam_extension', jam_extension)
	ProjectSettings.set_setting(PROJECT_SETTINGS_PATH + 'voting_extension', voting_extension)
