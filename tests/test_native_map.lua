local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local native=require('world-bridge.native-map')
local g={mouse_x=7,mouse_y=9,precise_mouse_x=59,precise_mouse_y=112}
local e={tracking_on=1,mouse_lbut=1,mouse_rbut=2,mouse_mbut=3,mouse_lbut_down=4,mouse_rbut_down=5,mouse_mbut_down=6}
df={global={gps=g,enabler=e}}
for _,fail in ipairs{false,true} do
 local ok,value=pcall(native.without_mouse,function()
  assert(g.mouse_x==-1 and g.precise_mouse_y==-1 and e.tracking_on==0)
  for k,v in pairs(e) do assert(v==0,k) end
  if fail then error('render failed') end
  return 'rendered'
 end)
 assert(ok~=fail and (fail or value=='rendered'))
 assert(g.mouse_x==7 and g.mouse_y==9 and g.precise_mouse_x==59 and g.precise_mouse_y==112)
 assert(e.tracking_on==1 and e.mouse_lbut==1 and e.mouse_rbut==2 and e.mouse_mbut==3)
 assert(e.mouse_lbut_down==4 and e.mouse_rbut_down==5 and e.mouse_mbut_down==6)
end
print('native planner mouse isolation tests passed')
