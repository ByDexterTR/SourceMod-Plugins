#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION   "3.0.2"

#pragma semicolon 1
#pragma newdecls required

int Warden = -1;
ConVar g_cVar_mnotes = null, g_cvar_remove_death = null, g_cvar_remove_startround = null;
Handle g_fward_onBecome = null, g_fward_onRemoved = null, g_fward_onDeath = null, g_fward_onRemove = null;

public Plugin myinfo = 
{
	name = "Jailbreak Warden", 
	author = "ecca, ByDexter", 
	description = "Jailbreak Warden script", 
	version = PLUGIN_VERSION, 
	url = "ffac.eu"
};

public void OnPluginStart()
{
	// Initialize our phrases
	LoadTranslations("warden.phrases");
	
	// Register our public commands
	RegConsoleCmd("sm_w", BecomeWarden);
	RegConsoleCmd("sm_warden", BecomeWarden);
	RegConsoleCmd("sm_uw", ExitWarden);
	RegConsoleCmd("sm_unwarden", ExitWarden);
	RegConsoleCmd("sm_c", BecomeWarden);
	RegConsoleCmd("sm_commander", BecomeWarden);
	RegConsoleCmd("sm_uc", ExitWarden);
	RegConsoleCmd("sm_uncommander", ExitWarden);
	
	// Register our admin commands
	RegAdminCmd("sm_rw", RemoveWarden, ADMFLAG_GENERIC);
	RegAdminCmd("sm_rc", RemoveWarden, ADMFLAG_GENERIC);
	
	// For our warden to look some extra cool
	AddCommandListener(HookPlayerChat, "say");
	
	// Hook
	HookEvent("round_start", RoundStart);
	HookEvent("player_death", OnClientDead);
	
	// May not touch this line
	CreateConVar("sm_warden_version", PLUGIN_VERSION, "The version of the SourceMod plugin JailBreak Warden, by ecca", FCVAR_REPLICATED | FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cVar_mnotes = CreateConVar("sm_better_warden_message", "0", "0 - Off, 1 - Center and Hint Text", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvar_remove_death = CreateConVar("sm_warden_death_remove", "1", "0 - Off, 1 - On", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvar_remove_startround = CreateConVar("sm_warden_roundstart_remove", "1", "0 - Off, 1 - On", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	g_fward_onBecome = CreateGlobalForward("warden_OnWardenCreated", ET_Ignore, Param_Cell);
	g_fward_onRemoved = CreateGlobalForward("warden_OnWardenRemoved", ET_Ignore, Param_Cell);
	g_fward_onRemove = CreateGlobalForward("warden_OnWardenRemove", ET_Ignore, Param_Cell);
	g_fward_onDeath = CreateGlobalForward("wardeN_OnWardenDeath", ET_Ignore, Param_Cell);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("warden_exist", Native_ExistWarden);
	CreateNative("warden_iswarden", Native_IsWarden);
	CreateNative("warden_set", Native_SetWarden);
	CreateNative("warden_remove", Native_RemoveWarden);
	
	RegPluginLibrary("warden");
	
	return APLRes_Success;
}

public Action BecomeWarden(int client, int args)
{
	if (Warden == -1) // There is no warden , so lets proceed
	{
		if (GetClientTeam(client) == 3) // The requested player is on the Counter-Terrorist side
		{
			if (IsPlayerAlive(client)) // A dead warden would be worthless >_<
			{
				SetTheWarden(client);
				return Plugin_Handled;
			}
			else // Grr he is not alive -.-
			{
				PrintToChat(client, "[SM] %t", "warden_playerdead");
				return Plugin_Handled;
			}
		}
		else // Would be wierd if an terrorist would run the prison wouldn't it :p
		{
			PrintToChat(client, "[SM] %t", "warden_ctsonly");
			return Plugin_Handled;
		}
	}
	else // The warden already exist so there is no point setting a new one
	{
		PrintToChat(client, "[SM] %t", "warden_exist", Warden);
		return Plugin_Handled;
	}
}

public Action ExitWarden(int client, int args)
{
	if (client == Warden) // The client is actually the current warden so lets proceed
	{
		PrintToChatAll("[SM] %t", "warden_retire", client);
		if (g_cVar_mnotes.BoolValue)
		{
			PrintCenterTextAll("%t", "warden_retire", client);
			PrintHintTextToAll("%t", "warden_retire", client);
		}
		Warden = -1; // Open for a new warden
		Forward_OnWardenRemove(client);
		SetEntityRenderColor(client, 255, 255, 255, 255); // Lets remove the awesome color
		return Plugin_Handled;
	}
	else // Fake dude!
	{
		PrintToChat(client, "[SM] %t", "warden_notwarden");
		return Plugin_Handled;
	}
}

public void OnClientDisconnect(int client)
{
	if (client == Warden) // The warden disconnected, action!
	{
		PrintToChatAll("[SM] %t", "warden_disconnected");
		if (g_cVar_mnotes.BoolValue)
		{
			PrintCenterTextAll("%t", "warden_disconnected", client);
			PrintHintTextToAll("%t", "warden_disconnected", client);
		}
		Warden = -1; // Lets open for a new warden
		Forward_OnWardenRemoved(client);
	}
}

public Action RemoveWarden(int client, int args)
{
	if (Warden != -1) // Is there an warden at the moment ?
	{
		RemoveTheWarden(client);
		return Plugin_Handled;
	}
	else
	{
		PrintToChatAll("[SM] %t", "warden_noexist");
		return Plugin_Handled;
	}
}

public Action RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_cvar_remove_startround.BoolValue && Warden != -1)
		Warden = -1;
}

public Action OnClientDead(Event event, const char[] name, bool dontBroadcast)
{
	if (Warden != -1)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		if (client == Warden)
		{
			Forward_OnWardenDeath(client);
			if (g_cvar_remove_death.BoolValue)
			{
				Warden = -1;
				PrintToChatAll("[SM] %t", "warden_dead");
				if (g_cVar_mnotes.BoolValue)
				{
					PrintCenterTextAll("%t", "warden_dead");
					PrintHintTextToAll("%t", "warden_dead");
				}
			}
		}
	}
}

public Action HookPlayerChat(int client, const char[] command, int argc)
{
	if (Warden == client && client != 0) // Check so the player typing is warden and also checking so the client isn't console!
	{
		char szText[256];
		GetCmdArg(1, szText, sizeof(szText));
		if (IsPlayerAlive(client)) // Typing warden is alive and his team is Counter-Terrorist
		{
			PrintToChatAll(" \x0B[Warden] \x10%N : \x04%s", client, szText);
			return Plugin_Handled;
		}
		else
		{
			PrintToChatAll(" \x02*DEAD* \x0B[Warden] \x10%N : \x04%s", client, szText);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

void SetTheWarden(int client)
{
	PrintToChatAll("[SM] %t", "warden_new", client);
	
	if (g_cVar_mnotes.BoolValue)
	{
		PrintCenterTextAll("%t", "warden_new", client);
		PrintHintTextToAll("%t", "warden_new", client);
	}
	Warden = client;
	SetEntityRenderColor(client, 0, 175, 255, 255);
	SetClientListeningFlags(client, VOICE_NORMAL);
	Forward_OnWardenCreation(client);
}

void RemoveTheWarden(int client)
{
	PrintToChatAll("[SM] %t", "warden_removed", client, Warden);
	if (g_cVar_mnotes.BoolValue)
	{
		PrintCenterTextAll("%t", "warden_removed", client);
		PrintHintTextToAll("%t", "warden_removed", client);
	}
	SetEntityRenderColor(Warden, 255, 255, 255, 255);
	Warden = -1;
	Forward_OnWardenRemoved(client);
}

public int Native_ExistWarden(Handle plugin, int numParams)
{
	if (Warden != -1)
		return true;
	
	return false;
}

public int Native_IsWarden(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsClientInGame(client) && !IsClientConnected(client))
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	
	if (client == Warden)
		return true;
	
	return false;
}

public int Native_SetWarden(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsClientInGame(client) && !IsClientConnected(client))
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	
	if (Warden == -1)
		SetTheWarden(client);
}

public int Native_RemoveWarden(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsClientInGame(client) && !IsClientConnected(client))
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	
	if (client == Warden)
		RemoveTheWarden(client);
}

public void Forward_OnWardenCreation(int client)
{
	Call_StartForward(g_fward_onBecome);
	Call_PushCell(client);
	Call_Finish();
}

public void Forward_OnWardenDeath(int client)
{
	Call_StartForward(g_fward_onDeath);
	Call_PushCell(client);
	Call_Finish();
}

public void Forward_OnWardenRemoved(int client)
{
	Call_StartForward(g_fward_onRemoved);
	Call_PushCell(client);
	Call_Finish();
}

public void Forward_OnWardenRemove(int client)
{
	Call_StartForward(g_fward_onRemove);
	Call_PushCell(client);
	Call_Finish();
} 