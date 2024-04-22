local M = {}
local imgui = ui_imgui

local function draw()
    if imgui.Begin("DragMP Prompt") then
        imgui.Text("Start Drag Race?")
        if imgui.Button("Start") then
            -- send broadcast to server
            local data = jsonEncode({ playerID = MPConfig.getPlayerServerID() })
            log("D", "prompt", dumps(data))
            log("D", "prompt", type(data))
            TriggerServerEvent('onRaceInitiated', data)
        end
    end
    imgui.End()
end

M.draw = draw

return M
