local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local access=require('world-bridge.trade-access')
local function copy(v)if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
local function fixture()
 local db={};local flags={[1]=false,[2]=false,[3]=false,[90]=true};local writes=0
 local env={site_id=7,persistent={getWorldData=function(k,d)return copy(db[k] or d) end,
  saveWorldData=function(k,v)db[k]=copy(v) end},
  get=function(id)return flags[id] end,set=function(id,value)writes=writes+1;flags[id]=value end}
 return env,flags,db,function()return writes end
end
local env,flags,db,writes=fixture()
local r=access.update(env,{[1]=true,[2]=true,[90]=true})
assert(r.added==2 and r.owned==2 and flags[1] and flags[2] and flags[90])
assert(writes()==2 and #access.load(env).owned==2)
r=access.update(env,{[1]=true,[2]=true,[90]=true});assert(r.added==0 and writes()==2)
-- Native recalculation after a reload can clear a mod-owned bit. Ownership
-- survives and only the still-valid extension is reapplied.
flags[1]=false;r=access.update(env,{[1]=true,[2]=true});assert(r.added==1 and flags[1])
r=access.update(env,{[2]=true});assert(r.restored==1 and not flags[1] and flags[2])
r=access.update(env,{});assert(r.restored==1 and not flags[2] and flags[90])
access.update(env,{[1]=true,[2]=true})
env.site_id=8;r=access.update(env,{[3]=true})
assert(flags[1] and flags[2] and flags[3] and r.owned==1)
access.update(env,{});assert(flags[1] and flags[2] and not flags[3] and flags[90])

for _,failure in ipairs{'save-after-write','set-after-write','rollback'} do
 local e,f,d=fixture();local paused=false;local native_set=e.set
 e.pause=function()paused=true end
 if failure=='save-after-write' then
  local save=e.persistent.saveWorldData;local first=true
  e.persistent.saveWorldData=function(k,v)save(k,v);if first then first=false;error('save failure') end end
 else
  local failed=false
  e.set=function(id,value)
   native_set(id,value)
   if id==2 and value then failed=true;error('set failure after mutation') end
   if failure=='rollback' and failed and id==1 and not value then error('restore failure') end
  end
 end
 local ok,err=pcall(access.update,e,{[1]=true,[2]=true})
 assert(not ok and not f[1] and not f[2] and f[90] and #access.load(e).owned==0)
 assert(paused==(failure=='rollback'))
 assert(tostring(err):find(failure=='rollback' and 'requires attention' or 'rolled back',1,true))
end
local e,f,d=fixture();d[access.KEY]={version=1,site_id=7,owned={1,1}}
assert(not pcall(access.update,e,{[1]=true}) and not f[1])
print('scoped trade access ownership and rollback tests passed')
