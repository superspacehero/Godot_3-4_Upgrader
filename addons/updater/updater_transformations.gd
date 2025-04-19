@tool
extends Node
class_name UpdaterTransformations

var script_functions: Dictionary = {
    "script_set_indentation_to_tabs": false,
    "script_update_classname_icon": false,
    "script_add_at_to_keywords": false,
    "script_update_variable_syntax": true,
    "script_update_3d_syntax": false,
    "script_update_ui_syntax": false,
    "script_update_thread_syntax": false,
    "script_update_signal_syntax": false,
    "script_update_string_functions": false,
    "script_update_math_functions": false,
    "script_update_move_and_slide": false,
    "script_update_set_cell_syntax_with_guide": false,
    "script_update_cell_size_access": false,
    "script_update_tween_syntax": false,
    "script_update_color_syntax": false,
    "script_update_super_call_syntax": false,
    "script_update_json_syntax": false,
    "script_update_directory_access": false,
    "script_update_file_access": false,
    "script_update_immediate_geometry": false,
    "script_update_engine_changes": false,
    "script_update_os_changes": false,
    "script_other_replacements": false,
}

var scene_functions: Dictionary = {
    "scene_other_replacements": false,
}

var problematic_functions: Array = []
var current_file_functions: Dictionary
var current_index: int = 0
var regex: RegEx = RegEx.new()

var current_function: String:
    get:
        if current_index < current_file_functions.size():
            return current_file_functions.keys()[current_index]
        return ""

var iteration_complete: bool:
    get:
        return current_index >= current_file_functions.size()

# Helper function to list all the problematic functions
func list_problematic_functions() -> String:
    var result = ""
    for function in problematic_functions:
        result += function + "\n"
    return result

# Helper function to print debug information
func debug(message: String, is_error: bool = false):
    var debug_prepend = "\n[DEBUG] "
    var current_function_exists: bool = current_function.length() > 0
    if current_function_exists:
        debug_prepend += current_function + ": "
    if current_file_functions == null:
        push_error(debug_prepend + "current_file_functions is null")
    elif current_file_functions.size() == 0:
        push_error(debug_prepend + "current_file_functions not set")
    elif current_function_exists and not current_file_functions[current_function]:
        push_error(debug_prepend + current_function + " is not in current_file_functions")
    else:
        if current_file_functions[current_function]:
            message = debug_prepend + message
            if is_error:
                push_error(message)
            else:
                print_debug(message)

var file_functions = {
    r"\[gd_scene.*\]" = scene_functions,
    r".*" = script_functions,
}

# Helper function to determine what kind of file is being edited
func get_file_functions(text: String):
    current_file_functions = {}
    for file_regex in file_functions.keys():
        regex.compile(file_regex)
        var file_result = regex.search(text)
        if get_string(file_result, 0).length() > 0:
            current_file_functions.assign(file_functions[file_regex])
            break
    if current_file_functions.size() == 0:
        debug("Could not find functions for the given text", true)
        return false
    return true

# Helper function to run the transformations
func run_function(text: String, function_name: String) -> String:
    var transformed_text: String = call(function_name, text)
    if transformed_text.strip_edges().is_empty():
        # If the function returns an empty string, add it to the problematic function list
        if function_name not in problematic_functions:
            problematic_functions.append(function_name)
    return transformed_text

func run_next_function(text: String) -> String:
    if current_index >= current_file_functions.size():
        return text
    text = run_function(text, current_function)
    current_index += 1
    return text

func run_all_functions(text: String) -> String:
    reset_iteration(text)
    for i in range(current_file_functions.size()):
        text = run_next_function(text)
    return text

func reset_iteration(text: String):
    current_index = 0
    problematic_functions.clear()
    get_file_functions(text)

# Helper function to get the arguments of a function call
func regex_get_function(input: String, function: String, required_string: String = "", disallowed_string: String = "", additional_string: String = "") -> Array:
    var pattern: String = r"(?:(?s)(" + function + r")" + r"\s*((\()[^()]*?(?:[^()]*?(?2)[^()]*?)*?[^()]*?(\))))(?-s)" + additional_string
    var outputs: Array = []

    # Add required or disallowed strings using lookaheads
    if required_string.length() > 0:
        pattern = r"(?=.*" + required_string + r".*)" + pattern
    if disallowed_string.length() > 0:
        pattern = r"(?!.*" + disallowed_string + r".*)" + pattern

    # Apply the regex pattern to the input string
    regex.compile(pattern)
    var matches = regex.search_all(input)

    for match in matches:
        # Replace any line breaks with spaces
        regex.compile(r"\n")
        var condensed_match = regex.sub(get_whole_string(match), " ", true)
        # Re-run the regex to get the matches
        regex.compile(pattern)
        outputs.append(regex.search(condensed_match))

    if outputs.size() > 0:
        var printed_matches = ""
        for output: RegExMatch in outputs:
            printed_matches += "\n\t\t" + get_whole_string(output)
        debug("\n" + current_function + "\n\tregex pattern:\n\t\t" + pattern + "\n\toutput: " + printed_matches)

    return outputs

# Helper function to separate the arguments of a function call
func regex_separate_arguments(text: String) -> Array:
    regex.compile(r"(?!\s)([^,]+(?:\([^\)]*\))?)")
    var matches = regex.search_all(text)
    var printed_matches = ""
    for match in matches:
        printed_matches += "\n\t" + get_whole_string(match)
    if printed_matches.length() > 0:
        debug("Arguments: " + printed_matches)
    return matches

# Helper function to unquote a string
func regex_unquote_string(text: String) -> String:
    regex.compile(r"""(?:['"])(.*)(?:['"])""")
    text = regex.sub(text, "$1", true)
    return text

# Helper function to get the arguments of a function call
func get_arguments(match: RegExMatch) -> String:
    var arguments = get_string(match, 2)
    # Strip the leading and trailing parentheses
    if arguments.begins_with(get_string_from_last(match, 1)) and arguments.ends_with(get_string_from_last(match)):
        arguments = arguments.substr(1, arguments.length() - 2)
    return arguments

# Helper function to get the whole string in a RegexMatch
func get_whole_string(match: RegExMatch) -> String:
    return get_string(match, 0)

# Helper function to get the first string in a RegexMatch
func get_string(match: RegExMatch, index: int = 1) -> String:
    if index < 0:
        index = 0

    if match == null:
        debug("RegexMatch match is null", true)
        return ""

    var string = match.get_string(index)
    if string.length() > 0:
        var string_prefix = "String" if index > 0 else "Whole String"
        debug(string_prefix + ":\n" + string)
    return string

# Helper function to get the last string in a RegexMatch
func get_string_from_last(match: RegExMatch, offset: int = 0) -> String:
    var index = match.strings.size() - (1 + offset)
    if index <= 0:
        return ""
    return get_string(match, index)

# Helper function for adding a Callable to a function
func add_callable_to_function(args: Array, bind = true) -> String:
    var new_args = ""
    for i in range(args.size()):
        match i:
            0:
                # First argument is the target - wrap the target in a Callable
                new_args += "Callable(" + get_whole_string(args[i]) + ")"
            1:
                # Second argument is the function name - insert it into the Callable after the target
                new_args = new_args.insert(new_args.length() - 1, ", " + get_whole_string(args[i]))
            2:
                # Third argument is the arguments - bind them to the Callable
                if bind:
                    new_args += ".bind(" + get_whole_string(args[i]) + ")"
                else:
                    # If bind is false, just add the arguments as is
                    new_args += ", " + get_whole_string(args[i])
            _:
                # Any other arguments are just added as is
                new_args += ", " + get_whole_string(args[i])
    debug("Callable arguments: (" + new_args + ")")
    return new_args

# ======
# Script Transformations
# ======

# Helper function to get the indentation from a string (usually a line)
func get_indent(line: String) -> String:
    regex.compile(r"^(\s*)")
    var match = regex.search(line)
    if match:
        return get_string(match)
    return ""

func script_set_indentation_to_tabs(text: String) -> String:
    # Replace leading spaces with a tab
    regex.compile(r"^(\s+)")
    text = regex.sub(text, "\t", true)
    # Remove trailing spaces
    regex.compile(r"\s+$")
    text = regex.sub(text, "", true)
    return text

func script_update_classname_icon(text: String) -> String:
    # Matches: class_name MyClass, "res://path/to/optional/icon.svg"
    regex.compile(r"(?s)(?![^@icon])(?:(.*)(class_name\s+\w+)\s*,\s*(\".*\"))")
    regex.sub(text, "@icon($3)\n\n$2\n\n$1", true)
    return text

func script_add_at_to_keywords(text: String) -> String:
    var keywords = ["onready", "tool"]
    for keyword in keywords:
        # Replace keyword with @keyword if not already prefixed by @
        regex.compile(r"(?<!@)\b%s\b" % keyword)
        text = regex.sub(text, "@%s" % keyword, true)

    return text

func script_update_variable_syntax(text: String) -> String:
    # Handle int/float (e.g., export(float, 0, 1, 0.1) var my_var:float = initial_value)
    var regex_matches = regex_get_function(text, "export", "", "", r"\s*(.*)")
    var replacement = ""
    for regex_match in regex_matches:
        # Separate the arguments
        var export_args = regex_separate_arguments(get_arguments(regex_match))
        var line = get_whole_string(regex_match)

        replacement = get_string(regex_match)

        if export_args.size() > 0:
            line = get_whole_string(regex_match)
            var type = get_string(export_args[0])

            match type:
                "int", "float":
                    match export_args.size() - 1:
                        0:
                            # No arguments, just make it a normal export
                            pass
                        1:
                            # Only one argument - a maximum value
                            replacement += "_range(0, " + get_whole_string(export_args[1]) + ")"
                        2:
                            # Two arguments - a minimum and maximum value
                            replacement += "_range(" + get_whole_string(export_args[1]) + ", " + get_whole_string(export_args[2]) + ")"
                        _:
                            # Three arguments (if more, we're just using the first three) - a minimum, maximum, and step value
                            replacement += "_range(" + get_whole_string(export_args[1]) + ", " + get_whole_string(export_args[2]) + ", " + get_whole_string(export_args[3]) + ")"
                "String":
                    #
                    if export_args.size() == 1:
                        # Only one argument - the type
                        pass
                    else:
                        replacement += "_enum("
                        for i in range(1, export_args.size()):
                            replacement += get_whole_string(export_args[i]) + (", " if i < export_args.size() - 1 else "")
                        replacement += ")"
                _:
                    # Export types that either are unhandled or just don't need modification
                    pass

            # Add the actual variable declaration
            regex.compile(r"(var)\s+(\w+)(?:(?:\s*(:?)\s*(\w*)\s*)?(=?)\s*(.*)\s?)")
            var variable_match = regex.search(get_string_from_last(regex_match))
            if variable_match:
                var has_type = get_string(variable_match, 4).length() > 0
                for i in range(1, variable_match.strings.size()):
                    match i:
                        3:
                            # Add the type
                            replacement += " :"
                        4:
                            # Add the type, either from the export or the existing type
                            replacement += " " + (get_string(variable_match, i) if has_type else type)
                        _:
                            replacement += " " + get_string(variable_match, i)

        text = text.replace(line, replacement)

    # Add @ to export (as well as any of its converted variants) if not already present
    regex.compile(r"(?<!@)\b(export\S*)")
    text = regex.sub(text, "@$1", true)

    # Convert setget syntax to the new format for both export and non-export variables, including multi-line declarations.
    # This regex matches lines (even with multi-line variable declarations) like:
    #   var my_var := initial_value setget setter, getter
    #   var my_var := initial_value setget setter
    #   var my_var := initial_value setget , getter
    #   var my_dict := {
    #       "var_1" : true,
    #       "var_2" : true,
    #   } setget setter , getter
    regex.compile(r"(?ms)^(\s*(?:@[\w\(\)\",\s]+)?var\s+\w+(?:\s*:\s*\w+)?(?:\s*(?::=|=)\s*.+?)?)\s+setget\s*([^,\s]*)\s*(?:,\s*([^\s]+))?\s*$")
    if not regex.is_valid():
        debug("Regex pattern is not valid. Ensure regex.compile() was successful.", true)
        return text
    regex_matches = regex.search_all(text)
    for regex_match in regex_matches:
        var original_decl = get_string(regex_match).rstrip(" \t\r\n")
        var setter = get_string(regex_match, 2)
        var getter = get_string(regex_match, 3)
        replacement = ""
        if setter.length() > 0 and getter.length() > 0 and getter != null:
            replacement = original_decl + ":\n" + "\t" + "set(value):\n" + "\t\t" + setter + "(value)\n" + "\t" + "get:\n" + "\t\t" + "return " + getter + "()"
        elif setter.length() > 0:
            replacement = original_decl + ":\n" + "\t" + "set(value):\n" + "\t\t" + setter + "(value)"
        elif getter.length() > 0 and getter != null:
            replacement = original_decl + ":\n" + "\t" + "get:\n" + "\t\t" + "return " + getter + "()"
        else:
            replacement = original_decl
        text = text.replace(get_whole_string(regex_match), replacement)

    # Warn if duplicate variable names are found in the same function or class scope.
    # This does NOT rename variables, but highlights potential conflicts.
    # You can extend this to rename if needed, but renaming can be risky and is best handled with a full parser.

    var variable_scopes = {}
    var current_scope = "_class"
    variable_scopes[current_scope] = []

    var lines = text.split("\n")
    for i in range(lines.size()):
        var line = lines[i].strip_edges()
        if line.begins_with("func "):
            # Extract function name
            var func_name = line.split(" ")[1].split("(")[0]
            current_scope = func_name
            if not variable_scopes.has(current_scope):
                variable_scopes[current_scope] = []
        elif line.begins_with("var ") or line.begins_with("for "):
            # Extract variable name
            var tokens = line.split(" ")
            if tokens.size() > 1:
                var var_name = tokens[1].split(":")[0].split("=")[0].strip_edges()
                if var_name in variable_scopes[current_scope]:
                    debug("Duplicate variable name '%s' found in scope '%s'" % [var_name, current_scope], true)
                else:
                    variable_scopes[current_scope].append(var_name)
        elif line == "" or line.begins_with("#"):
            continue

    return text

# Transformation for 3D syntax
func script_update_3d_syntax(text: String) -> String:
    # Replace "Transform" with "Transform3D"
    regex.compile(r"\bTransform\b")
    text = regex.sub(text, "Transform3D", true)

    # Replace "Spatial" with "Node3D"
    regex.compile(r"\bSpatial\b")
    text = regex.sub(text, "Node3D", true)

    # Replace "KinematicBody" with "CharacterBody"
    regex.compile(r"KinematicBody")
    text = regex.sub(text, "CharacterBody", true)

    # Replace "RayCast" with "RayCast3D"
    regex.compile(r"\bRayCast\b")
    text = regex.sub(text, "RayCast3D", true)

    # Replace "SpotLight" with "SpotLight3D"
    regex.compile(r"\bSpotLight\b")
    text = regex.sub(text, "SpotLight3D", true)

    # Replace "translation" with "position"
    regex.compile(r"translation")
    text = regex.sub(text, "position", true)

    # Replace "tween_with" with "interpolate_with"
    regex.compile(r"\btween_with\b")
    text = regex.sub(text, "interpolate_with", true)

    # Replace "Camera" with "Camera3D"
    regex.compile(r"\bCamera\b")
    text = regex.sub(text, "Camera3D", true)

    # Replace "Area" with "Area3D"
    regex.compile(r"\bArea\b")    
    text = regex.sub(text, "Area3D", true)

    # Replace "StaticBody" with "StaticBody3D"
    regex.compile(r"\bStaticBody\b")    
    text = regex.sub(text, "StaticBody", true)

    # Replace "MeshInstance" with "MeshInstance3D"
    regex.compile(r"\bMeshInstance\b")
    text = regex.sub(text, "MeshInstance3D", true)

    # Replace "SpatialMaterial" with "StandardMaterial3D"
    regex.compile(r"\bSpatialMaterial\b")
    text = regex.sub(text, "StandardMaterial3D", true)

    # Replace "PanoramaSky" with "PanoramaSkyMaterial"
    regex.compile(r"\bPanoramaSky\b")
    text = regex.sub(text, "PanoramaSkyMaterial", true)

    return text

# Transformation for UI syntax
func script_update_ui_syntax(text: String) -> String:
    # Replace "pressed" with "button_pressed" when "pressed" is not being used as a signal
    regex.compile(r"\.(?:button_)*pressed(.*)")
    for match in regex.search_all(text):
        var match_value = get_string_from_last(match)
        if match_value.contains("connect") or match_value.contains("emit_signal"):
            continue
        # Replace "pressed" with "button_pressed"
        text = text.replace(get_whole_string(match), ".button_pressed" + match_value)

    # Replace "TextureProgress" with "TextureProgressBar
    regex.compile(r"\bTextureProgress\b")
    text = regex.sub(text, "TextureProgressBar", true)

    # Replace "bbcode_text" with "text"
    regex.compile(r"\bbbcode_text\b")
    text = regex.sub(text, "text", true)

    return text

func script_update_thread_syntax(text: String) -> String:
    # Replace thread.start(target, function, args, priority) with thread.start(Callable(target, function).bind(args), priority)
    var thread_starts = regex_get_function(text, "start", "", "Callable")
    for start in thread_starts:
        # Separate the arguments
        var args = get_arguments(start)
        if args == "":
            continue

        args = regex_separate_arguments(args)

        var replacement = get_string(start) + get_string_from_last(start, 1) + add_callable_to_function(args) + get_string_from_last(start)

        # Replace the original thread.start with the new Callable format
        text = text.replace(get_whole_string(start), replacement)

    return text

func script_update_signal_syntax(text: String) -> String:
    # Move the signal name to the start of the connect call
    var signals = regex_get_function(text, "connect", "", "Callable")
    for listed_signal in signals:
        var replacement = get_string(listed_signal) + get_string_from_last(listed_signal, 1)

        # Separate the arguments
        var args = regex_separate_arguments(get_arguments(listed_signal))

        # First argument is the signal - unquote it and prepend it to the .connect
        var signal_name = regex_unquote_string(get_whole_string(args[0])) + "."
        replacement = signal_name + replacement
        args.pop_front()

        # Add the rest of the arguments
        replacement += add_callable_to_function(args) + get_string_from_last(listed_signal)

        # Replace the original signal.connect with the new Callable format
        text = text.replace(get_whole_string(listed_signal), replacement)

    # Move the signal name to the start of the emit_signal call
    signals = regex_get_function(text, "emit_signal")
    for listed_signal in signals:
        var replacement = get_string(listed_signal)

        # Separate the arguments
        var args = regex_separate_arguments(get_arguments(listed_signal))
        for i in range(args.size()):
            match i:
                0:
                    # First argument is the signal - unquote it and prepend it to the .connect
                    var signal_name = regex_unquote_string(get_whole_string(args[i]))

                    replacement = signal_name + "." + replacement + get_string_from_last(listed_signal, 1)
                _:
                    if i > 1:
                        replacement += ", "
                    # Any other arguments are just added as is
                    replacement += get_whole_string(args[i])

        replacement += get_string_from_last(listed_signal)

        # Replace the original emit_signal with the new signal.emit format
        text = text.replace(get_whole_string(listed_signal), replacement)

    # Replace yield with await
    var yields = regex_get_function(text, "yield")
    for found_yield in yields:
        # Separate the arguments
        var args = regex_separate_arguments(get_arguments(found_yield))

        var replacement = get_string(found_yield) + " "

        for i in range(args.size()):
            match i:
                0:
                    # First argument is the target - add it to the replacement if it's not just "self"
                    if get_whole_string(args[i]) != "self":
                        replacement += get_whole_string(args[i]) + "."
                1:
                    # Second argument is the function name - unquote it and add it after the target
                    replacement += regex_unquote_string(get_whole_string(args[i]))

        # Replace the original yield with the new await format
        text = text.replace(get_whole_string(found_yield), replacement)

    # Replace yield with await
    regex.compile(r"\byield\b")
    text = regex.sub(text, "await", true)

    # Replace "idle_frame" with "process_frame"
    regex.compile(r"\bidle_frame\b")
    text = regex.sub(text, "process_frame", true)

    # Replace "emit_signal" with "emit"
    regex.compile(r"\bemit_signal\b")
    text = regex.sub(text, "emit", true)

    return text

func script_update_string_functions(text: String) -> String:
    # Replace <array_expr>.join(<sep>) with <sep>.join(<array_expr>)
    regex.compile(r"(PoolStringArray)(?:\s|%)*(.*)(\.join\s*)\(([^\)]*)(?:\)?)")
    text = regex.sub(text, "$4$3($1$2)", true)
    return text

func script_update_math_functions(text: String) -> String:
    # Remove ":" from ":=" variable declarations
    regex.compile(":=")
    text = regex.sub(text, "=", true)

    # Replace "rand_range" with "randf_range"
    regex.compile(r"\brand_range\b")
    text = regex.sub(text, "randf_range", true)
    return text

func script_update_move_and_slide(text: String) -> String:
    regex.compile(r"move_and_slide\s*\(.*\)")
    text = regex.sub(text, "move_and_slide()", true)
    regex.compile(r"\w+\s*=\s*move_and_slide\(\s*\)")
    text = regex.sub(text, "move_and_slide()")
    regex.compile(r"\w+\.\w+\s*=\s*move_and_slide\([^)]+\)\.\w+")
    text = regex.sub(text, "move_and_slide()")
    return text

func script_update_set_cell_syntax_with_guide(text: String) -> String:
    var guide_text = "set_cell()\n# Please replace this set_cell/set_cell_v call with the new format:\n# set_cell(layer, Vector2i(x, y), source_id, atlas_coords, alternative_tile)\n# Example: set_cell(0, Vector2i(10, 20), -1, Vector2i(-1, -1), 0)"
    regex.compile(r"set_cell\s*\([^)]*\)")
    text = regex.sub(text, guide_text, true)
    regex.compile(r"set_cell_v\s*\([^)]*\)")
    text = regex.sub(text, guide_text, true)
    return text

# Transformation for cell_size access
func script_update_cell_size_access(text: String) -> String:
    regex.compile(r"(\s*)\.cell_size")
    var replacement_text = "$1.tile_set.tile_size"
    text = regex.sub(text, replacement_text, true)
    return text

# Transformation for Tween instantiation
func script_update_tween_syntax(text: String) -> String:
    var tween_variable = r"\S*tween\S*"

    # Remove assignment of Tween variables to Nodes
    regex.compile(r"(@?onready\s)?(?:((?:var)?\s*\w+\s*:\s*Tween)(?:\s*=\s*(?:\$.+)|(?:.*node.*))?)")
    text = regex.sub(text, "$2", true)

    # Replace any assignment of Tween.new() with create_tween()
    regex.compile(r"\bTween\.new\b")
    text = regex.sub(text, "create_tween", true)

    # Replace tween_all_completed with finished
    regex.compile(r"\btween_all_completed\b")
    text = regex.sub(text, "finished", true)

    var not_tween_functions = {
        "tween_with" = "interpolate_with",
    }

    # Replace interpolate_property with tween_property and update arguments
    var tweens = regex_get_function(text, r"\binterpolate_\w+\b")
    for tween in tweens:
        var replacement = get_string(tween) + get_string_from_last(tween, 1)
        var replacement_append = ""

        # Separate the arguments
        var args = regex_separate_arguments(get_arguments(tween))
        var initial_value_index: int = -1

        # Initial values aren't used in interpolate_property anymore - remove it
        if get_string(tween) == "interpolate_property":
            initial_value_index = 2

        if initial_value_index >= 0:
            args.remove_at(initial_value_index)

        regex.compile(r"Tween\.(?:(TRANS)|(EASE))_\w+")
        # Move the transition/ease types into the set_trans() and set_ease() functions
        for i in range(args.size()):
            var arg = regex.search(get_whole_string(args[args.size() - 1]))
            if arg:
                # If the argument is a transition or ease type, remove it from the arguments
                args.pop_back()
                # Add it to the replacement string
                replacement_append += "."
                if get_string(arg, 1).length() > 0:
                    replacement_append += "set_trans"
                if get_string(arg, 2).length() > 0:
                    replacement_append += "set_ease"
                replacement_append += "(" + get_whole_string(arg) + ")"
                i -= 1

        match get_string(tween):
            "interpolate_property":
                for i in range(args.size()):
                    match i:
                        0:
                            # First argument is the target
                            replacement += regex_unquote_string(get_whole_string(args[i]))
                        _:
                            # Any other arguments are just added as is
                            replacement += ", " + get_whole_string(args[i])
            "interpolate_method":
                replacement += add_callable_to_function(args, false)
            _:
                debug("Unaccounted for tween type: " + get_string(tween), true)
                replacement += get_arguments(tween)

        replacement += get_string_from_last(tween) + replacement_append

        text = text.replace(get_whole_string(tween), replacement)

    # Replace any interpolate_<type> calls with tween_<type> calls
    regex.compile(r"\binterpolate_(\w+)\b")
    text = regex.sub(text, "tween_$1", true)

    # Do another pass for any non-tween functions and set those to the appropriate function
    regex.compile(r"\btween_\w+\b")
    var tween_matches = regex.search_all(text)
    for tween_match in tween_matches:
        # If the match is not a tween type, replace it with the appropriate function
        var tween_type = get_whole_string(tween_match)
        if tween_type in not_tween_functions.keys():
            text = text.replace(tween_type, not_tween_functions[tween_type])

    # Remove any <tween_var>.start()
    regex.compile(r"\n?\s*" + tween_variable + r"\.start\(\)")
    text = regex.sub(text, "", true)

    # Remove any add_child(<tween_var>)
    regex.compile(r"\n?\s*add_child\(\s*" + tween_variable + r"\s*\)")
    text = regex.sub(text, "", true)

    return text

# Transformation for Color syntax
func script_update_color_syntax(text: String) -> String:
    var colors = r"alice|almond|antique|aqua|aquamarine|azure|beige|bisque|black|blanched|blue|blush|brown|burlywood|cadet|chartreuse|chiffon|chocolate|coral|cornflower|cornsilk|cream|crimson|cyan|dark|deep|dim|dodger|drab|firebrick|floral|forest|fuchsia|gainsboro|ghost|gold|goldenrod|gray|green|honeydew|hot|indian|indigo|ivory|khaki|lace|lavender|lawn|lemon|light|lime|linen|magenta|maroon|medium|midnight|mint|misty|moccasin|navajo|navy|old|olive|orange|orchid|pale|papaya|peach|peru|pink|plum|powder|puff|purple|rebecca|red|rose|rosy|royal|saddle|salmon|sandy|seashell|sea|sienna|silver|sky|slate|smoke|snow|spring|steel|tan|teal|thistle|tomato|transparent|turquoise|violet|web|wheat|whip|white|yellow"

    regex.compile(r"(?<=Color\.)(?:" + colors + r")+")
    var color_matches = regex.search_all(text)

    if color_matches.size() == 0:
        return text

    for color_match in color_matches:
        regex.compile(r"(" + colors + r")")
        var color_names = regex.search_all(get_whole_string(color_match))
        var final_color = ""
        for i in range(color_names.size()):
            # Put the color name in all caps.
            final_color += get_whole_string(color_names[i]).to_upper()
            # If it's not the last color in the match, add an underscore
            if i < color_names.size() - 1:
                final_color += "_"
        # Replace the original color name with the new one
        text = text.replace(get_whole_string(color_match), final_color)

    return text

# Transformation for super call syntax
func script_update_super_call_syntax(text: String) -> String:
    # Matches a line where a dot is followed by a function name, with only whitespace before the dot (no variable/class)
    # and not already "super."
    regex.compile(r"(^|\s)\.(\w+)\s*\(")
    text = regex.sub(text, "$1super.$2(", true)
    return text

# Transformation for JSON syntax
func script_update_json_syntax(text: String) -> String:
    # Replace JSON.parse with JSON.parse_string
    regex.compile(r"\bJSON\.parse\b")
    text = regex.sub(text, "JSON.parse_string", true)

    # Update JSON.print to JSON.stringify
    regex.compile(r"\bJSON\.print\b")
    text = regex.sub(text, "JSON.stringify", true)

    return text

# Transformation for Directory -> DirAccess migration
func script_update_directory_access(text: String) -> String:
    # Replace "var dir = Directory.new(" followed by "if dir.open(...) ..." with "var dir = DirAccess.open(..." and "if dir ..."
    regex.compile(r"(?m)^(\s*)var\s+(\w+)\s*=\s*Directory\.new\s*\(\s*\)\s*\n(\s*)if\s+\2\.open\(([^)]+)\)([^\n]*)")
    var matches = regex.search_all(text)
    for match in matches:
        var var_indent = get_indent(get_whole_string(match))
        var var_name = get_string(match, 2)
        var if_indent = get_string(match, 3)
        var open_arg = get_string(match, 4)
        var after_open = get_string(match, 5)
        var replacement = "%svar %s = DirAccess.open(%s)\n%sif %s%s" % [var_indent, var_name, open_arg, if_indent, var_name, after_open]
        text = text.replace(get_whole_string(match), replacement)

    # Replace any remaining "Directory" with "DirAccess"
    regex.compile(r"\bDirectory\b")
    text = regex.sub(text, "DirAccess", true)

    return text

# Transformation for File -> FileAccess migration
func script_update_file_access(text: String) -> String:
    # Remove "File.new()" variable assignments
    regex.compile(r"(?:(\s*var\s+(\S+)\s*=\s*)(?:File\.new\s*\(\s*\)))(?:(\n*\s*.*\2)(\.open\(.*\)))?")
    var matches = regex.search_all(text)
    for match in matches:
        var replacement = ""
        var open_function = get_string(match, 4)
        if open_function.length() > 0:
            replacement = regex.sub(get_whole_string(match), "$1File$4$3", true)
        text = text.replace(get_whole_string(match), replacement)

    # Replace "File" variables calling "file_exists"
    regex.compile(r"(?<=\s)(?:\S*(\.file_exists.*))")
    text = regex.sub(text, r"File$1", true)

    # Replace any "File" with "FileAccess"
    regex.compile(r"\bFile\b")
    text = regex.sub(text, "FileAccess", true)

    return text

# Transformation for ImmediateGeometry-related changes
func script_update_immediate_geometry(text: String, original_text: String = "") -> String:
    # Check if the original text extends ImmediateGeometry
    var extends_immediate_geometry = false
    regex.compile(r"^\s*extends\s+ImmediateGeometry\b")
    if original_text == "":
        original_text = text
    if regex.search(original_text):
        extends_immediate_geometry = true

    # Replace "ImmediateGeometry" node with "MeshInstance3D" and add a comment only if nothing follows
    regex.compile(r"\bImmediateGeometry\b(?!.)+")
    text = regex.sub(text, "MeshInstance3D # NOTE: Use ImmediateMesh as the mesh resource. See Godot 4 docs/examples.", true)
    # Replace "ImmediateGeometry" with "MeshInstance3D" (no comment) if followed by something else (e.g. in quotes, plugin configs, etc.)
    regex.compile(r"\bImmediateGeometry\b")
    text = regex.sub(text, "MeshInstance3D", true)

    # Replace "extends ImmediateGeometry" with "extends MeshInstance3D" and add a comment
    regex.compile(r"extends\s+ImmediateGeometry")
    text = regex.sub(text, "extends MeshInstance3D # NOTE: ImmediateGeometry is removed in Godot 4. Use ImmediateMesh as mesh resource.", true)

    # Add a comment at the top if ImmediateGeometry was used
    if text.find("MeshInstance3D # NOTE: Use ImmediateMesh as the mesh resource.") != -1:
        var comment = "# Godot 4: ImmediateGeometry is removed. Use MeshInstance3D with an ImmediateMesh resource.\n"
        if not text.begins_with(comment):
            text = comment + text

    # Map of ImmediateGeometry methods to ImmediateMesh equivalents
    var method_map = {
        "add_vertex": "surface_add_vertex",
        "begin": "surface_begin",
        "end": "surface_end",
        "clear": "clear_surfaces",
        "set_color": "surface_set_color",
        "set_normal": "surface_set_normal",
        "set_tangent": "surface_set_tangent",
        "set_uv2": "surface_set_uv2",
        "set_uv": "surface_set_uv",
    }

    # Replace method calls on mesh or self (after user migration)
    for old_method in method_map.keys():
        var new_method = method_map[old_method]
        # Replace calls like mesh.add_vertex(...), self.add_vertex(...)
        regex.compile(r"(\bmesh\b|\bself\b|\$[\w\/]+)\." + old_method + r"\s*\(")
        text = regex.sub(text, "$1." + new_method + "(", true)
        # Replace direct calls (add_vertex(...)) with mesh.surface_add_vertex(...)
        regex.compile(r"(?<!\.)\b" + old_method + r"\s*\(")
        text = regex.sub(text, "mesh." + new_method + "(", true)

    # Remove add_sphere, as ImmediateMesh does not have this helper
    regex.compile(r"(\bmesh\b|\bself\b|\$[\w\/]+)\.add_sphere\s*\([^\)]*\)")
    text = regex.sub(text, "# [REMOVED: add_sphere is not available in ImmediateMesh. Implement manually if needed.]", true)
    regex.compile(r"(?<!\.)\badd_sphere\s*\([^\)]*\)")
    text = regex.sub(text, "# [REMOVED: add_sphere is not available in ImmediateMesh. Implement manually if needed.]", true)

    # Only add _ready setup code if the original class extended ImmediateGeometry
    if extends_immediate_geometry:
        # Setup or update the _ready function with ImmediateMesh setup code
        regex.compile(r"func\s+_ready\s*\(\s*\)\s*:(?:\s*\w+)?\s*\n")
        var ready_match = regex.search(text)
        var setup_code = (
            "\tmesh = ImmediateMesh.new()\n" +
            "\tvar mat = StandardMaterial3D.new()\n" +
            "\tmat.no_depth_test = true\n" +
            "\tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED\n" +
            "\tmat.vertex_color_use_as_albedo = true\n" +
            "\tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA\n" +
            "\tmesh.surface_set_material(0, mat)\n" +
            "\tset_material_override(mat)\n"
        )
        if text.find("MeshInstance3D # NOTE: Use ImmediateMesh as the mesh resource.") != -1:
            if ready_match:
                # _ready exists, insert setup code if not present
                var ready_start = ready_match.get_start()
                var ready_end = ready_match.get_end()
                # Find the body of _ready
                var body_indent = "\t"
                regex.compile(r"func\s+_ready\s*\(\s*\)\s*:(?:\s*\w+)?\s*\n((?:\t[^\n]*\n?)*)")
                var body_match = regex.search(text)
                if body_match:
                    var body = get_string(body_match)
                    if body.find("mesh = ImmediateMesh.new()") == -1:
                        # Insert setup code at the start of the body
                        var new_body = setup_code + body
                        text = text.replace(body, new_body)
                else:
                    # _ready exists but body not found, append setup code after signature
                    text = text.insert(ready_end, setup_code)
            else:
                # _ready does not exist, add it at the top after class declaration
                regex.compile(r"(class_name\s+\w+[^\n]*\n)")
                var class_decl_match = regex.search(text)
                var insert_pos = 0
                if class_decl_match:
                    insert_pos = class_decl_match.get_end()
                text = text.insert(insert_pos, "\nfunc _ready():\n" + setup_code + "\n")

    return text

# Transformation for Engine-related changes
func script_update_engine_changes(text: String) -> String:
    # Replace "Engine.editor_hint" with "Engine.is_editor_hint"
    regex.compile(r"\bEngine\.editor_hint\b")
    text = regex.sub(text, "Engine.is_editor_hint", true)

    return text

# Transformation for OS-related changes
func script_update_os_changes(text: String) -> String:
    # Replace "OS.center_window()"
    regex.compile(r"\bOS\.center_window\s*\(\s*\)")
    text = regex.sub(text, "get_window().position = DisplayServer.screen_get_usable_rect(get_window().current_screen).position + (DisplayServer.screen_get_usable_rect(get_window().current_screen).size / 2 - get_window().get_size_with_decorations() / 2)", true)

    # Replace "OS.set_window_always_on_top(bool)" with "get_window().always_on_top = bool"
    regex.compile(r"OS\.set_window_always_on_top\s*\(\s*([^)]+)\s*\)")
    text = regex.sub(text, "get_window().always_on_top = $1", true)

    # Update the syntax of "OS.execute"
    # Remove the blocking variable from OS.execute(cmd, params, blocking, output, ...)
    var execute_matches = regex_get_function(text, "OS.execute")
    for match in execute_matches:
        var replacement = get_string(match) + get_string_from_last(match, 1)
        var args = regex_separate_arguments(get_arguments(match))

        for i in range(args.size()):
            match i:
                0:
                    # First argument is the command
                    replacement += get_whole_string(args[i])
                1:
                    # Second argument is the parameters - wrap them in a PackedStringArray
                    replacement += ", PackedStringArray(" + get_whole_string(args[i]) + ")"
                2:
                    # If third argument is a boolean, it's the blocking flag - skip it
                    if get_whole_string(args[i]) != "true" and get_whole_string(args[i]) != "false":
                        replacement += ", " + get_whole_string(args[i])
                _:
                    # Any other arguments are just added as is
                    replacement += ", " + get_whole_string(args[i])

        replacement += get_string_from_last(match)

        # Replace the original OS.execute with the new format
        text = text.replace(get_whole_string(match), replacement)

    return text

# Transformation for more straightforward replacements
func script_other_replacements(text: String) -> String:
    # Replace "ResourceInteractiveLoader" with "ResourceLoader"
    regex.compile(r"\bResourceInteractiveLoader\b")
    text = regex.sub(text, "ResourceLoader", true)

    # Replace "instance()" with "instantiate()"
    regex.compile(r"\binstance\s*\(\s*\)")
    text = regex.sub(text, "instantiate()", true)

    # Replace "Pool<Type>Array" with "Packed<Type>Array"
    regex.compile(r"\bPool(\w+)Array\b")
    text = regex.sub(text, "Packed$1Array", true)

    # Replace "set_as_toplevel" with "set_as_top_level"
    regex.compile(r"\bset_as_toplevel\b")
    text = regex.sub(text, "set_as_top_level", true)

    # Replace "scene_tree" with "get_tree()"
    regex.compile(r"\bscene_tree\b")
    text = regex.sub(text, "get_tree()", true)

    # Replace "array.invert()" with "array.reverse()"
    regex.compile(r"(\w+)\.invert\(\)")
    text = regex.sub(text, "$1.reverse()", true)

    # Replace "CONNECT_ONESHOT" with "CONNECT_ONE_SHOT"
    regex.compile(r"\bCONNECT_ONESHOT\b")
    text = regex.sub(text, "CONNECT_ONE_SHOT", true)

    # Replace "oggstr" with "ogg"
    regex.compile(r"\boggstr\b")
    text = regex.sub(text, "ogg", true)

    return text

# ======
# Scene Transformations
# ======
func scene_other_replacements(text: String) -> String:
    # Remove Tween nodes
    regex.compile(r"(?:\s*\n)*\[.*type=\"Tween\".*\]")
    text = regex.sub(text, "", true)

    return text