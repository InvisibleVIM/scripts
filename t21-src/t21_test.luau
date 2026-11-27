local Engine = require("./t21_engine")
local cards = {1,2,3,4,5,6,7,8,9,10,11}
local function show(name, t)
	local a = Engine.advise(t)
	local function f(r) if not r then return "n/a" end return string.format("win %.0f%% draw %.0f%% lose %.0f%% (value %.2f)", r.win*100, r.draw*100, r.lose*100, r.value) end
	print(name, "->", a.move:upper(), "| pass:", f(a.pass), "| draw:", f(a.draw))
end
local t0 = os.clock()
-- the round from the log: me 3(h)+5, opp ? + 2, opp to move first... my turn with 8
show("me 8 vs ?+2", { cards = cards, target = 21, mine = {3,5}, theirs = {2}, hidden = 1, myBet = 1, theirBet = 1, myDistance = 7, theirDistance = 7 })
show("me 19 vs ?+11 (opp drew)", { cards = cards, target = 21, mine = {3,5,11}, theirs = {2,1,8}, hidden = 1, theirPassed = false, myBet = 1, theirBet = 1, myDistance = 7, theirDistance = 7 })
show("me 19 vs ?+11 (opp passed)", { cards = cards, target = 21, mine = {3,5,11}, theirs = {2,1,8}, hidden = 1, theirPassed = true, myBet = 1, theirBet = 1, myDistance = 7, theirDistance = 7 })
show("me 14 vs ?+10", { cards = cards, target = 21, mine = {4,10}, theirs = {9}, hidden = 1, myBet = 1, theirBet = 1, myDistance = 7, theirDistance = 7 })
show("me 16 vs ?+6 passed", { cards = cards, target = 21, mine = {10,6}, theirs = {7}, hidden = 1, theirPassed = true, myBet = 1, theirBet = 1, myDistance = 7, theirDistance = 7 })
show("me 25 target 27 vs ?+18", { cards = cards, target = 27, mine = {5,7,1,8,4}, theirs = {6,10,2}, hidden = 1, theirPassed = true, myBet = 2, theirBet = 2, myDistance = 3, theirDistance = 5 })
show("lethal: me 15 vs ?+9, my distance 1", { cards = cards, target = 21, mine = {7,8}, theirs = {9}, hidden = 1, myBet = 1, theirBet = 1, myDistance = 1, theirDistance = 7 })
for _, e in ipairs(Engine.hiddenOdds({ cards = cards, target = 27, mine = {5,7,1,8,4}, theirs = {6,10,2}, hidden = 1, theirPassed = true })) do print("hidden", e.card, string.format("%.0f%%", e.chance*100), "total", e.total) end
print(string.format("%.3fs", os.clock() - t0))
local function trumps(name, t)
	local t1 = os.clock()
	local rated, base = Engine.rateTrumps(t)
	print(name, "base", base.move, string.format("%.2f", base.best.value))
	for _, r in ipairs(rated) do print("   ", r.name, string.format("%+.2f", r.gain), r.why) end
	print(string.format("    %.3fs", os.clock() - t1))
end
local all = {"One-up","Two-up","Shield","Shield+","Remove","Return","Exchange","Destroy","2-Card","3-Card","4-Card","5-Card","6-Card","7-Card","Perfect Draw","Go for 17","Go for 24","Go for 27","Hush","Bless","Reincarnation","Friendship","Bloodshed","Disservice","Refresh"}
trumps("bust 24 vs ?+17 passed", { cards = cards, target = 21, baseTarget = 21, mine = {7,3,4,10}, theirs = {9,8}, hidden = 1, theirPassed = true, myBet = 3, theirBet = 3, myDistance = 4, theirDistance = 7, trumps = all, tableTheirs = {"One-up"} })
trumps("me 14 vs ?+9", { cards = cards, target = 21, baseTarget = 21, mine = {4,10}, theirs = {9}, hidden = 1, myBet = 1, theirBet = 1, myDistance = 7, theirDistance = 7, trumps = all, tableTheirs = {} })
trumps("me 20 vs ?+12 passed", { cards = cards, target = 21, baseTarget = 21, mine = {9,11}, theirs = {3,4,5}, hidden = 1, theirPassed = true, myBet = 3, theirBet = 3, myDistance = 7, theirDistance = 1, trumps = all, tableTheirs = {} })
