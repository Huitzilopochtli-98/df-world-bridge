-- Deliver individual, unreserved blocks to a project. The command adapter
-- should show the available quantity and obtain an explicit in-game action.
local materials=require('world-bridge.materials')
local project=require('world-bridge.project')
local store=require('world-bridge.store')
local M={}

local function copy(value)
    if type(value)~='table' then return value end
    local result={};for k,v in pairs(value) do result[k]=copy(v) end;return result
end

-- Dependencies also capture/restore ground items. Removal and ledger writes
-- run without advancing the simulation, so failed deliveries can restore
-- items before DF garbage-collects them.
function M.deliver(deps,id,limit,now)
    assert(type(id)=='number' and id>=0 and id==math.floor(id), 'invalid project id')
    assert(type(limit)=='number' and limit>=0 and limit==math.floor(limit), 'invalid amount')
    assert(type(now)=='number' and now>=0 and now==math.floor(now) and now<1e15, 'invalid time')
    assert(type(deps.capture)=='function' and type(deps.restore)=='function',
        'delivery needs reversible item removal')
    local data=store.load(deps.persistent)
    local previous=copy(data)
    local p
    for _,entry in ipairs(data.projects) do
        if entry.project.id==id then
            assert(entry.owner_site_id==deps.site_id, 'project belongs to another fortress')
            p=entry.project;break
        end
    end
    assert(p and p.state=='funding', 'project is not accepting blocks')
    local ids=materials.select(deps.items,deps.block_type,math.min(limit,project.missing(p)))
    local delivered,staged=0,{}
    local ok,err=pcall(function()
        for _,item_id in ipairs(ids) do
            local item=deps.find(item_id)
            if materials.usable(item,deps.block_type) then
                local snapshot=deps.capture(item)
                staged[#staged+1]={item=item,snapshot=snapshot}
                local mat_type,mat_index=item:getMaterial(),item:getMaterialIndex()
                if deps.remove(item) then
                    if p.material_type==nil then p.material_type=mat_type;p.material_index=mat_index end
                    project.fund(p,1,now)
                    delivered=delivered+1
                else
                    -- Even a failed adapter call must leave the item intact.
                    assert(deps.restore(item,snapshot)~=false,'could not restore an unconsumed block')
                    staged[#staged]=nil
                end
            end
        end
        if delivered>0 then store.save(deps.persistent,data) end
    end)
    if not ok then
        local failures={}
        for i=#staged,1,-1 do
            local s=staged[i]
            local restored,why=pcall(function()
                assert(deps.restore(s.item,s.snapshot)~=false,'item restore returned false')
            end)
            if not restored then failures[#failures+1]=tostring(why) end
        end
        local restored,why=pcall(store.save,deps.persistent,previous)
        if not restored then failures[#failures+1]=tostring(why) end
        if #failures>0 then
            if deps.pause then deps.pause() end
            error(tostring(err)..'; delivery rollback requires attention: '..table.concat(failures,'; '))
        end
        error('Delivery rolled back: '..tostring(err))
    end
    return delivered,project.missing(p),p.state
end
return M
