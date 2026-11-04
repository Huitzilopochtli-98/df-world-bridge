-- Atomic in-memory construction transaction. Native placement and ledger
-- updates run on the game thread; a failure undoes all installed cells.
local M={}
function M.commit(adapter,entry,previous)
    local staged={};local installed=0
    local ok,result=pcall(function()
        for _,cell in ipairs(entry.cells) do staged[#staged+1]=adapter.stage(cell,entry) end
        for _,s in ipairs(staged) do installed=installed+1;adapter.install(s) end
        adapter.save(entry)
        return entry
    end)
    if not ok then
        local rollback_errors={}
        for i=installed,1,-1 do local undone,err=pcall(adapter.undo,staged[i]);if not undone then rollback_errors[#rollback_errors+1]=tostring(err) end end
        for i=installed+1,#staged do local disposed,err=pcall(adapter.dispose,staged[i]);if not disposed then rollback_errors[#rollback_errors+1]=tostring(err) end end
        local restored,err=pcall(adapter.restore_ledger,previous)
        if not restored then rollback_errors[#rollback_errors+1]=tostring(err) end
        adapter.invalidate()
        if #rollback_errors>0 then error(tostring(result)..'; rollback requires attention: '..table.concat(rollback_errors,'; ')) end
        error(result)
    end
    adapter.invalidate()
    return result
end
return M
