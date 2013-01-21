//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505;//deprecated
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
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

integer LOCALSETTING_SAVE = 2500;
integer LOCALSETTING_REQUEST = 2501;
integer LOCALSETTING_RESPONSE = 2502;
integer LOCALSETTING_DELETE = 2503;
integer LOCALSETTING_EMPTY = 2504;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.

//=============================================================================
//== OpenCuff - AOSwitch - Checking animation/AO state
//== En/Disables the AO
//==
//==
//== 2009-04-06 Cleo Collins - 1. draft
//==
//=============================================================================
integer    LM_CUFF_CMD        = -551001;        // used as channel for linkemessages - sending commands
integer    LM_CUFF_ANIM    = -551002;        // used as channel for linkedmessages - sending animation cmds

integer    g_nDebug        = FALSE;
integer    g_nShowScript    = FALSE;

// Cleo: For Communication with AOs
integer     g_nArmAnimRunning = FALSE;  // to make sure AOs get only switched off or on when needed
integer     g_nLegAnimRunning = FALSE;  // to make sure AOs get only switched off or on when needed
integer     g_nAOState = TRUE; // AO is on by default;
string      g_szStopCommand = "Stop"; // command to stop an animation

// variable for SUB AO communication
integer     g_nAOChannel = -782690;
string      g_szAO_ON = "ZHAO_UNPAUSE";
string      g_szAO_OFF = "ZHAO_PAUSE";

// variable for staying in place
integer     g_nStay = FALSE;
integer     g_nStayMode = TRUE;
integer     g_nSlowMode = TRUE;

// variable for staying in place
integer     g_nRLVArms = FALSE;
integer     g_nRLVLegs = FALSE;
integer     g_nRLVMode = TRUE;



key         g_keyWearer;
string      g_szWearerName;

// slowing down wearer

vector g_vBase_impulse = <0.7,0,0>;
integer g_nDuration = 5;
integer g_nStart_time;


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
//= parameters   :    none
//=
//= retun        :    none
//=
//= description  :    Cleo: Sends commands to OC Sub Ao and LM comaptible AOs to disable them
//=
//===============================================================================
DisableAOs()
{
    //llOwnerSay("Off");
    // send LM command for disabling AOs
    llSay(-8888,((string)llGetOwner())+"bootoff");

    //switch off OpenCollar Sub AO
    llSay(g_nAOChannel, g_szAO_OFF);
}
//===============================================================================
//= parameters   :    none
//=
//= retun        :    none
//=
//= description  :    Cleo: Sends commands to LM comaptible AOs to enable them again
//=
//===============================================================================
EnableAOs()
{
    //llOwnerSay("On");

    // send LM command for enabling AOs
    llSay(-8888,((string)llGetOwner())+"booton");

    //switch on OpenCollar Sub AO
    llSay(g_nAOChannel, g_szAO_ON);
}

StayPut()
{
    if (g_nStay) return;
    g_nStay = TRUE;
    llRequestPermissions(g_keyWearer, PERMISSION_TAKE_CONTROLS);
    llOwnerSay("You are bound, so your movement is restricted.");
}

UnStay()
{
    if (!g_nStay) return;
    g_nStay = FALSE;
    llReleaseControls();
    llOwnerSay("You are free to move again.");
}

RLVRestrictions(integer ShowMessages)
{
    if (g_nRLVMode)
    {
        if(g_nArmAnimRunning)
        {
            if (!g_nRLVArms)
            {
                if (ShowMessages) llOwnerSay("Your arms are bound, so you can do only limited things.");

                // edit, rez, showinv, fartouch
                g_nRLVArms=TRUE;
                llMessageLinked(LINK_THIS, RLV_CMD, "edit=n", NULL_KEY);
                llMessageLinked(LINK_THIS, RLV_CMD, "rez=n", NULL_KEY);
                llMessageLinked(LINK_THIS, RLV_CMD, "showinv=n", NULL_KEY);
                llMessageLinked(LINK_THIS, RLV_CMD, "fartouch=n", NULL_KEY);
            }

        }
        else
        {
            if (g_nRLVArms)
            {
                if (ShowMessages) llOwnerSay("Your arms are free to touch things again.");

                // edit, rez, showinv, fartouch
                g_nRLVArms=FALSE;
                llMessageLinked(LINK_THIS, RLV_CMD, "edit=y", NULL_KEY);
                llMessageLinked(LINK_THIS, RLV_CMD, "rez=y", NULL_KEY);
                llMessageLinked(LINK_THIS, RLV_CMD, "showinv=y", NULL_KEY);
                llMessageLinked(LINK_THIS, RLV_CMD, "fartouch=y", NULL_KEY);

            }
        }
        if(g_nLegAnimRunning)
        {
            if (!g_nRLVLegs)
            {
                if (ShowMessages) llOwnerSay("Your legs are bound, so you can only limited move.");

                // sittp, tplm, tploc, tplure
                g_nRLVLegs=TRUE;
                llMessageLinked(LINK_THIS, RLV_CMD, "sittp=n", NULL_KEY);
                llMessageLinked(LINK_THIS, RLV_CMD, "tplm=n", NULL_KEY);
                llMessageLinked(LINK_THIS, RLV_CMD, "tploc=n", NULL_KEY);
                llMessageLinked(LINK_THIS, RLV_CMD, "tplure=n", NULL_KEY);
            }

        }
        else
        {
            if (g_nRLVLegs)
            {
                if (ShowMessages) llOwnerSay("Your legs are free to you can move normal again.");

                // sittp, tplm, tploc, tplure
                g_nRLVLegs=FALSE;
                llMessageLinked(LINK_THIS, RLV_CMD, "sittp=y", NULL_KEY);
                llMessageLinked(LINK_THIS, RLV_CMD, "tplm=y", NULL_KEY);
                llMessageLinked(LINK_THIS, RLV_CMD, "tploc=y", NULL_KEY);
                llMessageLinked(LINK_THIS, RLV_CMD, "tplure=y", NULL_KEY);

            }
        }
    }
    else
    {
        if (g_nRLVArms)
        {
            if (ShowMessages) llOwnerSay("Your are free to touch things again.");
            llMessageLinked(LINK_THIS, RLV_CMD, "edit=y", NULL_KEY);
            llMessageLinked(LINK_THIS, RLV_CMD, "rez=y", NULL_KEY);
            llMessageLinked(LINK_THIS, RLV_CMD, "showinv=y", NULL_KEY);
            llMessageLinked(LINK_THIS, RLV_CMD, "fartouch=y", NULL_KEY);
            g_nRLVArms=FALSE;
        }


        if (g_nRLVLegs)
        {
            llMessageLinked(LINK_THIS, RLV_CMD, "sittp=y", NULL_KEY);
            llMessageLinked(LINK_THIS, RLV_CMD, "tplm=y", NULL_KEY);
            llMessageLinked(LINK_THIS, RLV_CMD, "tploc=y", NULL_KEY);
            llMessageLinked(LINK_THIS, RLV_CMD, "tplure=y", NULL_KEY);

            g_nRLVLegs=FALSE;
            if (ShowMessages) llOwnerSay("Your legs are free to you can move normal again.");
        }

    }
}


default
{
    state_entry()
    {
        g_keyWearer=llGetOwner();
        g_szWearerName=llKey2Name(g_keyWearer);
    }

    link_message(integer nSenderNum, integer nNum, string szMsg, key keyID)
    {
        if ( nNum == LM_CUFF_CMD )
        {
            if ( szMsg == "reset" )
            {
                llResetScript();
            }
            else if (szMsg == "staymode=on")
            {
                g_nStayMode = TRUE;
                g_nSlowMode = FALSE;
                if (g_nLegAnimRunning)
                {
                    StayPut();
                }
            }
            else if (szMsg == "staymode=slow")
            {
                g_nStayMode = TRUE;
                g_nSlowMode = TRUE;
                if (g_nLegAnimRunning)
                {
                    StayPut();
                }
            }
            else if (szMsg == "staymode=off")
            {
                g_nStayMode = FALSE;
                if (g_nStay)
                {
                    UnStay();
                }
            }
            else if (szMsg == "rlvmode=on")
            {
                g_nRLVMode = TRUE;
                RLVRestrictions(TRUE);
            }
            else if (szMsg == "rlvmode=off")
            {
                g_nRLVMode = FALSE;
                RLVRestrictions(TRUE);
            }
        }
        // check for Cuff Anim commands to interact with AOs
        else if (nNum == LM_CUFF_ANIM)
        {
            // pasre the message
            list lCommands=llParseString2List(szMsg,[":"],[]);
            string szTarget=llList2String(lCommands,0); // Arms or Legs?
            string szAnim=llList2String(lCommands,1); // Stop or another anim

            if (szTarget=="a") // Command for the Arms
            {
                if (szAnim==g_szStopCommand)
                    // Stop received
                {
                    g_nArmAnimRunning=FALSE;
                }
                else
                    // Normal anim received
                {
                    g_nArmAnimRunning=TRUE;
                }
            }

            if (szTarget=="l") // Command for the Legs
            {
                if (szAnim==g_szStopCommand)
                    // Stop received
                {
                    g_nLegAnimRunning=FALSE;
                }
                else
                    // Normal anim received
                {
                    g_nLegAnimRunning=TRUE;
                }
            }

            // now check if AOState has to be changed
            if (g_nAOState)
                // AO running atm
            {
                // disable AO if an arm OR a leg anim runs
                if ((g_nArmAnimRunning==TRUE)||(g_nLegAnimRunning==TRUE))
                {
                    DisableAOs();
                    g_nAOState=FALSE;
                }
            }
            else
                // AO is in sleep
            {
                // enable AO if no arm AND no leg anim runs
                if ((g_nArmAnimRunning==FALSE)&&(g_nLegAnimRunning==FALSE))
                {
                    EnableAOs();
                    g_nAOState=TRUE;
                }
            }
            if (g_nStayMode&&(g_nLegAnimRunning==TRUE))
            {
                StayPut();
            }
            else
            {
                UnStay();
            }
            RLVRestrictions(TRUE);
        }
        else if (nNum == RLV_REFRESH)
        {
            g_nRLVArms=FALSE;
            g_nRLVLegs=FALSE;
            RLVRestrictions(FALSE);
        }
    }

    on_rez(integer start_param)
    {
        llResetScript();
    }

    control(key id, integer level, integer edge)
    {
        if (g_nStay && g_nSlowMode)
        {
            if (edge & (CONTROL_FWD | CONTROL_BACK)) g_nStart_time = llGetUnixTime();
            float wear_off = (g_nDuration + g_nStart_time - llGetUnixTime() + 0.0)/g_nDuration;
            if (wear_off < 0) wear_off = 0;
            vector impulse = wear_off * g_vBase_impulse;
            if (level & CONTROL_FWD)
            {
                llApplyImpulse(impulse , TRUE);
            }
            else if (level & CONTROL_BACK)
            {
                llApplyImpulse(-impulse , TRUE);
            }
        }
    }

    run_time_permissions(integer perm)
    {
        if (PERMISSION_TAKE_CONTROLS & perm)
        {//disbale all controls but left mouse button (for stay cmd)
            if (g_nSlowMode)
            //slowdown only
            {
                llTakeControls(CONTROL_FWD|CONTROL_BACK, TRUE, FALSE);
            }
            else
            // full stay
            {
                llTakeControls( CONTROL_ROT_LEFT | CONTROL_ROT_RIGHT | CONTROL_LBUTTON | CONTROL_ML_LBUTTON, FALSE, FALSE);
            }
        }
    }

}