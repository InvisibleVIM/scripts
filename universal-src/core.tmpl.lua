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
-- Every switch, in menu order. Each one can have a key (settings key "K_" .. key).
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
					entry.root, entry.color = head, color
				end
			end
		end
	end
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
		end
	end
	---Marks: NPCs, tools, proximity prompts, click detectors and search results get an outline and
	---a name. Looked for again every two seconds, at most 150 of each.
	local MARKS = {
		{ key = "UEspNpc", color = Color3.fromRGB(255, 170, 60), find = function(object)
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
		end
		U.marks[key] = nil
	end
	local function markSet(key, color, found)
		markClear(key)
		local list = {}
		for index, item in ipairs(found) do
			if index > 150 then
				break
			end
			local highlight = Instance.new("Highlight")
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.FillTransparency = 0.85
			highlight.FillColor, highlight.OutlineColor = color, color
			highlight.Adornee = item.object
			highlight.Parent = holder
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
		for index, object in ipairs(workspace:GetDescendants()) do
			for _, kind in ipairs(wanted) do
				local target, name = kind.find(object)
				if target then
					table.insert(found[kind.key], { object = target, name = name })
				end
			end
			if index % 4000 == 0 then
				task.wait()
			end
		end
		for _, kind in ipairs(wanted) do
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
	function U.panic()
		for _, entry in ipairs(PotentUniversal.TOGGLES) do
			if entry.key ~= "UAntiAfk" then
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
		UI.toggle(page, "Fly", "UFly")
		UI.slider(page, "Fly speed", "UFlySpeed", 0.5, 10, 0.5, function(value)
			return string.format("%d studs/s", value * 50)
		end)
		UI.toggle(page, "Vehicle fly", "UFlyVehicle", "Leaves your character sitting, so the seat (and the vehicle) flies with you.")
		UI.heading(page, "Through things", "left")
		UI.toggle(page, "No clip", "NoClip", "Your character walks through walls and scenery. The floor still holds you.")
		UI.toggle(page, "Click teleport", "ClickTeleport", "Hold the key below and click: your character is put where you clicked.")
		UI.keybind(page, "Click teleport key", "ClickTeleportKey", "Hold this while you click.")
		UI.heading(page, "In the air", "left")
		UI.toggle(page, "Infinite jump", "UInfJump", "Jump again in mid-air, as often as you like.")
		UI.toggle(page, "Bunny hop", "UBhop", "Jumps the moment you land while you are moving.")
		UI.toggle(page, "Air walk", "UAirWalk", "A see-through slab under your feet at the height you switch it on.")
		UI.toggle(page, "Float", "UFloat", "Holds your height; you can still move sideways.")
		UI.heading(page, "Walk and jump", "right")
		UI.toggle(page, "Set walk speed", "USpeedOn")
		UI.slider(page, "Walk speed", "USpeed", 16, 300, 1, whole)
		UI.toggle(page, "Set jump power", "UJumpOn")
		UI.slider(page, "Jump power", "UJump", 50, 500, 5, whole, "Games that use jump height get the matching height.")
		UI.toggle(page, "Set gravity", "UGravityOn")
		UI.slider(page, "Gravity", "UGravity", 5, 196, 1, whole, "The game's normal is 196.")
		UI.toggle(page, "Spin", "USpin")
		UI.slider(page, "Spin speed", "USpinSpeed", 1, 60, 1, whole)
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
		UI.toggle(page, "Player ESP", "UEsp")
		UI.toggle(page, "Outlines (chams)", "UEspChams")
		UI.toggle(page, "Names", "UEspNames")
		UI.toggle(page, "Distance", "UEspDistance")
		UI.toggle(page, "Health bars", "UEspHealth")
		UI.toggle(page, "Tracers", "UEspTracers", Drawing and "A line from the bottom of the screen to each player." or "Your executor has no Drawing API: this one does nothing here.")
		UI.toggle(page, "Team colours", "UEspTeam", "Off: everyone is red.")
		UI.toggle(page, "Hide teammates", "UEspTeamCheck")
		UI.slider(page, "Range", "UEspRange", 100, 5000, 100, function(value)
			return whole(value) .. " studs"
		end)
		UI.heading(page, "Other ESP", "right", "Up to 150 of each, looked for again every two seconds.")
		UI.toggle(page, "NPCs", "UEspNpc", "Anything with a humanoid that is not a player.")
		UI.toggle(page, "Tools on the ground", "UEspTool")
		UI.toggle(page, "Proximity prompts", "UEspPrompt")
		UI.toggle(page, "Click detectors", "UEspClick")
		UI.heading(page, "Light and aim", "right")
		UI.toggle(page, "Fullbright", "UFullbright", "Daylight, no fog, no shadows.")
		UI.toggle(page, "Remove fog", "UNoFog")
		UI.toggle(page, "Crosshair", "UCrosshair")
		UI.slider(page, "Crosshair size", "UCrosshairSize", 3, 30, 1, whole)
	end
	do
		local page = UI.makePage("Camera", "Field of view, zoom and a free camera.", "Universal")
		UI.heading(page, "View", "left")
		UI.toggle(page, "Set field of view", "UFovOn")
		UI.slider(page, "Field of view", "UFov", 30, 120, 1, whole)
		UI.toggle(page, "Set max zoom", "UZoomOn", "How far the camera can zoom out (Infinite Yield's maxzoom).")
		UI.slider(page, "Max zoom", "UZoom", 50, 10000, 50, function(value)
			return whole(value) .. " studs"
		end)
		UI.toggle(page, "Allow third person", "UThirdPerson", "For games that lock you in first person.")
		UI.toggle(page, "First person", "UFirstPerson")
		UI.toggle(page, "Set mouse sensitivity", "USensOn")
		UI.slider(page, "Sensitivity", "USens", 0.1, 5, 0.1, function(value)
			return string.format("%.1fx", value)
		end)
		UI.heading(page, "Free camera", "right", "The camera leaves your character: W A S D, E up, Q down, hold right mouse to look, Shift to go faster.")
		UI.toggle(page, "Free camera", "UFreecam")
		UI.slider(page, "Camera speed", "UFreecamSpeed", 10, 400, 10, function(value)
			return whole(value) .. " studs/s"
		end)
	end
	do
		local page = UI.makePage("Character", "How your own character looks and moves, on your screen only.", "Universal")
		UI.heading(page, "Look", "left", "Only you see these.")
		UI.toggle(page, "Hide my character", "UHideSelf", "For screenshots.")
		UI.slider(page, "How hidden", "USelfAlpha", 0.1, 1, 0.1, function(value)
			return string.format("%d%%", value * 100)
		end)
		UI.toggle(page, "Hide my accessories", "UNoAccessories")
		UI.heading(page, "Animations", "left")
		UI.toggle(page, "Stop my animations", "UNoAnim")
		UI.toggle(page, "Set animation speed", "UAnimSpeedOn")
		UI.slider(page, "Animation speed", "UAnimSpeed", 0.1, 5, 0.1, function(value)
			return string.format("%.1fx", value)
		end)
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
		UI.heading(page, "Graphics", "left", "Put back when the switch goes off.")
		UI.toggle(page, "X-ray", "UXray", "The map goes see-through; characters stay solid.")
		UI.toggle(page, "No particles", "UNoParticles", "Particles, trails, beams, fire and smoke.")
		UI.toggle(page, "No textures", "UNoTextures", "Decals and textures.")
		UI.toggle(page, "No shadows", "UNoShadows")
		UI.toggle(page, "No screen effects", "UNoEffects", "Blur, bloom, depth of field, colour correction and sun rays.")
		UI.button(page, "Low graphics: all five on", function()
			Config.UNoParticles, Config.UNoTextures, Config.UNoShadows, Config.UNoEffects, Config.UNoFog = true, true, true, true, true
			pcall(UI.refreshAll)
			return "On"
		end)
		UI.heading(page, "Delete", "left")
		UI.toggle(page, "Click delete", "UClickDelete", "Hold the key below and click a part: it is gone, for you only.")
		UI.keybind(page, "Delete key", "UDeleteKey", "Hold this while you click.")
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
			findLine.Text = #found .. " found" .. (#found > 150 and " (first 150 marked)." or ".")
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
		UI.toggle(page, "Follow them", "UFollow", "Keeps you right behind the picked player.")
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
		UI.toggle(page, "Join and leave notices", "UJoinNotes", "A note whenever someone joins or leaves the server.")
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
		UI.toggle(page, "Show FPS", "UFps", "A small tag at the top right of the screen.")
		UI.toggle(page, "Show ping", "UPing")
		UI.toggle(page, "Set an FPS cap", "UFpsCapOn", setfpscap and "The slider at its top end means no cap." or "Your executor has no setfpscap: this one does nothing here.")
		UI.slider(page, "FPS cap", "UFpsCap", 30, 1000, 10, function(value)
			return value >= 1000 and "No cap" or whole(value)
		end)
		UI.toggle(page, "Hide the game's GUI", "UHideGui", "Every game screen is hidden until you switch this off. This menu stays.")
		UI.heading(page, "Comfort", "right")
		if not host.ownsAfk then
			UI.toggle(page, "Anti-AFK", "UAntiAfk", "Keeps Roblox from kicking you for standing still.")
		end
		UI.toggle(page, "Movement off when you die", "UOffOnDeath", "Fly, float, air walk, spin, bunny hop, free camera and follow are switched off on death. Off: they carry on after you respawn.")
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
		local page = UI.makePage("Keybinds", "A key for every switch. Click a box and press a key; Backspace clears it.", "Universal")
		UI.heading(page, "Panic", "left")
		UI.keybind(page, "Everything off", "UPanicKey", "Switches every Universal feature off at once.")
		local seen = {}
		for _, entry in ipairs(PotentUniversal.TOGGLES) do
			if not seen[entry.page] then
				seen[entry.page] = true
				UI.heading(page, entry.page)
			end
			if not (host.ownsAfk and entry.key == "UAntiAfk") then
				UI.keybind(page, entry.name, "K_" .. entry.key)
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
		holder:Destroy()
		meter:Destroy()
		cross:Destroy()
	end
	return U
end
