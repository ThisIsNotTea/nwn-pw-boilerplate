//::///////////////////////////////////////////////
//:: Summon Shadow
//:: X0_S2_ShadSum.nss
//:: Copyright (c) 2002 Bioware Corp.
//:://////////////////////////////////////////////
/*
    PRESTIGE CLASS VERSION
    Spell powerful ally from the shadow plane to
    battle for the wizard
*/
//:://////////////////////////////////////////////
//:: Created By: Preston Watamaniuk
//:: Created On: Oct 26, 2001
//:://////////////////////////////////////////////
#include "inc_general"
void main()
{
    //Declare major variables
    int nMetaMagic = GetMetaMagicFeat();
    int nCasterLevel = GetLevelByClass(27);
    int nDuration = nCasterLevel;
    effect eSummon;



    //Set the summoned undead to the appropriate template based on the caster level
    if (nCasterLevel <= 5)
    {
        eSummon = EffectSummonCreature("sum_sd_shadow",VFX_FNF_SUMMON_UNDEAD);
    }
    else if (nCasterLevel <= 8)
    {
        eSummon = EffectSummonCreature("sum_sd_shadowf",VFX_FNF_SUMMON_UNDEAD);
    }
    else if (nCasterLevel <=10)
    {
        eSummon = EffectSummonCreature("X1_S_SHADLORD",VFX_FNF_SUMMON_UNDEAD);
    }
    else
    {
      if (GetHasFeat(1002,OBJECT_SELF))// has epic shadowlord feat
      {
       //GZ 2003-07-24: Epic shadow lord
          eSummon = EffectSummonCreature("x2_s_eshadlord",VFX_FNF_SUMMON_UNDEAD);
      }
      else
      {
         eSummon = EffectSummonCreature("X1_S_SHADLORD",VFX_FNF_SUMMON_UNDEAD);
      }

    }
    if (GetIsPC(OBJECT_SELF))
    {
        IncrementPlayerStatistic(OBJECT_SELF, "creatures_summoned");
    }

    //Apply VFX impact and summon effect
    ApplyEffectAtLocation(DURATION_TYPE_TEMPORARY, eSummon, GetSpellTargetLocation(), HoursToSeconds(nDuration));
}
