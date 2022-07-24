print("[DWRV3] Client loaded.")

-- arccw is 2hard for me to care, so no offset fixage for u
GetConVar("arccw_enable_penetration"):SetInt(0)
GetConVar("arccw_enable_ricochet"):SetInt(0)


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
	if distance > 2000 then 
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

local function playReverb(reverbSoundFile, positionState, distanceState, dataSrc, customVolumeMultiplier)
	local volume = 1
	local soundLevel = SNDLVL_NONE -- sound plays everywhere
	local soundFlags = SND_DO_NOT_OVERWRITE_EXISTING_ON_CHANNEL
	local pitch = 100
	local dsp = 0 -- https://developer.valvesoftware.com/wiki/Dsp_presets

    local traceToShooter = util.TraceLine( {
        start = LocalPlayer():EyePos(),
        endpos = shooter:GetPos() + Vector(0,0,32),
        filter = LocalPlayer()
    })

    local direct = (trace_to_shooter.Entity == shooter)

    if not direct:
    	if distanceState == "distant":
			dsp = 30 -- lowpass
			volume = volume * 0.5
		else:
			volume = volume * 0.8
		end

	if distanceState == "close":
		local distance = LocalPlayer():EyePos():Distance(dataSrc) * 0.01905 -- in meters
		local distanceMultiplier = 1 / distance^2
		volume = volume * distanceMultiplier
	end

	EmitSound(reverbSoundFile, attacker:GetPos(), -2, CHAN_STATIC, volume, soundLevel, soundFlags, pitch, dsp)	
end

net.Receive("dwr_EntityFireBullets_networked", function(len)
	-- hook data
	local entity = net.ReadEntity()
	local weapon = net.ReadEntity()
	local dataSrc = net.ReadVector()
	local dataAmmoType = net.ReadString()

	print("[DWR] dwr_EntityFireBullets_networked received")

	-- looking for reverb soundfiles to use
	local positionState = getPositionState(entity)
	local distanceState = getDistanceState(dataSrc, LocalPlayer():EyePos())
	local ammoType = formatAmmoType(dataAmmoType)
	local reverbOptions = getEntriesStartingWith("dwr" .. "/" .. ammoType .. "/" .. positionState .. "/" .. distanceState .. "/", dwr_reverbFiles)
	local reverbSoundFile = reverbOptions[math.random(#reverbOptions)]

	print("[DWR] reverbSoundFile: " .. reverbSoundFile)

	local customVolumeMultiplier = 1

	playReverb(reverbSoundFile, positionState, distanceState, dataSrc, customVolumeMultiplier)
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

	print("[DWR] reverbSoundFile: " .. reverbSoundFile)

	local customVolumeMultiplier = 1

	playReverb(reverbSoundFile, positionState, distanceState, data.Pos, customVolumeMultiplier)
end)