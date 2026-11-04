local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
df={historical_entity_type={Civilization=0},diplomacy_state_type={NONE=-1,Peace=0}}
local adapter=require('world-bridge.df-trade-access')
local function civ(id)
 return {id=id,type=0,flags={},entity_raw={flags={},active_season={[0]=false,[1]=true,[2]=false,[3]=false}},relations={diplomacy={state={}}}}
end
local home=civ(1);local fort=civ(2);local e=civ(3)
assert(adapter.eligible(e,{home,fort}) and not adapter.eligible(home,{home,fort}))
for _,flag in ipairs{'dead','secret','isolated'} do
 e.flags[flag]=true;assert(not adapter.eligible(e,{home,fort}));e.flags[flag]=false
end
for _,flag in ipairs{'BABYSNATCHER','ITEM_THIEF','SKULKING','LAYER_LINKED'} do
 e.entity_raw.flags[flag]=true;assert(not adapter.eligible(e,{home,fort}));e.entity_raw.flags[flag]=false
end
e.entity_raw.active_season[1]=false;assert(not adapter.eligible(e,{home,fort}));e.entity_raw.active_season[1]=true
for _,side in ipairs{e,home,fort} do
 local target=side==e and home.id or e.id
 for _,relation in ipairs{1,2,3,4,5} do
  side.relations.diplomacy.state={{group_id=target,relation=relation}}
  assert(not adapter.eligible(e,{home,fort}))
 end
 side.relations.diplomacy.state={{group_id=target,relation=0}}
 assert(adapter.eligible(e,{home,fort}))
 side.relations.diplomacy.state={{group_id=target,relation=-1}}
 assert(adapter.eligible(e,{home,fort}))
 side.relations.diplomacy.state={}
end
print('native trade culture and diplomacy policy tests passed')
