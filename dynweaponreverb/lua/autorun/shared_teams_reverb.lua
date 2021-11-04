print("Reverb initialized...")
 
--basic tails
local tailnear = "distaudio/guntail_oldfar.wav"
local tailflat = "distaudio/explosion_far.wav"
local tailveryfar = "distaudio/clapper2_veryfar.wav"
local tailveryveryfar = "distaudio/clapper2_veryveryfar.wav"
--AddCSLuaFile()
 
local soniccrack = "distaudio/hho_explosion_outdoors2.wav"
 
--underwater sounds
local underwater_shot = "distaudio/underwater_shot10.wav"
 
--urban tails

local urbantails = {"distaudio/clienttail_urban5.wav", "distaudio/clienttail_urban6.wav"}
local urbantails2 = {"distaudio/clienttail_urban5.wav", "distaudio/clienttail_urban6.wav"}
 
--indoors tails

local roomtails = {"distaudio/hho_explosion_indoors9.wav"}
local largeroomtails = {"distaudio/clienttail_roomlarge3.wav"}

local roomheight = 1000
local PlayerName = nil
 
local hash = {}
local res = {}
swepstoignoreND = {}
 
local volumeconvar = nil --Set and updated when a weapon is fired; otherwise will cause an error
local volume = 0.8
 
function has_value(tbl, item)
    for key, value in pairs(tbl) do
        if value == item then return true end
    end
    return false
end

function correct_src(weapon, source)
    -- I swear to fucking god if someone changes this in ArcCW again...
    local owner = weapon:GetOwner()

    if owner:IsNPC() then return owner:GetShootPos() end

    local dir    = owner:EyeAngles()
    local offset = Vector(0, 0, 0)

    if weapon:GetOwner():Crouching() then
        offset = weapon:GetBuff_Override("Override_BarrelOffsetCrouch") or weapon.BarrelOffsetCrouch or offset
    end

    if weapon:GetState() == ArcCW.STATE_SIGHTS then
        offset = LerpVector(weapon:GetSightDelta(), offset, weapon:GetBuff_Override("Override_BarrelOffsetSighted", weapon.BarrelOffsetSighted) or offset)
    else
        offset = LerpVector(1 - weapon:GetSightDelta(), offset, weapon:GetBuff_Override("Override_BarrelOffsetHip", weapon.BarrelOffsetHip) or offset)
    end

    source = source - dir:Right()   * offset[1]
    source = source - dir:Forward() * offset[2]
    source = source - dir:Up()      * offset[3]

    return source
end

function string.startswith(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function DynamicReverb(entity, data)
    if data.Distance < 100 then return end
    local weapon = NULL
    local reverb_range = 1
    if entity:IsPlayer() then
        weapon = entity:GetActiveWeapon()
    else
        weapon = entity
    end

    if SERVER then
        volume = GetConVar("za_volume"):GetFloat() --Updating volume value
        if GetConVar("za_enable_reverb"):GetBool() == true then
            if has_value(swepstoignoreND, tostring(weapon:GetClass())) == false then
                --Penetration fix by jp4
                weapon_owner = weapon:GetOwner()
                weapon_class = weapon:GetClass()
                if weapon_owner != nil and weapon_owner:IsPlayer() and data.Attacker == weapon_owner then
                    entity_pos = weapon:GetOwner():GetPos()
                    if string.find(weapon_class, "arccw") then
                        if data.Distance == 20000 then return end
                        shoot_pos = correct_src(weapon, data.Src)
                    else
                        shoot_pos = data.Src
                    end

                    if Vector(entity_pos.x, entity_pos.y, 0) != Vector(shoot_pos.x, shoot_pos.y, 0) or data.Distance < 100 then
                        return
                    end
                end

                if string.startswith(weapon_class, "arccw_") and data.Distance != 20000 and weapon:GetBuff_Override("Silencer") then
                    volume = volume * 0.6
                    reverb_range = 0.4
                elseif string.startswith(weapon_class, "tfa_") and weapon:GetSilenced() then
                    volume = volume * 0.6
                    reverb_range = 0.4
                elseif string.startswith(weapon_class, "mg_") or weapon_class == mg_valpha then
                    for name, attachments in pairs(weapon.Customization) do
                        if name != "Muzzle" then continue end
                        local attachment = weapon.Customization[name][weapon.Customization[name].m_Index]
                        if string.find(attachment.Key, "silence") then
                            volume = volume * 0.6
                            reverb_range = 0.4
                        end
                    end
                elseif string.startswith(weapon_class, "cw_") then
                    for k, v in pairs(weapon.ActiveAttachments) do
                        if v == false then continue end
                        local att = CustomizableWeaponry.registeredAttachmentsSKey[k]
                        if att.isSuppressor then
                            volume = volume * 0.6
                            reverb_range = 0.4
                        end
                    end
                end

                local tracedown = util.TraceLine( {  --Tracing a line to floor
                    start = entity:EyePos() +  Vector(0, 0, 1) * 1,
                    endpos = entity:EyePos(s) + Vector(0, 0, 1) * -10000,
                    mask = MASK_OPAQUE
                } )
 
                local traceup = util.TraceLine( {  --Tracing a line from floor to ceiling to measure room height
                    start = tracedown.HitPos, --Trace start offset to prevent trace hitting player
                    endpos = tracedown.HitPos + Vector(0, 0, 1) * 10000,
                    mask = MASK_OPAQUE
                } )
 
                if entity:WaterLevel() == 3 then --3 means completely submerged
                    entity:EmitSound(underwater_shot, 70, 100, 1, CHAN_WEAPON )
                end
 
                roomheight = traceup.HitPos:Distance(tracedown.HitPos), traceup.Entity                  
                if roomheight < 400 && traceup.HitSky == false then --Small room sound
                    if GetConVar("za_indoors_tail"):GetBool() == true then
                        entity:EmitSound(roomtails[ math.random( #roomtails ) ], 110 * reverb_range, 100, 1 * volume, CHAN_STATIC )
                        entity:EmitSound(roomtails[ math.random( #roomtails ) ], 110 * reverb_range, 100, 1 * volume, CHAN_STATIC ) -- for meatier sound u can just play it twice
                    end
                elseif roomheight < 1000 && roomheight > 200 && traceup.HitSky == false then
                    if GetConVar("za_indoors_tail"):GetBool() == true then
                        entity:EmitSound(largeroomtails[ math.random( #largeroomtails ) ], 95 * reverb_range, 100, 1 * volume, CHAN_STATIC ) --Large room sound
                        entity:EmitSound(roomtails[ math.random( #roomtails ) ], 95 * reverb_range, 100, 1 * volume, CHAN_STATIC )
                    end
                else
                    if GetConVar("za_outdoors_tail"):GetBool() == true then
                        if entity:WaterLevel() != 3 then
                            if GetConVar("za_oneinstance"):GetBool() == true then
                                for i, name in ipairs(urbantails) do
                                    entity:StopSound(name) -- Making sure that only one instance of the sound is playing
                                end
                                for i, name in ipairs(urbantails2) do
                                    entity:StopSound(name) 
                                end
                            end
 
                            entity:EmitSound(urbantails[ math.random( #urbantails ) ], 90 * reverb_range, 90, 0.4 * volume, CHAN_STATIC )
                            --entity:EmitSound(roomtails[ math.random( #roomtails ) ], 95 * reverb_range, 100, 1 * volume, CHAN_STATIC )
                        end
                    end
                end
            end
        end
    end
 
    for i, v in ipairs( player.GetAll() ) do
        if SERVER then
            if GetConVar("za_server_distance_shots"):GetBool() == true then
                if (v:GetViewEntity():GetPos():Distance(entity:GetPos()) > 800) then
                    net.Start( "playSoundToClient" )
                    net.Send(v)
                    v:SetNWInt( 'listenerdistance', v:GetViewEntity():GetPos():Distance(entity:GetPos()))
                end
            end
        end
    end
end

timer.Simple(3, function()
    hook.Add("EntityFireBullets", "Teams_DynamicReverbs", DynamicReverb)
end)

 
