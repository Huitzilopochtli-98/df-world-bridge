local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
local materials=dofile(root..'/lua/world-bridge/materials.lua')
local function block(id, flags, flags2, stack)
    flags=flags or {};if flags.on_ground==nil then flags.on_ground=true end
    return {id=id,flags=flags,flags2=flags2 or {},stack_size=stack or 1,
        getType=function() return 2 end}
end
local items={block(8),block(3),block(9,{in_job=true}),block(10,{forbid=true}),
    block(2,{on_ground=false}),block(1,{}, {location_reserved=true}),block(7,{}, {},2),block(3)}
local ids=materials.select(items,2,10)
assert(#ids==2 and ids[1]==3 and ids[2]==8)
assert(#materials.select(items,2,0)==0)
assert(#materials.select(items,2,1)==1)
assert(#materials.select(items,3,5)==0)
assert(not pcall(materials.select,items,2,-1))
print('material selection tests passed')
