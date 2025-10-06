// this is mainly a copy of x0_inc_HENAI with a few changed things to work with Jasperre's AI
// this should NOT be used with familiars, animal companions, or pets. just henchman
// bk functions changed to AI_ to match Jasperre's naming conventions

//::///////////////////////////////////////////////
//:: x0_inc_HENAI
//:: Copyright (c) 2001 Bioware Corp.
//:://////////////////////////////////////////////
/*
    This is a wrapper overtop of the 'generic AI'
    system with custom behavior for Henchmen.

    BENEFIT:
    - easier to isolate henchmen behavior
    - easier to debug COMBAT-AI because the
    advanced Henchmen behaviour won't be in those scripts

    CONS:
    - code duplicate. The two 'combat round' functions
    will share a lot of code because the old-AI still has
    to allow any legacy henchmen to work.


    NEW RADIALS/COMMANDS:
  - Open Inventory    "inventory"
  - Open Everything
  - Remove Traps [even nonthiefs will walk to detected traps]
  - NEVER FIGHT mode (or ALWAYS RETREAT) ; SetLocal; Implementation Code inside of DetermineCombatRound  DONE


    -=-=-=-=-=-=-
    MODIFICATIONS
    -=-=-=-=-=-=-



    // * AI_ Feb 6 2003
    // * Put a check in so that when a henchmen who cannot disarm a trap
    // * sees a trap they do not repeat their voiceover forever

    // * Deva Winblood    Feb 22nd, 2008
    // * Made the Open Inventory Radial work with horses with Saddlebags


*/
//:://////////////////////////////////////////////
//:: Created By:
//:: Created On:
//:://////////////////////////////////////////////

// #include "nw_i0_generic"  //...and through this also x0_inc_generic

#include "70_inc_main"
//#include "x0_i0_henchman"
#include "nwnx_player"
#include "inc_general"
#include "x0_i0_assoc"
#include "j_inc_generic_ai"
#include "x0_i0_enemy"

// ****************************
// CONSTANTS
// ****************************

// ~ Behavior Constants
const int AI__HEALINMELEE = 10;
const int AI__CURRENT_AI_MODE = 20; // Can only be in one AI mode at a time
const int AI__AI_MODE_FOLLOW = 9; // default mode, moving after the player
const int AI__AI_MODE_RUN_AWAY = 19; // something is causing AI to retreat
const int AI__NEVERFIGHT = 30;


// ~ Distance Constants
const float AI__HEALTHRESHOLD = 5.0;
const float AI__FOLLOW_THRESHOLD= 15.0;

// difficulty difference at which familiar will flee
//int AI__FAMILIAR_COWARD = 7;


/**********************************************************************
 * FUNCTION PROTOTYPES
 **********************************************************************/

// * Sets up special additional listening patterns
// * for associates.
void AI_SetListeningPatterns();

// * Henchman/associate combat round wrapper
// * passing in OBJECT_INVALID is okay
// * Does special stuff for henchmen and familiars, then
// * falls back to default generic combat code.
void HenchmenCombatRound(object oIntruder=OBJECT_INVALID);

// * Attempt to disarm given trap
// * (called from RespondToShout and heartbeat)
int AI_AttemptToDisarmTrap(object oTrap, int bWasShout = FALSE);

// * Attempt to open a given locked object.
int AI_AttemptToOpenLock(object oLocked);

// Manually pick the nearest locked object
int AI_ManualPickNearestLock();

// Handles responses to henchmen commands, including both radial
// menu and voice commands.
void AI_RespondToHenchmenShout(object oShouter, int nShoutIndex, object oIntruder = OBJECT_INVALID, int nBanInventory=FALSE);



// * Attempt to heal self then master
int AI_CombatAttemptHeal();

// * Attempts to follow master if outside range
int AI_CombatFollowMaster();

// * set behavior used by AI
void AI_SetBehavior(int nBehavior, int nValue);

// * get behavior used by AI
int AI_GetBehavior(int nBehavior);

// ****LINEOFSIGHT*****

// * TRUE if the target door is in line of sight.
int AI_GetIsDoorInLineOfSight(object oTarget);

// Get the cosine of the angle between two objects.
float AI_GetCosAngleBetween(object Loc1, object Loc2);

// TRUE if target in the line of sight of the seer.
int AI_GetIsInLineOfSight(object oTarget, object oSeer=OBJECT_SELF);
// * called from state scripts (nw_g0_charm) to signal
// * to other party members to help me out
void SendForHelp();

/**********************************************************************
 * FUNCTION DEFINITIONS
 **********************************************************************/

int AI_BashDoorCheck(object oIntruder = OBJECT_INVALID)
{
    int bDoor = FALSE;
    //This code is here to make sure that henchmen keep bashing doors and placables.
    object oDoor = GetLocalObject(OBJECT_SELF, "NW_GENERIC_DOOR_TO_BASH");

    // * MODIFICATION February 7 2003 BK
    // * don't bash trapped doors.
    if (GetIsTrapped(oDoor) ) return FALSE;

    if(GetIsObjectValid(oDoor))
    {
        int nDoorMax = GetMaxHitPoints(oDoor);
        int nDoorNow = GetCurrentHitPoints(oDoor);
        int nCnt = GetLocalInt(OBJECT_SELF,"NW_GENERIC_DOOR_TO_BASH_HP");
        if(!GetIsObjectValid(GetNearestCreature(CREATURE_TYPE_REPUTATION, REPUTATION_TYPE_ENEMY, OBJECT_SELF, 1, CREATURE_TYPE_PERCEPTION, PERCEPTION_SEEN))
           || (!GetIsObjectValid(oIntruder) && !GetIsObjectValid(GetMaster())))
        {
            if(GetLocked(oDoor))
            {
                if(nDoorMax == nDoorNow)
                {
                    nCnt++;
                    SetLocalInt(OBJECT_SELF,"NW_GENERIC_DOOR_TO_BASH_HP", nCnt);
                }
                if(nCnt <= 0)
                {
                    bDoor = TRUE;
                    if(GetHasFeat(FEAT_IMPROVED_POWER_ATTACK))
                    {
                        ActionUseFeat(FEAT_IMPROVED_POWER_ATTACK, oDoor);
                    }
                    else if(GetHasFeat(FEAT_POWER_ATTACK))
                    {
                        ActionUseFeat(FEAT_POWER_ATTACK, oDoor);
                    }
                    else
                    {
                        ActionAttack(oDoor);
                    }
                }
            }
        }
        if(!bDoor)
        {
            PlayVoiceChat(VOICE_CHAT_CUSS);
            DeleteLocalObject(OBJECT_SELF, "NW_GENERIC_DOOR_TO_BASH");
            DeleteLocalInt(OBJECT_SELF, "NW_GENERIC_DOOR_TO_BASH_HP");
        }
    }
    return bDoor;
}

object AI_GetLockedObject(object oMaster)
{
    int nCnt = 1;
    object oLastObject = GetNearestObjectToLocation(OBJECT_TYPE_DOOR | OBJECT_TYPE_PLACEABLE, GetLocation(oMaster), nCnt);
    while (GetIsObjectValid(oLastObject))
    {
        //COMMENT THIS BACK IN WHEN DOOR ACTION WORKS ON PLACABLE.
        //object oItem = GetFirstItemInInventory(oLastObject);
        if(GetLocked(oLastObject))
        {
            return oLastObject;
        }
        if(++nCnt >= 10)
        {
            break;
        }
        oLastObject = GetNearestObjectToLocation(OBJECT_TYPE_DOOR | OBJECT_TYPE_PLACEABLE, GetLocation(oMaster), nCnt);
    }
    return OBJECT_INVALID;
}

int AI_EvaluationSanityCheck(object oIntruder, float fFollow)
{
    // Pausanias: sanity check for various effects
    if (GetHasEffect(EFFECT_TYPE_PARALYZE) ||
        GetHasEffect(EFFECT_TYPE_STUNNED) ||
        GetHasEffect(EFFECT_TYPE_FRIGHTENED) ||
        GetHasEffect(EFFECT_TYPE_SLEEP) ||
        GetHasEffect(EFFECT_TYPE_DAZED))
        return TRUE;

    // * no point in seeing if intruder has same master if no valid intruder
    if (!GetIsObjectValid(oIntruder))
        return FALSE;

    // Pausanias sanity check: do not attack target
    // if you share the same master.
    object oMaster = GetMaster();
    if (GetIsObjectValid(oMaster) && GetMaster(oIntruder) == oMaster)
        return TRUE;

    return FALSE; //* COntinue on with DetermineCombatRound
}

// * called from state scripts (nw_g0_charm) to signal
// * to other party members to help me out
void SendForHelp()
{
    // Apr. 1/04 (not an April Fool's joke, sorry)
    // Make sure we are in a PC's party. NPC's won't use the event fired...
    if(!GetIsPC(GetFactionLeader(OBJECT_SELF)))
    {
        // Stop
        return;
    }

    // *
    // * September 2003
    // * Was this a disabling type spell
    // * Signal an event so that my party members
    // * can check to see if they can remove it for me
    // *
    object oParty = GetFirstFactionMember(OBJECT_SELF, FALSE);
    while (GetIsObjectValid(oParty))
    {

        SignalEvent(oParty, EventUserDefined(46500));
        oParty = GetNextFactionMember(OBJECT_SELF, FALSE);
    }

}
// * Sets up any special listening patterns in addition to the default
// * associate ones that are used
void AI_SetListeningPatterns()
{

    SetListening(OBJECT_SELF, TRUE);
    SetListenPattern(OBJECT_SELF, "inventory",101);
    SetListenPattern(OBJECT_SELF, "pick",102);
    SetListenPattern(OBJECT_SELF, "trap", 103);
}

// Special combat round precursor for associates
void HenchmenCombatRound(object oIntruder)
{
    //------------------------------------------------------------------------------
    // Community Patch 1.72: function changed in order to allow modify combat AI without need
    // to recompile all creature scripts. The combat AI is now resolved in 70_ai_generic script
    //------------------------------------------------------------------------------
// force this to be used!
    SetLocalObject(OBJECT_SELF,"Intruder",oIntruder);
    ExecuteScript("70_ai_henchman",OBJECT_SELF);
    return;
    // * If someone has surrendered, then don't attack them.
    // * feb 25 2003
    if (GetIsObjectValid(oIntruder))
    {
        if (!GetIsEnemy(oIntruder))
        {
            ClearAllActions(TRUE);
            ActionAttack(OBJECT_INVALID);
            return;
        }
    }
    //SpeakString("in combat round. Is an enemy");
    // * This is the nearest enemy
    object oNearestTarget = GetNearestCreature(CREATURE_TYPE_REPUTATION,REPUTATION_TYPE_ENEMY,OBJECT_SELF,1,CREATURE_TYPE_PERCEPTION,PERCEPTION_SEEN);

    //    SpeakString("Henchman combat dude");

    // ****************************************
    // SETUP AND SANITY CHECKS (Quick Returns)
    // ****************************************

    // * AI_: stop fighting if something bizarre that shouldn't happen, happens
    if (AI_EvaluationSanityCheck(oIntruder, GetFollowDistance())) return;

    if(GetAssociateState(NW_ASC_IS_BUSY))
    {
        ActionForceFollowObject(GetMaster(), GetFollowDistance()); // make associates follow in this state - pok
        return;
    }

    if(GetAssociateState(NW_ASC_MODE_DYING))
    {
        return;
    }

    // June 2/04: Fix for when henchmen is told to use stealth until next fight
    if(GetLocalInt(OBJECT_SELF, "X2_HENCH_STEALTH_MODE")==2)
        SetLocalInt(OBJECT_SELF, "X2_HENCH_STEALTH_MODE", 0);

    // MODIFIED FEBRUARY 13 2003
    // The associate will not engage in battle if in Stand Ground mode unless
    // he takes damage
    if(GetAssociateState(NW_ASC_MODE_STAND_GROUND) && !GetIsObjectValid(GetLastHostileActor()))
    {
        return;
    }

    if(AI_BashDoorCheck(oIntruder)) return;

    // ** Store how difficult the combat is for this round
    //int nDiff = GetCombatDifficulty();
    //SetLocalInt(OBJECT_SELF, "NW_L_COMBATDIFF", nDiff);

    object oMaster = GetMaster();

    //1.72:  If in combat round already (variable set) do not enter it again.
    /*
    if (__InCombatRound())
    {
        return;
    }
    */


    // * Do henchmen specific things if I am a henchman otherwise run default AI
    if (GetIsObjectValid(oMaster))
    {
        /*
        if(GetActionMode(OBJECT_SELF,ACTION_MODE_DEFENSIVE_CAST))//1.72: needs to be disabled after every cast
        {
            SetActionMode(OBJECT_SELF,ACTION_MODE_DEFENSIVE_CAST,FALSE);
        }
        */
        // *******************************************
        // Healing
        // *******************************************
        // The FIRST PRIORITY: self-preservation
        // The SECOND PRIORITY: heal master;
        if (AI_CombatAttemptHeal())
        {
            return;
        }

        // NEXT priority: follow or return to master for up to three rounds.
        if (AI_CombatFollowMaster())
        {
            return;
        }

        //5. This check is to see if the master is being attacked and in need of help
        // * Guard Mode -- only attack if master attacking
        // * or being attacked.
        if(GetAssociateState(NW_ASC_MODE_DEFEND_MASTER))
        {
            oIntruder = GetLastHostileActor(GetMaster());
            if(!GetIsObjectValid(oIntruder))
            {
                //oIntruder = GetGoingToBeAttackedBy(GetMaster());

                // MODIFIED Major change. Defend is now Defend only if I attack
                // February 11 2003

                oIntruder = GetAttackTarget(GetMaster());
                // * February 11 2003
                // * means that the player was invovled in a battle

                if (GetIsObjectValid(oIntruder) || GetLocalInt(OBJECT_SELF, "X0_BATTLEJOINEDMASTER") == TRUE)
                {

                    SetLocalInt(OBJECT_SELF, "X0_BATTLEJOINEDMASTER", TRUE);
                    // * This is turned back to false whenever he hits the end of combat
                    if (!GetIsObjectValid(oIntruder))
                    {
                        oIntruder = oNearestTarget;
                        if (!GetIsObjectValid(oIntruder))
                        {
                            //* turn off the "I am in battle" sub-mode
                            SetLocalInt(OBJECT_SELF, "X0_BATTLEJOINEDMASTER", FALSE);
                        }
                    }
                }
                // * Exit out and do nothing this combat round
                else
                {
                  // * August 2003: If I'm getting beaten up and my master
                  // * is just standing around, I should attempt, one last time
                  // * to see if there is someone I should be fighting
                  oIntruder = GetLastAttacker(OBJECT_SELF);

                  // * EXIT CONDITION = There really is not anyone
                  // * near me to justify going into combat
                  if (!GetIsObjectValid(oIntruder))
                  {
                    return;
                  }
                }
            }
        }
/*
        int iAmHenchman = FALSE;
        if (GetAssociateType(OBJECT_SELF) == ASSOCIATE_TYPE_HENCHMAN)
        {
            iAmHenchman = TRUE;
        }
        if (iAmHenchman)
*/
        /*
        if (GetAssociateType(OBJECT_SELF) == ASSOCIATE_TYPE_HENCHMAN)
        {
            // 5% chance per round of speaking the relative challenge of the encounter.
            if (d100() > 95) {
                if (nDiff <= 1) VoiceLaugh(TRUE);
             // MODIFIED February 7 2003. This was confusing testing
             //   else if (nDiff <= 4) VoiceThreaten(TRUE);
             //   else VoiceBadIdea();
            }
        } // is a henchman
        */
        // I am a familiar FLEE if tough
        /*
        MODIFIED FEB10 2003. Q/A hated this.

        int iAmFamiliar = (GetAssociate(ASSOCIATE_TYPE_FAMILIAR,oMaster) == OBJECT_SELF);
        if (iAmFamiliar) {
            // Run away from tough enemies
            if (nDiff >= AI__FAMILIAR_COWARD || GetPercentageHPLoss(OBJECT_SELF) < 40) {
                VoiceFlee();

                ClearAllActions(CLEAR_X0_INC_HENAI_HCR);
                ActionMoveAwayFromObject(oNearestTarget, TRUE, 40.0);
                return;
            }
        }
        */
    } // * is an associate


    // Fall through to generic combat

    // * only go into determinecombatround if there's a valid enemy nearby
    // * feb 26 2003: To prevent henchmen from resuming combat
    if (GetIsObjectValid(oIntruder) || GetIsObjectValid(oNearestTarget))
    {
        //DetermineCombatRound(oIntruder);
        AI_DetermineCombatRound(oIntruder);
    }
}


// Manually pick the nearest locked object
int AI_ManualPickNearestLock()
{
    object oLastObject = AI_GetLockedObject(GetMaster());

    //MyPrintString("Attempting to unlock: " + GetTag(oLastObject));
    return AI_AttemptToOpenLock(oLastObject);
}

// * attempts to disarm last trap (called from RespondToShout and heartbeat
int AI_AttemptToDisarmTrap(object oTrap, int bWasShout = FALSE)
{
    //MyPrintString("Attempting to disarm: " + GetTag(oTrap));

    // * May 2003: Don't try to disarm a trap with no trap
    if (!GetIsObjectValid(oTrap) || !GetIsTrapped(oTrap))
    {
        return FALSE;
    }



    //1.71: ignore if ordered to deal with trap manually
    // * June 2003. If in 'do not disarm trap' mode, then do not disarm traps
    if(!bWasShout && !GetAssociateState(NW_ASC_DISARM_TRAPS))
    {
        return FALSE;
    }

    int bISawTrap = GetTrapDetectedBy(oTrap, OBJECT_SELF) || GetTrapDetectedBy(oTrap, GetMaster());

    int bCloseEnough = GetDistanceToObject(oTrap) <= 15.0;

    int bInLineOfSight = AI_GetIsInLineOfSight(oTrap);


    if(!bISawTrap || !bCloseEnough || !bInLineOfSight)
    {
        //MyPrintString("Failed basic disarm check");
        if (bWasShout)
            PlayVoiceChat(VOICE_CHAT_CANTDO);
        return FALSE;
    }

    //object oTrapSaved = GetLocalObject(OBJECT_SELF, "NW_ASSOCIATES_LAST_TRAP");
    SetLocalObject(OBJECT_SELF, "NW_ASSOCIATES_LAST_TRAP", oTrap);
    // We can tell we can't do it
        string sID = ObjectToString(oTrap);
    int nSkill = GetSkillRank(SKILL_DISABLE_TRAP);
    int nTrapDC = GetTrapDisarmDC(oTrap);
    if ( nSkill > 0 && (nSkill  + 20) >= nTrapDC && GetTrapDisarmable(oTrap)) {
        ClearAllActions(CLEAR_X0_INC_HENAI_AttemptToDisarmTrap);
        ActionUseSkill(SKILL_DISABLE_TRAP, oTrap);
        ActionDoCommand(SetCommandable(TRUE));
        ActionDoCommand(PlayVoiceChat(VOICE_CHAT_TASKCOMPLETE));
        SetCommandable(FALSE);
        return TRUE;
    } else if (GetHasSpell(SPELL_FIND_TRAPS) && GetTrapDisarmable(oTrap) && GetLocalInt(oTrap, "NW_L_IATTEMPTEDTODISARMNOWORK") ==0)
    {
       // SpeakString("casting");
        ClearAllActions(CLEAR_X0_INC_HENAI_AttemptToDisarmTrap);
        ActionCastSpellAtObject(SPELL_FIND_TRAPS, oTrap);
        SetLocalInt(oTrap, "NW_L_IATTEMPTEDTODISARMNOWORK", 10);
        return TRUE;
    }
    // MODIFIED February 7 2003. Merged the 'attack object' inside of the bshout
    // this is not really something you want the henchmen just to go and do
    // spontaneously
    else if (bWasShout)
    {
        //ClearAllActions(CLEAR_X0_INC_HENAI_AI_ATTEMPTTODISARMTRAP_ThrowSelfOnTrap);

        //SpeakStringByStrRef(40551); // * Out of game indicator that this trap can never be disarmed by henchman.
        if  (GetLocalInt(OBJECT_SELF, "X0_L_SAWTHISTRAPALREADY" + sID) != 10)
        {
            string sSpeak = GetStringByStrRef(40551);
            SendMessageToPC(GetMaster(), sSpeak);
            SetLocalInt(OBJECT_SELF, "X0_L_SAWTHISTRAPALREADY" + sID, 10);
        }
        if (GetObjectType(oTrap) != OBJECT_TYPE_TRIGGER)
        {
            // * because Henchmen are not allowed to switch weapons without the player's
            // * say this needs to be removed
            // it's an object we can destroy ranged
            // ActionEquipMostDamagingRanged(oTrap);
            ActionAttack(oTrap);
            SetLocalObject(OBJECT_SELF, "NW_GENERIC_DOOR_TO_BASH", oTrap);
            return TRUE;
        }

        // Throw ourselves on it nobly! :-)
        vector vPos = GetPosition(OBJECT_SELF);
        vector vTrap = GetPosition(oTrap);
        vector vDis = vTrap-vPos;
        vDis *= (VectorMagnitude(vDis) + 1.0)/ VectorMagnitude(vDis);
        ActionMoveToLocation(Location(GetArea(oTrap), GetPosition(oTrap) + vDis, VectorToAngle(vDis)));
        ActionMoveToObject(GetMaster());
        return TRUE;
    }
    else if (nSkill > 0)
    {

        // * AI_ Feb 6 2003
        // * Put a check in so that when a henchmen who cannot disarm a trap
        // * sees a trap they do not repeat their voiceover forever
        if  (GetLocalInt(OBJECT_SELF, "X0_L_SAWTHISTRAPALREADY" + sID) != 10)
        {
            PlayVoiceChat(VOICE_CHAT_CANTDO);
            SetLocalInt(OBJECT_SELF, "X0_L_SAWTHISTRAPALREADY" + sID, 10);
           string sSpeak = GetStringByStrRef(40551);
           SendMessageToPC(GetMaster(), sSpeak);
        }

        return FALSE;
    }

    return FALSE;
}
//* attempts to cast knock to open the door
int AttemptKnockSpell(object oLocked)
{
    // If that didn't work, let's try using a knock spell
    if (GetHasSpell(SPELL_KNOCK))
        //&& (GetIsDoorActionPossible(oLocked,
        //                            DOOR_ACTION_KNOCK)
        //    || GetIsPlaceableObjectActionPossible(oLocked,
        //                                          PLACEABLE_ACTION_KNOCK)))
    {
        if (!AI_GetIsDoorInLineOfSight(oLocked))
        {
            // For whatever reason, GetObjectSeen doesn't return seen doors.
            //if (GetObjectSeen(oLocked))
            if (LineOfSightObject(OBJECT_SELF, oLocked))
            {
                ClearAllActions(CLEAR_X0_INC_HENAI_AttemptToOpenLock2);
                PlayVoiceChat(VOICE_CHAT_CANDO);
                ActionWait(1.0);
                ActionCastSpellAtObject(SPELL_KNOCK, oLocked);
                ActionWait(1.0);
                return TRUE;
            }
        }

    }
    return FALSE;
}

// * Attempt to open a given locked object.
int AI_AttemptToOpenLock(object oLocked)
{

    // * September 2003
    // * if door is set to not be something
    // * henchmen should bash open  (like mind flayer beds)
    // * then ignore it.
    if (GetLocalInt(oLocked, "X2_L_BASH_FALSE") == 1)
    {
        return FALSE;
    }
    int bNeedKey = FALSE;
    int bInLineOfSight = TRUE;

    if (GetLockKeyRequired(oLocked))
    {
        bNeedKey = TRUE ;
    }

    // * October 17 2003 - AI_ - Decided that line of sight for doors is not relevant
    // * was causing too many errors.
    //if (AI_GetIsInLineOfSight(oLocked) == FALSE)
    //{
    //    bInLineOfSight = TRUE;
   // }
    if ( !GetIsObjectValid(oLocked)
         || bNeedKey
         || !bInLineOfSight)
         //|| GetObjectSeen(oLocked) == FALSE) This check doesn't work.
         {
        // Can't open this, so skip the checks
        //MyPrintString("Failed basic check");
        PlayVoiceChat(VOICE_CHAT_CANTDO);
        return FALSE;
    }

    // We might be able to open this

    int bCanDo = FALSE;

    // First, let's see if we notice that it's trapped
    if (GetIsTrapped(oLocked) && GetTrapDetectedBy(oLocked, OBJECT_SELF))
    {
        // Ick! Try and disarm the trap first
        //MyPrintString("Trap on it to disarm");
        if (! AI_AttemptToDisarmTrap(oLocked))
        {
            // * Feb 11 2003. Attempt to cast knock because its
            // * always safe to cast it, even on a trapped object
            if (AttemptKnockSpell(oLocked))
            {
                return TRUE;
            }
            //VoicePicklock();
            PlayVoiceChat(VOICE_CHAT_NO);
            return FALSE;
        }
    }

    // Now, let's try and pick the lock first
    int nSkill = GetSkillRank(SKILL_OPEN_LOCK);
    if (nSkill > 0) {
        nSkill += GetAbilityModifier(ABILITY_DEXTERITY);
        nSkill += 20;
    }

    if (nSkill > GetLockUnlockDC(oLocked)
        &&
        GetLocked(oLocked)) {
        //(GetIsDoorActionPossible(oLocked,
        //                         DOOR_ACTION_UNLOCK)
        // || GetIsPlaceableObjectActionPossible(oLocked,
        //                                       PLACEABLE_ACTION_UNLOCK))) {
        ClearAllActions(CLEAR_X0_INC_HENAI_AttemptToOpenLock1);
        PlayVoiceChat(VOICE_CHAT_CANDO);
        ActionWait(1.0);
        ActionUseSkill(SKILL_OPEN_LOCK,oLocked);
        ActionWait(1.0);
        bCanDo = TRUE;
    }

    if (!bCanDo)
        bCanDo = AttemptKnockSpell(oLocked);


    if (!bCanDo
        //&& GetAbilityScore(OBJECT_SELF, ABILITY_STRENGTH) >= 16 Removed since you now have control over their bashing via dialog
        //&& !GetPlotFlag(oLocked)
        // pok - modify for tfn lock bashing
        // check if they have enough strength to bash it open...
        && (GetLockUnlockDC(oLocked) <= 20+GetAbilityModifier(ABILITY_STRENGTH, OBJECT_SELF))
        // henchman with ranged weapons cannot lock bash!
        && !(GetWeaponRanged(GetItemInSlot(INVENTORY_SLOT_RIGHTHAND, OBJECT_SELF)))
        // let's also check to see if the door is locked
        && (GetLocked(oLocked))
        //&& (GetIsDoorActionPossible(oLocked,
        //                            DOOR_ACTION_BASH)
        //    || GetIsPlaceableObjectActionPossible(oLocked,
        //                                          PLACEABLE_ACTION_BASH))) {
        // this had to be commented out because it checks for plotness of doors/placeables
        // which we do set in our system
        ){
        ClearAllActions(CLEAR_X0_INC_HENAI_AttemptToOpenLock3);
        PlayVoiceChat(VOICE_CHAT_CANDO);
        ActionWait(1.0);

        // MODIFIED February 2003
        // Since the player has direct control over weapon, automatic equipping is frustrating.
        // removed.
        //        ActionEquipMostDamagingMelee(oLocked);
        ActionAttack(oLocked);
        SetLocalObject(OBJECT_SELF, "NW_GENERIC_DOOR_TO_BASH", oLocked);
        bCanDo = TRUE;
    }

    if (!bCanDo && !GetPlotFlag(oLocked) && GetHasSpell(SPELL_MAGIC_MISSILE))
    {
        ClearAllActions(CLEAR_X0_INC_HENAI_AttemptToOpenLock3);
        ActionCastSpellAtObject(SPELL_MAGIC_MISSILE,oLocked);
        return TRUE;
    }

    // If we did it, let the player know
    if(!bCanDo) {
        PlayVoiceChat(VOICE_CHAT_CANTDO);
    } else {
        ActionDoCommand(PlayVoiceChat(VOICE_CHAT_TASKCOMPLETE));
        return TRUE;
    }

    return FALSE;
}


// Handles responses to henchmen commands, including both radial
// menu and voice commands.
void AI_RespondToHenchmenShout(object oShouter, int nShoutIndex, object oIntruder = OBJECT_INVALID, int nBanInventory=FALSE)
{

    // * if petrified, jump out
    if (!GetIsControllable(OBJECT_SELF))
    {
        return;
    }

    // * MODIFIED February 19 2003
    // * Do not respond to shouts if in dying mode
    //if (GetIsHenchmanDying())
    //    return;

    // Do not respond to shouts if you've surrendered.
/*    int iSurrendered = GetLocalInt(OBJECT_SELF,"Generic_Surrender");
    if (iSurrendered)
        return;*/
    if(GetLocalInt(OBJECT_SELF,"Generic_Surrender")) return;

    object oLastObject;
    object oTrap;
    object oMaster = GetMaster();
    object oTarget;

    //ASSOCIATE SHOUT RESPONSES
    switch(nShoutIndex)
    {

    // * toggle search mode for henchmen
    case ASSOCIATE_COMMAND_TOGGLESEARCH:
    {
        if (GetActionMode(OBJECT_SELF, ACTION_MODE_DETECT))
        {
            SetActionMode(OBJECT_SELF, ACTION_MODE_DETECT, FALSE);
        }
        else
        {
            SetActionMode(OBJECT_SELF, ACTION_MODE_DETECT, TRUE);
        }
        break;
    }
    // * toggle stealth mode for henchmen
    case ASSOCIATE_COMMAND_TOGGLESTEALTH:
    {
        //SpeakString(" toggle stealth");
        if (GetActionMode(OBJECT_SELF, ACTION_MODE_STEALTH))
        {
            SetActionMode(OBJECT_SELF, ACTION_MODE_STEALTH, FALSE);
        }
        else
        {
            SetActionMode(OBJECT_SELF, ACTION_MODE_STEALTH, TRUE);
        }
        break;
    }
    // * June 2003: Stop spellcasting
    case ASSOCIATE_COMMAND_TOGGLECASTING:
    {
        if (GetLocalInt(OBJECT_SELF, "X2_L_STOPCASTING") == 10)
        {
            // SpeakString("Was in no casting mode. Switching to cast mode");
            NWNX_Player_FloatingTextStringOnCreature(oMaster, OBJECT_SELF, GetName(OBJECT_SELF)+" will now cast spells when possible");
            SetLocalInt(OBJECT_SELF, "X2_L_STOPCASTING", 0);
            PlayVoiceChat(VOICE_CHAT_CANDO);
        }
        else
        if (GetLocalInt(OBJECT_SELF, "X2_L_STOPCASTING") == 0)
        {
         //   SpeakString("Was in casting mode. Switching to NO cast mode");
            NWNX_Player_FloatingTextStringOnCreature(oMaster, OBJECT_SELF, GetName(OBJECT_SELF)+" will no longer cast spells");
            SetLocalInt(OBJECT_SELF, "X2_L_STOPCASTING", 10);
            PlayVoiceChat(VOICE_CHAT_CANDO);
        }
      break;
    }
    case ASSOCIATE_COMMAND_INVENTORY:
        // no inventory
        SpeakStringByStrRef(9066);
        break;

    case ASSOCIATE_COMMAND_PICKLOCK:
        AI_ManualPickNearestLock();
        break;

    case ASSOCIATE_COMMAND_DISARMTRAP: // Disarm trap
        oTarget = GetNearestTrapToObject(GetMaster());
        //1.71: if the nearest trap the master cannot be disarmed, try disarm nearest trap from self
        if(!GetIsObjectValid(oTarget) || !GetIsTrapped(oTarget) || !GetTrapDetectedBy(oTarget, OBJECT_SELF) || GetDistanceToObject(oTarget) > 15.0 || !AI_GetIsInLineOfSight(oTarget))
        {
            oTarget = GetNearestTrapToObject();
            if(!GetIsObjectValid(oTarget) || !GetIsTrapped(oTarget))
            {
                PlayVoiceChat(VOICE_CHAT_CANTDO);
                break;
            }
        }
        AI_AttemptToDisarmTrap(oTarget, TRUE);
        break;

    case ASSOCIATE_COMMAND_ATTACKNEAREST:
        if (GetAssociateState(NW_ASC_IS_BUSY) || GetAssociateState(NW_ASC_MODE_DEFEND_MASTER) || GetAssociateState(NW_ASC_MODE_STAND_GROUND))
        {
            SetAssociateState(NW_ASC_IS_BUSY, FALSE); // make them stop doing the follow command - pok
            NWNX_Player_FloatingTextStringOnCreature(oMaster, OBJECT_SELF, GetName(OBJECT_SELF)+" will now attack enemies on sight");
        }
        ResetHenchmenState();
        SetAssociateState(NW_ASC_MODE_DEFEND_MASTER, FALSE);
        SetAssociateState(NW_ASC_MODE_STAND_GROUND, FALSE);
        AI_DetermineCombatRound();

        // * bonus feature. If master is attacking a door or container, issues VWE Attack Nearest
        // * will make henchman join in on the fun
        oTarget = GetAttackTarget(GetMaster());
        if (GetIsObjectValid(oTarget))
        {
            if (GetObjectType(oTarget) == OBJECT_TYPE_PLACEABLE || GetObjectType(oTarget) == OBJECT_TYPE_DOOR)
            {
                ActionAttack(oTarget);
            }
        }
        break;

    case ASSOCIATE_COMMAND_FOLLOWMASTER:
        ResetHenchmenState();
        SetAssociateState(NW_ASC_MODE_STAND_GROUND, FALSE);
        DelayCommand(2.5, PlayVoiceChat(VOICE_CHAT_CANDO));

        //UseStealthMode();
        //UseDetectMode();

        NWNX_Player_FloatingTextStringOnCreature(oMaster, OBJECT_SELF, GetName(OBJECT_SELF)+" will follow and avoid any actions for 30 seconds until ordered otherwise");

        ActionForceFollowObject(GetMaster(), GetFollowDistance());
        SetAssociateState(NW_ASC_IS_BUSY);
        DelayCommand(30.0, SetAssociateState(NW_ASC_IS_BUSY, FALSE));
        break;

    case ASSOCIATE_COMMAND_GUARDMASTER:
    {
        ResetHenchmenState();
        //DelayCommand(2.5, VoiceCannotDo());

        //Companions will only attack the Masters Last Attacker

        NWNX_Player_FloatingTextStringOnCreature(oMaster, OBJECT_SELF, GetName(OBJECT_SELF)+" will only retaliate against your last attacker");

        SetAssociateState(NW_ASC_MODE_DEFEND_MASTER);
        SetAssociateState(NW_ASC_MODE_STAND_GROUND, FALSE);
        object oLastAttacker = GetLastHostileActor(GetMaster());
        // * for some reason this is too often invalid. still the routine
        // * works corrrectly
        SetLocalInt(OBJECT_SELF, "X0_BATTLEJOINEDMASTER", TRUE);
        HenchmenCombatRound(oLastAttacker);
        break;
    }
    case ASSOCIATE_COMMAND_HEALMASTER:
        //Ignore current healing settings and heal me now

        ResetHenchmenState();
        oMaster = GetMaster();

        if(GetIsDead(oMaster))//1.71: taught henchman to resurrect his master
        {
            /*
            if(GetHasSpell(SPELL_RESURRECTION))
            {
                if(AI_TalentFilter(TalentSpell(SPELL_RESURRECTION),oMaster))
                    DelayCommand(2.0, VoiceCanDo());
                break;
            }
            else if(GetHasSpell(SPELL_RAISE_DEAD))
            {
                if(AI_TalentFilter(TalentSpell(SPELL_RAISE_DEAD),oMaster))
                    DelayCommand(2.0, VoiceCanDo());
                break;
            }
            */
            int nRnd;
            talent tUse = GetCreatureTalentBest(TALENT_CATEGORY_BENEFICIAL_CONDITIONAL_SINGLE,0);
            while(GetIsTalentValid(tUse) && nRnd++ < 10)
            {
                if(GetTypeFromTalent(tUse) == TALENT_TYPE_SPELL && (GetIdFromTalent(tUse) == SPELL_RESURRECTION || GetIdFromTalent(tUse) == SPELL_RAISE_DEAD))
                {
                    ClearAllActions();
                    ActionUseTalentOnObject(tUse,oMaster);
                    DelayCommand(2.0, PlayVoiceChat(VOICE_CHAT_CANDO));
                    return;
                }
                tUse = GetCreatureTalentBest(TALENT_CATEGORY_BENEFICIAL_CONDITIONAL_SINGLE,0);
            }
            PlayVoiceChat(VOICE_CHAT_CANTDO);
            return;
        }

        //SetCommandable(TRUE);
        /*
        if(TalentCureCondition())
        {
            DelayCommand(2.0, PlayVoiceChat(VOICE_CHAT_CANDO));
            return;
        }

        if(TalentHeal(TRUE, oMaster))
        {
            DelayCommand(2.0, PlayVoiceChat(VOICE_CHAT_CANDO));
            return;
        }
        */
        if(AI_ActionHealObject(oMaster))
        {
            DelayCommand(2.0, PlayVoiceChat(VOICE_CHAT_CANDO));
            return;
        }

        PlayVoiceChat(VOICE_CHAT_CANTDO);
        break;

    case ASSOCIATE_COMMAND_MASTERFAILEDLOCKPICK:
        //Check local for re-try locked doors
        if(!GetAssociateState(NW_ASC_MODE_STAND_GROUND)
           && GetAssociateState(NW_ASC_RETRY_OPEN_LOCKS))
           {
            oLastObject = AI_GetLockedObject(GetMaster());
            AI_AttemptToOpenLock(oLastObject);
        }
        break;


    case ASSOCIATE_COMMAND_STANDGROUND:
        //No longer follow the master or guard him
        NWNX_Player_FloatingTextStringOnCreature(oMaster, OBJECT_SELF, GetName(OBJECT_SELF)+" will wait here until ordered otherwise");
        SetAssociateState(NW_ASC_MODE_STAND_GROUND);
        SetAssociateState(NW_ASC_MODE_DEFEND_MASTER, FALSE);
        DelayCommand(2.0, PlayVoiceChat(VOICE_CHAT_CANDO));
        ActionAttack(OBJECT_INVALID);
        ClearAllActions(CLEAR_X0_INC_HENAI_RespondToShout1);
        break;



        // ***********************************
        // * AUTOMATIC SHOUTS - not player
        // *   initiated
        // ***********************************
    case ASSOCIATE_COMMAND_MASTERSAWTRAP:
        if(!GetIsInCombat())
        {
            if(!GetAssociateState(NW_ASC_MODE_STAND_GROUND))
            {
                oTrap = GetLastTrapDetected(GetMaster());
                AI_AttemptToDisarmTrap(oTrap);
            }
        }
        break;

    case ASSOCIATE_COMMAND_MASTERUNDERATTACK:
        // Just go to henchman combat round
        //SpeakString("here 728");

        // * July 15, 2003: Make this only happen if not
        // * in combat, otherwise the henchman will
        // * ping pong between targets
        // if (!GetIsInCombat(OBJECT_SELF))
        if (GetCurrentAction() != ACTION_ATTACKOBJECT && GetCurrentAction() != ACTION_CASTSPELL)
            HenchmenCombatRound();
        break;

    case ASSOCIATE_COMMAND_MASTERATTACKEDOTHER:

        if(!GetAssociateState(NW_ASC_MODE_STAND_GROUND))
        {
            if(!GetAssociateState(NW_ASC_MODE_DEFEND_MASTER))
            {
                // if(!GetIsInCombat(OBJECT_SELF))
                if (GetCurrentAction() != ACTION_ATTACKOBJECT && GetCurrentAction() != ACTION_CASTSPELL)
                {
                    //SpeakString("here 737");
                    object oAttack = GetAttackTarget(GetMaster());
                    // April 2003: If my master can see the enemy, then I can too.
                    if(GetIsObjectValid(oAttack) && GetObjectSeen(oAttack, GetMaster()))
                    {
                        //ClearAllActions(CLEAR_X0_INC_HENAI_RespondToShout2); //1.71: fix for associates casting spell over and over
                        HenchmenCombatRound(oAttack);
                    }
                }
            }
        }
        break;

    case ASSOCIATE_COMMAND_MASTERGOINGTOBEATTACKED:
        if(!GetAssociateState(NW_ASC_MODE_STAND_GROUND))
        {
            // if(!GetIsInCombat(OBJECT_SELF))
            if (GetCurrentAction() != ACTION_ATTACKOBJECT && GetCurrentAction() != ACTION_CASTSPELL)
            {   // SpeakString("here 753");
                object oAttacker = GetGoingToBeAttackedBy(GetMaster());
                // April 2003: If my master can see the enemy, then I can too.
                // Potential Side effect : Henchmen may run
                // to stupid places, trying to get an enemy
                if(GetIsObjectValid(oAttacker) && GetObjectSeen(oAttacker, GetMaster()))
                {
                   // SpeakString("Defending Master");
                    //ClearAllActions(CLEAR_X0_INC_HENAI_RespondToShout3); //1.71: fix for associates casting spell over and over
                    ActionMoveToObject(oAttacker, TRUE, 7.0);
                    HenchmenCombatRound(oAttacker);

                }
            }
        }
        break;

    case ASSOCIATE_COMMAND_LEAVEPARTY:
        {
            // do nothing
            break;
        }
    }

}

//::///////////////////////////////////////////////
//:: AI_CombatAttemptHeal
//:: Copyright (c) 2001 Bioware Corp.
//:://////////////////////////////////////////////
/*
    Attempt to heal self and then master
*/
//:://////////////////////////////////////////////
//:: Created By:
//:: Created On:
//:://////////////////////////////////////////////

int AI_CombatAttemptHeal()
{
    // * if master is disabled then attempt to free master
    object oMaster = GetMaster();


    // *turn into a match function...
    if (MatchDoIHaveAMindAffectingSpellOnMe(oMaster)) {
        //int nSpellToUse = -1;

        if (GetHasSpell(SPELL_DISPEL_MAGIC, OBJECT_SELF) ) {
            ClearAllActions(CLEAR_X0_INC_HENAI_CombatAttemptHeal1);
            ActionCastSpellAtLocation(SPELL_DISPEL_MAGIC, GetLocation(oMaster));
            return TRUE;
        }
    }

    int iHealMelee = GetHasFeat(FEAT_COMBAT_CASTING);//1.72: now the heal in melee behavior is determined by combat casting feat
   // if (AI_GetBehavior(AI__HEALINMELEE) == FALSE)//1.72: unused, was always false
   //     iHealMelee = FALSE;


    object oNearestEnemy = GetNearestSeenEnemy();

    float fDistance = 99.0;
    if (GetIsObjectValid(oNearestEnemy)) {
        fDistance = GetDistanceToObject(oNearestEnemy);
    }

    int iHP = GetPercentageHPLoss(OBJECT_SELF);

    // if less than 10% hitpoints then pretend that I am allowed
    // to heal in melee. Things are getting desperate
    if (iHP < 10)
     iHealMelee = TRUE;

    int iAmFamiliar = (GetAssociate(ASSOCIATE_TYPE_FAMILIAR,oMaster) == OBJECT_SELF);

    // * must be out of Melee range or ALLOWED to heal in melee
    if (fDistance > AI__HEALTHRESHOLD || iHealMelee) {
        int iAmHenchman = GetAssociateType(OBJECT_SELF) == ASSOCIATE_TYPE_HENCHMAN;
        int iAmCompanion = (GetAssociate(ASSOCIATE_TYPE_ANIMALCOMPANION,oMaster) == OBJECT_SELF);
        int iAmSummoned = (GetAssociate(ASSOCIATE_TYPE_SUMMONED,oMaster) == OBJECT_SELF);

        // Condition for immediate self-healing
        // Hit-point at less than 50% and random chance
        if (iHP < 50) {
            // verbalize
            if (iAmHenchman || iAmFamiliar) {
                // * when hit points less than 10% will whine about
                // * being near death
                if (iHP < 10 && Random(5) == 0)
                    PlayVoiceChat(VOICE_CHAT_NEARDEATH);
            }

            // attempt healing
            if (d100() > iHP-20) {
                ClearAllActions(CLEAR_X0_INC_HENAI_CombatAttemptHeal2);
                if (AI_ActionHealObject(OBJECT_SELF)) return TRUE;
                if (iAmHenchman || iAmFamiliar)
                    if (Random(100) > 80) PlayVoiceChat(VOICE_CHAT_HEALME);
            }
        }

        // ********************************
        // Heal master if needed.
        // ********************************

        if (GetAssociateHealMaster()) {
            if (AI_ActionHealObject(oMaster)){
                return TRUE;  }
            else               {
                return FALSE;   }
        }
        else if(GetIsDead(oMaster))//1.71: taught henchman to resurrect his master
        {
            /*
            if(GetHasSpell(SPELL_RESURRECTION))
            {
                if(AI_TalentFilter(TalentSpell(SPELL_RESURRECTION),oMaster))
                    return TRUE;
            }
            else if(GetHasSpell(SPELL_RAISE_DEAD))
            {
                if(AI_TalentFilter(TalentSpell(SPELL_RAISE_DEAD),oMaster))
                    return TRUE;
            }
            */
            int nRnd;
            talent tUse = GetCreatureTalentBest(TALENT_CATEGORY_BENEFICIAL_CONDITIONAL_SINGLE,0);
            while(GetIsTalentValid(tUse) && nRnd++ < 10)
            {
                if(GetTypeFromTalent(tUse) == TALENT_TYPE_SPELL && (GetIdFromTalent(tUse) == SPELL_RESURRECTION || GetIdFromTalent(tUse) == SPELL_RAISE_DEAD))
                {
                    ClearAllActions();
                    ActionUseTalentOnObject(tUse,oMaster);
                    return TRUE;
                }
                tUse = GetCreatureTalentBest(TALENT_CATEGORY_BENEFICIAL_CONDITIONAL_SINGLE,0);
            }
        }
    }

    // * No healing done, continue with combat round
    return FALSE;
}

//::///////////////////////////////////////////////
//:: AI_GetBehavior
//:: Copyright (c) 2001 Bioware Corp.
//:://////////////////////////////////////////////
/*
    Set/get functions for CONTROL PANEL behavior
*/
//:://////////////////////////////////////////////
//:: Created By:
//:: Created On:
//:://////////////////////////////////////////////

int AI_GetBehavior(int nBehavior)
{
    return GetLocalInt(OBJECT_SELF, "NW_L_BEHAVIOR" + IntToString(nBehavior));
}

void AI_SetBehavior(int nBehavior, int nValue)
{
    SetLocalInt(OBJECT_SELF, "NW_L_BEHAVIOR"+IntToString(nBehavior), nValue);
}

//::///////////////////////////////////////////////
//:: AI_CombatFollowMaster
//:: Copyright (c) 2001 Bioware Corp.
//:://////////////////////////////////////////////
/*
    Forces the henchman to follow the player.
    Will even do this in the middle of combat if the
    distance it too great
*/
//:://////////////////////////////////////////////
//:: Created By:
//:: Created On:
//:://////////////////////////////////////////////

int AI_CombatFollowMaster()
{
    object oMaster = GetMaster();
    int iAmHenchman = (GetHenchman(oMaster) == OBJECT_SELF);
    int iAmFamiliar = (GetAssociate(ASSOCIATE_TYPE_FAMILIAR,oMaster) == OBJECT_SELF);

    if(AI_GetBehavior(AI__CURRENT_AI_MODE) != AI__AI_MODE_RUN_AWAY)
    {
        // * double follow threshold if in combat (May 2003)
        float fFollowThreshold = AI__FOLLOW_THRESHOLD;
        if (GetIsInCombat(OBJECT_SELF))
        {
            fFollowThreshold = AI__FOLLOW_THRESHOLD * 2.0;
        }
        if(GetDistanceToObject(oMaster) > fFollowThreshold)
        {
            if(GetCurrentAction(oMaster) != ACTION_FOLLOW)
            {
                ClearAllActions(CLEAR_X0_INC_HENAI_CombatFollowMaster1);
                //MyPrintString("*****EXIT on follow master.*******");
                ActionForceFollowObject(GetMaster(), GetFollowDistance());
                return TRUE;
            }
        }
    }


//       4. If in 'NEVER FIGHT' mode will not fight but should TELL the player
//      that they are in NEVER FIGHT mode
    if (AI_GetBehavior(AI__NEVERFIGHT))
    {

    ClearAllActions(CLEAR_X0_INC_HENAI_CombatFollowMaster2);
//    ActionWait(6.0);
//    ActionDoCommand(DelayCommand(5.9, SetCommandable(TRUE)));
//    SetCommandable(FALSE);
        if (d10() > 7)
        {
            if (iAmHenchman || iAmFamiliar)
                PlayVoiceChat(VOICE_CHAT_LOOKHERE);
        }
    return TRUE;
    }


    return FALSE;
}


//Pausanias: Is Object in the line of sight of the seer
int AI_GetIsInLineOfSight(object oTarget,object oSeer=OBJECT_SELF)
{
    // * if really close, line of sight
    // * is irrelevant
    // * if this check is removed it gets very annoying
    // * because the player can block line of sight
    if (GetDistanceBetween(oTarget, oSeer) < 6.0)
    {
        return TRUE;
    }

    return LineOfSightObject(oSeer, oTarget);

}

// Get the cosine of the angle between the two objects
float AI_GetCosAngleBetween(object Loc1, object Loc2)
{
    vector v1 = GetPositionFromLocation(GetLocation(Loc1));
    vector v2 = GetPositionFromLocation(GetLocation(Loc2));
    vector v3 = GetPositionFromLocation(GetLocation(OBJECT_SELF));

    v1.x -= v3.x; v1.y -= v3.y; v1.z -= v3.z;
    v2.x -= v3.x; v2.y -= v3.y; v2.z -= v3.z;

    float dotproduct = v1.x*v2.x+v1.y*v2.y+v1.z*v2.z;

    return dotproduct/(VectorMagnitude(v1)*VectorMagnitude(v2));

}

//Pausanias: Is there a closed door in the line of sight.
// * is door in line of sight
int AI_GetIsDoorInLineOfSight(object oTarget)
{
    float fMeDoorDist;

    object oView = GetFirstObjectInShape(SHAPE_SPHERE, 40.0,
                                         GetLocation(OBJECT_SELF),
                                         TRUE,OBJECT_TYPE_DOOR);

    float fMeTrapDist = GetDistanceBetween(oTarget,OBJECT_SELF);

    while (GetIsObjectValid(oView)) {
        fMeDoorDist = GetDistanceBetween(oView,OBJECT_SELF);
        //SpeakString("Trap3 : "+FloatToString(fMeTrapDist)+" "+FloatToString(fMeDoorDist));
        if (fMeDoorDist < fMeTrapDist && !GetIsTrapped(oView))
            if (GetIsDoorActionPossible(oView,DOOR_ACTION_OPEN) ||
                GetIsDoorActionPossible(oView,DOOR_ACTION_UNLOCK)) {
                float fAngle = AI_GetCosAngleBetween(oView,oTarget);
                //SpeakString("Angle: "+FloatToString(fAngle));
                if (fAngle > 0.5) {
                    // if (d10() > 7)
                    // SpeakString("There's something fishy near that door...");
                    return TRUE;
                }
            }

        oView = GetNextObjectInShape(SHAPE_SPHERE,40.0,
                                     GetLocation(OBJECT_SELF),
                                     TRUE, OBJECT_TYPE_DOOR);
    }

    //SpeakString("No matches found");
    return FALSE;
}


/* void main() {} /* */

