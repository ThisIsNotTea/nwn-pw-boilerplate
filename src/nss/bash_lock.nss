#include "nwnx_player"
#include "inc_general"

void BashLock(object oAttacker)
{
    int nUnlockDC = GetLockUnlockDC(OBJECT_SELF);
    SpeakString("GS_AI_BASH_LOCK", TALKVOLUME_SILENT_TALK);
// return and remove the script from itself if locked, plot, key required, and no key tag
    if (GetLocked(OBJECT_SELF) && GetPlotFlag(OBJECT_SELF) && GetLockKeyRequired(OBJECT_SELF) && GetLockKeyTag(OBJECT_SELF) == "")
    {
        SetEventScript(OBJECT_SELF, EVENT_SCRIPT_DOOR_ON_MELEE_ATTACKED, "");
        return;
    }

// return if not locked or low unlock DC
    if (!GetLocked(OBJECT_SELF) || nUnlockDC < 10) return;

    int nStrengthBonus = GetAbilityModifier(ABILITY_STRENGTH, oAttacker);

    if (GetActionMode(oAttacker, ACTION_MODE_IMPROVED_POWER_ATTACK))
    {
        nStrengthBonus = nStrengthBonus + 4;
    }
    else if (GetActionMode(oAttacker, ACTION_MODE_POWER_ATTACK))
    {
        nStrengthBonus = nStrengthBonus + 2;
    }

    if (nStrengthBonus < -7) nStrengthBonus = -7;

    int nRoll = d20();

    string sUUID = GetObjectUUID(oAttacker);
    int nHighestRoll = GetLocalInt(OBJECT_SELF, sUUID);

    // cannot use the highest roll if there is an enemy nearby
    object oEnemy = GetNearestCreature(CREATURE_TYPE_REPUTATION, REPUTATION_TYPE_ENEMY,
                                         oAttacker, 1,
                                         CREATURE_TYPE_IS_ALIVE, TRUE,
                                         CREATURE_TYPE_PERCEPTION, PERCEPTION_SEEN);

    if (GetIsObjectValid(oEnemy) && GetDistanceBetweenLocations(GetLocation(oAttacker), GetLocation(oEnemy)) < 20.0)
    {
        nHighestRoll = 0;
    }

    if (nHighestRoll == 20)
        nRoll = 20;

    if (nRoll > 0 && nRoll < 20)
    {
        nRoll = nHighestRoll + Random(20 - nHighestRoll) + 1;

        if (nRoll > 20)
            nRoll = 20;

        SetLocalInt(OBJECT_SELF, sUUID, nRoll);
    }

    if (nRoll > 20)
        nRoll = 20;

    int nTotal = nRoll + nStrengthBonus;

    int nEffect;

    string sSign;

    if (nStrengthBonus >= 0)
    {
        sSign = "+";
    }
    else
    {
        sSign = "-";
    }


    string sOutcome;
    if (nTotal >= nUnlockDC)
    {
        sOutcome = "success";
        SetLocked(OBJECT_SELF, FALSE);
        nEffect = VFX_COM_BLOOD_SPARK_LARGE;
        AssignCommand(oAttacker, ClearAllActions(TRUE));

        IncrementPlayerStatistic(oAttacker, "locks_bashed");

        PlaySound("cb_bu_metallrg");

        switch(GetObjectType(OBJECT_SELF))
        {
            case OBJECT_TYPE_DOOR: ActionOpenDoor(OBJECT_SELF); break;
            case OBJECT_TYPE_PLACEABLE: ActionPlayAnimation(ANIMATION_PLACEABLE_OPEN); break;
        }

        object oPartyPC = GetFirstFactionMember(oAttacker);
        while (GetIsObjectValid(oPartyPC))
        {
            if (GetAttackTarget(oPartyPC) == OBJECT_SELF)
                AssignCommand(oPartyPC, ClearAllActions(TRUE));

            oPartyPC = GetNextFactionMember(oAttacker);
        }

        object oPartyNPC = GetFirstFactionMember(oAttacker, FALSE);
        while (GetIsObjectValid(oPartyNPC))
        {
            if (GetAttackTarget(oPartyNPC) == OBJECT_SELF)
            {
                AssignCommand(oPartyNPC, ClearAllActions(TRUE));
                DeleteLocalObject(oPartyNPC, "NW_GENERIC_DOOR_TO_BASH");
            }

            oPartyNPC = GetNextFactionMember(oAttacker, FALSE);
        }
    }
    else if (20+nStrengthBonus < nUnlockDC)
    {
        sOutcome = "Success will never be possible";
        nEffect = VFX_COM_BLOOD_SPARK_SMALL;
    }
    else
    {
        sOutcome = "failure";
        nEffect = VFX_COM_BLOOD_SPARK_MEDIUM;
    }

    ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectVisualEffect(nEffect), OBJECT_SELF);
    ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectVisualEffect(nEffect), OBJECT_SELF);
    ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectVisualEffect(nEffect), OBJECT_SELF);

    string sMessage = GetName(oAttacker)+" : Bash Lock: *"+sOutcome+"* : ("+IntToString(nRoll)+" "+sSign+" "+IntToString(abs(nStrengthBonus))+" = "+IntToString(nTotal)+" vs. DC: "+IntToString(nUnlockDC)+")";

    object oMaster = GetMaster(oAttacker);
    if (GetIsPC(oMaster) && GetIsObjectValid(oMaster))
    {
        NWNX_Player_FloatingTextStringOnCreature(oMaster, oAttacker, sMessage);
    }
    else
    {
        FloatingTextStringOnCreature(sMessage, oAttacker, FALSE);
    }
}

void main()
{
    if (GetLockKeyRequired(OBJECT_SELF))
        return;

    object oAttacker = GetLastAttacker();

// range weapons cannot be used for lock bashing
    if (GetWeaponRanged(GetLastWeaponUsed(oAttacker))) return;

    DelayCommand(0.2, BashLock(oAttacker));
}

