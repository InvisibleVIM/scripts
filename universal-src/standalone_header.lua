-- Potent Universal: the Universal tools on their own, for any game Potent Hub has no script for.
-- Right Ctrl shows and hides the menu. Settings are kept in the executor's workspace/Universal.
local loadToken = {}
getgenv().PotentUniversalLoadToken = loadToken
if not game:IsLoaded() then
	game.Loaded:Wait()
end
game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 30)
task.wait(2)
if getgenv().PotentUniversalLoadToken ~= loadToken then
	return
end
if not shared then
	return warn("No shared, no script.")
end
loadstring("getfenv().LPH_NO_VIRTUALIZE = function(...) return ... end")()

local BeyRivals = { connections = {}, toggleRefreshers = {}, segmentRefreshers = {}, VERSION = "universal-1", alive = true }
if shared.PotentUniversal then
	pcall(shared.PotentUniversal.detach)
end

-- Services.
