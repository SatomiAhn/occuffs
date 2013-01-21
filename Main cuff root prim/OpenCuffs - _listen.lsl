//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//listener

//=============================================================================
//== OC Cuff - listen module
//== receives messages from exernal objects and the chat
//== checks if external commands are for this module
//== sends the valid messages for this module to the OC Cuff module
//==
//== 2009-01-16 Jenny Sigall - 1. draft
//==
//==
//=============================================================================
integer g_nStdChannel    = 1;            // standard chat channel
integer    g_nStdHandle;                    // standard listen handler

integer g_nCmdChannel    = -190890;        // command channel
integer g_nCuffChannel    = -190889;        // cuff channel // used for LG chains from the cuffs

integer    g_nCmdHandle    = 0;            // command listen handler
integer    g_nCuffHandle    = 0;            // cuff command listen handler


integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for

key        g_keyWearer        = NULL_KEY;        // key of the owner/wearer

integer    LM_CUFF_CMD        = -551001;
integer    LM_CUFF_ANIM    = -551002;

integer    g_nDebug        = FALSE;
integer    g_nShowScript    = FALSE;

//===================
//cuff prefixes
//prefixes for communication
//===================
list    g_lstExtPrefix    = [
    "occ",  //occ     opencollar collar command module, please amke sure to change that for you items, the list of names following ids should only be used for cuffs!
    "ruac", //ruac    right upper arm cuff
    "rlac", //rlac    right lower arm cuff
    "luac", //luac    left upper arm cuff
    "llac", //rlac    left lower arm cuff
    "rulc",    //rulc    right upper leg cuff
    "rllc",    //rllc    right lower leg cuff
    "lulc",    //lulc    left upper leg cuff
    "lllc", //lllc    left lower leg cuff
    "ocbelt"    //opencuffs belt
        ];

list    g_lstModTokens    = ["rlac"]; // valid token for this module

integer    CMD_UNKNOWN        = -1;        // unknown command - don't handle
integer    CMD_CHAT        = 0;        // chat cmd - check what should happen with it
integer    CMD_EXTERNAL    = 1;        // external cmd - check what should happen with it
integer    CMD_MODULE        = 2;        // cmd for this module

integer    g_nCmdType        = CMD_UNKNOWN;

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer COMMAND_COLLAR = 499;
//integer CHAT = 505; //deprecated.  Too laggy to make every single script parse a link message any time anyone says anything
integer COMMAND_OBJECT = 506;
integer COMMAND_RLV_RELAY = 507;
integer COMMAND_SAFEWORD = 510;  // new for safeword
//
// external command syntax
// sender prefix|receiver prefix|command1=value1~command2=value2|UUID to send under
// occ|rwc|chain=on~lock=on|aaa-bbb-2222...
//
string    g_szReceiver    = "";
string    g_szSender        = "";

integer g_nLockGuardChannel = -9119;

string g_sPrefix = "*" ;

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

// comamnd string cmd~value(s)
//string    g_nCommand        = "";        // command part
//string    g_szValues        = "";        // value part

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
//= parameters   : none
//=
//= retun        : none
//=
//= description  : get owner/wearer key and opens the listeners
//=
//===============================================================================
Init()
{
    g_keyWearer = llGetOwner();

    // get unique channel numbers for the command and cuff channel, cuff channel wil be used for LG chains of cuffs as well
    g_nCmdChannel = nGetOwnerChannel(g_nCmdChannelOffset);
    g_nCuffChannel = g_nCmdChannel+1;
    
    g_sPrefix = AutoPrefix() + "c " ;

    llListenRemove(g_nStdHandle);
    llListenRemove(g_nCmdHandle);
    llListenRemove(g_nCuffHandle);


    g_nStdHandle = llListen(g_nStdChannel, "", NULL_KEY, "");
    g_nCmdHandle = llListen(g_nCmdChannel, "", NULL_KEY, "");
    g_nCuffHandle = llListen(g_nCuffChannel, "", NULL_KEY, "");


    akDebug(llGetScriptName ()+" ready - Memory : " + (string)llGetFreeMemory(), "", FALSE, -1);
    //llOwnerSay(llGetScriptName ()+" ready - Memory : " + (string)llGetFreeMemory());

}

// Return the string to be used for a prefix on the cuffs:
string AutoPrefix()
{
    list sName = llParseString2List(llKey2Name(g_keyWearer), [" "], []);
    return llToLower(llGetSubString(llList2String(sName, 0), 0, 0)) + llToLower(llGetSubString(llList2String(sName, 1), 0, 0));
}

// Return true or false - true if 'needle' is found in 'haystack'
integer StartsWith(string sHayStack, string sNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(sHayStack, llStringLength(sNeedle), -1) == sNeedle;
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
        g_szSender    = llList2String(lstParsed,0);
        integer nIdx         = llListFindList(g_lstExtPrefix, [g_szSender]);

        g_nCmdType        = CMD_UNKNOWN;

        if ( nIdx != -1 ) // a known external sender
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

default
{
    state_entry()
    {
        Init();
        llListen(g_nLockGuardChannel,"","","");
    }

    //on_rez(integer start_param)
    //{
    //    llResetScript();
    //}

    link_message(integer nSenderNum, integer nNum, string szMsg, key keyID)
    {
        if( nNum == LM_CUFF_CMD )
        {
            if ( szMsg == "reset" )
            {
                llResetScript();
            }
            //            else
            //            {
            //                // set the receiver/module token of this module
            //                if ( llGetSubString(szMsg,0,8)  == "settoken=" )
            //                {
            //                    g_szModToken = llGetSubString(szMsg,9,-1);
            //                }
            //            }
        }
    }

    listen(integer nChannel, string szName, key keyID, string szMsg)
    {
        szMsg = llStringTrim(szMsg, STRING_TRIM);

        // commands sent on cmd channel
        if ( nChannel == g_nCmdChannel )
        {
            if ( IsAllowed(keyID) )
            {
                // check if external or maybe for this module
                string szCmd = CheckCmd( keyID, szMsg );

                if ( g_nCmdType == CMD_MODULE )
                {
                    llMessageLinked(LINK_THIS, LM_CUFF_CMD, szCmd, llGetOwnerKey(keyID));
                }
            }
        }
        // commands sent on cuff channel, in thes case only lockguard
        if ( nChannel == g_nCuffChannel )
        {
            if (IsAllowed(keyID))
            {
                if (llGetSubString(szMsg,0,8)=="lockguard")
                {
                    llMessageLinked(LINK_SET, -9119, szMsg, keyID);
                }
            }
        }
        else if ( nChannel == g_nStdChannel )
        {
            // test for chat message for owner, secowner, or blacklist, only from
            // the wearer of the cuffs (at least for now).
            key keySource = llGetOwnerKey( keyID ) ;
            if ( keySource == g_keyWearer && StartsWith(llToLower(szMsg), g_sPrefix )  )
            {
                szMsg = llGetSubString( szMsg, llStringLength(g_sPrefix), -1 ) ;
                integer IsCmd = FALSE ;
                if ( StartsWith(llToLower(szMsg), "owner " ) ) IsCmd = TRUE ;
                if ( StartsWith(llToLower(szMsg), "secowner " ) ) IsCmd = TRUE ;
                if ( StartsWith(llToLower(szMsg), "blacklist " ) ) IsCmd = TRUE ;
                if ( IsCmd )
                {
                    llMessageLinked( LINK_THIS, COMMAND_NOAUTH, szMsg, keySource ) ;
                }  
                
            }
            
            //llMessageLinked(LINK_THIS, LM_CUFF_CMD, szMsg, llGetOwnerKey(keyID));
            //if ( g_nCmdType == CMD_CHAT )
            //{
            //    llMessageLinked(LINK_THIS, LM_CUFF_CMD, szMsg, llGetOwnerKey(keyID));
            //}
        }
        else if ( nChannel == g_nLockGuardChannel )
        {
            llMessageLinked(LINK_SET,g_nLockGuardChannel,szMsg,NULL_KEY);
        }
    }
    
    on_rez(integer rez_state) 
    {
        llResetScript();

    }

}
