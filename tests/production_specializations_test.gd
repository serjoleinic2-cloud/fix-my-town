extends SceneTree
const Specializations = preload("res://scripts/production_specializations.gd")
var failures := 0

func _initialize() -> void:
	for kind in ["farm", "sawmill", "mill", "warehouse"]:
		var options := Specializations.branches(kind)
		if options.size() != 3:
			push_error("%s needs three branches" % kind)
			failures += 1
		for branch_id in options:
			if not Specializations.can_specialize(kind, 2, branch_id):
				push_error("%s/%s should unlock at level 2" % [kind, branch_id])
				failures += 1
			if Specializations.can_specialize(kind, 1, branch_id):
				push_error("%s/%s unlocked too early" % [kind, branch_id])
				failures += 1
			if Specializations.label(kind, branch_id, "ru").is_empty() or Specializations.label(kind, branch_id, "en").is_empty():
				push_error("Missing localization: %s/%s" % [kind, branch_id])
				failures += 1
	if Specializations.normalize("warehouse", "invalid") != "basic":
		push_error("Invalid saved specialization must fall back to basic")
		failures += 1
	print("PRODUCTION SPECIALIZATION CATALOG: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
