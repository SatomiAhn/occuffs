//=============================================================================
//== OpenCuff - _anim - animation modul
//== receives the anim command and starts the called animation
//==
//== 2009-02-03 Jenny Sigall - 1. draft
//== 2009-04-04 Jenny Sigall - added leg animation support
//==
//=============================================================================

string    g_szActAAnim        = ""; // arm anim
string    g_szActLAnim        = ""; // leg anim

key        g_keyWearer        = NULL_KEY;

integer    g_nOverride        = 0;
float    g_nOverrideTime    = 0.25;
integer    g_nInOverride = FALSE;

integer    LM_CUFF_CMD        = -551001;        // used as channel for linkemessages - sending commands
integer    LM_CUFF_ANIM    = -551002;        // used as channel for linkedmessages - sending animation cmds

integer    g_nLock            = FALSE;
string    g_szModToken    = "";         // valid token for this module


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
//= parameters   : string szAnimInfo    part info & animation
//=                key keyID        key of the calling AV
//=
//= description  : Stops old animation if available
//=                and starts new on - if parameter not "Stop"
//=
//===============================================================================
DoAnim( string szAnimInfo, key keyID )
{
    string szInfo = llGetSubString(szAnimInfo, 0,1);
    string szAnim = llGetSubString(szAnimInfo, 2,-1);

    // works only if the animation is found in inventory
    if (llGetInventoryType(szAnim) == INVENTORY_ANIMATION || llToLower(szAnim) == "stop")
    {
        if (llGetPermissionsKey() != NULL_KEY)
        {
            if ( szInfo == "a:" ) // arm anim
            {
                _DoAnim(g_szActAAnim, szAnim, keyID);
                g_szActAAnim = "";
                if ( llToLower(szAnim) != "stop" )
                {
                    g_szActAAnim = szAnim;
                }
            }
            else if ( szInfo == "l:" ) // leg anim
            {
                _DoAnim(g_szActLAnim, szAnim, keyID);
                g_szActLAnim = "";
                if ( llToLower(szAnim) != "stop" )
                {
                    g_szActLAnim = szAnim;
                }
            }
            else if ( szInfo == "*:" ) // arm anim
            {
                if ( llToLower(szAnim) == "stop" )
                {
                    _DoAnim(g_szActAAnim, szAnim, keyID);
                    _DoAnim(g_szActLAnim, szAnim, keyID);
                    g_szActAAnim = "";
                    g_szActLAnim = "";
                }
            }

        }
    }
}
//===============================================================================
//= parameters   : string szActAnim actual leg/arm anim
//=                string szAnim    new animation
//=                key keyID        key of the calling AV
//=
//= description  : Stops old animation if available
//=                and starts new on - if parameter not "Stop"
//=
//===============================================================================
_DoAnim(string szActAnim, string szAnim, key keyID )
{
            if ( szActAnim != "" )
            {
                llSetTimerEvent(0);
                g_nOverride = FALSE;
                llStopAnimation(szActAnim);

            }

            if ( llToLower(szAnim) != "stop" )
            {
                llStartAnimation(szAnim);

                //CheckAnims(g_keyWearer);

                g_nOverride = TRUE;
                llSetTimerEvent(g_nOverrideTime);

                //llSay(0, llKey2Name(keyID) + " forced " + llKey2Name(llGetOwner()) + " in pose <" + szAnim + ">.");
            }
}
//===============================================================================
//= description  : overrides the animations - called from timer and control
//===============================================================================
Override()
{
    if ( ! g_nInOverride )
    {
        g_nInOverride = TRUE;

        if ( g_nOverride && g_szActAAnim != "" )
        {
            llStopAnimation(g_szActAAnim);
            llStartAnimation(g_szActAAnim);
        }

        if ( g_nOverride && g_szActLAnim != "" )
        {
            llStopAnimation(g_szActLAnim);
            llStartAnimation(g_szActLAnim);
        }

        g_nInOverride = FALSE;
    }
}
//===============================================================================
//= description  : permission request for animation & take controls
//===============================================================================
GetPermissions()
{
    if ( llGetAttached() )
        llRequestPermissions(llGetOwner(),PERMISSION_TRIGGER_ANIMATION|PERMISSION_TAKE_CONTROLS);
}

Init()
{
    g_keyWearer = llGetOwner();
    GetPermissions();

    akDebug(llGetScriptName ()+" ready - Memory : " + (string)llGetFreeMemory(), "", FALSE, -1);
    //llOwnerSay(llGetScriptName ()+" ready - Memory : " + (string)llGetFreeMemory());
}

default
{
    state_entry()
    {
        Init();
    }

    attach(key attached)
    {
        if (attached != NULL_KEY)   // object has been //attached//
        {
            Init();
        }
    }

    control( key keyID, integer nHeld, integer nChange )
    {
        // Is the user holding down left or right?
        if ( nHeld & (CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT|CONTROL_FWD|CONTROL_BACK) )
            Override();
    }

    link_message(integer nSenderNum, integer nNum, string szMsg, key keyID)
    {
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
        }
        else if( nNum == LM_CUFF_ANIM )
        {
            DoAnim(szMsg, keyID);
        }
    }

    run_time_permissions(integer nParam)
    {
        if( nParam == (PERMISSION_TRIGGER_ANIMATION|PERMISSION_TAKE_CONTROLS) )
        {
            llTakeControls( CONTROL_DOWN|CONTROL_UP|CONTROL_FWD|CONTROL_BACK|CONTROL_LEFT|CONTROL_RIGHT|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT, TRUE, TRUE);
        }
    }

    timer()
    {
        if (g_szActAAnim != "" )
        {
            llStopAnimation(g_szActAAnim);
            llStartAnimation(g_szActAAnim);
        }

        if (g_szActLAnim != "" )
        {
            llStopAnimation(g_szActLAnim);
            llStartAnimation(g_szActLAnim);
        }
    }
}