local root=assert(os.getenv('WORLD_BRIDGE_TEST_ROOT'))
package.path=root..'/lua/?.lua;'..package.path
local removal=require('world-bridge.removal')
local store=require('world-bridge.store')
local ledger=require('world-bridge.local-store')
local project=require('world-bridge.project')

local function fixture(state)
    local p=project.create(7,{{x=1,y=1},{x=2,y=1},{x=3,y=1}},100,16800)
    if state=='funding' then project.fund(p,25,1)
    else
        project.fund(p,100,1)
        if state~='building' then project.advance(p,16801) end
        if state=='complete' then project.mark_complete(p,{road_id=42,bridge_ids={43}}) end
    end
    local section={project_id=7,site_id=10,region_x=0,region_y=0,region_z=2,
        width=48,height=48,deck_z=2,absolute_z=4,material_type=0,material_index=1,
        cells={{x=2,y=3,z=2,before_tile=1,after_tile=2,before_water=0,kind='deck',source=false}}}
    local data={
        [store.KEY]={version=1,next_id=8,projects={{owner_site_id=10,project=p}}},
        [ledger.KEY]={version=1,entries=state=='complete' and {section} or {}},
    }
    local native={world=true,deck=true,disposed=0}
    local failure
    local function part(name)
        return {
            detach=function(remember)
                native[name]=false
                remember(function()native[name]=true end)
                if failure==name then error('injected detach failure') end
            end,
            dispose=function()native.disposed=native.disposed+1 end,
        }
    end
    local env={site_id=10,world={},persistent={
        getWorldData=function(key,default)return data[key] or default end,
        saveWorldData=function(key,value)
            data[key]=value
            if failure==key then failure=nil;error('injected failure after writing') end
        end,
    },construction={prepare_removal=function()return part('world') end},removal={
        check_travel=function()assert(failure~='travel','active guided trip') end,
        prepare_local=function()return part('deck') end,
        require_pause=function()assert(failure~='unpaused','pause the game') end,
        pause=function()error('unexpected rollback failure') end,
    }}
    return env,data,native,function(value)failure=value end
end

for _,state in ipairs({'funding','building','ready'}) do
    local env,data,native=fixture(state)
    local preview=removal.preview(env,7)
    local p=preview.project
    assert(removal.summary(preview):find('will be lost',1,true))
    assert(not pcall(removal.run,env,7,state,0),'must recheck the confirmed block count')
    assert(removal.run(env,7,state,p.supplied_blocks).spent==p.supplied_blocks)
    assert(#data[store.KEY].projects==0 and data[store.KEY].next_id==8)
    assert(native.world and native.deck and native.disposed==0)
end

for _,failure in ipairs({'world','deck',ledger.KEY,store.KEY,'unpaused','travel'}) do
    local env,data,native,fail=fixture('complete')
    fail(failure)
    assert(not pcall(removal.run,env,7,'complete',100))
    assert(native.world and native.deck and native.disposed==0)
    assert(#data[store.KEY].projects==1 and #data[ledger.KEY].entries==1)
end

local env,data,native=fixture('complete')
data[ledger.KEY].entries[1].site_id=11
assert(not pcall(removal.preview,env,7),'cannot remove an unloaded deck')
data[ledger.KEY].entries[1].site_id=10
env.site_id=11
assert(not pcall(removal.preview,env,7),'cannot remove a bridge owned by another fortress')
env.site_id=10
local result=removal.run(env,7,'complete',100)
assert(result.completed and result.local_tiles==1)
assert(#data[store.KEY].projects==0 and #data[ledger.KEY].entries==0 and data[store.KEY].next_id==8)
assert(not native.world and not native.deck and native.disposed==2)
print('project cancellation and removal rollback tests passed')
