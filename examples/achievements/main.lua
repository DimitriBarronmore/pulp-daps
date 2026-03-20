import "../../pulp_switcher"

defaultPDX = "game1"
-- setReturnMenu("reset", nil)

import "achievements/all"

local data = {
    achievements = {
        {
            id = "my_achievement_1",
            name = "Achievement 1",
            description = "Achievement 1 Description",
        },
        {
            id = "my_progress_achievement",
            name = "My Progress Achievement",
            description = "My Progress Achievement description",
            progressMax = 5,
        },
        {
            id = "disks",
            name = "Collect Disks",
            description = "Collect Disks",
            progressMax = 5,
        }
	}
}

achievements.initialize(data)
achievements.toasts.initialize{
    toastOnGrant = "true",
    -- toastOnAdvance = "true",
}

local pulp_buffer = playdate.graphics.getDisplayImage()
addHook(function()
	local pdup = playdate.update
	playdate.update = function()
        if not achievements.toasts.isToasting() then
            playdate.graphics.lockFocus(pulp_buffer)
            pdup()
            playdate.graphics.unlockFocus()
        end
        pulp_buffer:draw(0, 0)
	end
end)

playdate.gameWillTerminate = function()
    achievements.save()
end

local sysmenu = playdate.getSystemMenu()
sysmenu:addMenuItem("cheevos", achievements.viewer.launch)