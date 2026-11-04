-- Experimental read-only adapter for local-plan. Unknown or occupied tiles
-- are rejected; this is not sufficient authorization to modify a live map.
local M={}
local function contains(set,value) return set[value] or false end
local mat=df.tiletype_material
local natural={[mat.SOIL]=true,[mat.STONE]=true,[mat.MINERAL]=true,[mat.LAVA_STONE]=true,
    [mat.GRASS_LIGHT]=true,[mat.GRASS_DARK]=true,[mat.GRASS_DRY]=true,[mat.GRASS_DEAD]=true}
local function inspect(x,y,z,role,allow_support_sources)
    local m=df.global.world.map
    if x<0 or y<0 or z<0 or x>=m.x_count or y>=m.y_count or z>=m.z_count then return nil end
    local p={x=x,y=y,z=z};local b=dfhack.maps.getTileBlock(p)
    if not b then return nil end
    local lx,ly=x%16,y%16;local tt=b.tiletype[lx][ly];local a=df.tiletype.attrs[tt]
    if not a then return nil end
    local d,o=b.designation[lx][ly],b.occupancy[lx][ly]
    local reason
    if o.edge_flow_in and not (allow_support_sources and role=='support') then reason='a map-edge liquid source'
    elseif d.water_table then reason='an aquifer'
    elseif d.hidden then reason='unrevealed terrain'
    elseif d.dig~=df.tile_dig_designation.No then reason='a designation'
    elseif o.unit or o.unit_grounded or o.item or o.vehicle or d.pile then reason='a unit, item, vehicle, or stockpile'
    elseif o.building~=df.tile_building_occ.None or o.monster_lair or
        dfhack.constructions.findAtTile(p)~=nil or dfhack.buildings.findAtTile(p)~=nil then reason='a building or construction' end
    local liquid=d.flow_size==0 and 'none' or (d.liquid_type and 'magma' or 'water')
    local shape='blocked';local basic=df.tiletype_shape.attrs[a.shape].basic_shape
    if a.shape==df.tiletype_shape.EMPTY and a.material==mat.AIR then shape='open'
    elseif contains(natural,a.material) and basic==df.tiletype_shape_basic.Floor then shape='natural_floor'
    elseif contains(natural,a.material) and basic==df.tiletype_shape_basic.Wall then shape='natural_wall' end
    return {shape=shape,occupied=reason~=nil,reason=reason,liquid=liquid,source=o.edge_flow_in,
        walk_group=role=='approach' and dfhack.maps.getWalkableGroup(p) or nil}
end
function M.probe(x,y,z,role)return inspect(x,y,z,role,false)end
function M.for_materialization()
    -- Source flags are preserved by the construction transaction. This mode
    -- is used only for supports; the walking deck and headroom stay dry.
    return function(x,y,z,role)return inspect(x,y,z,role,true)end
end
return M
