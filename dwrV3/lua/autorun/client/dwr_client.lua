print("[DWRV3] Client loaded.")

local function createUpwardsTrace(ent, offset)
	local pos = nil
	if ent:IsPlayer() then 
		pos = ent:GetShootPos()
	else
		pos = ent:GetPos() + ent:OBBCenter()
	end
	
    local tr = util.TraceLine({start=pos + offset, endpos=pos + Vector(offset.x, offset.y, 100000000), filter=ent})
    local temp = util.TraceLine({start=tr.StartPos, endpos=ent:GetPos() + ent:OBBCenter()})
    tr.traceableToPlayer = (temp.Entity == ent)
    return tr
end

local function getOutdoorsState(ent)
    local tr_1 = createUpwardsTrace(ent, Vector(0,0,0))
    local tr_2 = createUpwardsTrace(ent, Vector(120,0,0))
    local tr_3 = createUpwardsTrace(ent, Vector(0,120,0))
    local tr_4 = createUpwardsTrace(ent, Vector(-120,0,0))
    local tr_5 = createUpwardsTrace(ent, Vector(0,-120,0))

    massive_hitsky = ((tr_1.HitSky and tr_1.traceableToPlayer) or
                 (tr_2.HitSky and tr_2.traceableToPlayer) or
                 (tr_3.HitSky and tr_3.traceableToPlayer) or
                 (tr_4.HitSky and tr_4.traceableToPlayer) or
                 (tr_5.HitSky and tr_5.traceableToPlayer))
    return massive_hitsky -- true means we're outdoors, false means we're indoors
end

local function getPositionState(ent)
	local state = getOutdoorsState(ent)
	if state then
		return "outdoors"
	else
		return "indoors"
	end
end

local function getDistanceState(pos1, pos2)
	local distance = pos1:Distance(pos2)
	-- tweak this number later plz
	if distance > 1000 then 
		return "distant"
	else
		return "close"
	end
end

local function formatAmmoType(ammoType)
	if table.HasValue(dwr_supportedAmmoTypes, ammoType) then
		return ammoType
	else
		return "Other"
	end
end

local function getEntriesStartingWith(pattern, array)
	local tempArray = {}
	for _, path in ipairs(array) do
		if string.StartWith(path, pattern) then
			table.insert(tempArray, path)
		end
	end
	return tempArray
end

net.Receive("EntityFireBullets_networked", function(len)
	-- hook data
	local attacker = net.ReadEntity()
	local data = net.ReadTable()
	print("[DWR] EntityFireBullets_networked received")

	-- looking for reverb soundfiles to use
	local positionState = getPositionState(attacker)
	local distanceState = getDistanceState(data.Src, LocalPlayer():EyePos())
	local ammoType = formatAmmoType(data.AmmoType)
	local reverbOptions = getEntriesStartingWith("dwr" .. "/" .. ammoType .. "/" .. positionState .. "/" .. distanceState .. "/", dwr_reverbFiles)
	local reverbSoundFile = reverbOptions[math.random(#reverbOptions)]

	-- https://wiki.facepunch.com/gmod/Global.EmitSound
	-- that -2 parameter means we get to handle the sound fully by ourselves without source engine messing with it in any way. we should use that.
	-- get some dsp effects goin, soundlevels and shiet
	EmitSound(reverbSoundFile, attacker:GetPos(), -2, CHAN_AUTO, GetConVar("sv_dwr_volume"):GetInt() / 100, 75, 0, 100, 0)

	print("[DWR] reverbSoundFile: " .. reverbSoundFile)	
end)

hook.Add("EntityEmitSound", "dwr_EntityEmitSound", function(data)
	if not string.find(data.SoundName, "explo") then return end
	print("[DWR] EntityEmitSound")

	-- looking for reverb soundfiles to use
	local positionState = getPositionState(data.Entity)
	local distanceState = getDistanceState(data.Pos, LocalPlayer():EyePos())
	local ammoType = "Explosions"
	local reverbOptions = getEntriesStartingWith("dwr" .. "/" .. ammoType .. "/" .. positionState .. "/" .. distanceState .. "/", dwr_reverbFiles)
	local reverbSoundFile = reverbOptions[math.random(#reverbOptions)]

	-- https://wiki.facepunch.com/gmod/Global.EmitSound
	-- that -2 parameter means we get to handle the sound fully by ourselves without source engine messing with it in any way. we should use that.
	-- get some dsp effects goin, soundlevels and shiet
	EmitSound(reverbSoundFile, data.Pos, -2, CHAN_AUTO, 1, 75, 0, 100, 0)

	print("[DWR] reverbSoundFile: " .. reverbSoundFile)
end)