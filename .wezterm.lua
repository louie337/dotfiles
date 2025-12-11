-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices

config.color_scheme = "Tokyo Night Storm"
config.font = wezterm.font("MesloLGS NF")
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"
config.window_padding = { bottom = 0 }

local softLayer = {
	source = {
		Gradient = {
			orientation = "Vertical",
			colors = {
				"#24283b", -- bg
				"#1f2335", -- bg_dark
				-- "#1b1e2d", -- bg_dark1
			},
		},
	},
	width = "100%",
	height = "100%",
	opacity = 0.95,
}

local transparentLayer = {
	source = {
		Gradient = {
			orientation = "Vertical",
			colors = {
				"#24283b", -- bg
				"#1f2335", -- bg_dark
				-- "#1b1e2d", -- bg_dark1
			},
		},
	},
	width = "100%",
	height = "100%",
	opacity = 0.25,
}

local solidLayer = {
	source = {
		Gradient = {
			orientation = "Vertical",
			colors = {
				"#24283b", -- bg
				"#1f2335", -- bg_dark
				-- "#1b1e2d", -- bg_dark1
			},
		},
	},
	width = "100%",
	height = "100%",
	opacity = 1,
}

local imageLayer = {
	source = {
		File = "/Users/louie/wallpaper.jpg",
	},
	repeat_x = "NoRepeat",
	opacity = 0.1,
}

local dummyLayer = { source = { Color = "black" }, opacity = 0 }

-- NOTE: Fill with dummy layer
local background_modes = {
	{ softLayer },
	{ transparentLayer, dummyLayer },
	{ solidLayer,       dummyLayer, dummyLayer },
	{ softLayer,        imageLayer, dummyLayer, dummyLayer },
	{ solidLayer,       imageLayer, dummyLayer, dummyLayer, dummyLayer },
	-- image_background_config,
}

config.background = background_modes[1]

wezterm.on("cycle-background", function(window, pane)
	local overrides = window:get_config_overrides() or {}

	-- NOTE: Use the length of background layers to identify which stage it is, and is next
	if not overrides.background or #overrides.background == 1 then
		overrides.background = background_modes[2]
	elseif #overrides.background == 2 then
		overrides.background = background_modes[3]
	elseif #overrides.background == 3 then
		overrides.background = background_modes[4]
	elseif #overrides.background == 4 then
		overrides.background = background_modes[5]
	elseif #overrides.background == 5 then
		overrides.background = background_modes[1]
	end

	window:set_config_overrides(overrides)
end)

config.keys = {
	{
		key = "B",
		mods = "CTRL",
		action = wezterm.action.EmitEvent("cycle-background"),
	},
	{ key = "Enter", mods = "SHIFT", action = wezterm.action({ SendString = "\x1b\r" }) },
}

return config
