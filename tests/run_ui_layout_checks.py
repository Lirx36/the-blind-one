"""Execute actual resize callbacks with GUI doubles; no Roblox Play session."""
from pathlib import Path
import re, subprocess
root=Path(__file__).resolve().parents[1]
files=['src/StarterPlayer/StarterPlayerScripts/'+x+'.client.luau' for x in ['Hud','DeathMenu','GeneratorMinigame','ArrivalCinematic','BlindOneController']]+['lobby-src/StarterPlayer/StarterPlayerScripts/Lobby.client.luau']
parts=[r"""
local function object()
 return {AnchorPoint={X=0,Y=0},Position={X={Scale=0,Offset=0},Y={Scale=0,Offset=0}},Size={X={Scale=0,Offset=300},Y={Scale=0,Offset=100}},scale={Scale=1}}
end
local UDim2={new=function(x,px,y,py) return {X={Scale=x,Offset=px},Y={Scale=y,Offset=py}} end}
UDim2.fromOffset=function(x,y) return UDim2.new(0,x,0,y) end
UDim2.fromScale=function(x,y) return UDim2.new(x,0,y,0) end
local Vector2={new=function(x,y) return {X=x,Y=y} end,zero={X=0,Y=0}}
local Responsive={Scale=function(o) return o.scale end}
local Enum={TextTruncate={AtEnd='AtEnd'},ScreenInsets={DeviceSafeInsets='DeviceSafeInsets',CoreUISafeInsets='CoreUISafeInsets'}}
local cases={{320,260,true},{360,720,true},{390,760,true},{568,270,true},{740,310,true},{844,340,true},{768,940,true},{1024,700,true},{1366,680,false},{1920,1000,false}}
local count=0
"""]
for path in files:
    s=(root/path).read_text(encoding="utf-8")
    start=s.index('Responsive.Watch(gui, function(size');end=s.index('\nend)',start)+5
    callback=s[start:end].replace('Responsive.Watch(gui, ','local update = ',1)[:-1]
    names=set(re.findall(r'local\s+(\w+)\s*=',s))
    names-= {'Responsive','Vector2','UDim2','Enum','math','size','touch','compact','short','width','height','barScale','queueScale','narrow','contentHeight','buttonWidth','update'}
    setup='local env=setmetatable({}, {__index=getfenv()})\n'
    for name in sorted(names): setup+=f'env.{name}=object()\n'
    setup+='env.GuiService={GetGuiInset=function() return Vector2.new(0,36) end}\n'
    setup+='env.queueLayout={}\nenv.roster={}\nenv.Responsive=Responsive\nenv.Vector2=Vector2\nenv.UDim2=UDim2\nenv.Enum=Enum\n'
    parts+=['do\n'+setup+'local chunk=function()\n'+callback+'\nreturn update\nend\nsetfenv(chunk,env)\nlocal update=chunk()\n']
    parts+=['for _,c in cases do local size=Vector2.new(c[1],c[2]);update(size,c[3])\n']
    if '/Hud.' in path:
        parts+=['''local panel=env.panel;local rock=env.rockSlot
local panelWidth=300*panel.scale.Scale
local left=size.X/2+panel.Position.X.Offset-panelWidth/2
local right=size.X/2+rock.Position.X.Offset+rock.Size.X.Offset*rock.scale.Scale
assert(left>=0 and right<=size.X,'HUD inventory leaves screen')
assert(env.objectiveBanner.Size.X.Offset<=size.X,'objective width')
assert(env.objectiveTitle.Visible and env.objectiveRule.Visible,'objective heading retained')
if c[3] then assert(env.objectiveBanner.Position.Y.Offset==2,'phone objective raised') end
assert(env.objectiveTitle.Position.Y.Offset+env.objectiveTitle.Size.Y.Offset<=env.objective.Position.Y.Offset,'heading clears mission text')
''']
    elif '/DeathMenu.' in path:
        parts+=['assert(env.panel.Size.X.Offset*env.terminalScale.Scale<=size.X and env.panel.Size.Y.Offset*env.terminalScale.Scale<=size.Y,"terminal fits")\nassert(env.panel.Size.Y.Offset>=570,"buttons retain space")\n']
    elif '/GeneratorMinigame.' in path:
        parts+=['assert(env.panel.Size.X.Offset*env.scale.Scale<=size.X and env.panel.Size.Y.Offset*env.scale.Scale<=size.Y,"calibration fits")\nassert(env.calibrate.Size.Y.Offset*env.scale.Scale>=40,"calibration touch target")\nassert(env.roundLabel.Position.Y.Offset+24<=env.track.Position.Y.Offset,"labels clear track")\n']
    elif '/Lobby.' in path:
        parts+=['assert(env.panel.Size.X.Offset*env.panelScale.Scale<=size.X and env.panel.Size.Y.Offset*env.panelScale.Scale<=size.Y,"queue fits")\nassert(env.panelScale.Scale>0 and env.panelScale.Scale<=1,"queue fits without scrolling")\nassert(env.plus.Size.X.Offset>=44 and env.minus.Size.Y.Offset>=44,"capacity touch targets")\n']
    parts+=['count+=1\nend\nend\n']
parts+=['print("PASS",count,"layout scenarios across phones, tablets and laptops")\n']
out=root/'.tools/luau/ui-layout.generated.luau';out.write_text(''.join(parts))
subprocess.run([str(root/'.tools/luau/luau.exe'),str(out)],check=True,cwd=root)
