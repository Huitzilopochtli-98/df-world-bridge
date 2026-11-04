local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local project=require('world-bridge.project')
local index=require('world-bridge.bridge-index')
local p=project.create(0,{{x=1,y=2},{x=2,y=2},{x=3,y=2}},1,1)
project.fund(p,1,0);project.advance(p,1);project.mark_complete(p,{road_id=5,bridge_ids={6}})
local d={projects={{owner_site_id=1,project=p}}}
local no=index.build(d,function()return false end)
assert(not no.tile(2,2) and not no.edge(1,2,2,2))
local g=index.build(d,function()return true end)
assert(g.tile(2,2) and not g.tile(1,2))
assert(g.edge(1,2,2,2) and g.edge(2,2,1,2) and g.edge(2,2,3,2))
assert(not g.edge(2,2,2,1) and not g.edge(1,2,3,2))
print('completed bridge graph tests passed')
