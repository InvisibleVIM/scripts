-- Potent: Epic Minigames. Right Ctrl shows and hides the menu.
-- Settings, the log and the minigame recordings are kept in the executor's workspace/EpicMinigames.
local loadToken = {}
getgenv().EpicMinigamesLoadToken = loadToken
if not game:IsLoaded() then
	game.Loaded:Wait()
end
game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 30)
task.wait(3)
if getgenv().EpicMinigamesLoadToken ~= loadToken then
	return
end
if not shared then
	return warn("No shared, no script.")
end
loadstring("getfenv().LPH_NO_VIRTUALIZE = function(...) return ... end")()

local BeyRivals = { connections = {}, toggleRefreshers = {}, segmentRefreshers = {}, VERSION = "em-30", alive = true }
if shared.EpicMinigames then
	pcall(shared.EpicMinigames.detach)
end
if shared.PotentUniversal then
	pcall(shared.PotentUniversal.detach)
end

-- Services.
