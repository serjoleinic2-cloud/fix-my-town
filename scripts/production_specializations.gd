extends RefCounted
# Declarative specialization definitions for production-building integration.
# No economy mutation occurs until simulation explicitly adopts this catalog.
const TREES := {
	"farm": {
		"field_crops": {"ru": "Полевые культуры", "en": "Field crops", "output": "grain", "service": "fire"},
		"livestock": {"ru": "Животноводство", "en": "Livestock", "output": "food", "service": "medical"},
		"greenhouse": {"ru": "Теплицы", "en": "Greenhouses", "output": "produce", "service": "electric"}
	},
	"sawmill": {
		"boards": {"ru": "Доски", "en": "Boards", "output": "lumber", "service": "fire"},
		"furniture": {"ru": "Мебель", "en": "Furniture", "output": "furniture", "service": "repair"},
		"structural_timber": {"ru": "Строевой лес", "en": "Structural timber", "output": "materials", "service": "repair"}
	},
	"mill": {
		"bakery_supply": {"ru": "Мука для пекарен", "en": "Bakery supply", "output": "flour", "service": "repair"},
		"animal_feed": {"ru": "Комбикорм", "en": "Animal feed", "output": "feed", "service": "repair"},
		"wholesale": {"ru": "Оптовые поставки", "en": "Wholesale", "output": "bulk_flour", "service": "logistics"}
	},
	"warehouse": {
		"cold_chain": {"ru": "Холодильный склад", "en": "Cold chain", "output": "cold_storage", "service": "electric"},
		"construction_hub": {"ru": "Строительный склад", "en": "Construction hub", "output": "construction_supply", "service": "repair"},
		"distribution": {"ru": "Распределительный центр", "en": "Distribution", "output": "delivery", "service": "logistics"}
	}
}

static func branches(type_id: String) -> Array[String]:
	var result: Array[String] = []
	for branch_id: String in TREES.get(type_id, {}):
		result.append(branch_id)
	return result

static func valid_branch(type_id: String, branch_id: String) -> bool:
	return branch_id == "basic" or TREES.get(type_id, {}).has(branch_id)

static func branch_data(type_id: String, branch_id: String) -> Dictionary:
	return TREES.get(type_id, {}).get(branch_id, {})

static func normalize(type_id: String, branch_id: String) -> String:
	return branch_id if valid_branch(type_id, branch_id) else "basic"

static func can_specialize(type_id: String, level: int, branch_id: String) -> bool:
	return level >= 2 and branch_id != "basic" and TREES.get(type_id, {}).has(branch_id)

static func label(type_id: String, branch_id: String, language: String = "ru") -> String:
	if branch_id == "basic":
		return "Базовое производство" if language == "ru" else "Basic production"
	var data := branch_data(type_id, branch_id)
	return str(data.get("en" if language == "en" else "ru", branch_id))
