-- Experimental standalone marker view for copied saves only.
-- This is not wired into the scheduler and does not support world-map zoom.
local gui=require('gui')
local adapter=require('world-bridge.df-adapter')
local store=require('world-bridge.store')
local construction=require('world-bridge.construction')
local markers=require('world-bridge.markers')
local env=adapter.environment()
local s=dfhack.gui.getDFViewscreen(true)
if not s or s._type~=df.viewscreen_worldst or s.view_mode~=df.world_view_mode_type.NORMAL then
    qerror('Open the normal fortress world map first.')
end
local entries=markers.markers(store.load(env.persistent),function(p)return construction.verify(env.world,p) end)
BridgeMarkers=defclass(BridgeMarkers,gui.ZScreen)
BridgeMarkers.ATTRS{focus_path='world-bridge-markers-experiment',defocusable=false}
function BridgeMarkers:onInput(keys)
    self:sendInputToParent(keys)
    local current=dfhack.gui.getDFViewscreen(true)
    if not current or current._type~=df.viewscreen_worldst then self:dismiss() end
    return true
end
function BridgeMarkers:render(dc)
    self:renderParent()
    local screen=dfhack.gui.getDFViewscreen(true)
    if not screen or screen._type~=df.viewscreen_worldst or
        screen.view_mode~=df.world_view_mode_type.NORMAL or screen.focus_site then return end
    local g=df.global.gps;local port=g.main_map_port
    if not port or not port.flag.active then return end
    local p={x=port.top_left_corner_x,y=port.top_left_corner_y,width=port.dim_x,height=port.dim_y}
    local text={width=g.tile_pixel_x,height=g.tile_pixel_y,cols=g.dimx,rows=g.dimy}
    for _,m in ipairs(entries) do
        local x,y=markers.project(m,{x=screen.region_cent_x,y=screen.region_cent_y},p,text)
        -- The native UI occupies the right-hand edge; omit overlapping markers.
        if x and x*text.width<p.x+p.width*12 then
            dc:seek(x,y):char(m.ch,{fg=COLOR_YELLOW,keep_lower=true})
        end
    end
end
view=BridgeMarkers():show()
print(('World Bridge experimental view: %d verified bridge tiles.'):format(#entries))
