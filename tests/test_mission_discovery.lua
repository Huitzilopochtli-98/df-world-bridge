local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
local m=dofile(root..'/lua/world-bridge/mission-discovery.lua')
local existing={id=1,site_id=7,assigned_squads={2},goal='raid'}
local pending={id=3,site_id=7,assigned_squads={},goal='raid'}
local unrelated={id=4,site_id=8,assigned_squads={2},goal='raid'}
local wrong_squad={id=5,site_id=7,assigned_squads={9},goal='raid'}
local diplomacy={id=6,site_id=7,assigned_squads={2},goal='diplomacy'}
local controllers={existing,pending,unrelated,wrong_squad,diplomacy}
local state=m.begin({existing})
local function extended(id)return id==7 end
local function owned(id)return id==2 end
local function raid(c)return c.goal=='raid' end
local initial=m.observe(state,controllers,extended,owned,raid)
assert(#initial==1 and initial[1].controller_id==3)
pending.assigned_squads={2}
local found=m.observe(state,controllers,extended,owned,raid)
assert(#found==0)
assert(#m.observe(state,controllers,extended,owned,raid)==0)
print('mission discovery tests passed')
