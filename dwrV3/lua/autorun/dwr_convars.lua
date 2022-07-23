print("[DWR] Convar file loaded")

CreateConVar("sv_dwr_volume", "80", {FCVAR_REPLICATE, FCVAR_ARCHIVE}, "dwr global volume", 0, 100)
CreateConVar("sv_vr_disable_distance_checks", "0", {FCVAR_REPLICATE, FCVAR_ARCHIVE}, "dwr global volume", 0, 1)
