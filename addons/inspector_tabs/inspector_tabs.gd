extends EditorInspectorPlugin


var current_category:String = ""

var categories = [] # All categories/subclasses in the inspector
var tabs = [] # All tabs in the inspector

var categories_finish = false # Finish adding categories

var tab_bar:TabBar # Inspector Tabs
var base_control = EditorInterface.get_base_control()
var settings = EditorInterface.get_editor_settings()


var tab_can_change = false # Stops the TabBar from changing tab

var vertical_mode:bool = true # Tab position
var vertical_tab_side = 1 # 0:left; 1:Right;
var tab_style:int
var property_mode:int
var merge_abstract_class_tabs:bool

enum TabStyle{
	TextOnly,
	IconOnly,
	TextAndIcon
}


var object_custom_classes = [] # Custom classes in the inspector

var is_filtering = false # are the search bar in use

var property_container # path to the editor inspector list of properties
var favorite_container # path to the editor inspector favorite list.
var viewer_container # path to the editor inspector "viewer" area. (camera viewer or skeleton3D bone tree)
var property_scroll_bar:VScrollBar
var icon_grabber

var UNKNOWN_ICON:ImageTexture # Use to check if the loaded icon is an unknown icon

var current_parse_category:String = ""

func _can_handle(object):
	# We support all objects in this example.
	return true

# Start inspector loading
func parse_begin(object: Object) -> void:
	categories_finish = false
	categories.clear()
	tabs.clear()
	
	tab_can_change = false
	tab_bar.clear_tabs()
	object_custom_classes.clear()
	
# getting the category from the inspector
func _parse_category(object: Object, category: String) -> void:
	if category == "Atlas": return # Not sure what class this is. But it seems to break things.
		
	# reset the list if its the first category
	if categories_finish:
		parse_begin(object)
	
	if current_parse_category != "Node": # This line is needed because when selecting multiple nodes the refcounted class will be the last tab.
		current_parse_category = category
	
# Finished getting inspector categories
func _parse_end(object: Object) -> void:
	if current_parse_category != "Node": return # False finish
	current_parse_category = ""
	
	for i in property_container.get_children():
		if i.get_class() == "EditorInspectorCategory":
			
			# Get Node Name
			var category = i.get("tooltip_text").split("|")
			if category.size() > 1:
				category = category[1]
			else:
				category = category[0]
				
			if category.split('"').size() > 1:
				category = category.split('"')[1]

			# Add it to the list of categories and tabs
			categories.append(category)
			if is_new_tab(category):
				tabs.append(category)

		elif categories.size() == 0:# If theres properties at the top of the inspector without its own category.
			# Add it to the list of categories and tabs
			var category = "Unknown"
			tabs.append(category)
			categories.append(category)
	categories_finish = true
	update_tabs() # load tab
	tab_can_change = true

	var tab = tabs.find(current_category)
	if tab == -1:
		tab_clicked(0)
		tab_selected(0)
		tab_bar.current_tab = 0
	else:
		tab_clicked(tab)
		tab_bar.current_tab = tab
	
	tab_resized()
	
# Is it not a custom class
func is_base_class(c_name:String) -> bool:
	if c_name.contains("."):return false
	for list in ProjectSettings.get_global_class_list():
		if list.class == c_name:
			return false
	return true
	
	
func get_class_icon(c_name:String) -> ImageTexture:
	
	#Get GDExtension Icon
	var load_icon = icon_grabber.get_icon(c_name)
	if load_icon != null:
		return load_icon
	load_icon = UNKNOWN_ICON
	
	
	if c_name.ends_with(".gd"):# GDScript Icon
		load_icon = base_control.get_theme_icon("GDScript", "EditorIcons")
	if c_name == "RefCounted":# RefCounted Icon
		load_icon = base_control.get_theme_icon("Object", "EditorIcons")
	elif ClassDB.class_exists(c_name): # Get editor icon
		load_icon = base_control.get_theme_icon(c_name, "EditorIcons")
	else:
		# Get custom class icon
		for list in ProjectSettings.get_global_class_list():
			if list.class == c_name:
				if list.icon != "":
					var texture:Texture2D = load(list.icon)
					var image = texture.get_image()
					image.resize(load_icon.get_width(),load_icon.get_height())
					return ImageTexture.create_from_image(image)
				break

	if load_icon != UNKNOWN_ICON:
		return load_icon # Return if icon is not unknown
	
	# if icon not found just use the node disabled icon
	return base_control.get_theme_icon("NodeDisabled", "EditorIcons")

# add tabs
func update_tabs() -> void:
	tab_bar.clear_tabs()
	for tab in tabs:
		var load_icon = get_class_icon(tab)
		
		if vertical_mode:
			# Rotate the image for the vertical tab
			if vertical_tab_side == 0:
				var rotated_image = load_icon.get_image().duplicate()
				rotated_image.rotate_90(CLOCKWISE)
				load_icon = ImageTexture.create_from_image(rotated_image)
			else:
				var rotated_image = load_icon.get_image().duplicate()
				rotated_image.rotate_90(COUNTERCLOCKWISE)
				load_icon = ImageTexture.create_from_image(rotated_image)
			
		match tab_style:
			TabStyle.TextOnly:
				tab_bar.add_tab(tab,null)
			TabStyle.IconOnly:
				tab_bar.add_tab("",load_icon)
			TabStyle.TextAndIcon:
				tab_bar.add_tab(tab,load_icon)
		tab_bar.set_tab_tooltip(tab_bar.tab_count-1,tab)

func tab_clicked(tab: int) -> void:
	if is_filtering: return
	if property_mode == 0: # Tabbed
		var category_idx = -1
		var tab_idx = -1
		
		# Show nececary properties
		for i in property_container.get_children():
			if i.get_class() == "EditorInspectorCategory":
				category_idx += 1
				if is_new_tab(categories[category_idx]):
					tab_idx += 1
					
			elif tab_idx == -1: # If theres properties at the top of the inspector without its own category.
				category_idx += 1
				if is_new_tab(categories[category_idx]):
					tab_idx += 1
			if tab_idx != tab:
				i.visible = false
			else:
				i.visible = true
	elif property_mode == 1: # Jump Scroll
		var category_idx = -1
		var tab_idx = -1
		
		# Show nececary properties
		for i in property_container.get_children():
			if i.get_class() == "EditorInspectorCategory":
				category_idx += 1
				if is_new_tab(categories[category_idx]):
					tab_idx += 1
				if tab_idx == tab:
					property_scroll_bar.value = (i.position.y+property_container.position.y)/EditorInterface.get_inspector().get_node("@VBoxContainer@6472").size.y*property_scroll_bar.max_value
					break
			elif tab_idx == -1 and tab == 0: # If theres properties at the top of the inspector without its own category.
				property_scroll_bar.value = 0
				break

func is_new_tab(category:String) -> bool:
	if merge_abstract_class_tabs:
		if ClassDB.class_exists(category) and not ClassDB.can_instantiate(category):
			if categories[0] == category:
				return true
			return false
	return true


# Is searching
func filter_text_changed(text:String):
	if text != "":
		for i in property_container.get_children():
			i.visible = true
		is_filtering = true
	else:
		is_filtering = false
		tab_clicked(tab_bar.current_tab)

	
func tab_selected(tab):
	if tab_can_change:
		current_category = tabs[tab]
		
func tab_resized():
	if not vertical_mode:
		if tabs.size() != 0:
			tab_bar.max_tab_width = tab_bar.get_parent().get_rect().size.x/tabs.size()



# Change position mode
func change_vertical_mode(mode:bool = vertical_mode):
	vertical_mode = mode
	if tab_bar:
		tab_bar.queue_free()
	vertical_mode = vertical_mode

	tab_bar = TabBar.new()
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.clip_tabs = true
	tab_bar.rotation = PI/2
	tab_bar.mouse_filter =Control.MOUSE_FILTER_PASS
	var panel = Panel.new()
	tab_bar.add_child(panel)
	panel.anchor_right = 1
	panel.anchor_bottom = 1
	panel.show_behind_parent = true
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var inspector = EditorInterface.get_inspector().get_parent()
	
	tab_bar.tab_clicked.connect(tab_clicked)
	
	if not vertical_mode:
		inspector.add_child(tab_bar)
		inspector.move_child(tab_bar,3)

	update_tabs()

	if vertical_mode:
		EditorInterface.get_inspector().add_child(tab_bar)
		property_container.size_flags_horizontal = Control.SIZE_SHRINK_END
		favorite_container.size_flags_horizontal = Control.SIZE_SHRINK_END
		viewer_container.size_flags_horizontal = Control.SIZE_SHRINK_END
		tab_bar.top_level = true
		if vertical_tab_side == 0:
			tab_bar.layout_direction =Control.LAYOUT_DIRECTION_RTL
		else:
			tab_bar.layout_direction =Control.LAYOUT_DIRECTION_LTR
	else:
		property_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		favorite_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		viewer_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		property_container.custom_minimum_size.x = 0
		favorite_container.custom_minimum_size.x = 0
		viewer_container.custom_minimum_size.x = 0
	tab_bar.resized.connect(tab_resized)
	tab_bar.tab_selected.connect(tab_selected)
	tab_resized()
			

func settings_changed() -> void:
	var tab_pos = settings.get("interface/inspector/tab_layout")
	if tab_pos != null:
		if tab_pos == 0:
			if vertical_mode != false:
				change_vertical_mode(false)
		else:
			if vertical_mode != true:
				change_vertical_mode(true)
	var style = settings.get("interface/inspector/tab_style")
	if style != null:
		if tab_style != style:
			tab_style = style
	var prop_mode = settings.get("interface/inspector/tab_property_mode")
	if prop_mode != null:
		if property_mode != prop_mode:
			property_mode = prop_mode
	var merge_class = settings.get("interface/inspector/merge_abstract_class_tabs")
	if merge_class != null:
		if merge_abstract_class_tabs != merge_class:
			merge_abstract_class_tabs = merge_class
			
	if tab_pos != null and style != null and prop_mode != null and merge_class != null:

		#Save settings
		var config = ConfigFile.new()
		# Store some values.
		config.set_value("Settings", "tab layout", tab_pos)
		config.set_value("Settings", "tab style", style)
		config.set_value("Settings", "tab property mode", prop_mode)
		config.set_value("Settings", "merge abstract class tabs", merge_abstract_class_tabs)

		# Save it to a file (overwrite if already exists).
		var err = config.save(EditorInterface.get_editor_paths().get_config_dir()+"/InspectorTabsPluginSettings.cfg")
		if err != OK:
			print("Error saving inspector tab settings: ",error_string(err))

func property_scrolling():
	if property_mode != 1 or tab_bar.tab_count == 0 or is_filtering:return
	var category_idx = -1
	var tab_idx = -1
	var category_y = - INF
	if property_scroll_bar.value <= 1:
		tab_bar.current_tab = 0
		return
	for i in property_container.get_children():
		if i.get_class() == "EditorInspectorCategory":
			if (i.position.y+property_container.position.y-EditorInterface.get_inspector().size.y/3) <= property_scroll_bar.value/property_scroll_bar.max_value*EditorInterface.get_inspector().get_node("@VBoxContainer@6472").size.y:
				category_y = property_container.position.y
			else:
				tab_bar.current_tab = max(tab_idx,0)
				break
			category_idx += 1
			if is_new_tab(categories[category_idx]):
				tab_idx += 1
		elif tab_idx == -1: # If theres properties at the top of the inspector without its own category.
			category_idx += 1
			tab_idx += 1
