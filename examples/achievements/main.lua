import "../../pulp_switcher"
import "achievements/all"

-- setReturnMenu("reset", nil)

if config.toastConfig.pauseWhileToasting == nil then
    config.toastConfig.pauseWhileToasting = true
end

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
            if not pulp_buffer then
                 pulp_buffer = playdate.graphics.getDisplayImage()
            end
            playdate.graphics.lockFocus(pulp_buffer)
            pdup()
            playdate.graphics.unlockFocus()
            pulp_buffer:draw(0, 0)
        else
            pulp_buffer = nil
            pdup()
        end
	end
end)

playdate.gameWillTerminate = function()
    achievements.save()
end

local sysmenu = playdate.getSystemMenu()
sysmenu:addMenuItem("cheevos", achievements.viewer.launch)