@tool
extends Control

const TARGET_WEEKDAY : = 5
const TARGET_WEEKDAY_OCCURRENCE : int = 2
const TARGET_HOUR := 20
const JAM_DAYS = 9
const VOTING_DAYS = 7
const SECONDS_PER_DAY = 86400
const SECONDS_PER_HOUR = 3600
const SECONDS_PER_MINUTE = 60
const MIN_DAYS_PER_MONTH = 29

const DEFAULT_STAGE_STRING = "Jam Begins"
const VOTING_STAGE_STRING = "Voting Ends"
const JAM_STAGE_STRING = "Jam Ends"

const JAM_LINK_PREFIX = "https://itch.io/jam/godot-wild-jam-"
const JAM_FIRST_MONTH = 9
const JAM_FIRST_YEAR = 2018

@onready var stage_label = %StageLabel
@onready var countdown_label = %CountdownLabel

@export_range(1, 3) var precision : int = 2

@export_group("Debug")
@export var adjust_days : int = 0
@export var adjust_hours : int = 0

func _get_2nd_friday(day : int, weekday : int) -> int:
	var weekday_diff := weekday - TARGET_WEEKDAY
	var target_relative_day := (day - weekday_diff)
	var target_first_day := target_relative_day % 7
	var target_day = target_first_day + (7 * (TARGET_WEEKDAY_OCCURRENCE - 1))
	return target_day

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
	var jam_start_day = _get_2nd_friday(datetime_dict["day"], datetime_dict["weekday"])
	datetime_dict["day"] = jam_start_day
	datetime_dict["weekday"] = TARGET_WEEKDAY
	datetime_dict["hour"] = TARGET_HOUR
	datetime_dict["minute"] = 0
	datetime_dict["second"] = 0
	return datetime_dict

func _get_delta_time_until_next_month_jam() -> int:
	var current_time_dict := Time.get_datetime_dict_from_system(true)
	current_time_dict = adjust_datetime_dict(current_time_dict)
	var current_time_unix := int(Time.get_unix_time_from_datetime_dict(current_time_dict))
	var next_month_unix = current_time_unix + (MIN_DAYS_PER_MONTH * SECONDS_PER_DAY)
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

func _get_countdown_string(delta_time : int) -> String:
	var countdown_string : String = ""
	var countdown_array : Array[int]
	countdown_array.append(delta_time / SECONDS_PER_DAY)
	countdown_array.append((delta_time % SECONDS_PER_DAY ) / SECONDS_PER_HOUR)
	countdown_array.append((delta_time % SECONDS_PER_DAY % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)
	countdown_array.append(delta_time % SECONDS_PER_DAY % SECONDS_PER_HOUR % SECONDS_PER_MINUTE)
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

func _unix_is_after_jam(unix_time : int) -> bool:
	return unix_time > (JAM_DAYS + VOTING_DAYS) * SECONDS_PER_DAY

func _unix_is_voting_period(unix_time : int) -> bool:
	return unix_time > JAM_DAYS * SECONDS_PER_DAY and unix_time <= (JAM_DAYS + VOTING_DAYS) * SECONDS_PER_DAY

func _unix_is_jam_period(unix_time : int) -> bool:
	return unix_time > 0 and unix_time <= JAM_DAYS * SECONDS_PER_DAY

func refresh_text():
	var delta_time_unix := _get_delta_time_until_jam()
	if _unix_is_after_jam(-delta_time_unix):
		# Today is passed the current month's jam. Get next months jam.
		delta_time_unix = _get_delta_time_until_next_month_jam()
		stage_label.text = DEFAULT_STAGE_STRING
	elif _unix_is_voting_period(-delta_time_unix):
		stage_label.text = VOTING_STAGE_STRING
		delta_time_unix += (JAM_DAYS + VOTING_DAYS) * SECONDS_PER_DAY
	elif _unix_is_jam_period(-delta_time_unix):
		stage_label.text = JAM_STAGE_STRING
		delta_time_unix += JAM_DAYS * SECONDS_PER_DAY
	else:
		stage_label.text = DEFAULT_STAGE_STRING
	countdown_label.text = _get_countdown_string(delta_time_unix)

func _open_current_jam_page():
	var current_time_dict := Time.get_datetime_dict_from_system(true)
	var month_diff = current_time_dict["month"] - JAM_FIRST_MONTH
	var year_diff = current_time_dict["year"] - JAM_FIRST_YEAR
	var current_jam_index = month_diff + (year_diff * 12) + 1
	var _err = OS.shell_open("%s%d" % [JAM_LINK_PREFIX, current_jam_index])

func _on_timer_timeout():
	refresh_text()

func _on_texture_rect_pressed():
	_open_current_jam_page()

func _ready():
	refresh_text()
