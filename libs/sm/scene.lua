local COMMON = require "libs.common"
local SCENE_ENUMS = require "libs.sm.enums"
local SCENE_LOADER = require "libs.sm.scene_loader"
local CHECKS = require "libs.checks"
local TAG = "SCENE"

local CHECKS_OPTIONS = {
	modal = "?boolean",
	keep_loading = "?boolean"
}

---@class SceneConfig
---@field modal boolean
---@field keep_loaded boolean
local SCENE_CONFIG_DEFAULT = {
	modal = false,
	keep_loaded = false
}

--scene is singleton
--scene does not have script instance.It worked in main instance(init_controller.script)
---@class Scene
local Scene = COMMON.class('Scene')

---@param name string of scene.Must be unique
function Scene:initialize(name, url, config)
	CHECKS("?", "string", "string|url", CHECKS_OPTIONS)
	self._name = name
	self._url = msg.url(url)
	self._input = nil
	---@type SceneConfig
	self._config = config or COMMON.LUME.clone_deep(SCENE_CONFIG_DEFAULT)
	self._state = SCENE_ENUMS.STATES.UNLOADED
end

function Scene:load(async)
	assert(self._state == SCENE_ENUMS.STATES.UNLOADED, "can't load scene in state:" .. self._state)
	self._state = SCENE_ENUMS.STATES.LOADING
	local time = COMMON.get_time()
	SCENE_LOADER.load(self, function()
		self:load_done()
		self._state = SCENE_ENUMS.STATES.HIDE
		local load_time = COMMON.get_time() - time
		COMMON.i(string.format("%s loaded", self._name), TAG)
		COMMON.i(string.format("%s load time %s", self._name, load_time), TAG)
	end)
	while (not async and self._state == SCENE_ENUMS.STATES.LOADING) do coroutine.yield() end

end

function Scene:load_done()

end

function Scene:unload()
	assert(self._state == SCENE_ENUMS.STATES.HIDE)
	SCENE_LOADER.unload(self)
	self:unload_done()
	self._input_prev = self._input
	self._input = nil
	self._state = SCENE_ENUMS.STATES.UNLOADED
	COMMON.i(string.format("%s unloaded", self._name), TAG)
end

function Scene:unload_done() end

function Scene:hide_before()

end

function Scene:hide()
	assert(self._state == SCENE_ENUMS.STATES.PAUSED)
	self:hide_before()
	msg.post(self._url, COMMON.HASHES.MSG.DISABLE)
	self:hide_done()
	self._state = SCENE_ENUMS.STATES.HIDE
	COMMON.i(string.format("%s hide", self._name), TAG)
end

function Scene:hide_done() end

function Scene:show()
	assert(self._state == SCENE_ENUMS.STATES.HIDE)
	msg.post(self._url, COMMON.HASHES.MSG.ENABLE)
	coroutine.yield()--wait before engine enable proxy
	self:show_done()
	self._state = SCENE_ENUMS.STATES.PAUSED
	COMMON.i(string.format("%s show", self._name), TAG)
end

function Scene:show_done() end

function Scene:pause()
	assert(self._state == SCENE_ENUMS.STATES.RUNNING)
	msg.post(self._url, COMMON.HASHES.MSG.SET_TIME_STEP, { factor = 0, mode = 0 })
	self:pause_done()
	self._state = SCENE_ENUMS.STATES.PAUSED
	COMMON.i(string.format("%s paused", self._name), TAG)
end

function Scene:pause_done() end

function Scene:resume()
	assert(self._state == SCENE_ENUMS.STATES.PAUSED)
	msg.post(self._url, COMMON.HASHES.MSG.SET_TIME_STEP, { factor = 1, mode = 0 })
	self:resume_done()
	self._state = SCENE_ENUMS.STATES.RUNNING
	COMMON.i(string.format("%s resumed", self._name), TAG)
end

function Scene:input_acquire()
	self.handle_input = true
end

function Scene:input_release()
	self.handle_input = false
end

function Scene:resume_done()

end

---@param transition string
function Scene:transition(transition)
	CHECKS("?", "string")
end

--only top scene get input
function Scene:on_input(action_id, action)
end

function Scene:update(dt)
end

return Scene