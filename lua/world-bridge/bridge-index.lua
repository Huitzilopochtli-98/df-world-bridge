-- Graph of completed projects. The caller must verify that corresponding
-- native construction records still exist before allowing their use.
local project=require('world-bridge.project')
local M={}
local function point(x,y) return x..','..y end
local function edge(ax,ay,bx,by) return point(ax,ay)..'>'..point(bx,by) end
function M.build(registry,verify)
    assert(type(registry)=='table' and type(verify)=='function')
    local tiles,edges,count={},{},0
    for _,entry in ipairs(registry.projects) do
        local p=entry.project
        assert(project.validate(p))
        if p.state=='complete' and verify(p) then
            count=count+1
            for i,t in ipairs(p.path) do
                if i>1 and i<#p.path then tiles[point(t.x,t.y)]=true end
                if i>1 then
                    local a=p.path[i-1]
                    edges[edge(a.x,a.y,t.x,t.y)]=true
                    edges[edge(t.x,t.y,a.x,a.y)]=true
                end
            end
        end
    end
    return {
        count=count,
        tile=function(x,y) return not not tiles[point(x,y)] end,
        edge=function(ax,ay,bx,by) return not not edges[edge(ax,ay,bx,by)] end,
    }
end
return M
