print("[DWRV3] Server loaded.")

util.AddNetworkString("dwr_EntityFireBullets_networked")
util.AddNetworkString("dwr_EntityEmitSound_networked")

local networkSoundsConvar = CreateConVar("sv_dwr_network_sounds", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Network server-only gunshots to clients in order for them to get processed as well. Introduces delay to weapon firing.")
local networkGunshotsConvar = CreateConVar("sv_dwr_network_reverb_pas", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Network gunshot events only to people that are considered in range by the game.")
//local allowOverride = CreateConVar("sv_dwr_allow_weapon_override", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Allow weapons to alter the reverb. (Only works if the weapon devs support it)")

local function writeVectorUncompressed(vector)
    net.WriteFloat(vector.x)
    net.WriteFloat(vector.y)
    net.WriteFloat(vector.z)
end

local function getSuppressed(weapon, weaponClass)
    if string.StartWith(weaponClass, "arccw_") and weapon:GetBuff_Override("Silencer") then return true
    elseif string.StartWith(weaponClass, "tfa_") and weapon:GetSilenced() then return true
    elseif string.StartWith(weaponClass, "mg_") or weaponClass == mg_valpha then
        if weapon.Customization != nil then
            for name, attachments in pairs(weapon.Customization) do
                if name != "Muzzle" then continue end
                local attachment = weapon.Customization[name][weapon.Customization[name].m_Index]
                if string.find(attachment.Key, "silence") then
                    return true
                end
            end
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

hook.Add("InitPostEntity", "dwr_create_physbul_hooks", function()
    if ARC9 then
        function ARC9:SendBullet(bullet, attacker)
            if table.Count(bullet.Damaged) == 0 and not bullet.dwr_detected then
                local weapon = bullet.Weapon
                local weaponClass = weapon:GetClass()
                
                local isSuppressed = getSuppressed(weapon, weaponClass)
                local pos = attacker:GetShootPos()
                local ammotype = bullet.Weapon.Primary.Ammo
                local dir = bullet.Vel:Angle():Forward()
                local vel = bullet.Vel

                timer.Simple(0, function() 
                    net.Start("dwr_EntityFireBullets_networked")
                        writeVectorUncompressed(pos)
                        writeVectorUncompressed(dir)
                        writeVectorUncompressed(vel)
                        writeVectorUncompressed(Vector(0,0,0)) -- spread
                        net.WriteString(ammotype)
                        net.WriteBool(isSuppressed)
                        net.WriteEntity(attacker) -- to exclude them in MP. they're going to get hook data anyway
                    if networkGunshotsConvar:GetBool() then net.SendPAS(pos) else net.Broadcast() end
                end)
                bullet.dwr_detected = true
            end

            net.Start("ARC9_sendbullet", true)
            net.WriteVector(bullet.Pos)
            net.WriteAngle(bullet.Vel:Angle())
            net.WriteFloat(bullet.Vel:Length())
            net.WriteFloat(bullet.Travelled)
            net.WriteFloat(bullet.Drag)
            net.WriteFloat(bullet.Gravity)
            net.WriteBool(bullet.Indirect or false)
            net.WriteEntity(bullet.Weapon)
            net.WriteUInt(bullet.ModelIndex or 0, 8)

            if attacker and attacker:IsValid() and attacker:IsPlayer() and !game.SinglePlayer() then
                net.SendOmit(attacker)
            else
                if game.SinglePlayer() then
                    net.WriteEntity(attacker)
                end
                net.Broadcast()
            end
        end
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

            net.Start("dwr_EntityFireBullets_networked")
                writeVectorUncompressed(pos)
                writeVectorUncompressed(dir)
                writeVectorUncompressed(vel)
                writeVectorUncompressed(Vector(0,0,0)) -- spread
                net.WriteString(ammotype)
                net.WriteBool(isSuppressed)
                net.WriteEntity(latestPhysBullet["inflictor"]:GetOwner()) -- to exclude them in MP. they're going to get hook data anyway
            if networkGunshotsConvar:GetBool() then net.SendPAS(pos) else net.Broadcast() end

            latestPhysBullet["dwr_detected"] = true
        end)
    end

    if ArcCW then
        hook.Add("Think", "dwr_detectarccwphys", function()
            if ArcCW.PhysBullets[table.Count(ArcCW.PhysBullets)] == nil then return end
            local latestPhysBullet = ArcCW.PhysBullets[table.Count(ArcCW.PhysBullets)]
            if latestPhysBullet["dwr_detected"] then return end
            if latestPhysBullet["Attacker"] == Entity(0) then return end

            local weapon = latestPhysBullet["Weapon"]
            local weaponClass = weapon:GetClass()

            local isSuppressed = getSuppressed(weapon, weaponClass)
            local pos = latestPhysBullet["Pos"]
            local ammotype = weapon.Primary.Ammo
            local dir = latestPhysBullet["Vel"]:Angle():Forward()
            local vel = latestPhysBullet["Vel"]

            net.Start("dwr_EntityFireBullets_networked")
                writeVectorUncompressed(pos)
                writeVectorUncompressed(dir)
                writeVectorUncompressed(vel)
                writeVectorUncompressed(Vector(0,0,0)) -- spread
                net.WriteString(ammotype)
                net.WriteBool(isSuppressed)
                net.WriteEntity(latestPhysBullet["Attacker"]) -- to exclude them in MP. they're going to get hook data anyway
            if networkGunshotsConvar:GetBool() then net.SendPAS(pos) else net.Broadcast() end
            
            latestPhysBullet["dwr_detected"] = true
        end)
    end

    hook.Remove("InitPostEntity", "dwr_create_physbul_hooks")
end)

hook.Add("EntityFireBullets", "dwr_EntityFireBullets", function(attacker, data)
    if data.Spread.z == 0.125 then return end -- for my blood decal workaround for mw sweps

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

        if entity.dwr_shotThisTick == nil then entity.dwr_shotThisTick = false end
        if entity.dwr_shotThisTick then return end
        entity.dwr_shotThisTick = true
        timer.Simple(0, function() entity.dwr_shotThisTick = false end) -- the most universal fix for fuckin penetration and ricochet
    
        if #data.AmmoType > 2 then ammotype = data.AmmoType elseif weapon.Primary then ammotype = weapon.Primary.Ammo end

        if data.Distance < 200 then return end -- melee

        if string.StartWith(weaponClass, "arccw_") then
            if data.Distance == 20000 then -- grenade launchers in arccw
                return
            end
            if GetConVar("arccw_bullet_enable"):GetInt() == 1 and data.Spread == Vector(0, 0, 0) then -- bullet physics in arcw
                return
            end
        end

        if string.StartWith(weaponClass, "arc9_") then
            if GetConVar("arc9_bullet_physics"):GetInt() == 1 and data.Spread == Vector(0, 0, 0) then -- bullet physics in arc9
                return
            end
        end

        if game.GetTimeScale() < 1 and data.Spread == Vector(0,0,0) and data.Tracer == 0 then return end -- FEAR bullet time

        if weaponClass == "mg_arrow" then return end -- mw2019 sweps crossbow

        isSuppressed = getSuppressed(weapon, weaponClass)
    end

    -- according to docs gmod seems to "optimize" out small floating point numbers in vectors when u network them like that
    -- we have to go around it...
    -- fuck you whoever did that shit. i hate you
    -- yours truly, - jp4
    net.Start("dwr_EntityFireBullets_networked")
        writeVectorUncompressed(data.Src)
        writeVectorUncompressed(data.Dir)
        writeVectorUncompressed(Vector(0,0,0)) -- velocity
        writeVectorUncompressed(data.Spread)
        net.WriteString(ammotype)
        net.WriteBool(isSuppressed)
        net.WriteEntity(entity) -- to exclude them in MP. they're going to get hook data anyway
        if IsValid(weapon) then net.WriteEntity(weapon) else net.WriteEntity(entity) end -- we need to write SOMETHING. doesnt matter much down the line because it's just for the override wpn vars
    if networkGunshotsConvar:GetBool() then net.SendPAS(data.Src) else net.Broadcast() end
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
