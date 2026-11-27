
-- Twenty One: the game layer. In a function of its own: the main chunk has no registers to spare.
;(function()
	local T = BeyRivals
	local RS = game:GetService("ReplicatedStorage")
	local Events = RS:WaitForChild("Events", 30)
	local FOLDER = SETTINGS_FOLDER
	T.errors = {}
	T.status = "Waiting for a game"
	T.detail = ""
	T.log = {}
	T.session = { rounds = 0, won = 0, lost = 0, drawn = 0, matches = 0, matchesWon = 0 }
	T.advice = nil
	if not Events then
		T.status = "This is not Twenty One"
		return
	end

	local Engine = (function()
@ENGINE@
	end)()
	T.Engine = Engine

	local function supervise(name, loop)
		task.spawn(function()
			while T.alive do
				local ok, err = pcall(loop)
				pcall(setthreadidentity, 8)
				if not ok then
					T.errors[name] = tostring(err)
				end
				task.wait(1)
			end
		end)
	end

	---One line of the play-by-play: TwentyOne/log.txt, and the last 80 in memory for the panel.
	local function log(text)
		local line = os.date("%H:%M:%S ") .. text
		table.insert(T.log, line)
		if #T.log > 80 then
			table.remove(T.log, 1)
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
	T.say = log

	-- ── The table as the server has told it ────────────────────────────────────────────────
	local S = {
		inGame = false, me = nil, them = nil, round = 0,
		cards = { {}, {} }, bets = { 1, 1 }, distances = { 7, 7 }, onTable = { {}, {} },
		trumps = {}, target = 21, baseTarget = 21, deck = {}, turn = nil, theirPassed = nil,
		theirCountAtTurn = 0, version = 0, opponent = "?", timer = 30,
		rules = {},
	}
	T.state = S
	for value = 1, 11 do
		S.deck[value] = value
	end

	---The game's own match object (it holds the same things, a little later than the events).
	local function holder()
		for _, connection in ipairs(getconnections(Events.AddCards.OnClientEvent)) do
			local fn = connection.Function
			if fn and islclosure(fn) then
				local ok, upvalues = pcall(debug.getupvalues, fn)
				if ok then
					for _, value in pairs(upvalues) do
						if type(value) == "table" and rawget(value, "Players") and rawget(value, "Settings") then
							return value
						end
					end
				end
			end
		end
	end
	T.holder = holder

	local function nameOf(player)
		if typeof(player) == "Instance" then
			return player.Name
		end
		return tostring(player)
	end

	local function applySettings(settings)
		S.settings = settings
		S.me, S.them = nil, nil
		for index = 1, 2 do
			if settings["Player" .. index] == localPlayer then
				S.me, S.them = index, 3 - index
			end
		end
		if not S.me then
			return false
		end
		S.opponent = nameOf(settings["Player" .. S.them])
		S.baseTarget = tonumber(settings.WinScore) or 21
		S.target = S.baseTarget
		S.timer = tonumber(settings.Timer) or 30
		if type(settings.Deck) == "table" and #settings.Deck > 0 then
			S.deck = table.clone(settings.Deck)
			table.sort(S.deck)
		end
		local start = tonumber(settings.Saw_Distance) or 7
		S.distances = { start, start }
		return true
	end

	local function plainCards(list)
		local out = {}
		for _, card in ipairs(list or {}) do
			table.insert(out, { card[1], card[2] and true or false })
		end
		return out
	end

	---Picks the table up from the game when the script is loaded in the middle of a match.
	local function syncFromGame()
		local game_ = holder()
		if not game_ or type(game_.Players) ~= "table" or not game_.Settings then
			return false
		end
		if not applySettings(game_.Settings) then
			return false
		end
		for index, entry in pairs(game_.Players) do
			S.cards[index] = plainCards(entry.Cards)
			S.bets[index] = tonumber(entry.Bet) or 1
			S.distances[index] = tonumber(entry.Distance) or S.distances[index]
			local names = {}
			for _, played in ipairs(entry.TrumpsOnTable or {}) do
				table.insert(names, type(played) == "table" and played[1] or played)
			end
			S.onTable[index] = names
			if index == S.me then
				S.trumps = table.clone(entry.Trumps or {})
			end
		end
		S.target = tonumber(game_.WinningScore) or S.baseTarget
		S.inGame = true
		S.version += 1
		return true
	end

	local function values(index, known)
		local list, hidden = {}, 0
		for _, card in ipairs(S.cards[index] or {}) do
			if type(card[1]) == "number" then
				table.insert(list, card[1])
			else
				hidden += 1
			end
		end
		return list, hidden
	end

	---The table in the shape the engine wants.
	local function snapshot()
		if not (S.inGame and S.me) then
			return nil
		end
		local mine = values(S.me)
		local theirs, hidden = values(S.them)
		if #mine == 0 then
			return nil
		end
		local t = {
			cards = S.deck, target = S.target, baseTarget = S.baseTarget,
			mine = mine, theirs = theirs, hidden = hidden, theirPassed = S.theirPassed,
			myBet = S.bets[S.me], theirBet = S.bets[S.them],
			myDistance = S.distances[S.me], theirDistance = S.distances[S.them],
			trumps = S.trumps, tableTheirs = S.onTable[S.them],
			blessed = (table.find(S.onTable[1], "Bless") or table.find(S.onTable[2], "Bless")) and true or false,
		}
		-- Cards his face-down one cannot be, from what he has done this round.
		if hidden == 1 and #S.rules > 0 then
			local impossible = {}
			for _, card in ipairs(Engine.candidates(t)) do
				for _, rule in ipairs(S.rules) do
					if not rule(card) then
						impossible[card] = true
					end
				end
			end
			t.impossible = impossible
		end
		return t
	end
	T.snapshot = snapshot

	local function handText(index)
		local parts, total, hidden = {}, 0, 0
		for _, card in ipairs(S.cards[index] or {}) do
			if type(card[1]) == "number" then
				total += card[1]
				table.insert(parts, card[2] and ("[" .. card[1] .. "]") or tostring(card[1]))
			else
				hidden += 1
				table.insert(parts, "[?]")
			end
		end
		return table.concat(parts, " "), total, hidden
	end

	local function percent(x)
		return ("%d%%"):format(math.floor(x * 100 + 0.5))
	end
	local function chances(rated)
		if not rated then
			return "not possible"
		end
		return ("win %s, tie %s, lose %s"):format(percent(rated.win), percent(rated.draw), percent(rated.lose))
	end

	-- ── What the server sends ──────────────────────────────────────────────────────────────
	local function on(name, fn)
		local remote = Events:FindFirstChild(name)
		if remote and remote:IsA("RemoteEvent") then
			table.insert(T.connections, remote.OnClientEvent:Connect(function(...)
				local ok, err = pcall(fn, ...)
				if not ok then
					T.errors[name] = tostring(err)
				end
			end))
		end
	end

	on("LoadRoom", function(settings)
		if type(settings) ~= "table" then
			return
		end
		S.cards, S.bets, S.onTable, S.trumps = { {}, {} }, { 1, 1 }, { {}, {} }, {}
		S.round, S.theirPassed, S.turn = 0, nil, nil
		S.rules, S.perfect = {}, nil
		if applySettings(settings) then
			S.inGame = true
			T.gone = -300
			T.session.matches += 1
			log(("── Match against %s. First to run the other out of %d. Target %d, deck %d to %d."):format(S.opponent, S.distances[1], S.target, S.deck[1], S.deck[#S.deck]))
		end
		S.version += 1
	end)
	on("ClearTable", function()
		S.cards = { {}, {} }
		S.theirPassed, S.turn = nil, nil
		S.target = S.baseTarget
		S.onTable = { {}, {} }
		S.rules, S.perfect = {}, nil
		S.shown = false
		S.version += 1
	end)
	on("AddCards", function(mine, all)
		if not S.me then
			if not syncFromGame() then
				return
			end
		end
		S.inGame = true
		local before = { #S.cards[1], #S.cards[2] }
		local beforeTotal = { select(2, handText(1)), select(2, handText(2)) }
		local was = { S.cards[1], S.cards[2] }
		if type(all) == "table" then
			S.cards[S.them] = plainCards(all[S.them])
		end
		S.cards[S.me] = plainCards(mine)
		for _, index in ipairs({ S.me, S.them }) do
			local who = index == S.me and "You" or S.opponent
			local now = S.cards[index]
			local text, total, hidden = handText(index)
			local totalText = hidden > 0 and (total .. " + ?") or tostring(total)
			if #now > before[index] then
				local card = now[#now]
				if index == S.them and S.perfect and type(card[1]) == "number" then
					-- A Perfect Draw gives him the biggest card in the deck that still fits. So his
					-- face-down card is one for which this card fits and no bigger one left would.
					local drawn, shown, target, mineNow = card[1], beforeTotal[index], S.target, {}
					for _, own in ipairs(S.cards[S.me]) do
						mineNow[own[1]] = true
					end
					local onShow = {}
					for _, other in ipairs(now) do
						if type(other[1]) == "number" then
							onShow[other[1]] = true
						end
					end
					local deck = table.clone(S.deck)
					table.insert(S.rules, function(hiddenCard)
						local fits = shown + hiddenCard + drawn <= target
						local anyFits = fits
						for _, other in ipairs(deck) do
							if other ~= hiddenCard and not mineNow[other] and not onShow[other] then
								if shown + hiddenCard + other <= target then
									anyFits = true
									if other > drawn then
										return false
									end
								end
							end
						end
						return fits or not anyFits
					end)
					S.perfect = nil
					local t = snapshot()
					if t and t.impossible then
						local left = Engine.possible(t)
						log(("· That Perfect Draw gives it away: the face-down card can only be %s."):format(table.concat(left, " or ")))
					end
				end
				local dealt = #now <= 2 and S.turn == nil
				if #now == 1 and S.turn == nil then
					if index == S.me then
						S.round += 1
						S.rules, S.perfect, S.shown = {}, nil, false
						log(("Round %d. Your face-down card is %s. Bets: you %d, %s %d. Lives: you %d, %s %d."):format(math.max(S.round, 1), tostring(card[1]), S.bets[S.me], S.opponent, S.bets[S.them], S.distances[S.me], S.opponent, S.distances[S.them]))
					end
				else
					log(("%s %s %s  →  %s  (%s)"):format(who, dealt and (index == S.me and "are dealt" or "is dealt") or (index == S.me and "draw" or "draws"), type(card[1]) == "number" and tostring(card[1]) or "a face-down card", text, totalText))
				end
			elseif #now < before[index] then
				log(("%s lost a card  →  %s  (%s)"):format(who == "You" and "You" or who, text, totalText))
			elseif #now == before[index] and #now > 0 then
				local last, old = now[#now], was[index][#now]
				if old and last[1] ~= old[1] then
					log(("%s last card is now %s  →  %s  (%s)"):format(who == "You" and "Your" or (who .. "'s"), tostring(last[1]), text, totalText))
				end
			end
		end
		S.version += 1
	end)
	on("EnvChange", function(who)
		if typeof(who) ~= "Instance" then
			if who == "Timer" then
				log("The turn timer ran out.")
			end
			return
		end
		local previous = S.turn
		S.turn = who
		local theirCount = #S.cards[S.them or 2]
		local myCount = #S.cards[S.me or 1]
		if who == localPlayer then
			if previous and previous ~= localPlayer then
				S.theirPassed = theirCount <= S.theirCountAtTurn
				if S.theirPassed then
					log(S.opponent .. " passes.")
				end
			end
			S.myCountAtTurn = myCount
		else
			if previous == localPlayer and myCount <= (S.myCountAtTurn or 0) then
				log("You pass.")
			end
			S.theirCountAtTurn = theirCount
		end
		S.version += 1
	end)
	on("ShowHiddenCards", function(all)
		if type(all) ~= "table" or not S.me then
			return
		end
		-- What the face-down card turned out to be, against what could be worked out.
		local guess = snapshot()
		local odds = guess and guess.hidden == 1 and Engine.hiddenOdds(guess) or nil
		for index = 1, 2 do
			S.cards[index] = plainCards(all[index])
		end
		S.shown = true
		local mineText, mineTotal = handText(S.me)
		local theirText, theirTotal = handText(S.them)
		local hiddenCard = S.cards[S.them][1] and S.cards[S.them][1][1]
		local note = ""
		if odds and type(hiddenCard) == "number" then
			for _, entry in ipairs(odds) do
				if entry.card == hiddenCard then
					note = (" Their face-down card was %d (one of %d it could have been, rated %s)."):format(hiddenCard, #odds, percent(entry.chance))
				end
			end
		end
		log(("Showdown, target %d. You: %s = %d. %s: %s = %d.%s"):format(S.target, mineText, mineTotal, S.opponent, theirText, theirTotal, note))
		S.version += 1
	end)
	on("WinOrLoseEffect", function(winner)
		T.session.rounds += 1
		if winner == S.me then
			T.session.won += 1
			log(("You win the round. %s loses %d."):format(S.opponent, S.bets[S.them] or 1))
		elseif winner == S.them then
			T.session.lost += 1
			log(("You lose the round and %d."):format(S.bets[S.me] or 1))
		else
			T.session.drawn += 1
			log("The round is a tie.")
		end
	end)
	on("DistanceChangedVisual", function(distances)
		if type(distances) == "table" then
			S.distances = { tonumber(distances[1]) or S.distances[1], tonumber(distances[2]) or S.distances[2] }
			if S.me then
				log(("Lives: you %d, %s %d."):format(S.distances[S.me], S.opponent, S.distances[S.them]))
			end
			S.version += 1
		end
	end)
	on("ChangeVisualBet", function(bets)
		if type(bets) == "table" then
			local old = S.bets
			S.bets = { tonumber(bets[1]) or 1, tonumber(bets[2]) or 1 }
			if S.me and #S.cards[S.me] > 0 and (old[1] ~= S.bets[1] or old[2] ~= S.bets[2]) then
				log(("Bets now: you %d, %s %d."):format(S.bets[S.me], S.opponent, S.bets[S.them]))
			end
			S.version += 1
		end
	end)
	on("UpdateWinningScore", function(score)
		if tonumber(score) and tonumber(score) ~= S.target then
			S.target = tonumber(score)
			log(("The target is now %d."):format(S.target))
			S.version += 1
		end
	end)
	on("UpdatePlayerTrumps", function(list)
		if type(list) == "table" then
			S.trumps = table.clone(list)
			S.version += 1
		end
	end)
	on("PlayedTrumpVisual", function(played)
		if type(played) ~= "table" then
			return
		end
		for index = 1, 2 do
			local names = {}
			for _, entry in ipairs(played[index] or {}) do
				table.insert(names, type(entry) == "table" and entry[1] or entry)
			end
			S.onTable[index] = names
		end
		S.version += 1
	end)
	on("Message", function(text, _, args)
		if type(text) ~= "string" then
			return
		end
		local ok, formatted = pcall(string.format, text, table.unpack(type(args) == "table" and args or {}))
		formatted = ok and formatted or text
		if formatted:find("trump") then
			log("· " .. formatted:sub(1, 1):upper() .. formatted:sub(2) .. ".")
		end
		if text:find("opponent used") and type(args) == "table" then
			if args[1] == "Perfect Draw" then
				S.perfect = true
			elseif args[1] == "Refresh" then
				S.rules, S.perfect = {}, nil
			end
		end
	end)
	on("WonScreenAndLeave", function(winner)
		local won = winner == localPlayer or winner == S.me
		if won then
			T.session.matchesWon += 1
		end
		log("── The match is over" .. (winner ~= nil and (": " .. (won and "you won." or "you lost.")) or "."))
		S.inGame = false
	end)
	on("AfterRoundInfo", function(choice)
		log(choice == "NEXT" and "── Both of you chose another game." or "── Back to the menu.")
		if choice ~= "NEXT" then
			S.inGame = false
		end
	end)

	-- ── Advice ─────────────────────────────────────────────────────────────────────────────
	---The best thing to do now: { kind = "trump"|"draw"|"pass", name, text, base, rated }.
	local function think(allowTrumps, yield)
		local t = snapshot()
		if not t then
			return nil
		end
		t.yield = yield
		local rated, base
		if allowTrumps and #S.trumps > 0 then
			rated, base = Engine.rateTrumps(t)
		else
			base = Engine.advise(t)
		end
		local result = { base = base, rated = rated or {}, table = t }
		local top = rated and rated[1]
		if top and top.gain > 0 then
			result.kind, result.name = "trump", top.name
			result.text = ("Play %s: %s."):format(top.name, top.why)
		else
			result.kind = base.move
			result.text = (base.move == "draw" and "DRAW" or "PASS") .. (" (%s)"):format(chances(base.best))
		end
		return result
	end
	T.think = think

	---The lines of the on-screen panel.
	local function describe()
		if not (S.inGame and S.me) then
			return "No game on the table."
		end
		local lines = {}
		local mineText, mineTotal = handText(S.me)
		local theirText, theirTotal, theirHidden = handText(S.them)
		table.insert(lines, ("Round %d   target %d"):format(math.max(S.round, 1), S.target))
		table.insert(lines, ("You   %s  = %d    bet %d, lives %d"):format(mineText, mineTotal, S.bets[S.me], S.distances[S.me]))
		table.insert(lines, ("Them  %s  = %d%s    bet %d, lives %d"):format(theirText, theirTotal, theirHidden > 0 and " + ?" or "", S.bets[S.them], S.distances[S.them]))
		local t = snapshot()
		if t and not S.shown then
			if t.hidden == 1 then
				local parts = {}
				for _, entry in ipairs(Engine.hiddenOdds(t)) do
					table.insert(parts, ("%d→%d%s"):format(entry.card, entry.total, entry.total > t.target and "✗" or ""))
				end
				table.insert(lines, "Face-down could be (card→their total): " .. table.concat(parts, "  "))
			end
			local left = Engine.candidates(t)
			local safe = 0
			for _, card in ipairs(left) do
				if mineTotal + card <= t.target then
					safe += 1
				end
			end
			table.insert(lines, ("Not seen yet: %s   (%d of %d keep you at %d or under)"):format(table.concat(left, " "), safe, #left, t.target))
		end
		if #S.trumps > 0 then
			table.insert(lines, "Your trumps: " .. table.concat(S.trumps, ", "))
		end
		for _, index in ipairs({ S.me, S.them }) do
			if #S.onTable[index] > 0 then
				table.insert(lines, (index == S.me and "On the table, yours: " or "On the table, theirs: ") .. table.concat(S.onTable[index], ", "))
			end
		end
		return table.concat(lines, "\n")
	end
	T.describe = describe

	-- ── My turn ────────────────────────────────────────────────────────────────────────────
	local wrapper, afterWrapper

	local function useTrump(name)
		local index = table.find(S.trumps, name)
		if index then
			table.remove(S.trumps, index)
		end
		local game_ = holder()
		local ok = false
		if game_ and type(game_.UseTrump) == "function" then
			pcall(setthreadidentity, 2)
			ok = pcall(game_.UseTrump, game_, name)
			pcall(setthreadidentity, 8)
		end
		if not ok then
			Events.UseTrump:FireServer(name)
		end
	end

	---Plays the turn: trump cards first while one is worth it, then draw or pass.
	local function autoTurn()
		local started = os.clock()
		local budget = math.max(8, S.timer - 8)
		local function yield()
			task.wait()
		end
		local pause = math.clamp(Config.T21Delay, 0, 10)
		local played = 0
		while T.alive and Config.T21Auto do
			local hurried = os.clock() - started > budget * 0.6
			local plan = think(Config.T21Trumps and played < 4 and not hurried, yield)
			if not plan then
				return "P"
			end
			T.advice = plan
			if plan.kind == "trump" then
				local base = plan.base
				log(("▶ You play %s: %s. (Otherwise: %s, %s.)"):format(plan.name, plan.rated[1].why, base.move, chances(base.best)))
				task.wait(math.min(pause, 2))
				local version = S.version
				useTrump(plan.name)
				played += 1
				-- The table changes when the server has carried it out.
				local waited = 0
				while waited < 3 and S.version == version do
					waited += task.wait(0.1)
				end
				task.wait(1.2)
			else
				local base = plan.base
				local other = base.move == "draw" and base.pass or base.draw
				log(("▶ You %s. %s. %s: %s."):format(base.move == "draw" and "draw" or "pass", chances(base.best):sub(1, 1):upper() .. chances(base.best):sub(2), base.move == "draw" and "Passing" or "Drawing", chances(other)))
				local left = pause - (os.clock() - started)
				if left > 0 and not hurried then
					task.wait(left)
				end
				return base.move == "draw" and "D" or "P"
			end
		end
		return nil
	end

	local function callOriginal(fn, ...)
		pcall(setthreadidentity, 2)
		return fn(...)
	end

	wrapper = function(...)
		T.myTurn = true
		T.turnStarted = os.clock()
		local answer
		if Config.T21Auto then
			local ok, result = pcall(autoTurn)
			if ok then
				answer = result
			else
				T.errors.turn = tostring(result)
				log("The auto player hit an error: " .. tostring(result))
			end
		end
		if not answer then
			-- Yours to play: the game's own prompt, with the advice on the panel.
			local plan = nil
			pcall(function()
				plan = think(Config.T21Trumps, nil)
			end)
			T.advice = plan
			if plan then
				log("Your move. Suggested: " .. plan.text)
			end
			if T.original then
				local ok, result = pcall(callOriginal, T.original, ...)
				pcall(setthreadidentity, 8)
				answer = ok and result or "P"
			else
				answer = "P"
			end
			if plan and (answer == "D" or answer == "P") then
				local suggested = plan.base.move == "draw" and "D" or "P"
				if answer ~= suggested then
					log(("You chose to %s; the suggestion was to %s."):format(answer == "D" and "draw" or "pass", plan.base.move))
				end
			end
		end
		T.myTurn = false
		T.advice = nil
		return answer
	end

	afterWrapper = function(...)
		local choice = Config.T21After
		if choice == "Next" or choice == "Menu" then
			local args = table.pack(...)
			if T.originalAfter then
				-- The game's own screen still has to come up; its answer is not used.
				task.spawn(function()
					pcall(callOriginal, T.originalAfter, table.unpack(args, 1, args.n))
				end)
			end
			task.wait(3)
			log(choice == "Next" and "▶ Asked for another game." or "▶ Chose the menu.")
			return choice == "Next" and "NEXT" or "MENU"
		end
		if T.originalAfter then
			return callOriginal(T.originalAfter, ...)
		end
		return "MENU"
	end

	---The game sets its turn callbacks anew for every match: keep ours in front of them.
	local function hook()
		local ok, current = pcall(getcallbackvalue, Events.AskPlayer, "OnClientInvoke")
		-- The game clears its callback when the room is torn down.
		if ok and current == nil then
			T.gone = (T.gone or 0) + 1
			if S.inGame and T.gone > 30 then
				S.inGame = false
				S.version += 1
				log("── Left the table.")
			end
		else
			T.gone = 0
		end
		if ok and current and current ~= wrapper then
			T.original = current
			Events.AskPlayer.OnClientInvoke = wrapper
			if not S.inGame then
				syncFromGame()
			end
		end
		local okAfter, currentAfter = pcall(getcallbackvalue, Events.AskPlayerAfterRound, "OnClientInvoke")
		if okAfter and currentAfter and currentAfter ~= afterWrapper then
			T.originalAfter = currentAfter
			Events.AskPlayerAfterRound.OnClientInvoke = afterWrapper
		end
	end
	local function unhook()
		pcall(function()
			if getcallbackvalue(Events.AskPlayer, "OnClientInvoke") == wrapper then
				Events.AskPlayer.OnClientInvoke = T.original
			end
		end)
		pcall(function()
			if getcallbackvalue(Events.AskPlayerAfterRound, "OnClientInvoke") == afterWrapper then
				Events.AskPlayerAfterRound.OnClientInvoke = T.originalAfter
			end
		end)
	end
	table.insert(T.connections, { Disconnect = unhook })
	T.canHook = type(getcallbackvalue) == "function"
	pcall(syncFromGame)
	supervise("hook", function()
		while T.alive do
			if T.canHook then
				hook()
			end
			task.wait(0.1)
		end
	end)

	-- Advice while it is your turn and you are playing it yourself: kept fresh as the table changes.
	supervise("advice", function()
		local seen = -1
		while T.alive do
			if T.myTurn and not Config.T21Auto and S.version ~= seen then
				seen = S.version
				task.wait(0.4)
				T.advice = think(Config.T21Trumps, function()
					task.wait()
				end)
			end
			-- Without a way to read the game's callback the turn is told from the game's own flag.
			if not T.canHook then
				local game_ = holder()
				local turn = game_ and game_.PlayerTurn == true
				if turn and not T.myTurn then
					seen = -1
				end
				T.myTurn = turn
			end
			task.wait(0.2)
		end
	end)

	supervise("status", function()
		while T.alive do
			if not S.inGame then
				T.status = "Waiting for a game"
				T.detail = "Start or join a room; it picks the game up by itself."
			elseif T.myTurn then
				T.status = Config.T21Auto and "Playing your turn" or "Your turn"
				T.detail = T.advice and T.advice.text or "Thinking"
			else
				T.status = ("Round %d against %s"):format(math.max(S.round, 1), S.opponent)
				T.detail = S.turn == localPlayer and "Your turn" or (S.opponent .. " to move")
			end
			task.wait(0.25)
		end
	end)

	-- ── The panel on screen ────────────────────────────────────────────────────────────────
	do
		local parent = (gethui and gethui()) or game:GetService("CoreGui")
		local old = parent:FindFirstChild("TwentyOnePanel")
		if old then
			old:Destroy()
		end
		local screen = Instance.new("ScreenGui")
		screen.Name = "TwentyOnePanel"
		screen.ResetOnSpawn = false
		screen.IgnoreGuiInset = true
		screen.DisplayOrder = 40
		screen.Parent = parent
		table.insert(T.connections, { Disconnect = function()
			screen:Destroy()
		end })
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(1, 0)
		frame.Position = UDim2.new(1, -16, 0, 70)
		frame.Size = UDim2.fromOffset(430, 120)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.BackgroundColor3 = Color3.fromRGB(16, 21, 28)
		frame.BackgroundTransparency = 0.12
		frame.BorderSizePixel = 0
		frame.Active = true
		frame.Parent = screen
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(47, 71, 87)
		stroke.Parent = frame
		local padding = Instance.new("UIPadding")
		padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
		padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
		padding.Parent = frame
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = frame
		local function label(order, size, colour, bold)
			local item = Instance.new("TextLabel")
			item.LayoutOrder = order
			item.BackgroundTransparency = 1
			item.Size = UDim2.new(1, 0, 0, 0)
			item.AutomaticSize = Enum.AutomaticSize.Y
			item.TextWrapped = true
			item.TextXAlignment = Enum.TextXAlignment.Left
			item.TextYAlignment = Enum.TextYAlignment.Top
			item.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
			item.TextSize = size
			item.TextColor3 = colour
			item.Text = ""
			item.Parent = frame
			return item
		end
		local title = label(1, 13, Color3.fromRGB(242, 179, 61), true)
		local move = label(2, 20, Color3.fromRGB(233, 238, 240), true)
		local why = label(3, 13, Color3.fromRGB(141, 162, 174))
		local tableText = label(4, 13, Color3.fromRGB(233, 238, 240))
		local history = label(5, 12, Color3.fromRGB(141, 162, 174))
		-- Dragging.
		do
			local userInput = game:GetService("UserInputService")
			local dragging, origin, startPosition
			table.insert(T.connections, frame.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging, origin, startPosition = true, input.Position, frame.Position
				end
			end))
			table.insert(T.connections, userInput.InputChanged:Connect(function(input)
				if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
					local delta = input.Position - origin
					frame.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
				end
			end))
			table.insert(T.connections, userInput.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = false
				end
			end))
		end
		supervise("panel", function()
			while T.alive do
				screen.Enabled = Config.T21Panel and (S.inGame or not Config.T21PanelOnlyInGame)
				if screen.Enabled then
					title.Text = "TWENTY ONE   " .. (Config.T21Auto and "auto is on" or "you play, it advises")
					local plan = T.advice
					if not S.inGame then
						move.Text = "No game yet"
						why.Text = ""
					elseif T.myTurn and plan then
						local base = plan.base
						if plan.kind == "trump" then
							move.Text = (Config.T21Auto and "Playing " or "Play ") .. plan.name
							why.Text = plan.rated[1].why:sub(1, 1):upper() .. plan.rated[1].why:sub(2) .. (".\nAfter that or without it: %s (%s)."):format(base.move, chances(base.best))
						else
							move.Text = (Config.T21Auto and "" or "Your move: ") .. (base.move == "draw" and "DRAW" or "PASS")
							local other = base.move == "draw" and base.pass or base.draw
							why.Text = ("%s: %s.\n%s: %s."):format(base.move == "draw" and "Draw" or "Pass", chances(base.best), base.move == "draw" and "Pass" or "Draw", chances(other))
						end
						move.TextColor3 = Color3.fromRGB(70, 196, 126)
					elseif T.myTurn then
						move.Text = "Thinking"
						why.Text = ""
					else
						move.Text = S.shown and "Showdown" or (S.opponent .. " to move")
						move.TextColor3 = Color3.fromRGB(233, 238, 240)
						why.Text = ""
					end
					tableText.Text = describe()
					local lines = {}
					for index = math.max(1, #T.log - 6), #T.log do
						table.insert(lines, (T.log[index]:sub(10)))
					end
					history.Text = table.concat(lines, "\n")
				end
				task.wait(0.2)
			end
		end)
	end

	-- Cash, for the Home page.
	T.cash = nil
	supervise("cash", function()
		while T.alive do
			local ok, info = pcall(function()
				return Events.GetCash:InvokeServer()
			end)
			if ok and type(info) == "table" and tonumber(info.Cash) then
				T.cash = tonumber(info.Cash)
				T.cashStart = T.cashStart or T.cash
			end
			task.wait(30)
		end
	end)
	log("Twenty One " .. BeyRivals.VERSION .. " loaded." .. (S.inGame and " A game is already on the table." or ""))
end)()
