-- Experimental marker geometry for the unzoomed fortress world map.
local M={}
function M.markers(registry,verify)
    local result={}
    for _,entry in ipairs(registry.projects) do
        local p=entry.project
        if p.state=='complete' and verify(p) then
            for i=2,#p.path-1 do
                local a,t,b=p.path[i-1],p.path[i],p.path[i+1]
                local ch=a.y==t.y and b.y==t.y and '=' or
                    (a.x==t.x and b.x==t.x and '|' or '+')
                result[#result+1]={x=t.x,y=t.y,ch=ch,project_id=p.id}
            end
        end
    end
    return result
end
-- Map tiles are 16 pixels in this tested world-map view. Text tiles use
-- independent pixel dimensions; the caller supplies the live viewport.
function M.project(marker,center,port,text)
    if port.width<=0 or port.height<=0 or text.width<=0 or text.height<=0 then return nil end
    local px=port.x+port.width*8+(marker.x-center.x)*16
    local py=port.y+port.height*8+(marker.y-center.y)*16
    if px<port.x or py<port.y or px>=port.x+port.width*16 or py>=port.y+port.height*16 then return nil end
    local x,y=math.floor(px/text.width),math.floor(py/text.height)
    if x<0 or y<0 or x>=text.cols or y>=text.rows then return nil end
    return x,y
end
return M
