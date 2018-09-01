if myHero.charName ~= "Annie" then return end

-- [ update ]
do
      
    local Version = 1
    
    local Files = {
          Lua = {
                Path = SCRIPT_PATH,
                Name = "Annie.lua",
                Url = "https://raw.githubusercontent.com/miragessee/GoSAnnie/master/Annie.lua"
          },
          Version = {
                Path = SCRIPT_PATH,
                Name = "miragesannie.version",
                Url = "https://raw.githubusercontent.com/miragessee/GoSAkali/master/miragesannie.version"
          }
    }
    
    local function AutoUpdate()
          
          local function DownloadFile(url, path, fileName)
                DownloadFileAsync(url, path .. fileName, function() end)
                while not FileExist(path .. fileName) do end
          end
          
          local function ReadFile(path, fileName)
                local file = io.open(path .. fileName, "r")
                local result = file:read()
                file:close()
                return result
          end
          
          DownloadFile(Files.Version.Url, Files.Version.Path, Files.Version.Name)
          
          local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name)) 
          if NewVersion > Version then
                DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
                print(Files.Version.Name .. ": Updated to " .. tostring(NewVersion) .. ". Please Reload with 2x F6")
          else
                print(Files.Version.Name .. ": No Updates Found")
          end
          
    end
    
    AutoUpdate()
    
end

local _atan = math.atan2
local _min = math.min
local _abs = math.abs
local _sqrt = math.sqrt
local _floor = math.floor
local _max = math.max
local _pow = math.pow
local _huge = math.huge
local _pi = math.pi
local _insert = table.insert
local _contains = table.contains
local _sort = table.sort
local _pairs = pairs
local _find = string.find
local _sub = string.sub
local _len = string.len

local LocalDrawLine = Draw.Line;
local LocalDrawColor = Draw.Color;
local LocalDrawCircle = Draw.Circle;
local LocalDrawCircleMinimap = Draw.CircleMinimap;
local LocalDrawText = Draw.Text;
local LocalControlIsKeyDown = Control.IsKeyDown;
local LocalControlMouseEvent = Control.mouse_event;
local LocalControlSetCursorPos = Control.SetCursorPos;
local LocalControlCastSpell = Control.CastSpell;
local LocalControlKeyUp = Control.KeyUp;
local LocalControlKeyDown = Control.KeyDown;
local LocalControlMove = Control.Move;
local LocalGetTickCount = GetTickCount;
local LocalGamecursorPos = Game.cursorPos;
local LocalGameCanUseSpell = Game.CanUseSpell;
local LocalGameLatency = Game.Latency;
local LocalGameTimer = Game.Timer;
local LocalGameHeroCount = Game.HeroCount;
local LocalGameHero = Game.Hero;
local LocalGameMinionCount = Game.MinionCount;
local LocalGameMinion = Game.Minion;
local LocalGameTurretCount = Game.TurretCount;
local LocalGameTurret = Game.Turret;
local LocalGameWardCount = Game.WardCount;
local LocalGameWard = Game.Ward;
local LocalGameObjectCount = Game.ObjectCount;
local LocalGameObject = Game.Object;
local LocalGameMissileCount = Game.MissileCount;
local LocalGameMissile = Game.Missile;
local LocalGameParticleCount = Game.ParticleCount;
local LocalGameParticle = Game.Particle;
local LocalGameIsChatOpen = Game.IsChatOpen;
local LocalGameIsOnTop = Game.IsOnTop;

function GetMode()
    if _G.SDK then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
            return "Clear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
            return "Flee"
        end
    else
        return GOS.GetMode()
    end
end

function IsReady(spell)
    return Game.CanUseSpell(spell) == 0
end

function ValidTarget(target, range)
    range = range and range or math.huge
    return target ~= nil and target.valid and target.visible and not target.dead and target.distance <= range
end

function GetDistance(p1, p2)
    return _sqrt(_pow((p2.x - p1.x), 2) + _pow((p2.y - p1.y), 2) + _pow((p2.z - p1.z), 2))
end

function GetDistance2D(p1, p2)
    return _sqrt(_pow((p2.x - p1.x), 2) + _pow((p2.y - p1.y), 2))
end

local _OnWaypoint = {}
function OnWaypoint(unit)
    if _OnWaypoint[unit.networkID] == nil then _OnWaypoint[unit.networkID] = {pos = unit.posTo, speed = unit.ms, time = LocalGameTimer()} end
    if _OnWaypoint[unit.networkID].pos ~= unit.posTo then
        _OnWaypoint[unit.networkID] = {startPos = unit.pos, pos = unit.posTo, speed = unit.ms, time = LocalGameTimer()}
        DelayAction(function()
            local time = (LocalGameTimer() - _OnWaypoint[unit.networkID].time)
            local speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos, unit.pos) / (LocalGameTimer() - _OnWaypoint[unit.networkID].time)
            if speed > 1250 and time > 0 and unit.posTo == _OnWaypoint[unit.networkID].pos and GetDistance(unit.pos, _OnWaypoint[unit.networkID].pos) > 200 then
                _OnWaypoint[unit.networkID].speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos, unit.pos) / (LocalGameTimer() - _OnWaypoint[unit.networkID].time)
            end
        end, 0.05)
    end
    return _OnWaypoint[unit.networkID]
end

function VectorPointProjectionOnLineSegment(v1, v2, v)
    local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
    local pointLine = {x = ax + rL * (bx - ax), y = ay + rL * (by - ay)}
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or {x = ax + rS * (bx - ax), y = ay + rS * (by - ay)}
    return pointSegment, pointLine, isOnSegment
end

function GetMinionCollision(StartPos, EndPos, Width, Target)
    local Count = 0
    for i = 1, LocalGameMinionCount() do
        local m = LocalGameMinion(i)
        if m and not m.isAlly then
            local w = Width + m.boundingRadius
            local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(StartPos, EndPos, m.pos)
            if isOnSegment and GetDistanceSqr(pointSegment, m.pos) < w ^ 2 and GetDistanceSqr(StartPos, EndPos) > GetDistanceSqr(StartPos, m.pos) then
                Count = Count + 1
            end
        end
    end
    return Count
end

function GetDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx ^ 2 + dz ^ 2
end

function GetEnemyHeroes()
    EnemyHeroes = {}
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isEnemy then
            table.insert(EnemyHeroes, Hero)
        end
    end
    return EnemyHeroes
end

--[[ str = "This is some text containing the word tiger."
if str:match("tiger") then
print ("The word tiger was found.")
else
print ("The word tiger was not found.")
end
]]
function GetGameObjects()
    EnemyHeroes = {}
    for i = 1, Game.ObjectCount() do
        local GameObject = Game.Object(i)
        --if GameObject.name:match("Tibbers") then
        --    print(GameObject.name)
        --end
        --if GameObject.charName:match("Tibbers") then
        --print(GameObject.name)
        --end
        if GameObject.name == "Tibbers" then
            print(GetDistance(myHero.pos, GameObject.pos))
        end
    end
    return EnemyHeroes
end

function IsUnderTurret(unit)
    for i = 1, Game.TurretCount() do
        local turret = Game.Turret(i);
        if turret and turret.isEnemy and turret.valid and turret.health > 0 then
            if GetDistance(unit, turret.pos) <= 850 then
                return true
            end
        end
    end
    return false
end

function GetDashPos(unit)
    return myHero.pos + (unit.pos - myHero.pos):Normalized() * 500
end

function GetSpellEName()
    return myHero:GetSpellData(_E).name
end

function GetSpellRName()
    return myHero:GetSpellData(_R).name
end

function QDmg()
    local Dmg1 = (({80, 115, 150, 185, 220})[myHero:GetSpellData(_Q).level] + 0.8 * myHero.ap)
    return Dmg1
end

function WDmg()
    local Dmg1 = (({70, 115, 160, 205, 250})[myHero:GetSpellData(_W).level] + 0.85 * myHero.ap)
    return Dmg1
end

function RDmg()
    local Dmg1 = (({150, 275, 400})[myHero:GetSpellData(_R).level] + 0.65 * myHero.ap)
    return Dmg1
end

function GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then
            return buff.count
        end
    end
    return 0
end

function IsRecalling()
    for K, Buff in pairs(GetBuffs(myHero)) do
        if Buff.name == "recall" and Buff.duration > 0 then
            return true
        end
    end
    return false
end

function SetMovement(bool)
    if _G.EOWLoaded then
        EOW:SetMovements(bool)
        EOW:SetAttacks(bool)
    elseif _G.SDK then
        _G.SDK.Orbwalker:SetMovement(bool)
        _G.SDK.Orbwalker:SetAttack(bool)
    else
        GOS.BlockMovement = not bool
        GOS.BlockAttack = not bool
    end
end

function EnableMovement()
    SetMovement(true)
end

function ReturnCursor(pos)
    Control.SetCursorPos(pos)
    DelayAction(EnableMovement, 0.1)
end

function RightClick(pos)
    Control.mouse_event(MOUSEEVENTF_RIGHTDOWN)
    Control.mouse_event(MOUSEEVENTF_RIGHTUP)
    DelayAction(ReturnCursor, 0.05, {pos})
end

function IsImmune(unit)
    if type(unit) ~= "userdata" then error("{IsImmune}: bad argument #1 (userdata expected, got " .. type(unit) .. ")") end
    for i, buff in pairs(GetBuffs(unit)) do
        if (buff.name == "KindredRNoDeathBuff" or buff.name == "UndyingRage") and GetPercentHP(unit) <= 10 then
            return true
        end
        if buff.name == "VladimirSanguinePool" or buff.name == "JudicatorIntervention" then
            return true
        end
    end
    return false
end

function TestBuff(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            print(buff.name)
        end
    end
    print("No buff")
end

class "Annie"

local HeroIcon = "https://www.mobafire.com/images/champion/square/annie.png"
local IgniteIcon = "http://pm1.narvii.com/5792/0ce6cda7883a814a1a1e93efa05184543982a1e4_hq.jpg"
local PassiveIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/28/Pyromania.png"
local QIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/25/Disintegrate.png"
local WIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/21/Incinerate.png"
local EIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/90/Molten_Shield.png"
local RIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e7/Summon-_Tibbers.png"
local BCIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/44/Bilgewater_Cutlass_item.png/revision/latest"
local HGIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/64/Hextech_Gunblade_item.png"
local TibbersIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/cf/Annie_Summon_Tibbers_Render.png"
local IS = {}

function VectorPointProjectionOnLineSegment(v1, v2, v)
    local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
    local pointLine = {x = ax + rL * (bx - ax), y = ay + rL * (by - ay)}
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or {x = ax + rS * (bx - ax), y = ay + rS * (by - ay)}
    return pointSegment, pointLine, isOnSegment
end

local Version, Author, LVersion = "v1", "miragessee", "8.17"

function Annie:LoadMenu()
    
    self.Collision = nil
    
    self.CollisionSpellName = nil
    
    self.AnnieMenu = MenuElement({type = MENU, id = "Annie", name = "Mirage's Annie", leftIcon = HeroIcon})
    
    self.AnnieMenu:MenuElement({id = "Tibbers", name = "Tibbers", type = MENU})
    self.AnnieMenu.Tibbers:MenuElement({id = "UseTibbers", name = "Tibbers attack least health enemy", value = true, leftIcon = TibbersIcon})
    self.AnnieMenu.Tibbers:MenuElement({id = "UseET", name = "Use E Tibbers attack least health enemy", value = true, leftIcon = EIcon})
    
    self.AnnieMenu:MenuElement({id = "LaneClear", name = "LaneClear", type = MENU})
    self.AnnieMenu.LaneClear:MenuElement({id = "UseQ", name = "Use Q minion kill", value = true, leftIcon = QIcon})
    
    self.AnnieMenu:MenuElement({id = "Harass", name = "Harass", type = MENU})
    self.AnnieMenu.Harass:MenuElement({id = "UseQ", name = "Use Q", value = false, leftIcon = QIcon})
    self.AnnieMenu.Harass:MenuElement({id = "UseW", name = "Use W", value = false, leftIcon = WIcon})
    self.AnnieMenu.Harass:MenuElement({id = "UseQM", name = "Use Q is minion kill", value = true, leftIcon = QIcon})
    self.AnnieMenu.Harass:MenuElement({id = "UseQS", name = "Use Q is enemy Only Stun", value = true, leftIcon = QIcon})
    self.AnnieMenu.Harass:MenuElement({id = "UseRS", name = "Use R is enemy Only Stun", value = true, leftIcon = RIcon})
    self.AnnieMenu.Harass:MenuElement({id = "UseER", name = "Use E is R attack", value = true, leftIcon = EIcon})
    self.AnnieMenu.Harass:MenuElement({id = "UseBC", name = "Use Bilgewater Cutlass", value = true, leftIcon = BCIcon})
    self.AnnieMenu.Harass:MenuElement({id = "UseHG", name = "Use Hextech Gunblade", value = true, leftIcon = HGIcon})
    
    self.AnnieMenu:MenuElement({id = "Combo", name = "Combo", type = MENU})
    self.AnnieMenu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true, leftIcon = QIcon})
    self.AnnieMenu.Combo:MenuElement({id = "UseW", name = "Use W", value = true, leftIcon = WIcon})
    self.AnnieMenu.Combo:MenuElement({id = "UseR", name = "Use R", value = true, leftIcon = RIcon})
    self.AnnieMenu.Combo:MenuElement({id = "UseRS", name = "Use R is enemy Only Stun", value = true, leftIcon = RIcon})
    self.AnnieMenu.Combo:MenuElement({id = "UseER", name = "Use E is R attack", value = true, leftIcon = EIcon})
    self.AnnieMenu.Combo:MenuElement({id = "UseBC", name = "Use Bilgewater Cutlass", value = true, leftIcon = BCIcon})
    self.AnnieMenu.Combo:MenuElement({id = "UseHG", name = "Use Hextech Gunblade", value = true, leftIcon = HGIcon})
    
    self.AnnieMenu:MenuElement({id = "KillSteal", name = "KillSteal", type = MENU})
    self.AnnieMenu.KillSteal:MenuElement({id = "UseIgnite", name = "Use Ignite", value = true, leftIcon = IgniteIcon})
    
    self.AnnieMenu:MenuElement({id = "AutoLevel", name = "AutoLevel", type = MENU})
    self.AnnieMenu.AutoLevel:MenuElement({id = "AutoLevel", name = "Only Q->W->E", value = true})
    
    self.AnnieMenu:MenuElement({id = "AutoE", name = "AutoE", type = MENU})
    self.AnnieMenu.AutoE:MenuElement({id = "UseE", name = "Use E", value = true, leftIcon = EIcon})
    
    self.AnnieMenu:MenuElement({id = "AntiGapcloser", name = "AntiGapcloser", type = MENU})
    self.AnnieMenu.AntiGapcloser:MenuElement({id = "UseE", name = "Use E", value = true, leftIcon = EIcon})
    self.AnnieMenu.AntiGapcloser:MenuElement({id = "DistanceE", name = "Distance: E", value = 300, min = 25, max = 2000, step = 25})
    
    self.AnnieMenu:MenuElement({id = "Drawings", name = "Drawings", type = MENU})
    self.AnnieMenu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q Range", value = true})
    self.AnnieMenu.Drawings:MenuElement({id = "DrawW", name = "Draw W Range", value = true})
    self.AnnieMenu.Drawings:MenuElement({id = "DrawR", name = "Draw R Range", value = true})
    self.AnnieMenu.Drawings:MenuElement({id = "DrawAA", name = "Draw Killable AAs", value = false})
    self.AnnieMenu.Drawings:MenuElement({id = "DrawJng", name = "Draw Jungler Info", value = true})
    
    self.AnnieMenu:MenuElement({id = "blank", type = SPACE, name = ""})
    self.AnnieMenu:MenuElement({id = "blank", type = SPACE, name = "Script Ver: " .. Version .. " - LoL Ver: " .. LVersion .. ""})
    self.AnnieMenu:MenuElement({id = "blank", type = SPACE, name = "by " .. Author .. ""})
end

function Annie:Draw()
    if myHero.dead then return end
    if self.AnnieMenu.Drawings.DrawQ:Value() then Draw.Circle(myHero.pos, AnnieQ.range, 1, Draw.Color(255, 0, 191, 255)) end
    if self.AnnieMenu.Drawings.DrawW:Value() then Draw.Circle(myHero.pos, AnnieW.range, 1, Draw.Color(255, 65, 105, 225)) end
    if self.AnnieMenu.Drawings.DrawR:Value() then Draw.Circle(myHero.pos, AnnieR.range, 1, Draw.Color(255, 30, 144, 255)) end
    
    for i, enemy in pairs(GetEnemyHeroes()) do
        if self.AnnieMenu.Drawings.DrawJng:Value() then
            if enemy:GetSpellData(SUMMONER_1).name == "SummonerSmite" or enemy:GetSpellData(SUMMONER_2).name == "SummonerSmite" then
                Smite = true
            else
                Smite = false
            end
            if Smite then
                if enemy.alive then
                    if ValidTarget(enemy) then
                        if GetDistance(myHero.pos, enemy.pos) > 3000 then
                            Draw.Text("Jungler: Visible", 17, myHero.pos2D.x - 45, myHero.pos2D.y + 10, Draw.Color(0xFF32CD32))
                        else
                            Draw.Text("Jungler: Near", 17, myHero.pos2D.x - 43, myHero.pos2D.y + 10, Draw.Color(0xFFFF0000))
                        end
                    else
                        Draw.Text("Jungler: Invisible", 17, myHero.pos2D.x - 55, myHero.pos2D.y + 10, Draw.Color(0xFFFFD700))
                    end
                else
                    Draw.Text("Jungler: Dead", 17, myHero.pos2D.x - 45, myHero.pos2D.y + 10, Draw.Color(0xFF32CD32))
                end
            end
        end
        if self.AnnieMenu.Drawings.DrawAA:Value() then
            if ValidTarget(enemy) then
                AALeft = enemy.health / myHero.totalDamage
                Draw.Text("AA Left: " .. tostring(math.ceil(AALeft)), 17, enemy.pos2D.x - 38, enemy.pos2D.y + 10, Draw.Color(0xFF00BFFF))
            end
        end
    end
end

function Annie:LoadSpells()
    AnnieQ = {range = 625}
    AnnieW = {delay = 0.25, speed = math.huge, range = 600}
    --["Incinerate"]={charName="Annie",slot=_W,type="conic",speed=math.huge,range=600,delay=0.25,angle=50,hitbox=false,aoe=true,cc=false,collision=false},
    AnnieR = {range = 600}
end

function Annie:__init()
    self.Spells = {
        ["AatroxQ"] = {charName = "Aatrox", slot = _Q, type = "linear", speed = math.huge, range = 650, delay = 0.6, radius = 200, hitbox = true, aoe = true, cc = true, collision = false},
        ["AatroxQ2"] = {charName = "Aatrox", slot = _Q, type = "linear", speed = math.huge, range = 525, delay = 0.6, radius = 300, hitbox = true, aoe = true, cc = true, collision = false},
        ["AatroxQ3"] = {charName = "Aatrox", slot = _Q, type = "circular", speed = math.huge, range = 200, delay = 0.6, radius = 300, hitbox = true, aoe = true, cc = true, collision = false},
        ["AatroxW"] = {charName = "Aatrox", slot = _W, type = "linear", speed = 1800, range = 825, delay = 0.25, radius = 80, hitbox = true, aoe = false, cc = true, collision = true},
        ["AhriOrbofDeception"] = {charName = "Ahri", slot = _Q, type = "linear", speed = 2500, range = 880, delay = 0.25, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["AhriOrbReturn"] = {charName = "Ahri", slot = _Q, type = "linear", speed = 2500, range = 880, delay = 0.25, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["AhriSeduce"] = {charName = "Ahri", slot = _E, type = "linear", speed = 1550, range = 975, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = false, collision = true},
        ["AkaliQ"] = {charName = "Akali", slot = _Q, type = "conic", speed = math.huge, range = 550, delay = 0.25, angle = 45, hitbox = true, aoe = true, cc = true, collision = false},
        ["AkaliW"] = {charName = "Akali", slot = _W, type = "circular", speed = math.huge, range = 300, delay = 0.25, radius = 300, hitbox = false, aoe = true, cc = false, collision = false},
        ["AkaliE"] = {charName = "Akali", slot = _E, type = "linear", speed = 1650, range = 825, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = false, collision = true},
        ["AkaliR"] = {charName = "Akali", slot = _R, type = "linear", speed = 1650, range = 575, delay = 0, radius = 80, hitbox = true, aoe = true, cc = true, collision = false},
        ["AkaliRb"] = {charName = "Akali", slot = _R, type = "linear", speed = 3300, range = 575, delay = 0, radius = 80, hitbox = true, aoe = true, cc = false, collision = false},
        ["Pulverize"] = {charName = "Alistar", slot = _Q, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 365, hitbox = true, aoe = true, cc = true, collision = false},
        ["BandageToss"] = {charName = "Amumu", slot = _Q, type = "linear", speed = 2000, range = 1100, delay = 0.25, radius = 80, hitbox = true, aoe = false, cc = true, collision = true},
        ["AuraofDespair"] = {charName = "Amumu", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.307, radius = 300, hitbox = false, aoe = true, cc = false, collision = false},
        ["Tantrum"] = {charName = "Amumu", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 350, hitbox = false, aoe = true, cc = false, collision = false},
        ["CurseoftheSadMummy"] = {charName = "Amumu", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 550, hitbox = false, aoe = true, cc = true, collision = false},
        ["FlashFrost"] = {charName = "Anivia", slot = _Q, type = "linear", speed = 850, range = 1075, delay = 0.25, radius = 110, hitbox = true, aoe = true, cc = true, collision = false},
        ["Crystallize"] = {charName = "Anivia", slot = _W, type = "rectangle", speed = math.huge, range = 1000, delay = 0.25, radius1 = 250, radius2 = 75, hitbox = true, aoe = true, cc = true, collision = false},
        ["GlacialStorm"] = {charName = "Anivia", slot = _R, type = "circular", speed = math.huge, range = 750, delay = 0.25, radius = 400, hitbox = true, aoe = true, cc = true, collision = false},
        ["Incinerate"] = {charName = "Annie", slot = _W, type = "conic", speed = math.huge, range = 600, delay = 0.25, angle = 50, hitbox = false, aoe = true, cc = false, collision = false},
        ["InfernalGuardian"] = {charName = "Annie", slot = _R, type = "circular", speed = math.huge, range = 600, delay = 0.25, radius = 290, hitbox = true, aoe = true, cc = false, collision = false},
        ["Volley"] = {charName = "Ashe", slot = _W, type = "conic", speed = 1500, range = 1200, delay = 0.25, radius = 20, angle = 57.5, hitbox = true, aoe = true, cc = true, collision = true},
        ["EnchantedCrystalArrow"] = {charName = "Ashe", slot = _R, type = "linear", speed = 1600, range = 25000, delay = 0.25, radius = 130, hitbox = true, aoe = false, cc = true, collision = false},
        ["AurelionSolQ"] = {charName = "AurelionSol", slot = _Q, type = "linear", speed = 850, range = 1075, delay = 0.25, radius = 210, hitbox = true, aoe = true, cc = true, collision = false},
        ["AurelionSolR"] = {charName = "AurelionSol", slot = _R, type = "linear", speed = 4500, range = 1500, delay = 0.35, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["BardQ"] = {charName = "Bard", slot = _Q, type = "linear", speed = 1500, range = 950, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = true, collision = true},
        ["BardW"] = {charName = "Bard", slot = _W, type = "circular", speed = math.huge, range = 800, delay = 0.25, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["BardR"] = {charName = "Bard", slot = _R, type = "circular", speed = 2100, range = 3400, delay = 0.5, radius = 350, hitbox = true, aoe = true, cc = true, collision = false},
        ["RocketGrab"] = {charName = "Blitzcrank", slot = _Q, type = "linear", speed = 1800, range = 925, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = true, collision = true},
        ["StaticField"] = {charName = "Blitzcrank", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 600, hitbox = false, aoe = true, cc = true, collision = false},
        ["BrandQ"] = {charName = "Brand", slot = _Q, type = "linear", speed = 1600, range = 1050, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = true, collision = true},
        ["BrandW"] = {charName = "Brand", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 0.85, radius = 250, hitbox = true, aoe = true, cc = false, collision = false},
        ["BraumQ"] = {charName = "Braum", slot = _Q, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = true, collision = true},
        ["BraumRWrapper"] = {charName = "Braum", slot = _R, type = "linear", speed = 1400, range = 1250, delay = 0.5, radius = 115, hitbox = true, aoe = true, cc = true, collision = false},
        ["CaitlynPiltoverPeacemaker"] = {charName = "Caitlyn", slot = _Q, type = "linear", speed = 2200, range = 1250, delay = 0.625, radius = 90, hitbox = true, aoe = true, cc = false, collision = false},
        ["CaitlynYordleTrap"] = {charName = "Caitlyn", slot = _W, type = "circular", speed = math.huge, range = 800, delay = 0.25, radius = 75, hitbox = true, aoe = false, cc = true, collision = false},
        ["CaitlynEntrapmentMissile"] = {charName = "Caitlyn", slot = _E, type = "linear", speed = 1600, range = 750, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = true, collision = true},
        ["CamilleW"] = {charName = "Camille", slot = _W, type = "conic", speed = math.huge, range = 610, delay = 0.75, angle = 80, hitbox = false, aoe = true, cc = true, collision = false},
        ["CamilleE"] = {charName = "Camille", slot = _E, type = "linear", speed = 1900, range = 800, delay = 0, radius = 60, hitbox = true, aoe = false, cc = true, collision = false},
        ["CassiopeiaQ"] = {charName = "Cassiopeia", slot = _Q, type = "circular", speed = math.huge, range = 850, delay = 0.4, radius = 150, hitbox = true, aoe = true, cc = false, collision = false},
        ["CassiopeiaW"] = {charName = "Cassiopeia", slot = _W, type = "circular", speed = 2500, range = 800, delay = 0.25, radius = 160, hitbox = true, aoe = true, cc = false, collision = false},
        ["CassiopeiaR"] = {charName = "Cassiopeia", slot = _R, type = "conic", speed = math.huge, range = 825, delay = 0.5, angle = 80, hitbox = false, aoe = true, cc = true, collision = false},
        ["Rupture"] = {charName = "Chogath", slot = _Q, type = "circular", speed = math.huge, range = 950, delay = 0.5, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["FeralScream"] = {charName = "Chogath", slot = _W, type = "conic", speed = math.huge, range = 650, delay = 0.5, angle = 60, hitbox = false, aoe = true, cc = true, collision = false},
        ["PhosphorusBomb"] = {charName = "Corki", slot = _Q, type = "circular", speed = 1000, range = 825, delay = 0.25, radius = 250, hitbox = true, aoe = true, cc = false, collision = false},
        ["CarpetBomb"] = {charName = "Corki", slot = _W, type = "linear", speed = 650, range = 600, delay = 0, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["CarpetBombMega"] = {charName = "Corki", slot = _W, type = "linear", speed = 1500, range = 1800, delay = 0, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["GGun"] = {charName = "Corki", slot = _E, type = "conic", speed = math.huge, range = 600, delay = 0.25, angle = 35, hitbox = false, aoe = true, cc = false, collision = false},
        ["MissileBarrageMissile"] = {charName = "Corki", slot = _R, type = "linear", speed = 2000, range = 1225, delay = 0.175, radius = 40, hitbox = true, aoe = false, cc = false, collision = true},
        ["MissileBarrageMissile2"] = {charName = "Corki", slot = _R, type = "linear", speed = 2000, range = 1225, delay = 0.175, radius = 40, hitbox = true, aoe = false, cc = false, collision = true},
        ["DariusCleave"] = {charName = "Darius", slot = _Q, type = "circular", speed = math.huge, range = 0, delay = 0.75, radius = 425, hitbox = false, aoe = true, cc = false, collision = false},
        ["DariusAxeGrabCone"] = {charName = "Darius", slot = _E, type = "conic", speed = math.huge, range = 535, delay = 0.25, angle = 50, hitbox = false, aoe = true, cc = true, collision = false},
        ["DianaArc"] = {charName = "Diana", slot = _Q, type = "arc", speed = 1400, range = 900, delay = 0.25, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["InfectedCleaverMissileCast"] = {charName = "DrMundo", slot = _Q, type = "linear", speed = 2000, range = 975, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = true, collision = true},
        ["DravenDoubleShot"] = {charName = "Draven", slot = _E, type = "linear", speed = 1400, range = 1050, delay = 0.25, radius = 130, hitbox = true, aoe = true, cc = true, collision = false},
        ["DravenRCast"] = {charName = "Draven", slot = _R, type = "linear", speed = 2000, range = 25000, delay = 0.5, radius = 160, hitbox = true, aoe = true, cc = false, collision = false},
        ["DravenRDoublecast"] = {charName = "Draven", slot = _R, type = "linear", speed = 2000, range = 25000, delay = 0.5, radius = 160, hitbox = true, aoe = true, cc = false, collision = false},
        ["EkkoQ"] = {charName = "Ekko", slot = _Q, type = "linear", speed = 1650, range = 1075, delay = 0.25, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["EkkoW"] = {charName = "Ekko", slot = _W, type = "circular", speed = 1650, range = 1600, delay = 3.75, radius = 400, hitbox = true, aoe = true, cc = true, collision = false},
        ["EkkoR"] = {charName = "Ekko", slot = _R, type = "circular", speed = 1650, range = 1600, delay = 0.25, radius = 375, hitbox = false, aoe = true, cc = false, collision = false},
        ["EliseHumanE"] = {charName = "Elise", slot = _E, type = "linear", speed = 1600, range = 1075, delay = 0.25, radius = 55, hitbox = true, aoe = false, cc = true, collision = true},
        ["EvelynnQ"] = {charName = "Evelynn", slot = _Q, type = "linear", speed = 2200, range = 800, delay = 0.25, radius = 35, hitbox = true, aoe = false, cc = false, collision = true},
        ["EvelynnR"] = {charName = "Evelynn", slot = _R, type = "conic", speed = math.huge, range = 450, delay = 0.35, angle = 180, hitbox = false, aoe = true, cc = false, collision = false},
        ["EzrealMysticShot"] = {charName = "Ezreal", slot = _Q, type = "linear", speed = 2000, range = 1150, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = false, collision = true},
        ["EzrealEssenceFlux"] = {charName = "Ezreal", slot = _W, type = "linear", speed = 1600, range = 1000, delay = 0.25, radius = 80, hitbox = true, aoe = true, cc = false, collision = false},
        ["EzrealTrueshotBarrage"] = {charName = "Ezreal", slot = _R, type = "linear", speed = 2000, range = 25000, delay = 1, radius = 160, hitbox = true, aoe = true, cc = false, collision = false},
        ["FioraW"] = {charName = "Fiora", slot = _W, type = "linear", speed = 3200, range = 750, delay = 0.75, radius = 70, hitbox = true, aoe = true, cc = true, collision = false},
        ["FizzR"] = {charName = "Fizz", slot = _R, type = "linear", speed = 1300, range = 1300, delay = 0.25, radius = 80, hitbox = true, aoe = true, cc = true, collision = false},
        ["GalioQ"] = {charName = "Galio", slot = _Q, type = "arc", speed = 1150, range = 825, delay = 0.25, radius = 250, hitbox = true, aoe = true, cc = false, collision = false},
        ["GalioE"] = {charName = "Galio", slot = _E, type = "linear", speed = 1800, range = 650, delay = 0.45, radius = 160, hitbox = true, aoe = true, cc = true, collision = false},
        ["GalioR"] = {charName = "Galio", slot = _R, type = "circular", speed = math.huge, range = 5500, delay = 2.75, radius = 650, hitbox = true, aoe = true, cc = true, collision = false},
        ["GangplankE"] = {charName = "Gangplank", slot = _E, type = "circular", speed = math.huge, range = 1000, delay = 0.25, radius = 400, hitbox = true, aoe = true, cc = true, collision = false},
        ["GangplankR"] = {charName = "Gangplank", slot = _R, type = "circular", speed = math.huge, range = 25000, delay = 0.25, radius = 600, hitbox = true, aoe = true, cc = true, collision = false},
        ["GnarQ"] = {charName = "Gnar", slot = _Q, type = "linear", speed = 2500, range = 1100, delay = 0.25, radius = 55, hitbox = true, aoe = true, cc = true, collision = false},
        ["GnarQReturn"] = {charName = "Gnar", slot = _Q, type = "linear", speed = 1700, range = 3000, delay = 0.25, radius = 75, hitbox = true, aoe = true, cc = true, collision = false},
        ["GnarE"] = {charName = "Gnar", slot = _E, type = "circular", speed = 900, range = 475, delay = 0.25, radius = 160, hitbox = true, aoe = false, cc = true, collision = false},
        ["GnarBigQ"] = {charName = "Gnar", slot = _Q, type = "linear", speed = 2100, range = 1100, delay = 0.5, radius = 90, hitbox = true, aoe = true, cc = true, collision = true},
        ["GnarBigW"] = {charName = "Gnar", slot = _W, type = "linear", speed = math.huge, range = 550, delay = 0.6, radius = 100, hitbox = true, aoe = true, cc = true, collision = false},
        ["GnarBigE"] = {charName = "Gnar", slot = _E, type = "circular", speed = 800, range = 600, delay = 0.25, radius = 375, hitbox = true, aoe = true, cc = true, collision = false},
        ["GnarR"] = {charName = "Gnar", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 475, hitbox = true, aoe = true, cc = true, collision = false},
        ["GragasQ"] = {charName = "Gragas", slot = _Q, type = "circular", speed = 1000, range = 850, delay = 0.25, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["GragasE"] = {charName = "Gragas", slot = _E, type = "linear", speed = 900, range = 600, delay = 0.25, radius = 170, hitbox = true, aoe = true, cc = true, collision = true},
        ["GragasR"] = {charName = "Gragas", slot = _R, type = "circular", speed = 1800, range = 1000, delay = 0.25, radius = 400, hitbox = true, aoe = true, cc = true, collision = false},
        ["GravesQLineSpell"] = {charName = "Graves", slot = _Q, type = "linear", speed = 2000, range = 925, delay = 0.25, radius = 20, hitbox = true, aoe = true, cc = false, collision = false},
        ["GravesQLineMis"] = {charName = "Graves", slot = _Q, type = "rectangle", speed = math.huge, range = 925, delay = 0.25, radius1 = 250, radius2 = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["GravesQReturn"] = {charName = "Graves", slot = _Q, type = "linear", speed = 1600, range = 925, delay = 0.25, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["GravesSmokeGrenade"] = {charName = "Graves", slot = _W, type = "circular", speed = 1450, range = 950, delay = 0.15, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["GravesChargeShot"] = {charName = "Graves", slot = _R, type = "linear", speed = 2100, range = 1000, delay = 0.25, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["GravesChargeShotFxMissile"] = {charName = "Graves", slot = _R, type = "conic", speed = 2000, range = 800, delay = 0.3, radius = 20, angle = 80, hitbox = true, aoe = true, cc = false, collision = false},
        ["HecarimRapidSlash"] = {charName = "Hecarim", slot = _Q, type = "circular", speed = math.huge, range = 0, delay = 0, radius = 350, hitbox = false, aoe = true, cc = false, collision = false},
        ["HecarimUlt"] = {charName = "Hecarim", slot = _R, type = "linear", speed = 1100, range = 1000, delay = 0.01, radius = 230, hitbox = true, aoe = true, cc = true, collision = false},
        ["HeimerdingerQ"] = {charName = "Heimerdinger", slot = _Q, type = "circular", speed = math.huge, range = 450, delay = 0.25, radius = 55, hitbox = true, aoe = true, cc = false, collision = false},
        ["HeimerdingerW"] = {charName = "Heimerdinger", slot = _W, type = "linear", speed = 2050, range = 1325, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = false, collision = true},
        ["HeimerdingerE"] = {charName = "Heimerdinger", slot = _E, type = "circular", speed = 1200, range = 970, delay = 0.25, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["HeimerdingerEUlt"] = {charName = "Heimerdinger", slot = _E, type = "circular", speed = 1200, range = 970, delay = 0.25, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["IllaoiQ"] = {charName = "Illaoi", slot = _Q, type = "linear", speed = math.huge, range = 850, delay = 0.75, radius = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["IllaoiE"] = {charName = "Illaoi", slot = _E, type = "linear", speed = 1900, range = 900, delay = 0.25, radius = 50, hitbox = true, aoe = false, cc = false, collision = true},
        ["IllaoiR"] = {charName = "Illaoi", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.5, radius = 450, hitbox = false, aoe = true, cc = false, collision = false},
        ["IreliaW2"] = {charName = "Irelia", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0, radius = 275, hitbox = false, aoe = true, cc = false, collision = false},
        ["IreliaW2"] = {charName = "Irelia", slot = _W, type = "linear", speed = math.huge, range = 825, delay = 0.25, radius = 90, hitbox = false, aoe = true, cc = false, collision = false},
        ["IreliaE"] = {charName = "Irelia", slot = _E, type = "circular", speed = 2000, range = 850, delay = 0, radius = 90, hitbox = true, aoe = true, cc = true, collision = false},
        ["IreliaE2"] = {charName = "Irelia", slot = _E, type = "circular", speed = 2000, range = 850, delay = 0, radius = 90, hitbox = true, aoe = true, cc = true, collision = false},
        ["IreliaR"] = {charName = "Irelia", slot = _R, type = "linear", speed = 2000, range = 1000, delay = 0.4, radius = 160, hitbox = true, aoe = true, cc = true, collision = false},
        ["IvernQ"] = {charName = "Ivern", slot = _Q, type = "linear", speed = 1300, range = 1075, delay = 0.25, radius = 80, hitbox = true, aoe = false, cc = true, collision = true},
        ["IvernW"] = {charName = "Ivern", slot = _W, type = "circular", speed = math.huge, range = 1000, delay = 0.25, radius = 150, hitbox = true, aoe = true, cc = false, collision = false},
        ["HowlingGale"] = {charName = "Janna", slot = _Q, type = "linear", speed = 667, range = 1750, delay = 0, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["ReapTheWhirlwind"] = {charName = "Janna", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.001, radius = 725, hitbox = false, aoe = true, cc = true, collision = false},
        ["JarvanIVDragonStrike"] = {charName = "JarvanIV", slot = _Q, type = "linear", speed = math.huge, range = 770, delay = 0.4, radius = 60, hitbox = true, aoe = true, cc = false, collision = false},
        ["JarvanIVGoldenAegis"] = {charName = "JarvanIV", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.125, radius = 625, hitbox = false, aoe = true, cc = true, collision = false},
        ["JarvanIVDemacianStandard"] = {charName = "JarvanIV", slot = _E, type = "circular", speed = 3440, range = 860, delay = 0, radius = 175, hitbox = true, aoe = true, cc = false, collision = false},
        ["JaxCounterStrike"] = {charName = "Jax", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 1.4, radius = 300, hitbox = false, aoe = true, cc = true, collision = false},
        ["JayceShockBlast"] = {charName = "Jayce", slot = _Q, type = "linear", speed = 1450, range = 1175, delay = 0.214, radius = 70, hitbox = true, aoe = true, cc = false, collision = true},
        ["JayceShockBlastWallMis"] = {charName = "Jayce", slot = _Q, type = "linear", speed = 2350, range = 1900, delay = 0.214, radius = 115, hitbox = true, aoe = true, cc = false, collision = true},
        ["JayceStaticField"] = {charName = "Jayce", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 285, hitbox = false, aoe = true, cc = false, collision = false},
        ["JhinW"] = {charName = "Jhin", slot = _W, type = "linear", speed = 5000, range = 3000, delay = 0.75, radius = 40, hitbox = true, aoe = false, cc = true, collision = false},
        ["JhinE"] = {charName = "Jhin", slot = _E, type = "circular", speed = 1600, range = 750, delay = 0.25, radius = 120, hitbox = true, aoe = false, cc = true, collision = false},
        ["JhinRShot"] = {charName = "Jhin", slot = _R, type = "linear", speed = 5000, range = 3500, delay = 0.25, radius = 80, hitbox = true, aoe = false, cc = true, collision = false},
        ["JinxW"] = {charName = "Jinx", slot = _W, type = "linear", speed = 3300, range = 1450, delay = 0.6, radius = 60, hitbox = true, aoe = false, cc = true, collision = true},
        ["JinxE"] = {charName = "Jinx", slot = _E, type = "circular", speed = 1100, range = 900, delay = 1.5, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["JinxR"] = {charName = "Jinx", slot = _R, type = "linear", speed = 1700, range = 25000, delay = 0.6, radius = 140, hitbox = true, aoe = true, cc = false, collision = false},
        ["KaisaW"] = {charName = "Kaisa", slot = _W, type = "linear", speed = 1750, range = 3000, delay = 0.4, radius = 100, hitbox = true, aoe = false, cc = false, collision = true},
        ["KalistaMysticShot"] = {charName = "Kalista", slot = _Q, type = "linear", speed = 2400, range = 1150, delay = 0.35, radius = 40, hitbox = true, aoe = false, cc = false, collision = true},
        ["KalistaW"] = {charName = "Kalista", slot = _W, type = "circular", speed = math.huge, range = 5000, delay = 0.5, radius = 45, hitbox = true, aoe = false, cc = false, collision = false},
        ["KarmaQ"] = {charName = "Karma", slot = _Q, type = "linear", speed = 1700, range = 950, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = true, collision = true},
        ["KarmaQMantra"] = {charName = "Karma", slot = _Q, type = "linear", speed = 1700, range = 950, delay = 0.25, radius = 80, hitbox = true, aoe = false, cc = true, collision = true},
        ["KarthusLayWasteA1"] = {charName = "Karthus", slot = _Q, type = "circular", speed = math.huge, range = 875, delay = 0.625, radius = 200, hitbox = true, aoe = true, cc = false, collision = false},
        ["KarthusLayWasteA2"] = {charName = "Karthus", slot = _Q, type = "circular", speed = math.huge, range = 875, delay = 0.625, radius = 200, hitbox = true, aoe = true, cc = false, collision = false},
        ["KarthusLayWasteA3"] = {charName = "Karthus", slot = _Q, type = "circular", speed = math.huge, range = 875, delay = 0.625, radius = 200, hitbox = true, aoe = true, cc = false, collision = false},
        ["KarthusWallOfPain"] = {charName = "Karthus", slot = _W, type = "rectangle", speed = math.huge, range = 1000, delay = 0.25, radius1 = 470, radius2 = 75, hitbox = true, aoe = true, cc = true, collision = false},
        ["ForcePulse"] = {charName = "Kassadin", slot = _E, type = "conic", speed = math.huge, range = 600, delay = 0.25, angle = 80, hitbox = false, aoe = true, cc = true, collision = false},
        ["Riftwalk"] = {charName = "Kassadin", slot = _R, type = "circular", speed = math.huge, range = 500, delay = 0.25, radius = 300, hitbox = true, aoe = true, cc = false, collision = false},
        ["KatarinaW"] = {charName = "Katarina", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 1.25, radius = 340, hitbox = false, aoe = true, cc = false, collision = false},
        ["KatarinaE"] = {charName = "Katarina", slot = _E, type = "circular", speed = math.huge, range = 725, delay = 0.15, radius = 150, hitbox = true, aoe = false, cc = false, collision = false},
        ["KatarinaR"] = {charName = "Katarina", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0, radius = 550, hitbox = false, aoe = true, cc = false, collision = false},
        ["KaynQ"] = {charName = "Kayn", slot = _Q, type = "circular", speed = math.huge, range = 0, delay = 0.15, radius = 350, hitbox = false, aoe = true, cc = false, collision = false},
        ["KaynW"] = {charName = "Kayn", slot = _W, type = "linear", speed = math.huge, range = 700, delay = 0.55, radius = 90, hitbox = true, aoe = true, cc = true, collision = false},
        ["KennenShurikenHurlMissile1"] = {charName = "Kennen", slot = _Q, type = "linear", speed = 1700, range = 1050, delay = 0.175, radius = 50, hitbox = true, aoe = false, cc = false, collision = true},
        ["KennenShurikenStorm"] = {charName = "Kennen", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 550, hitbox = false, aoe = true, cc = false, collision = false},
        ["KhazixW"] = {charName = "Khazix", slot = _W, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = false, collision = true},
        ["KhazixWLong"] = {charName = "Khazix", slot = _W, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 70, hitbox = true, aoe = true, cc = true, collision = true},
        ["KhazixE"] = {charName = "Khazix", slot = _E, type = "circular", speed = 1000, range = 700, delay = 0.25, radius = 320, hitbox = true, aoe = true, cc = false, collision = false},
        ["KhazixELong"] = {charName = "Khazix", slot = _E, type = "circular", speed = 1000, range = 900, delay = 0.25, radius = 320, hitbox = true, aoe = true, cc = false, collision = false},
        ["KindredR"] = {charName = "Kindred", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 500, hitbox = false, aoe = true, cc = false, collision = false},
        ["KledQ"] = {charName = "Kled", slot = _Q, type = "linear", speed = 1600, range = 800, delay = 0.25, radius = 45, hitbox = true, aoe = false, cc = true, collision = true},
        ["KledEDash"] = {charName = "Kled", slot = _E, type = "linear", speed = 1100, range = 550, delay = 0, radius = 90, hitbox = true, aoe = true, cc = false, collision = false},
        ["KledRiderQ"] = {charName = "Kled", slot = _Q, type = "conic", speed = 3000, range = 700, delay = 0.25, angle = 25, hitbox = false, aoe = true, cc = false, collision = false},
        ["KogMawQ"] = {charName = "KogMaw", slot = _Q, type = "linear", speed = 1650, range = 1175, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = false, collision = true},
        ["KogMawVoidOoze"] = {charName = "KogMaw", slot = _E, type = "linear", speed = 1400, range = 1280, delay = 0.25, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["KogMawLivingArtillery"] = {charName = "KogMaw", slot = _R, type = "circular", speed = math.huge, range = 1800, delay = 0.85, radius = 200, hitbox = true, aoe = true, cc = false, collision = false},
        ["LeblancW"] = {charName = "Leblanc", slot = _W, type = "circular", speed = 1450, range = 600, delay = 0.25, radius = 260, hitbox = true, aoe = true, cc = false, collision = false},
        ["LeblancE"] = {charName = "Leblanc", slot = _E, type = "linear", speed = 1750, range = 925, delay = 0.25, radius = 55, hitbox = true, aoe = false, cc = true, collision = true},
        ["LeblancRW"] = {charName = "Leblanc", slot = _W, type = "circular", speed = 1450, range = 600, delay = 0.25, radius = 260, hitbox = true, aoe = true, cc = false, collision = false},
        ["LeblancRE"] = {charName = "Leblanc", slot = _E, type = "linear", speed = 1750, range = 925, delay = 0.25, radius = 55, hitbox = true, aoe = false, cc = true, collision = true},
        ["BlindMonkQOne"] = {charName = "LeeSin", slot = _Q, type = "linear", speed = 1800, range = 1200, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = false, collision = true},
        ["BlindMonkEOne"] = {charName = "LeeSin", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 350, hitbox = false, aoe = true, cc = false, collision = false},
        ["LeonaZenithBlade"] = {charName = "Leona", slot = _E, type = "linear", speed = 2000, range = 875, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = true, collision = false},
        ["LeonaSolarFlare"] = {charName = "Leona", slot = _R, type = "circular", speed = math.huge, range = 1200, delay = 0.625, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["LissandraQ"] = {charName = "Lissandra", slot = _Q, type = "linear", speed = 2200, range = 825, delay = 0.251, radius = 75, hitbox = true, aoe = true, cc = true, collision = false},
        ["LissandraW"] = {charName = "Lissandra", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 450, hitbox = false, aoe = true, cc = true, collision = false},
        ["LissandraE"] = {charName = "Lissandra", slot = _E, type = "linear", speed = 850, range = 1050, delay = 0.25, radius = 125, hitbox = true, aoe = true, cc = false, collision = false},
        ["LucianQ"] = {charName = "Lucian", slot = _Q, type = "linear", speed = math.huge, range = 900, delay = 0.5, radius = 65, hitbox = true, aoe = true, cc = false, collision = false},
        ["LucianW"] = {charName = "Lucian", slot = _W, type = "linear", speed = 1600, range = 900, delay = 0.25, radius = 55, hitbox = true, aoe = true, cc = false, collision = false},
        ["LucianR"] = {charName = "Lucian", slot = _R, type = "linear", speed = 2800, range = 1200, delay = 0.01, radius = 110, hitbox = true, aoe = false, cc = false, collision = true},
        ["LuluQ"] = {charName = "Lulu", slot = _Q, type = "linear", speed = 1450, range = 925, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = true, collision = false},
        ["LuxLightBinding"] = {charName = "Lux", slot = _Q, type = "linear", speed = 1200, range = 1175, delay = 0.25, radius = 50, hitbox = true, aoe = true, cc = true, collision = true},
        ["LuxPrismaticWave"] = {charName = "Lux", slot = _W, type = "linear", speed = 1400, range = 1075, delay = 0.25, radius = 110, hitbox = true, aoe = true, cc = false, collision = false},
        ["LuxLightStrikeKugel"] = {charName = "Lux", slot = _E, type = "circular", speed = 1200, range = 1000, delay = 0.25, radius = 310, hitbox = true, aoe = true, cc = true, collision = false},
        ["LuxMaliceCannon"] = {charName = "Lux", slot = _R, type = "linear", speed = math.huge, range = 3340, delay = 1, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["Landslide"] = {charName = "Malphite", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 0.242, radius = 200, hitbox = false, aoe = true, cc = true, collision = false},
        ["UFSlash"] = {charName = "Malphite", slot = _R, type = "circular", speed = 1835, range = 1000, delay = 0, radius = 300, hitbox = true, aoe = true, cc = true, collision = false},
        ["MalzaharQ"] = {charName = "Malzahar", slot = _Q, type = "rectangle", speed = math.huge, range = 900, delay = 0.25, radius1 = 400, radius2 = 100, hitbox = true, aoe = true, cc = true, collision = false},
        ["MaokaiQ"] = {charName = "Maokai", slot = _Q, type = "linear", speed = 1600, range = 600, delay = 0.375, radius = 110, hitbox = true, aoe = true, cc = true, collision = false},
        ["MaokaiR"] = {charName = "Maokai", slot = _R, type = "linear", speed = 150, range = 3000, delay = 0.25, radius = 650, hitbox = true, aoe = true, cc = true, collision = false},
        ["MissFortuneScattershot"] = {charName = "MissFortune", slot = _E, type = "circular", speed = math.huge, range = 1000, delay = 0.5, radius = 400, hitbox = true, aoe = true, cc = true, collision = false},
        ["MissFortuneBulletTime"] = {charName = "MissFortune", slot = _R, type = "conic", speed = math.huge, range = 1400, delay = 0.001, angle = 40, hitbox = false, aoe = true, cc = false, collision = false},
        ["MordekaiserSiphonOfDestruction"] = {charName = "Mordekaiser", slot = _E, type = "conic", speed = math.huge, range = 675, delay = 0.25, angle = 50, hitbox = false, aoe = true, cc = false, collision = false},
        ["DarkBindingMissile"] = {charName = "Morgana", slot = _Q, type = "linear", speed = 1200, range = 1175, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = true, collision = true},
        ["TormentedSoil"] = {charName = "Morgana", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 0.25, radius = 325, hitbox = true, aoe = true, cc = false, collision = false},
        ["NamiQ"] = {charName = "Nami", slot = _Q, type = "circular", speed = math.huge, range = 875, delay = 0.95, radius = 200, hitbox = true, aoe = true, cc = true, collision = false},
        ["NamiR"] = {charName = "Nami", slot = _R, type = "linear", speed = 850, range = 2750, delay = 0.5, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["NasusE"] = {charName = "Nasus", slot = _E, type = "circular", speed = math.huge, range = 650, delay = 0.25, radius = 400, hitbox = true, aoe = true, cc = false, collision = false},
        ["NautilusAnchorDrag"] = {charName = "Nautilus", slot = _Q, type = "linear", speed = 2000, range = 1100, delay = 0.25, radius = 90, hitbox = true, aoe = false, cc = true, collision = true},
        ["NautilusSplashZone"] = {charName = "Nautilus", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 600, hitbox = false, aoe = true, cc = true, collision = false},
        ["JavelinToss"] = {charName = "Nidalee", slot = _Q, type = "linear", speed = 1300, range = 1500, delay = 0.25, radius = 40, hitbox = true, aoe = true, cc = false, collision = true},
        ["Bushwhack"] = {charName = "Nidalee", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 0.25, radius = 85, hitbox = true, aoe = false, cc = false, collision = true},
        ["Pounce"] = {charName = "Nidalee", slot = _W, type = "circular", speed = 1750, range = 750, delay = 0.25, radius = 200, hitbox = true, aoe = true, cc = false, collision = false},
        ["Swipe"] = {charName = "Nidalee", slot = _E, type = "conic", speed = math.huge, range = 300, delay = 0.25, angle = 180, hitbox = false, aoe = true, cc = false, collision = false},
        ["NocturneDuskbringer"] = {charName = "Nocturne", slot = _Q, type = "linear", speed = 1600, range = 1200, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = false, collision = false},
        ["AbsoluteZero"] = {charName = "Nunu", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 3.01, radius = 650, hitbox = false, aoe = true, cc = true, collision = false},
        ["OlafAxeThrowCast"] = {charName = "Olaf", slot = _Q, type = "linear", speed = 1600, range = 1000, delay = 0.25, radius = 90, hitbox = true, aoe = true, cc = true, collision = false},
        ["OrianaIzunaCommand"] = {charName = "Orianna", slot = _Q, type = "linear", speed = 1400, range = 825, delay = 0.25, radius = 80, hitbox = true, aoe = true, cc = false, collision = false},
        ["OrianaDissonanceCommand"] = {charName = "Orianna", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 250, hitbox = false, aoe = true, cc = true, collision = false},
        ["OrianaRedactCommand"] = {charName = "Orianna", slot = _E, type = "linear", speed = 1400, range = 1100, delay = 0.25, radius = 80, hitbox = true, aoe = true, cc = false, collision = false},
        ["OrianaDetonateCommand"] = {charName = "Orianna", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.5, radius = 325, hitbox = false, aoe = true, cc = true, collision = false},
        ["OrnnQ"] = {charName = "Ornn", slot = _Q, type = "linear", speed = 1800, range = 800, delay = 0.3, radius = 65, hitbox = true, aoe = true, cc = true, collision = false},
        ["OrnnE"] = {charName = "Ornn", slot = _E, type = "linear", speed = 1800, range = 800, delay = 0.35, radius = 150, hitbox = true, aoe = true, cc = true, collision = false},
        ["OrnnR"] = {charName = "Ornn", slot = _R, type = "linear", speed = 1650, range = 2500, delay = 0.5, radius = 200, hitbox = true, aoe = true, cc = true, collision = false},
        ["PantheonE"] = {charName = "Pantheon", slot = _E, type = "conic", speed = math.huge, range = 0, delay = 0.389, angle = 80, hitbox = false, aoe = true, cc = false, collision = false},
        ["PantheonRFall"] = {charName = "Pantheon", slot = _R, type = "circular", speed = math.huge, range = 5500, delay = 2.5, radius = 700, hitbox = true, aoe = true, cc = true, collision = false},
        ["PoppyQSpell"] = {charName = "Poppy", slot = _Q, type = "linear", speed = math.huge, range = 430, delay = 1.32, radius = 85, hitbox = true, aoe = true, cc = true, collision = false},
        ["PoppyW"] = {charName = "Poppy", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0, radius = 400, hitbox = false, aoe = true, cc = false, collision = false},
        ["PoppyRSpell"] = {charName = "Poppy", slot = _R, type = "linear", speed = 2000, range = 1900, delay = 0.333, radius = 100, hitbox = true, aoe = true, cc = true, collision = false},
        ["PykeQMelee"] = {charName = "Pyke", slot = _Q, type = "linear", speed = math.huge, range = 400, delay = 0.25, radius = 70, hitbox = true, aoe = true, cc = true, collision = false},
        ["PykeQRange"] = {charName = "Pyke", slot = _Q, type = "linear", speed = 2000, range = 1100, delay = 0.2, radius = 70, hitbox = true, aoe = false, cc = true, collision = true},
        ["PykeR"] = {charName = "Pyke", slot = _R, type = "cross", speed = math.huge, range = 750, delay = 0.5, radius1 = 300, radius2 = 50, hitbox = true, aoe = true, cc = false, collision = false},
        ["QuinnQ"] = {charName = "Quinn", slot = _Q, type = "linear", speed = 1550, range = 1025, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = false, collision = true},
        ["RakanQ"] = {charName = "Rakan", slot = _Q, type = "linear", speed = 1850, range = 900, delay = 0.25, radius = 65, hitbox = true, aoe = false, cc = false, collision = true},
        ["RakanW"] = {charName = "Rakan", slot = _W, type = "circular", speed = 2050, range = 600, delay = 0, radius = 250, hitbox = true, aoe = true, cc = false, collision = false},
        ["RakanWCast"] = {charName = "Rakan", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.5, radius = 250, hitbox = false, aoe = true, cc = true, collision = false},
        ["Tremors2"] = {charName = "Rammus", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 300, hitbox = false, aoe = true, cc = true, collision = false},
        ["RekSaiQBurrowed"] = {charName = "RekSai", slot = _Q, type = "linear", speed = 1950, range = 1650, delay = 0.125, radius = 65, hitbox = true, aoe = false, cc = false, collision = true},
        ["RenektonCleave"] = {charName = "Renekton", slot = _Q, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 325, hitbox = false, aoe = true, cc = false, collision = false},
        ["RenektonSliceAndDice"] = {charName = "Renekton", slot = _E, type = "linear", speed = 1125, range = 450, delay = 0.25, radius = 45, hitbox = true, aoe = true, cc = false, collision = false},
        ["RengarW"] = {charName = "Rengar", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 450, hitbox = false, aoe = true, cc = false, collision = false},
        ["RengarE"] = {charName = "Rengar", slot = _E, type = "linear", speed = 1500, range = 1000, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = true, collision = true},
        ["RivenMartyr"] = {charName = "Riven", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.267, radius = 135, hitbox = false, aoe = true, cc = true, collision = false},
        ["RivenIzunaBlade"] = {charName = "Riven", slot = _R, type = "conic", speed = 1600, range = 900, delay = 0.25, angle = 50, hitbox = true, aoe = true, cc = false, collision = false},
        ["RumbleGrenade"] = {charName = "Rumble", slot = _E, type = "linear", speed = 2000, range = 850, delay = 0.25, radius = 60, hitbox = true, aoe = false, cc = true, collision = true},
        ["RumbleCarpetBombDummy"] = {charName = "Rumble", slot = _R, type = "rectangle", speed = 1600, range = 1700, delay = 0.583, radius1 = 600, radius2 = 200, hitbox = true, aoe = true, cc = true, collision = false},
        ["RyzeQ"] = {charName = "Ryze", slot = _Q, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 55, hitbox = true, aoe = false, cc = false, collision = true},
        ["SejuaniW"] = {charName = "Sejuani", slot = _W, type = "conic", speed = math.huge, range = 600, delay = 0.25, angle = 75, hitbox = false, aoe = true, cc = true, collision = false},
        ["SejuaniWDummy"] = {charName = "Sejuani", slot = _W, type = "linear", speed = math.huge, range = 600, delay = 1, radius = 65, hitbox = true, aoe = false, cc = true, collision = false},
        ["SejuaniR"] = {charName = "Sejuani", slot = _R, type = "linear", speed = 1600, range = 1300, delay = 0.25, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["ShenE"] = {charName = "Shen", slot = _E, type = "linear", speed = 1200, range = 600, delay = 0, radius = 60, hitbox = true, aoe = true, cc = true, collision = false},
        ["ShyvanaFireball"] = {charName = "Shyvana", slot = _E, type = "linear", speed = 1575, range = 925, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = false, collision = false},
        ["ShyvanaTransformLeap"] = {charName = "Shyvana", slot = _R, type = "linear", speed = 1130, range = 850, delay = 0.25, radius = 160, hitbox = true, aoe = true, cc = true, collision = false},
        ["ShyvanaFireballDragon2"] = {charName = "Shyvana", slot = _E, type = "linear", speed = 1575, range = 925, delay = 0.333, radius = 60, hitbox = true, aoe = true, cc = false, collision = false},
        ["MegaAdhesive"] = {charName = "Singed", slot = _W, type = "circular", speed = math.huge, range = 1000, delay = 0.25, radius = 265, hitbox = true, aoe = true, cc = true, collision = false},
        ["SionQ"] = {charName = "Sion", slot = _Q, type = "linear", speed = math.huge, range = 600, delay = 0, radius = 300, hitbox = false, aoe = true, cc = true, collision = false},
        ["SionE"] = {charName = "Sion", slot = _E, type = "linear", speed = 1800, range = 725, delay = 0.25, radius = 80, hitbox = false, aoe = true, cc = true, collision = false},
        ["SivirQ"] = {charName = "Sivir", slot = _Q, type = "linear", speed = 1350, range = 1250, delay = 0.25, radius = 90, hitbox = true, aoe = true, cc = false, collision = false},
        ["SivirQReturn"] = {charName = "Sivir", slot = _Q, type = "linear", speed = 1350, range = 1250, delay = 0, radius = 90, hitbox = true, aoe = true, cc = false, collision = false},
        ["SkarnerVirulentSlash"] = {charName = "Skarner", slot = _Q, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 350, hitbox = false, aoe = true, cc = false, collision = false},
        ["SkarnerFracture"] = {charName = "Skarner", slot = _E, type = "linear", speed = 1500, range = 1000, delay = 0.25, radius = 70, hitbox = true, aoe = true, cc = true, collision = false},
        ["SonaR"] = {charName = "Sona", slot = _R, type = "linear", speed = 2400, range = 900, delay = 0.25, radius = 140, hitbox = true, aoe = true, cc = true, collision = false},
        ["SorakaQ"] = {charName = "Soraka", slot = _Q, type = "circular", speed = 1150, range = 800, delay = 0.25, radius = 235, hitbox = true, aoe = true, cc = true, collision = false},
        ["SorakaE"] = {charName = "Soraka", slot = _E, type = "circular", speed = math.huge, range = 925, delay = 1.5, radius = 300, hitbox = true, aoe = true, cc = true, collision = false},
        ["SwainQ"] = {charName = "Swain", slot = _Q, type = "conic", speed = math.huge, range = 725, delay = 0.25, angle = 45, hitbox = false, aoe = true, cc = false, collision = false},
        ["SwainW"] = {charName = "Swain", slot = _W, type = "circular", speed = math.huge, range = 3500, delay = 1.5, radius = 325, hitbox = false, aoe = true, cc = false, collision = false},
        ["SwainE"] = {charName = "Swain", slot = _E, type = "linear", speed = 935, range = 850, delay = 0.25, radius = 85, hitbox = true, aoe = true, cc = true, collision = false},
        ["SwainR"] = {charName = "Swain", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.5, radius = 650, hitbox = false, aoe = true, cc = true, collision = false},
        ["SyndraQ"] = {charName = "Syndra", slot = _Q, type = "circular", speed = math.huge, range = 800, delay = 0.625, radius = 200, hitbox = true, aoe = true, cc = false, collision = false},
        ["SyndraWCast"] = {charName = "Syndra", slot = _W, type = "circular", speed = 1450, range = 950, delay = 0.25, radius = 225, hitbox = true, aoe = true, cc = true, collision = false},
        ["SyndraE"] = {charName = "Syndra", slot = _E, type = "conic", speed = 2500, range = 700, delay = 0.25, angle = 40, hitbox = false, aoe = true, cc = true, collision = false},
        ["SyndraEMissile"] = {charName = "Syndra", slot = _E, type = "linear", speed = 1600, range = 1250, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = true, collision = false},
        ["TahmKenchQ"] = {charName = "TahmKench", slot = _Q, type = "linear", speed = 2800, range = 800, delay = 0.25, radius = 70, hitbox = true, aoe = false, cc = true, collision = true},
        ["TaliyahQ"] = {charName = "Taliyah", slot = _Q, type = "linear", speed = 3600, range = 1000, delay = 0.25, radius = 100, hitbox = true, aoe = false, cc = false, collision = true},
        ["TaliyahWVC"] = {charName = "Taliyah", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 0.6, radius = 150, hitbox = true, aoe = true, cc = true, collision = false},
        ["TaliyahE"] = {charName = "Taliyah", slot = _E, type = "conic", speed = 2000, range = 800, delay = 0.25, angle = 80, hitbox = true, aoe = true, cc = true, collision = false},
        ["TaliyahR"] = {charName = "Taliyah", slot = _R, type = "linear", speed = 1700, range = 6000, delay = 1, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["TalonW"] = {charName = "Talon", slot = _W, type = "conic", speed = 1850, range = 650, delay = 0.25, angle = 35, hitbox = true, aoe = true, cc = true, collision = false},
        ["TalonR"] = {charName = "Talon", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 550, hitbox = false, aoe = true, cc = false, collision = false},
        ["TaricE"] = {charName = "Taric", slot = _E, type = "linear", speed = math.huge, range = 575, delay = 1, radius = 70, hitbox = true, aoe = true, cc = true, collision = false},
        ["TeemoRCast"] = {charName = "Teemo", slot = _R, type = "circular", speed = math.huge, range = 900, delay = 1.25, radius = 200, hitbox = true, aoe = true, cc = true, collision = false},
        ["ThreshQ"] = {charName = "Thresh", slot = _Q, type = "linear", speed = 1900, range = 1100, delay = 0.5, radius = 70, hitbox = true, aoe = false, cc = true, collision = true},
        ["ThreshE"] = {charName = "Thresh", slot = _E, type = "linear", speed = math.huge, range = 400, delay = 0.389, radius = 110, hitbox = false, aoe = true, cc = true, collision = false},
        ["ThreshRPenta"] = {charName = "Thresh", slot = _R, type = "pentagon", speed = math.huge, range = 0, delay = 0.45, radius = 450, hitbox = false, aoe = true, cc = true, collision = false},
        ["TristanaW"] = {charName = "Tristana", slot = _W, type = "circular", speed = 1100, range = 900, delay = 0.25, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["trundledesecrate"] = {charName = "Trundle", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 1000, hitbox = false, aoe = false, cc = false, collision = false},
        ["TrundleCircle"] = {charName = "Trundle", slot = _E, type = "circular", speed = math.huge, range = 1000, delay = 0.25, radius = 375, hitbox = true, aoe = true, cc = true, collision = false},
        ["TryndamereE"] = {charName = "Tryndamere", slot = _E, type = "linear", speed = 1300, range = 660, delay = 0, radius = 225, hitbox = true, aoe = true, cc = false, collision = false},
        ["WildCards"] = {charName = "TwistedFate", slot = _Q, type = "linear", speed = 1000, range = 1450, delay = 0.25, radius = 40, hitbox = true, aoe = true, cc = false, collision = false},
        ["TwitchVenomCask"] = {charName = "Twitch", slot = _W, type = "circular", speed = 1400, range = 950, delay = 0.25, radius = 340, hitbox = true, aoe = true, cc = true, collision = false},
        ["UrgotQ"] = {charName = "Urgot", slot = _Q, type = "circular", speed = math.huge, range = 800, delay = 0.6, radius = 215, hitbox = true, aoe = true, cc = true, collision = false},
        ["UrgotE"] = {charName = "Urgot", slot = _E, type = "linear", speed = 1050, range = 475, delay = 0.45, radius = 100, hitbox = true, aoe = true, cc = true, collision = false},
        ["UrgotR"] = {charName = "Urgot", slot = _R, type = "linear", speed = 3200, range = 1600, delay = 0.4, radius = 80, hitbox = true, aoe = false, cc = true, collision = false},
        ["VarusQ"] = {charName = "Varus", slot = _Q, type = "linear", speed = 1900, range = 1625, delay = 0, radius = 70, hitbox = true, aoe = true, cc = false, collision = false},
        ["VarusE"] = {charName = "Varus", slot = _E, type = "circular", speed = 1500, range = 925, delay = 0.242, radius = 280, hitbox = true, aoe = true, cc = true, collision = false},
        ["VarusR"] = {charName = "Varus", slot = _R, type = "linear", speed = 1950, range = 1075, delay = 0.242, radius = 120, hitbox = true, aoe = true, cc = true, collision = false},
        ["VeigarBalefulStrike"] = {charName = "Veigar", slot = _Q, type = "linear", speed = 2200, range = 950, delay = 0.25, radius = 70, hitbox = true, aoe = true, cc = false, collision = true},
        ["VeigarDarkMatter"] = {charName = "Veigar", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 1.25, radius = 225, hitbox = true, aoe = true, cc = false, collision = false},
        ["VeigarEventHorizon"] = {charName = "Veigar", slot = _E, type = "circular", speed = math.huge, range = 700, delay = 0.75, radius = 375, hitbox = true, aoe = true, cc = true, collision = false},
        ["VelKozQ"] = {charName = "VelKoz", slot = _Q, type = "linear", speed = 1300, range = 1050, delay = 0.251, radius = 50, hitbox = true, aoe = false, cc = true, collision = true},
        ["VelkozQMissileSplit"] = {charName = "VelKoz", slot = _Q, type = "linear", speed = 2100, range = 1050, delay = 0.251, radius = 45, hitbox = true, aoe = false, cc = true, collision = true},
        ["VelKozW"] = {charName = "VelKoz", slot = _W, type = "linear", speed = 1700, range = 1050, delay = 0.25, radius = 87.5, hitbox = true, aoe = true, cc = false, collision = false},
        ["VelKozE"] = {charName = "VelKoz", slot = _E, type = "circular", speed = math.huge, range = 850, delay = 0.75, radius = 235, hitbox = true, aoe = true, cc = true, collision = false},
        ["ViQ"] = {charName = "Vi", slot = _Q, type = "linear", speed = 1500, range = 725, delay = 0, radius = 90, hitbox = true, aoe = true, cc = true, collision = false},
        ["ViktorGravitonField"] = {charName = "Viktor", slot = _W, type = "circular", speed = math.huge, range = 800, delay = 1.333, radius = 290, hitbox = true, aoe = true, cc = true, collision = false},
        ["ViktorDeathRay"] = {charName = "Viktor", slot = _E, type = "linear", speed = 1050, range = 1025, delay = 0, radius = 80, hitbox = true, aoe = true, cc = false, collision = false},
        ["ViktorChaosStorm"] = {charName = "Viktor", slot = _R, type = "circular", speed = math.huge, range = 700, delay = 0.25, radius = 290, hitbox = true, aoe = true, cc = false, collision = false},
        ["VladimirSanguinePool"] = {charName = "Vladimir", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 300, hitbox = false, aoe = true, cc = true, collision = false},
        ["VladimirE"] = {charName = "Vladimir", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 0, radius = 600, hitbox = false, aoe = true, cc = true, collision = true},
        ["VladimirHemoplague"] = {charName = "Vladimir", slot = _R, type = "circular", speed = math.huge, range = 700, delay = 0.389, radius = 350, hitbox = true, aoe = true, cc = false, collision = true},
        ["WarwickR"] = {charName = "Warwick", slot = _R, type = "linear", speed = 1800, range = 3000, delay = 0.1, radius = 45, hitbox = true, aoe = true, cc = false, collision = false},
        ["XayahQ"] = {charName = "Xayah", slot = _Q, type = "linear", speed = 2075, range = 1100, delay = 0.5, radius = 50, hitbox = true, aoe = true, cc = false, collision = false},
        ["XayahE"] = {charName = "Xayah", slot = _E, type = "linear", speed = 4000, range = 2000, delay = 0, radius = 50, hitbox = true, aoe = true, cc = false, collision = false},
        ["XayahR"] = {charName = "Xayah", slot = _R, type = "conic", speed = 4000, range = 1100, delay = 1.5, radius = 20, angle = 40, hitbox = false, aoe = true, cc = false, collision = false},
        ["XerathArcanopulse2"] = {charName = "Xerath", slot = _Q, type = "linear", speed = math.huge, range = 1400, delay = 0.5, radius = 90, hitbox = false, aoe = true, cc = false, collision = false},
        ["XerathArcaneBarrage2"] = {charName = "Xerath", slot = _W, type = "circular", speed = math.huge, range = 1100, delay = 0.5, radius = 235, hitbox = true, aoe = true, cc = true, collision = false},
        ["XerathMageSpear"] = {charName = "Xerath", slot = _E, type = "linear", speed = 1400, range = 1050, delay = 0.2, radius = 60, hitbox = true, aoe = false, cc = true, collision = true},
        ["XerathRMissileWrapper"] = {charName = "Xerath", slot = _R, type = "circular", speed = math.huge, range = 6160, delay = 0.6, radius = 200, hitbox = true, aoe = true, cc = false, collision = false},
        ["XinZhaoW"] = {charName = "XinZhao", slot = _W, type = "conic", speed = math.huge, range = 125, delay = 0, angle = 180, hitbox = false, aoe = true, cc = false, collision = false},
        ["XinZhaoW"] = {charName = "XinZhao", slot = _W, type = "linear", speed = math.huge, range = 900, delay = 0.5, radius = 45, hitbox = true, aoe = true, cc = true, collision = false},
        ["XinZhaoR"] = {charName = "XinZhao", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.325, radius = 550, hitbox = false, aoe = true, cc = true, collision = false},
        ["YasuoQW"] = {charName = "Yasuo", slot = _Q, type = "linear", speed = math.huge, range = 475, delay = 0.339, radius = 40, hitbox = true, aoe = true, cc = false, collision = false},
        ["YasuoQ2W"] = {charName = "Yasuo", slot = _Q, type = "linear", speed = math.huge, range = 475, delay = 0.339, radius = 40, hitbox = true, aoe = true, cc = false, collision = false},
        ["YasuoQ3W"] = {charName = "Yasuo", slot = _Q, type = "linear", speed = 1200, range = 1000, delay = 0.339, radius = 90, hitbox = true, aoe = true, cc = true, collision = false},
        ["YorickW"] = {charName = "Yorick", slot = _W, type = "circular", speed = math.huge, range = 600, delay = 0.25, radius = 300, hitbox = true, aoe = true, cc = true, collision = false},
        ["YorickE"] = {charName = "Yorick", slot = _E, type = "conic", speed = 2100, range = 700, delay = 0.33, angle = 25, hitbox = true, aoe = true, cc = true, collision = false},
        ["ZacQ"] = {charName = "Zac", slot = _Q, type = "linear", speed = 2800, range = 800, delay = 0.33, radius = 80, hitbox = true, aoe = true, cc = true, collision = true},
        ["ZacW"] = {charName = "Zac", slot = _W, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 350, hitbox = false, aoe = true, cc = false, collision = false},
        ["ZacE"] = {charName = "Zac", slot = _E, type = "circular", speed = 1330, range = 1800, delay = 0, radius = 300, hitbox = false, aoe = true, cc = true, collision = false},
        ["ZacR"] = {charName = "Zac", slot = _R, type = "circular", speed = math.huge, range = 1000, delay = 0, radius = 300, hitbox = false, aoe = true, cc = true, collision = false},
        ["ZedQ"] = {charName = "Zed", slot = _Q, type = "linear", speed = 1700, range = 900, delay = 0.25, radius = 50, hitbox = true, aoe = true, cc = false, collision = false},
        ["ZedW"] = {charName = "Zed", slot = _W, type = "linear", speed = 1750, range = 650, delay = 0.25, radius = 60, hitbox = true, aoe = true, cc = false, collision = false},
        ["ZedE"] = {charName = "Zed", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 290, hitbox = false, aoe = true, cc = true, collision = false},
        ["ZiggsQ"] = {charName = "Ziggs", slot = _Q, type = "circular", speed = 1700, range = 1400, delay = 0.25, radius = 130, hitbox = true, aoe = true, cc = false, collision = false},
        ["ZiggsW"] = {charName = "Ziggs", slot = _W, type = "circular", speed = 2000, range = 1000, delay = 0.25, radius = 280, hitbox = true, aoe = true, cc = true, collision = false},
        ["ZiggsE"] = {charName = "Ziggs", slot = _E, type = "circular", speed = 1800, range = 900, delay = 0.25, radius = 250, hitbox = true, aoe = true, cc = true, collision = false},
        ["ZiggsR"] = {charName = "Ziggs", slot = _R, type = "circular", speed = 1600, range = 5300, delay = 0.375, radius = 550, hitbox = true, aoe = true, cc = false, collision = false},
        ["ZileanQ"] = {charName = "Zilean", slot = _Q, type = "circular", speed = math.huge, range = 900, delay = 0.8, radius = 180, hitbox = true, aoe = true, cc = true, collision = false},
        ["ZileanQAttachAudio"] = {charName = "Zilean", slot = _Q, type = "circular", speed = math.huge, range = 900, delay = 0.8, radius = 180, hitbox = true, aoe = true, cc = true, collision = false},
        ["ZoeQ"] = {charName = "Zoe", slot = _Q, type = "linear", speed = 1200, range = 800, delay = 0.25, radius = 50, hitbox = true, aoe = false, cc = false, collision = true},
        ["ZoeQRecast"] = {charName = "Zoe", slot = _Q, type = "linear", speed = 2500, range = 1600, delay = 0, radius = 70, hitbox = true, aoe = false, cc = false, collision = true},
        ["ZoeE"] = {charName = "Zoe", slot = _E, type = "linear", speed = 1700, range = 800, delay = 0.3, radius = 50, hitbox = true, aoe = false, cc = true, collision = true},
        ["ZyraQ"] = {charName = "Zyra", slot = _Q, type = "rectangle", speed = math.huge, range = 800, delay = 0.625, radius1 = 400, radius2 = 100, hitbox = true, aoe = true, cc = false, collision = false},
        ["ZyraW"] = {charName = "Zyra", slot = _W, type = "circular", speed = math.huge, range = 850, delay = 0.243, radius = 50, hitbox = true, aoe = false, cc = false, collision = false},
        ["ZyraE"] = {charName = "Zyra", slot = _E, type = "linear", speed = 1150, range = 1100, delay = 0.25, radius = 70, hitbox = true, aoe = true, cc = true, collision = false},
        ["ZyraR"] = {charName = "Zyra", slot = _R, type = "circular", speed = math.huge, range = 700, delay = 1.775, radius = 575, hitbox = true, aoe = true, cc = true, collision = false},
    }
    self.Detected = {}
    Item_HK = {}
    self:LoadMenu()
    self:LoadSpells()
    Callback.Add("Tick", function()self:Tick() end)
    Callback.Add("Draw", function()self:Draw() end)
end

function Annie:Tick()
    if myHero.dead or Game.IsChatOpen() == true or IsRecalling() == true or ExtLibEvade and ExtLibEvade.Evading == true then return end
    
    if self.Detected[1] == nil then
        self.Collision = false
        self.CollisionSpellName = nil
    end
    
    Item_HK[ITEM_1] = HK_ITEM_1
    Item_HK[ITEM_2] = HK_ITEM_2
    Item_HK[ITEM_3] = HK_ITEM_3
    Item_HK[ITEM_4] = HK_ITEM_4
    Item_HK[ITEM_5] = HK_ITEM_5
    Item_HK[ITEM_6] = HK_ITEM_6
    Item_HK[ITEM_7] = HK_ITEM_7
    
    self:AntiGapcloser()
    
    self:AutoE()
    
    if self.AnnieMenu.AutoLevel.AutoLevel:Value() then
        local mylevel = myHero.levelData.lvl
        local mylevelpts = myHero.levelData.lvlPts
        
        if mylevelpts > 0 then
            if mylevel == 6 or mylevel == 11 or mylevel == 16 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_R)
                LocalControlKeyUp(HK_R)
                LocalControlKeyUp(HK_LUS)
            elseif mylevel == 1 or mylevel == 4 or mylevel == 5 or mylevel == 7 or mylevel == 9 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_Q)
                LocalControlKeyUp(HK_Q)
                LocalControlKeyUp(HK_LUS)
            elseif mylevel == 2 or mylevel == 8 or mylevel == 10 or mylevel == 12 or mylevel == 13 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_W)
                LocalControlKeyUp(HK_W)
                LocalControlKeyUp(HK_LUS)
            elseif mylevel == 3 or mylevel == 14 or mylevel == 15 or mylevel == 17 or mylevel == 18 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_E)
                LocalControlKeyUp(HK_E)
                LocalControlKeyUp(HK_LUS)
            end
        end
    end
    
    self:KillSteal()
    
    self:Tibbers()
    
    if GetMode() == "Harass" then
        self:Harass()
    end
    if GetMode() == "Combo" then
        self:Combo()
    end
    if GetMode() == "Clear" then
        self:LaneClear()
    end
end

function Annie:CollisionX(myHeroPos, dangerousPos, unitPos, radius)
    local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(Vector(myHeroPos), Vector(unitPos), Vector(dangerousPos))
    if isOnSegment and GetDistanceSqr(pointSegment, Vector(dangerousPos)) < (myHero.boundingRadius * 2 + radius) ^ 2 then
        return true
    else
        return false
    end
end

function Annie:Action()
    for _, spell in pairs(self.Detected) do
        local delay = self.SpellsE[spell.name].delay
        local radius = self.SpellsE[spell.name].radius
        if spell.startTime + delay > Game.Timer() then
            if GetDistance(myHero.pos, spell.endPos) < (radius + myHero.boundingRadius) or GetDistance(spell.source, spell.endPos) < (radius + 100) or self:CollisionX(myHero.pos, spell.endPos, spell.source, radius) then
                --print("Yes")
                self.Collision = true
                self.CollisionSpellName = spell.name
            else
                --print("No")
                self.Collision = false
            end
        else
            table.remove(self.Detected, _)
        end
    end
--print("No")
--self.Collision = false
end

function Annie:CalculateEndPos(startPos, placementPos, unitPos, range)
    if range > 0 then
        if GetDistance(unitPos, placementPos) > range then
            local endPos = startPos - Vector(startPos - placementPos):Normalized() * range
            return endPos
        else
            local endPos = placementPos
            return endPos
        end
    else
        local endPos = unitPos
        return endPos
    end
end

function Annie:ProcessSpell(units)
    for i = 1, #units do
        local unit = units[i]
        if unit and unit.activeSpell and unit.activeSpell.isChanneling then
            --print(unit.activeSpell.name)
            if self.SpellsE and self.SpellsE[unit.activeSpell.name] then
                local startPos = Vector(unit.activeSpell.startPos)
                local placementPos = Vector(unit.activeSpell.placementPos)
                local unitPos = Vector(unit.pos)
                local sRange = self.SpellsE[unit.activeSpell.name].range
                local endPos = self:CalculateEndPos(startPos, placementPos, unitPos, sRange)
                spell = {source = unitPos, startPos = startPos, endPos = endPos, name = unit.activeSpell.name, startTime = Game.Timer()}
                table.insert(self.Detected, spell)
            end
        end
    end
end

function Annie:AntiGapcloser()
    for i, antigap in pairs(GetEnemyHeroes()) do
        if self.AnnieMenu.AntiGapcloser.UseE:Value() then
            if IsReady(_E) then
                if ValidTarget(antigap, self.AnnieMenu.AntiGapcloser.DistanceE:Value()) then
                    LocalControlCastSpell(HK_E)
                end
            end
        end
    end
end

function Annie:AutoE()
    for i = 1, Game.HeroCount() do
        local h = Game.Hero(i);
        if h.isEnemy then
            if h.activeSpell.valid and h.activeSpell.range > 0 then
                local t = self.Spells[h.activeSpell.name]
                if t then
                    if IS[h.networkID] == nil then
                        IS[h.networkID] = {
                            sPos = h.activeSpell.startPos,
                            ePos = h.activeSpell.startPos + Vector(h.activeSpell.startPos, h.activeSpell.placementPos):Normalized() * h.activeSpell.range,
                            radius = self.Spells[h.activeSpell.name].radius,
                            speed = self.Spells[h.activeSpell.name].speed,
                            startTime = h.activeSpell.startTime,
                            name = h.activeSpell.name,
                            delay = self.Spells[h.activeSpell.name].delay
                        }
                    end
                end
            end
        end
    end
    for key, v in pairs(IS) do
        local SpellHit = v.sPos + Vector(v.sPos, v.ePos):Normalized() * GetDistance(myHero.pos, v.sPos)
        local SpellPosition = v.sPos + Vector(v.sPos, v.ePos):Normalized() * (v.speed * (Game.Timer() - v.startTime) * 3)
        local dodge = SpellPosition + Vector(v.sPos, v.ePos):Normalized() * (v.speed * 0.1)
        if GetDistanceSqr(SpellHit, SpellPosition) <= GetDistanceSqr(dodge, SpellPosition) and GetDistance(SpellHit, v.sPos) - v.radius - myHero.boundingRadius <= GetDistance(v.sPos, v.ePos) then
            if GetDistanceSqr(myHero.pos, SpellHit) < (v.radius + myHero.boundingRadius) ^ 2 then
                if self.AnnieMenu.AutoE.UseE:Value() then
                    if IsReady(_E) then
                        LocalControlCastSpell(HK_E)
                    end
                end
            end
        end
        if (GetDistanceSqr(SpellPosition, v.sPos) >= GetDistanceSqr(v.sPos, v.ePos)) then
            IS[key] = nil
        end
    end
end

function Annie:KillSteal()
    for i, enemy in pairs(GetEnemyHeroes()) do
        if self.AnnieMenu.KillSteal.UseIgnite:Value() then
            local IgniteDmg = (55 + 25 * myHero.levelData.lvl)
            if ValidTarget(enemy, 600) and enemy.health + enemy.shieldAD < IgniteDmg then
                if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and IsReady(SUMMONER_1) then
                    Control.CastSpell(HK_SUMMONER_1, enemy)
                elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and IsReady(SUMMONER_2) then
                    Control.CastSpell(HK_SUMMONER_2, enemy)
                end
            end
        end
    end
end

function GetSpellRName()
    return myHero:GetSpellData(_R).name
end

function Annie:Tibbers()
    --print(GetSpellRName()) -- AnnieRController
    --GetGameObjects() -- Tibbers distance 2100
    if GetSpellRName() == "AnnieRController" then
        if self.AnnieMenu.Tibbers.UseTibbers:Value() then
            local minHealth = 50000
            local minHealthEnemy
            
            for i, enemy in pairs(GetEnemyHeroes()) do
                if ValidTarget(enemy, 2100) and enemy.health < minHealth then
                    minHealth = enemy.health
                    minHealthEnemy = enemy
                end
            end
            
            if minHealthEnemy then
                if not IsImmune(minHealthEnemy) then
                    if IsReady(_R) and GetSpellRName() == "AnnieRController" and (self.Collision == false or self.CollisionSpellName == "YasuoWMovingWall") then
                        if ValidTarget(minHealthEnemy, 2100) then
                            DelayAction(function()
                                LocalControlCastSpell(HK_R, minHealthEnemy)
                            end, 0.4)
                            if self.AnnieMenu.Tibbers.UseET:Value() then
                                if IsReady(_E) then
                                    LocalControlCastSpell(HK_E)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function Annie:HasStun()
    if myHero.hudAmmo == myHero.hudMaxAmmo then
        return true
    end
    return false
end

function Annie:Harass()
    
    local targetBC = GOS:GetTarget(550, "AP")
    
    if self.AnnieMenu.Harass.UseBC:Value() then
        if GetItemSlot(myHero, 3144) > 0 and ValidTarget(targetBC, 550) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3144)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3144)], targetBC)
            end
        end
    end
    
    local targetHG = GOS:GetTarget(700, "AP")
    
    if self.AnnieMenu.Harass.UseHG:Value() then
        if GetItemSlot(myHero, 3146) > 0 and ValidTarget(targetHG, 700) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], targetHG)
            end
        end
    end
    
    local targetQ = GOS:GetTarget(AnnieQ.range, "AP")
    local targetW = GOS:GetTarget(AnnieW.range, "AP")
    local targetR = GOS:GetTarget(AnnieR.range, "AP")
    
    if targetR then
        if not IsImmune(targetR) then
            if self.AnnieMenu.Harass.UseRS:Value() then
                if self:HasStun() then
                    if IsReady(_R) then
                        if ValidTarget(targetR, AnnieR.range) then
                            DelayAction(function()
                                LocalControlCastSpell(HK_R, targetR)
                            end, 0.4)
                            if self.AnnieMenu.Harass.UseER:Value() then
                                if IsReady(_E) then
                                    LocalControlCastSpell(HK_E)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    if targetQ then
        if not IsImmune(targetQ) then
            if self.AnnieMenu.Harass.UseQS:Value() then
                if self:HasStun() then
                    if self.CollisionSpellName == "YasuoWMovingWall" then
                        
                        else
                        if IsReady(_Q) then
                            if ValidTarget(targetQ, AnnieQ.range) then
                                LocalControlCastSpell(HK_Q, targetQ)
                            end
                        end
                    end
                end
            end
        end
    end
    
    if targetQ then
        if not IsImmune(targetQ) then
            if self.AnnieMenu.Harass.UseQ:Value() then
                if self.CollisionSpellName == "YasuoWMovingWall" then
                    
                    else
                    if IsReady(_Q) then
                        if ValidTarget(targetQ, AnnieQ.range) then
                            LocalControlCastSpell(HK_Q, targetQ)
                        end
                    end
                end
            end
        end
    end
    
    if targetW then
        if not IsImmune(targetW) then
            if self.AnnieMenu.Harass.UseW:Value() then
                if self.CollisionSpellName == "YasuoWMovingWall" then
                    
                    else
                    if IsReady(_W) then
                        if ValidTarget(targetW, AnnieW.range) then
                            LocalControlCastSpell(HK_W, targetW)
                        end
                    end
                end
            end
        end
    end
    
    if self.AnnieMenu.Harass.UseQM:Value() then
        for i = 1, LocalGameMinionCount() do
            local minion = LocalGameMinion(i)
            if minion and minion.isEnemy then
                if IsReady(_Q) then
                    --local wRange = FizzW.range + myHero.boundingRadius + minion.boundingRadius - 35
                    local wRange = AnnieQ.range + myHero.boundingRadius + minion.boundingRadius - 35
                    if ValidTarget(minion, wRange) then
                        if minion.health < QDmg() then
                            LocalControlCastSpell(HK_Q, minion)
                        end
                    end
                end
            end
        end
    end
end

function Annie:LaneClear()
    if self.AnnieMenu.LaneClear.UseQ:Value() then
        for i = 1, LocalGameMinionCount() do
            local minion = LocalGameMinion(i)
            if minion and minion.isEnemy then
                if IsReady(_Q) then
                    --local wRange = FizzW.range + myHero.boundingRadius + minion.boundingRadius - 35
                    local wRange = AnnieQ.range + myHero.boundingRadius + minion.boundingRadius - 35
                    if ValidTarget(minion, wRange) then
                        if minion.health < QDmg() then
                            LocalControlCastSpell(HK_Q, minion)
                        end
                    end
                end
            end
        end
    end
end

function Annie:Combo()
    local targetBC = GOS:GetTarget(550, "AP")
    
    if self.AnnieMenu.Combo.UseBC:Value() then
        if GetItemSlot(myHero, 3144) > 0 and ValidTarget(targetBC, 550) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3144)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3144)], targetBC)
            end
        end
    end
    
    local targetHG = GOS:GetTarget(700, "AP")
    
    if self.AnnieMenu.Combo.UseHG:Value() then
        if GetItemSlot(myHero, 3146) > 0 and ValidTarget(targetHG, 700) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], targetHG)
            end
        end
    end
    
    local targetQ = GOS:GetTarget(AnnieQ.range, "AP")
    local targetW = GOS:GetTarget(AnnieW.range, "AP")
    local targetR = GOS:GetTarget(AnnieR.range, "AP")
    
    if targetR then
        if not IsImmune(targetR) then
            if self.AnnieMenu.Combo.UseRS:Value() then
                if self:HasStun() then
                    if IsReady(_R) then
                        if ValidTarget(targetR, AnnieR.range) then
                            DelayAction(function()
                                LocalControlCastSpell(HK_R, targetR)
                            end, 0.4)
                            if self.AnnieMenu.Combo.UseER:Value() then
                                if IsReady(_E) then
                                    LocalControlCastSpell(HK_E)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    if targetR then
        if not IsImmune(targetR) then
            if self.AnnieMenu.Combo.UseR:Value() then
                if IsReady(_R) then
                    if ValidTarget(targetR, AnnieR.range) then
                        DelayAction(function()
                            LocalControlCastSpell(HK_R, targetR)
                        end, 0.4)
                        if self.AnnieMenu.Combo.UseER:Value() then
                            if IsReady(_E) then
                                LocalControlCastSpell(HK_E)
                            end
                        end
                    end
                end
            end
        end
    end
    
    if targetQ then
        if not IsImmune(targetQ) then
            if self.AnnieMenu.Combo.UseQ:Value() then
                if self.CollisionSpellName == "YasuoWMovingWall" then
                    
                    else
                    if IsReady(_Q) then
                        if ValidTarget(targetQ, AnnieQ.range) then
                            LocalControlCastSpell(HK_Q, targetQ)
                        end
                    end
                end
            end
        end
    end
    
    if targetW then
        if not IsImmune(targetW) then
            if self.AnnieMenu.Combo.UseW:Value() then
                if self.CollisionSpellName == "YasuoWMovingWall" then
                    
                    else
                    if IsReady(_W) then
                        if ValidTarget(targetW, AnnieW.range) then
                            LocalControlCastSpell(HK_W, targetW)
                        end
                    end
                end
            end
        end
    end
end

function OnLoad()
    Annie()
end
