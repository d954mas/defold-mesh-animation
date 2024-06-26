local Actions = {}

Actions.Parallel = require "libs.actions.parallel_action"
Actions.Sequence = require "libs.actions.sequence_action"
Actions.Wait = require "libs.actions.wait_action"
Actions.TweenGo = require "libs.actions.tween_action_go"
Actions.TweenGui = require "libs.actions.tween_action_gui"
Actions.TweenTable = require "libs.actions.tween_action_table"
Actions.Function = require "libs.actions.function_action"
Actions.Shake = require "libs.actions.shake_action"
Actions.ShakeEulerZ = require "libs.actions.shake_action_euler_z"

return Actions