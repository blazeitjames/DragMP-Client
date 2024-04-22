local M = {}

local guiAPI = require("ge/extensions/editor/api/gui")
M.gui = { setupEditorGuiTheme = nop }
local imgui = ui_imgui

M.prompt = require("dragMP.ui.prompt")

local function onExtensionLoaded()
    guiAPI.initialize(M.gui)
    M.gui.registerWindow("DragMP Prompt", imgui.ImVec2(256, 256))
end

local function onUpdate(dt)
    if M.gui.isWindowVisible("DragMP Prompt") then
        M.prompt.draw()
    end
end

M.onUpdate = onUpdate
M.onExtensionLoaded = onExtensionLoaded

return M
