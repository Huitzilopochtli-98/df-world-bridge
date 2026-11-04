-- Select unreserved individual blocks. Actual removal and persistence belong
-- to the DF adapter; this module does not change items or their flags.
local M={}
local disallowed={'in_job','hostile','in_inventory','removed','in_building',
    'construction','encased','trader','owned','garbage_collect','artifact',
    'forbid','dump','on_fire','melt','hidden','artifact_mood'}

function M.usable(item, block_type)
    if not item or item:getType()~=block_type or item.stack_size~=1 then return false end
    if (item.world_data_id~=nil and item.world_data_id~=-1) or
       (item.specific_refs and #item.specific_refs>0) then return false end
    local f=item.flags
    if not f.on_ground then return false end
    for _,name in ipairs(disallowed) do if f[name] then return false end end
    if item.flags2.location_reserved or item.flags2.utterly_destroyed then return false end
    return true
end

-- Items supplied by a DF vector or a normal Lua array. The result contains
-- IDs so the adapter can revalidate every item before consuming it.
function M.select(items, block_type, limit)
    assert(type(limit)=='number' and limit>=0 and limit==math.floor(limit), 'invalid limit')
    local result,seen={},{}
    for _,item in ipairs(items) do
        if M.usable(item,block_type) and not seen[item.id] then
            seen[item.id]=true;result[#result+1]=item.id
        end
    end
    table.sort(result)
    while #result>limit do result[#result]=nil end
    return result
end

return M
