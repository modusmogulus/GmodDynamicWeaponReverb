print("[DWRV3] Server loaded.")

-- arccw is 2hard for me to care, so no offset fixage for u
if ConVarExists("arccw_enable_penetration") then
    GetConVar("arccw_enable_penetration"):SetInt(0)
    GetConVar("arccw_enable_ricochet"):SetInt(0)
end

util.AddNetworkString("dwr_EntityFireBullets_networked")

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
        
        if #data.AmmoType > 2 then ammotype = data.AmmoType else ammotype = weapon.Primary.Ammo end

        if data.Distance < 100 then print("[DWR] Skipping bullet because it's a melee attack") return end

        if string.StartWith(weaponClass, "arccw_") then
            if data.Distance == 20000 then
                print("[DWR] Skipping bullet because it's... not a bullet!")
                return
            end
        end

        if Vector(math.floor(entityShootPos.x), math.floor(entityShootPos.y), 0) != Vector(math.floor(data.Src.x),math.floor(data.Src.y), 0) then
            print("[DWR] Bullet is apart of a penetration chain. Skipping.")
            return
        end

        if string.StartWith(weaponClass, "arccw_") and weapon:GetBuff_Override("Silencer") then isSuprressed = true
        elseif string.StartWith(weaponClass, "tfa_") and weapon:GetSilenced() then isSuprressed = false
        elseif string.StartWith(weaponClass, "mg_") or weaponClass == mg_valpha then
            for name, attachments in pairs(weapon.Customization) do
                if name != "Muzzle" then continue end
                local attachment = weapon.Customization[name][weapon.Customization[name].m_Index]
                if string.find(attachment.Key, "silence") then
                    isSuprressed = true
                end
            end
        elseif string.StartWith(weaponClass, "cw_") then
            for k, v in pairs(weapon.ActiveAttachments) do
                if v == false then continue end
                local att = CustomizableWeaponry.registeredAttachmentsSKey[k]
                if att.isSuppressor then
                    isSuprressed = true
                end
            end
        end
    end

    net.Start("dwr_EntityFireBullets_networked")
        net.WriteVector(data.Src)
        net.WriteString(ammotype)
        net.WriteBool(isSuprressed)
    net.Broadcast()

    print("[DWR] dwr_EntityFireBullets_networked sent")
end)
