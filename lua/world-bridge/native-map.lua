-- Native rendering must never interpret the planner's clicks as game orders.
local M={}
local buttons={'mouse_lbut','mouse_rbut','mouse_mbut','mouse_lbut_down','mouse_rbut_down','mouse_mbut_down'}
function M.without_mouse(fn)
    local g,e=df.global.gps,df.global.enabler
    local pointer={g.mouse_x,g.mouse_y,g.precise_mouse_x,g.precise_mouse_y}
    local saved={tracking_on=e.tracking_on}
    for _,name in ipairs(buttons) do saved[name]=e[name];e[name]=0 end
    g.mouse_x,g.mouse_y,g.precise_mouse_x,g.precise_mouse_y=-1,-1,-1,-1
    e.tracking_on=0
    local ok,result=pcall(fn)
    g.mouse_x,g.mouse_y,g.precise_mouse_x,g.precise_mouse_y=table.unpack(pointer)
    for _,name in ipairs(buttons) do e[name]=saved[name] end
    e.tracking_on=saved.tracking_on
    if not ok then error(result) end
    return result
end
return M
