### updater.gd

@tool
extends EditorPlugin

const Transformer = preload("res://addons/updater/updater_transformations.gd")
const file_types: Array = ["*.gd", "*.tscn"]

var transformer

# Called when the plugin is enabled.
func _enter_tree():
    # Add a new toolbar menu item for iterative transformation
    add_tool_menu_item("Upgrade Test", Callable(self, "_on_test_button_pressed"))
    # Add a toolbar menu item for upgrading
    add_tool_menu_item("Upgrade Project From Godot 3.X", Callable(self, "_on_upgrade_button_pressed"))
    
func _exit_tree():
    # Remove the toolbar menu items
    remove_tool_menu_item("Upgrade Test")
    remove_tool_menu_item("Upgrade Project From Godot 3.X")

func show_backup_warning():
    var dialog = AcceptDialog.new()
    dialog.title = "Warning"
    dialog.dialog_text = "Make sure you have backed up your project before upgrading all scripts. Continue?"
    dialog.get_ok_button().text = "Yes"
    dialog.add_cancel_button("Cancel")
    dialog.connect("confirmed", Callable(self, "_on_backup_warning_confirmed"))
    get_tree().get_root().add_child(dialog)
    dialog.popup_centered()

func _on_backup_warning_confirmed():
    var upgraded_files = upgrade_project()
    var dialog = AcceptDialog.new()

    var problematic_functions = transformer.list_problematic_functions()
    if problematic_functions != "":
        dialog.title = "Problematic Functions"
        dialog.dialog_text = "The following functions had issues:\n" + problematic_functions
    else:
        dialog.title = "Upgrade Complete"
        if upgraded_files.size() > 0:
            dialog.dialog_text = "The following files have been upgraded:\n" + "\n".join(upgraded_files)
        else:
            dialog.dialog_text = "No files were upgraded."

    dialog.get_ok_button().text = "OK"
    get_tree().get_root().add_child(dialog)
    dialog.popup_centered()

func upgrade_project() -> Array:
    # Instantiate the transformer
    transformer = Transformer.new()

    var files_to_upgrade = []
    var upgraded_files = []
    walk_directory("res://", files_to_upgrade)
    for file_path in files_to_upgrade:
        var file = FileAccess.open(file_path, FileAccess.READ)
        if file:
            var text = file.get_as_text()
            file.close()
            var new_text = transformer.run_all_functions(text)
            # Save only if the file has changed.
            if new_text != text:
                file = FileAccess.open(file_path, FileAccess.WRITE)
                file.store_string(new_text)
                file.close()
                upgraded_files.append(file_path)
        else:
            print("Could not open file: ", file_path)
    return upgraded_files

# Recursively walks the directory starting at 'path' and collects .gd files,
# skipping anything inside the plugin folder.
func walk_directory(path: String, files: Array):
    var dir = DirAccess.open(path)
    if dir == null:
        return
    dir.list_dir_begin()
    var filename = dir.get_next()
    while filename != "":
        if filename.begins_with("."):
            filename = dir.get_next()
            continue
        var full_path = path + "/" + filename
        if dir.current_is_dir():
            # Skip plugin folder
            if full_path.find("addons/updater") == -1:
                walk_directory(full_path, files)
        else:
            for file_type in file_types:
                file_type = file_type.substr(1)
                if full_path.ends_with(file_type):
                    files.append(full_path)
        filename = dir.get_next()
    dir.list_dir_end()

func _on_upgrade_button_pressed():
    show_backup_warning()

func _on_test_button_pressed():
    # Instantiate the transformer
    transformer = Transformer.new()

    var file_dialog = EditorFileDialog.new()
    file_dialog.title = "Select a file"
    file_dialog.filters = file_types
    
    file_dialog.file_selected.connect(Callable(self, "start_iteration"))
    get_tree().get_root().add_child(file_dialog)
    file_dialog.popup_centered()

func start_iteration(path: String = ""):
    var file = FileAccess.open(path, FileAccess.READ)
    if file:
        iterate_transform(file)
    else:
        print("Could not open file: ", path)

func iterate_transform(file: FileAccess):
    file = FileAccess.open(file.get_path(), FileAccess.READ)
    if file:
        var result = (transformer.current_function + "() complete") if transformer.current_function != "" else "No Function Selected"
        var text = file.get_as_text()
        file.close()
        var new_text = transformer.apply_next_function(text)

        result = ("Last Function: " if transformer.iteration_complete else "") + result + "\n\n" + file.get_path()
        if new_text == "":
            result += "\n(File is empty)"

        write_to_file(file, new_text)

        # Show the result in a dialog
        var dialog = ConfirmationDialog.new()
        dialog.title = "Transformation Result"
        dialog.dialog_text = result
        dialog.get_ok_button().text = "Keep"
        dialog.get_cancel_button().text = "Revert"
        dialog.confirmed.connect(Callable(self, "_on_transformation_confirmed").bind(file))
        dialog.canceled.connect(Callable(self, "write_to_file").bind(file, text))
        get_tree().get_root().add_child(dialog)
        dialog.popup_centered()

func write_to_file(file: FileAccess, text: String):
    file = FileAccess.open(file.get_path(), FileAccess.WRITE)
    if file:
        file.store_string(text)
        file.close()
        print("File saved: ", file.get_path())
    else:
        print("Could not save file: ", file.get_path())

func _on_transformation_confirmed(file: FileAccess):
    if transformer.iteration_complete:
        # If the transformation is complete, reset the iteration
        transformer.reset_iteration()
    else:
        # Continue to the next transformation
        iterate_transform(file)