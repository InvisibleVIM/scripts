# Builds core.lua from the feature tables below. TOGGLES: key, label, page, default.
TOGGLES = [
 ("UFly","Fly","Movement",False),("UFlyVehicle","Vehicle fly","Movement",False),("NoClip","No clip","Movement",False),("ClickTeleport","Click teleport","Movement",False),
 ("USpeedOn","Walk speed","Movement",False),("UJumpOn","Jump power","Movement",False),("UInfJump","Infinite jump","Movement",False),("UBhop","Bunny hop","Movement",False),
 ("UAirWalk","Air walk","Movement",False),("UFloat","Float","Movement",False),("UGravityOn","Gravity","Movement",False),("USpin","Spin","Movement",False),
 ("UFollow","Follow player","Players",False),("UJoinNotes","Join and leave notices","Players",False),
 ("UEsp","Player ESP","ESP",False),("UEspChams","ESP outlines","ESP",True),("UEspNames","ESP names","ESP",True),("UEspDistance","ESP distance","ESP",True),("UEspHealth","ESP health bars","ESP",True),("UEspTracers","ESP tracers","ESP",False),("UEspTeam","ESP team colours","ESP",True),("UEspTeamCheck","ESP hides teammates","ESP",False),
 ("UEspNpc","NPC ESP","ESP",False),("UEspTool","Tool ESP","ESP",False),("UEspPrompt","Prompt ESP","ESP",False),("UEspClick","Click detector ESP","ESP",False),
 ("UFullbright","Fullbright","ESP",False),("UNoFog","Remove fog","ESP",False),("UCrosshair","Crosshair","ESP",False),
 ("UFovOn","Field of view","Camera",False),("UZoomOn","Max zoom","Camera",False),("UThirdPerson","Allow third person","Camera",False),("UFirstPerson","First person","Camera",False),("UFreecam","Free camera","Camera",False),("USensOn","Mouse sensitivity","Camera",False),
 ("UHideSelf","Hide my character","Character",False),("UNoAccessories","Hide my accessories","Character",False),("UNoAnim","Stop my animations","Character",False),("UAnimSpeedOn","Animation speed","Character",False),
 ("UXray","X-ray","World",False),("UNoParticles","No particles","World",False),("UNoTextures","No textures","World",False),("UNoShadows","No shadows","World",False),("UNoEffects","No screen effects","World",False),("UClickDelete","Click delete","World",False),
 ("UFps","Show FPS","Server",False),("UPing","Show ping","Server",False),("UFpsCapOn","FPS cap","Server",False),("UHideGui","Hide the game's GUI","Server",False),("UAntiAfk","Anti-AFK","Server",True),("UOffOnDeath","Movement off on death","Server",False),
]
VALUES = {
 "UFlySpeed":1,"UFlyKeyHold":False,"ClickTeleportKey":"LeftControl","USpeed":50,"UJump":100,"UGravity":60,"USpinSpeed":10,
 "UEspRange":2000,"UCrosshairSize":8,"UFov":90,"UZoom":2000,"UFreecamSpeed":60,"USens":1,"USelfAlpha":1,"UAnimSpeed":1,
 "UDeleteKey":"LeftAlt","UFpsCap":240,"UWaypoints":"{}","UPanicKey":"End","MenuSet":"Game",
}
DEFAULT_BINDS = {"UFly":"F","UFreecam":"P"}
SESSION_OFF = ["UFly","UFreecam","UFollow","UAirWalk","UFloat","USpin","UClickDelete","UHideGui"]
def lua(v):
    if isinstance(v,bool): return "true" if v else "false"
    if isinstance(v,(int,float)): return repr(v)
    return '"'+str(v)+'"'
def defaults_lines(indent="\t"):
    out=[]
    row=[]
    for k,_,_,d in TOGGLES:
        row.append(f"{k} = {lua(d)}")
        row.append(f'K_{k} = {lua(DEFAULT_BINDS.get(k,"None"))}')
    for k,v in VALUES.items(): row.append(f"{k} = {lua(v)}")
    for i in range(0,len(row),6): out.append(indent+", ".join(row[i:i+6])+",")
    return "\n".join(out)
def toggles_lua():
    return "{\n"+"\n".join(f'\t{{ key = "{k}", name = "{n}", page = "{p}" }},' for k,n,p,_ in TOGGLES)+"\n}"
if __name__=="__main__":
    t=open('/home/claude/universal/core.tmpl.lua').read()
    t=t.replace("--@DEFAULTS@",defaults_lines("\t")).replace("--@TOGGLES@",toggles_lua()).replace("--@SESSION_OFF@",", ".join('"'+k+'"' for k in SESSION_OFF))
    open('/home/claude/universal/core.lua','w').write(t)
    print("core.lua", len(t.splitlines()), "lines")
