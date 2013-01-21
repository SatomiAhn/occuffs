//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//color

//on getting color command, give menu to choose which element, followed by menu to pick color

// Changes for OpenCuffs
// Globla variable for channel and commnad added
// function to send command to slave funtion added
// Sending of messages to slave cuff in Listener added


list elements;
string currentelement = "";
string currentcategory = "";
list categories = ["Blues", "Browns", "Grays", "Greens", "Purples", "Reds", "Yellows"];
list colorsettings;
string parentmenu = "Appearance";
string submenu = "Colors";

string dbtoken = "colorsettings";

key user;
key httpid;

list colors;
integer stridelength = 2;
integer page = 0;
integer menu_page;
integer pagesize = 10;
integer length;
list buttons;
list new_buttons;

list g_lstMenuIDs;

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer CHAT = 505;

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
//str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent when a token has no value in the httpdb

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;



//5000 block is reserved for IM slaves

//string UPMENU = "?";
//string MORE = "?";
string UPMENU = "^";
//string MORE = ">";

key wearer;

integer g_nCmdChannel    = -190890;
integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for

string    g_szModToken    = "rlac"; // valid token for this module
string g_szColorChangeCmd="ColorChanged"; // Comand for Cuffs to change the colors


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

// End of Changes for OpenCuffs functions



key ShortKey()
{//just pick 8 random hex digits and pad the rest with 0.  Good enough for dialog uniqueness.
    string chars = "0123456789abcdef";
    integer length = 16;
    string out;
    integer n;
    for (n = 0; n < 8; n++)
    {
        integer index = (integer)llFrand(16);//yes this is correct; an integer cast rounds towards 0.  See the llFrand wiki entry.
        out += llGetSubString(chars, index, index);
    }

    return (key)(out + "-0000-0000-0000-000000000000");
}

key Dialog(key rcpt, string prompt, list choices, list utilitybuttons, integer page)
{
    key id = ShortKey();
    llMessageLinked(LINK_SET, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page + "|" + llDumpList2String(choices, "`") + "|" + llDumpList2String(utilitybuttons, "`"), id);
    return id;
}


Notify(key id, string msg, integer alsoNotifyWearer)
{
    if (id == wearer) {
        llOwnerSay(msg);
    } else {
            llInstantMessage(id,msg);
        if (alsoNotifyWearer) {
            llOwnerSay(msg);
        }
    }
}

CategoryMenu(key av)
{
    //give av a dialog with a list of color cards
    string prompt = "Pick a Color.";
    g_lstMenuIDs+=[Dialog(av, prompt, categories, [UPMENU],0)];
}

ColorMenu(key av)
{
    string prompt = "Pick a Color.";
    list buttons = llList2ListStrided(colors,0,-1,2);
    g_lstMenuIDs+=[Dialog(av, prompt, buttons, [UPMENU],0)];
}

ElementMenu(key av)
{
    string prompt = "Pick which part of the collar you would like to recolor";
    buttons = llListSort(elements, 1, TRUE);
    g_lstMenuIDs+=[Dialog(av, prompt, buttons, [UPMENU],0)];
}

string ElementType(integer linknumber)
{
    string desc = (string)llGetObjectDetails(llGetLinkKey(linknumber), [OBJECT_DESC]);
    //each prim should have <elementname> in its description, plus "nocolor" or "notexture", if you want the prim to
    //not appear in the color or texture menus
    list params = llParseString2List(desc, ["~"], []);
    if ((~(integer)llListFindList(params, ["nocolor"])) || desc == "" || desc == " " || desc == "(No Description)")
    {
        return "nocolor";
    }
    else
    {
        return llList2String(params, 0);
    }
}


LoadColorSettings()
{
    //llOwnerSay(llDumpList2String(colorsettings, ","));
    //loop through links, setting each's color according to entry in colorsettings list
    integer n;
    integer linkcount = llGetNumberOfPrims();
    for (n = 2; n <= linkcount; n++)
    {
        string element = ElementType(n);
        integer index = llListFindList(colorsettings, [element]);
        vector color = (vector)llList2String(colorsettings, index + 1);
        //llOwnerSay(llList2String(colorsettings, index + 1));
        if (index != -1)
        {
            //set link to new color
            llSetLinkColor(n, color, ALL_SIDES);
            //llSay(0, "setting link " + (string)n + " to color " + (string)color);
        }
    }
}

BuildElementList()
{
    integer n;
    integer linkcount = llGetNumberOfPrims();

    //root prim is 1, so start at 2
    for (n = 2; n <= linkcount; n++)
    {
        string element = ElementType(n);
        if (!(~llListFindList(elements, [element])) && element != "nocolor")
        {
            elements += [element];
            //llSay(0, "added " + element + " to elements");
        }
    }
}

SetElementColor(string element, vector color)
{
    integer nElementFound=FALSE; // making sure we store only needed color values
    integer nSaveSettings=FALSE; // making sure we store only when really needed
    integer n;
    integer linkcount = llGetNumberOfPrims();
    for (n = 2; n <= linkcount; n++)
    {
        string thiselement = ElementType(n);
        if (thiselement == element)
        {
            //set link to new color
            //llSetLinkPrimitiveParams(n, [PRIM_COLOR, ALL_SIDES, color, 1.0]);
            nElementFound=TRUE; // the element is there, so we need to save the value later
            llSetLinkColor(n, color, ALL_SIDES);
        }
    }
    // the following part is not needed if the element is not part off the cuffs
    if (!nElementFound)
        return;

    //create shorter string from the color vectors before saving
    string strColor = Vec2String(color);
    //change the colorsettings list entry for the current element
    integer index = llListFindList(colorsettings, [element]);
    if (index == -1)
    {
        colorsettings += [element, strColor];
        nSaveSettings=TRUE;
    }
    else
    {
        if (llList2String(colorsettings,index+1)!=strColor)
        {
            nSaveSettings=TRUE;
            colorsettings = llListReplaceList(colorsettings, [strColor], index + 1, index + 1);
        }
    }
    if (nSaveSettings)
    {
        //save to httpdb
        llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(colorsettings, "~"), NULL_KEY);
        //currentelement = "";
    }
}



integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}

string Vec2String(vector vec)
{
    list parts = [vec.x, vec.y, vec.z];

    integer n;
    for (n = 0; n < 3; n++)
    {
        string str = llList2String(parts, n);
        //remove any trailing 0's or .'s from str
        while ((~(integer)llSubStringIndex(str, ".")) && (llGetSubString(str, -1, -1) == "0" || llGetSubString(str, -1, -1) == "."))
        {
            str = llGetSubString(str, 0, -2);
        }
        parts = llListReplaceList(parts, [str], n, n);
    }
    return "<" + llDumpList2String(parts, ",") + ">";
}

default
{
    state_entry()
    {
        wearer = llGetOwner();

        g_nCmdChannel = nGetOwnerChannel(g_nCmdChannelOffset); // get the owner defined channel


        //get dbprefix from object desc, so that it doesn't need to be hard coded, and scripts between differently-primmed collars can be identical
        string prefix = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
        if (prefix != "")
        {
            dbtoken = prefix + dbtoken;
        }

        //loop through non-root prims, build element list
        BuildElementList();

        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
    }

    http_response(key id, integer status, list meta, string body)
    {
        if (id == httpid)
        {
            if (status == 200)
            {
                //we'll have gotten several lines like "Chartreuse|<0.54118, 0.98431, 0.09020>"
                //parse that into 2-strided list of colorname, colorvector
                colors = llParseString2List(body, ["\n", "|"], []);
                colors = llListSort(colors, 2, TRUE);
                ColorMenu(user);
            }
        }
    }

    link_message(integer sender, integer auth, string str, key id)
    {
        //owner, secowner, group, and wearer may currently change colors
        if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER && str == "colors")
        {
            if (id!=wearer && auth!=COMMAND_OWNER)
            {
                Notify(id,"You are not allowed to change the colors.", FALSE);
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
            }
            else
            {
                currentelement = "";
                ElementMenu(id);
            }
        }
        else if (str == "reset" && (auth == COMMAND_OWNER || auth == COMMAND_WEARER))
        {
            //clear saved settings
            llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);
            llResetScript();
        }
        else if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER)
        {
            if (str == "settings")
            {
                Notify(id, "Color Settings: " + llDumpList2String(colorsettings, ","),FALSE);
            }
            else if (startswith(str, "setcolor"))
            {
                if (id!=wearer && auth!=COMMAND_OWNER)
                {
                    Notify(id,"You are not allowed to change the colors.", FALSE);
                }
                else
                {
                    list params = llParseString2List(str, [" "], []);
                    string element = llList2String(params, 1);
                    params = llParseString2List(str, ["<"], []);
                    vector color = (vector)("<"+llList2String(params, 1));
                    SetElementColor(element, color);
                }
            }
        }
        else if (auth == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == dbtoken)
            {
                colorsettings = llParseString2List(value, ["~"], []);
                //llInstantMessage(llGetOwner(), "Loaded color settings.");
                LoadColorSettings();
            }
        }
        else if (auth == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (auth == SUBMENU && str == submenu)
        {
            //we don't know the authority of the menu requester, so send a message through the auth system
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "colors", id);
        }
        else if (auth == DIALOG_RESPONSE)
        {
            integer menuindex = llListFindList(g_lstMenuIDs, [id]);
            if (menuindex != -1)
            {
                g_lstMenuIDs=llDeleteSubList(g_lstMenuIDs,menuindex,menuindex);
                //got a menu response meant for us.  pull out values
                list menuparams = llParseString2List(str, ["|"], []);
                key av = (key)llList2String(menuparams, 0);
                string message = llList2String(menuparams, 1);
                integer page = (integer)llList2String(menuparams, 2);
                if (message == UPMENU)
                {
                    if (currentelement == "")
                    {
                        //main menu
                        llMessageLinked(LINK_THIS, SUBMENU, parentmenu, av);
                    }
                    else if (currentcategory == "")
                    {
                        currentelement = "";
                        ElementMenu(av);
                    }
                    else
                    {
                        currentcategory = "";
                        CategoryMenu(av);
                    }
                }
                else if (currentelement == "")
                {
                    //we just got the element name
                    currentelement = message;
                    page = 0;
                    currentcategory = "";
                    CategoryMenu(av);
                }

                else if (currentcategory == "")
                {
                    colors = [];
                    currentcategory = message;
                    page = 0;
                    //ColorMenu(id);
                    user = av;
                    //line = 0;
                    //dataid = llGetNotecardLine("colors-" + currentcategory, line);
                    string url = "http://collardata.appspot.com/static/colors-" + currentcategory + ".txt";
                    httpid = llHTTPRequest(url, [HTTP_METHOD, "GET"], "");
                }
                else if (~(integer)llListFindList(colors, [message]))
                {
                    //found a color, now set it
                    integer index = llListFindList(colors, [message]);
                    vector color = (vector)llList2String(colors, index + 1);
                    //llSay(0, "color = " + (string)color);
                    //loop through links, setting color if element type matches what we're changing
                    //root prim is 1, so start at 2
                    SetElementColor(currentelement, color);
                    //ElementMenu(id);
                    // OpenCuffs: send colorchange to slave cuffs
                    SendCmd("*",g_szColorChangeCmd+"="+currentelement+"="+(string)color,NULL_KEY);
                    ColorMenu(av);
                }
            }
        }
        else if (auth == DIALOG_TIMEOUT)
        {
            integer menuindex = llListFindList(g_lstMenuIDs, [id]);
            if (menuindex != -1)
            {
                g_lstMenuIDs=llDeleteSubList(g_lstMenuIDs,menuindex,menuindex);
            }
        }

    }

    on_rez(integer param)
    {
        llResetScript();
    }
}
