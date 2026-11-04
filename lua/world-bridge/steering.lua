-- Pure waypoint state machine for one native mission controller and army.
-- The adapter must persist the state before changing a controller and must
-- verify it still owns that controller before applying any returned command.
local M={}
local function integer(n) return type(n)=='number' and n==math.floor(n) and n>=0 end
local function center(p) return p.x*48+24,p.y*48+24 end

function M.validate(s)
    if type(s)~='table' or s.version~=1 or s.state~='steering' or
       not integer(s.controller_id) or not integer(s.army_id) or not integer(s.site_id) or
       not integer(s.original_x) or not integer(s.original_y) or
       type(s.path)~='table' or #s.path<3 or #s.path>65536 or not integer(s.index) or
       s.index<2 or s.index>=#s.path then return false,'invalid steering state' end
    local count=0
    for k in pairs(s.path) do if not integer(k) or k<1 or k>#s.path then return false,'invalid waypoint list' end end
    for i,p in ipairs(s.path) do
        count=count+1
        if type(p)~='table' or not integer(p.x) or not integer(p.y) then return false,'invalid waypoint' end
        if i>1 then
            local dx,dy=math.abs(p.x-s.path[i-1].x),math.abs(p.y-s.path[i-1].y)
            if dx>1 or dy>1 or dx+dy==0 then return false,'nonadjacent waypoint' end
        end
    end
    if count~=#s.path then return false,'incomplete waypoint list' end
    local x,y=center(s.path[s.index])
    if s.expected_x~=x or s.expected_y~=y then return false,'waypoint target mismatch' end
    return true
end

function M.begin(controller_id,army_id,site_id,goal_x,goal_y,path)
    assert(integer(controller_id) and integer(army_id) and integer(site_id)
        and integer(goal_x) and integer(goal_y) and type(path)=='table' and #path>=3,
        'invalid steering request')
    local copy={}
    for i,p in ipairs(path) do
        assert(integer(p.x) and integer(p.y), 'invalid waypoint')
        if i>1 then
            local dx,dy=math.abs(p.x-path[i-1].x),math.abs(p.y-path[i-1].y)
            assert(dx<=1 and dy<=1 and dx+dy>0, 'nonadjacent waypoint')
        end
        copy[i]={x=p.x,y=p.y}
    end
    local tx,ty=center(copy[2])
    return {version=1,controller_id=controller_id,army_id=army_id,site_id=site_id,
        original_x=goal_x,original_y=goal_y,path=copy,index=2,
        expected_x=tx,expected_y=ty,state='steering'}, {x=tx,y=ty}
end

-- obs = {controller_present, army_present, site_id, goal_x, goal_y,
--        army_x, army_y, mission_ended}. No command means do not change DF.
function M.step(s,obs)
    local valid,err=M.validate(s);assert(valid,err)
    if not obs.controller_present or obs.site_id~=s.site_id or obs.mission_ended then
        s.state='ended';return nil,'mission changed'
    end
    if obs.goal_x~=s.expected_x or obs.goal_y~=s.expected_y then
        s.state='ended';return nil,'controller changed externally'
    end
    if not obs.army_present then return nil,'waiting for army' end
    if math.abs(obs.army_x-s.expected_x)>1 or math.abs(obs.army_y-s.expected_y)>1 then
        return nil,'traveling'
    end
    s.index=s.index+1
    -- Restore the actual destination before entering its world tile. DF may
    -- resolve the mission before an artificial tile-center is reached.
    if s.index>=#s.path then
        s.state='complete';return {x=s.original_x,y=s.original_y},'destination restored'
    end
    local x,y=center(s.path[s.index]);s.expected_x=x;s.expected_y=y
    return {x=x,y=y},'next waypoint'
end

function M.cancel(s,obs)
    local valid,err=M.validate(s);assert(valid,err)
    s.state='cancelled'
    if obs.controller_present and obs.site_id==s.site_id and
       obs.goal_x==s.expected_x and obs.goal_y==s.expected_y and not obs.mission_ended then
        return {x=s.original_x,y=s.original_y}
    end
end
return M
