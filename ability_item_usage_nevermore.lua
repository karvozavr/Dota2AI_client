_G.state = "laning"

local Constant = require(GetScriptDirectory().."/dev/constant_each_side")
local DotaBotUtility = require(GetScriptDirectory().."/utility")
require(GetScriptDirectory().."/util/json")


LastEnemyHP = 1000

EnemyTowerPosition = Vector(1024,320)
AllyTowerPosition = Vector(-1656,-1512)

LastEnemyTowerHP = 1300

LastDecesion = -1000

LastKill = 0

DeltaTime = 300 / 2

GotOrder = false

creep_zero_padding = {0,0,0,0,0,0,0}

first = "true"


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
            pos[1],
            pos[2]
        })
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
        self_pos[1],
        self_pos[2]
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

    msg["enemy_hero_input"] = {0,0,0,0,0,0,0,0,0}
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
            enemypos[1],
            enemypos[2]
        }
    end

    

    msg = {["state"] = msg,["reward"] = reward,["first"] = first}

    first = "false"



    encode_msg = Json.Encode(msg)
        
    local req = CreateHTTPRequest( ":8080" )
    req:SetHTTPRequestRawPostBody("application/json", encode_msg)
    req:Send( function( result )
        print( "GET response:\n" )
        for k,v in pairs( result ) do
            if k == "Body" then
                ApplyOrder(v)
                print( string.format( "%s : %s\n", k, v ) )
            end
            
        end
    end )
end

local function ClipTime(t)
    local ub = 3
    if t > ub then
        return ub
    else
        return t
    end
end

function OutputToConsole()
    local npcBot = GetBot()
    local enemyBotTbl = GetUnitList(UNIT_LIST_ENEMY_HEROES)
    local enemyBot = nil
    if enemyBotTbl ~= nil then
        enemyBot = enemyBotTbl[1]
    end
    local MyKill = GetHeroKills(npcBot:GetPlayerID())

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

    local Reward = (npcBot:GetHealth() - MyLastHP)
    - (EnemyHP - LastEnemyHP) * 10
    + (MyKill - LastKill) * 10000
    + GoldReward

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
end

LastTimeOutput = DotaTime()

function ApplyOrder(s)
    local action = tonumber(s)
    _G.LaningDesire = 0.0
    _G.AttackDesire = 0.0
    _G.RetreatDesire = 0.0
    if action == 0 then
        _G.LaningDesire = 1.0
    elseif action == 1 then
        _G.AttackDesire = 1.0
    elseif action == 2 then
        _G.RetreatDesire = 1.0
    end
    print("Apply Order",s)
end

LastTimeApplyOrder = DotaTime()

function BuybackUsageThink()
    if (GetGameState() == GAME_STATE_GAME_IN_PROGRESS or GetGameState() == GAME_STATE_PRE_GAME) then
        --print(math.abs(DotaTime() - LastTimeOutput))
        if math.abs(DotaTime() - LastTimeOutput) > 0.5 then
            OutputToConsole()
            LastTimeOutput = DotaTime()
        end
    end
end