#include "inc_ai_combat"
#include "inc_ai_event"

void main()
{
    SignalEvent(OBJECT_SELF, EventUserDefined(GS_EV_ON_SPELL_CAST_AT));

    if (GetLastSpellHarmful())
    {
        object oCaster = GetLastSpellCaster();

        if (GetLocalInt(OBJECT_SELF, "combat") == 0)
            SetLocalInt(OBJECT_SELF, "combat", 1);

        SpeakString("GS_AI_ATTACK_TARGET", TALKVOLUME_SILENT_TALK);

        if (gsCBGetHasAttackTarget())
        {
            object oTarget = gsCBGetLastAttackTarget();

// if the enemy spellcaster is within range, switch to it 25% of the time if already attacking
            if (oCaster != oTarget &&
                d4() == 1 &&
                (gsCBGetIsFollowing() ||
                 GetDistanceToObject(oCaster) <=
                 GetDistanceToObject(oTarget) + 5.0))
            {
                gsCBDetermineCombatRound(oCaster);
            }
        }
        else
        {
            gsCBDetermineCombatRound(oCaster);
        }


        string sAttackScript = GetLocalString(OBJECT_SELF, "attack_script");
        if (sAttackScript != "")
            ExecuteScript(sAttackScript);
    }
}


