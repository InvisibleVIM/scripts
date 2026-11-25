# Assembles Universal.lua from the Bey Rivals file's menu kit + core.lua.
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
header=open('/home/claude/universal/standalone_header.lua').read()
tail=open('/home/claude/universal/standalone_tail.lua').read()
consts='\nlocal SETTINGS_FOLDER = "Universal"\nlocal SETTINGS_FILE = SETTINGS_FOLDER .. "/settings.json"\n'
merge='\nfor key, value in pairs(PotentUniversal.DEFAULTS) do\n\tConfig[key] = value\nend\nConfig.AntiAfk = false\n'
settings=L(enc,load_end)+'\nif Config.UiLook ~= "dusk" then\n\tConfig.UiLook, Config.WindowX, Config.WindowY = "dusk", -1, -1\nend\nlocal status = "Universal"\n'
out='\n'.join([header,L(svc,svc+8),consts,L(pal,pal+13),L(cfg_a,cfg_b),core,merge,settings,L(kit_a,kit_b),L(alias,alias),"do",L(menu_a,menu_b),"end",tail])
out=out.replace('BeyRivalsUI','PotentUniversalUI')
def rep(a,b):
    global out
    assert out.count(a)==1,(a[:60],out.count(a))
    out=out.replace(a,b)
rep('Text = "Bey Rivals", FontFace = CODE_BOLD','Text = "Potent Universal", FontFace = CODE_BOLD')
rep('for _, group in ipairs({ "Play", "Account", "Menu" }) do','for _, group in ipairs({ "Universal", "Menu" }) do')
# USER: "universal should always start hidden and have no notifications".
rep('		panel.Visible = not Config.HideOnExecute','		-- Always starts closed, with no notice: the menu key opens it.\n		panel.Visible = false')
rep('''		if Config.HideOnExecute then
			UI.toast("Bey Rivals is running", (SHORT_KEYS[Config.MenuKey] or tostring(Config.MenuKey)) .. " opens the menu.", 6)
		end
''','')
rep('	toggle(page, "Start hidden", "HideOnExecute", "The menu stays closed when the script loads.")\n','')
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
open('/home/claude/universal/Universal.lua','w').write(out)
print(len(out.split('\n')),'lines')
