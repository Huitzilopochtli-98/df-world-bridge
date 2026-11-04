-- Own only NEARBY bits that this mod changed from false. Save ownership
-- before changing flags, and roll both back if either operation fails.
local M={KEY='world-bridge/trade-access-v1'}
local function integer(n)return type(n)=='number' and n>=0 and n==math.floor(n) and n<1e15 end
local function validate(d)
    assert(type(d)=='table' and d.version==1 and integer(d.site_id) and type(d.owned)=='table','invalid trade access ledger')
    local seen={};local count=0
    for k,id in pairs(d.owned) do
        assert(integer(k) and k>=1 and k<=#d.owned and integer(id) and not seen[id],'invalid trade access ownership')
        seen[id]=true;count=count+1
    end
    assert(count==#d.owned,'incomplete trade access ownership')
    return d
end
function M.load(env)
    return validate(env.persistent.getWorldData(M.KEY,{version=1,site_id=env.site_id,owned={}}))
end
local function same(a,b)
    if a.site_id~=b.site_id or #a.owned~=#b.owned then return false end
    for i,id in ipairs(a.owned) do if b.owned[i]~=id then return false end end
    return true
end
function M.update(env,desired)
    assert(integer(env.site_id) and type(desired)=='table','invalid trade access environment')
    local previous=M.load(env)
    local next_data={version=1,site_id=env.site_id,owned={}}
    local owned,changes={},{ }
    for id,enabled in pairs(desired) do assert(integer(id) and enabled==true,'invalid desired civilization') end
    local function current(id)
        local value=env.get(id)
        assert(value==nil or type(value)=='boolean','invalid native neighbor value')
        return value
    end
    if previous.site_id==env.site_id then
        for _,id in ipairs(previous.owned) do
            owned[id]=true
            local value=current(id)
            if value~=nil then
                if desired[id] then
                    next_data.owned[#next_data.owned+1]=id
                    if not value then changes[#changes+1]={id=id,old=false,value=true} end
                elseif value then changes[#changes+1]={id=id,old=true,value=false} end
            end
        end
    end
    -- A new fort has freshly calculated native neighbors. Drop the old
    -- fort's ownership without clearing any flag in the new fort's scope.
    for id in pairs(desired) do
        if not owned[id] and current(id)==false then
            next_data.owned[#next_data.owned+1]=id
            changes[#changes+1]={id=id,old=false,value=true}
        end
    end
    table.sort(next_data.owned);table.sort(changes,function(a,b)return a.id<b.id end)
    if same(previous,next_data) and #changes==0 then return {owned=#next_data.owned,added=0,restored=0} end
    validate(next_data)
    local applied=0
    local ok,err=pcall(function()
        env.persistent.saveWorldData(M.KEY,next_data)
        for i,c in ipairs(changes) do applied=i;env.set(c.id,c.value) end
    end)
    if not ok then
        local failures={}
        for i=applied,1,-1 do
            local c=changes[i];local restored,why=pcall(env.set,c.id,c.old)
            if not restored then failures[#failures+1]=tostring(why) end
        end
        local restored,why=pcall(env.persistent.saveWorldData,M.KEY,previous)
        if not restored then failures[#failures+1]=tostring(why) end
        if #failures>0 then
            if env.pause then env.pause() end
            error(tostring(err)..'; trade access rollback requires attention: '..table.concat(failures,'; '))
        end
        error('Trade access rolled back: '..tostring(err))
    end
    local result={owned=#next_data.owned,added=0,restored=0}
    for _,c in ipairs(changes) do local k=c.value and 'added' or 'restored';result[k]=result[k]+1 end
    return result
end
return M
