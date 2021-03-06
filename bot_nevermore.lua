_G.state = "laning"

local Constant = require(GetScriptDirectory().."/dev/constant_each_side")
local DotaBotUtility = require(GetScriptDirectory().."/utility")
require(GetScriptDirectory().."/util/json")

-- You have to use: luarocks-5.1 install lua-requests 
-- But you cant!!! DotA lua VM doesn't support any builtin features.
--Request = require "requests"

LastEnemyHP = 1000

EnemyTowerPosition = Vector(1024,320)
AllyTowerPosition = Vector(-1656,-1512)

LastEnemyTowerHP = 1300

LastDecesion = -1000

LastKill = 0

LastDeath = 0

LastXPNeededToLevel = 0

DeltaTime = 300 / 2

GotOrder = false

creep_zero_padding = {0,0,0,0,0,0,0}

first = "true"

punish = 0

vec_delta = Vector(0,0,0)

map_div  = 7000

msg_done = false

seq_num = 0

local npcBot = GetBot()

local raze1 = npcBot:GetAbilityByName("nevermore_shadowraze1")
local raze2 = npcBot:GetAbilityByName("nevermore_shadowraze2")
local raze3 = npcBot:GetAbilityByName("nevermore_shadowraze3")

function creeps_info(creeps)
    local ret = {}
    for creep_k,creep in pairs(creeps)
    do 
        pos = creep:GetLocation()
        table.insert(ret, {
            creep:GetAttackDamage(),
            creep:GetHealth(),
            creep:GetMaxHealth(),
            creep:GetArmor(),
            creep:GetAttackRange(),
            pos[1] / map_div,
            pos[2] / map_div
        })
    end
    if #ret == 0 then
        table.insert(ret,creep_zero_padding)
    end
    return ret
end

function Loop(reward)
    local bot = GetBot()

    lastUpdate = GameTime()
        
    local msg = {}

    if(GetTeam() == TEAM_RADIANT) then
        msg["side"] = "Radiant"
    else
        msg["side"] = "Dire"
    end

    local raze1_dmg = 0
    if raze1:IsFullyCastable() then
        raze1_dmg = raze1:GetAbilityDamage()
    end

    local raze2_dmg = 0
    if raze2:IsFullyCastable() then
        raze2_dmg = raze2:GetAbilityDamage()
    end

    local raze3_dmg = 0
    if raze3:IsFullyCastable() then
        raze3_dmg = raze3:GetAbilityDamage()
    end

    --My atk,My Hp,Hp ub,position x,position y
    self_pos = bot:GetLocation()
    self_input = {
        bot:GetAttackDamage(),
        bot:GetAttackSpeed(),
        bot:GetLevel(),
        bot:GetHealth(),
        bot:GetMaxHealth(),
        bot:GetMana(),
        bot:GetMaxMana(),
        bot:GetFacing(),
        raze1_dmg,
        raze2_dmg,
        raze3_dmg,
        self_pos[1] / map_div,
        self_pos[2] / map_div
    }
        
    msg["self_input"] = self_input

    local EnemyCreeps = bot:GetNearbyCreeps(1000,true)
    if(EnemyCreeps ~= nil) then
        msg["ally_input"] = creeps_info(EnemyCreeps)
    else
        msg["ally_input"] = creep_zero_padding
    end

    local AllyCreeps = bot:GetNearbyCreeps(1000,false)
    if(AllyCreeps ~= nil) then
        msg["enemy_input"] = creeps_info(AllyCreeps)
    else
        msg["enemy_input"] = creep_zero_padding
    end        

    local enemyBotTbl = GetUnitList(UNIT_LIST_ENEMY_HEROES)
    local enemyBot = nil
    if enemyBotTbl ~= nil then
        enemyBot = enemyBotTbl[1]
    end

    msg["enemy_hero_input"] = {0,0,0,0,0,0,0,0,0,0}
    if(enemyBot ~= nil) then
        enemypos = enemyBot:GetLocation()
        msg["enemy_hero_input"] = {
            enemyBot:GetAttackDamage(),
            enemyBot:GetAttackSpeed(),
            enemyBot:GetLevel(),
            enemyBot:GetHealth(),
            enemyBot:GetMaxHealth(),
            enemyBot:GetMana(),
            enemyBot:GetMaxMana(),
            enemyBot:GetFacing(),
            enemypos[1] / map_div,
            enemypos[2] / map_div
        }
    end

    local _end = "false"

    if GetGameState() == GAME_STATE_POST_GAME then
        _end = "true"
        print("Bot: the game has ended.")
    end

    msg = {["state"] = msg,
           ["reward"] = reward,
           ["first"] = first,
           ["done"] = _end,
           ["seq_num"] = seq_num}

    seq_num = seq_num + 1

    first = "false"



    encode_msg = Json.Encode(msg)
    send_state_message(encode_msg)

    local npcBot = GetBot()
    local loc = npcBot:GetLocation()

    print(loc,vec_delta)
    loc[1] = loc[1] + vec_delta[1]
    loc[2] = loc[2] + vec_delta[2]
    npcBot:Action_MoveToLocation(loc)
    
end

-- Send JSON with current state info.
-- @param message JSON state info
function send_state_message(message)
        

    local req = CreateHTTPRequest(':5000')
    req:SetHTTPRequestRawPostBody('application/json', message)
    req:Send( 
        function(result)
            for k, v in pairs( result ) do
                if k == 'Body' then
                    print( string.format( "%s : %s\n", k, v ) )
                    action_recieved(Json.Decode(v))
                end 
            end
        end
    )
end

local current_action = nil
local action_ready = false

-- On action recieved callback.
-- @param action new action
function action_recieved(action)
    print('action_recieved event', action['test2'])

    current_action = action
    action_ready = true
end

local function ClipTime(t)
    local ub = 3
    if t > ub then
        return ub
    else
        return t
    end
end

function process_environment_state()
    local npcBot = GetBot()
    local enemyBotTbl = GetUnitList(UNIT_LIST_ENEMY_HEROES)
    local enemyBot = nil
    if enemyBotTbl ~= nil then
        enemyBot = enemyBotTbl[1]
    end

    local myid = npcBot:GetPlayerID()

    local MyKill = GetHeroKills(myid)
    local MyDeath = GetHeroDeaths(myid)

    if(enemyBot ~= nil) then 
        npcBot:SetTarget(enemyBot)
    end
    local enemyTower = GetTower(TEAM_DIRE,TOWER_MID_1);
    local AllyTower = GetTower(TEAM_RADIANT,TOWER_MID_1);

    if MyLastGold == nil then
        MyLastGold = npcBot:GetGold()
    end

    local GoldReward = 0

    if npcBot:GetGold() - MyLastGold > 5 then
        GoldReward = (npcBot:GetGold() - MyLastGold)
    end

    local _XPNeededToLevel = npcBot:GetXPNeededToLevel()

    local XPreward = 0

    if _XPNeededToLevel < LastXPNeededToLevel then
        XPreward = LastXPNeededToLevel - _XPNeededToLevel
    end

    if MyLastHP == nil then
        MyLastHP = npcBot:GetHealth()
    end

    if LastEnemyHP == nil then
        LastEnemyHP = 600
    end

    if LastDistanceToEnemy == nil then
        LastDistanceToEnemy = 2000
    end

    if LastEnemyMaxHP == nil then
        LastEnemyMaxHP = 1000
    end
    
    if(enemyBot ~= nil) then 
        EnemyHP = enemyBot:GetHealth()
        EnemyMaxHP = enemyBot:GetMaxHealth()
    else
        
        EnemyHP = 600
        EnemyMaxHP = 1000
    end

    if(enemyBot ~= nil and enemyBot:CanBeSeen()) then
        DistanceToEnemy = GetUnitToUnitDistance(npcBot,enemyBot)
        if(DistanceToEnemy > 2000) then
            DistanceToEnemy = 2000
        end
    else
        DistanceToEnemy = LastDistanceToEnemy
    end

    if EnemyHP < 0 then
        EnemyHP = LastEnemyHP
        EnemyMaxHP = LastEnemyMaxHP
    end

    if AllyTowerLastHP == nil then
        AllyTowerLastHP = AllyTower:GetHealth()
    end

    if enemyTower:GetHealth() > 0 then
        EnemyTowerHP = enemyTower:GetHealth()
    else
        EnemyTowerHP = LastEnemyTowerHP
    end
    local AllyLaneFront = GetLaneFrontLocation(DotaBotUtility:GetEnemyTeam(),LANE_MID,0)
    local EnemyLaneFront = GetLaneFrontLocation(TEAM_RADIANT,LANE_MID,0)

    local DistanceToEnemyLane = GetUnitToLocationDistance(npcBot,EnemyLaneFront)
    local DistanceToAllyLane = GetUnitToLocationDistance(npcBot,AllyLaneFront)

    local DistanceToEnemyTower = GetUnitToLocationDistance(npcBot,EnemyTowerPosition)
    local DistanceToAllyTower = GetUnitToLocationDistance(npcBot,AllyTowerPosition)

    local DistanceToLane = (DistanceToEnemyLane + DistanceToAllyLane) / 2

    if LastDistanceToLane == nil then
        LastDistanceToLane = DistanceToLane
    end

    if(LastEnemyLocation == nil) then
        if(GetTeam() == TEAM_RADIANT) then
            LastEnemyLocation = Vector(6900,6650)
        else
            LastEnemyLocation = Vector(-7000,-7000)
        end
    end

    local EnemyLocation = Vector(0,0)
    if(enemyBot~=nil) then
        EnemyLocation = enemyBot:GetLocation()
    else
        EnemyLocation = LastEnemyLocation
    end
    
    local MyLocation = npcBot:GetLocation()

    local BotTeam = 0
    if(GetTeam() == TEAM_RADIANT) then
        BotTeam = 1
    else
        BotTeam = -1
    end

    if npcBot:DistanceFromFountain() == 0 and npcBot:GetHealth() == npcBot:GetMaxHealth() then
        punish = punish + 5
    end

    local EnemyHPReward = 0
    if (EnemyHP - LastEnemyHP) < 0 then
        EnemyHPReward = (EnemyHP - LastEnemyHP)-- * 2
    end

    local dist2line = PointToLineDistance(Vector(8000,8000),Vector(-8000,-8000),MyLocation)["distance"]

    local distance2mid = 0.1 * math.sqrt(MyLocation[1]*MyLocation[1] + MyLocation[2] * MyLocation[2])
        + dist2line
    --local distance2mid = dist2line
    
    print("dist2line", dist2line)

    --[[
    local __a = PointToLineDistance(Vector(7000,7000,0),Vector(-7000,-7000,0),MyLocation)
    for k,v in pairs(__a) do
        print("distane to mid lane",k,v)
    end
    ]]    

    if MyLastDistance2mid == nil then
        MyLastDistance2mid = distance2mid
    end

    local Reward = (npcBot:GetHealth() - MyLastHP) / 10.0
    --- EnemyHPReward
    -- + (MyKill - LastKill) * 100
    - (MyDeath - LastDeath) * 100
    -- + GoldReward
    + XPreward / 10.0
    --- punish
    - (MyLastDistance2mid - distance2mid) / 100.0
    -0.01

    print(Reward)
    Loop(Reward)

    if enemyTower:GetHealth() > 0 then
        LastEnemyTowerHP = enemyTower:GetHealth()
    end

    MyLastHP = npcBot:GetHealth()
    AllyTowerLastHP = AllyTower:GetHealth()
    LastEnemyHP = EnemyHP
    LastEnemyMaxHP = EnemyMaxHP
    MyLastGold = npcBot:GetGold()
    LastDistanceToLane = DistanceToLane
    LastDistanceToEnemy = DistanceToEnemy
    LastEnemyLocation = EnemyLocation
    LastKill = MyKill
    LastDeath = MyDeath
    LastXPNeededToLevel = _XPNeededToLevel
    MyLastDistance2mid = distance2mid
    punish = 0
end

LastTimeOutput = DotaTime()

function execute_action(action)
    -- local action = tonumber(s)
    -- _G.LaningDesire = 0.0
    -- _G.AttackDesire = 0.0
    -- _G.RetreatDesire = 0.0
    -- if action == 0 then
    --     _G.LaningDesire = 1.0
    -- elseif action == 1 then
    --     local enemyBotTbl = GetUnitList(UNIT_LIST_ENEMY_HEROES)
    --     local enemyBot = nil
    --     if enemyBotTbl ~= nil then
    --         enemyBot = enemyBotTbl[1]
    --     end
    --     if enemyBot == nil or GetUnitToUnitDistance(enemyBot,GetBot()) > 1600 then
    --         punish = punish + 20
    --     end
    --     _G.AttackDesire = 1.0
    -- elseif action == 2 then
    --     _G.RetreatDesire = 1.0
    -- end

    -- local thisBot = GetBot()
    -- thisBot:Action_MoveToLocation(  Vector(42, 22) )

    npcBot:ActionQueue_MoveToLocation(RandomVector(42.0))
    print("Execute action.", action)
    action_ready = false
end

LastTimeApplyOrder = DotaTime()

function Think()
    local _time = DotaTime()
    if (GetGameState() == GAME_STATE_GAME_IN_PROGRESS or GetGameState() == GAME_STATE_PRE_GAME or GetGameState() == GAME_STATE_POST_GAME) then
        --print(math.abs(DotaTime() - LastTimeOutput))

        if action_ready == true then
            execute_action(current_action)
        else 
            process_environment_state()
        end
    end
end
