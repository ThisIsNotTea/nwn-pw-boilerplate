#include "nwnx_creature"

void main()
{
    object oWeapon, oAmmo, oBackup;
    switch (d2())
    {
        case 1:
            oWeapon = CreateItemOnObject("nw_wpltr001", OBJECT_SELF);
        break;
        case 2:
            oWeapon = CreateItemOnObject("nw_wbwxh001", OBJECT_SELF);
            oAmmo = CreateItemOnObject("nw_wambo001", OBJECT_SELF, 99);
            oBackup = CreateItemOnObject("nw_wswsc001");

            SetDroppableFlag(oBackup, FALSE);
            SetPickpocketableFlag(oBackup, FALSE);
            SetDroppableFlag(oAmmo, FALSE);
            SetPickpocketableFlag(oAmmo, FALSE);

            AssignCommand(OBJECT_SELF, ActionEquipItem(oAmmo, INVENTORY_SLOT_BOLTS));
            SetLocalInt(OBJECT_SELF, "range", 1);
        break;
    }

    AssignCommand(OBJECT_SELF, ActionEquipItem(oWeapon, INVENTORY_SLOT_RIGHTHAND));

    SetDroppableFlag(oWeapon, FALSE);
    SetPickpocketableFlag(oWeapon, FALSE);
}
