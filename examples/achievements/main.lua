import "../../pulp_switcher"
import "achievements/all"

if config.toastConfig.pauseWhileToasting == nil then
    config.toastConfig.pauseWhileToasting = true
end
if config.toastConfig.miniMode == nil then
    config.toastConfig.miniMode = true
end
config.toastConfig.renderMode = "manual"

local pwt = config.toastConfig.pauseWhileToasting
local first_run = true
local pulp_buffer
addHook(function()
    if first_run then
        first_run = false
        achievements.initialize(config.achData or {})
        achievements.toasts.initialize(config.toastConfig)
        achievements.viewer.initialize(config.viewerConfig)
    end

	local pdup = playdate.update
	playdate.update = function()
        if achievements.toasts.isToasting() then
            if pulp_buffer then
                pulp_buffer:draw(0, 0)
            end
            if not pwt then
                pdup()
            end
            pulp_buffer = playdate.graphics.getWorkingImage()
            achievements.toasts.manualUpdate()
        else
            pulp_buffer = nil
            pdup()
        end
	end
end)

playdate.gameWillTerminate = function()
    achievements.save()
end

local sndsec = playdate.sound.getCurrentTime
local lastsec, behindsec = 0, 0
playdate.sound.getCurrentTime = function()
    return sndsec() - behindsec
end
local sndres = playdate.sound.resetTime
playdate.sound.resetTime = function()
    behindsec = 0
    sndres()
end

local sysmenu = playdate.getSystemMenu()
local function launchviewer_tracksec()
    lastsec = sndsec()
    achievements.viewer.launch()
end
local function return_calc_behindsec()
    local newsec = sndsec()
    behindsec = behindsec + (newsec - lastsec)
end
config.viewerConfig = config.viewerConfig or {}
config.viewerConfig.returnToGameFunction = return_calc_behindsec
sysmenu:addMenuItem("cheevos", launchviewer_tracksec)