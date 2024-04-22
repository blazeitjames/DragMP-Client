-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local logTag = 'DragMP'

local time = 0
local reactionTime = 0
local startTimer = 0

local alignMsgTimer = 0
-- TStatic objects used for left and right number displays
local leftTimeDigits = {}
local rightTimeDigits = {}
local leftSpeedDigits = {}
local rightSpeedDigits = {}

local initiated = false
local started = false
local countDownStarted = false
local jumpStarted = false
local disqualified = false

local speedUnit = 2.2369362920544
local vehicles = {}

local player1PrestageReady = false
local player1StageReady = false
local player1VehicleInsideTrigger
local player1Vehicle = nil

local player2PrestageReady = false
local player2StageReady = false
local player2VehicleInsideTrigger
local player2StartReady = false
local player2Vehicle = nil

local proTree = false

local lights = {}
local triggers = {}

local results = {}

local function updateDisplay(side, finishTime, finishSpeed)
    log("D", "updateDisplay", dumps(side) .. " = " .. dumps(finishTime) .. " =" .. dumps(finishSpeed))

    local timeDisplayValue = {}
    local speedDisplayValue = {}
    local timeDigits = {}
    local speedDigits = {}

    if side == "r" then
        timeDigits = rightTimeDigits
        speedDigits = rightSpeedDigits
    elseif side == "l" then
        timeDigits = leftTimeDigits
        speedDigits = leftSpeedDigits
    end

    if finishTime < 10 then
        table.insert(timeDisplayValue, "empty")
    end

    if finishSpeed < 100 then
        table.insert(speedDisplayValue, "empty")
    end

    -- Three decimal points for time
    for num in string.gmatch(string.format("%.3f", finishTime), "%d") do
        table.insert(timeDisplayValue, num)
    end

    -- Two decimal points for speed
    for num in string.gmatch(string.format("%.2f", finishSpeed), "%d") do
        table.insert(speedDisplayValue, num)
    end

    if #timeDisplayValue > 0 and #timeDisplayValue < 6 then
        for i, v in ipairs(timeDisplayValue) do
            timeDigits[i]:preApply()
            timeDigits[i]:setField('shapeName', 0, "art/shapes/quarter_mile_display/display_" .. v .. ".dae")
            timeDigits[i]:setHidden(false)
            timeDigits[i]:postApply()
        end
    end

    for i, v in ipairs(speedDisplayValue) do
        speedDigits[i]:preApply()
        speedDigits[i]:setField('shapeName', 0, "art/shapes/quarter_mile_display/display_" .. v .. ".dae")
        speedDigits[i]:setHidden(false)
        speedDigits[i]:postApply()
    end
end

local function clearDisplay(digits)
    -- Setting display meshes to empty object
    -- We can assume 5 as we know there are only 5 digits available for each display
    for i = 1, #digits do
        -- digits[i]:setField('shapeName', 0, "art/shapes/quarter_mile_display/display_empty.dae")
        -- digits[i]:postApply()
        digits[i]:setHidden(true)
    end
end

local function resetDisplays()
    clearDisplay(leftTimeDigits)
    clearDisplay(rightTimeDigits)
    clearDisplay(leftSpeedDigits)
    clearDisplay(rightSpeedDigits)
end

local function resetLights()
    for _, group in pairs(lights) do
        for _, light in pairs(group) do
            if light.obj then
                light.obj:setHidden(true)
            end
        end
    end
end

local function initLights()
    log("D", logTag, "Initializing lights")
    lights = {
        stageLights = {
            prestageLightL = { obj = scenetree.findObject("Prestagelight_l"), anim = "prestage" },
            prestageLightR = { obj = scenetree.findObject("Prestagelight_r"), anim = "prestage" },
            stageLightL    = { obj = scenetree.findObject("Stagelight_l"), anim = "prestage" },
            stageLightR    = { obj = scenetree.findObject("Stagelight_r"), anim = "prestage" }
        },
        countDownLights = {
            amberLight1R = { obj = scenetree.findObject("Amberlight1_R"), anim = "tree" },
            amberLight2R = { obj = scenetree.findObject("Amberlight2_R"), anim = "tree" },
            amberLight3R = { obj = scenetree.findObject("Amberlight3_R"), anim = "tree" },
            amberLight1L = { obj = scenetree.findObject("Amberlight1_L"), anim = "tree" },
            amberLight2L = { obj = scenetree.findObject("Amberlight2_L"), anim = "tree" },
            amberLight3L = { obj = scenetree.findObject("Amberlight3_L"), anim = "tree" },
            greenLightR  = { obj = scenetree.findObject("Greenlight_R"), anim = "tree" },
            greenLightL  = { obj = scenetree.findObject("Greenlight_L"), anim = "tree" },
            redLightR    = { obj = scenetree.findObject("Redlight_R"), anim = "tree" },
            redLightL    = { obj = scenetree.findObject("Redlight_L"), anim = "tree" }
        }
    }
end

local function init()
    initiated = false
    started = false
    time = 0
    startTimer = 0
    jumpStarted = false
    countDownStarted = false
    player2PrestageReady = false
    player2StageReady = false
    player2StartReady = false
    player1PrestageReady = false
    player1StageReady = false
    disqualified = false
    results = {}
    vehicles = {}
    resetLights()
end

local function resetStageLights(side)
    side = side or "both"
    if side == "both" or side == "left" then
        lights.stageLights.prestageLightL.obj:setHidden(true)
        lights.stageLights.stageLightL.obj:setHidden(true)
    end
    if side == "both" or side == "right" then
        lights.stageLights.prestageLightR.obj:setHidden(true)
        lights.stageLights.stageLightR.obj:setHidden(true)
    end
end

local function calculateDistanceFromStart(vehicle, trigger)
    if vehicle and trigger then
        -- local wheels = {}
        local maxFwd = -math.huge
        -- get the most forward-y wheel, then project that position to the center-line of the vehicle.
        for i = 0, vehicle:getWheelCount() - 1 do
            local axisNodes = vehicle:getWheelAxisNodes(i)
            local nodePos = vehicle:getNodePosition(axisNodes[1])
            -- local wheelNodePos = vehicle:getPosition() + vec3(nodePos.x, nodePos.y, nodePos.z)
            --local wheelNodePosToTrigger = vec3(wheelNodePos - trigger:getPosition())
            -- We need actual distance from starting line and not the center
            local dot = vec3(nodePos.x, nodePos.y, nodePos.z):dot(vehicle:getDirectionVector():normalized())
            maxFwd = math.max(dot, maxFwd)
            --wheels[i+1] = {wheelNodePos = wheelNodePos, distance = distance}
        end

        -- In order to accurately calculate that AI is in the correct position
        -- we need to find the wheels that are closest to the start line


        -- Point inbetween both wheels is calculated so that we can get a somewhat accurate distance measurement
        local centerPoint = vehicle:getPosition() + maxFwd * vehicle:getDirectionVector():normalized()
        local centerPointToTrigger = vec3(centerPoint - trigger:getPosition())
        centerPointToTrigger.z = 0

        if centerPointToTrigger:len() > 10 then return end

        local dot = centerPointToTrigger:dot(vehicle:getDirectionVector():normalized())
        local distanceFromStart = -dot

        if debugDist and debugDrawer then
            debugDrawer:drawLine((vehicle:getDirectionVector() + centerPoint), centerPoint, ColorF(1, 0, 0, 1))

            -- Line between two closest wheels
            --debugDrawer:drawLine(closestWheels[1].wheelNodePos, closestWheels[2].wheelNodePos, ColorF(0.5,0.0,0.5,1.0))
            -- Sphere indicating center point of the wheels
            debugDrawer:drawSphere(centerPoint, 0.2, ColorF(0.0, 0.0, 1.0, 1.0))
            -- Sphere indicating start line
            debugDrawer:drawLine(centerPoint, trigger:getPosition(), ColorF(1, 0.0, 0.5, 1.0))
            -- Text to indicate current distance from start line
            debugDrawer:drawTextAdvanced(trigger:getPosition(), String('Distance:' .. distanceFromStart), ColorF(0, 0, 0,
                1), true, false, ColorI(255, 255, 255, 255))
        end

        return distanceFromStart
    end
end

AddEventHandler("DragMP_RaceInitiated", function(data)
    log("D", "DragMP_RaceInitiated", "data: " .. dumps(data))
    local decodedData = jsonDecode(data)

    if decodedData.initiatorPlayerID == MPConfig.getPlayerServerID() then
        initiated = true
        guihooks.trigger('toastrMsg', {
            type = "info",
            title = "Get Ready",
            msg = "Please move to the right lane",
            config = { timeOut = 2000 }
        })
    -- else
    --     guihooks.trigger('toastrMsg', {
    --         type = "info",
    --         title = "Someone challenged a drag race!",
    --         msg = "Accept?",
    --         config = { timeOut = 2000 }
    --     })
    end
end)

-- AddEventHandler("DragMP:RaceStarted", function(data)
--     initiated = true
-- end)

AddEventHandler("DragMP_SyncDisplay", function(data) 
    local decodedData = jsonDecode(data)
    log("D", "DragMP_SyncDisplay", "Syncing display")
    updateDisplay(decodedData.side, tonumber(decodedData.time), tonumber(decodedData.speed))
end)

-- Someone has finished a race
-- Update the leaderboard
AddEventHandler("DragMP_RaceFinished", function(data)
    if initiated then
        initiated = false
    end
end)

local function finishRace()
    if started then
        -- displayOverview(true, true)
        TriggerServerEvent('onRaceFinished', jsonEncode({
            playerID = MPConfig.getPlayerServerID(),
            result = results[1]
        }))

        guihooks.trigger('toastrMsg', {
            type = "info",
            title = "Result",
            msg = string.format("%.3f", results[1].time) ..
                "s" .. "@" .. string.format("%.2f", results[1].speed) .. "mph" .. "\n" .. 
                "Reaction Time: " .. string.format("%.3f", results[1].reactionTime) .. "s",
            config = { timeOut = 5000 }
        })
        log("D", logTag, "finishRace" .. dumps(results))
        init()
    end
end

local function onVehicleDestroyed(id)
    if player1Vehicle and player1Vehicle:getID() == id then
        player1Vehicle = nil
        player1VehicleInsideTrigger = nil
        resetLights()
    -- elseif player2Vehicle and player2Vehicle:getID() == id then
    --     player2Vehicle = nil
    --     player2VehicleInsideTrigger = nil
    --     resetLights()
    end
end

local function onBeamNGTrigger(data)
    log("D", logTag, 'onBeamNGTrigger: ' .. dumps(data))
    local veh = be:getPlayerVehicle(0)
    -- print("veh: " .. dumps(veh))

    -- INITIATE PLAYERS VEHICLE
    if data.triggerName == "dragTrigger" then
        if data.event == "enter" and not player1Vehicle then
            player1Vehicle = be:getObjectByID(data.subjectID)
            player1VehicleInsideTrigger = true
        end
    end

    if data.triggerName == "dragTrigger_L" then
        if data.event == "enter" and not player2Vehicle then
            player2Vehicle = be:getObjectByID(data.subjectID)
            player2VehicleInsideTrigger = true
        end
    end

    -- USER PROMPT
    if data.triggerName == "dragTrigger" and data.subjectID == veh:getId() then
        -- local jsonData = rxijson.encode({
        --     event = data.event,
        --     vehicleID = MPVehicleGE.getServerVehicleId(data.subjectID),
        -- })

        -- TriggerServerEvent("dragTrigger", jsonData)

        if data.event == "enter" then
            if started then
                disqualified = true
                guihooks.trigger('toastrMsg', {
                    type = "warning",
                    title = "Race Abandoned!",
                    msg = "This record will not be saved",
                    config = { timeOut = 2000 }
                })
            end
            init()
            player1VehicleInsideTrigger = true
            -- guihooks.trigger('toastrMsg', {
            --     type = "info",
            --     title = "Start Drag Race",
            --     msg = "Type /start in chat to start",
            --     config = { timeOut = 2000 }
            -- })

            dragMultiplayerUI.gui.showWindow("DragMP Prompt")

            -- local buttonsTable = {}
            -- local txt = opponentVehicle == nil and 'ui.dragrace.Accept' or 'ui.dragrace.Configure'
            -- table.insert(buttonsTable, { action = 'accept', text = txt, cmd = 'freeroam_dragRace.accept()' })
            -- table.insert(buttonsTable,
            --     {
            --         action = 'decline',
            --         text = "Close",
            --         cmd = 'guihooks.trigger("MenuHide", true) ui_missionInfo.closeDialogue()'
            --     })
            -- local content = { title = "ui.wca.dragstrip.title", type = "race", typeName = "", buttons = buttonsTable }
            -- ui_missionInfo.openDialogue(content)
        end

        if data.event == "exit" then
            player1VehicleInsideTrigger = nil
            dragMultiplayerUI.gui.hideWindow("DragMP Prompt")
        end
    end

    -- FINISH LINE
    if data.event == "enter" and data.triggerName == "endTrigger" then
        if started == true then
            for i, v in pairs(vehicles) do
                if v.lane == "right" and v.id == data.subjectID then
                    local rightVehicle = be:getObjectByID(v.id)
                    -- Updating right display
                    if not disqualified then
                        time = time - reactionTime
                        local speed = rightVehicle:getVelocity():len() * speedUnit
                        TriggerServerEvent('onSyncDisplay', jsonEncode({
                            side = "r",
                            time = time,
                            speed = speed,
                        }))

                        updateDisplay("r", time, speed)
                    end

                    -- local currentVehicle = core_vehicles.getCurrentVehicleDetails()
                    -- local vehicleName = ""
                    -- if currentVehicle.configs then
                    --     vehicleName = currentVehicle.configs.Name
                    -- else
                    --     vehicleName = currentVehicle.model.Name
                    -- end

                    table.insert(results, {
                        time = (disqualified and "Disqualified" or time),
                        speed = rightVehicle:getVelocity():len() * speedUnit,
                        reactionTime = (disqualified and "Disqualified" or reactionTime)
                        -- vehicle = vehicleName
                    })

                    table.remove(vehicles, i)
                end

                if v.lane == "left" and v.id == data.subjectID then
                    local leftVehicle = be:getObjectByID(v.id)
                    local speed = leftVehicle:getVelocity():len() * speedUnit
                    -- Updating left display
                    if not disqualified then
                        updateDisplay("l", time, speed)
                    end

                    -- local currentVehicle =
                    -- local vehicleName = ""
                    -- if currentVehicle.configs then
                    --     vehicleName = currentVehicle.configs.Name
                    -- else
                    --     vehicleName = currentVehicle.model.Name
                    -- end

                    table.insert(results, {
                        time = (disqualified and "Disqualified" or time),
                        speed = speed,
                        -- vehicle = vehicleName
                    })

                    table.remove(vehicles, i)
                end

                if #vehicles == 0 then
                    finishRace()
                end
            end
        end
    end

    -- DRIVING ON THE OPPONENT SIDE
    if data.triggerName == "laneTrigger_L" then
        if data.event == "enter" and data.subjectID == be:getPlayerVehicleID(0) then
            if started then
                disqualified = true
                guihooks.trigger('Message',
                    { ttl = 5, msg = "Disqualifed for driving within opponents lane.", category = "fill", icon = "flag" })
            end
        end
    end

    -- REACTION TIME AND JUMPSTART DETECTION
    if data.triggerName == "laneTrigger_R" then
        if data.event == "enter" and data.subjectID == be:getPlayerVehicleID(0) then
            if started then
                reactionTime = time
            end
        end
    end

    -- INITIATE VEHICLES DATA
    if data.triggerName == "startTrigger_R" then
        if data.event == "enter" or not vehicles[1] or (vehicles[1].id ~= data.subjectID) then
            log("D", "trigger", "start R")
            vehicles[1] = { id = data.subjectID, lane = "right" }
        end
    end

    if data.triggerName == "startTrigger_L" then
        if data.event == "enter" or not vehicles[2] or (vehicles[2].id ~= data.subjectID) then
            vehicles[2] = { id = data.subjectID, lane = "left" }
        end
    end

    -- if data.triggerName == "dragTrigger_L" and opponentVehicle then
    --     if data.event == "enter" then
    --         init()
    --         opponentVehicle:queueLuaCommand('ai.setSpeed(5)')
    --         opponentVehicle:queueLuaCommand('ai.setSpeedMode("set")')
    --         opponentVehicle:queueLuaCommand('ai.setAggression(0)')
    --     end
    -- end
end

local function onPreRender(dtReal, dtSim, dtRaw)
    -- if not opponentVehicle then return end
    -- log("D", "onPreRender",
    --     "started: " ..
    --     tostring(started) ..
    --     " countDownStarted: " .. tostring(countDownStarted) .. " startTimer: " .. tostring(startTimer))
    -- if not player1Vehicle or not player2Vehicle then return end
    if not player1Vehicle then return end

    if countDownStarted and not started then
        startTimer = startTimer + dtSim
        if proTree then
            if startTimer > 2.0 then
                if startTimer < 2.4 and lights.countDownLights.amberLight1L.obj:isHidden() then
                    lights.countDownLights.amberLight1L.obj:setHidden(false)
                    lights.countDownLights.amberLight2L.obj:setHidden(false)
                    lights.countDownLights.amberLight3L.obj:setHidden(false)
                    lights.countDownLights.amberLight1R.obj:setHidden(false)
                    lights.countDownLights.amberLight2R.obj:setHidden(false)
                    lights.countDownLights.amberLight3R.obj:setHidden(false)
                end
                if startTimer > 2.4 and not started then
                    lights.countDownLights.amberLight1L.obj:setHidden(true)
                    lights.countDownLights.amberLight2L.obj:setHidden(true)
                    lights.countDownLights.amberLight3L.obj:setHidden(true)
                    lights.countDownLights.amberLight1R.obj:setHidden(not jumpStarted)
                    lights.countDownLights.amberLight2R.obj:setHidden(not jumpStarted)
                    lights.countDownLights.amberLight3R.obj:setHidden(not jumpStarted)
                    lights.countDownLights.greenLightL.obj:setHidden(false)
                    lights.countDownLights.greenLightR.obj:setHidden(jumpStarted)
                    if not jumpStarted then
                        started = true
                        guihooks.trigger('Message', { ttl = 0.25, msg = nil, category = "align", icon = "check" })
                        time = 0
                        resetDisplays()
                        -- opponentVehicle:queueLuaCommand('controller.setFreeze(0)')
                        -- startOpponent()
                        guihooks.trigger('Message',
                            { ttl = 5, msg = "Quarter mile started", category = "fill", icon = "flag" })
                    end
                end
            end
        else
            if startTimer > 1.0 and startTimer < 1.5 and lights.countDownLights.amberLight1L.obj:isHidden() then
                lights.countDownLights.amberLight1L.obj:setHidden(false)
                lights.countDownLights.amberLight1R.obj:setHidden(jumpStarted)
            end
            if startTimer > 1.5 and startTimer < 2.0 and lights.countDownLights.amberLight2L.obj:isHidden() then
                lights.countDownLights.amberLight1L.obj:setHidden(true)
                lights.countDownLights.amberLight2L.obj:setHidden(false)
                if not jumpStarted then
                    lights.countDownLights.amberLight1R.obj:setHidden(true)
                    lights.countDownLights.amberLight2R.obj:setHidden(false)
                end
            end
            if startTimer > 2.0 and startTimer < 2.5 and lights.countDownLights.amberLight3L.obj:isHidden() then
                lights.countDownLights.amberLight2L.obj:setHidden(true)
                lights.countDownLights.amberLight3L.obj:setHidden(false)
                if not jumpStarted then
                    lights.countDownLights.amberLight2R.obj:setHidden(true)
                    lights.countDownLights.amberLight3R.obj:setHidden(false)
                end
            end
            if startTimer > 2.5 and not started then
                lights.countDownLights.amberLight3L.obj:setHidden(true)
                lights.countDownLights.greenLightL.obj:setHidden(false)
                if not jumpStarted then
                    lights.countDownLights.amberLight3R.obj:setHidden(true)
                    lights.countDownLights.greenLightR.obj:setHidden(false)
                    started = true
                    -- guihooks.trigger('Message', { ttl = 0.25, msg = nil, category = "align", icon = "check" })
                    resetDisplays()
                    time = 0
                    reactionTime = 0
                    -- opponentVehicle:queueLuaCommand('controller.setFreeze(0)')
                    -- startOpponent()
                    guihooks.trigger('Message',
                        { ttl = 5, msg = "Quarter mile started", category = "fill", icon = "flag" })
                end
            end
        end
    end

    if started then
        time = time + dtSim
    end

    if player1Vehicle and not started and initiated then
        local player1DistanceFromStart = calculateDistanceFromStart(player1Vehicle, triggers["startTriggerR"])
        -- log("I", "onPreRender", "player1DistanceFromStart: " .. tostring(player1DistanceFromStart))
        if player1DistanceFromStart then
            if not countDownStarted then
                alignMsgTimer = alignMsgTimer + dtSim
                if alignMsgTimer >= 0.1 then
                    alignMsgTimer = 0
                    if player1DistanceFromStart > 0.35 then
                        guihooks.trigger('Message',
                            {
                                ttl = 0.25,
                                msg = "Align your front wheels with the starting line. (Move forward)",
                                category = "align",
                                icon = "arrow_upward"
                            })
                    elseif player1DistanceFromStart < 0 then
                        guihooks.trigger('Message',
                            {
                                ttl = 0.25,
                                msg = "Align your front wheels with the starting line. (Move backward)",
                                category = "align",
                                icon = "arrow_downward"
                            })
                    else
                        guihooks.trigger('Message',
                            { ttl = 0.25, msg = "Stop your vehicle now.", category = "align", icon = "check" })
                    end
                end
            end

            -- Jumpstart detection during countdown
            if countDownStarted and player1DistanceFromStart < -0.25 and not jumpStarted then
                countDownStarted = false
                jumpStarted = true
                disqualified = true
                -- lights.countDownLights.amberLight1R.obj:setHidden(false)
                -- lights.countDownLights.amberLight2R.obj:setHidden(false)
                -- lights.countDownLights.amberLight3R.obj:setHidden(false)
                -- lights.countDownLights.greenLightR.obj:setHidden(true)
                -- lights.countDownLights.redLightR.obj:setHidden(false)
                resetLights()
                guihooks.trigger('Message',
                    {
                        ttl = 5,
                        msg = "Disqualified for jumping the start, you need to restart the race.",
                        category = "fill",
                        icon = "flag"
                    })
                log("D", "pre", "JUMPED *****************************************************************")
                player1StageReady = false
                countDownStarted = false
                time = 0
            end

            if player1DistanceFromStart > 0 then
                -- if playerDistanceFromStart < 1 and playerDistanceFromStart > 0 and playerPrestageReady == false then
                --   lights.stageLights.prestageLightR.obj:setHidden(false)
                --   playerPrestageReady = true
                -- end
                player1PrestageReady = player1DistanceFromStart < 1 and player1DistanceFromStart > 0
                lights.stageLights.prestageLightL.obj:setHidden(not player1PrestageReady)
                lights.stageLights.prestageLightR.obj:setHidden(not player1PrestageReady)

                if player1DistanceFromStart <= 0.35 and player1StageReady == false and player1Vehicle:getVelocity():len() < 0.1 then
                    lights.stageLights.stageLightL.obj:setHidden(false)
                    lights.stageLights.stageLightR.obj:setHidden(false)
                    player1StageReady = true
                end

                if player1DistanceFromStart > 0.35 and player1PrestageReady and player1StageReady and not countDownStarted then
                    player1StageReady = false
                    started = false
                    countDownStarted = false
                    lights.stageLights.stageLightL.obj:setHidden(true)
                    lights.stageLights.stageLightR.obj:setHidden(true)
                end 
            end
        end
    end

    if player1Vehicle and started then
        local player1DistanceFromStart = calculateDistanceFromStart(player1Vehicle, triggers["startTriggerR"])
        if player1DistanceFromStart and player1DistanceFromStart > 8 then
            resetStageLights()
        end
    end

    if player1StageReady and not countDownStarted then
        countDownStarted = true
    end

    -- if player2Vehicle and not started and initiated then
    --     local player2DistanceFromStart = calculateDistanceFromStart(player2Vehicle, triggers["startTriggerL"])

    --     if player2DistanceFromStart then
    --         if not started and not countDownStarted then
    --             alignMsgTimer = alignMsgTimer + dtSim
    --             if alignMsgTimer >= 0.1 then
    --                 alignMsgTimer = 0
    --                 if player2DistanceFromStart > 0.35 then
    --                     guihooks.trigger('Message',
    --                         {
    --                             ttl = 0.25,
    --                             msg = "Align your front wheels with the starting line. (Move forward)",
    --                             category = "align",
    --                             icon = "arrow_upward"
    --                         })
    --                 elseif player2DistanceFromStart < 0 then
    --                     guihooks.trigger('Message',
    --                         {
    --                             ttl = 0.25,
    --                             msg = "Align your front wheels with the starting line. (Move backward)",
    --                             category = "align",
    --                             icon = "arrow_downward"
    --                         })
    --                 else
    --                     guihooks.trigger('Message',
    --                         { ttl = 0.25, msg = "Stop your vehicle now.", category = "align", icon = "check" })
    --                 end
    --             end
    --         end

    --         if player2DistanceFromStart > 0 then
    --             player2PrestageReady = player2DistanceFromStart < 1 and player2DistanceFromStart > 0
    --             lights.stageLights.prestageLightL.obj:setHidden(not player2PrestageReady)
    --             lights.stageLights.prestageLightR.obj:setHidden(not player2PrestageReady)

    --             if player2DistanceFromStart <= 0.35 and player2StageReady == false and player2Vehicle:getVelocity():len() < 0.1 then
    --                 lights.stageLights.stageLightL.obj:setHidden(false)
    --                 lights.stageLights.stageLightR.obj:setHidden(false)
    --                 player2StageReady = true
    --             end

    --             if player2DistanceFromStart > 0.35 and player2PrestageReady and player2StageReady and not started and not countDownStarted then
    --                 player2StageReady = false
    --                 started = false
    --                 countDownStarted = false
    --                 lights.stageLights.stageLightL.obj:setHidden(true)
    --                 lights.stageLights.stageLightR.obj:setHidden(true)
    --             end

    --             -- Jumpstart detection not working
    --             if (countDownStarted and player2DistanceFromStart < -0.25 and not jumpStarted and not started) then
    --                 countDownStarted = false
    --                 jumpStarted = true
    --                 disqualified = true
    --                 lights.countDownLights.amberLight1R.obj:setHidden(false)
    --                 lights.countDownLights.amberLight2R.obj:setHidden(false)
    --                 lights.countDownLights.amberLight3R.obj:setHidden(false)
    --                 lights.countDownLights.greenLightR.obj:setHidden(true)
    --                 lights.countDownLights.redLightR.obj:setHidden(false)
    --                 guihooks.trigger('Message',
    --                     {
    --                         ttl = 5,
    --                         msg = "Disqualified for jumping the start, you need to restart the race.",
    --                         category = "fill",
    --                         icon = "flag"
    --                     })
    --                 log("D", "pre", "JUMPED *****************************************************************")
    --                 -- opponentVehicle:queueLuaCommand('ai.setSpeed(0)')
    --                 -- opponentVehicle:queueLuaCommand('controller.setFreeze(1)')
    --                 -- stopOpponent()
    --                 player2StageReady = false
    --                 countDownStarted = false
    --                 time = 0
    --                 -- displayOverview(true)
    --             end
    --         end
    --     end
    -- end

    -- if player2Vehicle and started then
    --     local player2DistanceFromStart = calculateDistanceFromStart(player2Vehicle, triggers["startTriggerL"])
    --     if player2DistanceFromStart and player2DistanceFromStart > 8 then
    --         resetStageLights()
    --     end
    -- end

    -- if opponentVehicle and not started then
    --     local opponentDistanceFromStart = calculateDistanceFromStart(opponentVehicle, triggers["startTriggerL"])
    --     -- TODO: fine tune this value as some vehicles don't stop as well as others,
    --     -- not sure how this could be solved atm though
    --     if opponentDistanceFromStart then
    --         if opponentDistanceFromStart > 0 then
    --             -- AI vehicle is approximately 20cm from start line including tire radius
    --             if opponentDistanceFromStart < 1 and opponentDistanceFromStart > 0 and opponentPrestageReady == false then
    --                 setupPrestage()
    --             end
    --             if opponentDistanceFromStart < 0.7 and opponentStageReady == false and playerPrestageReady then
    --                 setupStage()
    --             end
    --             -- AI vehicle is approximately on the start line
    --             if opponentDistanceFromStart < 0.3 and opponentStageReady and not opponentStartReady and not jumpStarted then
    --                 setupStart()
    --             end
    --         end
    --     end
    -- end
    -- if started and (not opponentStartReady or not opponentStageReady) then
    --     log("E", "prerdr", "force start, was not ready")
    --     setupStart()
    --     opponentVehicle:queueLuaCommand('controller.setFreeze(0)')
    --     startOpponent()
    -- end
    -- if opponentVehicle and started then
    --     local opponentDistanceFromStart = calculateDistanceFromStart(opponentVehicle, triggers["startTriggerL"])
    --     if opponentDistanceFromStart and opponentDistanceFromStart > 8 then
    --         lights.stageLights.prestageLightL.obj:setHidden(true)
    --         lights.stageLights.stageLightL.obj:setHidden(true)
    --     end
    -- end

    -- if opponentStageReady and playerStageReady and not countDownStarted then
    --     countDownStarted = true
    -- end
    

    -- if player2StageReady and not countDownStarted then
    --     countDownStarted = true
    -- end
end

local function onVehicleResetted(vid)
    local vehicle = be:getObjectByID(vid)

    if not vehicle then return end

    -- if player1VehicleInsideTrigger and player1Vehicle and player1Vehicle:getID() == vid then
    --     ui_missionInfo.closeDialogue()
    -- end

    -- if player2Vehicle:getID() == vid then
    --     if quickReset == true then
    --         setupVehicle()
    --         quickReset = false
    --     else
    --         setupVehicle()
    --     end
    -- end
end

local function onWorldReadyState(state)
    log("W", logTag, 'onWorldReadyState: ' .. dumps(state))

    if state == 1 then
        guihooks.trigger('toastrMsg', {
            type = "info",
            title = "Welcome to DragMP Server",
            msg = "Go to the drag strip and start competing",
            config = { timeOut = 10000 }
        })

        started = false
        -- player1Vehicle = be:getPlayerVehicle(0)
        -- player2Vehicle = be:getPlayerVehicle(0)

        initLights()
        resetLights()

        -- Creating a table for the TStatics that are being used to display drag time and final speed
        for i = 1, 5 do
            local leftTimeDigit = scenetree.findObject("display_time_" .. i .. "_l")
            table.insert(leftTimeDigits, leftTimeDigit)

            local rightTimeDigit = scenetree.findObject("display_time_" .. i .. "_r")
            table.insert(rightTimeDigits, rightTimeDigit)

            local rightSpeedDigit = scenetree.findObject("display_speed_" .. i .. "_r")
            table.insert(rightSpeedDigits, rightSpeedDigit)

            local leftSpeedDigit = scenetree.findObject("display_speed_" .. i .. "_l")
            table.insert(leftSpeedDigits, leftSpeedDigit)
        end
        resetDisplays()

        triggers = {
            dragTriggerL         = scenetree.findObject("dragTrigger_L"),
            dragTriggerR         = scenetree.findObject("dragTrigger_R"),
            startTriggerL        = scenetree.findObject("startTrigger_L"),
            startTriggerR        = scenetree.findObject("startTrigger_R"),
            endTriggerL          = scenetree.findObject("endTrigger_L"),
            endTriggerR          = scenetree.findObject("endTrigger_R"),
            laneTriggerL         = scenetree.findObject("laneTrigger_L"),
            laneTriggerR         = scenetree.findObject("laneTrigger_R"),
            opponentSpawnTrigger = scenetree.findObject("opponentSpawnTrigger")
        }

        log("D", logTag, "triggers: " .. dumps(triggers))
    end
    -- if state == 2 then
    --     core_gamestate.setGameState("multiplayer", "multiplayer", "multiplayer")
    -- end
end

local function onExtensionLoaded()
    log('I', logTag, "DragMP Loaded")
end

local function onExtensionUnloaded()
    log('I', logTag, "DragMP Unloaded")
end

M.onVehicleDestroyed = onVehicleDestroyed
M.onVehicleResetted = onVehicleResetted
M.onPreRender = onPreRender
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onWorldReadyState = onWorldReadyState
M.onBeamNGTrigger = onBeamNGTrigger

return M
