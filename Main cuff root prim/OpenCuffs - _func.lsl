//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//listener

//=============================================================================
//== OC Cuff - function module
//== messages received from the main (menu) or listener (chat & external) module
//== are interpreted here and the corresponding actions are startet
//==
//== 2009-01-16 Jenny Sigall - 1. draft
//==
//==
//=============================================================================
integer    LM_CUFF_CMD        = -551001;
integer    LM_CUFF_ANIM    = -551002;

key        g_keyWearer        = NULL_KEY;

integer g_nCmdChannel    = -190890;

integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for


string    g_szModToken    = ""; // valid token for this module

integer    g_nDebug        = FALSE;
integer    g_nShowScript    = FALSE;
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

    //if ( szCmd == "anim" )
    //{
    //    if ( szValue == "link" )
    //        SendCmd("lwc", "chain=llac=rlac=link", llGetKey());
    //    else
    //        SendCmd("lwc", "chain=llac=rlac=unlink", llGetKey()    );
    //
    //}
    if ( szCmd == "chain" )
    {
        if ( llGetListLength(lstParsed) == 4 )
        {
            if ( llGetKey() != keyID )
                llMessageLinked( LINK_SET, LM_CUFF_CMD, szMsg, llGetKey() );
        }
    }
    else if (szCmd == "cmenu" )
    {
        llMessageLinked( LINK_SET, LM_CUFF_CMD, "menu", (key)llList2String(lstParsed,2) );
    }

    lstParsed = [];
}


//===============================================================================
//= parameters   : none
//=
//= retun        : none
//=
//= description  : get owner/wearer key
//=
//===============================================================================
Init()
{
    g_keyWearer = llGetOwner();

    g_nCmdChannel = nGetOwnerChannel(g_nCmdChannelOffset); // get the owner defined channel

    akDebug(llGetScriptName ()+" ready - Memory : " + (string)llGetFreeMemory(), "", FALSE, -1);
    //llOwnerSay(llGetScriptName ()+" ready - Memory : " + (string)llGetFreeMemory());
}

default
{
    state_entry()
    {
        Init();
    }

    //on_rez(integer start_param)
    //{
    //    llResetScript();
    //}

    link_message(integer nSenderNum, integer nNum, string szMsg, key keyID)
    {
        string szCmd = llToLower(llStringTrim(szMsg, STRING_TRIM));

        if ( nNum == LM_CUFF_CMD )
        {
            if ( szMsg == "reset")
            {
                llResetScript();
            }
            // set the receiver/module token of this module
            else if ( llGetSubString(szMsg,0,8)  == "settoken=" )
            {
                g_szModToken = llGetSubString(szMsg,9,-1);
            }
            else
            {
                ParseCmdString(keyID, szCmd);
            }
        }
        else if ( nNum == LM_CUFF_ANIM)
        {
        }
    }

    timer()
    {
    }

    attach(key attached)
    {
        if (attached != NULL_KEY)
        {
            Init();
        }
    }
}