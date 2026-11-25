-- Epic Minigames: the game layer. In a function of its own: the main chunk has no registers to spare.
;(function()
	local EM = BeyRivals
	local V = workspace:WaitForChild("WorkspaceVals", 30)
	local RS = game:GetService("ReplicatedStorage")
	local FOLDER = SETTINGS_FOLDER
	EM.errors = {}
	EM.status = "Starting"
	EM.detail = ""
	EM.session = { rounds = 0, survived = 0, out = 0, wins = 0, started = os.time() }
	EM.games = {}
	EM.handlers = {}
	EM.log = {}

	local function supervise(name, loop)
		task.spawn(function()
			while EM.alive do
				local ok, err = pcall(loop)
				pcall(setthreadidentity, 8)
				if not ok then
					EM.errors[name] = tostring(err)
				end
				task.wait(1)
			end
		end)
	end
	EM.supervise = supervise

	---One line in EpicMinigames/log.txt (and the last 60 in memory for the Home page).
	local function log(text)
		local line = os.date("%H:%M:%S ") .. text
		table.insert(EM.log, line)
		if #EM.log > 60 then
			table.remove(EM.log, 1)
		end
		pcall(function()
			if not isfolder(FOLDER) then
				makefolder(FOLDER)
			end
			local path = FOLDER .. "/log.txt"
			if isfile(path) and #readfile(path) < 400000 then
				appendfile(path, line .. "\n")
			else
				writefile(path, line .. "\n")
			end
		end)
	end
	EM.say = log

	local function val(name, default)
		local object = V and V:FindFirstChild(name)
		if object and object:IsA("ValueBase") then
			return object.Value
		end
		return default
	end
	local function mine(name, default)
		local object = localPlayer:FindFirstChild(name)
		if object and object:IsA("ValueBase") then
			return object.Value
		end
		return default
	end
	local function misc(name, default)
		local folder = localPlayer:FindFirstChild("Misc")
		local object = folder and folder:FindFirstChild(name)
		if object and object:IsA("ValueBase") then
			return object.Value
		end
		return default
	end
	EM.val, EM.mine, EM.misc = val, mine, misc

	local function character()
		return localPlayer.Character
	end
	local function root()
		local model = character()
		return model and model:FindFirstChild("HumanoidRootPart")
	end
	local function humanoid()
		local model = character()
		return model and model:FindFirstChildOfClass("Humanoid")
	end
	local function flat(v)
		return Vector3.new(v.X, 0, v.Z)
	end

	-- Categories come from the game's own list (ReplicatedStorage.MinigameCategories).
	local Categories = { list = {}, solo = {} }
	pcall(function()
		pcall(setthreadidentity, 2)
		local ok, module = pcall(require, RS:WaitForChild("MinigameCategories", 10))
		pcall(setthreadidentity, 8)
		if ok and type(module) == "table" then
			for category, names in pairs(module.MinigamesList or {}) do
				for _, name in pairs(names) do
					Categories.list[name] = category
				end
			end
			for _, name in pairs(module.SoloGames or {}) do
				Categories.solo[name] = true
			end
		end
	end)
	pcall(setthreadidentity, 8)
	function EM.category(name)
		return Categories.list[name] or "Unknown"
	end

	-- Per-minigame record kept across sessions: how often played, survived and won, and which
	-- brain played it.
	local STATS_FILE = FOLDER .. "/minigames.json"
	pcall(function()
		if isfile(STATS_FILE) then
			local data = httpService:JSONDecode(readfile(STATS_FILE))
			if type(data) == "table" then
				EM.games = data
			end
		end
	end)
	local function saveGames()
		pcall(function()
			if not isfolder(FOLDER) then
				makefolder(FOLDER)
			end
			writefile(STATS_FILE, httpService:JSONEncode(EM.games))
		end)
	end

	local function wins()
		local text = tostring(misc("monthlywins", ""))
		return tonumber(text:match(",(%d+)$")) or 0
	end

	----------------------------------------------------------------------------------------------
	-- Recorder. A minigame's map, its local scripts and its tools only exist on this side while
	-- that minigame is being played, so each one is written to EpicMinigames/rec the first time
	-- it comes up. Handlers are written from these files.
	----------------------------------------------------------------------------------------------
	local Recorder = { seen = {} }
	EM.Recorder = Recorder
	local function describe(object, indent, depth, lines, maxKids)
		local counts, shown = {}, 0
		for _, child in ipairs(object:GetChildren()) do
			local key = child.Name .. "|" .. child.ClassName
			counts[key] = (counts[key] or 0) + 1
			if counts[key] <= 3 and shown < maxKids then
				shown += 1
				local extra = ""
				if child:IsA("ValueBase") then
					extra = " = " .. tostring(child.Value):sub(1, 60)
				elseif child:IsA("BasePart") then
					extra = (" pos(%d,%d,%d) size(%d,%d,%d)%s%s%s%s"):format(child.Position.X, child.Position.Y, child.Position.Z, child.Size.X, child.Size.Y, child.Size.Z,
						child.CanCollide and "" or " nc", child.Transparency >= 1 and " inv" or "", child.Anchored and "" or " loose", child:FindFirstChildOfClass("TouchTransmitter") and " TOUCH" or "")
				elseif child:IsA("Model") then
					local ok, cf, size = pcall(child.GetBoundingBox, child)
					if ok then
						extra = (" box pos(%d,%d,%d) size(%d,%d,%d)"):format(cf.Position.X, cf.Position.Y, cf.Position.Z, size.X, size.Y, size.Z)
					end
				end
				table.insert(lines, indent .. child.Name .. " <" .. child.ClassName .. ">" .. extra .. (#child:GetChildren() > 0 and " (" .. #child:GetChildren() .. ")" or ""))
				if depth > 0 and not child:IsA("Humanoid") then
					describe(child, indent .. "  ", depth - 1, lines, maxKids)
				end
			end
		end
		for key, count in pairs(counts) do
			if count > 3 then
				table.insert(lines, indent .. "  [x" .. count .. "] " .. key)
			end
		end
	end
	---Code that runs on this side and can be read: local scripts, modules, and plain Scripts set
	---to run on the client (Fishing Frenzy, Hurdle Hurry and Juggernaut are written that way,
	---which is why their code was missed at first).
	local function clientCode(object)
		if object:IsA("LocalScript") or object:IsA("ModuleScript") then
			return true
		end
		if object:IsA("Script") then
			local ok, context = pcall(function()
				return object.RunContext
			end)
			return ok and context == Enum.RunContext.Client
		end
		return false
	end
	local function safeName(text)
		return (tostring(text):gsub("[^%w]", "_"))
	end
	function Recorder.snapshot(model, name, tag)
		local folder = FOLDER .. "/rec"
		local mapName = model:FindFirstChild("mapn") and tostring(model.mapn.Value) or ""
		local key = safeName(name) .. "__" .. safeName(mapName) .. "__" .. tag
		if Recorder.seen[key] then
			return
		end
		Recorder.seen[key] = true
		if not isfolder(FOLDER) then
			makefolder(FOLDER)
		end
		if not isfolder(folder) then
			makefolder(folder)
		end
		if isfile(folder .. "/" .. key .. ".txt") then
			return
		end
		local lines = { "# " .. name .. " map=" .. mapName .. " tag=" .. tag .. " category=" .. EM.category(name) }
		local part = root()
		table.insert(lines, "me: " .. (part and tostring(part.Position) or "?") .. " inround=" .. tostring(mine("inround")) .. " team=" .. tostring(mine("team")) .. " notification=" .. tostring(val("notification")))
		for _, name2 in ipairs({ "teamGame", "respawningame", "num3canwin", "nofloat", "isnotp", "ccam", "controller", "mapname" }) do
			table.insert(lines, "val " .. name2 .. "=" .. tostring(val(name2)))
		end
		describe(model, "", 5, lines, 60)
		table.insert(lines, "## tools")
		for _, tool in ipairs(localPlayer.Backpack:GetChildren()) do
			table.insert(lines, "backpack " .. tool.Name .. " <" .. tool.ClassName .. ">")
		end
		for _, tool in ipairs(character() and character():GetChildren() or {}) do
			if tool:IsA("Tool") then
				table.insert(lines, "holding " .. tool.Name)
			end
		end
		table.insert(lines, "## players in the round")
		for _, player in ipairs(playersService:GetPlayers()) do
			local inRound = player:FindFirstChild("inround")
			local body = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if inRound and inRound.Value and body then
				table.insert(lines, ("%s pos(%d,%d,%d) team=%s"):format(player.Name == localPlayer.Name and "ME" or "p", body.Position.X, body.Position.Y, body.Position.Z, tostring(player:FindFirstChild("team") and player.team.Value)))
			end
		end
		writefile(folder .. "/" .. key .. ".txt", table.concat(lines, "\n"))
		if tag ~= "start" then
			return
		end
		local count = 0
		local function source(object, label)
			count += 1
			local ok, text = pcall(decompile, object)
			writefile(folder .. "/" .. safeName(name) .. "__src" .. count .. ".lua", "-- " .. label .. "\n" .. (ok and text or "-- could not be read"))
		end
		for _, object in ipairs(model:GetDescendants()) do
			if clientCode(object) then
				source(object, object:GetFullName())
			end
		end
		local gui = localPlayer:FindFirstChild("PlayerGui")
		for _, object in ipairs(gui and gui:GetChildren() or {}) do
			if object:IsA("LocalScript") and object.Name ~= "showguis" then
				source(object, object:GetFullName())
			end
		end
		for _, tool in ipairs(localPlayer.Backpack:GetChildren()) do
			if tool:IsA("Tool") and not Recorder.seen["tool" .. tool.Name] then
				Recorder.seen["tool" .. tool.Name] = true
				for _, object in ipairs(tool:GetDescendants()) do
					if object:IsA("LocalScript") then
						local ok, text = pcall(decompile, object)
						writefile(folder .. "/tool__" .. safeName(tool.Name) .. "__" .. safeName(object.Name) .. ".lua", "-- " .. object:GetFullName() .. "\n" .. (ok and text or "-- could not be read"))
					end
				end
			end
		end
	end

	---Tools and scripts that only turn up part-way through a round (Juggernaut hands out its
	---launcher ten seconds in, after the first snapshot): saved the first time each is seen.
	function Recorder.late(model, name)
		local folder = FOLDER .. "/rec"
		if not isfolder(folder) then
			return
		end
		local function keep(object, label)
			local key = "late|" .. name .. "|" .. label
			if Recorder.seen[key] then
				return
			end
			Recorder.seen[key] = true
			local path = folder .. "/" .. safeName(name) .. "__late__" .. safeName(label) .. ".lua"
			if isfile(path) then
				return
			end
			local ok, text = pcall(decompile, object)
			writefile(path, "-- " .. object:GetFullName() .. "\n" .. (ok and text or "-- could not be read"))
		end
		local function tool(item)
			local key = "latetool|" .. name .. "|" .. item.Name
			if Recorder.seen[key] or Recorder.seen["tool" .. item.Name] then
				return
			end
			Recorder.seen[key] = true
			local lines = { "# tool " .. item.Name .. " in " .. name }
			describe(item, "", 5, lines, 60)
			writefile(folder .. "/" .. safeName(name) .. "__tool__" .. safeName(item.Name) .. ".txt", table.concat(lines, "\n"))
			for _, object in ipairs(item:GetDescendants()) do
				if clientCode(object) then
					keep(object, item.Name .. "_" .. object.Name)
				end
			end
		end
		for _, place in ipairs({ localPlayer:FindFirstChild("Backpack"), character() }) do
			for _, item in ipairs(place and place:GetChildren() or {}) do
				if item:IsA("Tool") then
					tool(item)
				end
			end
		end
		local gui = localPlayer:FindFirstChild("PlayerGui")
		local ours = { Shiftlock = true, QuestMarkers = true, MenuGui = true, FrontGui = true, GameGui = true, SpectateGui = true, ProximityPrompts = true, SoundFX = true }
		for _, object in ipairs(gui and gui:GetChildren() or {}) do
			if clientCode(object) and object.Name ~= "showguis" then
				keep(object, "gui_" .. object.Name)
			elseif not ours[object.Name] and not object:IsA("BillboardGui") then
				-- A screen the minigame put up: its buttons may carry the code.
				for _, inner in ipairs(object:GetDescendants()) do
					if clientCode(inner) then
						keep(inner, "gui_" .. object.Name .. "_" .. inner.Name)
					end
				end
			end
		end
		-- (Some minigames put their script in your character: Hurdle Hurry has none anywhere else.)
		local usual = { GearEquipping = true, itemsLocal = true, Emoting = true, Animate = true, normalcam = true, forwardcam = true, normalforwardcam = true, stubbornforwardcam = true, unfpscam = true }
		for _, object in ipairs(character() and character():GetChildren() or {}) do
			if clientCode(object) and not usual[object.Name] then
				keep(object, "char_" .. object.Name)
			end
		end
		for _, object in ipairs(model:GetDescendants()) do
			if clientCode(object) then
				keep(object, "map_" .. object.Name)
			end
		end
		-- Some minigames keep their client code and parts in ReplicatedStorage.TempMinigameStorage
		-- for the length of the round (Deadly Dogfight's planes come from there).
		local temp = RS:FindFirstChild("TempMinigameStorage")
		if temp then
			if not Recorder.seen["temp|" .. name] and #temp:GetChildren() > 0 then
				Recorder.seen["temp|" .. name] = true
				local lines = { "# TempMinigameStorage during " .. name }
				describe(temp, "", 4, lines, 40)
				writefile(folder .. "/" .. safeName(name) .. "__temp.txt", table.concat(lines, "\n"))
			end
			for _, object in ipairs(temp:GetDescendants()) do
				if clientCode(object) then
					keep(object, "temp_" .. object.Name)
				end
			end
		end
	end

	----------------------------------------------------------------------------------------------
	-- Watching the other players. Every player in the round leaves a trail of where they stood
	-- and where they jumped. The generic brains follow a good player's trail on foot, which
	-- needs no knowledge of the minigame and moves the way a player moves.
	----------------------------------------------------------------------------------------------
	local Trails = { of = {} }
	EM.Trails = Trails
	local function playerAlive(player)
		local inRound = player:FindFirstChild("inround")
		local model = player.Character
		local human = model and model:FindFirstChildOfClass("Humanoid")
		return inRound and inRound.Value and human and human.Health > 0 and model:FindFirstChild("HumanoidRootPart") ~= nil
	end
	Trails.alive = playerAlive
	function Trails.reset()
		Trails.of = {}
	end
	function Trails.step()
		local now = os.clock()
		for _, player in ipairs(playersService:GetPlayers()) do
			if player ~= localPlayer and playerAlive(player) then
				local trail = Trails.of[player]
				if not trail then
					trail = { crumbs = {}, first = player.Character.HumanoidRootPart.Position, born = now }
					Trails.of[player] = trail
				end
				local part = player.Character.HumanoidRootPart
				local human = player.Character:FindFirstChildOfClass("Humanoid")
				local last = trail.crumbs[#trail.crumbs]
				local state = human:GetState()
				local airborne = state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
				local jumped = airborne and not trail.airborne and part.AssemblyLinearVelocity.Y > 8
				trail.airborne = airborne
				if not last or (part.Position - last.pos).Magnitude > 1.5 or jumped then
					table.insert(trail.crumbs, { pos = part.Position, t = now, jump = jumped or nil })
					if #trail.crumbs > 1500 then
						table.remove(trail.crumbs, 1)
						trail.shift = (trail.shift or 0) + 1
					end
				end
				trail.seen = now
				trail.pos = part.Position
			elseif Trails.of[player] and not Trails.of[player].lost then
				Trails.of[player].lost = now
			end
		end
	end

	----------------------------------------------------------------------------------------------
	-- Moving. Only ever the way a player moves: Humanoid:MoveTo and a jump. This game puts walk
	-- speed, jump power and body movers back by itself and tells the server about some of them,
	-- so none of those are touched.
	----------------------------------------------------------------------------------------------
	local Move = { lastKey = 0 }
	EM.Move = Move
	local KEYS = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right }
	---True while you are steering yourself: the brains stand back for a moment after any movement key.
	function Move.yours()
		if userInputService:GetFocusedTextBox() == nil then
			for _, key in ipairs(KEYS) do
				if userInputService:IsKeyDown(key) then
					Move.lastKey = os.clock()
					break
				end
			end
		end
		return os.clock() - Move.lastKey < 1.2
	end
	function Move.to(position)
		local human = humanoid()
		if human and human.Health > 0 and not Move.yours() then
			human:MoveTo(position)
			return true
		end
		return false
	end
	function Move.stop()
		local human, part = humanoid(), root()
		if human and part and not Move.yours() then
			human:MoveTo(part.Position)
		end
	end
	function Move.jump()
		local human = humanoid()
		if human and not Move.yours() and human.FloorMaterial ~= Enum.Material.Air then
			human.Jump = true
		end
	end
	---Walk to a place by a route the game's own pathfinder works out (round houses and fences,
	---jumping where it says to), a step at a time. Returns true once you are there. Call it over
	---and over; `tag` names the destination so a new one starts a new route.
	local pathService = game:GetService("PathfindingService")
	function Move.path(round, goal, tag, near)
		local part = root()
		if not part then
			return false
		end
		local state = round.route
		local now = os.clock()
		if not state or state.tag ~= tag or state.redo or now - state.at > 6 then
			state = { tag = tag, at = now, index = 2, spot = part.Position, moved = now }
			round.route = state
			local path = pathService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6 })
			local ok = pcall(function()
				path:ComputeAsync(part.Position, goal)
			end)
			if ok and path.Status == Enum.PathStatus.Success then
				state.points = path:GetWaypoints()
			end
			part = root()
			if not part then
				return false
			end
		end
		local point = state.points and state.points[state.index]
		while point and flat(point.Position - part.Position).Magnitude < 3 do
			state.index += 1
			point = state.points[state.index]
		end
		if point then
			Move.to(point.Position)
			if point.Action == Enum.PathWaypointAction.Jump then
				Move.jump()
			end
		else
			Move.to(goal)
		end
		-- Not getting anywhere: hop, and work the route out again from here.
		if (part.Position - state.spot).Magnitude > 2 then
			state.spot, state.moved = part.Position, now
		elseif now - state.moved > 1 then
			Move.jump()
			state.redo = now - state.moved > 2
		end
		return flat(goal - part.Position).Magnitude < (near or 4)
	end
	---Is there something to stand on under this point?
	function Move.ground(position, depth)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = {}
		for _, player in ipairs(playersService:GetPlayers()) do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -(depth or 14), 0), params)
		return hit and hit.Instance.CanCollide and hit or nil
	end

	----------------------------------------------------------------------------------------------
	-- Brains.
	----------------------------------------------------------------------------------------------
	local Brain = {}
	EM.Brain = Brain

	---Things flying about: parts of the minigame that are moving right now. Used to step aside.
	local function movers(round)
		local now = os.clock()
		if round.moversAt and now - round.moversAt < 0.12 then
			return round.movers
		end
		local list = {}
		local seen = round.partPos or {}
		local nextSeen = {}
		local mePart = root()
		if mePart then
			for _, object in ipairs(round.model:GetDescendants()) do
				if object:IsA("BasePart") and (object.Position - mePart.Position).Magnitude < 70 then
					local before = seen[object]
					local dt = round.moversAt and (now - round.moversAt) or 0
					if before and dt > 0 then
						local velocity = (object.Position - before) / dt
						if velocity.Magnitude > 3 and velocity.Magnitude < 400 then
							table.insert(list, { part = object, pos = object.Position, vel = velocity, size = object.Size.Magnitude / 2 })
						end
					end
					nextSeen[object] = object.Position
				end
			end
		end
		round.partPos, round.moversAt, round.movers = nextSeen, now, list
		return list
	end
	---A step to the side when something is about to pass through where you stand, or nil.
	local function dodge(round)
		local part = root()
		if not part then
			return nil
		end
		local worst, away = 0, nil
		for _, mover in ipairs(movers(round)) do
			for _, ahead in ipairs({ 0.15, 0.35, 0.6 }) do
				local future = mover.pos + mover.vel * ahead
				local gap = flat(future - part.Position).Magnitude - math.min(mover.size, 14)
				if gap < 5 and math.abs(future.Y - part.Position.Y) < math.max(8, mover.size) then
					local threat = (5 - gap) / ahead
					if threat > worst then
						local path = flat(mover.vel)
						local side = path.Magnitude > 0.5 and Vector3.new(-path.Z, 0, path.X).Unit or flat(part.Position - future).Unit
						if side:Dot(flat(part.Position - mover.pos)) < 0 then
							side = -side
						end
						worst, away = threat, side
					end
				end
			end
		end
		if away then
			for _, reach in ipairs({ 9, 6 }) do
				local spot = part.Position + away * reach
				if Move.ground(spot) then
					return spot
				end
			end
		end
		return nil
	end

	local function pickGuide(round, mode)
		local part = root()
		local best, bestScore
		for player, trail in pairs(Trails.of) do
			if playerAlive(player) and trail.pos then
				local score
				if mode == "race" then
					score = (trail.pos - round.origin).Magnitude
				else
					local streak = player:FindFirstChild("streak")
					score = (streak and streak.Value or 0) * 40 - (part and (trail.pos - part.Position).Magnitude or 0)
				end
				if round.guide == player then
					score += mode == "race" and 14 or 60
				end
				if not bestScore or score > bestScore then
					best, bestScore = player, score
				end
			end
		end
		if best ~= round.guide then
			round.guide, round.cursor = best, nil
		end
		return best
	end

	---Racing: run the leader's trail, crumb by crumb, jumping where they jumped.
	function Brain.race(round)
		local stuckAt, stuckPos = os.clock(), nil
		while round.live() do
			local part, human = root(), humanoid()
			local guide = pickGuide(round, "race")
			local trail = guide and Trails.of[guide]
			if part and human and trail and #trail.crumbs > 0 then
				local crumbs = trail.crumbs
				local cursor = round.cursor and (round.cursor - (trail.shift or 0) + (round.shiftAt or 0)) or nil
				if not cursor or cursor < 1 or cursor > #crumbs then
					-- Join the trail at the crumb nearest to you.
					local nearest, distance = #crumbs, math.huge
					for index = 1, #crumbs do
						local d = (crumbs[index].pos - part.Position).Magnitude
						if d <= distance then
							nearest, distance = index, d
						end
					end
					cursor = nearest
				end
				while cursor < #crumbs and flat(crumbs[cursor].pos - part.Position).Magnitude < 3.2 and math.abs(crumbs[cursor].pos.Y - part.Position.Y) < 7 do
					if crumbs[cursor].jump then
						Move.jump()
					end
					cursor += 1
				end
				round.cursor, round.shiftAt = cursor, trail.shift or 0
				local target = crumbs[cursor]
				round.detail = ("following %s, %d steps behind"):format(guide.Name, #crumbs - cursor)
				local aside = dodge(round)
				Move.to(aside or target.pos)
				if target.jump and flat(target.pos - part.Position).Magnitude < 4.5 then
					Move.jump()
				elseif target.pos.Y - part.Position.Y > 2.2 and flat(target.pos - part.Position).Magnitude < 7 then
					Move.jump()
				end
				-- Stuck: jump, then give up on this crumb and rejoin the trail.
				if not stuckPos or (part.Position - stuckPos).Magnitude > 2.5 then
					stuckPos, stuckAt = part.Position, os.clock()
				elseif os.clock() - stuckAt > 0.8 and cursor < #crumbs then
					Move.jump()
					if os.clock() - stuckAt > 3.5 then
						round.cursor = nil
						stuckAt = os.clock()
					end
				end
			else
				round.detail = "waiting for someone to follow"
			end
			task.wait(0.07)
		end
	end

	---Staying alive: stand where a good player stood a moment ago, and step out of the way of
	---anything moving at you.
	function Brain.survive(round)
		while round.live() do
			local part, human = root(), humanoid()
			local guide = pickGuide(round, "survive")
			local trail = guide and Trails.of[guide]
			if part and human then
				local aside = dodge(round)
				if aside then
					round.detail = "stepping aside"
					Move.to(aside)
				elseif trail and #trail.crumbs > 0 then
					local crumbs = trail.crumbs
					local target = crumbs[#crumbs]
					local now = os.clock()
					for index = #crumbs, 1, -1 do
						if now - crumbs[index].t >= 0.35 then
							target = crumbs[index]
							break
						end
					end
					round.detail = "staying with " .. guide.Name
					local gap = flat(target.pos - part.Position)
					if gap.Magnitude > 4 then
						Move.to(target.pos - gap.Unit * 3)
					end
					if (target.jump and gap.Magnitude < 8) or (target.pos.Y - part.Position.Y > 2.5 and gap.Magnitude < 8) then
						Move.jump()
					end
				else
					round.detail = "nobody left to stay with"
				end
			end
			task.wait(0.07)
		end
	end

	----------------------------------------------------------------------------------------------
	-- Handlers written for one minigame each.
	----------------------------------------------------------------------------------------------

	-- Paint to Perfection. The painting to copy is `tpaint` (p1..p16 on the board); your easel is
	-- the model named after your player number, with the same sixteen cells under `paper`. A
	-- click on a cell moves it on to its next colour, and `pwon` goes true when all sixteen
	-- match. Nothing is assumed about the order of the colours: each cell is clicked until it
	-- shows the wanted one. USER: "do this ... this minigame".
	EM.handlers["Paint to Perfection"] = function(round)
		local model = round.model
		local clicks, started = 0, os.clock()
		local tries = {}
		local reported = false
		while round.live() do
			local target = model:FindFirstChild("tpaint")
			local easel = model:FindFirstChild(tostring(mine("playernum", 0)))
			local paper = easel and easel:FindFirstChild("paper")
			local allowed = model:FindFirstChild("canpaint")
			local part = root()
			local clicked = false
			if target and paper and part and (not allowed or allowed.Value) then
				local wrong, nextCell, nextDetector = 0, nil, nil
				for index = 1, 16 do
					local cell, want = paper:FindFirstChild("p" .. index), target:FindFirstChild("p" .. index)
					if cell and want and cell.BrickColor ~= want.BrickColor then
						wrong += 1
						local detector = cell:FindFirstChildOfClass("ClickDetector")
						if detector and not nextCell and (tries[cell] or 0) < 40 then
							nextCell, nextDetector = cell, detector
						end
					end
				end
				round.detail = wrong == 0 and "painting matches" or (wrong .. " cells to go")
				if wrong == 0 and not reported then
					reported = true
					log(("Paint to Perfection: matched in %.1fs with %d clicks"):format(os.clock() - started, clicks))
				elseif wrong > 0 then
					reported = false
				end
				if nextCell then
					local reach = math.min(nextDetector.MaxActivationDistance, 28)
					local gap = (nextCell.Position - part.Position).Magnitude
					if gap > reach - 2 then
						-- Walk up to the easel first: a click from out of reach does nothing.
						Move.to(nextCell.Position + flat(part.Position - nextCell.Position).Unit * 5)
					elseif fireclickdetector then
						local before = nextCell.BrickColor
						fireclickdetector(nextDetector)
						clicks += 1
						tries[nextCell] = (tries[nextCell] or 0) + 1
						clicked = true
						local waited = 0
						while waited < 0.5 and nextCell.BrickColor == before do
							waited += task.wait()
						end
						-- (About eight clicks a second, the pace of someone clicking quickly.)
						task.wait(0.07 + math.random() * 0.07)
					else
						round.detail = "this executor cannot click for you"
					end
				end
			end
			if not clicked then
				task.wait(0.15)
			end
		end
	end

	-- Cake Delivery. You are handed a cake, a tool named after a house number, and the doors are
	-- parts of the minigame with that number written on them (a SurfaceGui label). Walking the
	-- cake into the door with the same number delivers it; `cakecount` suggests more than one
	-- cake a round, so it keeps going for as long as you are holding one. USER: "do this minigame".
	EM.handlers["Cake Delivery"] = function(round)
		local model = round.model
		local delivered, lastNumber = 0, nil
		local function doorFor(number)
			for _, object in ipairs(model:GetChildren()) do
				if object:IsA("BasePart") then
					local face = object:FindFirstChildOfClass("SurfaceGui")
					local label = face and face:FindFirstChildOfClass("TextLabel")
					if label and label.Text == number then
						return object
					end
				end
			end
			return nil
		end
		while round.live() do
			local body, human = character(), humanoid()
			local cake
			for _, place in ipairs({ body, localPlayer:FindFirstChild("Backpack") }) do
				for _, item in ipairs(place and place:GetChildren() or {}) do
					if item:IsA("Tool") and tonumber(item.Name) then
						cake = item
					end
				end
			end
			if cake and body and human then
				if cake.Parent ~= body and not Move.yours() then
					human:EquipTool(cake)
				end
				if lastNumber and lastNumber ~= cake.Name then
					delivered += 1
				end
				lastNumber = cake.Name
				local door = doorFor(cake.Name)
				if door then
					local part = root()
					round.detail = ("cake %s, door %d studs away, %d delivered"):format(cake.Name, part and (door.Position - part.Position).Magnitude or 0, delivered)
					-- The door is set into a wall: walk to just in front of whichever face is nearer
					-- to you, then straight into it.
					local front = door.Position + door.CFrame.LookVector * 3
					local back = door.Position - door.CFrame.LookVector * 3
					local stand = part and (back - part.Position).Magnitude < (front - part.Position).Magnitude and back or front
					if Move.path(round, stand, "door" .. cake.Name, 3.5) then
						Move.to(door.Position)
					end
				else
					round.detail = "cake " .. cake.Name .. ": no door with that number yet"
				end
			else
				if lastNumber then
					delivered += 1
					lastNumber = nil
					log("Cake Delivery: delivered " .. delivered)
				end
				round.detail = delivered > 0 and (delivered .. " delivered, waiting for the next cake") or "waiting for a cake"
			end
			task.wait(0.1)
		end
	end

	-- Hurdle Hurry. You are carried down your lane on your own (walk speed is 0, about 18 studs a
	-- second) and the only thing to do is jump. Each lane (`Lanes.L<n>`) holds its hurdles in
	-- `Hurdles`; the bar is the 7-wide part and its top is level with your waist. A jump at the
	-- game's own jump power is above the bar from 0.07 s to 0.44 s after take-off, so the jump is
	-- timed to put the top of the arc (0.255 s) over the bar. USER: "jump over the hurdles on this one".
	EM.handlers["Hurdle Hurry"] = function(round)
		local lanes = round.model:WaitForChild("Lanes", 8)
		local bars = {}
		local function barsOf(lane)
			if not bars[lane] then
				local list = {}
				local folder = lane:FindFirstChild("Hurdles")
				for _, hurdle in ipairs(folder and folder:GetChildren() or {}) do
					for _, piece in ipairs(hurdle:GetChildren()) do
						if piece:IsA("BasePart") and piece.Transparency < 1 and math.max(piece.Size.X, piece.Size.Z) >= 6 then
							table.insert(list, piece)
							break
						end
					end
				end
				bars[lane] = list
			end
			return bars[lane]
		end
		local jumps, lastJump = 0, 0
		while round.live() do
			local part, human = root(), humanoid()
			if part and human and lanes then
				local velocity = flat(part.AssemblyLinearVelocity)
				local speed = velocity.Magnitude
				if speed > 4 then
					local heading = velocity.Unit
					-- Take-off point: top of the arc over the bar, plus the time the jump takes to start.
					local takeOff = speed * (0.255 + 0.05)
					local nearest
					-- (Every lane is looked at; only a bar straight ahead of you counts.)
					for _, lane in ipairs(lanes:GetChildren()) do
						for _, bar in ipairs(barsOf(lane)) do
							if bar.Parent then
								local to = flat(bar.Position - part.Position)
								local ahead = to:Dot(heading)
								if ahead > 0 and ahead < 60 and (to - heading * ahead).Magnitude < 4 and (not nearest or ahead < nearest) then
									nearest = ahead
								end
							end
						end
					end
					round.detail = nearest and ("next hurdle in %d studs, %d jumped"):format(nearest, jumps) or (jumps .. " jumped, no hurdle ahead")
					if nearest and nearest <= takeOff and nearest > takeOff - speed * 0.12 and human.FloorMaterial ~= Enum.Material.Air and os.clock() - lastJump > 0.3 then
						human.Jump = true
						jumps += 1
						lastJump = os.clock()
					end
				else
					round.detail = "waiting for the start"
				end
			end
			runService.Heartbeat:Wait()
		end
		log("Hurdle Hurry: jumped " .. jumps .. " hurdles")
	end

	---Which brain plays this minigame, or nil when it is left to you.
	function EM.pick(name)
		if not Config.EmAuto then
			return nil
		end
		local special = EM.handlers[name]
		if special and Config.EmSpecial then
			return special, "its own handler"
		end
		local category = EM.category(name)
		if category == "Racing" and Config.EmRace then
			return Brain.race, "follow the leader"
		end
		if (category == "Other" or category == "Luck") and Config.EmSurvive then
			return Brain.survive, "stay with a good player"
		end
		return nil
	end

	----------------------------------------------------------------------------------------------
	-- Rounds.
	----------------------------------------------------------------------------------------------
	local function finish(round, why)
		round.over = true
		EM.round = nil
		local seconds = os.clock() - round.t0
		local model = round.model
		local ended = val("roundended", false) or not val("roundon", true) or (model and model.Parent and model:FindFirstChild("RoundEnd") and model.RoundEnd.Enabled) or false
		local result = ended and "survived" or "out"
		local before = round.wins
		task.spawn(function()
			task.wait(4)
			local won = wins() > before
			local entry = EM.games[round.name] or { played = 0, survived = 0, wins = 0 }
			entry.played += 1
			entry.category = round.category
			entry.brain = round.label or "you"
			if result == "survived" then
				entry.survived += 1
				EM.session.survived += 1
			else
				EM.session.out += 1
			end
			if won then
				entry.wins += 1
				EM.session.wins += 1
			end
			EM.session.rounds += 1
			EM.games[round.name] = entry
			saveGames()
			local steered = round.label and round.ticks and math.floor((round.yoursTicks or 0) / round.ticks * 100 + 0.5) or nil
			entry.steered = steered
			log(("%s (%s) %s: %s after %ds%s"):format(round.name, round.category, round.label or "you played", won and "WON" or result, seconds, steered and steered > 0 and (", you steered " .. steered .. "% of it") or ""))
		end)
	end

	local function begin(name, model)
		local part = root()
		local round = { name = name, model = model, t0 = os.clock(), category = EM.category(name), origin = part and part.Position or Vector3.zero, wins = wins(), detail = "" }
		function round.live()
			return EM.alive and not round.over and mine("inround", false) and model.Parent ~= nil and val("mname", "") == name
		end
		EM.round = round
		Trails.reset()
		local brain, label = EM.pick(name)
		round.label = label
		if brain then
			task.spawn(function()
				-- (The round starts with everyone frozen on their start pad.)
				local ok, err = pcall(brain, round)
				pcall(setthreadidentity, 8)
				if not ok then
					EM.errors["brain " .. name] = tostring(err)
					log("brain error in " .. name .. ": " .. tostring(err))
				end
			end)
		end
		return round
	end

	supervise("rounds", function()
		while EM.alive do
			local name = val("mname", "")
			local model = name ~= "" and workspace:FindFirstChild(name) or nil
			local round = EM.round
			if round then
				if not round.live() then
					finish(round)
				else
					Trails.step()
					round.ticks = (round.ticks or 0) + 1
					if Move.yours() then
						round.yoursTicks = (round.yoursTicks or 0) + 1
					end
					local elapsed = os.clock() - round.t0
					if Config.EmRecord then
						if os.clock() - (round.lateAt or 0) > 1.5 then
							round.lateAt = os.clock()
							pcall(Recorder.late, model, name)
						end
						if elapsed > 10 then
							pcall(Recorder.snapshot, model, name, "t10")
						end
						if elapsed > 30 then
							pcall(Recorder.snapshot, model, name, "t30")
						end
					end
				end
			elseif model and mine("inround", false) then
				begin(name, model)
				if Config.EmRecord then
					pcall(Recorder.snapshot, model, name, "start")
				end
			elseif model and Config.EmRecord and not Recorder.seen["peek" .. name] then
				-- Watching from the lobby still shows the map.
				Recorder.seen["peek" .. name] = true
				pcall(Recorder.snapshot, model, name, "start")
			end
			round = EM.round
			if round then
				EM.status = round.name
				EM.detail = (round.label and (round.label .. ": " .. (round.detail or "")) or "left to you") .. (Move.yours() and " (you are steering)" or "")
			elseif name ~= "" and val("roundon", false) then
				EM.status = "Watching " .. name
				EM.detail = tostring(val("notification", ""))
			else
				EM.status = "Lobby"
				EM.detail = tostring(val("notification", ""))
			end
			task.wait(0.1)
		end
	end)

	----------------------------------------------------------------------------------------------
	-- Chores: staying in the rounds and collecting what the game hands out for playing.
	----------------------------------------------------------------------------------------------
	local PLAYTIME = { 300, 600, 900, 1200, 1500, 1800, 2400, 3000, 3600 }
	EM.claims = {}
	supervise("chores", function()
		while EM.alive do
			task.wait(3)
			local remotes = workspace:FindFirstChild("REs")
			-- The game takes you out of the rounds after a minute without input.
			if Config.EmJoin and mine("playing", true) == false and not val("isparty", false) then
				local playing = localPlayer:FindFirstChild("playing")
				if playing and remotes and remotes:FindFirstChild("otherOption") then
					playing.Value = true
					remotes.otherOption:FireServer("playing", true)
					log("back in the rounds (the game had set you to AFK)")
				end
			end
			local folder = RS:FindFirstChild("RemoteFolder")
			local playEvent = folder and folder:FindFirstChild("PlayEvent")
			if playEvent and mine("dayready", false) then
				if Config.EmDaily and misc("lastday", "") ~= "" and misc("lastday", "") ~= misc("lastclaimday", "") and EM.claims.daily ~= misc("lastday", "") then
					EM.claims.daily = misc("lastday", "")
					playEvent:FireServer("redeemdaily")
					log("claimed the daily reward")
				end
				if Config.EmPlaytime then
					local ok, rewards = pcall(function()
						return httpService:JSONDecode(misc("playtimerewards2", "[]"))
					end)
					local played = misc("playtimetoday2", 0)
					if ok and type(rewards) == "table" then
						for index, reward in ipairs(rewards) do
							local need = PLAYTIME[index]
							local key = "playtime" .. tostring(misc("lastday", "")) .. index
							if need and played >= need and type(reward) == "table" and not reward[3] and not EM.claims[key] then
								EM.claims[key] = true
								playEvent:FireServer("redeemplaytime", index)
								log(("claimed playtime reward %d (%s %s)"):format(index, tostring(reward[1]), tostring(reward[2])))
								task.wait(1)
							end
						end
					end
				end
			end
		end
	end)
end)()
