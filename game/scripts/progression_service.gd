extends RefCounted


static func grant_session_rewards(
	session_mode: String,
	status: String,
	actual_sec: int,
	planned_duration_sec: int,
	currencies: Dictionary,
	level_progress: Dictionary,
	bond_progress: Dictionary,
	min_rewardable_session_sec: int,
	base_focus_points: int,
	base_bond: int,
	base_xp: int
) -> Dictionary:
	var rewardable := session_mode == "focus" and actual_sec >= min_rewardable_session_sec and status != "abandoned"
	if not rewardable:
		return {
			"rewardable": false,
			"focus_points": 0,
			"xp": 0,
			"bond": 0,
			"summary": "No reward. Session was below the reward threshold."
		}

	var ratio := 1.0
	if status == "partial":
		ratio = clamp(actual_sec / float(planned_duration_sec), 0.3, 0.99)

	var focus_points := int(round(base_focus_points * ratio))
	var bond := int(round(base_bond * ratio))
	var xp := int(round(base_xp * ratio))

	currencies.focus_points += focus_points
	currencies.bond_points_total += bond
	add_xp(level_progress, xp, currencies)
	add_bond(bond_progress, bond)

	return {
		"rewardable": true,
		"focus_points": focus_points,
		"xp": xp,
		"bond": bond,
		"summary": "+%d Focus Points  +%d XP  +%d Bond" % [focus_points, xp, bond]
	}


static func add_xp(level_progress: Dictionary, amount: int, currencies: Dictionary = {}) -> void:
	level_progress.focus_xp += amount
	level_progress.focus_xp_lifetime += amount
	var required := xp_required_for_next_level(level_progress)
	while level_progress.focus_xp >= required:
		level_progress.focus_xp -= required
		if not currencies.is_empty():
			currencies.gold_tokens = int(currencies.get("gold_tokens", 0)) + 1
		else:
			level_progress.focus_level += 1
		required = xp_required_for_next_level(level_progress)


static func add_bond(bond_progress: Dictionary, amount: int) -> void:
	bond_progress.bond_points_current += amount
	bond_progress.bond_points_lifetime += amount
	bond_progress.last_interaction_at = Time.get_datetime_string_from_system(false, true)
	var required := bond_required_for_next_level(bond_progress)
	while bond_progress.bond_points_current >= required:
		bond_progress.bond_points_current -= required
		bond_progress.bond_level += 1
		required = bond_required_for_next_level(bond_progress)


static func xp_required_for_next_level(level_progress: Dictionary) -> int:
	return 80


static func bond_required_for_next_level(bond_progress: Dictionary) -> int:
	return 60 + (int(bond_progress.bond_level) - 1) * 25
