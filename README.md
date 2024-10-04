# [TF2] Chat Colors Redux

## Description

**[TF2] Chat Colors Redux** is a SourceMod plugin designed to enhance the chat experience in Team Fortress 2 by allowing players to customize their nickname colors, text colors, and chat prefixes. This plugin provides a user-friendly interface for selecting and applying colors, ensuring a personalized and visually appealing chat environment.

## Features

- **Customizable Name Colors**: Players can set their nickname colors using a gradient effect or a single color.
- **Text Color Customization**: Customize the color of your chat messages.
- **Prefix Support**: Add a custom prefix to your chat messages with customizable colors.
- **GUI Color Picker**: An intuitive GUI for selecting colors using hue, saturation, and brightness controls.
- **Persistent Settings**: Color and prefix settings are saved and restored across sessions using client cookies.

## Installation

1. **Download the Plugin**: Grab the [latest release](https://github.com/roxrosykid/tf2-chat-colors-redux/releases/latest).
2. **Install the Plugin**: Place the `.smx` file in your `tf/addons/sourcemod/plugins/` directory.
3. **Restart the Server**: Restart your server to load the plugin.

## Usage

### Commands

- **`sm_customchat`**: Opens the custom chat settings menu.
- **`sm_setcolor <type> <color> [color2]`**: Sets a color for the specified type (name, text, prefix).
- **`sm_guicolor`**: Opens the GUI color picker.
- **`sm_setprefix <prefix>`**: Sets a custom prefix for your chat messages.

### Example Commands

- **Set Name Color**: `sm_setcolor name FF0000 FF00FF`
- **Set Text Color**: `sm_setcolor text 00FF00`
- **Set Prefix Color**: `sm_setcolor prefix 0000FF FF0000`
- **Set Custom Prefix**: `sm_setprefix COOL DUDE XD`

### GUI Color Picker

- **Hue**: Adjust the hue of the color.
- **Saturation**: Adjust the saturation of the color.
- **Brightness**: Adjust the brightness of the color.
- **Cycle Inputs**: Use `W` and `S` to cycle through hue, saturation, and brightness inputs.
- **Adjust Values**: Use `A` and `D` to adjust the selected input value.
- **Apply**: Press `R` to apply the selected color.
