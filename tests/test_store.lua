local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local store=require('world-bridge.store')
local project=require('world-bridge.project')
local db={}
local fake={getWorldData=function(key,default) return db[key] or default end,
    saveWorldData=function(key,value) db[key]=value end}
local d=store.load(fake)
assert(d.next_id==0 and #d.projects==0)
local p=project.create(0,{{x=0,y=0},{x=1,y=0},{x=2,y=0}},10,100)
d.projects[1]={owner_site_id=42,project=p};d.next_id=1
store.save(fake,d)
assert(store.load(fake).projects[1].owner_site_id==42)
local corrupt={version=1,next_id=0,projects={{owner_site_id=42,project=p}}}
assert(not pcall(store.save,fake,corrupt))
assert(db[store.KEY]==d)
corrupt={version=7,next_id=0,projects={}}
assert(not store.validate(corrupt))
print('world project storage tests passed')
