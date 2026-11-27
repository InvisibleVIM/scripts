-- Twenty One: the thinking part. Pure Luau (no Roblox calls) so it can be run and checked
-- outside the game.
--
-- The game: a deck of the numbers in Settings.Deck (1 to 11, one of each). Each player has one
-- face-down card and the rest face-up. On your turn you draw or pass; when both pass in a row
-- the hands are shown. Nearest to the target (21 unless a "Go for" trump changed it) without
-- going over wins; if both are over, the nearer one wins; equal is a draw. The loser pays his
-- own bet in "distance".
--
-- What is not known is the opponent's face-down card and the order of the deck. Every card not
-- on show is equally likely to be the hidden one, a little less so for the ones that would
-- make the opponent's last move (drawing or passing) a strange one.
local Engine = {}

local function bit(card)
	return 2 ^ (card - 1)
end
local function has(mask, card)
	return math.floor(mask / bit(card)) % 2 == 1
end
Engine.has = has

---Who wins a showdown: 1 me, -1 them, 0 draw.
function Engine.showdown(mine, theirs, target)
	local meOver, themOver = mine > target, theirs > target
	if meOver and themOver then
		if mine == theirs then
			return 0
		end
		return mine < theirs and 1 or -1
	elseif meOver then
		return -1
	elseif themOver then
		return 1
	elseif mine == theirs then
		return 0
	end
	return mine > theirs and 1 or -1
end

---How likely the opponent is to draw, holding `total`, with these cards (mask) still unseen
---by him. He draws when most of what is left is safe for him, and when he cannot bust.
function Engine.opponentDraws(total, target, mask, cards)
	if total > target then
		return 0
	end
	local safe, count = 0, 0
	for _, card in ipairs(cards) do
		if has(mask, card) then
			count += 1
			if total + card <= target then
				safe += 1
			end
		end
	end
	if count == 0 then
		return 0
	end
	local share = safe / count
	if share >= 0.999 then
		return 1
	end
	return math.clamp((share - 0.3) / 0.35, 0, 1)
end

---The round played out from here: the chances that I win, draw and lose, with me choosing
---the better move at every turn of mine and the opponent following opponentDraws.
---state: { mine, theirs, mask (deck left), target, cards (all values), utility = {win, lose} }
local function solve(state)
	local cards, target = state.cards, state.target
	local uWin, uLose = state.utility.win, state.utility.lose
	local memo = {}
	local function value(triple)
		return triple[1] * uWin + triple[3] * uLose
	end
	local play
	local function drawFor(mine, theirs, mask, mover)
		local w, d, l, count = 0, 0, 0, 0
		for _, card in ipairs(cards) do
			if has(mask, card) then
				count += 1
				local result
				if mover == 1 then
					result = play(mine + card, theirs, mask - bit(card), 2, false)
				else
					result = play(mine, theirs + card, mask - bit(card), 1, false)
				end
				w += result[1]
				d += result[2]
				l += result[3]
			end
		end
		if count == 0 then
			return nil
		end
		return { w / count, d / count, l / count }
	end
	local function ended(mine, theirs)
		local who = Engine.showdown(mine, theirs, target)
		return { who == 1 and 1 or 0, who == 0 and 1 or 0, who == -1 and 1 or 0 }
	end
	---turn: 1 me, 2 them. passed: did the other player pass just before this turn.
	function play(mine, theirs, mask, turn, passed)
		local key = ((mask * 128 + mine) * 128 + theirs) * 4 + (turn == 1 and 0 or 1) + (passed and 2 or 0)
		local known = memo[key]
		if known then
			return known
		end
		local result
		if turn == 1 then
			local pass = passed and ended(mine, theirs) or play(mine, theirs, mask, 2, true)
			local draw = mine <= target and drawFor(mine, theirs, mask, 1) or nil
			result = (draw and value(draw) > value(pass)) and draw or pass
		else
			local chance = Engine.opponentDraws(theirs, target, mask, cards)
			local pass = passed and ended(mine, theirs) or play(mine, theirs, mask, 1, true)
			local draw = chance > 0 and drawFor(mine, theirs, mask, 2) or nil
			if not draw then
				result = pass
			else
				result = {
					chance * draw[1] + (1 - chance) * pass[1],
					chance * draw[2] + (1 - chance) * pass[2],
					chance * draw[3] + (1 - chance) * pass[3],
				}
			end
		end
		memo[key] = result
		return result
	end
	return play, drawFor, ended, value
end

---Everything the adviser needs to know about the table.
---table = {
---  cards = {1..11}, target = 21,
---  mine = {values, first is my hidden one}, theirs = {visible values}, hidden = number of
---  face-down cards the opponent holds, theirPassed = bool (his last move was a pass),
---  myBet, theirBet, myDistance, theirDistance, tug = bool (SAW: winner also gains) }
function Engine.candidates(t)
	local seen = {}
	for _, card in ipairs(t.mine) do
		seen[card] = true
	end
	for _, card in ipairs(t.theirs) do
		seen[card] = true
	end
	local list = {}
	for _, card in ipairs(t.cards) do
		if not seen[card] then
			table.insert(list, card)
		end
	end
	return list
end

---The cards the opponent's face-down one can still be: not on show, and not ruled out by
---something he did (t.impossible, a set of card values).
function Engine.possible(t)
	local unknown = Engine.candidates(t)
	if not t.impossible then
		return unknown
	end
	local list = {}
	for _, card in ipairs(unknown) do
		if not t.impossible[card] then
			table.insert(list, card)
		end
	end
	return #list > 0 and list or unknown
end

local function sum(list)
	local total = 0
	for _, value in ipairs(list) do
		total += value
	end
	return total
end
Engine.sum = sum

---What a win and a loss are worth: the bets, three times over when one of them ends the game.
function Engine.utility(t)
	local myBet, theirBet = math.max(t.myBet or 1, 0), math.max(t.theirBet or 1, 0)
	local myLeft, theirLeft = t.myDistance or 99, t.theirDistance or 99
	-- What is really taken: no more than is left. Ending the game counts three times over.
	local win, lose = math.max(math.min(theirBet, theirLeft), 0.25), -math.max(math.min(myBet, myLeft), 0.25)
	if not t.blessed then
		if theirLeft - theirBet <= 0 then
			win *= 3
		end
		if myLeft - myBet <= 0 then
			lose *= 3
		end
	end
	return { win = win, lose = lose }
end

---The chances for one of my moves ("pass" or "draw"), averaged over what the hidden card may be.
---Returns { win, draw, lose, value } or nil when the move is not possible.
function Engine.rate(t, move)
	local unknown = Engine.candidates(t)
	local mine, shown = sum(t.mine), sum(t.theirs)
	local utility = Engine.utility(t)
	local hiddenCount = t.hidden or 1
	local total, w, d, l = 0, 0, 0, 0
	local function consider(hiddenSum, mask, weight)
		local play, drawFor, ended, value = solve({ cards = t.cards, target = t.target, utility = utility })
		local theirs = shown + hiddenSum
		local result
		if move == "pass" then
			result = t.theirPassed and ended(mine, theirs) or play(mine, theirs, mask, 2, true)
		else
			if mine > t.target then
				return
			end
			result = drawFor(mine, theirs, mask, 1)
		end
		if result then
			total += weight
			w += result[1] * weight
			d += result[2] * weight
			l += result[3] * weight
		end
	end
	local fullMask = 0
	for _, card in ipairs(unknown) do
		fullMask += bit(card)
	end
	if hiddenCount <= 0 then
		consider(0, fullMask, 1)
	elseif hiddenCount == 1 then
		for _, card in ipairs(Engine.possible(t)) do
			local mask = fullMask - bit(card)
			-- A pass from someone who could draw safely is unlikely, and the other way round.
			local weight = 1
			if t.theirPassed ~= nil then
				local chance = Engine.opponentDraws(shown + card, t.target, mask + (t.mine[1] and bit(t.mine[1]) or 0), t.cards)
				weight = t.theirPassed and (1 - chance) or chance
				weight = 0.08 + 0.92 * weight
			end
			consider(card, mask, weight)
		end
	else
		-- Two face-down cards (a Hush): every pair.
		for i = 1, #unknown do
			for j = i + 1, #unknown do
				consider(unknown[i] + unknown[j], fullMask - bit(unknown[i]) - bit(unknown[j]), 1)
			end
		end
	end
	if total <= 0 then
		return nil
	end
	local result = { win = w / total, draw = d / total, lose = l / total }
	result.value = result.win * utility.win + result.lose * utility.lose
	return result
end

---Draw or pass, with the chances for both.
function Engine.advise(t)
	local pass, draw = Engine.rate(t, "pass"), Engine.rate(t, "draw")
	local best = "pass"
	if draw and (not pass or draw.value > pass.value + 1e-9) then
		best = "draw"
	end
	return { move = best, pass = pass, draw = draw, best = best == "draw" and draw or pass }
end

---The hidden card's candidates with their chances and the total each would give the opponent.
function Engine.hiddenOdds(t)
	local unknown = Engine.candidates(t)
	local shown = sum(t.theirs)
	local fullMask = 0
	for _, card in ipairs(unknown) do
		fullMask += bit(card)
	end
	local list, total = {}, 0
	for _, card in ipairs(Engine.possible(t)) do
		local weight = 1
		if t.theirPassed ~= nil and (t.hidden or 1) == 1 then
			local chance = Engine.opponentDraws(shown + card, t.target, fullMask - bit(card) + (t.mine[1] and bit(t.mine[1]) or 0), t.cards)
			weight = 0.08 + 0.92 * (t.theirPassed and (1 - chance) or chance)
		end
		total += weight
		table.insert(list, { card = card, weight = weight, total = shown + card })
	end
	for _, entry in ipairs(list) do
		entry.chance = total > 0 and entry.weight / total or 0
	end
	return list
end


---A copy of the table with some fields changed.
local function with(t, changes)
	local copy = {}
	for key, value in pairs(t) do
		copy[key] = value
	end
	for key, value in pairs(changes) do
		copy[key] = value
	end
	return copy
end
local function appended(list, value)
	local copy = table.clone(list)
	table.insert(copy, value)
	return copy
end
local function withoutLast(list)
	local copy = table.clone(list)
	table.remove(copy)
	return copy
end

local BET_UP = { ["One-up"] = 1, ["Two-up"] = 2, Bloodshed = 1 }
local BET_DOWN = { Shield = 1, ["Shield+"] = 2 }
local GO_FOR = { ["Go for 17"] = 17, ["Go for 24"] = 24, ["Go for 27"] = 27 }
Engine.BET_UP, Engine.BET_DOWN, Engine.GO_FOR = BET_UP, BET_DOWN, GO_FOR

---What each trump in my hand is worth right now, as the gain over not playing it.
---t also needs: trumps (my hand, names), tableTheirs (their trumps on the table, in order),
---baseTarget (the room's own target), and optionally yield (called between the slow sums).
---Returns a list sorted best first: { name, gain, why }.
function Engine.rateTrumps(t)
	local base = Engine.advise(t)
	local baseValue = base.best.value
	local scale = math.max(1, ((t.myBet or 1) + (t.theirBet or 1)) / 2)
	local unknown = Engine.candidates(t)
	local odds = Engine.hiddenOdds(t)
	local hiddenChance = {}
	for _, entry in ipairs(odds) do
		hiddenChance[entry.card] = (t.hidden or 1) >= 1 and entry.chance or 0
	end
	local mine = sum(t.mine)
	local function value(changed)
		if t.yield then
			t.yield()
		end
		return Engine.advise(changed).best.value
	end
	---The average value over one more card from the deck going to me or to them.
	local function afterCard(side)
		local total, count = 0, 0
		for _, card in ipairs(unknown) do
			local weight = 1 - (hiddenChance[card] or 0)
			if weight > 0 then
				total += weight * value(with(t, { [side] = appended(t[side], card) }))
				count += weight
			end
		end
		return count > 0 and total / count or baseValue
	end
	local seen, rated = {}, {}
	local passing = base.move == "pass"
	for _, name in ipairs(t.trumps or {}) do
		if not seen[name] then
			seen[name] = true
			local gain, why
			local number = tonumber(name:match("^(%d)%-Card$"))
			if number then
				local inDeck = table.find(unknown, number) and (1 - (hiddenChance[number] or 0)) or 0
				if inDeck > 0 and mine + number <= t.target then
					gain = inDeck * (value(with(t, { mine = appended(t.mine, number) })) - baseValue) - 0.2 * scale
					why = ("takes the %d for %d"):format(number, mine + number)
				end
			elseif name == "Perfect Draw" then
				-- The best card still in the deck: the biggest that fits.
				local total, weightSum, pick = 0, 0, nil
				for _, entry in ipairs(#odds > 0 and odds or { { card = 0, chance = 1 } }) do
					local best
					for _, card in ipairs(unknown) do
						if card ~= entry.card and mine + card <= t.target and (not best or card > best) then
							best = card
						end
					end
					local chance = (t.hidden or 1) >= 1 and entry.chance or 1 / math.max(1, #odds)
					if best then
						total += chance * value(with(t, { mine = appended(t.mine, best) }))
						pick = math.max(pick or 0, best)
					else
						total += chance * baseValue
					end
					weightSum += chance
				end
				if pick and weightSum > 0 then
					gain = total / weightSum - baseValue - 0.25 * scale
					why = ("best card left, most likely the %d for %d"):format(pick, mine + pick)
				end
			elseif name == "Return" then
				if #t.mine >= 2 then
					gain = value(with(t, { mine = withoutLast(t.mine) })) - baseValue - 0.2 * scale
					why = ("puts my %d back"):format(t.mine[#t.mine])
				end
			elseif name == "Remove" then
				if #t.theirs >= 1 then
					gain = value(with(t, { theirs = withoutLast(t.theirs) })) - baseValue - 0.2 * scale
					why = ("takes their %d away"):format(t.theirs[#t.theirs])
				end
			elseif name == "Exchange" then
				if #t.mine >= 2 and #t.theirs >= 1 then
					local a, b = t.mine[#t.mine], t.theirs[#t.theirs]
					gain = value(with(t, { mine = appended(withoutLast(t.mine), b), theirs = appended(withoutLast(t.theirs), a) })) - baseValue - 0.2 * scale
					why = ("swaps my %d for their %d"):format(a, b)
				end
			elseif GO_FOR[name] then
				if GO_FOR[name] ~= t.target then
					gain = value(with(t, { target = GO_FOR[name] })) - baseValue - 0.2 * scale
					why = ("changes the target to %d"):format(GO_FOR[name])
				end
			elseif name == "Destroy" or name == "Reincarnation" then
				local list = t.tableTheirs or {}
				local last = list[#list]
				if last then
					local changed
					if BET_UP[last] then
						changed = with(t, { myBet = math.max(0, (t.myBet or 1) - BET_UP[last]) })
					elseif BET_DOWN[last] then
						changed = with(t, { theirBet = (t.theirBet or 1) + BET_DOWN[last] })
					elseif GO_FOR[last] then
						changed = with(t, { target = t.baseTarget or 21 })
					elseif last == "Bless" then
						changed = with(t, { blessed = false })
					end
					if changed then
						gain = value(changed) - baseValue - (name == "Destroy" and 0.2 or 0.05) * scale
						why = ("removes their %s"):format(last)
					end
				end
			elseif BET_DOWN[name] then
				-- Only once my hand is final: the bet matters at the showdown.
				if passing and (t.myBet or 1) > 0 then
					local cut = math.min(BET_DOWN[name], t.myBet or 1)
					gain = value(with(t, { myBet = (t.myBet or 1) - cut })) - baseValue - 0.45 * cut
					why = ("I lose this %d%% of the time; my bet drops by %d"):format(base.best.lose * 100 + 0.5, cut)
				end
			elseif BET_UP[name] then
				if passing then
					gain = value(with(t, { theirBet = (t.theirBet or 1) + BET_UP[name] })) - baseValue - 0.6 * BET_UP[name] + (name == "Bloodshed" and 0.1 or 0)
					why = ("I win this %d%% of the time; their bet goes up by %d"):format(base.best.win * 100 + 0.5, BET_UP[name])
				end
			elseif name == "Bless" then
				if passing and not t.blessed and (t.myDistance or 99) - (t.myBet or 1) <= 0 then
					gain = value(with(t, { blessed = true })) - baseValue - 0.5 * scale
					why = "a loss here would end the game for me"
				end
			elseif name == "Hush" then
				if base.move == "draw" then
					gain = afterCard("mine") - baseValue - 0.02
					why = "a draw they cannot see"
				end
			elseif name == "Disservice" then
				gain = afterCard("theirs") - baseValue - 0.25 * scale
				why = "makes them draw a card"
			elseif name == "Refresh" then
				if base.best.win < 0.3 and #t.mine >= 2 then
					-- Two new cards: a sample of the pairs is enough.
					local total, count = 0, 0
					for i = 1, #unknown do
						for j = i + 1, #unknown do
							if (i + j) % 3 == 0 then
								total += value(with(t, { mine = { unknown[i], unknown[j] } }))
								count += 1
							end
						end
					end
					if count > 0 then
						gain = total / count - baseValue - 0.3 * scale
						why = "my hand is poor; two new cards"
					end
				end
			elseif name == "Friendship" then
				if #(t.trumps or {}) <= 2 then
					gain = 0.01
					why = "two more trump cards each"
				end
			end
			if gain then
				table.insert(rated, { name = name, gain = gain, why = why })
			end
		end
	end
	table.sort(rated, function(a, b)
		return a.gain > b.gain
	end)
	return rated, base
end

return Engine
