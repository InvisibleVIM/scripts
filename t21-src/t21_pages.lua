-- Twenty One pages.
;(function()
	local T = BeyRivals
	local function live(fn)
		task.spawn(function()
			while T.alive do
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
		heading(page, "Play", "left")
		toggle(page, "Play for me", "T21Auto")
		hint(page, "On: it plays every turn of yours, trump cards included. Off: you play, and the panel tells you the best move with the chances for drawing and passing.")
		toggle(page, "Use trump cards", "T21Trumps")
		hint(page, "On: trump cards are played (auto) or suggested (advice) when one is worth more than keeping it. Off: draw and pass only.")
		UI.slider(page, "Time per move", "T21Delay", 0, 10, 0.5, function(v)
			return v == 0 and "At once" or (tostring(v) .. " s")
		end, "How long the auto player waits before it draws or passes, so it does not answer in the same instant every time.")
		UI.segmented(page, "After a match", "T21After", { "Ask", "Next", "Menu" }, "What to answer when the game asks for another round against the same player. Ask leaves it to you.", { Ask = "Ask me", Next = "Play again", Menu = "Menu" })
		heading(page, "Panel", "left")
		toggle(page, "Show the panel", "T21Panel")
		hint(page, "The box on the right of the screen: the suggested move, both hands, what the face-down card could be, and the last lines of the play-by-play. Drag it anywhere.")
		toggle(page, "Only during a game", "T21PanelOnlyInGame")
		heading(page, "This session", "right", "Counted since the script loaded.")
		local rounds, won, lost, tied, matches, cash = UI.kv(page, "Rounds"), UI.kv(page, "Won"), UI.kv(page, "Lost"), UI.kv(page, "Tied"), UI.kv(page, "Matches won"), UI.kv(page, "Cash gained")
		UI.callout(page, "The other player's face-down card cannot be read: the server only sends it at the showdown. What can be known is which cards it is not, and the panel lists every card it could still be.")
		heading(page, "Play-by-play", "right", "The same lines go to TwentyOne/log.txt in the executor's workspace folder.")
		local recent = UI.infoLine(page, 260)
		live(function()
			statusLine.Text = T.status
			detailLine.Text = T.detail
			rounds.Text = tostring(T.session.rounds)
			won.Text = tostring(T.session.won)
			lost.Text = tostring(T.session.lost)
			tied.Text = tostring(T.session.drawn)
			matches.Text = ("%d of %d"):format(T.session.matchesWon, T.session.matches)
			cash.Text = T.cash and tostring(T.cash - (T.cashStart or T.cash)) or "?"
			local lines = {}
			for index = math.max(1, #T.log - 13), #T.log do
				table.insert(lines, T.log[index])
			end
			recent.Text = #lines > 0 and table.concat(lines, "\n") or "Nothing yet."
		end)
	end
end)()
