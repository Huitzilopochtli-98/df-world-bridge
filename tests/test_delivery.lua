local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local store=require('world-bridge.store')
local project=require('world-bridge.project')
local delivery=require('world-bridge.delivery')
local db={}
local persistent={getWorldData=function(k,d) return db[k] or d end,
    saveWorldData=function(k,v) db[k]=v end}
local p=project.create(0,{{x=0,y=0},{x=1,y=0},{x=2,y=0}},2,100)
store.save(persistent,{version=1,next_id=1,projects={{owner_site_id=7,project=p}}})
local function item(id,forbidden)
    return {id=id,stack_size=1,flags={on_ground=true,forbid=forbidden},flags2={},
        getType=function() return 2 end,getMaterial=function() return 0 end,
        getMaterialIndex=function() return 33 end}
end
local a,b,c=item(4),item(2,true),item(3)
local items={a,b,c}
local deps={persistent=persistent,items=items,block_type=2,site_id=7,
    find=function(id) for _,x in ipairs(items) do if x.id==id then return x end end end,
    remove=function(x) x.flags.removed=true;return true end,
    capture=function(x)return {removed=x.flags.removed} end,
    restore=function(x,snapshot)x.flags.removed=snapshot.removed;return true end}
local n,left,state=delivery.deliver(deps,0,2,1000)
assert(n==2 and left==0 and state=='building' and p.started_tick==1000)
assert(p.material_type==0 and p.material_index==33 and not b.flags.removed)
assert(not pcall(delivery.deliver,deps,0,1,1001))
local other=project.create(1,{{x=0,y=0},{x=1,y=0},{x=2,y=0}},1,1)
local d=store.load(persistent);d.next_id=2;d.projects[2]={owner_site_id=8,project=other};store.save(persistent,d)
assert(not pcall(delivery.deliver,deps,1,1,1001))

-- Ledger failure after a multi-item removal must restore every item and the
-- old project, including when persistence mutates its data before throwing.
local function failure_case(remove_failure,restore_failure)
    local data={}
    local ps={getWorldData=function(k,d)return data[k] or d end,
        saveWorldData=function(k,v)data[k]=v end}
    local p0=project.create(0,{{x=0,y=0},{x=1,y=0},{x=2,y=0}},2,100)
    store.save(ps,{version=1,next_id=1,projects={{owner_site_id=7,project=p0}}})
    local x,y=item(10),item(11)
    local paused=false
    local dd={persistent=ps,site_id=7,items={x,y},block_type=2,
        find=function(id)return id==10 and x or y end,
        capture=deps.capture,
        restore=function(it,snapshot)
            if restore_failure and it.id==10 then error('restore failed') end
            return deps.restore(it,snapshot)
        end,
        pause=function()paused=true end,
        remove=function(it)
            it.flags.removed=true
            if remove_failure and it.id==11 then error('remove failed after mutation') end
            return true
        end}
    local once=true
    ps.saveWorldData=function(k,v)
        data[k]=v
        if once and not remove_failure then once=false;error('save failed after mutation') end
    end
    local success,err=pcall(delivery.deliver,dd,0,2,1234)
    assert(not success)
    local reloaded=store.load(ps).projects[1].project
    assert(reloaded.supplied_blocks==0 and reloaded.state=='funding' and
        reloaded.started_tick==nil and reloaded.material_type==nil)
    if restore_failure then
        assert(paused and err:match('rollback requires attention'))
    else
        assert(not x.flags.removed and not y.flags.removed and not paused)
        assert(err:match('Delivery rolled back'))
    end
end
failure_case(false,false)
failure_case(true,false)
failure_case(true,true)

-- Native item references can reserve a block even when in_job is unset.
local reserved=item(12);reserved.specific_refs={{}}
assert(not require('world-bridge.materials').usable(reserved,2))
reserved.specific_refs={};reserved.world_data_id=40
assert(not require('world-bridge.materials').usable(reserved,2))
print('material delivery tests passed')
