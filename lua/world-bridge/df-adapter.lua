-- DFHack-specific environment for the project service. Experimental.
local construction=require('world-bridge.construction')
local project=require('world-bridge.project')
local removal=require('world-bridge.df-removal')
local M={}
-- Each Windows Steam build is paired with the tested DFHack code and structures.
local verified_builds={
    ['v0.53.16 win64 STEAM']={
        commit='0bf381cc1615656acf756e6e67573fffca715125',
        xml='d8ff8a6326db37c11dc4173fadcf30b56e51b42d',
    },
    ['v0.53.17 win64 STEAM']={
        commit='3bc63a220af608e1cf20b123dc45bc0a22e296ab',
        xml='611369f12c5f214e0f8114900398ba74e8a2dd2f',
    },
}
function M.environment()
    assert(dfhack.isMapLoaded() and dfhack.world.isFortressMode(), 'load a fortress first')
    -- World-construction and controller layouts are native, version-specific
    -- structures. Refuse writes until another build has been tested.
    local build=verified_builds[dfhack.getDFVersion()]
    assert(build and dfhack.getGitCommit()==build.commit and dfhack.getGitXmlCommit()==build.xml,
        'unsupported DF/DFHack build; World Bridge needs a verified build')
    local w=df.global.world.world_data
    local function classify(x,y)
        local tile=w.region_map[x]:_displace(y)
        if tile.region_id<0 or tile.region_id>=#w.regions then return 'blocked' end
        local r=w.regions[tile.region_id]
        if not r or r.index~=tile.region_id then return 'blocked' end
        if r.type==df.world_region_type.Ocean or r.type==df.world_region_type.Lake then return 'water' end
        if r.type==df.world_region_type.Mountains then return 'blocked' end
        return 'land'
    end
    local site_id=df.global.plotinfo.site_id
    return {world=w,persistent=dfhack.persistent,site_id=site_id,classify=classify,
        now=function()return df.global.cur_year*403200+df.global.cur_year_tick end,
        construction=construction,removal=removal,
        validate_plan=function(p)
            -- Preflight with a synthetic, fully funded copy; no item is used.
            local trial=project.create(p.id,p.path,1,1)
            trial.supplied_blocks=trial.required_blocks;trial.started_tick=0;trial.state='ready'
            trial.material_type=0;trial.material_index=-1
            local shape,err=construction.preflight(w,trial)
            return shape~=nil,err
        end,
        delivery={persistent=dfhack.persistent,site_id=site_id,
            items=df.global.world.items.other.BLOCKS,block_type=df.item_type.BLOCKS,
            find=df.item.find,remove=dfhack.items.remove,
            capture=function(item)
                return {pos={x=item.pos.x,y=item.pos.y,z=item.pos.z},flags=item.flags.whole}
            end,
            restore=function(item,snapshot)
                if item.flags.removed then
                    assert(dfhack.items.moveToGround(item,snapshot.pos),'could not return block to the ground')
                end
                assert(item.flags.on_ground and item.pos.x==snapshot.pos.x and
                    item.pos.y==snapshot.pos.y and item.pos.z==snapshot.pos.z,
                    'block did not return to its original position')
                item.flags.whole=snapshot.flags
                return true
            end,
            pause=function()df.global.pause_state=true end}}
end
return M
