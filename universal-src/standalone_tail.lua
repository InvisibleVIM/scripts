
local universalState
do
	local okUniversal, made = pcall(PotentUniversal.install, {
		UI = UI, Config = Config, connections = BeyRivals.connections, gui = BeyRivals.gui, shared = true,
		alive = function()
			return BeyRivals.alive
		end,
	})
	if okUniversal then
		universalState = made
	else
		warn("[Potent Universal] " .. tostring(made))
	end
end
UI.finish("Movement")

-- Autosave whenever a setting changes.
do
	local lastSaved = encodeSettings()
	local elapsed = 0
	table.insert(BeyRivals.connections, runService.Heartbeat:Connect(function(dt)
		elapsed = elapsed + dt
		if elapsed < 0.5 then
			return
		end
		elapsed = 0
		local encoded = encodeSettings()
		if encoded ~= lastSaved then
			lastSaved = encoded
			saveSettings()
		end
	end))
end
table.insert(BeyRivals.connections, runService.Heartbeat:Connect(function()
	statusLabel.Text = "Universal"
end))

function BeyRivals.detach()
	BeyRivals.alive = false
	BeyRivals.detached = true
	saveSettings()
	if universalState then
		pcall(universalState.stop)
	end
	for _, connection in ipairs(BeyRivals.connections) do
		connection:Disconnect()
	end
	if BeyRivals.gui then
		BeyRivals.gui:Destroy()
	end
	if shared.PotentUniversal == BeyRivals then
		shared.PotentUniversal = nil
	end
end
BeyRivals.universal = universalState
shared.PotentUniversal = BeyRivals
getgenv().PotentUniversalConfig = Config
table.insert(BeyRivals.connections, runService.Heartbeat:Connect(function()
	if shared.PotentUniversal ~= BeyRivals then
		BeyRivals.detach()
	end
end))
