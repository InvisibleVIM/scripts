-- ============================================================
-- Universal tools: the same set in every game. A host script (a game's own script, or the
-- standalone Universal one) hands over its menu kit and its settings table; this block adds the
-- pages (group "Universal") and runs every feature off the settings, so a switch in the menu, a
-- key bound to it and a saved setting are all the same thing. Fly is Infinite Yield's (sFLY /
-- NOFLY: BodyGyro + BodyVelocity on the root, W A S D and Q E, 50 studs a second times the
-- speed); max zoom is its maxzoom (CameraMaxZoomDistance); spectate is its view.
-- ============================================================
local PotentUniversal = {}
PotentUniversal.DEFAULTS = {
--@DEFAULTS@
}
-- The keys a game starts with until you set your own there.
PotentUniversal.BINDS = { --@BINDS@ }
-- Every switch, in menu order. Each one can have a key (settings key "K_" .. key), and can show
-- that key beside itself (settings key "P_" .. key).
PotentUniversal.TOGGLES = --@TOGGLES@
---host: { UI, Config, connections, alive = function, gui = ScreenGui, ownsClip, ownsAfk }
function PotentUniversal.install(host)
	local UI, Config = host.UI, host.Config
	local players = game:GetService("Players")
	local runService = game:GetService("RunService")
	local input = game:GetService("UserInputService")
	local lighting = game:GetService("Lighting")
	local teleports = game:GetService("TeleportService")
	local httpService = game:GetService("HttpService")
	local me = players.LocalPlayer
	local U = { saved = {}, esp = {}, marks = {}, deleted = {} }
	PotentUniversal.state = U
	for key, value in pairs(PotentUniversal.DEFAULTS) do
		if Config[key] == nil or type(Config[key]) ~= type(value) then
			Config[key] = value
		end
	end
	-- These never start by themselves when the script loads.
	for _, key in ipairs({ --@SESSION_OFF@ }) do
		Config[key] = false
	end
	local function alive()
		return host.alive()
	end
	local function hook(signal, fn)
		local connection = signal:Connect(fn)
		table.insert(host.connections, connection)
		return connection
	end
	local function character()
		return me.Character
	end
	local function humanoid()
		local model = me.Character
		return model and model:FindFirstChildOfClass("Humanoid")
	end
	local function root()
		local model = me.Character
		return model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso"))
	end
	local function keyOf(name)
		if name == nil or name == "None" or name == "" then
			return nil
		end
		local ok, code = pcall(function()
			return Enum.KeyCode[tostring(name)]
		end)
		return ok and code or nil
	end
	local function typing()
		return input:GetFocusedTextBox() ~= nil or UI.capturing == true
	end
	local function copy(text)
		local set = setclipboard or toclipboard
		if not set then
			return "No clipboard function"
		end
		set(tostring(text))
		return "Copied"
	end
	local function whole(value)
		return tostring(math.floor(value + 0.5))
	end
	local function teleportTo(position)
		local model = character()
		if model and position then
			model:PivotTo(model:GetPivot().Rotation + position + Vector3.new(0, 3.5, 0))
			local part = root()
			if part then
				part.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end
	local holder = Instance.new("Folder")
	holder.Name = "PotentUniversal"
	holder.Parent = host.gui

	-- Keys are kept per game (the universe id, so a game's sub-places share them); which switches
	-- show their key beside them (P_ settings) is the same everywhere. USER: "the toggles i've
	-- chosen to have the keybind button next to should save for all games but the actual keybinds
	-- should only save per game". The K_ settings are the keys of the game you are in: read from
	-- UBinds when the script loads, written back whenever one changes.
	local GAME = tostring(game.GameId)
	local function bindsRead()
		local ok, all = pcall(function()
			return httpService:JSONDecode(Config.UBinds)
		end)
		return (ok and type(all) == "table") and all or {}
	end
	-- USER: "nothing should be keybinded in a game i haven't set up until i set the keybind for it
	-- ... Keep panic keybinded on end though." Earlier builds wrote Fly = F and Free camera = P into
	-- every game they loaded in; those two are cleared once from what was saved.
	if Config.UBindsRev ~= 2 then
		local all = bindsRead()
		for _, saved in pairs(all) do
			if type(saved) == "table" then
				if saved.K_UFly == "F" then
					saved.K_UFly = "None"
				end
				if saved.K_UFreecam == "P" then
					saved.K_UFreecam = "None"
				end
			end
		end
		Config.UBinds = httpService:JSONEncode(all)
		Config.UBindsRev = 2
	end
	do
		local mine = bindsRead()[GAME]
		for _, entry in ipairs(PotentUniversal.TOGGLES) do
			local name = "K_" .. entry.key
			if type(mine) == "table" then
				Config[name] = type(mine[name]) == "string" and mine[name] or "None"
			else
				Config[name] = PotentUniversal.BINDS[entry.key] or "None"
			end
		end
		Config.UPanicKey = type(mine) == "table" and type(mine.UPanicKey) == "string" and mine.UPanicKey or "End"
	end
	local function bindsStep()
		local now = { UPanicKey = Config.UPanicKey }
		for _, entry in ipairs(PotentUniversal.TOGGLES) do
			now["K_" .. entry.key] = Config["K_" .. entry.key]
		end
		local text = httpService:JSONEncode(now)
		if text ~= U.bindsText then
			local first = U.bindsText == nil
			U.bindsText = text
			local all = bindsRead()
			if not first or all[GAME] == nil then
				all[GAME] = now
				Config.UBinds = httpService:JSONEncode(all)
			end
		end
	end
	local KEY_NAMES = { None = "Not set", LeftControl = "L Ctrl", RightControl = "R Ctrl", LeftShift = "L Shift", RightShift = "R Shift", LeftAlt = "L Alt", RightAlt = "R Alt" }
	---Click a button, press a key: stored under the settings key. Backspace clears, Escape keeps.
	local function capture(button, settingKey, done)
		UI.capturing = true
		button.Text = "Press a key"
		local connection
		connection = input.InputBegan:Connect(function(pressed)
			if pressed.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			connection:Disconnect()
			if pressed.KeyCode == Enum.KeyCode.Backspace then
				Config[settingKey] = "None"
			elseif pressed.KeyCode ~= Enum.KeyCode.Escape then
				Config[settingKey] = pressed.KeyCode.Name
			end
			task.defer(function()
				UI.capturing = false
			end)
			pcall(UI.refreshAll)
			if done then
				done()
			end
		end)
	end
	local function small(parent, width)
		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(1, 0)
		button.Size = UDim2.fromOffset(width, 22)
		button.BackgroundColor3 = UI.roles and UI.roles.Control or Color3.fromRGB(40, 40, 40)
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Font = Enum.Font.GothamMedium
		button.TextSize = 12
		button.TextColor3 = UI.roles and UI.roles.Font or Color3.fromRGB(240, 240, 240)
		button.TextTruncate = Enum.TextTruncate.AtEnd
		button.ZIndex = 5
		button.Parent = parent
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)
		return button
	end
	---A switch row. With its P_ setting on, the switch's key sits beside it and can be set there.
	---USER: "add the ? thing next to settings that may be confusing and put a short description of
	---what the setting does when you hover over the ?". Descriptions are a "?" beside the row,
	---never a line of text under its name.
	local function tip(page, note)
		if note and note ~= "" and UI.hint then
			UI.hint(page, note)
		end
	end
	local function switch(page, text, key, note)
		local row = UI.toggle(page, text, key)
		if typeof(row) ~= "Instance" then
			return row
		end
		tip(page, note)
		local mark = row:FindFirstChild("Tip")
		local markAt = mark and mark.Position
		local keyButton = small(row, 66)
		keyButton.Position = UDim2.new(1, -44, 0, 0)
		-- The row's caption gives up the room the button takes.
		local captionFrame, captionSize
		for _, child in ipairs(row:GetChildren()) do
			if child:IsA("GuiObject") and child ~= keyButton and child.Size.X.Scale == 1 then
				captionFrame, captionSize = child, child.Size
			end
		end
		local function refresh()
			local shown = Config["P_" .. key] == true
			keyButton.Visible = shown
			local name = tostring(Config["K_" .. key] or "None")
			keyButton.Text = KEY_NAMES[name] or name
			keyButton.BackgroundColor3 = UI.roles and UI.roles.Control or keyButton.BackgroundColor3
			keyButton.TextColor3 = UI.roles and (name == "None" and UI.roles.Muted or UI.roles.Font) or keyButton.TextColor3
			if mark then
				-- The "?" steps left of the key button.
				mark.Position = shown and UDim2.new(markAt.X.Scale, markAt.X.Offset - 72, markAt.Y.Scale, markAt.Y.Offset) or markAt
			end
			if captionFrame then
				captionFrame.Size = shown and UDim2.new(captionSize.X.Scale, captionSize.X.Offset - 72, captionSize.Y.Scale, captionSize.Y.Offset) or captionSize
			end
		end
		keyButton.MouseButton1Click:Connect(function()
			capture(keyButton, "K_" .. key, refresh)
		end)
		table.insert(UI.refreshers, refresh)
		refresh()
		return row
	end
	---A slider whose number can also be typed (click the number). A typed value may go past the
	---slider's ends; dragging the slider brings it back inside them.
	local function slide(page, text, key, minValue, maxValue, step, format, note)
		local row = UI.slider(page, text, key, minValue, maxValue, step, format)
		if typeof(row) ~= "Instance" then
			return row
		end
		tip(page, note)
		local shown
		for _, object in ipairs(row:GetDescendants()) do
			if object:IsA("TextLabel") and object.AnchorPoint.X == 1 and object.TextXAlignment == Enum.TextXAlignment.Right then
				shown = object
			end
		end
		if not shown then
			return row
		end
		local box = Instance.new("TextBox")
		box.AnchorPoint, box.Position, box.Size = shown.AnchorPoint, shown.Position, shown.Size
		box.BackgroundTransparency = 1
		box.ClearTextOnFocus = false
		box.Text = ""
		box.PlaceholderText = ""
		box.FontFace = shown.FontFace
		box.TextSize = shown.TextSize
		box.TextColor3 = shown.TextColor3
		box.TextXAlignment = Enum.TextXAlignment.Right
		box.ZIndex = shown.ZIndex + 1
		box.Parent = shown.Parent
		box.Focused:Connect(function()
			shown.TextTransparency = 1
			box.TextColor3 = shown.TextColor3
			box.Text = tostring(Config[key])
			box.CursorPosition = #box.Text + 1
		end)
		box.FocusLost:Connect(function()
			local typed = tonumber((box.Text:gsub("[^%d%.%-]", "")))
			if typed and typed == typed and math.abs(typed) < 1e9 then
				Config[key] = typed
			end
			box.Text = ""
			shown.TextTransparency = 0
			pcall(UI.refreshAll)
		end)
		return row
	end

	-- Fly (Infinite Yield's sFLY / NOFLY) ---------------------------------------------------
	local fly = { on = false }
	function fly.stop()
		fly.on = false
		if fly.gyro then
			fly.gyro:Destroy()
		end
		if fly.velocity then
			fly.velocity:Destroy()
		end
		fly.gyro, fly.velocity, fly.root = nil, nil, nil
		local human = humanoid()
		if human then
			human.PlatformStand = false
		end
	end
	function fly.start()
		local part = root()
		if not part then
			return
		end
		fly.stop()
		fly.on, fly.root = true, part
		local gyro = Instance.new("BodyGyro")
		local velocity = Instance.new("BodyVelocity")
		gyro.P = 9e4
		gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
		gyro.CFrame = part.CFrame
		velocity.Velocity = Vector3.zero
		velocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
		gyro.Parent, velocity.Parent = part, part
		fly.gyro, fly.velocity = gyro, velocity
	end
	function fly.step()
		local want = Config.UFly == true
		if want and (not fly.on or not fly.root or not fly.root.Parent or fly.root ~= root()) then
			fly.start()
		elseif not want and fly.on then
			fly.stop()
		end
		if not fly.on or not fly.velocity then
			return
		end
		local camera = workspace.CurrentCamera
		local human = humanoid()
		if human and not Config.UFlyVehicle then
			human.PlatformStand = true
		end
		local speed = tonumber(Config.UFlySpeed) or 1
		local F, B, L, R, Q, E = 0, 0, 0, 0, 0, 0
		if not typing() then
			F = input:IsKeyDown(Enum.KeyCode.W) and speed or 0
			B = input:IsKeyDown(Enum.KeyCode.S) and -speed or 0
			L = input:IsKeyDown(Enum.KeyCode.A) and -speed or 0
			R = input:IsKeyDown(Enum.KeyCode.D) and speed or 0
			Q = input:IsKeyDown(Enum.KeyCode.E) and speed * 2 or 0
			E = input:IsKeyDown(Enum.KeyCode.Q) and -speed * 2 or 0
		end
		if L + R ~= 0 or F + B ~= 0 or Q + E ~= 0 then
			fly.velocity.Velocity = ((camera.CFrame.LookVector * (F + B)) + ((camera.CFrame * CFrame.new(L + R, (F + B + Q + E) * 0.2, 0).Position) - camera.CFrame.Position)) * 50
		else
			fly.velocity.Velocity = Vector3.zero
		end
		fly.gyro.CFrame = camera.CFrame
	end

	-- No clip (skipped when the host script already runs it) -----------------------------------
	local clipped = {}
	local function clipStep()
		if host.ownsClip then
			return
		end
		if not Config.NoClip then
			if next(clipped) then
				for part in pairs(clipped) do
					if part.Parent then
						part.CanCollide = true
					end
				end
				table.clear(clipped)
			end
			return
		end
		local model = character()
		for _, part in ipairs(model and model:GetDescendants() or {}) do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
				clipped[part] = true
			end
		end
	end

	-- Walk speed, jump, gravity, bunny hop, air walk, float, spin ---------------------------------
	local function bodyStep()
		local human, part = humanoid(), root()
		if human then
			if Config.USpeedOn then
				if U.saved.speed == nil then
					U.saved.speed = human.WalkSpeed
				end
				human.WalkSpeed = tonumber(Config.USpeed) or 16
			elseif U.saved.speed ~= nil then
				human.WalkSpeed = U.saved.speed
				U.saved.speed = nil
			end
			if Config.UJumpOn then
				if U.saved.jump == nil then
					U.saved.jump = { power = human.JumpPower, height = human.JumpHeight }
				end
				local power = tonumber(Config.UJump) or 50
				if human.UseJumpPower then
					human.JumpPower = power
				else
					human.JumpHeight = power * power / (2 * 196.2)
				end
			elseif U.saved.jump ~= nil then
				human.JumpPower, human.JumpHeight = U.saved.jump.power, U.saved.jump.height
				U.saved.jump = nil
			end
			-- No ragdoll: the tumbling states are switched off on your own humanoid.
			if Config.UNoRagdoll then
				U.ragdollOff = human
				for _, state in ipairs({ Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.FallingDown }) do
					human:SetStateEnabled(state, false)
					if human:GetState() == state then
						human:ChangeState(Enum.HumanoidStateType.GettingUp)
					end
				end
			elseif U.ragdollOff then
				pcall(function()
					U.ragdollOff:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
					U.ragdollOff:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
				end)
				U.ragdollOff = nil
			end
			if Config.UBhop and human.MoveDirection.Magnitude > 0 and human.FloorMaterial ~= Enum.Material.Air then
				human:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
		if Config.UGravityOn then
			if U.saved.gravity == nil then
				U.saved.gravity = workspace.Gravity
			end
			workspace.Gravity = tonumber(Config.UGravity) or 196.2
		elseif U.saved.gravity ~= nil then
			workspace.Gravity = U.saved.gravity
			U.saved.gravity = nil
		end
		-- Air walk: a see-through slab that stays under your feet at the height you switched it on.
		if Config.UAirWalk and part then
			if not U.slab or not U.slab.Parent then
				local slab = Instance.new("Part")
				slab.Name = "PotentAirWalk"
				slab.Anchored, slab.CanCollide = true, true
				slab.Size = Vector3.new(7, 1, 7)
				slab.Transparency = 0.75
				slab.Material = Enum.Material.ForceField
				slab.Parent = workspace
				U.slab = slab
				U.slabY = part.Position.Y - (human and human.HipHeight or 2) - part.Size.Y / 2 - 0.5
			end
			U.slab.CFrame = CFrame.new(part.Position.X, U.slabY, part.Position.Z)
		elseif U.slab then
			U.slab:Destroy()
			U.slab = nil
		end
		-- Float: holds your height; you still walk sideways.
		if Config.UFloat and part and not fly.on then
			if not U.floatForce or U.floatForce.Parent ~= part then
				if U.floatForce then
					U.floatForce:Destroy()
				end
				local force = Instance.new("BodyVelocity")
				force.MaxForce = Vector3.new(0, 9e9, 0)
				force.Velocity = Vector3.zero
				force.Parent = part
				U.floatForce = force
			end
		elseif U.floatForce then
			U.floatForce:Destroy()
			U.floatForce = nil
		end
		if Config.USpin and part then
			if not U.spin or U.spin.Parent ~= part then
				if U.spin then
					U.spin:Destroy()
				end
				local spin = Instance.new("BodyAngularVelocity")
				spin.MaxTorque = Vector3.new(0, 9e9, 0)
				spin.Parent = part
				U.spin = spin
			end
			U.spin.AngularVelocity = Vector3.new(0, tonumber(Config.USpinSpeed) or 10, 0)
		elseif U.spin then
			U.spin:Destroy()
			U.spin = nil
		end
	end

	-- Camera -------------------------------------------------------------------------------------
	local freecam = { on = false }
	function freecam.stop()
		if not freecam.on then
			return
		end
		freecam.on = false
		local camera = workspace.CurrentCamera
		camera.CameraType = freecam.type or Enum.CameraType.Custom
		local human = humanoid()
		if human then
			camera.CameraSubject = human
		end
		if freecam.anchored and freecam.anchored.Parent then
			freecam.anchored.Anchored = false
		end
		freecam.anchored = nil
		input.MouseBehavior = Enum.MouseBehavior.Default
	end
	function freecam.start()
		local camera = workspace.CurrentCamera
		freecam.on, freecam.type, freecam.cf = true, camera.CameraType, camera.CFrame
		local x, y = camera.CFrame:ToOrientation()
		freecam.pitch, freecam.yaw = x, y
		camera.CameraType = Enum.CameraType.Scriptable
		local part = root()
		if part and not part.Anchored then
			part.Anchored = true
			freecam.anchored = part
		end
	end
	function freecam.step(dt)
		if Config.UFreecam and not freecam.on then
			freecam.start()
		elseif not Config.UFreecam and freecam.on then
			freecam.stop()
		end
		if not freecam.on then
			return
		end
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		if input:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			input.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			local delta = input:GetMouseDelta()
			freecam.yaw -= delta.X * 0.004
			freecam.pitch = math.clamp(freecam.pitch - delta.Y * 0.004, -1.5, 1.5)
		else
			input.MouseBehavior = Enum.MouseBehavior.Default
		end
		local move = Vector3.zero
		if not typing() then
			local function axis(plus, minus)
				return (input:IsKeyDown(plus) and 1 or 0) - (input:IsKeyDown(minus) and 1 or 0)
			end
			move = Vector3.new(axis(Enum.KeyCode.D, Enum.KeyCode.A), axis(Enum.KeyCode.E, Enum.KeyCode.Q), -axis(Enum.KeyCode.W, Enum.KeyCode.S))
		end
		local speed = (tonumber(Config.UFreecamSpeed) or 60) * (input:IsKeyDown(Enum.KeyCode.LeftShift) and 3 or 1)
		local rotation = CFrame.fromOrientation(freecam.pitch, freecam.yaw, 0)
		freecam.cf = CFrame.new(freecam.cf.Position + rotation:VectorToWorldSpace(move) * speed * dt) * rotation
		camera.CFrame = freecam.cf
	end
	---A property held at a value while a switch is on, put back when it goes off.
	local function hold(name, on, object, property, value)
		if on then
			if U.saved[name] == nil then
				U.saved[name] = { object = object, value = object[property] }
			end
			if object[property] ~= value then
				object[property] = value
			end
		elseif U.saved[name] ~= nil then
			pcall(function()
				U.saved[name].object[property] = U.saved[name].value
			end)
			U.saved[name] = nil
		end
	end
	local function cameraStep()
		local camera = workspace.CurrentCamera
		hold("fov", Config.UFovOn, camera, "FieldOfView", tonumber(Config.UFov) or 70)
		hold("zoom", Config.UZoomOn, me, "CameraMaxZoomDistance", tonumber(Config.UZoom) or 400)
		hold("sens", Config.USensOn, input, "MouseDeltaSensitivity", tonumber(Config.USens) or 1)
		local mode = Config.UFirstPerson and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic
		hold("mode", Config.UFirstPerson or Config.UThirdPerson, me, "CameraMode", mode)
		if Config.UThirdPerson and not Config.UFirstPerson and not Config.UZoomOn and me.CameraMaxZoomDistance < 20 then
			me.CameraMaxZoomDistance = 100
		end
		hold("bright", Config.UFullbright, lighting, "Brightness", 2)
		hold("clock", Config.UFullbright, lighting, "ClockTime", 14)
		hold("shadows", Config.UFullbright or Config.UNoShadows, lighting, "GlobalShadows", false)
		hold("ambient", Config.UFullbright, lighting, "Ambient", Color3.fromRGB(178, 178, 178))
		hold("outdoor", Config.UFullbright, lighting, "OutdoorAmbient", Color3.fromRGB(178, 178, 178))
		hold("fog", Config.UFullbright or Config.UNoFog, lighting, "FogEnd", 1e6)
		local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere then
			hold("haze", Config.UNoFog, atmosphere, "Density", 0)
		end
		if Config.UFpsCapOn and setfpscap then
			local cap = math.floor(tonumber(Config.UFpsCap) or 240)
			if U.capSet ~= cap then
				U.capSet = cap
				pcall(setfpscap, cap >= 1000 and 0 or cap)
			end
		elseif U.capSet then
			U.capSet = nil
			pcall(setfpscap, 60)
		end
		-- The game's own interface, hidden (ours lives outside PlayerGui).
		local playerGui = me:FindFirstChildOfClass("PlayerGui")
		if Config.UHideGui and playerGui then
			U.hidden = U.hidden or {}
			for _, gui in ipairs(playerGui:GetChildren()) do
				if gui:IsA("ScreenGui") and gui.Enabled then
					gui.Enabled = false
					U.hidden[gui] = true
				end
			end
		elseif U.hidden then
			for gui in pairs(U.hidden) do
				if gui.Parent then
					gui.Enabled = true
				end
			end
			U.hidden = nil
		end
	end
	---Every frame: my own character's look (the camera scripts write these too).
	local function selfStep()
		local model = character()
		if not model then
			return
		end
		local alpha = Config.UHideSelf and math.clamp(tonumber(Config.USelfAlpha) or 1, 0, 1) or 0
		if alpha > 0 or Config.UNoAccessories or U.selfDirty then
			U.selfDirty = alpha > 0 or Config.UNoAccessories
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					local inAccessory = part.Parent and part.Parent:IsA("Accessory")
					part.LocalTransparencyModifier = (inAccessory and Config.UNoAccessories) and 1 or alpha
				end
			end
		end
	end
	local function animStep()
		local human = humanoid()
		local animator = human and human:FindFirstChildOfClass("Animator")
		if not animator or not (Config.UNoAnim or Config.UAnimSpeedOn or U.animDirty) then
			return
		end
		U.animDirty = Config.UNoAnim or Config.UAnimSpeedOn
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			if Config.UNoAnim then
				track:Stop(0)
			else
				track:AdjustSpeed(Config.UAnimSpeedOn and (tonumber(Config.UAnimSpeed) or 1) or 1)
			end
		end
	end

	-- Spectate (Infinite Yield's view) and follow ----------------------------------------------
	local function watchStep()
		local target = U.viewing
		if target and target.Parent ~= players then
			U.viewing, target = nil, nil
		end
		local camera = workspace.CurrentCamera
		if target then
			local human = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
			if human and camera.CameraSubject ~= human and not freecam.on then
				camera.CameraSubject = human
			end
			U.wasViewing = true
		elseif U.wasViewing then
			U.wasViewing = nil
			local human = humanoid()
			if human then
				camera.CameraSubject = human
			end
		end
		if Config.UFollow then
			local player = U.pick and players:FindFirstChild(U.pick)
			local theirs = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local model = character()
			if theirs and model then
				model:PivotTo(theirs.CFrame * CFrame.new(0, 0, 4))
			end
		end
	end

	-- ESP ----------------------------------------------------------------------------------------
	local function tag(parent)
		local board = Instance.new("BillboardGui")
		board.AlwaysOnTop = true
		board.Size = UDim2.fromOffset(240, 40)
		board.StudsOffset = Vector3.new(0, 2.8, 0)
		board.Parent = parent
		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, 0, 0, 18)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamMedium
		text.TextSize = 13
		text.TextStrokeTransparency = 0.4
		text.Parent = board
		return board, text
	end
	local function espClear(player)
		local entry = U.esp[player]
		if entry then
			entry.highlight:Destroy()
			entry.board:Destroy()
			if entry.line then
				pcall(function()
					entry.line:Remove()
				end)
			end
			for _, bone in ipairs(entry.bones or {}) do
				pcall(function()
					bone:Remove()
				end)
			end
			U.esp[player] = nil
		end
	end
	local function espStep()
		if not Config.UEsp then
			for player in pairs(U.esp) do
				espClear(player)
			end
			return
		end
		local mine = root()
		for player in pairs(U.esp) do
			if player.Parent ~= players then
				espClear(player)
			end
		end
		for _, player in ipairs(players:GetPlayers()) do
			if player ~= me then
				local model = player.Character
				local head = model and (model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart"))
				local human = model and model:FindFirstChildOfClass("Humanoid")
				local distance = (head and mine) and (head.Position - mine.Position).Magnitude or 0
				local mate = Config.UEspTeamCheck and player.Team ~= nil and player.Team == me.Team
				if not head or mate or distance > (tonumber(Config.UEspRange) or 2000) then
					espClear(player)
				else
					local entry = U.esp[player]
					if not entry then
						local highlight = Instance.new("Highlight")
						highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						highlight.FillTransparency = 0.8
						highlight.Parent = holder
						local board, text = tag(holder)
						local back = Instance.new("Frame")
						back.Position = UDim2.new(0.25, 0, 0, 22)
						back.Size = UDim2.new(0.5, 0, 0, 4)
						back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
						back.BorderSizePixel = 0
						back.Parent = board
						local bar = Instance.new("Frame")
						bar.Size = UDim2.fromScale(1, 1)
						bar.BorderSizePixel = 0
						bar.Parent = back
						entry = { highlight = highlight, board = board, text = text, back = back, bar = bar }
						U.esp[player] = entry
					end
					local color = (Config.UEspTeam and player.Team and player.TeamColor.Color) or Color3.fromRGB(255, 80, 80)
					entry.highlight.Adornee = model
					entry.highlight.Enabled = Config.UEspChams == true
					entry.highlight.FillColor, entry.highlight.OutlineColor = color, color
					entry.board.Adornee = head
					local parts = {}
					if Config.UEspNames then
						table.insert(parts, player.DisplayName ~= player.Name and (player.DisplayName .. " (@" .. player.Name .. ")") or player.Name)
					end
					if Config.UEspDistance then
						table.insert(parts, string.format("%d studs", distance))
					end
					entry.text.Text = table.concat(parts, "  ")
					entry.text.TextColor3 = color
					entry.back.Visible = Config.UEspHealth == true and human ~= nil
					if human then
						local share = math.clamp(human.Health / math.max(human.MaxHealth, 1), 0, 1)
						entry.bar.Size = UDim2.fromScale(share, 1)
						entry.bar.BackgroundColor3 = Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(80, 220, 110), share)
					end
					entry.root, entry.color, entry.model = head, color, model
				end
			end
		end
	end
	local BONES = {
		{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
		{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
		{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
		{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
		{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
		{ "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
	}
	---Tracers: a line from the bottom of the screen to every ESP player (needs the Drawing API).
	local function tracerStep()
		local can = Drawing ~= nil and Config.UEsp and Config.UEspTracers
		local camera = workspace.CurrentCamera
		for _, entry in pairs(U.esp) do
			if can and entry.root and entry.root.Parent then
				if not entry.line then
					local okLine, line = pcall(Drawing.new, "Line")
					if okLine then
						line.Thickness = 1
						entry.line = line
					end
				end
				if entry.line then
					local point, onScreen = camera:WorldToViewportPoint(entry.root.Position)
					entry.line.Visible = onScreen
					entry.line.Color = entry.color
					entry.line.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
					entry.line.To = Vector2.new(point.X, point.Y)
				end
			elseif entry.line then
				entry.line.Visible = false
			end
			-- Skeletons: a line along every limb (R15 and R6 rigs).
			local bonesOn = Drawing ~= nil and Config.UEsp and Config.UEspSkeleton and entry.model and entry.model.Parent
			if bonesOn then
				entry.bones = entry.bones or {}
				local index = 0
				for _, pair in ipairs(BONES) do
					local from, to = entry.model:FindFirstChild(pair[1]), entry.model:FindFirstChild(pair[2])
					if from and to then
						index += 1
						local bone = entry.bones[index]
						if not bone then
							local okBone, made = pcall(Drawing.new, "Line")
							if not okBone then
								break
							end
							made.Thickness = 1.5
							entry.bones[index] = made
							bone = made
						end
						local a, aOn = camera:WorldToViewportPoint(from.Position)
						local b, bOn = camera:WorldToViewportPoint(to.Position)
						bone.Visible = aOn and bOn
						bone.Color = entry.color
						bone.From, bone.To = Vector2.new(a.X, a.Y), Vector2.new(b.X, b.Y)
					end
				end
				for extra = index + 1, #entry.bones do
					entry.bones[extra].Visible = false
				end
			elseif entry.bones then
				for _, bone in ipairs(entry.bones) do
					bone.Visible = false
				end
			end
		end
	end
	---Marks: NPCs, tools, proximity prompts, click detectors and search results get an outline and
	---a name. Looked for again every two seconds. Only those inside the range are marked (the
	---player ESP range for NPCs, the object range for the rest), nearest first, at most MARK_CAP of
	---each. USER: "esp all touch triggers in a 500 stud radius. (let me change the range)".
	local MARK_CAP = 500
	local MARKS = {
		{ key = "UEspNpc", range = "UEspRange", color = Color3.fromRGB(255, 170, 60), find = function(object)
			if object:IsA("Humanoid") and object.Parent and object.Parent:IsA("Model") and not players:GetPlayerFromCharacter(object.Parent) then
				return object.Parent, object.Parent.Name
			end
		end },
		{ key = "UEspTool", color = Color3.fromRGB(90, 200, 255), find = function(object)
			if object:IsA("Tool") and object:FindFirstChild("Handle") and not object:FindFirstAncestorOfClass("Backpack") and not players:GetPlayerFromCharacter(object.Parent) then
				return object, object.Name
			end
		end },
		{ key = "UEspPrompt", color = Color3.fromRGB(120, 255, 140), find = function(object)
			if object:IsA("ProximityPrompt") and object.Parent then
				return object.Parent, (object.ActionText ~= "" and object.ActionText or "Prompt") .. (object.ObjectText ~= "" and (": " .. object.ObjectText) or "")
			end
		end },
		{ key = "UEspTouch", color = Color3.fromRGB(255, 110, 110), find = function(object)
			if object:IsA("TouchTransmitter") and object.Parent and not object.Parent:FindFirstAncestorOfClass("Tool") then
				local model = object.Parent:FindFirstAncestorOfClass("Model")
				if not (model and model:FindFirstChildOfClass("Humanoid")) then
					return object.Parent, "Touch: " .. object.Parent.Name
				end
			end
		end },
		{ key = "UEspClick", color = Color3.fromRGB(230, 130, 255), find = function(object)
			if object:IsA("ClickDetector") and object.Parent then
				return object.Parent, "Click: " .. object.Parent.Name
			end
		end },
	}
	local function markClear(key)
		for _, entry in ipairs(U.marks[key] or {}) do
			entry.highlight:Destroy()
			entry.board:Destroy()
			if entry.edge then
				entry.edge:Destroy()
			end
		end
		U.marks[key] = nil
	end
	local function markSet(key, color, found)
		markClear(key)
		local list = {}
		for index, item in ipairs(found) do
			if index > MARK_CAP then
				break
			end
			-- Roblox draws only about 31 Highlights at a time, so single parts get a see-through
			-- box instead: those have no limit. Models keep the Highlight.
			local highlight
			if item.object:IsA("BasePart") then
				highlight = Instance.new("BoxHandleAdornment")
				highlight.Size = item.object.Size
				highlight.AlwaysOnTop = true
				highlight.ZIndex = 5
				highlight.Transparency = 0.7
				highlight.Color3 = color
				highlight.Adornee = item.object
				highlight.Parent = holder
			else
				highlight = Instance.new("Highlight")
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.FillTransparency = 0.85
				highlight.FillColor, highlight.OutlineColor = color, color
				highlight.Adornee = item.object
				highlight.Parent = holder
			end
			local board, text = tag(holder)
			board.StudsOffset = Vector3.new(0, 1.5, 0)
			board.Adornee = item.object
			text.Text = item.name
			text.TextColor3 = color
			table.insert(list, { highlight = highlight, board = board })
		end
		U.marks[key] = list
	end
	local function markStep()
		local wanted = {}
		for _, kind in ipairs(MARKS) do
			if Config[kind.key] then
				table.insert(wanted, kind)
			elseif U.marks[kind.key] then
				markClear(kind.key)
			end
		end
		if #wanted == 0 or os.clock() - (U.markAt or 0) < 2 then
			return
		end
		U.markAt = os.clock()
		local found = {}
		for _, kind in ipairs(wanted) do
			found[kind.key] = {}
		end
		local part = root()
		local from = part and part.Position or workspace.CurrentCamera.CFrame.Position
		for index, object in ipairs(workspace:GetDescendants()) do
			for _, kind in ipairs(wanted) do
				local target, name = kind.find(object)
				if target then
					local okSpot, spot = pcall(function()
						return target:IsA("BasePart") and target.Position or target:GetPivot().Position
					end)
					local away = okSpot and (spot - from).Magnitude or 0
					if away <= (tonumber(Config[kind.range or "UEspObjRange"]) or 500) then
						table.insert(found[kind.key], { object = target, name = name, away = away })
					end
				end
			end
			if index % 4000 == 0 then
				task.wait()
			end
		end
		for _, kind in ipairs(wanted) do
			table.sort(found[kind.key], function(a, b)
				return a.away < b.away
			end)
			markSet(kind.key, kind.color, found[kind.key])
		end
	end

	-- World: things switched off for you alone, and put back when the switch goes off ----------
	local RULES = {
		UXray = { test = function(object)
			if not object:IsA("BasePart") or object.Name == "PotentAirWalk" then
				return false
			end
			local model = object:FindFirstAncestorOfClass("Model")
			return not (model and model:FindFirstChildOfClass("Humanoid"))
		end, property = "LocalTransparencyModifier", value = 0.65 },
		UNoParticles = { test = function(object)
			return object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") or object:IsA("Fire") or object:IsA("Smoke") or object:IsA("Sparkles")
		end, property = "Enabled", value = false },
		UNoTextures = { test = function(object)
			return object:IsA("Decal") or object:IsA("Texture")
		end, property = "Transparency", value = 1 },
		UNoEffects = { test = function(object)
			return object:IsA("PostEffect")
		end, property = "Enabled", value = false, where = "effects" },
	}
	local ruleSaved = {}
	local function ruleApply(key, rule, object)
		local okTest, match = pcall(rule.test, object)
		if okTest and match then
			ruleSaved[key] = ruleSaved[key] or setmetatable({}, { __mode = "k" })
			if ruleSaved[key][object] == nil then
				ruleSaved[key][object] = object[rule.property]
			end
			object[rule.property] = rule.value
		end
	end
	local function ruleStep()
		for key, rule in pairs(RULES) do
			if Config[key] and not U["rule" .. key] then
				U["rule" .. key] = true
				task.spawn(function()
					local places = rule.where == "effects" and { lighting, workspace.CurrentCamera } or { workspace }
					for _, place in ipairs(places) do
						for index, object in ipairs(place:GetDescendants()) do
							if not Config[key] then
								return
							end
							pcall(ruleApply, key, rule, object)
							if index % 3000 == 0 then
								task.wait()
							end
						end
					end
				end)
			elseif not Config[key] and U["rule" .. key] then
				U["rule" .. key] = nil
				for object, value in pairs(ruleSaved[key] or {}) do
					pcall(function()
						object[rule.property] = value
					end)
				end
				ruleSaved[key] = nil
			end
		end
	end
	hook(workspace.DescendantAdded, function(object)
		for key, rule in pairs(RULES) do
			if Config[key] and rule.where ~= "effects" then
				pcall(ruleApply, key, rule, object)
			end
		end
	end)

	-- FPS and ping tag, crosshair ---------------------------------------------------------------
	local meter = Instance.new("TextLabel")
	meter.Name = "PotentMeter"
	meter.AnchorPoint = Vector2.new(1, 0)
	meter.Position = UDim2.new(1, -12, 0, 8)
	meter.Size = UDim2.fromOffset(170, 24)
	meter.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	meter.BackgroundTransparency = 0.25
	meter.BorderSizePixel = 0
	meter.Font = Enum.Font.GothamMedium
	meter.TextSize = 13
	meter.TextColor3 = Color3.fromRGB(240, 240, 240)
	meter.Visible = false
	meter.ZIndex = 300
	meter.Parent = host.gui
	Instance.new("UICorner", meter).CornerRadius = UDim.new(0, 6)
	local cross = Instance.new("Frame")
	cross.Name = "PotentCrosshair"
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Position = UDim2.fromScale(0.5, 0.5)
	cross.BackgroundTransparency = 1
	cross.Visible = false
	cross.ZIndex = 299
	cross.Parent = host.gui
	local crossH, crossV = Instance.new("Frame"), Instance.new("Frame")
	for _, bar in ipairs({ crossH, crossV }) do
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		bar.BorderColor3 = Color3.fromRGB(0, 0, 0)
		bar.BorderSizePixel = 1
		bar.Parent = cross
	end
	-- Direction indicator: an arrow for where you are moving relative to where you look, and how fast.
	local compass = Instance.new("Frame")
	compass.Name = "PotentDirection"
	compass.AnchorPoint = Vector2.new(0.5, 1)
	compass.Position = UDim2.new(0.5, 0, 1, -90)
	compass.Size = UDim2.fromOffset(70, 70)
	compass.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	compass.BackgroundTransparency = 0.4
	compass.BorderSizePixel = 0
	compass.Visible = false
	compass.ZIndex = 298
	compass.Parent = host.gui
	Instance.new("UICorner", compass).CornerRadius = UDim.new(1, 0)
	local arrow = Instance.new("TextLabel")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.42)
	arrow.Size = UDim2.fromOffset(40, 40)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBold
	arrow.Text = "^"
	arrow.TextSize = 30
	arrow.TextColor3 = Color3.fromRGB(255, 255, 255)
	arrow.ZIndex = 299
	arrow.Parent = compass
	local pace = Instance.new("TextLabel")
	pace.AnchorPoint = Vector2.new(0.5, 1)
	pace.Position = UDim2.new(0.5, 0, 1, -6)
	pace.Size = UDim2.fromOffset(60, 14)
	pace.BackgroundTransparency = 1
	pace.Font = Enum.Font.GothamMedium
	pace.TextSize = 11
	pace.TextColor3 = Color3.fromRGB(230, 230, 230)
	pace.ZIndex = 299
	pace.Parent = compass
	local function compassStep()
		compass.Visible = Config.UDirection == true
		local part = root()
		if not compass.Visible or not part then
			return
		end
		local velocity = part.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local look = workspace.CurrentCamera.CFrame.LookVector
		local speed = flat.Magnitude
		pace.Text = string.format("%d studs/s", speed)
		arrow.Visible = speed > 0.5
		if speed > 0.5 then
			local turn = math.atan2(flat.X, flat.Z) - math.atan2(look.X, look.Z)
			arrow.Rotation = -math.deg(turn)
		end
	end
	-- Camera roll and the steady camera run right after the game's own camera each frame.
	local ROLL_STEP = "PotentUniversalCamera" .. tostring(math.random(1e6))
	pcall(function()
		runService:BindToRenderStep(ROLL_STEP, Enum.RenderPriority.Camera.Value + 1, function()
			if not alive() then
				return
			end
			if Config.UNoShake then
				local human = humanoid()
				if human and human.CameraOffset ~= Vector3.zero then
					human.CameraOffset = Vector3.zero
				end
			end
			if Config.URollOn and not freecam.on then
				local camera = workspace.CurrentCamera
				camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, math.rad(tonumber(Config.URoll) or 0))
			end
		end)
	end)
	local frames, frameClock, fps = 0, os.clock(), 0
	function U.ping()
		local ok, value = pcall(function()
			return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		return ok and tonumber(value) or nil
	end
	local function meterStep()
		meter.Visible = Config.UFps == true or Config.UPing == true
		if meter.Visible then
			local parts = {}
			if Config.UFps then
				table.insert(parts, string.format("%d FPS", fps))
			end
			if Config.UPing then
				local ping = U.ping()
				table.insert(parts, ping and string.format("%d ms", ping) or "ping ?")
			end
			meter.Text = table.concat(parts, "   ")
			meter.Size = UDim2.fromOffset(#parts > 1 and 170 or 90, 24)
		end
		cross.Visible = Config.UCrosshair == true
		local size = tonumber(Config.UCrosshairSize) or 8
		cross.Size = UDim2.fromOffset(size * 2, size * 2)
		crossH.Size, crossV.Size = UDim2.fromOffset(size * 2, 2), UDim2.fromOffset(2, size * 2)
	end

	-- The loops ---------------------------------------------------------------------------------
	hook(runService.RenderStepped, function(dt)
		frames += 1
		if os.clock() - frameClock >= 0.5 then
			fps = frames / (os.clock() - frameClock)
			frames, frameClock = 0, os.clock()
		end
		if not alive() then
			return
		end
		pcall(fly.step)
		pcall(freecam.step, dt)
		pcall(selfStep)
		pcall(tracerStep)
		pcall(compassStep)
	end)
	hook(runService.Stepped, function()
		if alive() then
			pcall(clipStep)
		end
	end)
	task.spawn(function()
		while alive() do
			pcall(bodyStep)
			pcall(cameraStep)
			pcall(animStep)
			pcall(watchStep)
			pcall(espStep)
			pcall(meterStep)
			pcall(ruleStep)
			pcall(bindsStep)
			task.wait(0.15)
		end
	end)
	task.spawn(function()
		while alive() do
			pcall(markStep)
			task.wait(0.5)
		end
	end)
	hook(input.JumpRequest, function()
		if alive() and Config.UInfJump then
			local human = humanoid()
			if human then
				human:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end)
	local PANIC_KEEPS = { UAntiAfk = true, UEspChams = true, UEspNames = true, UEspDistance = true, UEspHealth = true, UEspTracers = true, UEspSkeleton = true, UEspTeam = true, UEspTeamCheck = true, UOffOnDeath = true }
	function U.panic()
		-- Turns every feature off and leaves Anti-AFK, the keys and the option switches (what ESP
		-- draws, and so on) as they are, so a feature switched back on looks the way it did.
		for _, entry in ipairs(PotentUniversal.TOGGLES) do
			if not PANIC_KEEPS[entry.key] then
				Config[entry.key] = false
			end
		end
		U.viewing = nil
		pcall(UI.refreshAll)
		return "Everything off"
	end
	hook(input.InputBegan, function(pressed, processed)
		if not alive() then
			return
		end
		if pressed.UserInputType == Enum.UserInputType.Keyboard and not typing() then
			if pressed.KeyCode == keyOf(Config.UPanicKey) then
				U.panic()
				return
			end
			local changed = false
			for _, entry in ipairs(PotentUniversal.TOGGLES) do
				if pressed.KeyCode == keyOf(Config["K_" .. entry.key]) then
					Config[entry.key] = not Config[entry.key]
					changed = true
				end
			end
			if changed then
				pcall(UI.refreshAll)
			end
		end
		if pressed.UserInputType ~= Enum.UserInputType.MouseButton1 or processed then
			return
		end
		local function aimed()
			local camera = workspace.CurrentCamera
			local at = input:GetMouseLocation()
			local ray = camera:ViewportPointToRay(at.X, at.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { character() }
			return workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
		end
		local deleteKey = keyOf(Config.UDeleteKey)
		if Config.UClickDelete and deleteKey and input:IsKeyDown(deleteKey) then
			local hit = aimed()
			if hit and hit.Instance and not hit.Instance:IsA("Terrain") then
				table.insert(U.deleted, { object = hit.Instance, parent = hit.Instance.Parent })
				hit.Instance.Parent = nil
			end
			return
		end
		if host.ownsClip or not Config.ClickTeleport then
			return
		end
		local key = keyOf(Config.ClickTeleportKey)
		if key and input:IsKeyDown(key) and character() then
			local hit = aimed()
			if hit then
				teleportTo(hit.Position)
			end
		end
	end)
	if not host.ownsAfk then
		hook(me.Idled, function()
			if alive() and Config.UAntiAfk then
				pcall(function()
					local virtual = game:GetService("VirtualUser")
					virtual:CaptureController()
					virtual:ClickButton2(Vector2.new())
				end)
			end
		end)
	end
	local function onCharacter(model)
		local human = model:WaitForChild("Humanoid", 10)
		if human then
			human.Died:Connect(function()
				if alive() and Config.UOffOnDeath then
					for _, key in ipairs({ "UFly", "UFloat", "UAirWalk", "USpin", "UBhop", "UFreecam", "UFollow" }) do
						Config[key] = false
					end
					pcall(UI.refreshAll)
				end
			end)
		end
		-- (Everything else is held by the loops, so it comes back by itself after a respawn.)
		U.saved.speed, U.saved.jump = nil, nil
	end
	hook(me.CharacterAdded, onCharacter)
	if me.Character then
		task.spawn(onCharacter, me.Character)
	end
	hook(players.PlayerAdded, function(player)
		if alive() and Config.UJoinNotes then
			pcall(UI.toast, "Joined", player.DisplayName .. " (@" .. player.Name .. ")", 4)
		end
	end)
	hook(players.PlayerRemoving, function(player)
		if alive() and Config.UJoinNotes then
			pcall(UI.toast, "Left", player.DisplayName .. " (@" .. player.Name .. ")", 4)
		end
	end)

	-- Actions -----------------------------------------------------------------------------------
	function U.reset()
		local human = humanoid()
		if human then
			human.Health = 0
		end
		return "Resetting"
	end
	function U.refresh()
		local model, human = character(), humanoid()
		if not model or not human then
			return "No character"
		end
		local at = model:GetPivot()
		human.Health = 0
		task.spawn(function()
			local fresh = me.CharacterAdded:Wait()
			fresh:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.3)
			pcall(function()
				fresh:PivotTo(at)
			end)
		end)
		return "Respawning here"
	end
	function U.rejoin()
		if #players:GetPlayers() <= 1 then
			teleports:Teleport(game.PlaceId, me)
		else
			teleports:TeleportToPlaceInstance(game.PlaceId, game.JobId, me)
		end
		return "Rejoining"
	end
	function U.serverHop()
		local http = request or http_request
		if not http then
			return "No http request function"
		end
		local ok, response = pcall(http, { Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100", Method = "GET" })
		local okList, list = pcall(function()
			return httpService:JSONDecode(response.Body)
		end)
		local open = {}
		for _, server in ipairs((ok and okList and type(list) == "table" and type(list.data) == "table") and list.data or {}) do
			if server.id ~= game.JobId and (tonumber(server.playing) or 0) < (tonumber(server.maxPlayers) or 0) then
				table.insert(open, server.id)
			end
		end
		if #open == 0 then
			return "No other server found"
		end
		teleports:TeleportToPlaceInstance(game.PlaceId, open[math.random(#open)], me)
		return "Hopping"
	end
	function U.playerOptions()
		local options = {}
		for _, player in ipairs(players:GetPlayers()) do
			if player ~= me then
				table.insert(options, { id = player.Name, name = player.DisplayName ~= player.Name and (player.DisplayName .. " (@" .. player.Name .. ")") or player.Name, current = U.pick == player.Name })
			end
		end
		table.sort(options, function(a, b)
			return a.name:lower() < b.name:lower()
		end)
		return options
	end
	function U.picked()
		return U.pick and players:FindFirstChild(U.pick) or nil
	end
	-- Waypoints, kept per place in the settings.
	local function waypoints()
		local ok, all = pcall(function()
			return httpService:JSONDecode(Config.UWaypoints)
		end)
		all = (ok and type(all) == "table") and all or {}
		local place = tostring(game.PlaceId)
		all[place] = type(all[place]) == "table" and all[place] or {}
		return all, all[place]
	end
	local function waypointSave(all)
		Config.UWaypoints = httpService:JSONEncode(all)
	end

	-- Pages --------------------------------------------------------------------------------------
	do
		local page = UI.makePage("Movement", "Flying, walking through walls, speed and jumping.", "Universal")
		UI.heading(page, "Fly", "left", "Infinite Yield's fly: W A S D to move, E up, Q down.")
		switch(page, "Fly", "UFly", "W A S D to move, E up, Q down. Switches itself off when the script loads.")
		slide(page, "Fly speed", "UFlySpeed", 0.5, 10, 0.5, function(value)
			return string.format("%d studs/s", value * 50)
		end)
		switch(page, "Vehicle fly", "UFlyVehicle", "Leaves your character sitting, so the seat (and the vehicle) flies with you.")
		UI.heading(page, "Through things", "left")
		switch(page, "No clip", "NoClip", "Your character walks through walls and scenery. The floor still holds you.")
		switch(page, "Click teleport", "ClickTeleport", "Hold the key below and click: your character is put where you clicked.")
		UI.keybind(page, "Click teleport key", "ClickTeleportKey")
		tip(page, "Hold this key and click: you are put where you clicked. Click teleport must be on.")
		UI.heading(page, "In the air", "left")
		switch(page, "Infinite jump", "UInfJump", "Jump again in mid-air, as often as you like.")
		switch(page, "Bunny hop", "UBhop", "Jumps the moment you land while you are moving.")
		switch(page, "Air walk", "UAirWalk", "A see-through slab under your feet at the height you switch it on.")
		switch(page, "Float", "UFloat", "Holds your height; you can still move sideways.")
		UI.heading(page, "Walk and jump", "right")
		switch(page, "Set walk speed", "USpeedOn", "On: your walk speed is held at the value below. Off: the game's own speed comes back.")
		slide(page, "Walk speed", "USpeed", 16, 300, 1, whole)
		switch(page, "Set jump power", "UJumpOn", "On: your jump is held at the value below. Off: the game's own jump comes back.")
		slide(page, "Jump power", "UJump", 50, 500, 5, whole, "Games that use jump height get the matching height.")
		switch(page, "Set gravity", "UGravityOn", "On: gravity is held at the value below, for you only. Off: the game's own gravity comes back.")
		slide(page, "Gravity", "UGravity", 5, 196, 1, whole, "The game's normal is 196.")
		switch(page, "Direction indicator", "UDirection", "A small dial at the bottom of the screen: which way you are moving compared with where you look, and how fast.")
		switch(page, "Spin", "USpin", "Turns your character round on the spot.")
		slide(page, "Spin speed", "USpinSpeed", 1, 60, 1, whole)
		UI.button(page, "Reset movement values", function()
			for _, key in ipairs({ "USpeedOn", "UJumpOn", "UGravityOn", "USpin", "UFloat", "UAirWalk", "UBhop", "UInfJump", "UFly" }) do
				Config[key] = false
			end
			Config.USpeed, Config.UJump, Config.UGravity, Config.UFlySpeed, Config.USpinSpeed = 50, 100, 60, 1, 10
			pcall(UI.refreshAll)
			return "Back to the game's own values"
		end)
	end
	do
		local page = UI.makePage("Positions", "Saved spots, waypoints and where you are.", "Universal")
		UI.heading(page, "Where you are", "left")
		local spot, facing = UI.kv(page, "Position"), UI.kv(page, "Facing")
		UI.button(page, "Copy position", function()
			local part = root()
			return part and copy(string.format("%.1f, %.1f, %.1f", part.Position.X, part.Position.Y, part.Position.Z)) or "No character"
		end)
		UI.button(page, "Copy CFrame", function()
			local model = character()
			return model and copy("CFrame.new(" .. tostring(model:GetPivot()) .. ")") or "No character"
		end)
		UI.heading(page, "Saved spot", "left")
		UI.button(page, "Save this spot", function()
			local model = character()
			if not model then
				return "No character"
			end
			U.spot = model:GetPivot()
			return "Saved"
		end)
		UI.button(page, "Return to the saved spot", function()
			local model = character()
			if not model or not U.spot then
				return U.spot and "No character" or "Nothing saved yet"
			end
			model:PivotTo(U.spot)
			return "Back"
		end)
		UI.heading(page, "Waypoints", "right", "Kept for this game between sessions.")
		local nameBox = UI.textbox(page, "Name", "Waypoint name")
		UI.button(page, "Add a waypoint here", function()
			local part = root()
			if not part then
				return "No character"
			end
			local all, list = waypoints()
			local name = nameBox.Text ~= "" and nameBox.Text or ("Waypoint " .. tostring(#list + 1))
			table.insert(list, { name = name, x = part.Position.X, y = part.Position.Y, z = part.Position.Z })
			waypointSave(all)
			U.waypoint = name
			nameBox.Text = ""
			pcall(UI.refreshAll)
			return "Added " .. name
		end)
		UI.cycler(page, "Waypoint", function()
			local _, list = waypoints()
			local options = {}
			for _, entry in ipairs(list) do
				table.insert(options, { id = entry.name, name = entry.name, current = entry.name == U.waypoint })
			end
			return options
		end, function()
			return U.waypoint or "Pick one"
		end, function(option)
			U.waypoint = option.id
		end)
		UI.button(page, "Teleport to the waypoint", function()
			local _, list = waypoints()
			for _, entry in ipairs(list) do
				if entry.name == U.waypoint then
					teleportTo(Vector3.new(entry.x, entry.y - 3.5, entry.z))
					return "Teleported"
				end
			end
			return "Pick a waypoint first"
		end)
		UI.button(page, "Delete the waypoint", function()
			local all, list = waypoints()
			for index, entry in ipairs(list) do
				if entry.name == U.waypoint then
					table.remove(list, index)
					waypointSave(all)
					U.waypoint = nil
					pcall(UI.refreshAll)
					return "Deleted"
				end
			end
			return "Pick a waypoint first"
		end)
		task.spawn(function()
			while alive() and page.Parent do
				local part = root()
				spot.Text = part and string.format("%.0f, %.0f, %.0f", part.Position.X, part.Position.Y, part.Position.Z) or "?"
				local look = part and part.CFrame.LookVector
				facing.Text = look and string.format("%d deg", (math.deg(math.atan2(-look.X, -look.Z)) + 360) % 360) or "?"
				task.wait(0.25)
			end
		end)
	end
	do
		local page = UI.makePage("ESP", "ESP, lighting and a crosshair.", "Universal")
		UI.heading(page, "Player ESP", "left", "Seen through walls.")
		switch(page, "Player ESP", "UEsp")
		switch(page, "Outlines (chams)", "UEspChams", "A coloured glow over each player that shows through walls.")
		switch(page, "Names", "UEspNames")
		switch(page, "Distance", "UEspDistance")
		switch(page, "Health bars", "UEspHealth")
		switch(page, "Tracers", "UEspTracers", Drawing and "A line from the bottom of the screen to each player." or "Your executor has no Drawing API: this one does nothing here.")
		switch(page, "Skeletons", "UEspSkeleton", Drawing and "A line along every limb." or "Your executor has no Drawing API: this one does nothing here.")
		switch(page, "Team colours", "UEspTeam", "Off: everyone is red.")
		switch(page, "Hide teammates", "UEspTeamCheck", "Players on your own team are not marked.")
		slide(page, "Range", "UEspRange", 100, 5000, 100, function(value)
			return whole(value) .. " studs"
		end, "Players farther away than this are not marked.")
		UI.heading(page, "NPC ESP", "right", "Touch triggers, prompts, click detectors and tools are on the World tab.")
		switch(page, "NPCs", "UEspNpc", "Anything with a humanoid that is not a player. Uses the player ESP range and is looked for again every two seconds.")
		UI.heading(page, "Light and aim", "right")
		switch(page, "Fullbright", "UFullbright", "Daylight, no fog, no shadows.")
		switch(page, "Remove fog", "UNoFog", "Only the fog goes; the lighting stays as the game set it.")
		switch(page, "Crosshair", "UCrosshair")
		slide(page, "Crosshair size", "UCrosshairSize", 3, 30, 1, whole)
	end
	do
		local page = UI.makePage("Camera", "Field of view, zoom and a free camera.", "Universal")
		UI.heading(page, "View", "left")
		switch(page, "Set field of view", "UFovOn", "On: the camera's field of view is held at the value below. Roblox's normal is 70.")
		slide(page, "Field of view", "UFov", 30, 120, 1, whole)
		switch(page, "Set max zoom", "UZoomOn", "How far the camera can zoom out (Infinite Yield's maxzoom).")
		slide(page, "Max zoom", "UZoom", 50, 10000, 50, function(value)
			return whole(value) .. " studs"
		end)
		switch(page, "Allow third person", "UThirdPerson", "For games that lock you in first person.")
		switch(page, "First person", "UFirstPerson", "Locks the camera inside your character's head.")
		switch(page, "Set mouse sensitivity", "USensOn", "On: how fast the camera turns with the mouse is held at the value below. 1 is normal.")
		slide(page, "Sensitivity", "USens", 0.1, 5, 0.1, function(value)
			return string.format("%.1fx", value)
		end)
		switch(page, "Roll the camera", "URollOn", "Tilts the view sideways by the angle below.")
		slide(page, "Roll", "URoll", -180, 180, 5, function(value)
			return whole(value) .. " deg"
		end)
		switch(page, "Steady camera", "UNoShake", "Cancels shake that a game does by nudging your character's camera offset. Shake a game applies straight to the camera itself cannot be told apart from normal movement and stays.")
		UI.heading(page, "Free camera", "right", "The camera leaves your character: W A S D, E up, Q down, hold right mouse to look, Shift to go faster.")
		switch(page, "Free camera", "UFreecam", "Your character stays where it is while the camera flies. Switches itself off when the script loads.")
		slide(page, "Camera speed", "UFreecamSpeed", 10, 400, 10, function(value)
			return whole(value) .. " studs/s"
		end)
	end
	do
		local page = UI.makePage("Character", "How your own character looks and moves, on your screen only.", "Universal")
		UI.heading(page, "Look", "left", "Only you see these.")
		switch(page, "Hide my character", "UHideSelf", "For screenshots.")
		slide(page, "How hidden", "USelfAlpha", 0.1, 1, 0.1, function(value)
			return string.format("%d%%", value * 100)
		end, "100% is fully invisible; lower leaves you faintly visible.")
		switch(page, "Hide my accessories", "UNoAccessories", "Hats, hair and other accessories on your character, for you only.")
		UI.heading(page, "Animations", "left")
		switch(page, "Stop my animations", "UNoAnim", "Stops every animation playing on your character.")
		switch(page, "Set animation speed", "UAnimSpeedOn", "On: your animations play at the speed below. 1 is normal.")
		slide(page, "Animation speed", "UAnimSpeed", 0.1, 5, 0.1, function(value)
			return string.format("%.1fx", value)
		end)
		switch(page, "No ragdoll", "UNoRagdoll", "Switches the tumbling and falling-down states off on your character. Games that ragdoll you with their own physics are not affected.")
		UI.heading(page, "Actions", "right")
		UI.button(page, "Sit", function()
			local human = humanoid()
			if human then
				human.Sit = true
			end
			return "Sitting"
		end)
		UI.button(page, "Stand up", function()
			local human = humanoid()
			if human then
				human.Sit = false
				human:ChangeState(Enum.HumanoidStateType.Jumping)
			end
			return "Standing"
		end)
		UI.button(page, "Reset character", function()
			return U.reset()
		end)
		UI.button(page, "Respawn at this spot", function()
			return U.refresh()
		end)
	end
	do
		local page = UI.makePage("World", "Things switched off or removed on your screen only.", "Universal")
		UI.heading(page, "Object ESP", "left", "Pick what to mark. Everything of that kind inside the range is boxed and named through walls.")
		switch(page, "Touch triggers", "UEspTouch", "Parts that fire something when touched: kill bricks, checkpoints, pads.")
		switch(page, "Proximity prompts", "UEspPrompt", "Things you use by holding a key near them: doors, pickups, shops.")
		switch(page, "Click detectors", "UEspClick", "Parts that do something when you click them with the mouse.")
		switch(page, "Tools on the ground", "UEspTool", "Tools lying in the world that you can pick up.")
		slide(page, "Range", "UEspObjRange", 50, 5000, 50, function(value)
			return whole(value) .. " studs"
		end, "Only things within this many studs of you are marked. It follows you: the list is redone every two seconds. Click the number to type any distance. The nearest " .. MARK_CAP .. " of each kind are shown.")
		UI.heading(page, "Graphics", "left", "Put back when the switch goes off.")
		switch(page, "X-ray", "UXray", "The map goes see-through; characters stay solid.")
		switch(page, "No particles", "UNoParticles", "Particles, trails, beams, fire and smoke.")
		switch(page, "No textures", "UNoTextures", "Decals and textures.")
		switch(page, "No shadows", "UNoShadows")
		switch(page, "No screen effects", "UNoEffects", "Blur, bloom, depth of field, colour correction and sun rays.")
		UI.button(page, "Low graphics: all five on", function()
			Config.UNoParticles, Config.UNoTextures, Config.UNoShadows, Config.UNoEffects, Config.UNoFog = true, true, true, true, true
			pcall(UI.refreshAll)
			return "On"
		end)
		UI.heading(page, "Delete", "left")
		switch(page, "Click delete", "UClickDelete", "Hold the key below and click a part: it is gone, for you only.")
		UI.keybind(page, "Delete key", "UDeleteKey")
		tip(page, "Hold this key and click a part to delete it. Click delete must be on.")
		UI.button(page, "Undo the last delete", function()
			local last = table.remove(U.deleted)
			if not last then
				return "Nothing to undo"
			end
			pcall(function()
				last.object.Parent = last.parent
			end)
			return "Put back"
		end)
		UI.button(page, "Put everything back", function()
			local count = #U.deleted
			for index = #U.deleted, 1, -1 do
				pcall(function()
					U.deleted[index].object.Parent = U.deleted[index].parent
				end)
			end
			table.clear(U.deleted)
			return count .. " put back"
		end)
		UI.heading(page, "Find", "right", "Search the workspace by name.")
		local findBox = UI.textbox(page, "Name contains", "door, chest, coin...")
		local findLine = UI.note(page, "")
		UI.button(page, "Search and mark", function()
			local want = findBox.Text:lower()
			if want == "" then
				return "Type a name first"
			end
			local found = {}
			for index, object in ipairs(workspace:GetDescendants()) do
				if object.Name:lower():find(want, 1, true) and (object:IsA("BasePart") or object:IsA("Model")) then
					table.insert(found, { object = object, name = object.Name })
				end
				if index % 4000 == 0 then
					task.wait()
				end
			end
			U.found = found
			markSet("search", Color3.fromRGB(255, 235, 90), found)
			findLine.Text = #found .. " found" .. (#found > MARK_CAP and " (first " .. MARK_CAP .. " marked)." or ".")
			return #found .. " found"
		end)
		UI.button(page, "Teleport to the nearest", function()
			local part, best, bestAt = root(), nil, math.huge
			for _, item in ipairs(U.found or {}) do
				local okAt, at = pcall(function()
					return item.object:IsA("Model") and item.object:GetPivot().Position or item.object.Position
				end)
				if okAt and part and (at - part.Position).Magnitude < bestAt then
					best, bestAt = at, (at - part.Position).Magnitude
				end
			end
			if not best then
				return "Search first"
			end
			teleportTo(best)
			return "Teleported"
		end)
		UI.button(page, "Clear the marks", function()
			markClear("search")
			U.found = nil
			findLine.Text = ""
			return "Cleared"
		end)
		UI.heading(page, "What is in this place", "right")
		local prompts, clicks, touches, parts = UI.kv(page, "Proximity prompts"), UI.kv(page, "Click detectors"), UI.kv(page, "Touch triggers"), UI.kv(page, "Parts")
		UI.button(page, "Scan now", function()
			local count = { p = 0, c = 0, t = 0, b = 0 }
			for index, object in ipairs(workspace:GetDescendants()) do
				if object:IsA("ProximityPrompt") then
					count.p += 1
				elseif object:IsA("ClickDetector") then
					count.c += 1
				elseif object:IsA("TouchTransmitter") then
					count.t += 1
				elseif object:IsA("BasePart") then
					count.b += 1
				end
				if index % 5000 == 0 then
					task.wait()
				end
			end
			prompts.Text, clicks.Text, touches.Text, parts.Text = tostring(count.p), tostring(count.c), tostring(count.t), tostring(count.b)
			return "Scanned"
		end)
	end
	do
		local page = UI.makePage("Players", "Watch, reach and read the other players in the server.", "Universal")
		UI.heading(page, "Pick a player", "left")
		UI.cycler(page, "Player", U.playerOptions, function()
			local player = U.picked()
			return player and player.DisplayName or "Pick one"
		end, function(option)
			U.pick = option.id
		end)
		local health, distance, team, where, watching = UI.kv(page, "Health"), UI.kv(page, "Distance"), UI.kv(page, "Team"), UI.kv(page, "Position"), UI.kv(page, "Spectating")
		UI.heading(page, "Do", "right")
		UI.button(page, "Spectate", function()
			local player = U.picked()
			if not player then
				return "Pick a player first"
			end
			Config.UFreecam = false
			U.viewing = player
			return "Watching " .. player.DisplayName
		end)
		UI.button(page, "Stop spectating", function()
			U.viewing = nil
			return "Stopped"
		end)
		UI.button(page, "Teleport to them", function()
			local player = U.picked()
			local part = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not part then
				return player and "They have no character" or "Pick a player first"
			end
			teleportTo(part.Position)
			return "Teleported"
		end)
		switch(page, "Follow them", "UFollow", "Keeps you right behind the picked player.")
		UI.heading(page, "Copy", "right")
		UI.button(page, "Copy username", function()
			local player = U.picked()
			return player and copy(player.Name) or "Pick a player first"
		end)
		UI.button(page, "Copy display name", function()
			local player = U.picked()
			return player and copy(player.DisplayName) or "Pick a player first"
		end)
		UI.button(page, "Copy user id", function()
			local player = U.picked()
			return player and copy(player.UserId) or "Pick a player first"
		end)
		switch(page, "Join and leave notices", "UJoinNotes", "A note whenever someone joins or leaves the server.")
		task.spawn(function()
			while alive() and page.Parent do
				local player = U.picked()
				local model = player and player.Character
				local human = model and model:FindFirstChildOfClass("Humanoid")
				local theirs, mine = model and model:FindFirstChild("HumanoidRootPart"), root()
				health.Text = human and string.format("%d / %d", human.Health, human.MaxHealth) or "-"
				distance.Text = (theirs and mine) and string.format("%d studs", (theirs.Position - mine.Position).Magnitude) or "-"
				team.Text = player and (player.Team and player.Team.Name or "None") or "-"
				where.Text = theirs and string.format("%.0f, %.0f, %.0f", theirs.Position.X, theirs.Position.Y, theirs.Position.Z) or "-"
				watching.Text = U.viewing and U.viewing.DisplayName or "Nobody"
				task.wait(0.4)
			end
		end)
	end
	do
		local page = UI.makePage("Server", "This server, your frame rate and a few comforts.", "Universal")
		UI.heading(page, "This server", "left")
		local fpsRow, physics, pingRow, memory, count, age = UI.kv(page, "FPS"), UI.kv(page, "Physics FPS"), UI.kv(page, "Ping"), UI.kv(page, "Memory"), UI.kv(page, "Players"), UI.kv(page, "Server age")
		UI.button(page, "Rejoin this server", function()
			return U.rejoin()
		end)
		UI.button(page, "Hop to another server", function()
			return U.serverHop()
		end)
		UI.button(page, "Copy place id", function()
			return copy(game.PlaceId)
		end)
		UI.button(page, "Copy server id", function()
			return copy(game.JobId)
		end)
		UI.heading(page, "On screen", "right")
		switch(page, "Show FPS", "UFps", "A small tag at the top right of the screen.")
		switch(page, "Show ping", "UPing", "Added to the same tag as the FPS, at the top right of the screen.")
		switch(page, "Set an FPS cap", "UFpsCapOn", setfpscap and "The slider at its top end means no cap." or "Your executor has no setfpscap: this one does nothing here.")
		slide(page, "FPS cap", "UFpsCap", 30, 1000, 10, function(value)
			return value >= 1000 and "No cap" or whole(value)
		end)
		switch(page, "Hide the game's GUI", "UHideGui", "Every game screen is hidden until you switch this off. This menu stays.")
		UI.heading(page, "One game screen", "right", "Hide a single piece of the game's interface, for you only.")
		UI.cycler(page, "Screen", function()
			local options = {}
			local playerGui = me:FindFirstChildOfClass("PlayerGui")
			for _, gui in ipairs(playerGui and playerGui:GetChildren() or {}) do
				if gui:IsA("ScreenGui") then
					table.insert(options, { id = gui.Name, name = gui.Name .. (gui.Enabled and "" or " (hidden)"), current = gui.Name == U.guiPick })
				end
			end
			table.sort(options, function(a, b)
				return a.name:lower() < b.name:lower()
			end)
			return options
		end, function()
			return U.guiPick or "Pick one"
		end, function(option)
			U.guiPick = option.id
		end)
		UI.button(page, "Hide or show it", function()
			local playerGui = me:FindFirstChildOfClass("PlayerGui")
			local gui = playerGui and U.guiPick and playerGui:FindFirstChild(U.guiPick)
			if not gui or not gui:IsA("ScreenGui") then
				return "Pick a screen first"
			end
			U.guiOff = U.guiOff or {}
			gui.Enabled = not gui.Enabled
			U.guiOff[gui] = (not gui.Enabled) or nil
			pcall(UI.refreshAll)
			return gui.Enabled and "Shown" or "Hidden"
		end)
		UI.button(page, "Show them all again", function()
			for gui in pairs(U.guiOff or {}) do
				if gui.Parent then
					gui.Enabled = true
				end
			end
			U.guiOff = nil
			pcall(UI.refreshAll)
			return "All shown"
		end)
		UI.heading(page, "Comfort", "right")
		if not host.ownsAfk then
			switch(page, "Anti-AFK", "UAntiAfk", "Keeps Roblox from kicking you for standing still.")
		end
		switch(page, "Movement off when you die", "UOffOnDeath", "Fly, float, air walk, spin, bunny hop, free camera and follow are switched off on death. Off: they carry on after you respawn.")
		UI.button(page, "Panic: everything off", function()
			return U.panic()
		end)
		task.spawn(function()
			while alive() and page.Parent do
				fpsRow.Text = string.format("%d", fps)
				physics.Text = string.format("%d", workspace:GetRealPhysicsFPS())
				local ping = U.ping()
				pingRow.Text = ping and string.format("%d ms", ping) or "?"
				local okMemory, used = pcall(function()
					return game:GetService("Stats"):GetTotalMemoryUsageMb()
				end)
				memory.Text = okMemory and string.format("%d MB", used) or "?"
				count.Text = string.format("%d / %d", #players:GetPlayers(), players.MaxPlayers)
				local seconds = math.floor(workspace.DistributedGameTime)
				age.Text = string.format("%dh %02dm", seconds // 3600, seconds // 60 % 60)
				task.wait(0.5)
			end
		end)
	end
	do
		local page = UI.makePage("Keybinds", "A key for every switch, kept separately for every game. Click a box and press a key; Backspace clears it. Beside switch puts the key next to the switch on its own page, in every game.", "Universal")
		UI.heading(page, "Panic", "left")
		UI.keybind(page, "Everything off", "UPanicKey")
		tip(page, "Switches every Universal feature off at once, except Anti-AFK. Your keys and the ESP option switches stay as they are.")
		local seen = {}
		for _, entry in ipairs(PotentUniversal.TOGGLES) do
			if not seen[entry.page] then
				seen[entry.page] = true
				UI.heading(page, entry.page)
			end
			if not (host.ownsAfk and entry.key == "UAntiAfk") then
				local row = UI.keybind(page, entry.name, "K_" .. entry.key)
				if typeof(row) == "Instance" then
					-- "Beside switch": the key also shows next to the switch itself, on its own page.
					local pin = small(row, 86)
					pin.Position = UDim2.new(1, -112, 0, 4)
					for _, child in ipairs(row:GetChildren()) do
						if child:IsA("GuiObject") and child ~= pin and child.Size.X.Scale == 1 then
							child.Size = UDim2.new(1, child.Size.X.Offset - 92, child.Size.Y.Scale, child.Size.Y.Offset)
						end
					end
					local function refresh()
						local on = Config["P_" .. entry.key] == true
						pin.Text = on and "Beside switch" or "Menu only"
						if UI.roles then
							pin.BackgroundColor3 = on and UI.roles.Accent or UI.roles.Control
							pin.TextColor3 = on and (UI.onAccent and UI.onAccent() or UI.roles.Font) or UI.roles.Muted
						end
					end
					pin.MouseButton1Click:Connect(function()
						Config["P_" .. entry.key] = not Config["P_" .. entry.key]
						pcall(UI.refreshAll)
					end)
					table.insert(UI.refreshers, refresh)
					refresh()
				end
			end
		end
	end

	---Put everything back the way the game had it.
	function U.stop()
		-- Everything is switched off for the clean-up below and the settings put back after it,
		-- so what was on is on again the next time the script loads.
		local kept = {}
		for _, entry in ipairs(PotentUniversal.TOGGLES) do
			kept[entry.key] = Config[entry.key]
			if not (host.ownsClip and (entry.key == "NoClip" or entry.key == "ClickTeleport")) then
				Config[entry.key] = false
			end
		end
		U.viewing = nil
		pcall(fly.stop)
		pcall(freecam.stop)
		for part in pairs(clipped) do
			if part.Parent then
				part.CanCollide = true
			end
		end
		for player in pairs(U.esp) do
			espClear(player)
		end
		for key in pairs(U.marks) do
			markClear(key)
		end
		pcall(bodyStep)
		pcall(cameraStep)
		pcall(ruleStep)
		pcall(selfStep)
		pcall(animStep)
		pcall(watchStep)
		pcall(meterStep)
		for key, value in pairs(kept) do
			Config[key] = value
		end
		pcall(function()
			runService:UnbindFromRenderStep(ROLL_STEP)
		end)
		for gui in pairs(U.guiOff or {}) do
			if gui.Parent then
				gui.Enabled = true
			end
		end
		holder:Destroy()
		meter:Destroy()
		cross:Destroy()
		compass:Destroy()
	end
	return U
end
