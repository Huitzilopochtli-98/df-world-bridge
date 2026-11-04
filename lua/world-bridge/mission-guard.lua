-- Experimental: restrict bridge-only destinations to raid missions.
-- Called before native input and rendering, not merely on a timer.
local M={}
function M.filter(screen,is_extended,raid_goal,okay,inaccessible,new_mission_mode)
    if not screen or screen.view_mode~=new_mission_mode or not screen.focus_site then return 0 end
    local site=screen.focus_site
    if not is_extended(site.pos.x,site.pos.y) then return 0 end
    local n=0
    for i,value in ipairs(screen.new_mission) do
        if i~=raid_goal and value==okay then screen.new_mission[i]=inaccessible;n=n+1 end
    end
    return n
end
return M
