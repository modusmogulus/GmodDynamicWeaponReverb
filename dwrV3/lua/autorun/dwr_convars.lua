print("[DWR] Convar file loaded")

CreateConVar("sv_dwr_volume", "100", {FCVAR_REPLICATE, FCVAR_ARCHIVE}, "dwr global volume", 0, 100)
CreateConVar("sv_vr_disable_distance_checks", "0", {FCVAR_REPLICATE, FCVAR_ARCHIVE}, "disable distance checks", 0, 1)
CreateConVar("sv_dwr_disable_soundspeed", "1", {FCVAR_REPLICATE, FCVAR_ARCHIVE}, "disable sound speed", 0, 1)
CreateConVar("sv_dwr_disable_indoors_reverb", "0", {FCVAR_REPLICATE, FCVAR_ARCHIVE}, "disable indoors reverb", 0, 1)
CreateConVar("sv_dwr_disable_outdoors_reverb", "0", {FCVAR_REPLICATE, FCVAR_ARCHIVE}, "disable outdoors reverb", 0, 1)
CreateConVar("sv_dwr_disable_reverb", "0", {FCVAR_REPLICATE, FCVAR_ARCHIVE}, "disables all reverb", 0, 1)
CreateConVar("sv_dwr_soundspeed", "343", {FCVAR_REPLICATE, FCVAR_ARCHIVE}, "sound speed", 0, 1000) -- needs to be converted by this * 1.905, default is sound speed in air @20C
