
do
	local okUniversal, made = pcall(PotentUniversal.install, {
		UI = UI, Config = Config, connections = BeyRivals.connections, gui = BeyRivals.gui,
		alive = function()
			return BeyRivals.alive
		end,
	})
	if okUniversal then
		BeyRivals.universal = made
	else
		warn("[Twenty One] Universal tools: " .. tostring(made))
	end
end
UI.finish("Home")

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
	statusLabel.Text = BeyRivals.status or "Twenty One"
end))

function BeyRivals.detach()
	BeyRivals.alive = false
	BeyRivals.detached = true
	saveSettings()
	if BeyRivals.universal then
		pcall(BeyRivals.universal.stop)
	end
	for _, connection in ipairs(BeyRivals.connections) do
		connection:Disconnect()
	end
	if BeyRivals.gui then
		BeyRivals.gui:Destroy()
	end
	if shared.TwentyOne == BeyRivals then
		shared.TwentyOne = nil
	end
end
shared.TwentyOne = BeyRivals
getgenv().TwentyOneConfig = Config
table.insert(BeyRivals.connections, runService.Heartbeat:Connect(function()
	if shared.TwentyOne ~= BeyRivals then
		BeyRivals.detach()
	end
end))
