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
    end

    net.Start("dwr_EntityFireBullets_networked")
        net.WriteVector(data.Src)
        net.WriteString(data.AmmoType)
    net.Broadcast()

    print("[DWR] dwr_EntityFireBullets_networked sent")
end)
