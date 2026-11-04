local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local transaction=require('world-bridge.local-transaction')
for _,failure in ipairs({'none','stage','insert','save'}) do
 local world={};local allocated={};local current='old';local saved=0
 local adapter={
  stage=function(c)
   if failure=='stage' and c.id==2 then error('stage failure') end
   local s={id=c.id,inserted=false};allocated[s]=true;return s
  end,
  install=function(s)
   world[s.id]=true;s.inserted=true
   if failure=='insert' and s.id==2 then error('partial insertion failure') end
  end,
  undo=function(s)world[s.id]=nil;allocated[s]=nil end,
  dispose=function(s)allocated[s]=nil end,
  save=function()current='new';if failure=='save' then error('ledger failure after write') end end,
  restore_ledger=function(old)current=old end,
  invalidate=function()saved=saved+1 end,
 }
 local ok=pcall(transaction.commit,adapter,{cells={{id=1},{id=2},{id=3}}},'old')
 if failure=='none' then assert(ok and current=='new' and world[1] and world[2] and world[3])
 else assert(not ok and current=='old' and next(world)==nil and next(allocated)==nil) end
 assert(saved==1)
end
-- A failed rollback is surfaced explicitly, rather than reported as success.
local ok,err=pcall(transaction.commit,{stage=function(c)return c end,install=function()error('insert')end,
 undo=function()error('undo')end,dispose=function()end,save=function()end,restore_ledger=function()end,invalidate=function()end},
 {cells={{id=1}}},{})
assert(not ok and tostring(err):match('rollback requires attention'))
print('local construction rollback tests passed')
