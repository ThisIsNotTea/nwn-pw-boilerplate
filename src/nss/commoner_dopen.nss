#include "inc_commoner"

void main()
{
    struct CommonerSettings sSettings;

    sSettings.NumberOfCommonersDuringDay = 8;
    sSettings.NumberOfCommonersDuringNight = 4;
    sSettings.NumberOfCommonersDuringRain = 2;
    sSettings.CommonerResRef = "commoner";
    sSettings.CommonerTag = "AMBIENT_COMMONER";
    sSettings.WaypointTag = "WP_COMMONER";
    sSettings.MinSpawnDelay = COMMONER_MIN_SPAWN_DELAY;
    sSettings.MaxSpawnDelay = COMMONER_MAX_SPAWN_DELAY;
    SpawnAndUpdateCommoners(sSettings);

    sSettings.NumberOfCommonersDuringDay = 5;
    sSettings.NumberOfCommonersDuringNight = 3;
    sSettings.NumberOfCommonersDuringRain = 2;
    sSettings.CommonerResRef = "sailor";
    sSettings.CommonerTag = "AMBIENT_SAILOR";
    sSettings.WaypointTag = "WP_SAILOR";
    SpawnAndUpdateCommoners(sSettings);

    sSettings.NumberOfCommonersDuringDay = 4;
    sSettings.NumberOfCommonersDuringNight = 3;
    sSettings.NumberOfCommonersDuringRain = 2;
    sSettings.CommonerResRef = "nwguard";
    sSettings.CommonerTag = "AMBIENT_NWGUARD";
    sSettings.WaypointTag = "WP_NWGUARD";
    sSettings.MinSpawnDelay = GUARD_MIN_SPAWN_DELAY;
    sSettings.MaxSpawnDelay = GUARD_MAX_SPAWN_DELAY;
    SpawnAndUpdateCommoners(sSettings);

    // The SpawnAndUpdateCommoners function can be called multiple times with
    // different settings. Just make sure the CommonerTag is set to something
    // different (otherwise the script will get confused).
    sSettings.NumberOfCommonersDuringDay = 5;
    sSettings.NumberOfCommonersDuringNight = 2;
    sSettings.NumberOfCommonersDuringRain = 2;
    sSettings.CommonerResRef = "militia";
    sSettings.CommonerTag = "AMBIENT_MILITIA";
    sSettings.WaypointTag = "WP_MILITIA";
    sSettings.MinSpawnDelay = MILITIA_MIN_SPAWN_DELAY;
    sSettings.MaxSpawnDelay = MILITIA_MAX_SPAWN_DELAY;
    SpawnAndUpdateCommoners(sSettings);
}
