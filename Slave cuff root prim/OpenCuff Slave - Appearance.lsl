//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//Cuff Command Interpreter
// part of the function reused from OpenCollar Color and OpenCollar Texture modules

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

string g_szColorChangeCmd="ColorChanged";
string g_szTextureChangeCmd="TextureChanged";
string g_szLockCmd="Lock";
string g_szInfoRequest="SendLockInfo"; // request info about RLV and Lock status from main cuff
string g_szHideCmd="HideMe"; // Comand for Cuffs to hide
integer g_nHidden=FALSE;


integer    LM_CUFF_CMD        = -551001;
integer    LM_CUFF_ANIM    = -551002;


///////////////////////////////////////////////////////////////
// parts from the OpenCollar scripts for texturing and coloring 

list TextureElements;
list ColorElements;
list textures;
list colorsettings;


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
//= parameters   :    string    szStr   String to be stripped
//=
//= return        :    string stStr without spaces
//=
//= description  :    strip the spaces out of a string, needed to as workarounfd in the LM part of OpenCollar - color
//=
//===============================================================================

string szStripSpaces (string szStr)
{
    return llDumpList2String(llParseString2List(szStr, [" "], []), "");
}



///////////////////////////////////////////////////////////////
// parts from the OpenCollar scripts for texturing and coloring 

// From OpenCollar Texture
string ElementTextureType(integer linknumber)
{
    string desc = (string)llGetObjectDetails(llGetLinkKey(linknumber), [OBJECT_DESC]);
    //prim desc will be elementtype~notexture(maybe)
    list params = llParseString2List(desc, ["~"], []);
    if (~llListFindList(params, ["notexture"]) || desc == "" || desc == " " || desc == "(No Description)")
    {
        return "notexture";
    }
    else
    {
        return llList2String(llParseString2List(desc, ["~"], []), 0);
    }
}

// From OpenCollar Color

string ElementColorType(integer linknumber)
{
    string desc = (string)llGetObjectDetails(llGetLinkKey(linknumber), [OBJECT_DESC]);
    //each prim should have <elementname> in its description, plus "nocolor" or "notexture", if you want the prim to 
    //not appear in the color or texture menus
    list params = llParseString2List(desc, ["~"], []);
    if (~llListFindList(params, ["nocolor"]) || desc == "" || desc == " " || desc == "(No Description)")
    {
        return "nocolor";
    }
    else
    {
        return llList2String(params, 0);
    }
}

// From OpenCollar Texture
BuildTextureList()
{
    //loop through non-root prims, build element list
    integer n;
    integer linkcount = llGetNumberOfPrims();

    //root prim is 1, so start at 2
    for (n = 2; n <= linkcount; n++)
    {
        string element = ElementTextureType(n);
        if (!(~llListFindList(TextureElements, [element])) && element != "notexture")
        {
            TextureElements += [element];
            //llSay(0, "added " + element + " to elements");
        }
    }
}

// From OpenCollar Texture
SetElementTexture(string element, key tex)
{
    integer i=llListFindList(textures,[element]);
    if ((i==-1)||(llList2Key(textures,i+1)!=tex))
    {
        integer n;
        integer linkcount = llGetNumberOfPrims();
        for (n = 2; n <= linkcount; n++)
        {
            string thiselement = ElementTextureType(n);
            if (thiselement == element)
            {
                //set link to new texture
                llSetLinkTexture(n, tex, ALL_SIDES);
            }
        }            
        
        //change the textures list entry for the current element
        integer index;
        index = llListFindList(textures, [element]);
        if (index == -1)
        {
            textures += [element, tex];
        }
        else
        {
            textures = llListReplaceList(textures, [tex], index + 1, index + 1);
        }
        //save to httpdb is not needed
        // llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(textures, "~"), NULL_KEY);     
    }
}

// From OpenCollar Colors
BuildColorElementList()
{
    integer n;
    integer linkcount = llGetNumberOfPrims();
    
    //root prim is 1, so start at 2
    for (n = 2; n <= linkcount; n++)
    {
        string element = ElementColorType(n);
        if (!(~llListFindList(ColorElements, [element])) && element != "nocolor")
        {
            ColorElements += [element];
            //llSay(0, "added " + element + " to elements");
        }
    }    
}

// From OpenCollar Colors
SetElementColor(string element, vector color)
{
    
    integer i=llListFindList(colorsettings,[element]);
    if ((i==-1)||(llList2Vector(colorsettings,i+1)!=color))
    {
    
        integer n;
        integer linkcount = llGetNumberOfPrims();
        for (n = 2; n <= linkcount; n++)
        {
            string thiselement = ElementColorType(n);
            if (thiselement == element)
            {
                //set link to new color
                //llSetLinkPrimitiveParams(n, [PRIM_COLOR, ALL_SIDES, color, 1.0]);
                llSetLinkColor(n, color, ALL_SIDES);
            }
        }            
        
        //change the colorsettings list entry for the current element
        
        integer index = llListFindList(colorsettings, [element]);
        if (index == -1)
        {
            colorsettings += [element, color];
        }
        else
        {
            colorsettings = llListReplaceList(colorsettings, [color], index + 1, index + 1);
        }
        //save to httpdb not needed
        // llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(colorsettings, "~"), NULL_KEY); 
        //currentelement = "";    
    }
}

// end of OpenCollar parts


default
{
    state_entry()
    {
        // Build a líst of all elements for texturing and coloring
        BuildTextureList();
        BuildColorElementList();
    }
    
    link_message(integer nSenderNum, integer nNum, string szMsg, key keyID)
    {
        if (nNum == LM_CUFF_CMD)
        // cuff commans
        {
            if (nStartsWith(szMsg,g_szColorChangeCmd))
            {
                // a change of colors has occured, make sure the cuff try to set identiccal to the collar
                list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
                // set the color, uses StripSpace fix for colrs just in case
                SetElementColor(llList2String(lstCmdList,1),(vector)szStripSpaces(llList2String(lstCmdList,2)));   
    
            }
            else if (nStartsWith(szMsg,g_szTextureChangeCmd))
            {
                // a change of colors has occured, make sure the cuff try to set identiccal to the collar
                list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
                // set the texture
                SetElementTexture(llList2String(lstCmdList,1),szStripSpaces(llList2String(lstCmdList,2)));   
            }
            else if (nStartsWith(szMsg,g_szHideCmd))
            {
                // a change of colors has occured, make sure the cuff try to set identiccal to the collar
                list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
                g_nHidden= llList2Integer(lstCmdList,1);
                if (g_nHidden)
                {
                    llSetLinkAlpha(LINK_SET,0.0,ALL_SIDES);
                }
                else
                {
                    llSetLinkAlpha(LINK_SET,1.0,ALL_SIDES);
                }
            }
    
        }
    
    }

}
