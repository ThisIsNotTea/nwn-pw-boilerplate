// Returns TRUE if the PC is CURRENTLY at quest#: ##_<quest_name>, zero padded
#include "inc_quest"

int StartingConditional()
{
    object oPC = GetPCSpeaker();

    return GetIsCurrentlyAtQuestStage(OBJECT_SELF, oPC, 7);
}
