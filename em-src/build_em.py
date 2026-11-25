# Assembles EpicMinigames from the Bey Rivals menu kit + the Universal core + the game layer here.
import sys
sys.path.insert(0,'/home/claude/universal')
import importlib.util
spec=importlib.util.spec_from_file_location('inject','/home/claude/universal/inject.py'); inj=importlib.util.module_from_spec(spec); spec.loader.exec_module(inj)
B='/home/claude/em/build/'
bey=open('/home/claude/universal/BeyRivals.kitbase').read().split('\n')
def L(a,b): return '\n'.join(bey[a-1:b])
core=open('/home/claude/universal/core.lua').read()
def find(pat, start=0):
    for i in range(start,len(bey)):
        if bey[i].startswith(pat): return i+1
    raise Exception(pat)
cfg_a=find('local Config = {'); cfg_b=cfg_a
while bey[cfg_b-1]!='}': cfg_b+=1
enc=find('local function encodeSettings()'); load_end=find('loadSettings()')
kit_a=find('local UI = { order'); kit_b=find('end)()',kit_a)
alias=find('local create, statusLabel, panel',kit_b)
menu_a=find('	UI.musicSection(makePage("Music"')-1; menu_b=find('UI.finish("Battle")')-1
svc=find('local playersService = game:GetService("Players")'); pal=find('local STEEL = ')
header=open(B+'em_header.lua').read(); tail=open(B+'em_tail.lua').read()
game=open(B+'em_game.lua').read(); pages=open(B+'em_pages.lua').read()
consts='\nlocal SETTINGS_FOLDER = "EpicMinigames"\nlocal SETTINGS_FILE = SETTINGS_FOLDER .. "/settings.json"\n'
merge='''
for key, value in pairs(PotentUniversal.DEFAULTS) do
	Config[key] = value
end
-- Epic Minigames settings.
for key, value in pairs({ EmAuto = true, EmRace = true, EmSurvive = true, EmSpecial = true, EmJoin = true, EmRecord = true, EmDaily = true, EmPlaytime = true }) do
	Config[key] = value
end
Config.AntiAfk = false
'''
settings=L(enc,load_end)+'\nif Config.UiLook ~= "dusk" then\n\tConfig.UiLook, Config.WindowX, Config.WindowY = "dusk", -1, -1\nend\nlocal status = "Epic Minigames"\n'
out='\n'.join([header,L(svc,svc+8),consts,L(pal,pal+13),L(cfg_a,cfg_b),core,merge,settings,L(kit_a,kit_b),L(alias,alias),game,pages,"do",L(menu_a,menu_b),"end",tail])
out=out.replace('BeyRivalsUI','EpicMinigamesUI')
def rep(a,b):
    global out
    assert out.count(a)==1,(a[:60],out.count(a))
    out=out.replace(a,b)
rep('Text = "Bey Rivals", FontFace = CODE_BOLD','Text = "Epic Minigames", FontFace = CODE_BOLD')
a=out.index('		local order = 0\n		for _, group in ipairs({ "Play", "Account", "Menu" }) do')
b=out.index('		screenGui.Parent = guiParent',a)
out=out[:a]+inj.SWITCH.replace('@GROUPS@','"Play", "Menu"').replace('@TITLE@','Epic Minigames')+'\n'+out[b:]
rep('''		UI.selectTab(pages[firstTab] and firstTab or UI.order[1])
''','''		UI.selectTab(pages[firstTab] and firstTab or UI.order[1])
		UI.showSet(Config.MenuSet == "Universal" and "Universal" or "Game", Config.MenuSet == "Universal")
''')
rep('UI.toast("Bey Rivals is running"','UI.toast("Epic Minigames is running"')
rep('	local SHORT_KEYS = { RightControl','	local SHORT_KEYS = { None = "Not set", RightControl')
rep('''				if input.KeyCode ~= Enum.KeyCode.Escape then
					Config[key] = input.KeyCode.Name
				end''','''				if input.KeyCode == Enum.KeyCode.Backspace and key ~= "MenuKey" then
					Config[key] = "None"
				elseif input.KeyCode ~= Enum.KeyCode.Escape then
					Config[key] = input.KeyCode.Name
				end''')
t='	toggle(page, "Anti-AFK", "AntiAfk", "Answers Roblox\'s 20 minute idle check.")\n'
a=out.index(t); out=out[:a]+out[a+len(t):]
a=out.index('	table.insert(BeyRivals.connections, localPlayer.Idled:Connect(function()\n		if Config.AntiAfk then')
b=out.index('	end))\n',a)+len('	end))\n'); out=out[:a]+out[b:]
open('/home/claude/scripts/EpicMinigames','w').write(out)
print(len(out.split('\n')),'lines')
