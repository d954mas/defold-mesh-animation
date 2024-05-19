local COMMON = require "libs.common"
local Camera = require "libs.rendercam_camera"

local Cameras = COMMON.class("Cameras")

function Cameras:initialize()

end

function Cameras:init()
	self.game_camera = Camera("game", {
		orthographic = false,
		near_z = 0.01,
		far_z = 100,
		view_distance = 0,
		fov = 60,
		ortho_scale = 1,
		fixed_aspect_ratio = false,
		use_view_area = false,
		view_area = vmath.vector3(720, 720, 0),
		scale_mode = Camera.SCALEMODE.FIXEDAREA
	})
	self:window_resized()
end

function Cameras:window_resized()
	if self.game_camera then
		self.game_camera:recalculate_viewport()
	end
end

return Cameras()
