local explosions_far = {"distaudio/exp_lpg_8_44khz.wav", "distaudio/exp_lpg_10_44khz.wav", "distaudio/exp_lpg_11_44khz.wav"}
local explosions_veryfar = {"distaudio/exp_lpg_6_44khz.wav"}
local explosion_keywords = {"^weapons/explode", "gbombs_5/explosions/light_bomb/small_explosion_5.mp3", "gbombs_5/explosions/"}

function FadeByDistance(value, peakdistance, maxdistance) -- when used on volume for example, this makes the volume raise in a straight line until peakdistance is reached (returns 1.0). after that it will decrease until maxdistance is reached (returns 0.0 beyond that)
    return math.Clamp(value / peakdistance, 0.0, 1.0) - math.Clamp(value / maxdistance, 0.0, 1.0)
end

function contains_keywords(tbl, item)
    for key, value in pairs(tbl) do
        if string.find(item, value, 1, true) != nil then return true end
    end
    return false
end

function DistantExplosions(recentsound)

    local soundfilename = recentsound.SoundName
    local explosiondistance = 1
    local audiblemin = 1500 --min distance where the sound will be at full volume
    local audiblemax = 10000 --max distance for the distant explosion sound to play
    local localear = LocalPlayer():GetViewEntity()
    if contains_keywords(explosion_keywords, soundfilename) == true then

        if recentsound.Pos != nil then
            explosiondistance = LocalPlayer():GetViewEntity():GetPos():Distance(recentsound.Pos) --recentsound.Pos returned nil a couple of times; making sure sounds not nil
            --print("not nil: distance of sound was = ", explosiondistance)
        end

        if explosiondistance != nil or explosiondistance != 0 then

            
        end

        localear:EmitSound(explosions_far[ math.random( #explosions_far ) ], 140, 100 * (FadeByDistance(explosiondistance, audiblemin, audiblemax) * 0.5 + 0.65), FadeByDistance(explosiondistance, audiblemin, audiblemax), CHAN_STATIC ) --also fades pitch because sounded cool
        
        localear:EmitSound(explosions_veryfar[ math.random( #explosions_veryfar ) ], 140, 100, FadeByDistance(explosiondistance, audiblemin + audiblemax, audiblemax + audiblemax * 2) * 2, CHAN_STATIC )

    end

end

hook.Add( "EntityEmitSound", "Teams_OnExplosionSound", DistantExplosions)
