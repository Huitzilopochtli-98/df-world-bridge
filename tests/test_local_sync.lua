local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local option;local calls={};local fail=false;local announced=0
local persistent={getWorldData=function(_,d)return option or d end,saveWorldData=function(_,v)option=v end}
package.loaded['world-bridge.store']={load=function()return {projects={{project={id=1,state='complete'}},{project={id=2,state='funding'}},{project={id=3,state='complete'}}}} end}
package.loaded['world-bridge.local-construction']={build=function(_,p)
 calls[#calls+1]=p.id;if fail and p.id==1 then error('occupied') end
 return p.id==1 and {} or {empty=true}
end}
df={global={pause_state=false}};COLOR_GREEN=2
dfhack={printerr=function()end,gui={showAnnouncement=function()announced=announced+1 end}}
local sync=require('world-bridge.local-sync');local env={persistent=persistent}
local a=sync.run(env);assert(a.built==1 and a.verified==0 and #a.errors==0 and #calls==2 and not df.global.pause_state and announced==1)
calls={};sync.set_enabled(persistent,false);a=sync.run(env);assert(#calls==0 and not df.global.pause_state)
sync.set_enabled(persistent,true);fail=true;a=sync.run(env,1)
assert(#a.errors==1 and df.global.pause_state and #calls==1)
print('automatic local placement tests passed')
