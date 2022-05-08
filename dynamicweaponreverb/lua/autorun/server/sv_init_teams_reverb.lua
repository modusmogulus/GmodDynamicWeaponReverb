util.AddNetworkString("dynrev_playSoundAtClient")
util.AddNetworkString("dynrev_BulletCrack")

function AddDir(dir)
    local list = file.Find( dir.."/*", "GAME" )
    for _, fdir in pairs(list) do
 
       if fdir != ".svn" then
          AddDir(dir.."/"..fdir)
       end
    end
  
    for k,v in pairs(file.Find(dir.."/*", "DATA")) do
       resource.AddFile(dir.."/"..v)
    end
 end
  
AddDir( "sounds/tails" )
AddDir( "sounds/distaudio" )
