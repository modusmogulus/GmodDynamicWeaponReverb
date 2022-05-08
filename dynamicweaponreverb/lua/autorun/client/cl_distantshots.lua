
local distancedsp = 0 
net.Receive( "dynrev_playSoundAtClient", function( len, ply )
    local localear = LocalPlayer():GetViewEntity()
    volumemultiplier = net.ReadFloat()
    soundtable = net.ReadTable()
    shooter = net.ReadEntity()
    sidechain = net.ReadBool() -- nothing fancy, not a real sidechaining effect. just forces the one instance thing
    desiredspace = net.ReadString()
    

    timespeed = 331 * 1.905 / 1 -- sound speed in air converted from m/s to gmod units
    timespeeddelay = (shooter:GetPos():Distance(localear:GetPos()) * 1.905 / 100) / timespeed

    randompitch = math.random(90, 110)

    if sidechain == true then
        for i,v in ipairs(soundtable) do
            LocalPlayer():StopSound(v)
        end
    end

    timer.Simple(timespeeddelay, function() --time speed delay
        print(tostring(shooter))
        

        shooter:EmitSound("tails/dynrev_expfar.wav", 140, math.random(140, 100),
        0.4, CHAN_STATIC)
        
        shooter:EmitSound(foliage[math.random(#foliage)], 50, math.random(80, 100),
        0.5, CHAN_STATIC)
    
        firesound = soundtable[math.random(#soundtable)]
        --shooter:EmitSound(firesound, 132, randompitch,
        --2.0 * volumemultiplier, CHAN_STATIC)

        EmitSound( Sound( firesound ), shooter:GetPos(), 1, CHAN_STATIC, 1 * volumemultiplier, 130, 0, randompitch )
        print("modified:", volumemultiplier)

    end)



end )



net.Receive( "dynrev_BulletCrack", function( len, ply )
    --LocalPlayer():SetDSP(35)
    --EmitSound( Sound( bulletcracks[math.random(#bulletcracks)] ), LocalPlayer():GetPos(), 1, CHAN_STATIC, 1, 75, 0, math.random(75, 100) )
    print("cracking client")
    surface.PlaySound(bulletcracks[math.random(#bulletcracks)])
    --surface.PlaySound("tails/dynrev_muffler2.wav")
end )