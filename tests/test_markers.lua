local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
local M=dofile(root..'/lua/world-bridge/markers.lua')
local registry={projects={
 {project={id=1,state='complete',path={{x=65,y=4},{x=66,y=4},{x=67,y=4}}}},
 {project={id=2,state='complete',path={{x=3,y=1},{x=3,y=2},{x=3,y=3},{x=4,y=3}}}},
 {project={id=3,state='building',path={{x=1,y=1},{x=2,y=1},{x=3,y=1}}}},
 {project={id=4,state='complete',path={{x=1,y=1},{x=2,y=1},{x=3,y=1}}}},
}}
local marks=M.markers(registry,function(p)return p.id~=4 end)
assert(#marks==3 and marks[1].ch=='=' and marks[2].ch=='|' and marks[3].ch=='+')
local port={x=0,y=0,width=75,height=43};local text={width=8,height=12,cols=150,rows=56}
local x,y=M.project(marks[1],{x=66,y=4},port,text);assert(x==75 and y==28)
x,y=M.project(marks[1],{x=65,y=5},port,text);assert(x==77 and y==27)
assert(not M.project({x=200,y=4},{x=66,y=4},port,text))
assert(not M.project(marks[1],{x=66,y=4},port,{width=0,height=12,cols=150,rows=56}))
print('world map marker tests passed')
