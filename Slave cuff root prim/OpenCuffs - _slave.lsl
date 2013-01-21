//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//listener

//=============================================================================
//== OC Cuff - slave listen module
//== receives messages from exernal objects
//==
//== 2009-01-16 Jenny Sigall - 1. draft
//==
//==
//=============================================================================
integer g_nCmdChannel    = -190890;        // command channel
integer    g_nCmdHandle    = 0;            // command listen handler
integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for


key        g_keyWearer        = NULL_KEY;        // key of the owner/wearer

integer    LM_CUFF_CMD        = -551001;
integer    LM_CUFF_ANIM    = -551002;
integer    LM_CUFF_CUFFPOINTNAME = -551003;

integer    g_nDebug        = FALSE;
integer    g_nShowScript    = FALSE;

list lstCuffNames=["Not","chest","skull","lshoulder","rshoulder","lhand","rhand","lfoot","rfoot","spine","ocbelt","mouth","chin","lear","rear","leye","reye","nose","ruac","rlac","luac","llac","rhip","rulc","rllc","lhip","lulc","lllc","ocbelt","rpec","lpec","HUD Center 2","HUD Top Right","HUD Top","HUD Top Left","HUD Center","HUD Bottom Left","HUD Bottom","HUD Bottom Right"]; // list of attachment point to resolcve the names for the cuffs system, addition cuff chain point will be transamitted via LMs
// attention, belt is twice in the list, once for stomach. , once for pelvis as there are version for both points

string  g_szAllowedCommadToken = "rlac"; // only accept commands from this token adress
list    g_lstModTokens    = []; // valid token for this module

integer    CMD_UNKNOWN        = -1;        // unknown command - don't handle
integer    CMD_CHAT        = 0;        // chat cmd - check what should happen with it
integer    CMD_EXTERNAL    = 1;        // external cmd - check what should happen with it
integer    CMD_MODULE        = 2;        // cmd for this module

integer    g_nCmdType        = CMD_UNKNOWN;

//
// external command syntax
// sender prefix|receiver prefix|command1=value1~command2=value2|UUID to send under
// occ|rwc|chain=on~lock=on|aaa-bbb-2222...
//
string    g_szReceiver    = "";
string    g_szSender        = "";

integer g_nLockGuardChannel = -9119;



//===============================================================================
//= parameters   :  string szMsg        output message
//=                 string szFunc        function name if not ""
//=                 integer nScript        send scriptname ?
//=                 integer nChannel    channel to be sent on -1 = llOwnerSay
//=
//= description  : Function for debug output.
//=                If g_nDebug is FALSE = no output is sent
//=                If g_nShowScript is FALSE = scriptname always shown
//=
//===============================================================================
akDebug(string szMsg, string szFunc, integer nScript, integer nChannel)
{
    if ( g_nDebug )
    {
        string    szOutput    = "\nDebug Output :\n=============";

        if( szFunc != "" )
            szOutput += "\nFunction : " + szFunc;

        if ( nScript || g_nShowScript)
            szOutput += "\nScript : " + llGetScriptName();

        szOutput += "\n" + szMsg + "\n=============";

        if ( nChannel == -1 )
            llOwnerSay(szOutput);
        else
            llWhisper(nChannel, szOutput);
    }
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
//= parameters   : key keyID - the key to check for permission
//=
//= retun        : TRUE if permission is granted
//=
//= description  : checks if the key is allowed to send command to this modul
//=
//===============================================================================
integer IsAllowed( key keyID )
{
    integer nAllow    = FALSE;

    if ( llGetOwnerKey(keyID) == g_keyWearer )
        nAllow = TRUE;

    return nAllow;
}
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
    llRegionSay(g_nCmdChannel, llList2String(g_lstModTokens,0) + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
    //llWhisper(0, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}
//===============================================================================
//= parameters   : none
//=
//= retun        : none
//=
//= description  : get owner/wearer key and opens the listeners (std channel + 1)
//=
//===============================================================================
Init()
{
    g_keyWearer = llGetOwner();

    // get unique channel numbers for the command and cuff channel, cuff channel wil be used for LG chains of cuffs as well
    g_nCmdChannel = nGetOwnerChannel(g_nCmdChannelOffset);

    llListenRemove(g_nCmdHandle);

    g_nCmdHandle = llListen(g_nCmdChannel + 1, "", NULL_KEY, "");

    g_lstModTokens = (list)llList2String(lstCuffNames,llGetAttached()); // get name of the cuff from the attachment point, this is absolutly needed for the system to work, other chain point wil be received via LMs

    //akDebug(llGetScriptName ()+" ready - Memory : " + (string)llGetFreeMemory(), "", FALSE, -1);
    //llOwnerSay(llGetScriptName ()+" ready - Memory : " + (string)llGetFreeMemory());
}

//===============================================================================
//= parameters   :    key        keyID    key of the calling AV or object
//=                   string    szMsg   message string received
//=
//= retun        :    string    command without prefixes if it has to be handled here
//=
//= description  :    checks if the message includes a valid ext. prefix
//=                    and if it's for this module
//=
//===============================================================================
string CheckCmd( key keyID, string szMsg )
{
    list    lstParsed    = llParseString2List( szMsg, [ "|" ], [] );
    string    szCmd        = szMsg;

    // first part should be sender token
    // second part the receiver token
    // third part = command
    if ( llGetListLength(lstParsed) > 2 )
    {
        // check the sender of the command occ,rwc,...
        g_szSender            = llList2String(lstParsed,0);
        g_nCmdType        = CMD_UNKNOWN;

        if ( g_szSender==g_szAllowedCommadToken ) // only accept command from the master cuff
        {
            g_nCmdType    = CMD_EXTERNAL;

            // cap and store the receiver
            g_szReceiver = llList2String(lstParsed,1);

            // we are the receiver
            if ( (llListFindList(g_lstModTokens,[g_szReceiver]) != -1) || g_szReceiver == "*" )
            {
                // set cmd return to the rest of the command string
                szCmd = llList2String(lstParsed,2);
                g_nCmdType = CMD_MODULE;
            }
        }
    }

    lstParsed = [];
    return szCmd;
}

//===============================================================================
//= parameters   :    key        keyID    key of the calling AV or object
//=                   string    szMsg   message string received
//=
//= retun        :
//=
//= description  :    devides the command string into single commands
//=                    delimiter = ~
//=                    single commands are redirected to ParseSingleCmd
//=
//===============================================================================
ParseCmdString( key keyID, string szMsg )
{
    list    lstParsed = llParseString2List( szMsg, [ "~" ], [] );

    integer nCnt = llGetListLength(lstParsed);
    integer i = 0;

    for (i = 0; i < nCnt; i++ )
    {
        ParseSingleCmd(keyID, llList2String(lstParsed, i));
    }

    lstParsed = [];
}

//===============================================================================
//= parameters   :    key        keyID    key of the calling AV or object
//=                   string    szMsg   single command string
//=
//= retun        :
//=
//= description  :    devides the command string into command & parameter
//=                    delimiter is =
//=
//===============================================================================
ParseSingleCmd( key keyID, string szMsg )
{
    list    lstParsed    = llParseString2List( szMsg, [ "=" ], [] );

    string    szCmd    = llList2String(lstParsed,0);
    string    szValue    = llList2String(lstParsed,1);

    if ( szCmd == "chain" )
    {
        if ( llGetListLength(lstParsed) == 4 )
        {
            if ( llGetKey() != keyID )
                llMessageLinked( LINK_SET, LM_CUFF_CMD, szMsg, llGetKey() );
        }
        //llWhisper(0, "OC Cuff slave : " + szMsg  );
    }
    else
    {
        llMessageLinked(LINK_SET, LM_CUFF_CMD, szMsg, keyID);
    }

    lstParsed = [];
}

default
{
    state_entry()
    {
        Init();
        // listen to LockGuard requests
        llListen(g_nLockGuardChannel,"","","");
    }

    link_message(integer nSenderNum, integer nNum, string szMsg, key keyID)
    {
        if( nNum == LM_CUFF_CMD )
        {
            if ( szMsg == "reset" )
            {
                llResetScript();
            }
        }
        else if( nNum == LM_CUFF_CUFFPOINTNAME )
        {
            if (llListFindList(g_lstModTokens,[szMsg])==-1)
            {
                g_lstModTokens+=[szMsg];
            }
            akDebug(llList2CSV(g_lstModTokens),"",0,0);
        }
    }

    touch_start(integer nCnt)
    {
        // call menu from maincuff
        // Cleo: Added another parameter of clicker to the message
        SendCmd("rlac", "cmenu=on="+(string)llDetectedKey(0), llDetectedKey(0));
    }

    listen(integer nChannel, string szName, key keyID, string szMsg)
    {
        szMsg = llStringTrim(szMsg, STRING_TRIM);

        // commands sent on cmd channel
        if ( nChannel == g_nCmdChannel+ 1 )
        {
            if ( IsAllowed(keyID) )
            {
                if (llGetSubString(szMsg,0,8)=="lockguard")
                {
                    llMessageLinked(LINK_SET, -9119, szMsg, keyID);
                }
                else
                {
                    // check if external or maybe for this module
                    string szCmd = CheckCmd( keyID, szMsg );

                    if ( g_nCmdType == CMD_MODULE )
                    {
                        ParseCmdString(keyID, szCmd);
                    }
                }
            }
        } 
        else if ( nChannel == g_nLockGuardChannel)
        // LG message received, forward it to the other prims
        {
            llMessageLinked(LINK_SET,g_nLockGuardChannel,szMsg,NULL_KEY);
        }

        
    }

    on_rez(integer nParam)
    {
        llMessageLinked(LINK_SET, LM_CUFF_CMD, "reset", NULL_KEY);
        llResetScript();
    }
}
