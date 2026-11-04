local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
local steering=dofile(root..'/lua/world-bridge/steering.lua')
local path={{x=1,y=1},{x=2,y=1},{x=3,y=1},{x=4,y=1}}
local s,cmd=steering.begin(7,8,9,200,70,path)
assert(cmd.x==120 and cmd.y==72 and s.index==2)
path[2].x=99;assert(s.path[2].x==2)
local o={controller_present=true,army_present=true,site_id=9,goal_x=120,goal_y=72,army_x=119,army_y=72}
cmd=steering.step(s,o);assert(cmd.x==168 and cmd.y==72 and s.index==3)
o.goal_x=168;o.army_x=168
cmd=steering.step(s,o);assert(cmd.x==200 and cmd.y==70 and s.state=='complete')
local s2=steering.begin(7,8,9,200,70,{{x=1,y=1},{x=2,y=1},{x=3,y=1}})
local cmd2=steering.cancel(s2,{controller_present=true,site_id=9,goal_x=120,goal_y=72})
assert(cmd2.x==200 and s2.state=='cancelled')
local s3=steering.begin(7,8,9,200,70,{{x=1,y=1},{x=2,y=1},{x=3,y=1}})
local c,reason=steering.step(s3,{controller_present=true,site_id=9,goal_x=333,goal_y=4})
assert(c==nil and reason=='controller changed externally' and s3.state=='ended')
assert(not pcall(steering.begin,7,8,9,200,70,{{x=1,y=1},{x=3,y=1},{x=4,y=1}}))
local s4=steering.begin(7,8,9,200,70,{{x=1,y=1},{x=2,y=1},{x=3,y=1}})
s4.expected_x=999
assert(not steering.validate(s4))
assert(not pcall(steering.step,s4,o))
print('mission waypoint state tests passed')
