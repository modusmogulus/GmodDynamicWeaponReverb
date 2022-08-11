print("[DWRV3] Server loaded.")


if not game.SinglePlayer() then return end

util.AddNetworkString("dwr_EntityFireBullets_networked")

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

hook.Add("EntityFireBullets", "dwr_EntityFireBullets", function(attacker, data)
    local entity = NULL
    local weapon = NULL
    local weaponIsWeird = false
    local isSuprressed = false
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

    if not weaponIsWeird then -- should solve all of the issues caused by external bullet sources (such as the turret mod)
        local weaponClass = weapon:GetClass()
        local entityShootPos = entity:GetShootPos()

        if entity.dwr_shotThisTick == nil then entity.dwr_shotThisTick = false end
        if entity.dwr_shotThisTick then return end
        entity.dwr_shotThisTick = true
        timer.Simple(0, function() entity.dwr_shotThisTick = false end) -- the most universal fix for fuckin penetration and ricochet
    
        if #data.AmmoType > 2 then ammotype = data.AmmoType else ammotype = weapon.Primary.Ammo end

        if data.Distance < 100 then print("[DWR] Skipping bullet because it's a melee attack") return end

        if string.StartWith(weaponClass, "arccw_") then
            if data.Distance == 20000 then
                print("[DWR] Skipping bullet because it's... not a bullet!")
                return
            end
            if data.Spread == Vector(0, 0, 0) then
                print("[DWR] Arccw PhysBullets surface impact detected, skipping")
                return
            end
        end

        isSuppressed = getSuppressed(weapon, weaponClass)
    end

    --if data.Damage == 0 then return end -- lol what's the point

    net.Start("dwr_EntityFireBullets_networked")
        net.WriteVector(data.Src)
        net.WriteString(ammotype)
        net.WriteBool(isSuppressed)
    net.SendPVS(data.Src)

    print("[DWR] dwr_EntityFireBullets_networked sent")
end)
