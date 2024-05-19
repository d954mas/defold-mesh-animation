local Event = require "libs.event"

local M = {}
M.WINDOW_RESIZED = Event("WINDOW_RESIZED")
M.WINDOW_EVENT = Event("WINDOW_EVENT")

return M