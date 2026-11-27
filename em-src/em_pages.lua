-- Epic Minigames pages.
;(function()
	local EM = BeyRivals
	local function live(fn)
		task.spawn(function()
			while EM.alive do
				pcall(fn)
				task.wait(0.5)
			end
		end)
	end
	do
		local page = makePage("Home", "What it is doing right now.", "Play")
		heading(page, "Now", "left")
		local statusLine = UI.infoLine(page, 20)
		local detailLine = UI.infoLine(page, 40)
		heading(page, "This session", "left", "Counted since the script loaded. A win is the game adding one to your wins this month.")
		local rounds, survived, out, won, coins = UI.kv(page, "Rounds played"), UI.kv(page, "Lasted to the end"), UI.kv(page, "Knocked out"), UI.kv(page, "Wins"), UI.kv(page, "Coins gained")
		UI.callout(page, "Leave walk speed, jump power, fly and float on the Universal tab off in this game. It puts them back by itself and reports some of them to the server.")
		heading(page, "Recent", "right", "The same lines go to EpicMinigames/log.txt in the executor's workspace folder.")
		local recent = UI.infoLine(page, 200)
		local startCoins = EM.misc("points", 0)
		live(function()
			statusLine.Text = EM.status
			detailLine.Text = EM.detail
			rounds.Text = tostring(EM.session.rounds)
			survived.Text = tostring(EM.session.survived)
			out.Text = tostring(EM.session.out)
			won.Text = tostring(EM.session.wins)
			coins.Text = tostring(EM.misc("points", 0) - startCoins)
			local lines = {}
			for index = math.max(1, #EM.log - 9), #EM.log do
				table.insert(lines, EM.log[index])
			end
			recent.Text = #lines > 0 and table.concat(lines, "\n") or "Nothing yet."
		end)
	end
	do
		local page = makePage("Play", "Which minigames it plays for you.", "Play")
		heading(page, "Play for me", "left", "It only walks and jumps, the way you would. Touch W, A, S, D or Space and it lets go for a moment.")
		toggle(page, "Play minigames for me", "EmAuto")
		hint(page, "The main switch. Off: you play everything and it only records and collects rewards.")
		toggle(page, "Minigames with their own handler", "EmSpecial")
		hint(page, "Uses a handler written for that minigame when there is one. So far: Paint to Perfection (clicks your easel until it matches the board) Balloon Platoon (shoots the balloon of the called colour) Accurate Archery (shoots the targets, golden ones first) Eagle Observation (counts every eagle) Cannon Cooldown (steps on your team's pads until they are green) Timestamp Trace (stops your timer on the big clock's time) Drawing the Line (walks the line in your lane) Hurdle Hurry (jumps each hurdle in your lane) Cake Delivery (walks your cake to the door with its number), Block Hunt (marks the other team's blocks through walls and walks to them; hiding is yours) Fishing Frenzy (moves your mouse onto the next fish and away from sharks) The Sweeper (jumps the bar each time it comes round) Just Jump (jumps the rope each turn) and Toxic Reactions (walks to the platform whose colour the sign shows). More are added from the recordings below.")
		UI.slider(page, "Fist reach in brawls", "EmFistReach", 0, 20, 1, function(v)
			return v == 0 and "Off" or (tostring(v) .. " studs")
		end, "Backstreet Brawl: your punch counts on anyone this close, not only those you touch. You still click to punch. 0 leaves the fist as the game made it.")
		heading(page, "Left to you", "left")
		UI.note(page, "Every minigame without a handler of its own. Nothing follows other players any more.")
		heading(page, "Rounds", "right")
		toggle(page, "Stay in the rounds", "EmJoin")
		hint(page, "The game marks you AFK after a minute without input and stops putting you in minigames. This puts you back in.")
		heading(page, "Learning", "right", "A minigame's map and scripts only exist while it is being played.")
		toggle(page, "Record new minigames", "EmRecord")
		hint(page, "Writes each minigame's layout and scripts to EpicMinigames/rec the first time it comes up, so a handler can be written for it. Costs a short hitch at the start of a new minigame.")
		local seenLine = UI.infoLine(page, 20)
		live(function()
			local count = 0
			for _ in pairs(EM.games) do
				count += 1
			end
			seenLine.Text = count .. " different minigames played so far"
		end)
	end
	do
		local page = makePage("Rewards", "Free rewards for playing.", "Play")
		heading(page, "Collect", "left", "Nothing here spends coins, stars or Robux.")
		toggle(page, "Daily reward", "EmDaily")
		hint(page, "Claims today's daily reward once the game has it ready.")
		toggle(page, "Playtime rewards", "EmPlaytime")
		hint(page, "Claims each playtime reward as you reach it: every 5 minutes for the first half hour, then every 10 up to an hour.")
		heading(page, "Today", "right")
		local played, streak = UI.kv(page, "Played today"), UI.kv(page, "Day streak")
		live(function()
			local seconds = EM.misc("playtimetoday2", 0)
			played.Text = ("%d min"):format(seconds / 60)
			streak.Text = tostring(EM.misc("daystreak", 0))
		end)
	end
	do
		local page = makePage("Minigames", "How each minigame has gone.", "Play")
		heading(page, "Record", "left", "Played / lasted to the end / won, and what played it.")
		local text = UI.infoLine(page, 400)
		live(function()
			local names = {}
			for name in pairs(EM.games) do
				table.insert(names, name)
			end
			table.sort(names)
			local lines = {}
			for _, name in ipairs(names) do
				local entry = EM.games[name]
				table.insert(lines, ("%s: %d / %d / %d  (%s)"):format(name, entry.played or 0, entry.survived or 0, entry.wins or 0, tostring(entry.brain or "you")))
			end
			text.Text = #lines > 0 and table.concat(lines, "\n") or "No rounds yet."
		end)
	end
end)()
