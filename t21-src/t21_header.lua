-- Potent: Twenty One. Right Ctrl shows and hides the menu.
-- Settings and the play-by-play log are kept in the executor's workspace/TwentyOne.
local loadToken = {}
getgenv().TwentyOneLoadToken = loadToken
if not game:IsLoaded() then
	game.Loaded:Wait()
end
game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 30)
task.wait(3)
if getgenv().TwentyOneLoadToken ~= loadToken then
	return
end
if not shared then
	return warn("No shared, no script.")
end
loadstring("getfenv().LPH_NO_VIRTUALIZE = function(...) return ... end")()

local BeyRivals = { connections = {}, toggleRefreshers = {}, segmentRefreshers = {}, VERSION = "t21-3", alive = true }
if shared.TwentyOne then
	pcall(shared.TwentyOne.detach)
end
if shared.PotentUniversal then
	pcall(shared.PotentUniversal.detach)
end

-- Services.
