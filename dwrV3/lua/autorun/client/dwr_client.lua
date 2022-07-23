-- Don't forget about the path shit: (AMMOTYPE/INDOORS||OUTDOORS/CLOSE||DISTANT)

print("[DWRV3] Client loaded.")

if !dwr_successfullyCached then return end

net.Receive("EntityFireBullets_networked", function()
	local attacker = net.ReadEntity()
	local data = net.ReadTable()
	-- do whatever
end)

net.Receive("EntityEmitSound_networked", function() 
	local data = net.ReadTable()
	-- do whatever
end)