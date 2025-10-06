#include "inc_merchant"

void main()
{
    object oMerchant = OBJECT_SELF;

    string sMerchantTag = GetLocalString(OBJECT_SELF, "merchant");

    object oStore = GetObjectByTag(sMerchantTag);

    OpenMerchant(oMerchant, oStore, GetPCSpeaker());
}
