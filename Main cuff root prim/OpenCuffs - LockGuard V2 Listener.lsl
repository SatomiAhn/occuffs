// Hopefully a fast enough Dispatcher for the internal LockGuard Script
// it just listens on the LockGuard Channel and sends every message it
// receives to the entire Linkset via llMessageLinked

// Depending on Performance issues I'll piggyback maybe on channel -9119
// check if LockGuard is contained in cmd and pass it along if so
// ceck if HtFcuffs is contained and pass it along if so
// discard the message in all other cases
// Must be tested - too little SL experience to tell offhand :)
integer g_nLockGuardChannel = -9119;

default {
    
    state_entry() 
    {
        llListen(g_nLockGuardChannel,"","","");
    }

    on_rez(integer rez_state) 
    {
        llResetScript();

    }
    
    listen( integer channel, string name, key id, string cmd )
    {
        llMessageLinked(LINK_SET,g_nLockGuardChannel,cmd,NULL_KEY);
    }
}