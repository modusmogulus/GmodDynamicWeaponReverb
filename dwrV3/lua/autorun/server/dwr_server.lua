print("[DWRV3] Server loaded.")

util.AddNetworkString("dwr_EntityFireBullets_networked")
util.AddNetworkString("dwr_EntityEmitSound_networked")
util.AddNetworkString("dwr_sync_blacklist")

local networkSoundsConvar = CreateConVar("sv_dwr_network_sounds", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Network server-only gunshots to clients in order for them to get processed as well. Introduces delay to weapon firing.")
local networkGunshotsConvar = CreateConVar("sv_dwr_network_reverb_pas", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Network gunshot events only to people that are considered in range by the game.")
local blacklist = {}

if not file.Read("dwr_sv_weapon_blacklist.json") or #file.Read("dwr_sv_weapon_blacklist.json") == 0 then
    print("[DWRV3] Created the blacklist file.")
    file.Write("dwr_sv_weapon_blacklist.json", util.TableToJSON({}))
else
    print("[DWRV3] Loaded the blacklist file.")
    blacklist = util.JSONToTable(file.Read("dwr_sv_weapon_blacklist.json"))
end

local function changeBlacklist(action, weaponClass)
    local JSONData = file.Read("dwr_sv_weapon_blacklist.json")
    local converted = util.JSONToTable(JSONData) or {}

    if action == "remove" then 
        print("Removed " .. weaponClass .. " from the blacklist.")
        converted[weaponClass] = nil
    end

    if action == "add" then
        print("Added " .. weaponClass .. " to the blacklist.")
        converted[weaponClass] = true
    end

    if action == "clear" then 
        print("Blacklist cleared.")
        converted = {}
    end

    blacklist = converted
    file.Write("dwr_sv_weapon_blacklist.json", util.TableToJSON(blacklist))

    net.Start("dwr_sync_blacklist")
        net.WriteTable(blacklist)
    net.Broadcast()
end

local function removeWeaponFromBlacklist(ply, cmd, args)
    if not args[1] then print("Missing weapon class.") return end
    changeBlacklist("remove", args[1])
end
concommand.Add("sv_dwr_blacklist_remove", removeWeaponFromBlacklist, nil, "Remove your current weapon from the blacklist.")

local function addWeaponToBlacklist(ply, cmd, args)
    if not args[1] then print("Missing weapon class.") return end
    changeBlacklist("add", args[1])
end
concommand.Add("sv_dwr_blacklist_add", addWeaponToBlacklist, nil, "Blacklist your current weapon from being affected by this mod. (clients will be able to override this)")

local function clearBlacklist(ply, cmd, args)
    changeBlacklist("clear", nil)
end
concommand.Add("sv_dwr_blacklist_clear", clearBlacklist, nil, "Clear the blacklist from anything and everything.")

hook.Add("PlayerSpawn", "dwr_blacklist_sync", function() 
    net.Start("dwr_sync_blacklist")
        net.WriteTable(blacklist)
    net.Broadcast()
end)

local function writeVectorUncompressed(vector)
    net.WriteFloat(vector.x)
    net.WriteFloat(vector.y)
    net.WriteFloat(vector.z)
end

local function getSuppressed(weapon, weaponClass)
    if string.StartWith(weaponClass, "arccw_") and weapon:GetBuff_Override("Silencer") then return true
    elseif string.StartWith(weaponClass, "arc9_") and isfunction(weapon.GetProcessedValue) and weapon:GetProcessedValue("Silencer") then return true
    elseif string.StartWith(weaponClass, "tfa_") and weapon:GetSilenced() then return true
    elseif string.StartWith(weaponClass, "mg_") or weaponClass == mg_valpha then
        if not weapon.GetAllAttachmentsInUse then return false end
        for slot, attachment in pairs(weapon:GetAllAttachmentsInUse()) do
            if string.find(attachment.ClassName, "silence") or string.find(attachment.ClassName, "suppress") then return true end
        end
    elseif string.StartWith(weaponClass, "cw_") then
        if weapon.ActiveAttachments != nil then
            for k, v in pairs(weapon.ActiveAttachments) do
                if v == false then continue end
                local att = CustomizableWeaponry.registeredAttachmentsSKey[k]
                if att.isSuppressor then
                    return true
                end
            end
        end
    end

    return false
end

local function networkGunshotEvent(data)
    net.Start("dwr_EntityFireBullets_networked", false)
        writeVectorUncompressed(data.Src)
        writeVectorUncompressed(data.Dir)
        writeVectorUncompressed(data.Vel) -- velocity
        writeVectorUncompressed(data.Spread)
        net.WriteString(data.Ammotype)
        net.WriteBool(data.isSuppressed)
        net.WriteEntity(data.Entity) -- to exclude them in MP. they're going to get hook data anyway
    if networkGunshotsConvar:GetBool() then net.SendPAS(data.Src) else net.Broadcast() end
end

function tacrp_dwr_detour(args)
    local bullet = args[2]
    local attacker = bullet.Attacker

    if attacker.dwr_shotThisTick == nil then attacker.dwr_shotThisTick = false end
    if attacker.dwr_shotThisTick then return end
    if table.Count(bullet.Damaged) != 0 or bullet.dwr_detected then return end

    local weapon = bullet.Weapon
    local weaponClass = weapon:GetClass()
    local isSuppressed = getSuppressed(weapon, weaponClass)
    local pos = attacker:GetShootPos()
    local ammotype = bullet.Weapon.Primary.Ammo
    local dir = bullet.Vel:Angle():Forward()
    local vel = bullet.Vel

    timer.Simple(0, function()
        local data = {}
        data.Src = pos
        data.Dir = dir
        data.Vel = vel
        data.Spread = vector_origin
        data.Ammotype = ammotype
        data.isSuppressed = isSuppressed
        data.Entity = attacker
        data.Weapon = attacker:GetActiveWeapon()
        networkGunshotEvent(data)
    end)
    bullet.dwr_detected = true
    attacker.dwr_shotThisTick = true

    timer.Simple(engine.TickInterval()*2, function() attacker.dwr_shotThisTick = false end)
end

function arc9_dwr_detour(args)
    local bullet = args[2]
    local attacker = bullet.Attacker

    if attacker.dwr_shotThisTick == nil then attacker.dwr_shotThisTick = false end
    if attacker.dwr_shotThisTick then return end
    if table.Count(bullet.Damaged) != 0 or bullet.dwr_detected then return end

    local weapon = bullet.Weapon
    local weaponClass = weapon:GetClass()
    local isSuppressed = getSuppressed(weapon, weaponClass)
    local pos = attacker:GetShootPos()
    local ammotype = bullet.Weapon.Primary.Ammo
    local dir = bullet.Vel:Angle():Forward()
    local vel = bullet.Vel

    timer.Simple(0, function()
        local data = {}
        data.Src = pos
        data.Dir = dir
        data.Vel = vel
        data.Spread = vector_origin
        data.Ammotype = ammotype
        data.isSuppressed = isSuppressed
        data.Entity = attacker
        data.Weapon = attacker:GetActiveWeapon()
        networkGunshotEvent(data)
    end)
    bullet.dwr_detected = true
    attacker.dwr_shotThisTick = true

    timer.Simple(engine.TickInterval()*2, function() attacker.dwr_shotThisTick = false end)
end

hook.Add("InitPostEntity", "dwr_create_physbul_hooks", function()
    if TacRP then
        local function create_tacrp_detour(a)
            return function(...)
                local args = { ... }
                tacrp_dwr_detour(args)
                return a(...)
            end
        end
        TacRP.SendBullet = create_tacrp_detour(TacRP.SendBullet)
    end

    if ARC9 then
        local function create_arc9_detour(a)    -- a = old function
          return function(...)
            local args = { ... }
            arc9_dwr_detour(args)
            return a(...)
          end
        end
        ARC9.SendBullet = create_arc9_detour(ARC9.SendBullet)
    end

    if TFA then
        hook.Add("Think", "dwr_detecttfaphys", function()
            local latestPhysBullet = TFA.Ballistics.Bullets["bullet_registry"][table.Count(TFA.Ballistics.Bullets["bullet_registry"])]
            if latestPhysBullet == nil then return end
            if latestPhysBullet["dwr_detected"] then return end

            local weapon = latestPhysBullet["inflictor"]
            local weaponClass = weapon:GetClass()

            local isSuppressed = getSuppressed(weapon, weaponClass)
            local pos = latestPhysBullet["bul"]["Src"]
            local ammotype = weapon.Primary.Ammo
            local dir = latestPhysBullet["velocity"]:Angle():Forward()
            local vel = latestPhysBullet["velocity"]
            local entity = latestPhysBullet["inflictor"]:GetOwner()

            if entity.dwr_shotThisTick == nil then entity.dwr_shotThisTick = false end
            if entity.dwr_shotThisTick then return end
            entity.dwr_shotThisTick = true
            timer.Simple(engine.TickInterval()*2, function() entity.dwr_shotThisTick = false end)

            local data = {}
            data.Src = pos
            data.Dir = dir
            data.Vel = vel
            data.Spread = Vector(0,0,0)
            data.Ammotype = ammotype
            data.isSuppressed = isSuppressed
            data.Entity = latestPhysBullet["inflictor"]:GetOwner()
            data.Weapon = latestPhysBullet["inflictor"]
            networkGunshotEvent(data)

            latestPhysBullet["dwr_detected"] = true
        end)
    end

    if ArcCW then
        hook.Add("Think", "dwr_detectarccwphys", function()
            if ArcCW.PhysBullets[table.Count(ArcCW.PhysBullets)] == nil then return end
            local latestPhysBullet = ArcCW.PhysBullets[table.Count(ArcCW.PhysBullets)]
            if latestPhysBullet["dwr_detected"] then return end
            if latestPhysBullet["Attacker"] == Entity(0) then return end
            local entity = latestPhysBullet["Attacker"]

            if entity.dwr_shotThisTick == nil then entity.dwr_shotThisTick = false end
            if entity.dwr_shotThisTick then return end
            entity.dwr_shotThisTick = true
            timer.Simple(engine.TickInterval()*2, function() entity.dwr_shotThisTick = false end)

            local weapon = latestPhysBullet["Weapon"]
            local weaponClass = weapon:GetClass()

            local isSuppressed = getSuppressed(weapon, weaponClass)
            local pos = latestPhysBullet["Pos"]
            local ammotype = weapon.Primary.Ammo
            local dir = latestPhysBullet["Vel"]:Angle():Forward()
            local vel = latestPhysBullet["Vel"]

            local data = {}
            data.Src = pos
            data.Dir = dir
            data.Vel = vel
            data.Spread = Vector(0,0,0)
            data.Ammotype = ammotype
            data.isSuppressed = isSuppressed
            data.Entity = latestPhysBullet["Attacker"]
            data.Weapon = latestPhysBullet["Attacker"]:GetActiveWeapon()
            networkGunshotEvent(data)
            
            latestPhysBullet["dwr_detected"] = true
        end)
    end

    if MW_ATTS then -- global var from mw2019 sweps
        hook.Add("OnEntityCreated", "dwr_detectmw2019phys", function(ent)
            if ent:GetClass() != "mg_sniper_bullet" and ent:GetClass() != "mg_slug" then return end
            timer.Simple(0, function()
                local attacker = ent:GetOwner()
                local entity = attacker
                local weapon = attacker:GetActiveWeapon()
                local pos = ent.LastPos
                local dir = (ent:GetPos() - ent.LastPos):GetNormalized()
                local vel = ent:GetAngles():Forward() * ent.Projectile.Speed
                local isSuppressed = getSuppressed(weapon, weapon:GetClass())
                local ammotype = "none"
                if weapon.Primary and weapon.Primary.Ammo then ammotype = weapon.Primary.Ammo end

                if entity.dwr_shotThisTick == nil then entity.dwr_shotThisTick = false end
                if entity.dwr_shotThisTick then return end
                entity.dwr_shotThisTick = true
                timer.Simple(engine.TickInterval()*2, function() entity.dwr_shotThisTick = false end)

                local data = {}
                data.Src = pos
                data.Dir = dir
                data.Vel = vel
                data.Spread = Vector(0,0,0)
                data.Ammotype = ammotype
                data.isSuppressed = isSuppressed
                data.Entity = attacker
                data.Weapon = attacker:GetActiveWeapon()

                networkGunshotEvent(data)
            end)
        end)
    end

    hook.Remove("InitPostEntity", "dwr_create_physbul_hooks")
end)

local arccw_bullet_enable = GetConVar("arccw_bullet_enable")
local arc9_bullet_physics = GetConVar("arc9_bullet_physics")
local tacrp_physbullet = GetConVar("tacrp_physbullet")

hook.Add("EntityFireBullets", "dwr_EntityFireBullets", function(attacker, data)
    if data.Spread.z == 0.125 then return end -- for my blood decal workaround for mw sweps
    if data.AmmoType == "grenadeFragments" then return end -- rfs support

    local entity = NULL
    local weapon = NULL
    local weaponIsWeird = false
    local isSuppressed = false
    local ammotype = "none"

    if attacker:IsPlayer() or attacker:IsNPC() then
        entity = attacker
        weapon = entity:GetActiveWeapon()
    else
        weapon = attacker
        entity = weapon:GetOwner()
        if entity == NULL then 
            entity = attacker
            weaponIsWeird = true
        end
    end

    if not weaponIsWeird and weapon != NULL and entity.GetShootPos != nil then -- should solve all of the issues caused by external bullet sources (such as the turret mod)
        local weaponClass = weapon:GetClass()
        local entityShootPos = entity:GetShootPos()

        if weaponClass == "mg_arrow" then return end -- mw2019 sweps crossbow
        if weaponClass == "mg_sniper_bullet" and data.Spread == Vector(0,0,0) then return end -- physical bullets in mw2019
        if weaponClass == "mg_slug" and data.Spread == Vector(0,0,0) then return end -- physical bullets in mw2019

        if data.Distance < 200 then return end -- melee

        if string.StartWith(weaponClass, "arccw_") then
            if data.Distance == 20000 then -- grenade launchers in arccw
                return
            end
            if arccw_bullet_enable:GetInt() == 1 and data.Spread == vector_origin then -- bullet physics in arcw
                return
            end
        end

        if string.StartWith(weaponClass, "arc9_") then
            if arc9_bullet_physics:GetInt() == 1 and data.Spread == vector_origin then -- bullet physics in arc9
                return
            end
        end

        if string.StartWith(weaponClass, "tacrp_") then
            if tacrp_physbullet:GetInt() == 1 and data.Spread == vector_origin then -- bullet physics in arc9
                return
            end
        end

        if game.GetTimeScale() < 1 and data.Spread == vector_origin and data.Tracer == 0 then return end -- FEAR bullet time

        if entity.dwr_shotThisTick == nil then entity.dwr_shotThisTick = false end
        if entity.dwr_shotThisTick then return end
        entity.dwr_shotThisTick = true
        timer.Simple(engine.TickInterval()*2, function() entity.dwr_shotThisTick = false end)
                                                                                             
        if #data.AmmoType > 2 then ammotype = data.AmmoType elseif weapon.Primary then ammotype = weapon.Primary.Ammo end
        isSuppressed = getSuppressed(weapon, weaponClass)
    end

    local dwr_data = {}
    dwr_data.Src = data.Src
    dwr_data.Dir = data.Dir
    dwr_data.Vel = Vector(0,0,0)
    dwr_data.Spread = data.Spread
    dwr_data.Ammotype = ammotype
    dwr_data.isSuppressed = isSuppressed
    dwr_data.Entity = entity
    dwr_data.Weapon = weapon
    networkGunshotEvent(dwr_data)
end)

-- Can't get it working reliably for all scenarios. I know for a fact it works well for weapons so I'll leave it at that.
hook.Add("EntityEmitSound", "dwr_EntityEmitSound", function(data)
    if not networkSoundsConvar:GetBool() then return end
    if not string.find(data.SoundName, "weapon") then return end
    if string.find(data.SoundName, "rpg") then return end

    local src = data.Entity:GetPos()
    if data.Entity:IsPlayer() or data.Entity:IsNPC() then src = data.Entity:GetShootPos() end
    data.Pos = src

    net.Start("dwr_EntityEmitSound_networked")
        net.WriteTable(data) -- send each element separately later
    net.Broadcast()

    data.Volume = 0
    return true
end)
