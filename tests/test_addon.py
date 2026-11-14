"""Run actual addon Lua in Lua 5.1; the WoW host is replaced only at the API boundary."""
from pathlib import Path
import unittest
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

# Release 0.1.2 compatibility checks; later layout experiments are not part of
# this baseline suite.

class CoreTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.ns = self.lua.table()
        source = ROOT / 'Core.lua'
        self.assertTrue(source.exists(), 'Aura selection/arc core has not been implemented')
        self.lua.execute(source.read_text(), 'ForeverAuraOrbit', self.ns)

    def test_forms_discover_custom_auras_deduplicate_ranks_and_keep_latest(self):
        self.lua.globals().Core = self.ns.Core
        self.lua.execute('''
            local forms = {
                {spellID=465, name="Devotion Aura", icon=1, active=false},
                {spellID=10290, name="Devotion Aura", icon=2, active=true},
                {spellID=999001, name="Forever Custom Aura", icon=3, active=false},
            }
            local auras = Core.Collect(forms, function() return false end, function() end)
            assert(#auras == 2, "Known forms must include custom auras and deduplicate ranks")
            assert(auras[1].spellID == 10290 and auras[1].active, "Keep the last learned rank")
            assert(auras[2].spellID == 999001, "Do not hardcode the list of available forms")
        ''')

    def test_active_lower_rank_is_preserved_when_cast_rank_is_deduplicated(self):
        self.lua.globals().Core = self.ns.Core
        self.lua.execute('''
            local forms = {
                {spellID=465,name='Devotion Aura',active=true,icon=1},
                {spellID=10290,name='Devotion Aura',active=false,icon=2},
            }
            local auras=Core.Collect(forms)
            assert(#auras==1 and auras[1].spellID==10290)
            assert(auras[1].active, 'An active lower rank must retain the highlight')
            assert(not forms[2].active, 'Discovery must not mutate source records')
        ''')

    def test_fallback_only_returns_highest_known_rank_for_each_aura(self):
        self.lua.globals().Core = self.ns.Core
        self.lua.execute('''
            local known = { [465]=true, [10290]=true, [7294]=true, [19746]=true }
            local function info(id) return {name="spell"..id, icon=id} end
            local auras = Core.Collect({}, function(id) return known[id] end, info)
            assert(#auras == 3, "Fallback must omit unlearned auras")
            assert(auras[1].spellID == 10290, "Highest learned devotion rank required")
            assert(auras[2].spellID == 7294, "Learned retribution required")
            assert(auras[3].spellID == 19746, "Learned concentration required")
            assert(#Core.Collect({}, function() return false end, info) == 0)
        ''')

    def test_portrait_arc_layout_and_opening_origin(self):
        self.lua.globals().Core = self.ns.Core
        self.lua.execute("""
            for count=1,12 do
                local lastX,lastY
                for i=1,count do
                    local x,y=Core.Position(i,count,45,1,-65,26)
                    assert(x==x and y==y)
                    assert(math.sqrt(x*x+y*y)>=45-0.000001)
                    if lastX then assert(math.sqrt((x-lastX)^2+(y-lastY)^2)>=29) end
                    local sx,sy=Core.Position(i,count,45,0,-65,26)
                    assert(math.abs(sx-26*math.cos(math.rad(-65)))<0.000001)
                    assert(math.abs(sy-26*math.sin(math.rad(-65)))<0.000001)
                    lastX,lastY=x,y
                end
            end
        """)


    def test_frame_fitted_arc_clears_number_and_stops_before_bar(self):
        self.lua.globals().Core = self.ns.Core
        self.lua.execute('''
            local cases={
                {angle=-140, distance=34, half=12, bar=40}, -- screenshot-like left badge
                {angle=-65, distance=30, half=11, bar=35},
                {angle=-140, distance=34, half=12, bar=24},
            }
            for _,c in ipairs(cases) do
                local bx=c.distance*math.cos(math.rad(c.angle))
                local by=c.distance*math.sin(math.rad(c.angle))
                for count=1,12 do
                    local radius,first,last=Core.ArcLayout(count,48,c.angle,c.distance,c.half,17,c.bar,4)
                    assert(first<=-100 and first>=-170, 'Start on the lower-left, not in the bar')
                    assert(last>=-280, 'Stop above the portrait before wrapping into the bar')
                    if count>=5 and count<=7 then assert(radius<=85, 'Do not create a needlessly distant fan') end
                    for _,p in ipairs({0,0.1,0.25,0.5,0.75,1}) do
                        local previousX,previousY
                        for i=1,count do
                            local x,y=Core.Position(i,count,radius,p,first,radius,last)
                            assert(math.sqrt((x-bx)^2+(y-by)^2)>=c.half+17+4-0.000001,
                                'Aura artwork must clear the level badge')
                            assert(x+17+4<=c.bar+0.000001, 'Aura artwork must stop before the bar area')
                            if p==1 and previousX then
                                assert(math.sqrt((x-previousX)^2+(y-previousY)^2)>=30-0.000001,
                                    'Keep usable spacing between icons')
                            end
                            previousX,previousY=x,y
                        end
                    end
                end
            end
        ''')

class IntegrationTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute((ROOT/'tests/wow_host.lua').read_text())
        self.ns = self.lua.table()
        self.lua.execute((ROOT/'Core.lua').read_text(), 'ForeverAuraOrbit', self.ns)
        source = ROOT/'ForeverAuraOrbit.lua'
        self.assertTrue(source.exists(), 'Hover flyout addon has not been implemented')
        self.lua.execute(source.read_text(), 'ForeverAuraOrbit', self.ns)
        self.lua.execute("FireEvent('PLAYER_LOGIN')")

    def test_hover_opens_animated_clickable_known_auras(self):
        self.lua.execute('''
            assert(ForeverAuraOrbitTrigger and ForeverAuraOrbitPanel)
            assert(not ForeverAuraOrbitPanel:IsShown(), "Must start collapsed")
            ForeverAuraOrbitTrigger:Fire('OnEnter')
            assert(ForeverAuraOrbitPanel:IsShown(), "Hover must open panel")
            assert(ForeverAuraOrbitPanel.autoHide, "Must close when mouse leaves")
            assert(#ForeverAuraOrbitPanel.autoFrames == 4, "Full menu area tracks trigger and every icon")
            local b=ForeverAuraOrbitButton1
            assert(b:GetAttribute('type')=='spell' and b:GetAttribute('spell')==465)
            assert(b:GetAlpha()<1, "Opening must animate")
            ForeverAuraOrbitAnimator:Fire('OnUpdate',1)
            assert(b:GetAlpha()==1 and b.point[4]==b:GetAttribute('final-x'))
            assert(b.active:IsShown(), "Current aura is highlighted")
        ''')

    def test_combat_snaps_mid_animation_and_keeps_secure_hover_working(self):
        self.lua.execute('''
            ForeverAuraOrbitTrigger:Fire('OnEnter')
            ForeverAuraOrbitAnimator:Fire('OnUpdate',0.02)
            SetCombat(true)
            ForeverAuraOrbitAnimator:Fire('OnUpdate',0.02)
            local b=ForeverAuraOrbitButton1
            assert(b:GetAlpha()==1, "Combat transition must finish animation securely")
            assert(b.point[4]==b:GetAttribute('final-x') and b.point[5]==b:GetAttribute('final-y'))
            Secure=true; ForeverAuraOrbitPanel:Hide(); Secure=false
            ForeverAuraOrbitTrigger:Fire('OnEnter')
            assert(ForeverAuraOrbitPanel:IsShown(), "Combat must allow secure hover")
            assert(b:GetAttribute('spell')==465)
            Forms[#Forms+1]={19876,'Shadow Resistance Aura',104,false}
            FireEvent('SPELLS_CHANGED')
            assert(ForeverAuraOrbitPanel:GetAttribute('count')==3, "Learning rebuild deferred in combat")
            SetCombat(false)
            assert(ForeverAuraOrbitPanel:GetAttribute('count')==4, "Deferred rebuild after combat")
            assert(ForeverAuraOrbitButton4:GetAttribute('spell')==19876)
        ''')

    def test_interrupted_reopening_registers_final_not_intermediate_hit_rectangles(self):
        self.lua.execute('''
            ForeverAuraOrbitTrigger:Fire('OnEnter')
            ForeverAuraOrbitAnimator:Fire('OnUpdate',0.02)
            ForeverAuraOrbitPanel:Hide()
            ForeverAuraOrbitTrigger:Fire('OnEnter')
            local p=ForeverAuraOrbitPanel.autoPoints[2]
            local b=ForeverAuraOrbitButton1
            assert(p[4]==b:GetAttribute('final-x') and p[5]==b:GetAttribute('final-y'),
                'Auto-hide snapshots must match the final clickable positions')
        ''')

    def test_secure_anchors_use_owner_frames_with_scaled_region_offsets(self):
        self.lua.execute('''
            local portrait=PlayerFrame.PlayerFrameContainer.PlayerPortrait
            local level=PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.LevelBackgroundCircle
            local portraitOwner=CreateFrame('Frame',nil,PlayerFrame)
            portraitOwner.cx,portraitOwner.cy=200,100
            portraitOwner.GetEffectiveScale=function() return 0.5 end
            portrait.parent=portraitOwner
            portrait.cx,portrait.cy=230,110
            portrait.GetEffectiveScale=false
            local levelOwner=CreateFrame('Frame',nil,PlayerFrame)
            levelOwner.cx,levelOwner.cy=100,50
            levelOwner.GetEffectiveScale=function() return 2 end
            level.parent=levelOwner
            level.cx,level.cy=108,43
            level.GetEffectiveScale=false
            PlayerLevelText.parent=levelOwner
            PlayerLevelText.cx,PlayerLevelText.cy=108,43
            PlayerLevelText.GetEffectiveScale=false
            SlashCmdList.FOREVERAURAORBIT('refresh')
            local rootPoint=ForeverAuraOrbitRoot.point
            assert(rootPoint[2]==portraitOwner, 'Secure root must anchor to Frame, never Texture')
            assert(rootPoint[4]==15 and rootPoint[5]==5, 'Portrait center must respect owner scale')
            local triggerPoint=ForeverAuraOrbitTrigger.point
            assert(triggerPoint[2]==levelOwner, 'Secure trigger must anchor to Frame, never badge Texture')
            assert(triggerPoint[4]==16 and triggerPoint[5]==-14, 'Level hitbox must respect owner scale')
            assert(ForeverAuraOrbitPanel:GetAttribute('count')==3, 'Initialization must reach aura discovery')
        ''')

    def test_concentration_uses_spell_texture_instead_of_wrong_stance_texture(self):
        self.lua.execute('''
            Forms[3][3]=136116 -- Actual raw stance icon reported by this Forever client.
            C_Spell.GetSpellTexture=function(id) if id==19746 then return 135933 end end
            SlashCmdList.FOREVERAURAORBIT('refresh')
            assert(ForeverAuraOrbitButton3.icon.texture==135933,
                'Concentration must match its spell icon, not the inconsistent stance icon')
            assert(ForeverAuraOrbitButton1.icon.texture==101, 'Missing spell textures must fall back')
        ''')

    def test_player_aura_changes_move_marker_without_rebuilding_combat_buttons(self):
        self.lua.execute('''
            ForeverAuraOrbitTrigger:Fire('OnEnter')
            ForeverAuraOrbitAnimator:Fire('OnUpdate',1)
            SetCombat(true)
            local originalPoint=ForeverAuraOrbitButton3.point
            Forms[1][4],Forms[3][4]=false,true
            FireEvent('UNIT_AURA','target')
            assert(ForeverAuraOrbitButton1.active:IsShown(), 'Ignore other units')
            FireEvent('UNIT_AURA','player')
            assert(not ForeverAuraOrbitButton1.active:IsShown(), 'Old aura marker must clear')
            assert(ForeverAuraOrbitButton3.active:IsShown(), 'Concentration must gain the marker')
            assert(ForeverAuraOrbitPanel:IsShown(), 'Selection updates must not collapse the menu')
            assert(ForeverAuraOrbitButton3.point==originalPoint, 'No protected layout mutation')
            Forms[3][4],Forms[2][4]=false,true
            FireEvent('UPDATE_SHAPESHIFT_USABLE')
            assert(ForeverAuraOrbitButton2.active:IsShown() and not ForeverAuraOrbitButton3.active:IsShown())
        ''')

    def test_confirmed_selection_pulses_only_new_active_aura_without_moving_buttons(self):
        self.lua.execute('''
            ForeverAuraOrbitTrigger:Fire('OnEnter')
            ForeverAuraOrbitAnimator:Fire('OnUpdate',1)
            local b=ForeverAuraOrbitButton3
            assert(b.pulseAnimation, 'Selection needs a cosmetic pulse animation')
            assert((b.pulseAnimation.playCount or 0)==0, 'Opening is not a new aura activation')
            SetCombat(true)
            local originalPoint=b.point
            Forms[1][4],Forms[3][4]=false,true
            FireEvent('UPDATE_SHAPESHIFT_FORM')
            assert(b.pulseAnimation.playCount==1, 'Pulse after confirmed activation')
            assert(b.pulseAnimation.animations[1].fromAlpha==1)
            assert(b.pulseAnimation.animations[1].toAlpha==0)
            assert(b.pulseAnimation.animations[1].duration==0.35)
            FireEvent('UNIT_AURA','player')
            assert(b.pulseAnimation.playCount==1, 'Duplicate events must not replay the pulse')
            ForeverAuraOrbitButton2:Fire('PostClick','LeftButton',false)
            assert(b.active:IsShown() and not ForeverAuraOrbitButton2.active:IsShown(),
                'Failed or unconfirmed clicks must not change active state')
            assert(b.point==originalPoint, 'Pulse must never move a protected hitbox')
            Forms[3][4]=false
            FireEvent('UPDATE_SHAPESHIFT_FORM')
            assert(not b.active:IsShown() and not b.pulseAnimation:IsPlaying(),
                'Toggling the aura off clears the marker and pulse')
        ''')

    def test_screenshot_layout_clears_level_badge_and_live_bar_bounds(self):
        self.lua.execute('''
            Forms[#Forms+1]={19876,'Shadow Resistance Aura',104,false}
            Forms[#Forms+1]={19888,'Frost Resistance Aura',105,false}
            Forms[#Forms+1]={19891,'Fire Resistance Aura',106,false}
            local level=PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.LevelBackgroundCircle
            level.cx,level.cy=74,78
            PlayerLevelText.cx,PlayerLevelText.cy=74,78
            local health=CreateFrame('Frame',nil,PlayerFrame)
            health.cx,health.cy,health.w,health.h=200,105,120,14
            PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer={HealthBar=health}
            local function check()
                local left=health:GetRect()
                local lx,ly=ForeverAuraOrbitTrigger:GetCenter()
                for i=1,ForeverAuraOrbitPanel:GetAttribute('count') do
                    local b=_G['ForeverAuraOrbitButton'..i]
                    local x,y=b:GetCenter()
                    assert(math.sqrt((x-lx)^2+(y-ly)^2)>=11+17+4-0.000001,
                        'Aura outline must not intersect the level badge')
                    assert(x+17+4<=left+0.000001, 'Arc must end before the health/name bar area')
                end
            end
            SlashCmdList.FOREVERAURAORBIT('refresh')
            ForeverAuraOrbitTrigger:Fire('OnEnter')
            check()
            for step=1,6 do ForeverAuraOrbitAnimator:Fire('OnUpdate',0.04); check() end
            SetCombat(true); check()
            SetCombat(false)
            health.cx=180 -- tighter frame geometry must adjust the endpoint
            SlashCmdList.FOREVERAURAORBIT('refresh')
            ForeverAuraOrbitTrigger:Fire('OnEnter')
            ForeverAuraOrbitAnimator:Fire('OnUpdate',1)
            check()
        ''')

    def test_missing_health_bar_fallback_fits_scaled_portrait_clearance(self):
        self.lua.execute('''
            Forms[#Forms+1]={19876,'Shadow Resistance Aura',104,false}
            Forms[#Forms+1]={19888,'Frost Resistance Aura',105,false}
            Forms[#Forms+1]={19891,'Fire Resistance Aura',106,false}
            local main=PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
            main.HealthBarsContainer=nil
            PlayerFrame.healthbar,PlayerFrameHealthBar=nil,nil
            PlayerName,PlayerFrame.name=nil,nil
            local portrait=PlayerFrame.PlayerFrameContainer.PlayerPortrait
            local portraitOwner=CreateFrame('Frame',nil,PlayerFrame)
            portraitOwner.cx,portraitOwner.cy=180,190
            portraitOwner.GetEffectiveScale=function() return 0.5 end
            portrait.parent=portraitOwner
            portrait.cx,portrait.cy,portrait.w=200,200,60
            local level=main.LevelBackgroundCircle
            local levelOwner=CreateFrame('Frame',nil,PlayerFrame)
            levelOwner.GetEffectiveScale=function() return 2 end
            level.parent,PlayerLevelText.parent=levelOwner,levelOwner
            level.cx,level.cy=37,39
            PlayerLevelText.cx,PlayerLevelText.cy=37,39
            PlayerLevelText.w,PlayerLevelText.h=9,7
            level.GetEffectiveScale,PlayerLevelText.GetEffectiveScale=false,false
            -- Exercise both region scale and Texture parent-scale fallback.
            for _,hasRegionScale in ipairs({true,false}) do
                portrait.GetEffectiveScale=hasRegionScale and
                    function() return 0.5 end or false
                SlashCmdList.FOREVERAURAORBIT('refresh')
                local root=ForeverAuraOrbitRoot
                assert(root:GetEffectiveScale()==1, 'Root scale must differ from portrait and badge')
                local rx,ry=root:GetCenter()
                assert(math.abs(rx-100)<0.000001 and math.abs(ry-100)<0.000001,
                    'Root must stay at the scaled portrait center')
                assert(ForeverAuraOrbitPanel:GetAttribute('count')==6, 'Fit all six auras')
                local barLeft=portrait:GetWidth()*0.5/root:GetEffectiveScale()/2+6
                assert(barLeft==21, 'Fallback boundary must be in root coordinates')
                local badgeHalf=math.sqrt(18*18+14*14)/2+2
                local function check()
                    for i=1,6 do
                        local b=_G['ForeverAuraOrbitButton'..i]
                        local x,y=b:GetCenter()
                        assert(x-rx+17+4<=barLeft+0.000001,
                            'Scaled missing-bar fallback must clear every aura outline plus gap')
                        assert(math.sqrt((x-74)^2+(y-78)^2)>=badgeHalf+17+4-0.000001,
                            'Fitted arc must also clear the differently scaled level badge')
                    end
                end
                check()
                ForeverAuraOrbitTrigger:Fire('OnEnter')
                check()
                for step=1,6 do ForeverAuraOrbitAnimator:Fire('OnUpdate',0.04); check() end
                SetCombat(true); check()
                SetCombat(false)
            end
        ''')

    def test_missing_number_geometry_defers_instead_of_reusing_fitted_radius(self):
        self.lua.execute('''
            PlayerLevelText.GetCenter=function() return nil,nil end
            SlashCmdList.FOREVERAURAORBIT('refresh')
            assert(not ForeverAuraOrbitTrigger:IsShown(), 'Wait for number geometry before placing the arc')
            PlayerLevelText.GetCenter=nil
            FireEvent('PLAYER_ENTERING_WORLD')
            assert(ForeverAuraOrbitTrigger:IsShown(), 'Rebuild when geometry becomes available')
        ''')

    def test_texture_regions_without_frame_scale_methods_are_supported(self):
        self.lua.execute('''
            PlayerFrame.PlayerFrameContainer.PlayerPortrait.GetEffectiveScale=false
            PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.LevelBackgroundCircle.GetEffectiveScale=false
            SlashCmdList.FOREVERAURAORBIT('refresh')
            assert(ForeverAuraOrbitPanel:GetAttribute('count')==3)
        ''')

if __name__ == '__main__':
    unittest.main(verbosity=2)
