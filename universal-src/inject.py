import sys
sys.path.insert(0,'/home/claude/universal')
import gen
core=open('/home/claude/universal/core.lua').read()
SWITCH = '''		-- The page list holds two sets: this game's pages and the Universal ones. The button at
		-- the top of the list swaps which set is listed and is named after the set it takes you to.
		local order = 0
		local sets = { Game = { rows = {}, first = nil }, Universal = { rows = {}, first = nil } }
		for _, group in ipairs({ @GROUPS@, "Universal" }) do
			local set = sets[group == "Universal" and "Universal" or "Game"]
			local opened = false
			for _, name in ipairs(UI.order) do
				if UI.groups[name] == group then
					if not opened then
						opened = true
						order += 1
						table.insert(set.rows, UI.makeGroup(group == "Universal" and "Universal tools" or group, order))
					end
					order += 1
					table.insert(set.rows, UI.makeTab(name, order))
					set.first = set.first or name
				end
			end
		end
		UI.sets = sets
		local switch = create("TextButton", {
			Name = "SetSwitch",
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = UI.roles.Control,
			BorderSizePixel = 0,
			FontFace = CODE_BOLD,
			Text = "",
			TextSize = px(14),
			TextColor3 = UI.roles.Font,
			AutoButtonColor = false,
			LayoutOrder = -1,
			Parent = tabBar,
		})
		round(switch, 7)
		function UI.showSet(which, select)
			if not sets[which] or #sets[which].rows == 0 then
				which = "Game"
			end
			Config.MenuSet = which
			for name, set in pairs(sets) do
				for _, row in ipairs(set.rows) do
					row.Visible = name == which
				end
			end
			switch.Text = which == "Game" and "Universal" or "@TITLE@"
			switch.Visible = #sets.Universal.rows > 0
			if select and sets[which].first then
				UI.selectTab((which == "Game" and pages[firstTab]) and firstTab or sets[which].first)
			end
		end
		switch.MouseButton1Click:Connect(function()
			UI.showSet(Config.MenuSet == "Universal" and "Game" or "Universal", true)
		end)'''
def aa():
    p='/home/claude/scripts/Anime Adventures'
    s=open(p).read()
    a=s.index("AA.Universal = (function()\n"); b=s.index("\treturn PotentUniversal\nend)()\n",a)
    s=s[:a]+"AA.Universal = (function()\n"+core+s[b:]
    a=s.index("	-- Universal tools (v275): the Universal pages of the menu, the same in every game.\n")
    b=s.index("\n	HideOnExecute = ",a)+1
    skip={"NoClip","ClickTeleport","ClickTeleportKey"}; row=[]
    for k,_,_,d in gen.TOGGLES:
        if k not in skip: row.append(f"{k} = {gen.lua(d)}")
        row.append(f'K_{k} = {gen.lua(gen.DEFAULT_BINDS.get(k,"None"))}')
        row.append(f'P_{k} = false')
    for k,v in gen.VALUES.items():
        if k not in skip: row.append(f"{k} = {gen.lua(v)}")
    lines=["\t"+", ".join(row[i:i+6])+"," for i in range(0,len(row),6)]
    s=s[:a]+"	-- Universal tools (v275): the Universal pages of the menu, the same in every game.\n"+"\n".join(lines)+"\n"+s[b:]
    open(p,'w').write(s)
def bey():
    p='/home/claude/scripts/BeyRivals'
    s=open('/home/claude/universal/BeyRivals.kitbase').read()
    def rep(a,b):
        nonlocal s
        assert s.count(a)==1,(a[:60],s.count(a))
        s=s.replace(a,b)
    rep('local function encodeSettings()','-- Universal tools: the Universal set of the menu (see universal-src in the repo).\n'+core+'''for key, value in pairs(PotentUniversal.DEFAULTS) do
	if Config[key] == nil then
		Config[key] = value
	end
end
BeyRivals.Universal = PotentUniversal

local function encodeSettings()''')
    rep('UI.finish("Battle")','''do
	local okUniversal, made = pcall(PotentUniversal.install, {
		UI = UI, Config = Config, connections = BeyRivals.connections, gui = BeyRivals.gui, ownsAfk = true,
		alive = function()
			return not BeyRivals.detached
		end,
	})
	if okUniversal then
		BeyRivals.universal = made
	else
		warn("[Bey Rivals] Universal tools: " .. tostring(made))
	end
end
UI.finish("Battle")''')
    a=s.index('		local order = 0\n		for _, group in ipairs({ "Play", "Account", "Menu" }) do')
    b=s.index('		screenGui.Parent = guiParent',a)
    s=s[:a]+SWITCH.replace('@GROUPS@','"Play", "Account", "Menu"').replace('@TITLE@','Bey Rivals')+'\n'+s[b:]
    rep('''		UI.selectTab(pages[firstTab] and firstTab or UI.order[1])
''','''		UI.selectTab(pages[firstTab] and firstTab or UI.order[1])
		UI.showSet(Config.MenuSet == "Universal" and "Universal" or "Game", Config.MenuSet == "Universal")
''')
    rep('	local SHORT_KEYS = { RightControl','	local SHORT_KEYS = { None = "Not set", RightControl')
    rep('''				if input.KeyCode ~= Enum.KeyCode.Escape then
					Config[key] = input.KeyCode.Name
				end''','''				if input.KeyCode == Enum.KeyCode.Backspace and key ~= "MenuKey" then
					Config[key] = "None"
				elseif input.KeyCode ~= Enum.KeyCode.Escape then
					Config[key] = input.KeyCode.Name
				end''')
    rep('''function BeyRivals.detach()
	BeyRivals.detached = true
	saveSettings()''','''function BeyRivals.detach()
	saveSettings()
	if BeyRivals.universal then
		pcall(BeyRivals.universal.stop)
	end
	BeyRivals.detached = true''')
    rep('VERSION = "dusk-2"','VERSION = "dusk-3"')
    open(p,'w').write(s)
if __name__=="__main__":
    aa(); bey(); print("injected")
