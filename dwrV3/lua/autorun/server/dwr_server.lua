-- network only the data we use before we release it on workshop (or don't, it wont really matter, i just like optimization - jp4)

print("[DWRV3] Server loaded.")

util.AddNetworkString("EntityFireBullets_networked")

hook.Add("EntityFireBullets", "dwr_EntityFireBullets", function(ent, data)
    net.Start("EntityFireBullets_networked")
        net.WriteEntity(ent)
        net.WriteTable(data)
    net.Broadcast()
    print("[DWR] EntityFireBullets_networked sent")
end)
