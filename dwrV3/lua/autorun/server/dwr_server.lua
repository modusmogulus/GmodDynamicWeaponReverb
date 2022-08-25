print("[DWRV3] Server loaded.")

util.AddNetworkString("dwr_EntityFireBullets_networked")
util.AddNetworkString("dwr_EntityEmitSound_networked")

networkSoundsConvar = CreateConVar("sv_dwr_network_sounds", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Network some of the server-only sounds to the client to process them as well. May cause compatibility issues or max out the static channel.")

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

hook.Add("Think", "dwr_detectarccwphys", function()
    if ArcCW == nil then return end
    if ArcCW.PhysBullets[table.Count(ArcCW.PhysBullets)] == nil then return end
    local latestPhysBullet = ArcCW.PhysBullets[table.Count(ArcCW.PhysBullets)]
    if latestPhysBullet["dwr_detected"] then return end
    --if table.IsEmpty(latestPhysBullet) then return end
    if latestPhysBullet["OldPos"] != nil then return end
    if latestPhysBullet["Attacker"] == Entity(0) then return end
    --if latestPhysBullet["WeaponClass"] == nil then return end

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
    net.SendPAS(pos)
    latestPhysBullet["dwr_detected"] = true
end)

hook.Add("Think", "dwr_detecttfaphys", function()
    if TFA == nil then return end
    local latestPhysBullet = TFA.Ballistics.Bullets["bullet_registry"][table.Count(TFA.Ballistics.Bullets["bullet_registry"])]
    if latestPhysBullet == nil then return end
    --if latestPhysBullet["bul"]["Src"] != latestPhysBullet["pos"] then return end
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
    net.SendPAS(pos)

    latestPhysBullet["dwr_detected"] = true
end)

hook.Add("EntityFireBullets", "dwr_EntityFireBullets", function(attacker, data)
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

    if not weaponIsWeird and weapon != NULL then -- should solve all of the issues caused by external bullet sources (such as the turret mod)
        local weaponClass = weapon:GetClass()
        local entityShootPos = entity:GetShootPos()

        if entity.dwr_shotThisTick == nil then entity.dwr_shotThisTick = false end
        if entity.dwr_shotThisTick then return end
        entity.dwr_shotThisTick = true
        timer.Simple(0, function() entity.dwr_shotThisTick = false end) -- the most universal fix for fuckin penetration and ricochet
    
        if #data.AmmoType > 2 then ammotype = data.AmmoType else ammotype = weapon.Primary.Ammo end

        if data.Distance < 100 then return end

        if string.StartWith(weaponClass, "arccw_") then
            if data.Distance == 20000 then
                return
            end
            if GetConVar("arccw_bullet_enable"):GetInt() == 1 and data.Spread == Vector(0, 0, 0) then
                return
            end
        end

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
    net.SendPAS(data.Src)
end)


hook.Add("EntityEmitSound", "neegor", function(data)
    if not networkSoundsConvar:GetBool() then return end

    local src = data.Entity:GetPos()

    if data.Entity:IsPlayer() or data.Entity:IsNPC() then src = data.Entity:GetShootPos() end

    data.Pos = src

    net.Start("dwr_EntityEmitSound_networked")
        net.WriteTable(data) -- send each element separately later
    net.Broadcast(data.Pos)

    data.Volume = 0
    return true
end)