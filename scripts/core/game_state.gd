extends Node

signal money_changed(current_money: int)
signal processed_items_changed(total_processed_items: int)
signal state_restored

var _money: int = 0
var _total_money_earned: int = 0
var _total_processed_items: int = 0
var _total_playtime: float = 0.0


func _process(delta: float) -> void:
	_total_playtime += delta


func get_money() -> int:
	return _money


func get_total_money_earned() -> int:
	return _total_money_earned


func get_total_processed_items() -> int:
	return _total_processed_items


func get_total_playtime() -> float:
	return _total_playtime


func add_money(amount: int) -> bool:
	if amount <= 0:
		return false

	_money += amount
	_total_money_earned += amount
	money_changed.emit(_money)
	return true


func spend_money(amount: int) -> bool:
	if amount <= 0 or amount > _money:
		return false

	_money -= amount
	money_changed.emit(_money)
	return true


func register_processed_items(amount: int) -> bool:
	if amount <= 0:
		return false

	_total_processed_items += amount
	processed_items_changed.emit(_total_processed_items)
	return true


func restore_state(
	money: int, total_money_earned: int, total_processed_items: int, total_playtime: float
) -> bool:
	if money < 0 or total_money_earned < 0 or total_processed_items < 0 or total_playtime < 0.0:
		return false

	_money = money
	_total_money_earned = total_money_earned
	_total_processed_items = total_processed_items
	_total_playtime = total_playtime

	money_changed.emit(_money)
	processed_items_changed.emit(_total_processed_items)
	state_restored.emit()
	return true
