-- network only the data we use before we release it on workshop (or don't, it wont really matter, i just like optimization - jp4)

print("[DWRV3] Server loaded.")

util.AddNetworkString("EntityFireBullets_networked")
util.AddNetworkString("EntityEmitSound_networked")

if !dwr_successfullyCached then return end

hook.Add("EntityFireBullets", "dwr_EntityFireBullets", function(ent, data)
    net.Start("EntityFireBullets_networked")
    net.WriteEntity(ent)
    net.WriteTable(data)
    net.Broadcast()
end)

hook.Add("EntityEmitSound", "dwr_EntityEmitSound", function(data) 
    net.Start("EntityEmitSound_networked")
    net.WriteTable(data)
    net.Broadcast()
end)
