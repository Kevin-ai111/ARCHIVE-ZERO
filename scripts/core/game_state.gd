extends Node

signal money_changed(current_money: int)
signal processed_items_changed(total_processed_items: int)
signal state_restored

const TRANSACTION_SNAPSHOT_KEYS: Array[String] = [
	"money", "total_money_earned", "total_processed_items", "total_playtime",
]

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


func get_transaction_snapshot() -> Dictionary:
	return {
		"money": _money,
		"total_money_earned": _total_money_earned,
		"total_processed_items": _total_processed_items,
		"total_playtime": _total_playtime,
	}


func is_valid_transaction_snapshot(snapshot: Variant) -> bool:
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.size() != TRANSACTION_SNAPSHOT_KEYS.size():
		return false
	for key: String in TRANSACTION_SNAPSHOT_KEYS:
		if not snapshot.has(key):
			return false
	return (
		_is_non_negative_integer(snapshot["money"])
		and _is_non_negative_integer(snapshot["total_money_earned"])
		and _is_non_negative_integer(snapshot["total_processed_items"])
		and typeof(snapshot["total_playtime"]) in [TYPE_INT, TYPE_FLOAT]
		and is_finite(float(snapshot["total_playtime"]))
		and float(snapshot["total_playtime"]) >= 0.0
	)


func restore_transaction_snapshot_silent(snapshot: Variant) -> bool:
	if not is_valid_transaction_snapshot(snapshot):
		return false
	_money = int(snapshot["money"])
	_total_money_earned = int(snapshot["total_money_earned"])
	_total_processed_items = int(snapshot["total_processed_items"])
	_total_playtime = float(snapshot["total_playtime"])
	return true


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


func _is_non_negative_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= 0
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and value >= 0.0 and value == floor(value)
	return false
