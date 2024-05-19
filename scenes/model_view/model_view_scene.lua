local COMMON = require "libs.common"
local BaseScene = require "libs.sm.scene"

---@class GameScene:Scene
local Scene = BaseScene:subclass("Game")
function Scene:initialize()
	BaseScene.initialize(self, "ModelView", "/scenes#model_view_scene")
end

function Scene:pause_done()

end

return Scene