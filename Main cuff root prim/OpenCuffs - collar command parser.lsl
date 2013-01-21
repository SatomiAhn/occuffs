//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//Cuff Command Interpreter

//=============================================================================
//== OC Cuff - Command forwarder to listen for commands in OpenCollar
//== receives messages from linkmessages send within the collar
//== sends the needed commands out to the cuffs
//==
//==
//==
//=============================================================================

// Show debug Messages?
integer g_nDebugState=FALSE;


// Commands to be send from the collar
string g_szOwnerChangeCmd="OwnerChanged"; //message to be send to

// entry for main menu
string g_szParentmenu = "Main";
string g_szMenuEntry = "Collar Menu";



string g_szColorChangeCmd="ColorChanged";
string g_szTextureChangeCmd="TextureChanged";
string g_szInfoRequest="SendLockInfo"; // request info about RLV and Lock status from main cuff
string g_szHideCmd="HideMe"; // Comand for Cuffs to change the colors
integer g_nHidden=FALSE;
string g_szHiddenToken="hide";


string g_szSubOwnerMsg="subowner";
string g_szLockCmd="Lock";
string g_szUseRLV="UseRLV";

string g_szCuffMenuCmd="CuffMenu";
string g_szSwitchLockCmd="SwitchLock";

string g_szPrefix; // sub prefix for databse actions
integer g_nLocked=FALSE; // are the cuffs logged
integer g_nUseRLV=FALSE; // is RLV to be used


key g_keySubOwner=NULL_KEY; // stores the owner of the sub

list g_lstColorSettings;

integer g_nCollar_Backchannel = -1812221819; // channel for sending back owner changes to the collar

string g_szOwnerChangeCollarInfo="OpenCuff_OwnerChanged"; // command for the collar to reset owner system
string g_szCollarMenuInfo="OpenCollar_ShowMenu"; // command for the collar to show the menu
string g_szRLVChangeToCollarInfo="OpenCuff_RLVChanged"; // command to the collar to inform about RLV usage switched
string g_szRLVChangeFromCollarInfo="OpenCollar_RLVChanged"; // command from the collar to inform about RLV usage switched


integer g_nLastRLVChange=-1;

list g_lstResetOnOwnerChange=["OpenCollar - httpdb - 3.","OpenCollar - auth","OpenCollar - settings"]; // scripts to be reseted on ownerchanges to keep system in sync

key g_keyLockSound="abdb1eaa-6160-b056-96d8-94f548a14dda"; // Sound for locking the collar
key g_keyUnLockSound="ee94315e-f69b-c753-629c-97bd865b7094"; // Sound for unlocking the collar

key g_keyWearer; // wearer(owner of the cuf for saving script time

key g_szColors; // color values for cuffs, need to be resubmitted on each attaching
key g_szTextures; // texture values for cuffs, need to be resubmitted on each attaching
integer g_nCuffs_Visible=TRUE; // visiblity value of the cuffs


// Message Mapper Cuff Communication
integer    LM_CUFF_CMD        = -551001;
integer    LM_CUFF_ANIM    = -551002;

//MESSAGE MAP Collar Scripts
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505; //deprecated.  Too laggy to make every single script parse a link message any time anyone says anything
integer COMMAND_OBJECT = 506;
integer COMMAND_RLV_RELAY = 507;
integer COMMAND_SAFEWORD = 510;  // new for safeword

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
//str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent when a token has no value in the httpdb
integer HTTPDB_REQUEST_NOCACHE = 2005;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;

integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.

// preparation for online mode
string g_szOnlineModeCommand="online";
integer g_nOnline=TRUE;

//
float g_nStartTime=2.5;
integer g_nStarted=FALSE;

integer g_nCmdChannel    = -190890;
integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for


string    g_szModToken    = "rlac"; // valid token for this module, should be mabye requested by LM to be more independent

list resetFirst = ["menu cuffs", "rlvmain", "appearance cuffs"];
string resetScripts = "resetscripts";


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
    llRegionSay(g_nCmdChannel + 1, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
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
    integer chan = (integer)("0x"+llGetSubString((string)llGetOwner(),3,8)) + g_nCmdChannelOffset;
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
    if (g_nDebugState)
    {
        llOwnerSay(llGetScriptName() + ": " + szMsg);
    }
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
//= parameters   :   none
//=
//= return        :    string prefix for the object in the form of "oc_"
//=
//= description  :    generate the prefix from the object desctiption
//=
//===============================================================================


string szGetDBPrefix()
{//get db prefix from list in object desc
    return llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
}

//===============================================================================
//= parameters   :    string    szStr   String to be stripped
//=
//= return        :    string stStr without spaces
//=
//= description  :    strip the spaces out of a string, needed to as workarounfd in the LM part of OpenCollar - color
//=
//===============================================================================

string x_szStripSpaces (string szStr)
{
    return llDumpList2String(llParseString2List(szStr, [" "], []), "");
}

//===============================================================================
//= parameters   :   string    szMsg   message string received
//=
//= return        :    none
//=
//= description  :    gets called when a command to save into the HTTPDB is detected
//=                    analyzes if the save would need any update in th cuffs
//=
//===============================================================================

Analyse_HTTPDB_Save(string szMsg)
{
    // split the message into token and message
    list lstParams = llParseString2List(szMsg, ["="], []);
    string szToken = llList2String(lstParams, 0);
    string szValue = llList2String(lstParams, 1);
    // now scheck if we have to take action
    if ((szToken=="owner")||(szToken=="secowners")||(szToken=="group")||(szToken=="openaccess")||(szToken=="blacklist"))
    {
        if (g_nOnline)
        {
            // owner right have been changed,, inform the collar using the object backtalk which is send in the collar as LM
            // the collar wil reacht (currently by resseting httpdb and auth scripts
            llWhisper(g_nCollar_Backchannel,g_szOwnerChangeCollarInfo+"="+szMsg+"|" + (string)g_keyWearer);
        }

    }
}

//===============================================================================
//= parameters   :   string    szMsg   message string received
//=
//= return        :    none
//=
//= description  :    gets called when a command to delete a value stored in the HTTPDB is detected
//=                    analyzes if the delete would need any update in th cuffs
//=
//===============================================================================

Analyse_HTTPDB_Delete(string szMsg)
{
    if ((szMsg=="owner")||(szMsg=="secowners")||(szMsg=="group")||(szMsg=="openaccess")||(szMsg=="blacklist"))
    {
        // owner right have been changed,, inform the cuffs
        llWhisper(g_nCollar_Backchannel,g_szOwnerChangeCollarInfo+"="+szMsg+"|" + (string)g_keyWearer);
    }

}

//===============================================================================
//= parameters   :   string    szColorString   string with objectnames and colors
//=
//= return        :    none
//=
//= description  :    break up the Itemnams and Color into seveal commands
//=                    and send them out to the cuffs
//=
//===============================================================================


SendRecoloring ()
{
    list lstColorList=llParseString2List(g_szColors, ["~"], []);
    integer nColorCount=llGetListLength(lstColorList);
    integer i;
    for (i=0;i<nColorCount;i=i+2)
    {
        llRegionSay(g_nCmdChannel+1,"rlac|*|"+g_szColorChangeCmd+"="+llList2String(lstColorList,i)+"="+llList2String(lstColorList,i+1)+"|" + (string)llGetOwner());
    }

}

//===============================================================================
//= parameters   :   string    szTextureString   string with objectnames and texture IDs
//=
//= return        :    none
//=
//= description  :    break up the Itemnams and texture IDs into several commands
//=                    and send them out to the cuffs
//=
//===============================================================================


SendRetexturing ()
{
    list lstTextureList=llParseString2List(g_szTextures, ["~"], []);
    integer nTextureCount=llGetListLength(lstTextureList);
    integer i;
    for (i=0;i<nTextureCount;i=i+2)
    {
        llRegionSay(g_nCmdChannel+1,"rlac|*|"+g_szTextureChangeCmd+"="+llList2String(lstTextureList,i)+"="+llList2String(lstTextureList,i+1)+"|" + (string)llGetOwner());
    }

}

//===============================================================================
//= parameters   :   key    keySender   key of person sending the info
//=
//= return        :    none
//=
//= description  :    sends infos to the slave cuffs
//=
//===============================================================================


SendInfoToSlaves(key keySender)
{
    if (!g_nStarted) return; // only send info after a start delay

    string szSendMsg;
    // send RLV usuage status
    if (g_nUseRLV)
    {
        szSendMsg+="rlvon";
    }
    else
    {
        szSendMsg+="rlvoff";
    }
    // send lock status
    if (g_nLocked)
    {
        szSendMsg+="~"+g_szLockCmd+"=on";
    }
    else
    {
        szSendMsg+="~"+g_szLockCmd+"=off";
    }
    szSendMsg+="~"+"subowner="+(string)g_keySubOwner;
    SendCmd("*",szSendMsg,keySender);

    szSendMsg=g_szHideCmd+"="+(string)g_nHidden;
    SendCmd("*",szSendMsg,keySender);

    // and make sure all colors and texture are in sync as well
    SendRecoloring();
    SendRetexturing ();
}

ScriptReseter()
{
    integer i;
    integer j;
    integer nMaxScripts=llGetInventoryNumber(INVENTORY_SCRIPT);
    integer nMaxResetScripts=llGetListLength(g_lstResetOnOwnerChange);
    string sz_CurrentScript;
    for (i=0;i<nMaxScripts;i++)
    {
        sz_CurrentScript=llGetInventoryName(INVENTORY_SCRIPT,i);
        for (j=0;j<nMaxResetScripts;j++)
        {
            if (nStartsWith(sz_CurrentScript,llList2String(g_lstResetOnOwnerChange,j)))
            {
                llResetOtherScript(sz_CurrentScript);
                llSleep(1.5);
            }
        }
    }

    llSetTimerEvent(5); // give the scripts time to laod and than send the infos again to the subcuffs
}

SafeResetOther(string scriptname)
{
    if (llGetInventoryType(scriptname) == INVENTORY_SCRIPT)
    {
        llResetOtherScript(scriptname);
        llSetScriptState(scriptname, TRUE);
    }
}

integer isOpenCollarScript(string name)
{
    name = llList2String(llParseString2List(name, [" - "], []), 0);
    if ((name == "OpenCollar")||(name == "OpenCuffs"))
    {
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}


OrderlyReset(integer fullReset, integer isUpdateReset)
{
    string fullScriptName;
    string scriptName;
    string thisscriptName=llGetScriptName ();
    integer scriptNumber = llGetInventoryNumber(INVENTORY_SCRIPT);
    integer resetNext = 0;
    integer i;
    llOwnerSay("OpenCollar scripts initializing...");
    
    for (i=0;i<scriptNumber;i++)
    {
        scriptName=llGetInventoryName(INVENTORY_SCRIPT,i);
        if (thisscriptName!=scriptName)
        {
            llResetOtherScript(scriptName);
        }
    }
    llResetScript();
    
    // prob unneeded from here
    
    
    while(resetNext <= llGetListLength(resetFirst) - 1)
    {   //reset script from the resetFirst list in order of their list position
        for (i = 0; i < scriptNumber; i++)
        {
            fullScriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
            scriptName = llList2String(llParseString2List(fullScriptName, [" - "], []) , 1);
            if(isOpenCollarScript(fullScriptName))
            {
                integer scriptPos = llListFindList(resetFirst, [scriptName]);
                if (scriptPos != -1)
                {
                    if(scriptPos == resetNext)
                    {//do not reset rlvmain on rez only on a full reset
                        resetNext++;
                        if (fullReset)
                        {
                            SafeResetOther(fullScriptName);
                        }
                        else if (scriptName != "rlvmain" && scriptName != "settings")
                        {
                            SafeResetOther(fullScriptName);
                        }
                    }
                }
            }
        }
    }
    for (i = 0; i < scriptNumber; i++)
    {   //reset all other OpenCollar scripts
        fullScriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
        scriptName = llList2String(llParseString2List(fullScriptName, [" - "], []) , 1);
        if(isOpenCollarScript(fullScriptName) && llListFindList(resetFirst, [scriptName]) == -1)
        {
            if(fullScriptName != llGetScriptName() && scriptName != "settings" && scriptName != "updateManager")
            {
                SafeResetOther(fullScriptName);
            }
        }
        //take care of non OC script that were set to "not running" for the update, do not reset but set them back to "running"
        else //if (isUpdateReset)
        {
            if(!llGetScriptState(fullScriptName))
            {
                if (llGetInventoryType(fullScriptName) == INVENTORY_SCRIPT)
                {
                    llSetScriptState(fullScriptName, TRUE);
                }
            }
        }
    }
    llSleep(1.5);
    llMessageLinked(LINK_SET, COMMAND_OWNER, "refreshmenu", NULL_KEY);
}



default
{
    state_entry()
    {
        // How is our memory?
        Debug("Available memory: "+(string)llGetFreeMemory());

        g_keyWearer=llGetOwner();

        g_nCmdChannel = nGetOwnerChannel(g_nCmdChannelOffset); // get the owner defined channel

        // setup user specific backchannel
        g_nCollar_Backchannel = (integer)("0x" + llGetSubString(g_keyWearer,30,-1));
        if (g_nCollar_Backchannel > 0) g_nCollar_Backchannel = -g_nCollar_Backchannel;



        //get dbprefix from object desc, so that it doesn't need to be hard coded, and scripts between differently-primmed collars can be identical
        g_szPrefix = szGetDBPrefix();

        // till we know better, the wearer is the owner
        g_keySubOwner=g_keyWearer;

        llSleep(1.0);

        //SendInfoToSlaves(llGetOwner());
        g_nStarted=FALSE;
        llSetTimerEvent(g_nStartTime);

        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_szParentmenu + "|" + g_szMenuEntry, NULL_KEY);

    }

    timer()
    {
        g_nStarted=TRUE;
        SendInfoToSlaves(g_keyWearer);
        llSetTimerEvent(0);
    }

    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            g_keyWearer=llGetOwner();
            llResetScript();
        }
    }

    on_rez(integer start_param)
    {
        llResetScript();
    }

    link_message(integer nSenderNum, integer nNum, string szMsg, key keyID)
    {
//llOwnerSay("Parser mem:"+(string)llGetFreeMemory());        
        if (nNum == LM_CUFF_CMD)
            // cuff command received
        {
            // reset requested
            if ( szMsg == "reset" )
            {
                llResetScript();
            }
            // Menu call from slave cuffs or Collar received, run through auth system
            else if (szMsg == "menu" )
            {
                llMessageLinked(LINK_THIS,COMMAND_NOAUTH,"menu",keyID);
            }
            else if (nStartsWith(szMsg,g_szCuffMenuCmd))
            {
                list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
                llMessageLinked(LINK_THIS,COMMAND_NOAUTH,"menu",llList2Key(lstCmdList,1));
            }

            // the owner hs changed, now react, damn!
            else if (nStartsWith(szMsg,g_szOwnerChangeCmd))
            {
                // to properly handle onwerchnages we have to reset the httpdb so it reparses the seetings and the auth scripts
                if (g_nOnline)
                {
                    // to properly handle onwerchnages we have to reset the httpdb so it reparses the seetings and the auth scripts
                    llOwnerSay("Setting in the owner system changed, reloading to syncronize!");
                    // now for resetting
                    ScriptReseter();


                }
                else
                {
                    llOwnerSay("The owners of your collar changed, but will not be kept in sync, as your cuffs are in offline modus!");
                }

            }
            else if (nStartsWith(szMsg,g_szSwitchLockCmd))
            {
                // received command switch lock status of the cuffs, run them through the auth system
                list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );

                if (g_nLocked)
                {
                    llMessageLinked(LINK_THIS,COMMAND_NOAUTH,"unlock",llList2Key(lstCmdList,1));
                }
                else
                {
                    llMessageLinked(LINK_THIS,COMMAND_NOAUTH,"lock",llList2Key(lstCmdList,1));
                }
            }
            // a color change been received
            else if (nStartsWith(szMsg,g_szColorChangeCmd))
            {
                // temp forward to all cuffs till design discussion about this is fixed
                SendCmd("*",szMsg,keyID);
                // a change of colors has occured, make sure the cuff try to set identiccal to the collar
                list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
                // send LM to change color, make sure it color vecor has no spaces so the bug in the color module is avoided
                llMessageLinked(LINK_THIS,COMMAND_WEARER,"setcolor "+llList2String(lstCmdList,1)+" "+llList2String(lstCmdList,2),keyID);

            }
            // a texture change has been received
            else if (nStartsWith(szMsg,g_szTextureChangeCmd))
            {
                // temp forward to lwc till issue with this is fixed
                SendCmd("*",szMsg,keyID);
                // a change of colors has occured, make sure the cuff try to set identiccal to the collar
                list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
                llMessageLinked(LINK_THIS,COMMAND_WEARER,"settexture "+llList2String(lstCmdList,1)+" "+llList2String(lstCmdList,2),keyID);
            }
            // a cuff requested info about the lock status
            else if (szMsg==g_szInfoRequest)
            {
                if (g_nStarted)
                {
                    g_nStarted=FALSE;
                    llSetTimerEvent(g_nStartTime);
                    // the timer wil now take care of this after 5 seconds
                    // SendInfoToSlaves(g_keyWearer);
                }
            }
            else if (nStartsWith(szMsg,g_szRLVChangeFromCollarInfo))
            {
                list lstCmdList = llParseString2List( szMsg, [ "=" ], [] );
                if (llList2String(lstCmdList,1)=="on")
                {
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "rlvon", llList2Key(lstCmdList,2));
                }
                else
                {
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "rlvoff", llList2Key(lstCmdList,2));

                }
                g_nLastRLVChange=llGetUnixTime();
            }
            else if ((szMsg=="SAFEWORD")&&(g_keyWearer==keyID))
            {
                llMessageLinked(LINK_THIS, COMMAND_SAFEWORD, "", NULL_KEY);
            }

        }

        // now OC LMs get parsed
        if ((nNum == HTTPDB_RESPONSE)||(nNum == HTTPDB_SAVE))
            // listen if the cuffs are locked
        {
            //Debug("1:"+szMsg);
            list params = llParseString2List(szMsg, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == g_szPrefix+ g_szHiddenToken)
            {
                g_nHidden=(integer)value;
            }
            else if (token == g_szPrefix+"locked")
                // saving or loading of lock variable found, store its value
            {
                if ((integer)value==1)
                {
                    g_nLocked=TRUE;
                }
                else
                {
                    g_nLocked=FALSE;
                }
                // Insert playing of sound here
                if (g_nLocked)
                {
                    llPlaySound(g_keyLockSound,1.0);
                }
                else
                {
                    llPlaySound(g_keyUnLockSound,1.0);
                }
                SendInfoToSlaves(g_keyWearer);
            }
            else if (token == "owner")
                // promary owner reuqested or changed
            {
                g_keySubOwner=(key)value;
                SendCmd("*","subowner="+value,g_keyWearer);
            }
            /* // removed ass this si not reliable, instead w use the LM "rlvon"/"rlvoff" and RLV_REFRESH
                else if (token == "rlvon")
                    // rlv enabled or disabled?
                {
                    if (value=="1")
                    {
                        g_nUseRLV=TRUE;
                    }
                    else if (value=="0") // this is to deal with the unset mode, if unset the rlvmain script should send a message
                    {
                        g_nUseRLV=FALSE;
                    }
                    SendInfoToSlaves(g_keyWearer);
                }
            */
                else if (token==g_szOnlineModeCommand)
                    // is the collar in online mode?
                {
                    if (value=="1")
                    {
                        g_nOnline=TRUE;
                    }
                    else
                    {
                        g_nOnline=FALSE;
                    }

                }
            else if (token==g_szPrefix+"colorsettings")
                // keep color setting for resubmitting to slave cuffs
            {
                g_szColors=value;
                //if (nNum == HTTPDB_RESPONSE) SendRecoloring();
            }
            else if (token==g_szPrefix+"textures")
                // keep textue setting for resubmitting to slave cuffs
            {
                g_szTextures=value;
                //if (nNum == HTTPDB_RESPONSE) SendRetexturing ();
            }
        }
        if (nNum == HTTPDB_SAVE)
        {
            // the cuff saves to the HTTDB, so analyse the values if we have to react
            Analyse_HTTPDB_Save(szMsg);
        }
        if (nNum == HTTPDB_DELETE)
        {
            // listen if the cuffs get unlocked
            if (szMsg == g_szPrefix+"locked")
                // deleting of lock variable found, store false
            {
                g_nLocked=FALSE;
                // send command to unlock to the slave cuffs
                SendInfoToSlaves(g_keyWearer);
                // play audio
                llPlaySound(g_keyUnLockSound,1.0);

            }
            else if (szMsg == g_szPrefix+ g_szHiddenToken)
            {
                g_nHidden=FALSE;
            }
            else // it is not about locking, so do further analysing
            {
                // the cuff saves to the HTTDB, so analyse the command
                Analyse_HTTPDB_Delete(szMsg);
            }

        }

        if (nNum == RLV_REFRESH)
            // workaround as the RLVmain script detected RLV and decided to force RLVON to true, but does NOT save it (becuase RLVON=unset in the default notecard. TBD: Fix that behaviour of the collar/cuffs)
        {
            g_nUseRLV=TRUE;
            SendInfoToSlaves(g_keyWearer);
        }

        if (nNum >= COMMAND_OWNER && nNum <= COMMAND_WEARER)
            // check if a owner command comes through and if it is about disabling RLV
        {
            if (szMsg == "rlvon" )
            {
                g_nUseRLV=TRUE;
                SendInfoToSlaves(g_keyWearer);
                if(llGetUnixTime()>g_nLastRLVChange+10)
                {
                    llWhisper(g_nCollar_Backchannel,g_szRLVChangeToCollarInfo+"=on="+(string)keyID);
                    g_nLastRLVChange=llGetUnixTime();
                }

            }
            else if (szMsg == "resend_appearance" )
            {

                SendInfoToSlaves(g_keyWearer);

            }
            else if (szMsg == "refreshmenu")
            {

                llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_szParentmenu + "|" + g_szMenuEntry, NULL_KEY);
            }
            else if( (keyID ==g_keyWearer  && nNum <= COMMAND_WEARER && nNum >= COMMAND_OWNER) || nNum == COMMAND_OWNER)
            {
                if (szMsg == resetScripts)
                {
                    Debug(szMsg + (string)nNum);
                    OrderlyReset(TRUE, FALSE);
                    llMessageLinked(LINK_SET,LM_CUFF_CMD,"resetscripts",keyID);
                }
            }

        }

        if (nNum == COMMAND_OWNER)
            // check if a owner command comes through and if it is about enabling RLV
        {
            if (szMsg == "rlvoff" )
            {
                g_nUseRLV=FALSE;
                SendInfoToSlaves(g_keyWearer);
                if(llGetUnixTime()>g_nLastRLVChange+10)
                {
                    llWhisper(g_nCollar_Backchannel,g_szRLVChangeToCollarInfo+"=off="+(string)keyID);
                    g_nLastRLVChange=llGetUnixTime();
                }


            }
        }
        if (nNum == MENUNAME_REQUEST && szMsg == g_szParentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_szParentmenu + "|" + g_szMenuEntry, NULL_KEY);
        }
        if (nNum == SUBMENU)
        {
            if (szMsg == g_szMenuEntry)
            {
                llWhisper(g_nCollar_Backchannel,g_szCollarMenuInfo+"=on="+(string)keyID);

            }
        }

    }

}
