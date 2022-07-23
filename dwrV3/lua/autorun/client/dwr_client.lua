print("[DWRV3] Client loaded.")

if !dwr_successfullyCached then return end

local function getPositionState(position)
	-- detect if the player is outdoors or indoors
	-- return "outdoors"
	-- return "indoors"
end

local function getDistanceState(pos1, pos2)
	-- get distance between two positions
	-- if distance > %some_value_idk% then
	--     return "distant"
	-- else
	-- 	   return "close"
end

local function formatAmmoType(ammoType)
	-- find a neat way to deal with custom/nonexistent ammotypes so they lead into "\dwrV3\sound\dwr\Other"
	-- return formattedAmmoType
end

net.Receive("EntityFireBullets_networked", function()
	local attacker = net.ReadEntity()
	local data = net.ReadTable()
	-- local positionState = getPositionState(attacker:EyePos() or data.Src)
	-- local distanceState = getDistanceState(attacker:EyePos() or data.Src, LocalPlayer():EyePos())
	-- local ammoType = formatAmmoType(data.AmmoType)
	-- local sound_path = ammoType + "/" + positionState + "/" + distanceState + "/" + math.random(1,2) + ".wav"
	-- do whatever
end)

net.Receive("EntityEmitSound_networked", function() 
	local data = net.ReadTable()
	-- we're here solely for explosions
	-- local positionState = getPositionState(data.Pos)
	-- local distanceState = getDistanceState(attacker:EyePos() or data.Src, LocalPlayer():EyePos())
	-- local sound_path = "Explosions/" + positionState + "/" + distanceState + "/" + math.random(1,2) + ".wav"
	-- do whatever
end)