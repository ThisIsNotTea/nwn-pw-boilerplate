#include "nwnx_creature"

void main()
{
    switch (d2())
    {
        case 2:
            SetGender(OBJECT_SELF, GENDER_FEMALE);
            SetCreatureAppearanceType(OBJECT_SELF, APPEARANCE_TYPE_HUMAN_NPC_FEMALE_07);
            SetPortraitResRef(OBJECT_SELF, "po_hu_f_08_");
            SetSoundset(OBJECT_SELF, 157);
        break;
    }
}
