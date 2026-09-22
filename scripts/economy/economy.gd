extends Node


func can_afford(amount: int) -> bool:
	return amount >= 0 and GameState.get_money() >= amount


func add_money(amount: int) -> bool:
	if amount <= 0:
		return false

	return GameState.add_money(amount)


func spend_money(amount: int) -> bool:
	if amount <= 0 or not can_afford(amount):
		return false

	return GameState.spend_money(amount)
