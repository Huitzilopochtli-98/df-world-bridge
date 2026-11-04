local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
local block={tiletype={[0]={[0]=10}},designation={[0]={[0]={flow_size=0,liquid_type=false,pile=false,water_table=false,hidden=false,dig=0}}},
 occupancy={[0]={[0]={unit=false,unit_grounded=false,item=false,vehicle=false,building=0,edge_flow_in=false,monster_lair=false}}}}
local attrs={[10]={shape=1,material=1},[11]={shape=2,material=2},[12]={shape=2,material=9},[13]={shape=3,material=2}}
df={global={world={map={x_count=16,y_count=16,z_count=10}}},
 tiletype={attrs=attrs},tiletype_shape={EMPTY=1,attrs={[1]={basic_shape=1},[2]={basic_shape=2},[3]={basic_shape=3}}},
 tiletype_shape_basic={Open=1,Floor=2,Wall=3},tile_building_occ={None=0},tile_dig_designation={No=0},
 tiletype_material={AIR=1,SOIL=2,STONE=3,MINERAL=4,LAVA_STONE=5,GRASS_LIGHT=6,GRASS_DARK=7,GRASS_DRY=8,GRASS_DEAD=9}}
local constructed=false;local building=false
dfhack={maps={getTileBlock=function()return block end},constructions={findAtTile=function()return constructed and {} or nil end},
 buildings={findAtTile=function()return building and {} or nil end}}
local module=dofile(root..'/lua/world-bridge/df-local-probe.lua')
local probe=module.probe
assert(probe(0,0,0).shape=='open' and not probe(0,0,0).occupied)
block.tiletype[0][0]=11;assert(probe(0,0,0).shape=='natural_floor')
block.tiletype[0][0]=13;assert(probe(0,0,0).shape=='natural_wall')
block.tiletype[0][0]=10;block.designation[0][0].flow_size=7;assert(probe(0,0,0).liquid=='water')
block.designation[0][0].liquid_type=true;assert(probe(0,0,0).liquid=='magma')
constructed=true;assert(probe(0,0,0).occupied);constructed=false;building=true;assert(probe(0,0,0).occupied);building=false
block.designation[0][0].hidden=true;assert(probe(0,0,0).occupied)
block.designation[0][0].hidden=false;block.occupancy[0][0].edge_flow_in=true
assert(probe(0,0,0,'support').occupied)
local building_probe=module.for_materialization()
assert(not building_probe(0,0,0,'support').occupied and building_probe(0,0,0,'support').source)
assert(building_probe(0,0,0,'deck').occupied and block.occupancy[0][0].edge_flow_in)
assert(probe(-1,0,0)==nil)
print('local map inspection tests passed')
