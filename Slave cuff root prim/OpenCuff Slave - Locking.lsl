//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//Cuff Command Interpreter
// alotn reused from OpenCollar rlvmain module, see comment below

//=============================================================================
//== OC Cuff - Color and Texture Parser
//== receives messages from linkmessages send within the Cuff
//== annd applies Colora and Texture changes
//==
//==
//== 2009-01-16 Cleo Collins - 1. draft
//==
//==
//=============================================================================


//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//new viewer checking method, as of 2.73
//on rez, restart script
//on script start, query db for rlvon setting
//on rlvon response, if rlvon=0 then just switch to checked state.  if rlvon=1 or rlvon=unset then open listener, do @version, start 30 second timer
//on listen, we got version, so stop timer, close listen, turn on rlv flag, and switch to checked state
//on timer, we haven't heard from viewer yet.  Either user is not running RLV, or else they're logging in and viewer could not respond yet when we asked.
//so do @version one more time, and wait another 30 seconds.
//on next timer, give up. User is not running RLV.  Stop timer, close listener, set rlv flag to FALSE, save to db, and switch to checked state.

string    g_szModToken    = "llac"; // valid token for this module, TBD need to be read more global

key g_keyWearer;

// Messages to be received
string g_szLockCmd="Lock"; // message for setting lock on or off
string g_szSubOwnerMsg="subowner"; // info on owner
string g_szInfoRequest="SendLockInfo"; // request info about RLV and Lock status from main cuff

// name of occ part for requesting info from the master cuff
// NOTE: for products other than cuffs this HAS to be change for the OCC names or the your items will interferre with the cuffs
list lstCuffNames=["Not","chest","skull","lshoulder","rshoulder","lhand","rhand","lfoot","rfoot","spine","ocbelt","mouth","chin","lear","rear","leye","reye","nose","ruac","rlac","luac","llac","rhip","rulc","rllc","lhip","lulc","lllc","ocbelt","rpec","lpec","HUD Center 2","HUD Top Right","HUD Top","HUD Top Left","HUD Center","HUD Bottom Left","HUD Bottom","HUD Bottom Right"];


// cuff LM message map
integer    LM_CUFF_CMD        = -551001;
integer    LM_CUFF_ANIM    = -551002;

integer g_nLocked=FALSE; // is the cuff locked

integer g_nUseRLV=FALSE; // should RLV be used

integer g_nLockedState=FALSE; // state submitted to RLV viewer

list g_lstSubOwners; // owner of the sub t send information about detaching while locked
string g_szIllegalDetach="";
key g_keyFirstOwner;

integer viewercheck = FALSE;//set to TRUE if viewer is has responded to @version message
integer listener;

float versiontimeout = 30.0;
integer versionchannel = 293847;
integer checkcount;//increment this each time we say @version.  check it each time timer goes off in default state. give up if it's >= 2
string rlvString = "RestrainedLife viewer v1.15";

//"checked" state - HANDLING RLV SUBMENUS AND COMMANDS
//on start, request RLV submenus
//on rlv submenu response, add to list
//on main submenu "RLV", bring up this menu

integer g_nCmdChannel    = -190890;
integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for

//===============================================================================
//= parameters   :    string    szSendTo    prefix of receiving modul
//=                    string    szCmd       message string to send
//=                    key        keyID        key of the AV or object
//=
//= retun        :    none
//=
//= description  :    Sends the command with the prefix and the UUID
//=                    on the command channel
//=
//===============================================================================
SendCmd( string szSendTo, string szCmd, key keyID )
{
    llRegionSay(g_nCmdChannel, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
    //llWhisper(0, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}

//===============================================================================
//= parameters   :  integer nOffset        Offset to make sure we use really a unique channel
//=
//= description  : Function which calculates a unique channel number based on the owner key, to reduce lag
//=
//= returns      : Channel number to be used
//===============================================================================
integer nGetOwnerChannel(integer nOffset)
{
    integer chan = (integer)("0x"+llGetSubString((string)g_keyWearer,3,8)) + g_nCmdChannelOffset;
    if (chan>0)
    {
        chan=chan*(-1);
    }
    if (chan > -10000)
    {
        chan -= 30000;
    }
    return chan;
}



//===============================================================================
//= parameters   :    string    szMsg   message string received
//=
//= return        :    none
//=
//= description  :    output debug messages
//=
//===============================================================================


Debug(string szMsg)
{
    llOwnerSay(llGetScriptName() + ": " + szMsg);
}

//===============================================================================
//= parameters   :    string    szMsg   message string received
//=
//= return        :    integer TRUE/FALSE
//=
//= description  :    checks if a string begin with another string
//=
//===============================================================================

integer nStartsWith(string szHaystack, string szNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return (llDeleteSubString(szHaystack, llStringLength(szNeedle), -1) == szNeedle);
}


//===============================================================================
//= parameters   :    none
//=
//= return        :    none
//=
//= description  :    send locking and RLV info to slave cuffs
//=
//===============================================================================

SetLocking()
{
    //Debug("vc: "+(string)viewercheck+"; RLV: "+(string)g_nUseRLV+"; Lock: "+(string)g_nLocked);
    if (viewercheck)
    {   // RLV is alive and we want to use it
        if (g_nLocked&&g_nUseRLV)
            // lock or unlock cuff as needed in RLV
        {
            if (!g_nLockedState)
            {
                g_nLockedState=TRUE;
                llOwnerSay("@detach=n");
            }
        }
        else
        {
            if (g_nLockedState)
            {
                g_nLockedState=FALSE;
                llOwnerSay("@detach=y");
            }
        }

    }

}

//===============================================================================
//= parameters   :    none
//=
//= return        :    none
//=
//= description  :    checks if RLV is available
//=
//===============================================================================

CheckVersion()
{
    //llOwnerSay("checking version");
    //open listener
    listener = llListen(versionchannel, "", g_keyWearer, "");
    //start timer
    llSetTimerEvent(versiontimeout);
    //do ownersay
    checkcount++;
    llOwnerSay("@version=" + (string)versionchannel);
}

//===============================================================================
//= parameters   :    none
//=
//= return        :    string    szMsg   message string received
//=
//= description  :    read name of cuff from attachment spot
//=
//===============================================================================


string GetCuffName()
{
    return llList2String(lstCuffNames,llGetAttached());
}

NotifyAllOwners()
{
    integer i;
    integer m=llGetListLength(g_lstSubOwners);

    for (i=0;i<m;i=i+2)
    {
        llInstantMessage(llList2Key(g_lstSubOwners,i), llKey2Name(g_keyWearer) + " has detached me while locked ("+g_szIllegalDetach+")!");
    }
    g_szIllegalDetach="";
}

default
{
    on_rez(integer param)
    {
        if ((g_szIllegalDetach!="") && (g_keyWearer==llGetOwner()))
        {
            NotifyAllOwners();
        }
        llResetScript();
    }

    state_entry()
    {  // wait for init and start RLV check
        g_szModToken=GetCuffName();
        g_keyWearer=llGetOwner();
        // get unique channel numbers for the command and cuff channel, cuff channel wil be used for LG chains of cuffs as well
        g_nCmdChannel = nGetOwnerChannel(g_nCmdChannelOffset);

        viewercheck = TRUE;
        state checked;

        //llSleep(1.0);
        //CheckVersion();
    }

    listen(integer channel, string name, key id, string message)
    {
        if (channel == versionchannel)
        {
            //llOwnerSay("heard " + message);
            llListenRemove(listener);
            llSetTimerEvent(0.0);
            //get the version to send to rlv plugins
            string rlvVersion = llList2String(llParseString2List(message, [" "], []), 2);
            list temp = llParseString2List(rlvVersion, ["."], []);
            string majorV = llList2String(temp, 0);
            string minorV = llList2String(temp, 1);
            rlvVersion = llGetSubString(majorV, -1, -1) + llGetSubString(minorV, 0, 1);
            //this is already TRUE if rlvon=1 in the DB, but not if rlvon was unset.  set it to true here regardless, since we're setting rlvon=1 in the DB
            //i think this should always be said
            //            if (verbose)
            //            {
            //                llOwnerSay("Restrained Life functions enabled. " + message + " detected.");
            //            }
            viewercheck = TRUE;
            state checked;
        }
    }

    link_message(integer nSenderNum, integer nNum, string szMsg, key keyID)
    {
        // make sure to check any values comming in for us while we still do the version checking
        if (nNum == LM_CUFF_CMD)
        {
            // any lock command?
            if (nStartsWith(szMsg,g_szLockCmd))
            {
                list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
                if (llList2String(lstCmdList,1)=="on")
                {
                    g_nLocked=TRUE;
                }
                else
                {
                    g_nLocked=FALSE;
                }
            }
            // or owner message, TBD
            else if (nStartsWith(szMsg,g_szSubOwnerMsg))
            {
                // store the subowner for detach warning
                list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
                g_lstSubOwners=llParseString2List(llList2String(lstCmdList,1), [","], [""]);

                // now store the first owner for asap notify on detach
                g_keyFirstOwner=NULL_KEY;
                integer m=llGetListLength(g_lstSubOwners);
                integer i;
                for (i=0;i<m;i=i+2)
                {
                    if (llList2Key(g_lstSubOwners,i)!=g_keyWearer)
                    {
                        g_keyFirstOwner=llList2Key(g_lstSubOwners,i);
                        i=m;
                    }
                }

            }
            // or info about RLV to be used
            else if (nStartsWith(szMsg,"rlvon"))
            {
                // store the subowner for detach warning
                g_nUseRLV=TRUE;
            }
            // or info about RLV NOT to be used
            else if (nStartsWith(szMsg,"rlvoff"))
            {
                // store the subowner for detach warning
                g_nUseRLV=FALSE;
            }

        }
    }



    timer()
    {
        llListenRemove(listener);
        llSetTimerEvent(0.0);
        if (checkcount == 1)
        {   //the viewer hasn't responded after 30 seconds, but maybe it was still logging in when we did @version
            //give it one more chance
            CheckVersion();
        }
        else if (checkcount >= 2)
        {   //we've given the viewer a full 60 seconds
            viewercheck = FALSE;
            //else the user normally logs in with RLv, but just not this time
            //in which case, leave it turned on in the database, until user manually changes it
            //i think this should always be said
            //            if (verbose)
            //            {
            // Maybe remove this, as the owner my get flooded, need to be decided and as well discussed witrh community
            llOwnerSay("Could not detect Restrained Life Viewer.  Restrained Life functions disabled.");
            //            }

            //DEBUG force rlvon and viewercheck for now, during development
            //viewercheck = TRUE;
            //rlvon = TRUE;
            //llOwnerSay("DEBUG: rlv on");

            state checked;
        }
    }
}

state checked
    // The chekc for RLV is finished, we are now in normal run state
{
    on_rez(integer param)
    {
        if ((g_szIllegalDetach!="") && (g_keyWearer==llGetOwner()))
        {
            NotifyAllOwners();
        }
        llResetScript();
    }

    attach(key id)
    {
        // clear all RLV commands on detaching, if RLV is used
        //if (id == NULL_KEY && viewercheck)
        //{
        //    llOwnerSay("@clear");
        //}
        // notify owner of sub
        if (g_nLocked && id == NULL_KEY)
        {
            // notify owner of dettachign, could be spaming, but well, more trouble for the sub *giggles*
            g_szIllegalDetach=llGetTimestamp();
            if (g_keyFirstOwner!=NULL_KEY) llInstantMessage(g_keyFirstOwner, llKey2Name(g_keyWearer) + " has detached me while locked!");

        }

    }

    state_entry()
    {
        // request infos from main cuff
        SendCmd("rlac",g_szInfoRequest,g_keyWearer);
        // and set all now existing lockstates
        SetLocking();
    }

    link_message(integer sender, integer nNum, string szMsg, key id)
    {
        if (nNum == LM_CUFF_CMD)
            // message for cuff received
        {
            if (nStartsWith(szMsg,g_szLockCmd))
                // it is a lock commans
            {
                list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
                if (llList2String(lstCmdList,1)=="on")
                {
                    //llOwnerSay("@detach=n");
                    g_nLocked=TRUE;
                }
                else
                {
                    //llOwnerSay("@detach=y");
                    g_nLocked=FALSE;
                }
                // Update Cuff lock status
                SetLocking();
            }
            else if (nStartsWith(szMsg,g_szSubOwnerMsg))
                // OWner of sub received for information service
            {
                // store the subowner for detach warning
                list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
                g_lstSubOwners=llParseString2List(llList2String(lstCmdList,1), [","], [""]);


                // now store the first owner for asap notify on detach
                g_keyFirstOwner=NULL_KEY;
                integer m=llGetListLength(g_lstSubOwners);
                integer i;
                for (i=0;i<m;i=i+2)
                {
                    if (llList2Key(g_lstSubOwners,i)!=g_keyWearer)
                    {
                        g_keyFirstOwner=llList2Key(g_lstSubOwners,i);
                        i=m;
                    }
                }


            }
            else if (szMsg=="rlvon")
                // RLV got activated
            {
                // store the subowner for detach warning
                g_nUseRLV=TRUE;
                // Update Cuff lock status
                SetLocking();

            }
            else if (szMsg=="rlvoff")
                // RLV got deactivated
            {
                // store the subowner for detach warning
                g_nUseRLV=FALSE;
                // Update Cuff lock status
                SetLocking();
            }

        }
    }


}