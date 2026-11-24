extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Simulation.new(false)
	game.save_path = "user://market_order_%s.json" % str(Time.get_ticks_usec())
	game.start_empty_city()
	game.new_day_market()
	check(game.market_order_amount == 0, "No order without farm storage")
	game.campaign_stage = 15
	game.territory.set_expansion_level(15)
	var bridge_site: Vector2i = game.territory.bridge_site
	game.territory.place_bridge(bridge_site.x, bridge_site.y)
	game.budget = 100000
	game.farm_build_suggestion()
	game.farm_build_suggestion()
	check(game.farm_storage_capacity() > 0.0, "A barn gives storage")
	game.new_day_market()
	check(game.market_order_amount >= 10 and game.market_order_fresh, "A new day brings an order")
	check(game.market_order_reward == game.market_order_amount * Simulation.MARKET_ORDER_REWARD_PER_UNIT, "Reward scales with amount")
	check(not game.market_order_fulfill(), "Cannot fulfil without stock")
	var amount := game.market_order_amount
	var reward := game.market_order_reward
	game.farm_stock = float(amount) + 5.0
	var budget_before: int = game.budget
	check(game.market_order_fulfill(), "Fulfils with enough stock")
	check(game.budget == budget_before + reward and absf(game.farm_stock - 5.0) < 0.01, "Pays the reward and takes the goods")
	check(game.market_order_amount == 0, "Order cleared")
	game.new_day_market()
	check(game.market_order_amount > 0, "Next day, a new order")
	game.new_day_market()
	game.new_day_market()
	var days_left: int = game.market_order_days_left
	var pending: int = game.market_order_amount
	game.save_game()
	var loaded := Simulation.new(false)
	loaded.save_path = game.save_path
	check(loaded.load_game(), "Save loads")
	check(loaded.market_order_amount == pending and loaded.market_order_days_left == days_left, "Order survives save/load")
	print("MARKET ORDER CHECKS: ", "PASS" if failures.is_empty() else "FAIL")
	for f in failures:
		print(f)
	quit(0 if failures.is_empty() else 1)
