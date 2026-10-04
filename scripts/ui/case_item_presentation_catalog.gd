class_name CaseItemPresentationCatalog
extends RefCounted

# Presentation mapping only. No textures enter CaseManager or its save schema.
const TEXTURES := {
	&"red_folding_umbrella": preload("res://assets/cases/items/AZ_ITEM_red_folding_umbrella_2x.png"),
	&"smartphone": preload("res://assets/cases/items/AZ_ITEM_smartphone_2x.png"),
	&"backpack": preload("res://assets/cases/items/AZ_ITEM_backpack_2x.png"),
	&"passport_wallet": preload("res://assets/cases/items/AZ_ITEM_passport_wallet_2x.png"),
	&"wireless_earbuds": preload("res://assets/cases/items/AZ_ITEM_wireless_earbuds_2x.png"),
	&"canvas_tote_bag": preload("res://assets/cases/items/AZ_ITEM_canvas_tote_bag_2x.png"),
	&"house_keys": preload("res://assets/cases/items/AZ_ITEM_house_keys_2x.png"),
	&"tablet": preload("res://assets/cases/items/AZ_ITEM_tablet_2x.png"),
	&"document_folder": preload("res://assets/cases/items/AZ_ITEM_document_folder_2x.png"),
	&"black_hotel_keycard": preload("res://assets/cases/items/AZ_ITEM_black_hotel_keycard_2x.png"),
}


static func get_texture(item_id: StringName) -> Texture2D:
	return TEXTURES.get(item_id) as Texture2D
