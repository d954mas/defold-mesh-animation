local COMMON = require "libs.common"
local GOOEY = require "gooey.gooey"

local GUI_SET_SCALE = gui.set_scale

---@class BtnScale
local Btn = COMMON.class("ButtonScale")

function Btn:initialize(root_name, path)
	self.vh = {
		root = gui.get_node(root_name .. (path or "/root")),
	}
	self.scale = 0.9
	self.template_name = root_name
	self.root_name = root_name .. (path or "/root")
	self.scale_start = gui.get_scale(self.vh.root)
	self.current_scale = self.scale_start
	self.pressed = false
	self.pressed_now_handled = false --fixed pressed_now 2 times when multi touch enabled\
	self.btn_refresh_f = function(button)
		self.pressed = button.pressed
		if button.pressed then
			self.current_scale = self.scale_start * self.scale
			GUI_SET_SCALE(button.node, self.current_scale)
		else
			self.current_scale = self.scale_start
			GUI_SET_SCALE(button.node, self.current_scale)
			self.pressed_now_handled = false
		end

		if self.input_on_pressed and button.pressed_now and not self.pressed_now_handled then
			self.pressed_now_handled = true
			if self.input_listener then self.input_listener() end
			self.btn:on_input(nil, nil)
		elseif not self.input_on_pressed and button.clicked then
			if self.input_listener then self.input_listener() end
		end
	end
	self.input_on_pressed = false --listener worked on pressed not on released

	self.btn = GOOEY.button(self.root_name, nil, self.btn_refresh_f)
end

function Btn:set_input_listener(listener)
	self.input_listener = listener
end

function Btn:on_input(action_id, action)
	if (self.ignore_input) then return false end
	local scale_changed = false
	if (self.current_scale ~= self.scale_start and action and action.released) then
		GUI_SET_SCALE(self.vh.root, self.scale_start)
		scale_changed = true
	end

	local result = self.btn:on_input(action_id, action)
	if (scale_changed) then
		GUI_SET_SCALE(self.vh.root, self.current_scale)
	end
	return result
end

function Btn:set_enabled(enable)
	gui.set_enabled(self.vh.root, enable)
end

function Btn:is_enabled()
	return gui.is_enabled(self.vh.root)
end

function Btn:is_pressed()
	return self:get_button().pressed
end

function Btn:set_ignore_input(ignore)
	self.ignore_input = ignore
end

function Btn:get_button()
	return self.button
end

return Btn