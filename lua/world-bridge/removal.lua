-- Remove a single project and its verified native records on the game thread.
local store=require('world-bridge.store')
local ledger=require('world-bridge.local-store')
local M={}

local function without(entries,index)
    local result={}
    for i,entry in ipairs(entries) do
        if i~=index then result[#result+1]=entry end
    end
    return result
end

function M.preview(env,id)
    local data=store.load(env.persistent)
    local index,selected
    for i,entry in ipairs(data.projects) do
        if entry.project.id==id then index,selected=i,entry;break end
    end
    assert(selected,'project not found')
    assert(selected.owner_site_id==env.site_id,'project belongs to another fortress')
    local project=selected.project
    local placements=ledger.load(env.persistent)
    local local_index,section
    for i,entry in ipairs(placements.entries) do
        if entry.project_id==id then
            assert(project.state=='complete','unfinished project has a local deck')
            assert(entry.site_id==env.site_id,'a deck section is on an unloaded fortress map')
            local_index,section=i,entry
        end
    end
    local result={project=project,registry=data,project_index=index,placements=placements,
        local_index=local_index,local_tiles=section and #section.cells or 0}
    if project.state=='complete' then
        env.removal.check_travel(env,project)
        result.world=env.construction.prepare_removal(env.world,project)
        if section then result.local_deck=env.removal.prepare_local(env,section) end
    end
    return result
end

function M.summary(result)
    local p=result.project
    if p.state=='complete' then
        return ('Remove bridge #%d and its world route? This restores %d verified local tiles. No blocks are returned.'):format(p.id,result.local_tiles)
    end
    if p.supplied_blocks==0 then return ('Cancel project #%d? No blocks have been delivered.'):format(p.id) end
    return ('Cancel project #%d? The %d blocks already delivered will be lost.'):format(p.id,p.supplied_blocks)
end

function M.run(env,id,expected_state,expected_blocks)
    local result=M.preview(env,id)
    local project=result.project
    assert(project.state==expected_state and project.supplied_blocks==expected_blocks,
        'project changed since confirmation; review it again')
    if result.world then env.removal.require_pause() end
    local undo={}
    local function remember(action) undo[#undo+1]=action end
    local ok,err=pcall(function()
        if result.local_deck then result.local_deck.detach(remember) end
        if result.world then result.world.detach(remember) end
        if result.local_index then
            local old=result.placements
            remember(function() ledger.save(env.persistent,old) end)
            ledger.save(env.persistent,{version=old.version,entries=without(old.entries,result.local_index)})
        end
        local old=result.registry
        remember(function() store.save(env.persistent,old) end)
        store.save(env.persistent,{version=old.version,next_id=old.next_id,
            projects=without(old.projects,result.project_index)})
    end)
    if not ok then
        local errors={}
        for i=#undo,1,-1 do
            local restored,why=pcall(undo[i])
            if not restored then errors[#errors+1]=tostring(why) end
        end
        if #errors>0 then
            if env.removal then env.removal.pause() end
            error(tostring(err)..'; removal rollback requires attention: '..table.concat(errors,'; '))
        end
        error('Removal rolled back: '..tostring(err))
    end
    if result.local_deck then result.local_deck.dispose() end
    if result.world then result.world.dispose() end
    return {id=id,completed=project.state=='complete',local_tiles=result.local_tiles,
        spent=project.supplied_blocks}
end

return M
