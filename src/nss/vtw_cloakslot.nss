int StartingConditional()
{
    object oPC = GetPCSpeaker();
    object oItem = GetItemInSlot(INVENTORY_SLOT_CLOAK, oPC);
    if (GetIsObjectValid(oItem)) return TRUE;
    else return FALSE;
}

