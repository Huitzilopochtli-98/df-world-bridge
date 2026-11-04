local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local map=require('world-bridge.map-coordinates')
local world={width=129,height=65};local center={x=10,y=20}
local p={top_left_corner_x=40,top_left_corner_y=24,dim_x=5,dim_y=3}
local x,y=map.pick(p,center,world,40,24);assert(x==8 and y==19)
x,y=map.pick(p,center,world,119.99,71.99);assert(x==12 and y==21)
assert(not map.pick(p,center,world,120,24))
assert(not map.pick(p,center,world,40,72))
assert(not map.pick(p,center,world,39.99,24))
local px,py=map.pixel(p,center,10,20);assert(px==80 and py==48)
-- Even dimensions put the center tile half a tile past the viewport midpoint.
p.dim_x=6;p.dim_y=4
px,py=map.pixel(p,center,10,20);assert(px==96 and py==64)
x,y=map.pick(p,center,world,px,py);assert(x==10 and y==20)
-- Resized and offset viewports still select every drawn tile correctly.
for _,size in ipairs{{75,43},{100,56},{101,57}} do
 p.dim_x,p.dim_y=size[1],size[2]
 for wx=0,128 do for wy=0,64 do
  px,py=map.pixel(p,{x=64,y=32},wx,wy)
  if px then x,y=map.pick(p,{x=64,y=32},world,px,py);assert(x==wx and y==wy) end
 end end
end
assert(not map.pick(p,{x=0,y=0},world,40,24),'blank area outside the world must not select a tile')
p.dim_x=75;p.dim_y=50
x,y=map.clamp_center(p,world,24,22);assert(x==37 and y==25)
x,y=map.clamp_center(p,world,999,999);assert(x==91 and y==40)
x,y=map.clamp_center(p,{width=17,height=17},0,0);assert(x==8 and y==8)
p.dim_x=0;assert(not map.pick(p,center,world,40,24) and not map.pixel(p,center,10,20))
print('native world-map coordinate tests passed')
