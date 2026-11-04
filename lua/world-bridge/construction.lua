-- Experimental DF 53.16 construction-record adapter.
-- This is not yet enabled for real saves: local-map realization and recovery
-- after partial failures require further validation.
local geometry=require('world-bridge.geometry')
local project=require('world-bridge.project')
local M={}

local function int(n) return type(n)=='number' and n==math.floor(n) end
local function classify(w,x,y)
    local tile=w.region_map[x]:_displace(y)
    if tile.region_id<0 or tile.region_id>=#w.regions then return 'blocked' end
    local r=w.regions[tile.region_id]
    if not r or r.index~=tile.region_id then return 'blocked' end
    if r.type==df.world_region_type.Ocean or r.type==df.world_region_type.Lake then return 'water' end
    if r.type==df.world_region_type.Mountains then return 'blocked' end
    return 'land'
end

-- Verify all prerequisites before creating or linking any objects.
function M.preflight(w,p)
    local ok,err=project.validate(p);if not ok then return nil,err end
    if p.state~='ready' then return nil,'project is not ready' end
    if not int(p.material_type) or not int(p.material_index) then return nil,'missing construction material' end
    local d=w.constructions
    local needed=#p.path-1 -- one road plus one bridge per interior water tile
    if not int(d.next_id) or d.next_id<0 or d.next_id+needed>2147483647 then return nil,'invalid construction ID range' end
    for id=d.next_id,d.next_id+needed-1 do
        if df.world_construction.find(id) then return nil,'construction ID already exists' end
    end
    for i,tile in ipairs(p.path) do
        if tile.x>=w.world_width or tile.y>=w.world_height then return nil,'route leaves world bounds' end
        local expected=(i==1 or i==#p.path) and 'land' or 'water'
        if classify(w,tile.x,tile.y)~=expected then return nil,'route terrain changed' end
        local bx,by=math.floor(tile.x/16),math.floor(tile.y/16)
        if bx>=d.width or by>=d.height then return nil,'missing construction block' end
        local block=d.map[bx]:_displace(by)
        if not block then return nil,'missing construction block' end
        -- Until interaction with existing roads is proven, reject overlaps.
        for _,s in ipairs(block.square) do
            if s.region_pos.x==tile.x and s.region_pos.y==tile.y then return nil,'route overlaps another construction' end
        end
    end
    return geometry.paths(p.path)
end

local function name(n,text)
    n.first_name=text;n.nickname='';n.language=0;n.has_name=true
    for i=0,#n.words-1 do n.words[i]=-1 end
end
local function road_square(tile,id,mat_type,mat_index,own)
    local s=own(df.world_construction_square_roadst:new())
    s.region_pos.x=tile.x;s.region_pos.y=tile.y;s.construction_id=id
    s.item_type=df.item_type.BLOCKS;s.item_subtype=-1;s.mat_type=mat_type;s.mat_index=mat_index
    for _,point in ipairs(tile.points) do
        s.embark_x:insert('#',point.x);s.embark_y:insert('#',point.y)
        -- 24 matches the observed generated road, but its meaning is unknown.
        s.embark_exit:insert('#',24)
    end
    return s
end
local function bridge_square(tile,id,road_id,mat_type,mat_index,own)
    local s=own(df.world_construction_square_bridgest:new())
    s.region_pos.x=tile.x;s.region_pos.y=tile.y;s.construction_id=id;s.road_id=road_id
    s.item_type=df.item_type.BLOCKS;s.item_subtype=-1;s.mat_type=mat_type;s.mat_index=mat_index
    for _,point in ipairs(tile.points) do s.embark_x:insert('#',point.x);s.embark_y:insert('#',point.y) end
    return s
end

-- Return construction IDs. The caller owns project-state persistence and
-- must only mark completion after successful insertion in the same game save.
function M.apply(w,p,commit)
    local tiles,err=M.preflight(w,p);assert(tiles,err)
    local d=w.constructions;local first=d.next_id;local road_id=first
    local road;local records,pending,bridges,created={},{},{},{}
    local function own(obj) created[#created+1]=obj;return obj end
    -- No game ticks can occur inside this Lua call. If an insertion errors,
    -- unlink every newly inserted record by its unique ID before returning.
    local success,problem=pcall(function()
        road=own(df.world_construction_roadst:new());road.id=road_id
        name(road.name,'World Bridge Road '..p.id);records[1]=road
        for i,tile in ipairs(tiles) do
            road.square_pos.x:insert('#',tile.x);road.square_pos.y:insert('#',tile.y)
            road.square_obj:insert('#',road_square(tile,road_id,p.material_type,p.material_index,own))
            local block=d.map[math.floor(tile.x/16)]:_displace(math.floor(tile.y/16))
            pending[#pending+1]={block=block,square=road_square(tile,road_id,p.material_type,p.material_index,own)}
            if i>1 and i<#tiles then
                local id=first+i-1;local b=own(df.world_construction_bridgest:new());b.id=id
                name(b.name,'World Bridge '..p.id)
                b.square_pos.x:insert('#',tile.x);b.square_pos.y:insert('#',tile.y)
                records[#records+1]=b;bridges[#bridges+1]=id
                pending[#pending+1]={block=block,square=bridge_square(tile,id,road_id,p.material_type,p.material_index,own)}
            end
        end
        for _,v in ipairs(pending) do v.block.square:insert('#',v.square) end
        for _,v in ipairs(records) do d.list:insert('#',v) end
        d.next_id=first+#records
        if commit then commit({road_id=road_id,bridge_ids=bridges}) end
    end)
    if not success then
        for _,v in ipairs(pending) do
            local squares=v.block.square
            for i=#squares-1,0,-1 do if squares[i].construction_id>=first and squares[i].construction_id<first+#records then squares:erase(i) end end
        end
        for i=#d.list-1,0,-1 do if d.list[i].id>=first and d.list[i].id<first+#records then d.list:erase(i) end end
        d.next_id=first
        if road then road.square_obj:resize(0) end
        for i=#created,1,-1 do created[i]:delete() end
        error('World Bridge construction insertion failed: '..tostring(problem))
    end
    return {road_id=road_id,bridge_ids=bridges}
end

-- Do not grant bridge access if records disappeared or were changed. This is
-- deliberately strict until more native construction variations are tested.
function M.verify(w,p)
    local ok=project.validate(p)
    if not ok or p.state~='complete' then return false,'invalid completed project' end
    local road=df.world_construction.find(p.construction.road_id)
    if not road or road._type~=df.world_construction_roadst or #road.square_obj~=#p.path
       or #road.square_pos.x~=#p.path or #road.square_pos.y~=#p.path then return false,'road missing or changed' end
    local tiles=geometry.paths(p.path)
    local function matches(s,tile,expected_id,bridge)
        if not s or s.construction_id~=expected_id or s.region_pos.x~=tile.x or s.region_pos.y~=tile.y
           or #s.embark_x~=#tile.points or #s.embark_y~=#tile.points
           or s.mat_type~=p.material_type or s.mat_index~=p.material_index
           or s.item_type~=df.item_type.BLOCKS or s.item_subtype~=-1 then return false end
        if bridge then
            if s._type~=df.world_construction_square_bridgest or s.road_id~=road.id then return false end
        elseif s._type~=df.world_construction_square_roadst or #s.embark_exit~=#tile.points then return false end
        for i,point in ipairs(tile.points) do
            if s.embark_x[i-1]~=point.x or s.embark_y[i-1]~=point.y then return false end
            if not bridge and s.embark_exit[i-1]~=24 then return false end
        end
        return true
    end
    for i,tile in ipairs(tiles) do
        if tile.x>=w.world_width or tile.y>=w.world_height or road.square_pos.x[i-1]~=tile.x
           or road.square_pos.y[i-1]~=tile.y or not matches(road.square_obj[i-1],tile,road.id,false) then
            return false,'road geometry changed'
        end
        local bx,by=math.floor(tile.x/16),math.floor(tile.y/16)
        if bx>=w.constructions.width or by>=w.constructions.height then return false,'construction block missing' end
        local block=w.constructions.map[bx]:_displace(by)
        if not block then return false,'construction block missing' end
        local found_road,found_bridge=0,0
        local bridge_id=(i>1 and i<#tiles) and p.construction.bridge_ids[i-1] or nil
        if bridge_id then
            local b=df.world_construction.find(bridge_id)
            if not b or b._type~=df.world_construction_bridgest or #b.square_pos.x~=1 or #b.square_pos.y~=1
               or b.square_pos.x[0]~=tile.x or b.square_pos.y[0]~=tile.y then return false,'bridge missing or changed' end
        end
        for _,s in ipairs(block.square) do
            if s.construction_id==road.id and s.region_pos.x==tile.x and s.region_pos.y==tile.y then
                if not matches(s,tile,road.id,false) then return false,'road square changed' end
                found_road=found_road+1
            elseif bridge_id and s.construction_id==bridge_id then
                if not matches(s,tile,bridge_id,true) then return false,'bridge square changed' end
                found_bridge=found_bridge+1
            end
        end
        if found_road~=1 or (bridge_id and found_bridge~=1) then return false,'construction square missing or duplicated' end
    end
    return true
end
return M
