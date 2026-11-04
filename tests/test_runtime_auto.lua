local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local now=0;local screen={_type='fort'};local cur=screen;local timer;local next_id=0
local env={now=function()return now end,persistent={},site_id=1}
local updates,stops,cancels,shows=0,0,0,0;local fail=false;local guard
local automatic={update=function()updates=updates+1;if fail then error('injected') end end,stop=function()stops=stops+1 end}
local trade_updates,trade_stops=0,0;local trade_fail=false
package.loaded['world-bridge.df-trade-access']={refresh=function(_,enabled)
 assert(enabled);trade_updates=trade_updates+1;if trade_fail then error('injected trade failure') end
end,stop=function()trade_stops=trade_stops+1 end}
package.loaded['world-bridge.automatic-experiment']=automatic
package.loaded['world-bridge.df-adapter']={environment=function()return env end}
package.loaded['world-bridge.store']={load=function()return {projects={}} end}
package.loaded['world-bridge.service']={advance=function()error('unexpected project') end}
package.loaded['world-bridge.steering-adapter']={update=function()end,cancel_all=function()cancels=cancels+1 end}
df={viewscreen_worldst='world',global={pause_state=false}}
dfhack={isMapLoaded=function()return true end,world={isFortressMode=function()return true end},
 gui={getDFViewscreen=function()return screen end,getCurViewscreen=function()return cur end,showAnnouncement=function()end},
 timeout=function(_,_,fn)next_id=next_id+1;timer=fn;return next_id end,timeout_active=function()timer=nil end,
 printerr=function()end,
 run_script=function(name)
  assert(name=='gui/world-bridge-guard');shows=shows+1
  guard={_native={_type='guard'},active=true};cur=guard._native
  function guard:isActive()return self.active end
  function guard:dismiss()self.active=false;cur=screen;automatic.stop() end
  function guard:suspend()automatic.stop() end
 end,
 script_environment=function()return {view=guard} end}
local runtime=require('world-bridge.runtime')
runtime.configure_automatic(true);runtime.start();assert(updates==1 and shows==0 and runtime.is_active())
screen={_type='world'};cur=screen;timer();assert(shows==1 and updates==2 and guard.active)
-- Another overlay is above the guard; temporary accessibility must be removed.
cur={_type='other'};timer();assert(stops==1 and updates==2)
cur=guard._native;timer();assert(updates==3)
-- Leaving the map dismisses the guard and continues processing pending work.
screen={_type='fort'};cur=screen;timer();assert(not guard.active and updates==4)
-- A failure removes the guard and pauses after cleanup.
screen={_type='world'};cur=screen;fail=true;df.global.pause_state=false;timer()
assert(not runtime.is_active() and df.global.pause_state and cancels==1 and not guard.active)
fail=false;screen={_type='fort'};cur=screen
runtime.configure_automatic(false);runtime.configure_trade(true);runtime.start()
assert(runtime.is_active() and runtime.is_trade_enabled() and trade_updates==1)
timer();assert(trade_updates==1,'trade geography must not be rebuilt every frame')
now=1200;timer();assert(trade_updates==2)
runtime.configure_trade(false);local stopped=trade_stops
now=2400;timer();assert(trade_updates==2 and not runtime.is_trade_enabled())
runtime.configure_trade(true);trade_fail=true;df.global.pause_state=false;timer()
assert(not runtime.is_active() and df.global.pause_state and trade_stops>stopped and cancels==2)
print('experimental automatic runtime tests passed')
