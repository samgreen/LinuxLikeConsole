"""
- contains a list of commands (Commands.gd)
"""
tool
extends Control

class_name Console

# Signals
signal on_message_sent
signal on_command_sent

# types
const Command = preload("res://console/command.gd")
const CommandRef = preload("res://console/command_ref.gd")

#var logFile = preload("res://Log.gd").new()

onready var lineEdit = $offset/lineEdit
onready var textLabel = $offset/richTextLabel
onready var animation = $offset/animation

#var allText = ""
var messageHistory := ""
var messages := []
var currentIndex := -1
var resetSwitch := true

export(String) var COMMAND_SIGN := "/"
var commands := []

var isShown := true

export(String) var next_message_history = "ui_down"
export(String) var previous_message_history = "ui_up"
export(String) var autoComplete = "ui_focus_next"
export(bool) var showButton = false setget update_visibility_button
export(String) var userMessageSign = ">" setget update_lineEdit
const toggleConsole = KEY_QUOTELEFT

func update_lineEdit(text : String):
	userMessageSign = text
	if has_node("offset/lineEdit") and $offset/lineEdit != null:
		$offset/lineEdit.set_placeholder(text)
		

func update_visibility_button(show):
	showButton = show
	if has_node("offset/send") and $offset/send != null:
		$offset/send.visible = show
	if has_node("offset/richTextLabel") and $offset/richTextLabel != null:
		if show:
			$offset/richTextLabel.margin_bottom = -19
			$offset/lineEdit.margin_right = -66
		else:
			$offset/richTextLabel.margin_bottom = -19
			$offset/lineEdit.margin_right = -5


#export(String) var logFileName = "logs/log.txt"

func _init():
	print("init")
	set_process_input(true)
	add_basic_commands()
	
func add_basic_commands():
	var exitRef = CommandRef.new(self, "exit", CommandRef.COMMAND_REF_TYPE.FUNC, 0)
	var exitCommand = Command.new('exit',  exitRef, [], 'Closes the console.')
	add_command(exitCommand)
	
	var clearRef = CommandRef.new(self, "clear", CommandRef.COMMAND_REF_TYPE.FUNC, 0)
	var clearCommand = Command.new('clear', clearRef, [], 'Clears the console.')
	add_command(clearCommand)
	
	var manRef = CommandRef.new(self, "man", CommandRef.COMMAND_REF_TYPE.FUNC, 1)
	var manCommand = Command.new('man', manRef, [], 'shows command description.')
	add_command(manCommand)
	
	var helpRef = CommandRef.new(self, "help", CommandRef.COMMAND_REF_TYPE.FUNC, 0)
	var helpCommand = Command.new('help', helpRef, [], 'shows all commands.')
	add_command(helpCommand)
	

func _input(event):
	if event is InputEventKey and event.scancode == toggleConsole and event.is_pressed() and not event.is_echo():
		toggle_console()
	
	# left or right mouse button pressed
	# test if really needed
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT or event.button_index == BUTTON_RIGHT:
			if event.position.x < get_position().x or event.position.y < get_position().y \
					or event.position.x > get_position().x + get_size().x or event.position.y > get_position().y + get_size().y:
				lineEdit.focus_mode = FOCUS_NONE
			else:
				lineEdit.focus_mode = FOCUS_CLICK
	
	if Input.is_key_pressed(KEY_ENTER):
		if not lineEdit.text.empty():
			var tmp = lineEdit.text
			send_message_without_event("\n" + userMessageSign + " ", false, false)
			send_message(tmp)
		
			
	elif event.is_action_pressed(previous_message_history):
		if resetSwitch:
			messages.append(lineEdit.text)
			resetSwitch = false
		currentIndex -= 1
		if currentIndex < 0:
			currentIndex = messages.size() - 1
		lineEdit.text = messages[currentIndex]
		
	elif event.is_action_pressed(next_message_history):
		if resetSwitch:
			messages.append(lineEdit.text)
			resetSwitch = false
		currentIndex += 1
		if currentIndex > messages.size() - 1:
			currentIndex = 0
		lineEdit.text = messages[currentIndex]
		
	if event.is_action_pressed(autoComplete):
		var closests = get_closest_commands(lineEdit.text)
		print(closests)
		if  closests != null:
			if closests.size() == 1:
				lineEdit.text = COMMAND_SIGN + closests[0]
				lineEdit.set_cursor_position(lineEdit.text.length())
			elif closests.size() > 1:
				var tempLine = lineEdit.text
				send_message_without_event("possible commands: ")
				for c in closests:
					send_message_without_event(COMMAND_SIGN + c, true)
					messages.append(COMMAND_SIGN + c)
				#send_message_without_event("Press [Up] or [Down] to cycle through available commands.", false)
				lineEdit.text = tempLine
				lineEdit.set_cursor_position(lineEdit.text.length())


func toggle_console() -> void:
	if isShown:
		hide()
	else:
		show()
		play_animation()
		
	isShown = !isShown

func get_last_message() -> String:
	return messages.back()
	

func play_animation() -> void:
	animation.play("slide_in_console")
	

func grab_line_focus() -> void:
	lineEdit.focus_mode = Control.FOCUS_ALL
	lineEdit.grab_focus()
	
	
func add_command(command : Command) -> void:
	commands.append(command)
	
func remove_command(commandName : String) -> bool:
	for i in range(commands.size()):
		if commands[i].get_name() == commandName:
			commands.remove(i)
			return true
	return false
	
	
func send_message(message : String):
	if message.empty():
		return
		
	if not resetSwitch:
		messages.pop_back()
	resetSwitch = true
	
	# let the message be switched through
	messages.append(message)
	currentIndex += 1
	messageHistory += message
	
	# logging
	#logFile.write_log(message)
	
	# check if the input is a command
	if message[0] == COMMAND_SIGN:
		var currentCommand = message
		currentCommand = currentCommand.trim_prefix(COMMAND_SIGN)
		if is_input_real_command(currentCommand):
			# return the command and the whole message
			var cmd = get_command(currentCommand)
			if cmd == null:
				textLabel.add_text("Command not found!\n")
				return
			
			var found = false
			for i in range(commands.size()):
				if commands[i].get_name() == cmd.get_name(): # found command
					textLabel.add_text(message)
					textLabel.newline()
					found = true
					var args = _extract_arguments(currentCommand)
					if not cmd.get_ref().get_expected_arguments() == args.size():
						 send_message_without_event("expected: %s arguments!" % \
								cmd.get_ref().get_expected_arguments())
					else:
						cmd.apply(_extract_arguments(currentCommand))
						
					emit_signal("on_command_sent", cmd, currentCommand)
					break
			if not found:
				textLabel.add_text("Commnd not found!\n")
		else:
			textLabel.add_text("Command not found!\n")
	else:
		textLabel.add_text(message)
	#textLabel.newline()
		
	emit_signal("on_message_sent", lineEdit.text)
	lineEdit.clear()


func clear():
	textLabel.clear()
	
	
func exit():
	toggle_console()
	
	
func man(command):
	for i in range(commands.size()):
		if commands[i].get_name() == command[0]:
			send_message_without_event("%s%s" % [COMMAND_SIGN, commands[i].get_name()], true, false)
			send_message_without_event(": %s" % commands[i].get_description())
	
	
func help():
	for i in range(commands.size()):
		send_message_without_event("%s%s" % [COMMAND_SIGN, commands[i].get_name()], true, false)
		send_message_without_event(": %s" % commands[i].get_description())
	 
	
func send_message_without_event(message : String, clickable = false, newLine = true):
	if message.empty():
		return
	
	if clickable:
		textLabel.push_meta("[u]" + message)
	
	messageHistory += message
	textLabel.add_text(message)
	if newLine:
		textLabel.newline()
	lineEdit.clear()
	
	if clickable:
		textLabel.pop()
	

# check first for real command
func get_command(cmdName : String) -> Command:
	var regex = RegEx.new()
	# if command looks like: "/..."
	regex.compile("^(\\S+)\\s?.*$")
	var result = regex.search(cmdName)
	
	if result:
		cmdName = result.get_string(1)
		for com in commands:
			if com.get_name() == cmdName:
				# commands[com] is the value
				return com
	return null

# before calling this method check for command sign
func is_input_real_command(cmdName : String) -> bool:
	if cmdName.empty():
		return false
		
	var regex = RegEx.new()
	regex.compile("^(\\S+).*$")
	var result = regex.search(cmdName)
	
	
	if result:
		cmdName = result.get_string(1)
		for com in commands:
			if com.get_name() == cmdName:
				# commands[com] is the value
				return true
	return false

func get_closest_commands(cmdName : String) -> Array:
	if cmdName.empty() or cmdName[0] != COMMAND_SIGN:
		return []
	
	var regex = RegEx.new()
	regex.compile("^%s(\\S+).*$" % COMMAND_SIGN)
	var result = regex.search(cmdName)

	var results = []

	if result:
		cmdName = result.get_string(1)
		for com in commands:
			if cmdName in com.get_name():	
				results.append(com.get_name())
		
		return results
		
	else:
		return []


func _extract_arguments(commandPostFix : String) -> Array:
	var args = commandPostFix.split(" ", false)
	args.remove(0)
	return args


func _on_send_pressed():
	send_message(lineEdit.text)
	lineEdit.grab_focus()
	

func _on_richTextLabel_meta_clicked(meta):
	lineEdit.text = meta.substr(3, meta.length() - 3)