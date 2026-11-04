-- Identify newly created raid controllers while a bridge accessibility
-- overlay is active. This module does not start or alter missions.
local M={}
function M.begin(controllers)
    local baseline={}
    for _,c in ipairs(controllers) do baseline[c.id]=true end
    return {baseline=baseline,seen={}}
end
-- is_extended(site_id) tests the active overlay, owns_squad(id) identifies
-- a squad from the current fort, and is_raid(c) recognizes supported goals.
function M.observe(state,controllers,is_extended,owns_squad,is_raid)
    local found={}
    for _,c in ipairs(controllers) do
        if not state.baseline[c.id] and not state.seen[c.id] and is_raid(c)
           and is_extended(c.site_id) then
            local owned=true
            for _,id in ipairs(c.assigned_squads) do
                if not owns_squad(id) then owned=false end
            end
            -- A raid controller can exist before the player assigns squads.
            -- Retain it so a later guard dismissal cannot lose the mission.
            if owned then
                state.seen[c.id]=true
                found[#found+1]={controller_id=c.id,site_id=c.site_id}
            end
        end
    end
    return found
end
return M
