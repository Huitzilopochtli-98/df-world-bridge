-- Project registry saved in the world, since bridges outlive a single fort.
-- Caller provides dfhack.persistent (or an equivalent test double).
local project=require('world-bridge.project')
local M={KEY='world-bridge/projects-v1'}
local function integer(n)
    return type(n)=='number' and n==math.floor(n) and n>=0 and n<1e15
end
function M.validate(data)
    if type(data)~='table' or data.version~=1 or not integer(data.next_id)
       or type(data.projects)~='table' then return false,'invalid registry' end
    for k in pairs(data.projects) do
        if not integer(k) or k<1 or k>#data.projects then return false,'invalid project list' end
    end
    local seen,count={},0
    for _,entry in ipairs(data.projects) do
        count=count+1
        if type(entry)~='table' or not integer(entry.owner_site_id) then return false,'invalid owner' end
        local ok,err=project.validate(entry.project)
        if not ok then return false,err end
        local id=entry.project.id
        if seen[id] or id>=data.next_id then return false,'invalid project id' end
        seen[id]=true
    end
    if count~=#data.projects then return false,'incomplete project list' end
    return true
end
function M.load(persistent)
    local data=persistent.getWorldData(M.KEY,{version=1,next_id=0,projects={}})
    local ok,err=M.validate(data)
    if not ok then error('World Bridge save data: '..err) end
    return data
end
function M.save(persistent,data)
    local ok,err=M.validate(data)
    if not ok then error('World Bridge save data: '..err) end
    persistent.saveWorldData(M.KEY,data)
end
return M
