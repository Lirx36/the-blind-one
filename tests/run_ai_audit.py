"""Run actual AI functions/modules under Luau with small engine doubles; no Play."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
def source(path): return (root / path).read_text(encoding="utf-8-sig")
monster = source("src/ServerScriptService/MonsterService.server.luau")
rocks = source("src/ServerScriptService/ThrowableService.server.luau")
def section(text, start, end): return text[text.index(start):text.index(end)]
modules = ""
for name, file in [("Config","Config"),("Hearing","MonsterHearing"),("Patrol","MonsterPatrol"),("Detour","MonsterDetour")]:
    modules += "local " + name + " = (function()\n" + source("src/ReplicatedStorage/"+file+".luau") + "\nend)()\n"
preamble = r"""
local Vector3 = {}
local mt = {}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},mt) end
Vector3.zero=Vector3.new(0,0,0)
mt.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
mt.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
mt.__mul=function(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
mt.__index=function(v,k)
 if k=='Magnitude' then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 if k=='Unit' then return v*(1/v.Magnitude) end
end
local builtinTypeof=typeof
local function typeof(v) return if getmetatable(v)==mt then 'Vector3' else builtinTypeof(v) end
local count=0
local function check(ok,message) assert(ok,message);count+=1;print('PASS',message) end
local now=100
local os={clock=function() return now end}
local roster={}
local Players={GetPlayers=function() return roster end}
local root={Position=Vector3.zero}
local monster={Parent=true,SetAttribute=function() end}
local state,wanderGoal,lastHuntHeard,targetSpeed='wander',nil,0,0
local heard,selectedAt=nil,0
local function nearestNode() return Vector3.new(30,0,30) end
local function player(id,noise,x,active,role)
 local attrs={Noise=noise,InMatch=active,Role=role or 'Survivor'}
 local part={Position=Vector3.new(x,0,0),IsA=function() return true end}
 local hum={Health=100}
 return {UserId=id,Parent=Players,attrs=attrs,part=part,hum=hum,
  GetAttribute=function(self,key) return self.attrs[key] end,
  Character={FindFirstChild=function() return part end,FindFirstChildOfClass=function() return hum end}}
end
"""
functions = section(monster,'local function humanBlindOne()', '-- Rojo can restart')
functions += section(monster,'local function registerNoise(', 'noiseBindable.Event:Connect')
functions += '\nlocal generatorAlert\nlocal noiseBindable={Event={Connect=function(_, fn) generatorAlert=fn end}}\n'
functions += section(monster,'noiseBindable.Event:Connect', '------------------------------------------------------------------- main AI loop')
functions += section(monster,'local function eligible(', '------------------------------------------------------------------- locomotion')
cases=r"""
check(Config.MonsterHuntSpeed==17.5,'bot hunt speed 17.5')
local loading=player(1,100,1,false)
local survivor=player(2,24,20,true)
roster={loading,survivor}
check(humanBlindOne()==nil,'loading survivor does not suppress bot')
local human=player(3,0,20,true,'BlindOne');table.insert(roster,human)
check(humanBlindOne()==human,'actual active human monster replaces bot')
check(not eligible(loading) and eligible(survivor) and not eligible(human),'target eligibility')
survivor.attrs.Escaped=true;check(not eligible(survivor),'escaped survivor excluded');survivor.attrs.Escaped=false
check(Hearing.Strength(3,0,Config)==nil,'crouch below hearing threshold')
check(Hearing.Strength(24,80,Config)~=nil and Hearing.Strength(24,81,Config)==nil,'walking range boundary')
check(Hearing.Strength(95,300,Config)~=nil and Hearing.Strength(95,301,Config)==nil,'rock capped at 300 studs')
local a=player(10,100,30,true);local b=player(11,100,32,true)
roster={a,b,loading};pollPlayers();check(heard.player==a,'nearest equally loud survivor chosen')
now+=0.2;b.part.Position=Vector3.new(29,0,0);pollPlayers()
check(heard.player==a,'small score changes do not cause target oscillation')
a.attrs.Noise=0;b.part.Position=Vector3.new(300,0,0)
now+=16;pollPlayers();check(heard.player==b,'stronger remaining noise can replace fading target')
heard=nil;now+=10;registerNoise(Vector3.new(30,0,0),100,a);decide()
check(state=='hunt' and targetSpeed==17.5,'nearby loud survivor starts hunt')
registerNoise(Vector3.new(40,0,0),95,nil)
check(heard.player==a,'rock does not override stronger active pursuit automatically')
now+=10;registerNoise(Vector3.new(40,0,0),95,nil);decide()
check(heard.player==nil and state=='investigate' and targetSpeed==14,'rock diverts fading pursuit to investigation')
now+=20;decide();check(heard~=nil,'travel time does not consume six second search')
root.Position=Vector3.new(40,0,0);decide();now+=6.1;decide()
check(heard==nil and state=='wander','six seconds at sound then resume patrol')
-- Execute the actual generator event callback, not just registerNoise.
root.Position=Vector3.zero;heard=nil;roster={};now+=10
local generatorPos=Vector3.new(400,0,0)
generatorAlert(generatorPos,100,nil,"GeneratorAlert")
check(heard and heard.generator and heard.pos==generatorPos,'generator alert heard beyond normal hearing range')
decide();check(state=='investigate','generator alert starts investigation')
now+=30;decide();check(heard~=nil and not heard.arrivedAt,'distant generator allows travel time')
root.Position=Vector3.new(394,0,0)
local inspectionGoal=decide()
check(heard.arrivedAt~=nil and inspectionGoal==root.Position and targetSpeed==0,'generator inspection stops beside machine')
now+=2.6;decide();check(heard==nil and state=='wander','generator inspection ends in patrol')
root.Position=Vector3.zero;now+=10
registerNoise(a.part.Position,100,a)
generatorAlert(generatorPos,100,nil,"GeneratorAlert")
check(heard.player==a,'fresh survivor pursuit takes priority over generator')
now+=Config.MonsterHuntGrace+0.1
generatorAlert(generatorPos,100,nil,"GeneratorAlert")
check(heard.generator==true,'stale survivor memory does not discard generator alert')
registerNoise(Vector3.new(10,0,0),24,b)
check(heard.player==b and not heard.generator,'audible survivor immediately interrupts generator investigation')
heard=nil;generatorAlert(generatorPos,100,nil,"GeneratorAlert")
now+=91;decide();check(heard==nil and state=='wander','unreachable generator eventually resumes patrol')
local nodes={};for x=0,2 do for z=0,2 do table.insert(nodes,Vector3.new(x*100,0,z*100)) end end
local planner=Patrol.New(nodes);local pos=nodes[1];local visited={[pos]=true}
for i=1,8 do pos=planner.Select(pos,{},i);visited[pos]=true end
local regions=0;for _ in visited do regions+=1 end
check(regions==9,'quiet patrol visits all nine regions')
local function clear(a,b)
 for i=0,100 do local p=a+(b-a)*(i/100)
  if p.X>=5 and p.X<=10 and math.abs(p.Z)<5 then return false end
 end
 return true
end
local from=Vector3.zero;local goal=Vector3.new(18,0,0)
local route=Detour.Find(from,{goal},clear)
check(route~=nil,'detour found around furniture')
local previous=from
for _,p in route do check(clear(previous,p),'detour segment avoids collider');previous=p end
check((previous-goal).Magnitude<0.01,'detour reaches intended route point')
check(Detour.Find(from,{goal},function() return false end)==nil,'sealed route terminates without false path')
"""
fallback_setup=r"""
local waypoints,wpIndex,directFallbackGoal,blockedTargets,routeDirty={},1,nil,nil,false
local workspace={FindFirstChild=function() return {GetAttribute=function() return 'Maze' end} end}
local PathWaypoint={new=function(pos) return {Position=pos} end}
local Enum={PathWaypointAction={Walk='Walk'}}
local MazeLayout={Route=function() return {Vector3.zero,Vector3.new(10,0,0),Vector3.new(20,0,0),Vector3.new(30,0,0)} end}
local function passageClear(a,b) return b.X<20 end
root.Position=Vector3.zero
"""
fallback_functions=section(monster,'local function fallbackRoute(', 'local function recompute(')
fallback_cases=r"""
fallbackRoute(Vector3.new(30,0,0))
check(#waypoints==4 and wpIndex==2,'distant obstacle preserves clear starting route')
"""
rock_setup=r"""
local held={}
local function setHeld(p,n) held[p]=n end
local callbacks={}
local Remotes={Throw={OnServerEvent={Connect=function(_,fn) callbacks.throw=fn end}}}
local delays={}
local task={delay=function(_,fn) table.insert(delays,fn) end}
local workspace={GetServerTimeNow=function() return now end}
local lastRock=nil
local function makeRock(pos)
 local r={Position=pos,alive=true,attributes={}}
 r.IsDescendantOf=function(self) return self.alive end
 r.SetAttribute=function(self,k,v) self.attributes[k]=v end
 r.SetNetworkOwner=function() end
 r.Touched={Connect=function(_,fn) r.touch=fn end}
 lastRock=r;return r
end
local pulses={}
local noiseBindable={Fire=function(_,pos,loudness) table.insert(pulses,{pos=pos,loudness=loudness}) end}
"""
rock_functions=section(rocks,'local function finiteVector(', 'local function setHeld(')
rock_functions+=rocks[rocks.index('Remotes.Throw.OnServerEvent:Connect'):]
rock_cases=r"""
local p=player(1,0,0,true);held[p]=3
callbacks.throw(p,Vector3.zero);check(held[p]==3 and lastRock==nil,'zero direction cannot consume rock')
callbacks.throw(p,Vector3.new(0/0,0,0));check(held[p]==3,'NaN direction rejected')
callbacks.throw(p,Vector3.new(math.huge,0,0));check(held[p]==3,'infinite direction rejected')
p.attrs.InMatch=false;callbacks.throw(p,Vector3.new(1,0,0));check(held[p]==3,'loading player cannot throw')
p.attrs.InMatch=true;callbacks.throw(p,Vector3.new(1,0,0));check(held[p]==2,'valid throw consumes one rock')
local solid={CanCollide=true,IsDescendantOf=function() return false end}
local trigger={CanCollide=false,IsDescendantOf=function() return false end}
lastRock.touch(trigger);check(#pulses==0,'noncolliding trigger creates no impact')
lastRock.touch(solid);lastRock.touch(solid);delays[#delays]()
check(#pulses==1 and pulses[1].loudness==95,'first solid hit creates exactly one loud pulse')
callbacks.throw(p,Vector3.new(1,0,0));lastRock.alive=false;delays[#delays]()
check(#pulses==1,'removed rock cannot emit delayed ghost sound')
callbacks.throw(p,Vector3.new(1,0,0));delays[#delays]()
check(#pulses==2 and pulses[2].loudness==57,'missed impact fallback emits one weaker pulse')
print('TOTAL',count,'checks passed')
"""
out=root / '.tools/luau/ai-audit.generated.luau'
out.write_text(preamble+modules+functions+cases+fallback_setup+fallback_functions+fallback_cases+rock_setup+rock_functions+rock_cases,encoding='utf-8')
subprocess.run([str(root / '.tools/luau/luau.exe'),str(out)],check=True,cwd=root)
