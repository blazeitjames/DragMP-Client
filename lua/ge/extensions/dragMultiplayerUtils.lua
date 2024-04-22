local M = {}

local function getLocalPlayer()
    local players = MPVehicleGE.getPlayers()
    for _, player in pairs(players) do
        if player.isLocal then
            return player
        end
    end
end

M.getLocalPlayer = getLocalPlayer

return M
