#include "inc_quest"
#include "nwnx_visibility"

void main()
{
    object oPC = GetEnteringObject();

    // Update Karlat's visibility
    if (!GetIsObjectValid(oPC)) return;

    if (GetQuestEntry(oPC, "q_charwood_karlat") == 1)
    {
        NWNX_Visibility_SetVisibilityOverride(oPC, GetObjectByTag("karlat"), NWNX_VISIBILITY_HIDDEN);
    }
    else
    {
        NWNX_Visibility_SetVisibilityOverride(oPC, GetObjectByTag("karlat"), NWNX_VISIBILITY_DEFAULT);
    }
}
