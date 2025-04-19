### correct_button.gd

@tool
extends Button

@onready var output_text_edit = $"../Input/CodeOutput/OutputTextEdit"
@onready var input_text_edit = $"../Input/InputTextEdit"

var replacements = {}
const Transformations = preload("res://addons/updater/updater_transformations.gd")

func _ready():
    load_replacements()

func load_replacements():
    var file = FileAccess.open("res://addons/updater/replacement_list.json", FileAccess.READ)
    if file:
        var data = file.get_as_text()
        var json_data = JSON.parse_string(data)
        if json_data:
            replacements = json_data
        else:
            print("Error parsing JSON: ", json_data)
        file.close()
    else:
        print("Failed to open JSON file.")

func _enter_tree():
    pressed.connect(_on_correction_button_pressed)

func apply_all_transformations(input_text):
    # Delegate transformation to the new script.
    var transformer = Transformations.new()
    return transformer.run_all_functions(input_text)

func _on_correction_button_pressed():
    var input_text = input_text_edit.text
    input_text = apply_all_transformations(input_text)
    call_deferred("update_output_text", input_text)

func update_output_text(updated_text):
    output_text_edit.text = updated_text
