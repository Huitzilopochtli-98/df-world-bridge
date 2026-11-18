-- Native local bridge materialization for the verified DF/DFHack build.
local plan=require('world-bridge.local-plan')
local probe_module=require('world-bridge.df-local-probe')
local ledger=require('world-bridge.local-store')
local transaction=require('world-bridge.local-transaction')
local native=require('world-bridge.construction')
local approach=require('world-bridge.local-approach')
local geometry=require('world-bridge.local-geometry')
local elevation=require('world-bridge.deck-elevation')
local M={}
local function copy(v)if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
local function invalidate()
    df.global.world.reindex_pathfinding=true
end
local function map_matches(e,m)
    return e.region_x==m.region_x and e.region_y==m.region_y and e.region_z==m.region_z and e.width==m.x_count and e.height==m.y_count
end
function M.verify(env,entry)
    local m=df.global.world.map
    if entry.site_id~=env.site_id or not map_matches(entry,m) then return false,'placement belongs to another local map' end
    for _,cell in ipairs(entry.cells) do
        local p={x=cell.x,y=cell.y,z=cell.z};local b=dfhack.maps.getTileBlock(p);local c=dfhack.constructions.findAtTile(p)
        if not b or not c then return false,'local construction is missing' end
        local x,y=cell.x%16,cell.y%16
        if b.tiletype[x][y]~=cell.after_tile or b.designation[x][y].flow_size~=0 or b.occupancy[x][y].edge_flow_in~=cell.source or
            c.original_tile~=cell.before_tile or c.item_type~=df.item_type.BLOCKS or c.item_subtype~=-1 or
            c.mat_type~=entry.material_type or c.mat_index~=entry.material_index or not c.flags.no_build_item then
            return false,('local tile %d,%d,%d was changed'):format(cell.x,cell.y,cell.z)
        end
    end
    return true
end

local function cell_key(x,y,z)
    return x..','..y..','..z
end

function M.prepare_removal(env,entry)
    local intact,why=M.verify(env,entry)
    assert(intact,why)
    local map=df.global.world.map
    local footprint,tiles,records,indices={}, {}, {}, {}
    local list=df.global.world.event.constructions
    for _,cell in ipairs(entry.cells) do
        local pos={x=cell.x,y=cell.y,z=cell.z}
        local record=dfhack.constructions.findAtTile(pos)
        footprint[cell_key(cell.x,cell.y,cell.z)]=true
        tiles[#tiles+1]={cell=cell,block=dfhack.maps.getTileBlock(pos)}
        local _,address=df.sizeof(record)
        assert(address and not records[address],'unexpected local construction reference')
        records[address]=record
    end

    local function inspect(x,y,z)
        if x<0 or y<0 or z<0 or x>=map.x_count or y>=map.y_count or z>=map.z_count then return end
        local pos={x=x,y=y,z=z}
        local block=dfhack.maps.getTileBlock(pos)
        assert(block,'nearby local terrain is unavailable')
        local lx,ly=x%16,y%16
        local d,o=block.designation[lx][ly],block.occupancy[lx][ly]
        local attrs=df.tiletype.attrs[block.tiletype[lx][ly]]
        return pos,d,o,attrs
    end
    local function clear(pos,d,o)
        assert(not (o.unit or o.unit_grounded or o.item or o.vehicle or o.monster_lair or d.pile or
            o.building~=df.tile_building_occ.None or dfhack.buildings.findAtTile(pos)),
            ('a unit, item, vehicle, stockpile or building is on or above the deck at %d,%d,%d'):format(pos.x,pos.y,pos.z))
        assert(not d.hidden and not d.water_table and d.dig==df.tile_dig_designation.No,
            ('unsafe terrain or designation at %d,%d,%d'):format(pos.x,pos.y,pos.z))
    end
    local function check_water_boundary(pos,d,attrs)
        local solid=attrs and df.tiletype_shape.attrs[attrs.shape].basic_shape==df.tiletype_shape_basic.Wall
        assert(not d.hidden and not d.water_table and
            (solid or (d.flow_size>0 and not d.liquid_type)),
            ('water boundary changed near %d,%d,%d'):format(pos.x,pos.y,pos.z))
    end
    local directions={{1,0},{-1,0},{0,1},{0,-1}}
    for _,cell in ipairs(entry.cells) do
        local pos,d,o=inspect(cell.x,cell.y,cell.z)
        clear(pos,d,o)
        local above,ad,ao=inspect(cell.x,cell.y,cell.z+1)
        if above then
            clear(above,ad,ao)
            if not footprint[cell_key(above.x,above.y,above.z)] then
                assert(ad.flow_size==0 and not dfhack.constructions.findAtTile(above),
                    'liquid or another construction is above the bridge')
            end
        end
        local wet=cell.before_water>0 or cell.source
        local sides={}
        for _,dir in ipairs(directions) do
            local x,y,z=cell.x+dir[1],cell.y+dir[2],cell.z
            if not footprint[cell_key(x,y,z)] then
                local side,sd,so,attrs=inspect(x,y,z)
                if side then
                    assert(not dfhack.constructions.findAtTile(side) and
                        so.building==df.tile_building_occ.None and not dfhack.buildings.findAtTile(side),
                        'another construction or building touches the bridge')
                    sides[#sides+1]={pos=side,designation=sd,attrs=attrs}
                    wet=wet or (cell.kind=='pillar' and sd.flow_size>0)
                end
            end
        end
        if wet then
            for _,side in ipairs(sides) do check_water_boundary(side.pos,side.designation,side.attrs) end
            local original=df.tiletype.attrs[cell.before_tile]
            assert(original,'unknown original bridge terrain')
            if original.shape==df.tiletype_shape.EMPTY and
                not footprint[cell_key(cell.x,cell.y,cell.z-1)] then
                local below,bd,_,attrs=inspect(cell.x,cell.y,cell.z-1)
                if below then check_water_boundary(below,bd,attrs) end
            end
        end
    end
    for i,record in ipairs(list) do
        local _,address=df.sizeof(record)
        if records[address] then indices[#indices+1]=i end
    end
    assert(#indices==#tiles,'local construction list changed')
    return {
        detach=function(remember)
            for i=#indices,1,-1 do
                local index=indices[i]
                local record=list[index]
                list:erase(index)
                remember(function() list:insert(index,record) end)
            end
            for i=#tiles,1,-1 do
                local cell,block=tiles[i].cell,tiles[i].block
                local x,y=cell.x%16,cell.y%16
                local designation=block.designation[x][y]
                local old_liquid=designation.liquid_type
                remember(function()
                    block.tiletype[x][y]=cell.after_tile
                    designation.flow_size=0
                    designation.liquid_type=old_liquid
                end)
                block.tiletype[x][y]=cell.before_tile
                -- Let existing water and unchanged sources refill the space.
                -- Old depths can be wrong after seasons or drainage.
                if cell.before_water>0 then designation.liquid_type=false end
            end
        end,
        dispose=function()
            for _,record in pairs(records) do record:delete() end
            for _,tile in ipairs(tiles) do
                tile.block.flags.update_liquid=true
                tile.block.flags.update_liquid_twice=true
            end
            invalidate()
        end,
    }
end

function M.suggested_z(env,project_id)
    for _,entry in ipairs(ledger.load(env.persistent).entries) do
        if entry.project_id==project_id then return entry.absolute_z-df.global.world.map.region_z end
    end
    local selected
    for _,entry in ipairs(require('world-bridge.store').load(env.persistent).projects) do
        if entry.project.id==project_id then selected=entry.project;break end
    end
    assert(selected,'bridge project not found')
    local absolute=elevation.choose(selected.path,function(x,y)
        local tile=env.world.region_map[x]:_displace(y)
        local region=env.world.regions[tile.region_id]
        assert(region and region.index==tile.region_id,'water region is missing')
        if region.type==df.world_region_type.Ocean then return 100 end
        if region.type==df.world_region_type.Lake then return region.lake_surface end
    end)
    return absolute-df.global.world.map.region_z
end
function M.preview(env,p,z)
    assert(p.state=='complete','finish the world bridge project first')
    local m=df.global.world.map
    local local_map={region_x=m.region_x,region_y=m.region_y,width=m.x_count,height=m.y_count,z_count=m.z_count}
    -- Unrelated maps must not fail a height or native-record check for a
    -- distant bridge. They require no local placement or ledger entry.
    if #geometry.footprint(p.path,local_map,3).centerline==0 then return {empty=true} end
    local valid,err=native.verify(env.world,p);assert(valid,err)
    z=z or M.suggested_z(env,p.id)
    local data=ledger.load(env.persistent)
    for _,e in ipairs(data.entries) do if e.project_id==p.id then
        assert(e.absolute_z==m.region_z+z,'this project already has a different deck elevation')
        if e.site_id==env.site_id then
            local ok,why=M.verify(env,e);assert(ok,why)
            return {existing=true,entry=e,data=data}
        end
    end end
    local probe=probe_module.for_materialization()
    local result,why=plan.plan(p.path,local_map,z,probe,8,{support_offsets={0,4,-4,5,-5,6,-6,7,-7,8,-8}})
    assert(result,why)
    if #result.deck==0 then return {empty=true,plan=result,data=data} end
    local home_group
    for _,unit in ipairs(df.global.world.units.active) do
        if dfhack.units.isCitizen(unit) then local g=dfhack.maps.getWalkableGroup(unit.pos);if g~=0 then home_group=g;break end end
    end
    local access=approach.find(p.path,local_map,z,probe,result,home_group)
    result.stairs={};result.approaches=0
    if access then
        result.stairs=access.stairs;result.approaches=1
        for _,cell in ipairs(access.deck) do result.deck[#result.deck+1]=cell end
    end
    local entry={project_id=p.id,site_id=env.site_id,region_x=m.region_x,region_y=m.region_y,region_z=m.region_z,
        width=m.x_count,height=m.y_count,deck_z=z,absolute_z=m.region_z+z,
        material_type=p.material_type,material_index=p.material_index,cells={}}
    local seen={}
    local function capture(t,kind,tt)
        local pos={x=t.x,y=t.y,z=t.z};local b=assert(dfhack.maps.getTileBlock(pos),'map block missing')
        local x,y=t.x%16,t.y%16;local key=t.x..','..t.y..','..t.z;assert(not seen[key],'duplicate planned tile');seen[key]=true
        assert(not dfhack.constructions.findAtTile(pos),'existing construction in proposed placement')
        entry.cells[#entry.cells+1]={x=t.x,y=t.y,z=t.z,kind=kind,before_tile=b.tiletype[x][y],
            before_water=b.designation[x][y].flow_size,after_tile=tt,source=b.occupancy[x][y].edge_flow_in}
    end
    for _,t in ipairs(result.pillars) do capture(t,'pillar',df.tiletype.ConstructedPillar) end
    for _,t in ipairs(result.deck) do capture(t,'deck',df.tiletype.ConstructedFloor) end
    local stair_tiles={stair_up=df.tiletype.ConstructedStairU,stair_down=df.tiletype.ConstructedStairD,stair_both=df.tiletype.ConstructedStairUD}
    for _,t in ipairs(result.stairs) do capture(t,t.kind,stair_tiles[t.kind]) end
    table.sort(entry.cells,function(a,b)if a.z~=b.z then return a.z<b.z end;if a.x~=b.x then return a.x<b.x end;return a.y<b.y end)
    local trial=copy(data);trial.entries[#trial.entries+1]=entry;local good,why=ledger.validate(trial);assert(good,why)
    return {entry=entry,plan=result,data=data}
end
function M.build(env,p,z)
    assert(df.global.pause_state,'pause the game before placing a local bridge')
    local preview=M.preview(env,p,z)
    if preview.existing or preview.empty then return preview end
    local entry,data=preview.entry,preview.data;local previous=copy(data)
    local function unlink(c)
        local list=df.global.world.event.constructions
        for i=#list-1,0,-1 do if list[i]==c then list:erase(i);return true end end
        return false
    end
    local adapter={}
    function adapter.stage(cell,e)
        local pos={x=cell.x,y=cell.y,z=cell.z};local b=assert(dfhack.maps.getTileBlock(pos))
        local x,y=cell.x%16,cell.y%16
        assert(b.tiletype[x][y]==cell.before_tile and b.designation[x][y].flow_size==cell.before_water and
            b.occupancy[x][y].edge_flow_in==cell.source and not dfhack.constructions.findAtTile(pos),'placement changed during preparation')
        local c=df.construction:new()
        local ok,why=pcall(function()
            c.pos:assign(pos);c.item_type=df.item_type.BLOCKS;c.item_subtype=-1
            c.mat_type=e.material_type;c.mat_index=e.material_index;c.sec_i_sc1=-1;c.sec_i_sc2=-1;c.original_tile=cell.before_tile;c.flags.no_build_item=true
        end)
        if not ok then c:delete();error(why) end
        return {cell=cell,b=b,c=c,inserted=false}
    end
    function adapter.install(s)
        local c=s.cell;local x,y=c.x%16,c.y%16
        assert(s.b.tiletype[x][y]==c.before_tile and not dfhack.constructions.findAtTile(s.c.pos),'placement changed before insertion')
        assert(dfhack.constructions.insert(s.c),'construction insertion failed');s.inserted=true
        s.b.tiletype[x][y]=c.after_tile;s.b.designation[x][y].flow_size=0
        if c.before_water>0 then s.b.flags.update_liquid=true;s.b.flags.update_liquid_twice=true end
    end
    function adapter.undo(s)
        if s.inserted or dfhack.constructions.findAtTile(s.c.pos)==s.c then assert(unlink(s.c),'could not unlink construction during rollback') end
        local c=s.cell;s.b.tiletype[c.x%16][c.y%16]=c.before_tile;s.b.designation[c.x%16][c.y%16].flow_size=c.before_water
        s.b.flags.update_liquid=true;s.b.flags.update_liquid_twice=true;s.c:delete()
    end
    function adapter.dispose(s)s.c:delete()end
    function adapter.save(e)data.entries[#data.entries+1]=e;ledger.save(env.persistent,data)end
    function adapter.restore_ledger(old)ledger.save(env.persistent,old)end
    adapter.invalidate=invalidate
    transaction.commit(adapter,entry,previous)
    return preview
end
return M
