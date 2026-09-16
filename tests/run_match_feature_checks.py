from pathlib import Path
import subprocess
root=Path.cwd()
def read(p):return (root/p).read_text(encoding='utf-8')
def section(s,a,b):return s[s.index(a):s.index(b)]
hud=read('src/StarterPlayer/StarterPlayerScripts/Hud.client.luau')
blind=read('src/StarterPlayer/StarterPlayerScripts/BlindOneController.client.luau')
game=read('src/ServerScriptService/GameService.server.luau')
setup='''local count=0
local function check(v,msg) assert(v,msg);count+=1;print('PASS',msg) end
local clock=100
local os={clock=function() return clock end}
local takeoverAt=nil
local workspace={GetAttribute=function() return takeoverAt end,GetServerTimeNow=function() return clock end}
local noticeUntil=0
'''
code=setup+section(hud,'local function updateTakeoverNotice()', 'workspace:GetAttributeChangedSignal("BlindOneBotTakeoverAt")')+'''
takeoverAt=97;updateTakeoverNotice();check(noticeUntil==103,'late UI keeps remaining notice duration')
takeoverAt=80;updateTakeoverNotice();check(noticeUntil==100,'old takeover does not replay')
takeoverAt=100;updateTakeoverNotice();check(noticeUntil==106,'new takeover notice lasts six seconds')
local map={}
local hit=nil
local Workspace={FindFirstChild=function() return map end,Raycast=function() return hit end}
local generatorVisitRay={}
'''+section(blind,'local function canVisitGenerator(', 'local function generatorMarker(')+'''
local station={}
local root={Position=0};local base={Position=5}
check(canVisitGenerator(station,root,base),'unobstructed visit clears marker')
hit={Instance={IsDescendantOf=function() return false end}}
check(not canVisitGenerator(station,root,base),'wall prevents marker dismissal')
hit={Instance={IsDescendantOf=function(_,s) return s==station end}}
check(canVisitGenerator(station,root,base),'generator casing counts as arrival')
local roster={}
local Players={GetPlayers=function() return roster end}
local sawSurvivor=false
local survivorEscaped=false
local respawnRequests={}
local function canReturn()
'''+section(game,'\t\tlocal survivorsCanReturn = false','\t\tif sawSurvivor and not survivorsCanReturn')+'''
return survivorsCanReturn
end
local attrs={InMatch=true,Role='Survivor',RespawnsRemaining=0}
local hum={Health=100}
local p={GetAttribute=function(_,k) return attrs[k] end,Character={FindFirstChildOfClass=function() return hum end}}
roster={p}
check(canReturn(),'living final-life survivor prevents victory')
hum.Health=0;attrs.RespawnsRemaining=1
check(canReturn(),'dead survivor with respawn prevents victory')
attrs.RespawnsRemaining=0
check(not canReturn(),'exhausted dead survivor permits victory')
respawnRequests[p]=true
check(canReturn(),'in-flight last respawn prevents victory')
respawnRequests[p]=nil;roster={}
check(not canReturn() and sawSurvivor,'all survivors left permits victory')
roster={p};attrs.Escaped=true
check(canReturn() and survivorEscaped,'escape prevents hunter victory')
print('TOTAL',count,'match feature checks passed')
'''
out=root/'.tools/luau/match-feature-check.luau';out.write_text(code,encoding='utf-8')
subprocess.run([str(root/'.tools/luau/luau.exe'),str(out)],check=True)
