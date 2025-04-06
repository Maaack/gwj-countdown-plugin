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
const JAM_STAGE_STRING = "Submission Due"

const JAM_LINK_PREFIX = "https://itch.io/jam/godot-wild-jam-"
const JAM_FIRST_MONTH = 9
const JAM_FIRST_YEAR = 2018

@onready var stage_label = %StageLabel
@onready var countdown_label = %CountdownLabel

func _get_2nd_friday(day : int, weekday : int) -> int:
	var weekday_diff := weekday - TARGET_WEEKDAY
	var target_relative_day := (day - weekday_diff)
	var target_first_day := target_relative_day % 7
	var target_day = target_first_day + (7 * (TARGET_WEEKDAY_OCCURRENCE - 1))
	return target_day

func _get_delta_time_until_next_month_jam() -> int:
	var current_time_unix := int(Time.get_unix_time_from_system())
	var next_month_unix = current_time_unix + (MIN_DAYS_PER_MONTH * SECONDS_PER_DAY)
	var next_month_dict := Time.get_datetime_dict_from_unix_time(next_month_unix)
	var day = next_month_dict["day"]
	var weekday = next_month_dict["weekday"]
	var jam_start_day = _get_2nd_friday(day, weekday)
	next_month_dict["day"] = jam_start_day
	next_month_dict["weekday"] = TARGET_WEEKDAY
	next_month_dict["hour"] = TARGET_HOUR
	next_month_dict["minute"] = 0
	next_month_dict["second"] = 0
	var jam_time_unix := Time.get_unix_time_from_datetime_dict(next_month_dict)
	return jam_time_unix - current_time_unix

func _get_delta_time_until_jam() -> int:
	var current_time_dict := Time.get_datetime_dict_from_system(true)
	var day = current_time_dict["day"]
	var weekday = current_time_dict["weekday"]
	var jam_start_day = _get_2nd_friday(day, weekday)
	var jam_time_dict = current_time_dict.duplicate()
	jam_time_dict["day"] = jam_start_day
	jam_time_dict["weekday"] = TARGET_WEEKDAY
	jam_time_dict["hour"] = TARGET_HOUR
	jam_time_dict["minute"] = 0
	jam_time_dict["second"] = 0
	var current_time_unix := Time.get_unix_time_from_datetime_dict(current_time_dict)
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
	var display_length := 2
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
		if displayed_count >= display_length:
			break
	return countdown_string

func refresh_text():
	var delta_time_unix := _get_delta_time_until_jam()
	var jam_days_delta := delta_time_unix / SECONDS_PER_DAY
	if -jam_days_delta >= JAM_DAYS + VOTING_DAYS:
		# Today is passed the current month's jam. Get next months jam.
		delta_time_unix = _get_delta_time_until_next_month_jam()
	elif -jam_days_delta >= JAM_DAYS and -jam_days_delta < JAM_DAYS + VOTING_DAYS:
		stage_label.text = VOTING_STAGE_STRING
		delta_time_unix += (JAM_DAYS + VOTING_DAYS) * SECONDS_PER_DAY
	elif -jam_days_delta >= 0 and -jam_days_delta < JAM_DAYS:
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
