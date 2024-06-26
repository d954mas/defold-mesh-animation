local COMMON = require "libs.common"
local CHECKS = require "libs.checks"
--local PERLIN = require "libs.perlin"
--PERLIN.init()


-- Vectors used in calculations for public transform functions
local nv = vmath.vector4(0, 0, -1, 1)
local fv = vmath.vector4(0, 0, 1, 1)
local pv = vmath.vector4(0, 0, 0, 1)

local TEMP_WPOS = vmath.vector3()
local TEMP_FORWARD = vmath.vector3()

---@class Camera
local Camera = COMMON.class("camera")

Camera.SCALEMODE = {
	EXPANDVIEW = "expandView",
	FIXEDAREA = "fixedArea",
	FIXEDWIDTH = "fixedWidth",
	FIXEDHEIGHT = "fixedHeight",
}

Camera.GUI_ADJUST = {
	FIT = "fit",
	ZOOM = "zoom",
	STRETCH = "stretch"
}

---@class CameraConfig
local CameraConfig = {
	orthographic = "boolean",
	near_z = "number",
	far_z = "number",
	view_distance = "number",
	fov = "number",
	ortho_scale = "number",
	fixed_aspect_ratio = "boolean",
	aspect_ratio = "userdata", -- only used with a fixed aspect ratio
	use_view_area = "boolean",
	view_area = "userdata",
	scale_mode = "string",
}

local TWO_PI = math.pi * 2
local FORWARDVEC = vmath.vector3(0, 0, -1)
local UPVEC = vmath.vector3(0, 1, 0)
local RIGHTVEC = vmath.vector3(1, 0, 0)

local VMATH_ROTATE = vmath.rotate

local CAMERA_DEFAULTS = {
	orthographic = true,
	near_z = -1,
	far_z = 1,
	view_distance = 0,
	fov = -1,
	ortho_scale = 1,
	fixed_aspect_ratio = true,
	aspect_ratio = vmath.vector3(16, 9, 0), -- only used with a fixed aspect ratio

	use_view_area = false,
	view_area = vmath.vector3(800, 600, 0),

	scale_mode = Camera.SCALEMODE.EXPANDVIEW
}

---@param config CameraConfig
function Camera:initialize(id, config)
	config = COMMON.LUME.merge_table(CAMERA_DEFAULTS, config)
	CHECKS("?", "string", CameraConfig)
	assert(config.scale_mode == Camera.SCALEMODE.EXPANDVIEW or config.scale_mode == Camera.SCALEMODE.FIXEDAREA
			or config.scale_mode == Camera.SCALEMODE.FIXEDHEIGHT or config.scale_mode == Camera.SCALEMODE.FIXEDWIDTH)
	self.config = config

	if not self.config.orthographic then
		assert(self.config.near_z > 0 and self.config.far_z > 0)
	end

	self.screen_size = { w = COMMON.RENDER.screen_size.w, h = COMMON.RENDER.screen_size.h }

	self.ortho_zoom_mult = 0.01
	self.follow_lerp_speed = 3

	-- Put all camera data into a table for rendercam module and init camera.
	self.id = assert(id)
	self.near_z = assert(self.config.near_z)
	self.far_z = assert(self.config.far_z)
	self.abs_near_z = assert(self.near_z)
	self.abs_far_z = assert(self.far_z)
	self.world_z = 0 -- self.wpos.z - self.viewDistance, -- worldZ only used for screen_to_world_2d
	self.orthographic = self.config.orthographic
	self.fov = assert(self.config.fov)
	self.fixed_aspect_ratio = self.config.fixed_aspect_ratio
	self.ortho_scale = assert(self.config.ortho_scale)
	self.aspect_ratio = assert(self.config.aspect_ratio)
	self.aspect_ratio_number = self.config.aspect_ratio.x / self.config.aspect_ratio.y
	self.scale_mode = assert(self.config.scale_mode)
	self.use_view_area = self.config.use_view_area
	---@type vector3
	self.view_area = assert(self.config.view_area)
	self.view_area_no_zoom = assert(vmath.vector3(self.config.view_area))
	self.view_area_initial = vmath.vector3(self.view_area)
	self.half_view_area = vmath.vector3(self.view_area) * 0.5

	--local pos. Used for effets shake zoom rotation and etc
	self.lpos = vmath.vector3(0)
	self.lrot = vmath.quat_rotation_z(0)

	self.wpos = vmath.vector3(0)
	self.wrot = vmath.quat_rotation_z(0)

	self.lforward_vec = vmath.rotate(self.lrot, FORWARDVEC) -- for zooming
	self.lup_vec = vmath.rotate(self.lrot, UPVEC) -- or panning
	self.lright_vec = vmath.rotate(self.lrot, RIGHTVEC) -- for panning

	self.wforward_vec = vmath.rotate(self.wrot, FORWARDVEC) -- for calculating view matrix
	self.wup_vec = vmath.rotate(self.wrot, UPVEC) -- for calculating view matrix

	self.shake = vmath.vector3()
	self.follow_pos = vmath.vector3()

	self.shakes = {}
	self.recoils = {}
	self.follows = {}
	self.rotations = {}
	self.perlin_seeds = { math.random(256), math.random(256), math.random(256) }
	self.following = false

	self.zoom = 1 --0.5 is x0.5 pixels. 2 is x2 pixels Big value is near.  Small value is far away

	if self.fixed_aspect_ratio then
		if self.use_view_area then
			-- aspectRatio overrides proportion of viewArea (uses viewArea.x)
			self.view_area.y = self.view_area.x / self.aspect_ratio_number
		else
			-- or get fixed aspect viewArea inside current window
			local scale = math.min(self.screen_size.w / self.aspect_ratio_number, self.screen_size.h / 1)
			self.view_area.x = scale * self.aspect_ratio_number;
			self.view_area.y = scale
		end
	elseif not self.use_view_area then
		-- not using viewArea and non-fixed aspect ratio
		-- Set viewArea to current window size
		self.view_area.x = self.screen_size.w;
		self.view_area.y = self.screen_size.h
	end

	self.view_area.z = self.config.view_distance
	-- viewArea.z only used (with viewArea.y) in rendercam.update_window to get the FOV

	-- Fixed FOV -- just have to set initial viewArea to match the FOV
	-- to -maintain- a fixed FOV, must use "Fixed Height" mode, or a fixed aspect ratio and any "Fixed" scale mode.
	if self.fov > 0 then
		self.fov = math.rad(self.fov) -- FOV is set in degrees
		if not self.orthographic and not self.use_view_area then
			-- don't use FOV if using view area
			if self.view_area.z == 0 then self.view_area.z = 1 end -- view distance doesn't matter for fixed FOV, it just can't be zero.
			self.view_area.y = (self.view_area.z * math.tan(self.fov * 0.5)) * 2
			if self.fixed_aspect_ratio then
				self.view_area.x = self.view_area.y * self.aspect_ratio_number
			end
		end
	end

	self.view = vmath.matrix4() -- current view matrix
	self.proj = vmath.matrix4() -- current proj matrix
	self.gui_proj = vmath.matrix4()
	self.viewport = { x = 0, y = 0, width = self.screen_size.w, height = self.screen_size.h, scale = { x = 1, y = 1 } }

	-- GUI "transform" data - set in `calculate_gui_adjust_data` and used for screen-to-gui transforms in multiple places
	--				Fit		(scale)		(offset)	Zoom						Stretch
	self.gui_adjust = { [Camera.GUI_ADJUST.FIT] = { sx = 1, sy = 1, ox = 0, oy = 0 },
						[Camera.GUI_ADJUST.ZOOM] = { sx = 1, sy = 1, ox = 0, oy = 0 },
						[Camera.GUI_ADJUST.STRETCH] = { sx = 1, sy = 1, ox = 0, oy = 0 } }
	self.gui_offset = vmath.vector3()

	self.dirty = true
end

function Camera:follow_lerp_func(curPos, targetPos, dt)
	return vmath.lerp(dt * self.follow_lerp_speed, curPos, targetPos)
end

function Camera:shake_camera(dist, duration)
	table.insert(self.shakes, { dist = dist, dur = duration, t = duration })
end

function Camera:update(dt)

end

function Camera:set_position(pos)
	if (self.wpos.x ~= pos.x or self.wpos.y ~= pos.y or self.wpos.z ~= pos.z) then
		self.wpos.x, self.wpos.y, self.wpos.z = pos.x, pos.y, pos.z
		self.dirty = true
	end
end

function Camera:move(pos)
	self:set_position(self.wpos + pos)
end

---@param screen_x number [0,1] move camera to that zoom point
---@param screen_y number [0,1] move camera to that zoom point
function Camera:set_zoom(zoom, screen_x, screen_y)
	assert(zoom)
	assert(zoom > 0 and zoom < math.huge)
	screen_x = screen_x or 0.5
	screen_y = screen_y or 0.5
	assert(screen_x >= 0 and screen_x <= 1)
	assert(screen_y >= 0 and screen_y <= 1)
	if (self.zoom ~= zoom) then
		self.zoom = zoom
		local prev_w, prev_h = self.view_area.x, self.view_area.y
		self:recalculate_viewport()
		local new_w, new_h = self.view_area.x, self.view_area.y
		local dx = new_w - prev_w
		local dy = new_h - prev_h
		local vx = -dx * (screen_x - 0.5)
		local vy = -dy * (screen_y - 0.5)
		self:move(vmath.vector3(vx, vy, 0))
		self.dirty = true
	end
end

function Camera:get_view()
	if (self.dirty) then
		self:recalculate_view_proj()
	end
	return self.view
end

function Camera:get_proj()
	if (self.dirty) then
		self:recalculate_view_proj()
	end
	return self.proj
end

function Camera:get_gui_proj()
	return self.gui_proj
end

function Camera:recalculate_view_proj()
	--    print("camera:" .. self.id .. " recalculate_view_proj")
	self.dirty = false
	--recalculate all
	self.wforward_vec = VMATH_ROTATE(self.wrot, FORWARDVEC)
	self.wup_vec = VMATH_ROTATE(self.wrot, UPVEC)

	xmath.add(TEMP_WPOS,self.wpos, self.lpos)
	--TEMP_WPOS.y = TEMP_WPOS.y - self.view_area.y/2
	xmath.add(TEMP_FORWARD,TEMP_WPOS, self.wforward_vec)

	-- Absolute/world near and far positions for screen-to-world transform
	self.abs_near_z = TEMP_WPOS.z - self.near_z
	self.abs_far_z = TEMP_WPOS.z - self.far_z

	xmath.matrix_look_at(self.view, TEMP_WPOS, TEMP_FORWARD, self.wup_vec)

	if (self.orthographic) then
		local x = self.half_view_area.x * self.ortho_scale
		local y = self.half_view_area.y * self.ortho_scale
		xmath.matrix4_orthographic(self.proj,-x, x, -y, y, self.near_z, self.far_z)
	else
		self.proj = vmath.matrix4_perspective(self.fov, self.aspect_ratio_number, self.near_z, self.far_z)
	end
end

function Camera:get_target_worldViewSize(lastX, lastY, lastWinX, lastWinY, winX, winY)
	local x, y
	if self.fixed_aspect_ratio then
		if self.scale_mode == Camera.SCALEMODE.EXPANDVIEW then
			local z = math.max(lastX / lastWinX, lastY / lastWinY)
			x, y = winX * z, winY * z
		else
			-- Fixed Area, Fixed Width, and Fixed Height all work the same with a fixed aspect ratio
			--		The proportion and world view area remain the same.
			x, y = lastX, lastY
		end
		-- Enforce aspect ratio
		local scale = math.min(x / self.aspect_ratio_number, y / 1)
		x, y = scale * self.aspect_ratio_number, scale
	else
		-- Non-fixed aspect ratio
		if self.scale_mode == Camera.SCALEMODE.EXPANDVIEW then
			local z = math.max(lastX / lastWinX, lastY / lastWinY)
			x, y = winX * z, winY * z
		elseif self.scale_mode == Camera.SCALEMODE.FIXEDAREA then
			local aspect = winX / winY
			local view_area_aspect = self.view_area_initial.x / self.view_area_initial.y
			if aspect >= view_area_aspect then
				x, y = self.view_area_initial.y * aspect, self.view_area_initial.y
			else
				x, y = self.view_area_initial.x, self.view_area_initial.x / aspect
			end
		elseif self.scale_mode == Camera.SCALEMODE.FIXEDWIDTH then
			local ratio = winX / winY
			x, y = lastX, lastX / ratio
		elseif self.scale_mode == Camera.SCALEMODE.FIXEDHEIGHT then
			local ratio = winX / winY
			x, y = lastY * ratio, lastY
		else
			error("rendercam - get_target_worldViewSize() - camera:  scale mode not found.")
		end
	end

	return x, y
end

function Camera:recalculate_viewport()
	print("camera:" .. self.id .. " recalculate_viewport")
	local new_x = COMMON.RENDER.screen_size.w
	local new_y = COMMON.RENDER.screen_size.h

	local x, y = self:get_target_worldViewSize(self.view_area_no_zoom.x, self.view_area_no_zoom.y,
			self.screen_size.w, self.screen_size.h, new_x, new_y)
	self.view_area_no_zoom.x = x;
	self.view_area_no_zoom.y = y
	self.view_area.x = self.view_area_no_zoom.x / self.zoom
	self.view_area.y = self.view_area_no_zoom.y / self.zoom

	self.aspect_ratio = x / y
	self.screen_size.w = new_x
	self.screen_size.h = new_y
	self.viewport.width = x;
	self.viewport.height = y -- if using a fixed aspect ratio this will be immediately overwritten

	if self.fixed_aspect_ratio then
		-- if fixed aspect ratio, calculate viewport cropping
		local scale = math.min(self.screen_size.w / self.aspect_ratio_number, self.screen_size.h / 1)
		self.viewport.width = self.aspect_ratio_number * scale
		self.viewport.height = scale

		-- Viewport offset: bar on edge of screen from fixed aspect ratio
		self.viewport.x = (self.screen_size.w - self.viewport.width) * 0.5
		self.viewport.y = (self.screen_size.h - self.viewport.height) * 0.5

		-- For screen-to-viewport coordinate conversion
		self.viewport.scale.x = self.viewport.width / new_x
		self.viewport.scale.y = self.viewport.height / new_y
	else
		self.viewport.x = 0;
		self.viewport.y = 0
		self.viewport.width = new_x;
		self.viewport.height = new_y
	end

	if self.orthographic then
		self.half_view_area.x = x / 2 / self.zoom
		self.half_view_area.y = y / 2 / self.zoom
	else
		self.fov = self:fov_calculate(self.view_area.z, self.view_area.y * 0.5)
	end
	self:calculate_gui_adjust_data(self.screen_size.w, self.screen_size.h, COMMON.RENDER.config_size.w, COMMON.RENDER.config_size.h)
	xmath.matrix4_orthographic(self.gui_proj,0, self.screen_size.w, 0, self.screen_size.h, -1, 1)
	self.dirty = true
end

function Camera:fov_calculate(distance, y)
	-- must use Y, not X
	return math.atan(y / distance) * 2
end

function Camera:calculate_gui_adjust_data(winX, winY, configX, configY)
	local sx, sy = winX / configX, winY / configY

	-- Fit
	local adj = self.gui_adjust[Camera.GUI_ADJUST.FIT]
	local scale = math.min(sx, sy)
	adj.sx = scale;
	adj.sy = scale
	adj.ox = (winX - configX * adj.sx) * 0.5 / adj.sx
	adj.oy = (winY - configY * adj.sy) * 0.5 / adj.sy

	-- Zoom
	adj = self.gui_adjust[Camera.GUI_ADJUST.ZOOM]
	scale = math.max(sx, sy)
	adj.sx = scale;
	adj.sy = scale
	adj.ox = (winX - configX * adj.sx) * 0.5 / adj.sx
	adj.oy = (winY - configY * adj.sy) * 0.5 / adj.sy

	-- Stretch
	adj = self.gui_adjust[Camera.GUI_ADJUST.STRETCH]
	adj.sx = sx;
	adj.sy = sy
	-- distorts to fit window, offsets always zero
end

function Camera:screen_to_viewport(x, y, delta)
	if delta then
		x = x / self.viewport.scale.x
		y = y / self.viewport.scale.y
	else
		x = (x - self.viewport.x) / self.viewport.scale.x
		y = (y - self.viewport.y) / self.viewport.scale.y
	end
	return x, y
end

function Camera:screen_to_world_2d(x, y, delta, worldz, raw)
	worldz = worldz or self.world_z

	if self.fixed_aspect_ratio then
		x, y = self:screen_to_viewport(x, y, delta)
	end

	local m = not delta and vmath.inv(self.proj * self.view) or vmath.inv(self.proj)

	-- Remap coordinates to range -1 to 1
	local x1 = (x - COMMON.RENDER.screen_size.w * 0.5) / COMMON.RENDER.screen_size.w * 2
	local y1 = (y - COMMON.RENDER.screen_size.h * 0.5) / COMMON.RENDER.screen_size.h * 2

	if delta then
		x1 = x1 + 1;
		y1 = y1 + 1
	end

	nv.x, nv.y = x1, y1
	fv.x, fv.y = x1, y1
	local np = m * nv
	local fp = m * fv
	np = np * (1 / np.w)
	fp = fp * (1 / fp.w)

	local t = (worldz - self.abs_near_z) / (self.abs_far_z - self.abs_near_z) -- normalize desired Z to 0-1 from abs_nearZ to abs_farZ
	local worldpos = vmath.lerp(t, np, fp)

	if raw then return worldpos.x, worldpos.y, worldpos.z
	else return vmath.vector3(worldpos.x, worldpos.y, worldpos.z) end -- convert vector4 to vector3
end

function Camera:screen_to_gui(x, y, adjust, isSize)
	if not isSize then
		x = x / self.gui_adjust[adjust].sx - self.gui_adjust[adjust].ox
		y = y / self.gui_adjust[adjust].sy - self.gui_adjust[adjust].oy
	else
		x = x / self.gui_adjust[adjust].sx
		y = y / self.gui_adjust[adjust].sy
	end
	return x, y
end

function Camera:screen_to_gui_pick(x, y)
	return x / self.gui_adjust[Camera.GUI_ADJUST.ZOOM].sx, y / self.gui_adjust[Camera.GUI_ADJUST.ZOOM].sy
end

function Camera:world_to_screen(pos, adjust, raw)
	local m = self.proj * self.view
	pv.x, pv.y, pv.z, pv.w = pos.x, pos.y, pos.z, 1

	pv = m * pv
	pv = pv * (1 / pv.w)
	pv.x = (pv.x / 2 + 0.5) * self.viewport.width + self.viewport.x
	pv.y = (pv.y / 2 + 0.5) * self.viewport.height + self.viewport.y

	if adjust then
		pv.x = pv.x / self.gui_adjust[adjust].sx - self.gui_adjust[adjust].ox
		pv.y = pv.y / self.gui_adjust[adjust].sy - self.gui_adjust[adjust].oy
	end

	if raw then return pv.x, pv.y, 0
	else return vmath.vector3(pv.x, pv.y, 0) end
end

return Camera
