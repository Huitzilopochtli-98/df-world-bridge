local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
local geometry=dofile(root..'/lua/world-bridge/geometry.lua')
local path={{x=2,y=3},{x=3,y=3},{x=3,y=4},{x=4,y=4}}
local paths=geometry.paths(path)
assert(#paths==#path)
local previous
for _,tile in ipairs(paths) do
    for _,point in ipairs(tile.points) do
        assert(point.x>=0 and point.x<16 and point.y>=0 and point.y<16)
        local x,y=tile.x*16+point.x,tile.y*16+point.y
        if previous then assert(math.abs(x-previous.x)+math.abs(y-previous.y)==1) end
        previous={x=x,y=y}
    end
end
assert(paths[1].points[1].x==8 and paths[1].points[1].y==8)
assert(paths[#paths].points[#paths[#paths].points].x==8)
assert(not pcall(geometry.paths,{{x=0,y=0},{x=1,y=1}}))
print('bridge geometry tests passed')
