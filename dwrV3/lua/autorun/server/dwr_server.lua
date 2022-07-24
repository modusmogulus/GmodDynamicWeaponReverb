print("[DWRV3] Server loaded.")

-- arccw is 2hard for me to care, so no offset fixage for u
GetConVar("arccw_enable_penetration"):SetInt(0)
GetConVar("arccw_enable_ricochet"):SetInt(0)

util.AddNetworkString("dwr_EntityFireBullets_networked")


hook.Add("EntityFireBullets", "dwr_EntityFireBullets", function(attacker, data)
    local entity = NULL
    local weapon = NULL
    if not attacker:IsPlayer() and not attacker:IsNPC() then
        weapon = attacker
        entity = weapon:GetOwner()
    else
        entity = attacker
        weapon = entity:GetActiveWeapon()
    end

    local weaponClass = weapon:GetClass()
    local entityShootPos = entity:EyePos()
    if string.find(weaponClass, "arccw") then
        if dataDistance == 20000 or data.Distance < 100 then
            print("[DWR] Skipping bullet because it's... not a bullet!")
            return
        end
    end

    if Vector(math.floor(entityShootPos.x), math.floor(entityShootPos.y), 0) != Vector(math.floor(data.Src.x),math.floor(data.Src.y), 0) then
        print("[DWR] Bullet is apart of a penetration chain. Skipping.")
        return
    end

    net.Start("dwr_EntityFireBullets_networked")
        net.WriteEntity(entity)
        net.WriteEntity(weapon)
        net.WriteVector(data.Src)
        net.WriteString(data.AmmoType)
    net.Broadcast()

    print("[DWR] dwr_EntityFireBullets_networked sent")
end)
