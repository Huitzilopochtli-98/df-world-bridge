-- World-scoped ledger for local bridge placements, including their original
-- tiles. Each entry belongs to one fortress map; deck height is shared by all
-- entries for the same world project.
local M={KEY='world-bridge/local-placements-v1'}
local function int(n)return type(n)=='number' and n==math.floor(n) end
local function dense(t)
    if type(t)~='table' then return false end
    local n=0;for k in pairs(t) do if not int(k) or k<1 or k>#t then return false end;n=n+1 end
    return n==#t
end
function M.validate(data)
    if type(data)~='table' or data.version~=1 or not dense(data.entries) then return false,'invalid local placement ledger' end
    local maps,heights={},{}
    for _,e in ipairs(data.entries) do
        if type(e)~='table' or not int(e.project_id) or e.project_id<0 or not int(e.site_id) or e.site_id<0 or
            not int(e.region_x) or e.region_x<0 or not int(e.region_y) or e.region_y<0 or not int(e.region_z) or
            not int(e.width) or e.width<1 or not int(e.height) or e.height<1 or
            not int(e.deck_z) or e.deck_z<1 or not int(e.absolute_z) or e.absolute_z~=e.region_z+e.deck_z or
            not int(e.material_type) or e.material_type<0 or not int(e.material_index) or e.material_index< -1 or
            not dense(e.cells) or #e.cells<1 or #e.cells>100000 then return false,'invalid local placement' end
        local k=e.project_id..':'..e.site_id
        if maps[k] then return false,'duplicate local placement' end;maps[k]=true
        if heights[e.project_id] and heights[e.project_id]~=e.absolute_z then return false,'inconsistent deck elevation' end
        heights[e.project_id]=e.absolute_z
        local cells={}
        for _,c in ipairs(e.cells) do
            if type(c)~='table' or not int(c.x) or c.x<0 or c.x>=e.width or not int(c.y) or c.y<0 or c.y>=e.height or
                not int(c.z) or c.z<0 or c.z>e.deck_z or not int(c.before_tile) or c.before_tile<0 or c.before_tile>65535 or
                not int(c.after_tile) or c.after_tile<0 or c.after_tile>65535 or not int(c.before_water) or c.before_water<0 or c.before_water>7 or
                (c.kind~='deck' and c.kind~='pillar' and c.kind~='stair_up' and c.kind~='stair_down' and c.kind~='stair_both') or type(c.source)~='boolean' then return false,'invalid placement tile' end
            local p=c.x..','..c.y..','..c.z;if cells[p] then return false,'duplicate placement tile' end;cells[p]=true
        end
    end
    return true
end
function M.load(persistent)
    local d=persistent.getWorldData(M.KEY,{version=1,entries={}})
    local ok,err=M.validate(d);assert(ok,err);return d
end
function M.save(persistent,data)local ok,err=M.validate(data);assert(ok,err);persistent.saveWorldData(M.KEY,data)end
return M
