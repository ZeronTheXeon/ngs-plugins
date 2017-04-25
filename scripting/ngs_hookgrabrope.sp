/**
 * ==========================================================================
 * SourceMod Hook Grab Rope for Source
 *
 * SourceMod Forums URL:
 * https://forums.alliedmods.net/showthread.php?t=201154
 *
 * by Sheepdude and SumGuy14
 *
 * Allows admins (or all players) to hook on to walls, grab other players, or swing on a rope
 *
 */

#include <sourcemod>
#include <sdktools>
#include <hgr>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.1.4"

public Plugin myinfo = {
	name = "[NGS] Hook Grab Rope",
	author = "Sheepdude, SumGuy14 / TheXeon",
	description = "Allows admins (or all players) to hook on to walls, grab other players, or swing on a rope",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net"
}

// General handles
ConVar h_cvarAnnounce;
ConVar h_cvarSoundAmplify;
ConVar h_cvarOverrideMode;
ConVar h_cvarRopeOldMode;
ConVar h_cvarUpButton;
ConVar h_cvarDownButton;

// Hook handles
ConVar h_cvarHookEnable;
ConVar h_cvarHookAdminOnly;
ConVar h_cvarHookFreeze;
ConVar h_cvarHookSlide;
ConVar h_cvarHookSpeed;
ConVar h_cvarHookInitWidth;
ConVar h_cvarHookEndWidth;
ConVar h_cvarHookAmplitude;
ConVar h_cvarHookBeamColor;
ConVar h_cvarHookRed;
ConVar h_cvarHookGreen;
ConVar h_cvarHookBlue;
ConVar h_cvarHookAlpha;
ConVar h_cvarHookSound;

// Grab handles
ConVar h_cvarGrabEnable;
ConVar h_cvarGrabAdminOnly;
ConVar h_cvarGrabFreeze;
ConVar h_cvarGrabSlide;
ConVar h_cvarGrabSpeed;
ConVar h_cvarGrabInitWidth;
ConVar h_cvarGrabEndWidth;
ConVar h_cvarGrabAmplitude;
ConVar h_cvarGrabBeamColor;
ConVar h_cvarGrabRed;
ConVar h_cvarGrabGreen;
ConVar h_cvarGrabBlue;
ConVar h_cvarGrabAlpha;
ConVar h_cvarGrabSound;

// Rope handles
ConVar h_cvarRopeEnable;
ConVar h_cvarRopeAdminOnly;
ConVar h_cvarRopeFreeze;
ConVar h_cvarRopeSlide;
ConVar h_cvarRopeSpeed;
ConVar h_cvarRopeInitWidth;
ConVar h_cvarRopeEndWidth;
ConVar h_cvarRopeAmplitude;
ConVar h_cvarRopeBeamColor;
ConVar h_cvarRopeRed;
ConVar h_cvarRopeGreen;
ConVar h_cvarRopeBlue;
ConVar h_cvarRopeAlpha;
ConVar h_cvarRopeSound;

// Forward handles
Handle FwdClientHook;
Handle FwdClientGrabSearch;
Handle FwdClientGrab;
Handle FwdClientRope;

// HGR variables
int g_cvarSoundAmplify;
bool g_cvarAnnounce;
bool g_cvarOverrideMode;
bool g_cvarRopeOldMode;
bool g_cvarFreeze[3];
bool g_cvarSlide[3];
bool g_cvarEnable[3];
bool g_cvarAdminOnly[3];
float g_cvarSpeed[3];
float g_cvarInitWidth[3];
float g_cvarEndWidth[3];
float g_cvarAmplitude[3];
int g_cvarBeamColor[3];
int g_cvarBeamRed[3];
int g_cvarBeamGreen[3];
int g_cvarBeamBlue[3];
int g_cvarBeamAlpha[3];
char g_cvarSound[3][64];

// Client status arrays
bool g_Status[MAXPLAYERS+1][3]; // Is client using hook, grab, or rope
bool g_AllowedClients[MAXPLAYERS+1][3]; // Does client have hook, grab, or rope access
bool g_Grabbed[MAXPLAYERS+1]; // Is client being grabbed
bool g_Backward[MAXPLAYERS+1]; // Is client hooking backward or forward
bool g_Attracting[MAXPLAYERS+1][2]; // Is client pushing or pulling grab target
bool g_Climbing[MAXPLAYERS+1][2]; // Is client ascending or descending rope
bool g_TRIgnore[MAXPLAYERS+1]; // Used to ignore traceray collisions with originating player
float g_Gravity[MAXPLAYERS+1]; // Used to reset client gravity to previous value
float g_MaxSpeed[MAXPLAYERS+1]; // Used to reset grab target speed after being slowed

// HGR Arrays
int g_Targetindex[MAXPLAYERS+1][4];
float g_Location[MAXPLAYERS+1][4][3];
float g_Distance[MAXPLAYERS+1][4];

// Button bitstrings
int g_cvarUpButton;
int g_cvarDownButton;

// Freezetime variables
bool g_HookedFreeze;
bool g_HookedRoundStart;
bool g_Frozen[3];

// Offset variables
int OriginOffset;
int GetVelocityOffset_x;
int GetVelocityOffset_y;
int GetVelocityOffset_z;

// Precache variables
int precache_laser;

enum HGRAction
{
	Hook = 0, /** User is using hook */
	Grab = 1, /** User is using grab */
	Rope = 2, /** User is using rope */
};

enum HGRAccess
{
	Give = 0, /** Gives access to user */
	Take = 1, /** Takes access from user */
};

public void OnPluginStart()
{
	// Load Translation Files
	LoadTranslations("common.phrases");
	LoadTranslations("hookgrabrope.phrases");
	
	PrintToServer("----------------|         [HGR] %t        |---------------", "Loading");
	
	// Create global forwards
	FwdClientHook = CreateGlobalForward("HGR_OnClientHook", ET_Hook, Param_Cell);
	FwdClientGrabSearch = CreateGlobalForward("HGR_OnClientGrabSearch", ET_Hook, Param_Cell);
	FwdClientGrab = CreateGlobalForward("HGR_OnClientGrab", ET_Hook, Param_Cell);
	FwdClientRope = CreateGlobalForward("HGR_OnClientRope", ET_Hook, Param_Cell);
	
	// Hook events
	HookEvent("player_spawn", PlayerSpawnEvent);
	g_HookedFreeze = HookEventEx("round_freeze_end", RoundFreezeEndEvent, EventHookMode_PostNoCopy);
	g_HookedRoundStart = HookEventEx("round_start", RoundStartEvent, EventHookMode_PostNoCopy);

	// Register client commands
	RegConsoleCmd("+hook", HookCmd);
	RegConsoleCmd("-hook", UnHookCmd);
	RegConsoleCmd("hook_toggle", HookToggle);

	RegConsoleCmd("+grab", GrabCmd);
	RegConsoleCmd("-grab", DropCmd);
	RegConsoleCmd("grab_toggle", GrabToggle);

	RegConsoleCmd("+rope", RopeCmd);
	RegConsoleCmd("-rope", DetachCmd);
	RegConsoleCmd("rope_toggle", RopeToggle);
	
	RegConsoleCmd("+push", PushCmd);
	RegConsoleCmd("-push", UnPushCmd);
	RegConsoleCmd("push_toggle", HookToggle);

	// Register admin cmds
	RegAdminCmd("sm_hgr_givehook", GiveHook, ADMFLAG_GENERIC);
	RegAdminCmd("sm_hgr_takehook", TakeHook, ADMFLAG_GENERIC);

	RegAdminCmd("sm_hgr_givegrab", GiveGrab, ADMFLAG_GENERIC);
	RegAdminCmd("sm_hgr_takegrab", TakeGrab, ADMFLAG_GENERIC);

	RegAdminCmd("sm_hgr_giverope", GiveRope, ADMFLAG_GENERIC);
	RegAdminCmd("sm_hgr_takerope", TakeRope, ADMFLAG_GENERIC);

	// Find offsets
	OriginOffset = FindSendPropInfo("CBaseEntity", "m_vecOrigin");
	if(OriginOffset == -1)
		SetFailState("[HGR] Error: Failed to find the origin offset, aborting");

	GetVelocityOffset_x = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	if(GetVelocityOffset_x == -1)
		SetFailState("[HGR] Error: Failed to find the velocity_x offset, aborting");

	GetVelocityOffset_y = FindSendPropInfo("CBasePlayer", "m_vecVelocity[1]");
	if(GetVelocityOffset_y == -1)
		SetFailState("[HGR] Error: Failed to find the velocity_y offset, aborting");

	GetVelocityOffset_z = FindSendPropInfo("CBasePlayer", "m_vecVelocity[2]");
	if(GetVelocityOffset_z == -1)
		SetFailState("[HGR] Error: Failed to find the velocity_z offset, aborting");

	// Public convar
	CreateConVar("sm_hgr_version", PLUGIN_VERSION, "[HGR] Plugin version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_SPONLY);

	// General convars
	h_cvarAnnounce      = CreateConVar("sm_hgr_announce", "1", "Enable plugin announcements, 1 - enable, 0 - disable", 0, true, 0.0, true, 1.0);
	h_cvarSoundAmplify  = CreateConVar("sm_hgr_sound_amplify", "3", "Control the sound effect volume, 0 - No Sound, 1 - Quiet, 5 - Loud", 0, true, 0.0, true, 5.0);
	h_cvarOverrideMode  = CreateConVar("sm_hgr_overridemode", "0", "If enabled, only players who have manually been given access can use plugin", 0, true, 0.0, true, 1.0);
	h_cvarRopeOldMode   = CreateConVar("sm_hgr_rope_oldmode", "0", "Use the old rope type, 1 - Use old type, 0 - Don't use old type", 0, true, 0.0, true, 1.0);
	h_cvarUpButton      = CreateConVar("sm_hgr_upbutton", "IN_JUMP", "Button to use for ascending rope, hooking forward, and pushing grab target");
	h_cvarDownButton    = CreateConVar("sm_hgr_downbutton", "IN_DUCK", "Button to use for descending rope, hooking backward, and pulling grab target");

	// Hook convars
	h_cvarHookEnable    = CreateConVar("sm_hgr_hook_enable", "1", "This will enable the hook feature of this plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_cvarHookAdminOnly = CreateConVar("sm_hgr_hook_adminonly", "1", "If 1, only admins can use hook", 0, true, 0.0, true, 1.0);
	h_cvarHookFreeze    = CreateConVar("sm_hgr_hook_freeze_enable", "0", "Allow players to hook during freezetime, 1 - Allow, 0 - Disallow", 0, true, 0.0, true, 1.0);
	h_cvarHookSlide     = CreateConVar("sm_hgr_hook_slide_enable", "1", "Allow players to reverse the direction of the hook, 1 - Allow, 0 - Disallow", 0, true, 0.0, true, 1.0);
	h_cvarHookSpeed     = CreateConVar("sm_hgr_hook_speed", "5.0", "The speed of the player using hook", 0, true, 0.0, true, 100.0);
	h_cvarHookInitWidth = CreateConVar("sm_hgr_hook_initwidth", "5.0", "The initial width of the hook beam", 0, true, 0.0, true, 100.0);
	h_cvarHookEndWidth  = CreateConVar("sm_hgr_hook_endwidth", "5.0", "The end width of the hook beam", 0, true, 0.0, true, 100.0);
	h_cvarHookAmplitude = CreateConVar("sm_hgr_hook_amplitude", "0.0", "The amplitude of the hook beam", 0, true, 0.0, true, 100.0);
	h_cvarHookBeamColor = CreateConVar("sm_hgr_hook_color", "2", "The color of the hook, 0 = White, 1 = Team color, 2 = custom, 3 = Reverse team color", 0, true, 0.0, true, 3.0);
	h_cvarHookRed       = CreateConVar("sm_hgr_hook_red", "255", "The red component of the beam (Only if you are using a custom color)", 0, true, 0.0, true, 255.0);
	h_cvarHookGreen     = CreateConVar("sm_hgr_hook_green", "0", "The green component of the beam (Only if you are using a custom color)", 0, true, 0.0, true, 255.0);
	h_cvarHookBlue      = CreateConVar("sm_hgr_hook_blue", "0", "The blue component of the beam (Only if you are using a custom color)", 0, true, 0.0, true, 255.0);
	h_cvarHookAlpha     = CreateConVar("sm_hgr_hook_alpha", "255", "The alpha component of the beam (Only if you are using a custom color)", 0, true, 0.0, true, 255.0);
	h_cvarHookSound     = CreateConVar("sm_hgr_hook_sound", "hgr/hookhit.mp3", "Location of hook sound effect relative to /sound/music/");

	// Grab convars
	h_cvarGrabEnable    = CreateConVar("sm_hgr_grab_enable", "1", "This will enable the grab feature of this plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_cvarGrabAdminOnly = CreateConVar("sm_hgr_grab_adminonly", "1", "If 1, only admins can use grab", 0, true, 0.0, true, 1.0);
	h_cvarGrabFreeze    = CreateConVar("sm_hgr_grab_freeze_enable", "0", "Allow players to grab during freezetime, 1 - Allow, 0 - Disallow", 0, true, 0.0, true, 1.0);
	h_cvarGrabSlide     = CreateConVar("sm_hgr_grab_slide_enable", "1", "Allow players to push or pull grab target, 1 - Allow, 0 - Disallow", 0, true, 0.0, true, 1.0);
	h_cvarGrabSpeed     = CreateConVar("sm_hgr_grab_speed", "5.0", "The speed of the grabbers target", 0, true, 0.0, true, 100.0);
	h_cvarGrabInitWidth = CreateConVar("sm_hgr_grab_initwidth", "1.0", "The initial width of the grab beam", 0, true, 0.0, true, 100.0);
	h_cvarGrabEndWidth  = CreateConVar("sm_hgr_grab_endwidth", "10.0", "The end width of the grab beam", 0, true, 0.0, true, 100.0);
	h_cvarGrabAmplitude = CreateConVar("sm_hgr_grab_amplitude", "0.0", "The amplitude of the grab beam", 0, true, 0.0, true, 100.0);
	h_cvarGrabBeamColor = CreateConVar("sm_hgr_grab_color", "2", "The color of the grab beam, 0 = White, 1 = Team color, 2 = custom, 3 = Reverse team color", 0, true, 0.0, true, 3.0);
	h_cvarGrabRed       = CreateConVar("sm_hgr_grab_red", "0", "The red component of the beam (Only if you are using a custom color)", 0, true, 0.0, true, 255.0);
	h_cvarGrabGreen     = CreateConVar("sm_hgr_grab_green", "0", "The green component of the beam (Only if you are using a custom color)", 0, true, 0.0, true, 255.0);
	h_cvarGrabBlue      = CreateConVar("sm_hgr_grab_blue", "255", "The blue component of the beam (Only if you are using a custom color)", 0, true, 0.0, true, 255.0);
	h_cvarGrabAlpha     = CreateConVar("sm_hgr_grab_alpha", "255", "The alpha component of the beam (Only if you are using a custom color)", 0, true, 0.0, true, 255.0);
	h_cvarGrabSound     = CreateConVar("sm_hgr_grab_sound", "hgr/hookhit.mp3", "Location of grab sound effect relative to /sound/music/");

	// Rope convars
	h_cvarRopeEnable    = CreateConVar("sm_hgr_rope_enable", "1", "This will enable the rope feature of this plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_cvarRopeAdminOnly = CreateConVar("sm_hgr_rope_adminonly", "1", "If 1, only admins can use rope", 0, true, 0.0, true, 1.0);
	h_cvarRopeFreeze    = CreateConVar("sm_hgr_rope_freeze_enable", "0", "Allow players to rope during freezetime, 1 - Allow, 0 - Disallow", 0, true, 0.0, true, 1.0);
	h_cvarRopeSlide     = CreateConVar("sm_hgr_rope_slide_enable", "1", "Allow players to slide up or down rope, 1 - Allow, 0 - Disallow", 0, true, 0.0, true, 1.0);
	h_cvarRopeSpeed     = CreateConVar("sm_hgr_rope_speed", "5.0", "The speed of the player using rope", 0, true, 0.0, true, 100.0);
	h_cvarRopeInitWidth = CreateConVar("sm_hgr_rope_initwidth", "3.0", "The initial width of the rope beam", 0, true, 0.0, true, 100.0);
	h_cvarRopeEndWidth  = CreateConVar("sm_hgr_rope_endwidth", "3.0", "The end width of the rope beam", 0, true, 0.0, true, 100.0);
	h_cvarRopeAmplitude = CreateConVar("sm_hgr_rope_amplitude", "0.0", "The amplitude of the rope beam", 0, true, 0.0, true, 100.0);
	h_cvarRopeBeamColor = CreateConVar("sm_hgr_rope_color", "2", "The color of the rope, 0 = White, 1 = Team color, 2 = custom, 3 = Reverse team color", 0, true, 0.0, true, 3.0);
	h_cvarRopeRed       = CreateConVar("sm_hgr_rope_red", "0", "The red component of the beam (Only if you are using a custom color)", 0, true, 0.0, true, 255.0);
	h_cvarRopeGreen     = CreateConVar("sm_hgr_rope_green", "255", "The green component of the beam (Only if you are using a custom color)", 0, true, 0.0, true, 255.0);
	h_cvarRopeBlue      = CreateConVar("sm_hgr_rope_blue", "0", "The blue component of the beam (Only if you are using a custom color)", 0, true, 0.0, true, 255.0);
	h_cvarRopeAlpha     = CreateConVar("sm_hgr_rope_alpha", "255", "The alpha component of the beam (Only if you are using a custom color)", 0, true, 0.0, true, 255.0);
	h_cvarRopeSound     = CreateConVar("sm_hgr_rope_sound", "hgr/hookhit.mp3", "Location of rope sound effect relative to /sound/music/");
	
	// General convar changes
	h_cvarAnnounce.AddChangeHook(ConvarChanged);
	h_cvarSoundAmplify.AddChangeHook(ConvarChanged);
	h_cvarOverrideMode.AddChangeHook(ConvarChanged);
	h_cvarRopeOldMode.AddChangeHook(ConvarChanged);
	h_cvarUpButton.AddChangeHook(ConvarChanged);
	h_cvarDownButton.AddChangeHook(ConvarChanged);
	
	// Hook convar changes
	h_cvarHookEnable.AddChangeHook(ConvarChanged);
	h_cvarHookAdminOnly.AddChangeHook(ConvarChanged);
	h_cvarHookFreeze.AddChangeHook(ConvarChanged);
	h_cvarHookSlide.AddChangeHook(ConvarChanged);
	h_cvarHookSpeed.AddChangeHook(ConvarChanged);
	h_cvarHookInitWidth.AddChangeHook(ConvarChanged);
	h_cvarHookEndWidth.AddChangeHook(ConvarChanged);
	h_cvarHookAmplitude.AddChangeHook(ConvarChanged);
	h_cvarHookBeamColor.AddChangeHook(ConvarChanged);
	h_cvarHookRed.AddChangeHook(ConvarChanged);
	h_cvarHookGreen.AddChangeHook(ConvarChanged);
	h_cvarHookBlue.AddChangeHook(ConvarChanged);
	h_cvarHookAlpha.AddChangeHook(ConvarChanged);
	h_cvarHookSound.AddChangeHook(ConvarChanged);
	
	// Grab convar changes
	h_cvarGrabEnable.AddChangeHook(ConvarChanged);
	h_cvarGrabAdminOnly.AddChangeHook(ConvarChanged);
	h_cvarGrabFreeze.AddChangeHook(ConvarChanged);
	h_cvarGrabSlide.AddChangeHook(ConvarChanged);
	h_cvarGrabSpeed.AddChangeHook(ConvarChanged);
	h_cvarGrabInitWidth.AddChangeHook(ConvarChanged);
	h_cvarGrabEndWidth.AddChangeHook(ConvarChanged);
	h_cvarGrabAmplitude.AddChangeHook(ConvarChanged);
	h_cvarGrabBeamColor.AddChangeHook(ConvarChanged);
	h_cvarGrabRed.AddChangeHook(ConvarChanged);
	h_cvarGrabGreen.AddChangeHook(ConvarChanged);
	h_cvarGrabBlue.AddChangeHook(ConvarChanged);
	h_cvarGrabAlpha.AddChangeHook(ConvarChanged);
	h_cvarGrabSound.AddChangeHook(ConvarChanged);
	
	// Rope convar changes
	h_cvarRopeEnable.AddChangeHook(ConvarChanged);
	h_cvarRopeAdminOnly.AddChangeHook(ConvarChanged);
	h_cvarRopeFreeze.AddChangeHook(ConvarChanged);
	h_cvarRopeSlide.AddChangeHook(ConvarChanged);
	h_cvarRopeSpeed.AddChangeHook(ConvarChanged);
	h_cvarRopeInitWidth.AddChangeHook(ConvarChanged);
	h_cvarRopeEndWidth.AddChangeHook(ConvarChanged);
	h_cvarRopeAmplitude.AddChangeHook(ConvarChanged);
	h_cvarRopeBeamColor.AddChangeHook(ConvarChanged);
	h_cvarRopeRed.AddChangeHook(ConvarChanged);
	h_cvarRopeGreen.AddChangeHook(ConvarChanged);
	h_cvarRopeBlue.AddChangeHook(ConvarChanged);
	h_cvarRopeAlpha.AddChangeHook(ConvarChanged);
	h_cvarRopeSound.AddChangeHook(ConvarChanged);
  
	// Auto-generate configuration file
	AutoExecConfig(true, "hookgrabrope");

	PrintToServer("----------------|         [HGR] %t         |---------------", "Loaded");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char file[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, file, sizeof(file), "plugins/hookgrabrope.smx");
	if(!FileExists(file))
	{
		SetFailState("ERROR: Cannot find required plugin hookgrabrope.smx");
		return APLRes_Failure;
	}
	RegPluginLibrary("hookgrabrope");
	
	// Access natives
	CreateNative("HGR_Access", __Access);
	CreateNative("HGR_ClientAccess", __ClientAccess);
	
	// Status bools
	CreateNative("HGR_IsHooking", __IsHooking);
	CreateNative("HGR_IsGrabbing", __IsGrabbing);
	CreateNative("HGR_IsBeingGrabbed", __IsBeingGrabbed);
	CreateNative("HGR_IsRoping", __IsRoping);
	CreateNative("HGR_IsPushing", __IsPushing);
	CreateNative("HGR_IsAttracting", __IsAttracting);
	CreateNative("HGR_IsRepelling", __IsRepelling);
	CreateNative("HGR_IsAscending", __IsAscending);
	CreateNative("HGR_IsDescending", __IsDescending);
	
	// Information natives
	CreateNative("HGR_GetHookLocation", __GetHookLocation);
	CreateNative("HGR_GetGrabLocation", __GetGrabLocation);
	CreateNative("HGR_GetRopeLocation", __GetRopeLocation);
	CreateNative("HGR_GetPushLocation", __GetPushLocation);
	CreateNative("HGR_GetHookDistance", __GetHookDistance);
	CreateNative("HGR_GetGrabDistance", __GetGrabDistance);
	CreateNative("HGR_GetRopeDistance", __GetRopeDistance);
	CreateNative("HGR_GetPushDistance", __GetPushDistance);
	CreateNative("HGR_GetHookTarget", __GetHookTarget);
	CreateNative("HGR_GetGrabTarget", __GetGrabTarget);
	CreateNative("HGR_GetRopeTarget", __GetRopeTarget);
	CreateNative("HGR_GetPushTarget", __GetPushTarget);
	
	// Action overrides
	CreateNative("HGR_ForceHook", __ForceHook);
	CreateNative("HGR_ForceGrab", __ForceGrab);
	CreateNative("HGR_ForceRope", __ForceRope);
	CreateNative("HGR_ForcePush", __ForcePush);
	CreateNative("HGR_StopHook", __StopHook);
	CreateNative("HGR_StopGrab", __StopGrab);
	CreateNative("HGR_StopRope", __StopRope);
	
	return APLRes_Success;
}

/**********
 *Forwards*
***********/

public void OnConfigsExecuted()
{
	UpdateAllConvars();
	// Precache models
	precache_laser = PrecacheModel("materials/sprites/laserbeam.vmt");
	
	// Precache sounds
	if(g_cvarSoundAmplify > 0) // Don't download sounds if sound is disabled
	{
		for(HGRAction i = Hook; i <= Rope; i++)
		{
			Format(g_cvarSound[i], sizeof(g_cvarSound[]), "music/%s", g_cvarSound[i]);
			char path[64];
			Format(path, sizeof(path), "sound/%s", g_cvarSound[i]);
			AddFileToDownloadsTable(path);
			PrecacheSound(g_cvarSound[i], true);
		}
	}
}

public void OnClientConnected(int client)
{
	// Initialize variables for special plugin access when clients connect
	ResetAccess(client);
}

public void OnClientDisconnect(int client)
{
	// Disable special plugin access for client when they disconnect
	ResetAccess(client);
}

/*********
 *Natives*
**********/

public int __Access(Handle plugin, int numParams)
{
	char client[64];
	GetNativeString(1, client, sizeof(client));
	HGRAccess access = GetNativeCell(2);
	HGRAction action = GetNativeCell(3);
	return Access(client, access, action);
}

public int __ClientAccess(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	HGRAccess access = GetNativeCell(2);
	HGRAction action = GetNativeCell(3);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	return ClientAccess(client, access, action) == 1;
}

public int __IsHooking(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	return g_Status[client][Hook];
}

public int __IsGrabbing(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	return g_Status[client][Grab];
}

public int __IsBeingGrabbed(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	return g_Grabbed[client];
}

public int __IsRoping(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	return g_Status[client][Rope];
}

public int __IsPushing(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Hook])
		return g_Backward[client];
	return false;
}

public int __IsAttracting(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Grab])
		return g_Attracting[client][1];
	return false;
}

public int __IsRepelling(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Grab])
		return g_Attracting[client][0];
	return false;
}

public int __IsAscending(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Rope])
		return g_Climbing[client][0];
	return false;
}

public int __IsDescending(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Rope])
		return g_Climbing[client][1];
	return false;
}

public int __GetHookLocation(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Hook])
	{
		SetNativeArray(2, g_Location[client][0], 3);
		return true;
	}
	return false;
}

public int __GetGrabLocation(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Grab])
	{
		float buffer[3];
		GetEntityOrigin(g_Targetindex[client][Grab], buffer);
		SetNativeArray(2, buffer, 3);
		return true;
	}
	else
		return false;
}

public int __GetRopeLocation(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Rope])
	{
		SetNativeArray(2, g_Location[client][2], 3);
		return true;
	}
	else
		return false;
}

public int __GetPushLocation(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Hook])
	{
		SetNativeArray(2, g_Location[client][3], 3);
		return true;
	}
	else
		return false;
}

public int __GetHookDistance(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Hook])
		return view_as<int>(g_Distance[client][0]);
	else
		return -1;
}

public int __GetGrabDistance(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Grab])
		return view_as<int>(g_Distance[client][1]);
	else
		return -1;
}

public int __GetRopeDistance(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Rope])
		return view_as<int>(g_Distance[client][2]);
	else
		return -1;
}

public int __GetPushDistance(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Hook])
		return view_as<int>(g_Distance[client][3]);
	else
		return -1;
}

public int __GetHookTarget(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Hook])
		return g_Targetindex[client][Hook];
	else
		return -1;
}

public int __GetGrabTarget(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Grab])
		return g_Targetindex[client][Grab];
	else
		return -1;
}

public int __GetRopeTarget(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Rope])
		return g_Targetindex[client][Rope];
	else
		return -1;
}

public int __GetPushTarget(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Hook])
		return g_Targetindex[client][3];
	else
		return -1;
}

public int __ForceHook(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(!g_Status[client][Hook] && !g_Status[client][Grab] && !g_Status[client][Rope] && !g_Grabbed[client])
	{
		HookCmd(client, 0);
		return true;
	}
	return false;
}

public int __ForceGrab(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(!g_Status[client][Hook] && !g_Status[client][Grab] && !g_Status[client][Rope] && !g_Grabbed[client])
	{
		GrabCmd(client, 0);
		return true;
	}
	return false;
}

public int __ForceRope(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(!g_Status[client][Hook] && !g_Status[client][Grab] && !g_Status[client][Rope] && !g_Grabbed[client])
	{
		RopeCmd(client, 0);
		return true;
	}
	return false;
}

public int __ForcePush(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(!g_Status[client][Hook] && !g_Status[client][Grab] && !g_Status[client][Rope] && !g_Grabbed[client])
	{
		PushCmd(client, 0);
		return true;
	}
	return false;
}

public int __StopHook(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Hook])
	{
		UnHookCmd(client, 0);
		return true;
	}
	return false;
}

public int __StopGrab(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Grab])
	{
		DropCmd(client, 0);
		return true;
	}
	return false;
}

public int __StopRope(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Rope])
	{
		DetachCmd(client, 0);
		return true;
	}
	return false;
}

public int __StopPush(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	else if(!IsClientInGame(client))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
	if(g_Status[client][Hook] && g_Backward[client])
	{
		DetachCmd(client, 0);
		return true;
	}
	return false;
}

/********
 *Events*
*********/

public void OnGameFrame()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			int cl_buttons = GetClientButtons(i);
			if(g_Status[i][Hook] && g_cvarSlide[Hook])
			{
				if(cl_buttons & g_cvarUpButton && g_Backward[i])
				{
					SetEntityMoveType(i, MOVETYPE_WALK);
					g_Backward[i] = false; // Hook in forward direction if client is jumping
				}
				else if(cl_buttons & g_cvarDownButton && !g_Backward[i])
				{
					SetEntityMoveType(i, MOVETYPE_WALK);
					g_Backward[i] = true; // Hook in reverse direction if client is crouching
				}
			}
			else if(g_Status[i][Grab] && g_cvarSlide[Grab])
			{
				if(cl_buttons & g_cvarUpButton)
				{
					if(!g_Attracting[i][0])
					{
						g_Attracting[i][0] = true; // Repel grab target away from client while jumping
						g_Attracting[i][1] = false;
					}
				}
				else
				{
					if(g_Attracting[i][0])
						g_Attracting[i][0] = false; // Tell plugin client is no longer repelling grab target while no longer jumping
					if(cl_buttons & g_cvarDownButton)
					{
						if(!g_Attracting[i][1])
							g_Attracting[i][1] = true; // Attract grab target toward client while crouching
					}
					else if(g_Attracting[i][1])
						g_Attracting[i][1] = false; // Tell plugin client is no longer attracting grab target while no longer crouching
				}
			}
			else if(g_Status[i][Rope] && g_cvarSlide[Rope])
			{
				if(cl_buttons & g_cvarUpButton)
				{
					if(!g_Climbing[i][0])
					{
						g_Climbing[i][0] = true; // Ascend rope while jumping
						g_Climbing[i][1] = false;
					}
				}
				else
				{
					if(g_Climbing[i][0])
						g_Climbing[i][0] = false; // Tell plugin client is no longer ascending rope while not jumping
					if(cl_buttons & g_cvarDownButton)
					{
						if(!g_Climbing[i][1])
							g_Climbing[i][1] = true; // Descend rope while crouching
					}
					else if(g_Climbing[i][1])
						g_Climbing[i][1] = false; // Tell plugin client is no longer descending rope while not crouching
				}
			}
		}
	}
}

public void PlayerSpawnEvent(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsFakeClient(client))
		return;
	
	// Tell plugin that the client isn't using any of its features
	g_Status[client][Hook] = false;
	g_Status[client][Grab] = false;
	g_Status[client][Rope] = false;
	g_Grabbed[client] = false;
	g_Backward[client] = false;
	g_Attracting[client][0] = false;
	g_Attracting[client][1] = false;
	g_Climbing[client][0] = false;
	g_Climbing[client][1] = false;
	g_Targetindex[client][0] = -1;
	g_Targetindex[client][1] = -1;
	g_Targetindex[client][2] = -1;
	g_Targetindex[client][3] = -1;
	if(g_cvarAnnounce)
	{	
		char buffer[128];
		Format(buffer, sizeof(buffer), "\x01\x0B\x04[HGR]\x01 %t\x04 ", "Enabled");
		if(HasAccess(client, Hook))
			Format(buffer, sizeof(buffer), "%s[+Hook] ", buffer);
		if(HasAccess(client, Grab))
			Format(buffer, sizeof(buffer), "%s[+Grab] ", buffer);
		if(HasAccess(client, Rope))
			Format(buffer, sizeof(buffer), "%s[+Rope]", buffer);
		PrintToChat(client, buffer);
	}
}

public void RoundStartEvent(Event event, const char[] name, bool dontBroadcast)
{
	// Tell plugin whether players can use hook grab rope during freezetime
	if(g_HookedFreeze)
	{
		for(HGRAction i = Hook; i <= Rope; i++)
			g_Frozen[i] = g_cvarFreeze[i];
	}
	else
	{
		for(HGRAction k = Hook; k <= Rope; k++)
			g_Frozen[k] = true;
	}
}

public void RoundFreezeEndEvent(Event event, const char[] name, bool dontBroadcast)
{
	// Freezetime has ended
	for(HGRAction i = Hook; i <= Rope; i++)
		g_Frozen[i] = true;
}

/******************
 *Console Commands*
*******************/

public Action HookCmd(int client, int args)
{
	g_Backward[client] = false;
	Action_Hook(client);
	return Plugin_Handled;
}

public Action UnHookCmd(int client, int args)
{
	if(IsPlayerAlive(client))
		Action_UnHook(client);
	return Plugin_Handled;
}

public Action HookToggle(int client, int args)
{
	if(g_Status[client][Hook])
		g_Status[client][Hook] = false;
	else
	{
		g_Backward[client] = false;
		Action_Hook(client);
	}
	return Plugin_Handled;
}
    
public Action GrabCmd(int client, int args)
{
	Action_Grab(client);
	return Plugin_Handled;
}

public Action DropCmd(int client, int args)
{
	if(IsPlayerAlive(client))
		Action_Drop(client);
	return Plugin_Handled;
}

public Action GrabToggle(int client, int args)
{
	if(g_Status[client][Grab])
		g_Status[client][Grab] = false;
	else
		Action_Grab(client);
	return Plugin_Handled;
}

public Action RopeCmd(int client, int args)
{
	Action_Rope(client); 
	return Plugin_Handled;
}

public Action DetachCmd(int client, int args)
{
	if(IsPlayerAlive(client))
		Action_Detach(client);
	return Plugin_Handled;
}

public Action RopeToggle(int client, int args)
{
	if(g_Status[client][Rope])
		g_Status[client][Rope] = false;
	else
		Action_Rope(client);
	return Plugin_Handled;
}

public Action PushCmd(int client, int args)
{
	g_Backward[client] = true;
	Action_Hook(client);
	return Plugin_Handled;
}

public Action UnPushCmd(int client, int args)
{
	if(IsPlayerAlive(client))
	{
		g_Backward[client] = false;
		Action_UnHook(client);
	}
	return Plugin_Handled;
}

public Action PushToggle(int client, int args)
{
	if(g_Status[client][Hook])
	{
		g_Backward[client] = false;
		g_Status[client][Hook] = false;
	}
	else
	{
		g_Backward[client] = true;
		Action_Hook(client);
	}
	return Plugin_Handled;
}

/****************
 *Admin Commands*
*****************/

public Action GiveHook(int client, int args)
{
	if(args > 0)
	{
		char target[64];
		GetCmdArg(1, target, sizeof(target));
		if(Access(target, Give, Hook) == 0)
		{
			int targetindex = FindTarget(client, target);
			if(targetindex > 0)
			{
				ClientAccess(targetindex, Give, Hook);
				ShowActivity2(client, "\x01\x0B\x04[HGR]\x01 ", "%N %t %N", client, "Admin Give", "hook", targetindex);
			}
		}
		else
			ShowActivity2(client, "\x01\x0B\x04[HGR]\x01 ", "%N %t %s", client, "Admin Give", "hook", target);
	}
	else
		ReplyToCommand(client,"\x01\x0B\x04[HGR] Usage:\x01 sm_hgr_givehook <@all/@t/@ct/partial name>");
	return Plugin_Handled;
}

public Action TakeHook(int client, int args)
{
	if(args > 0)
	{
		char target[64];
		GetCmdArg(1, target, sizeof(target));
		if(Access(target, Take, Hook) == 0)
		{
			int targetindex = FindTarget(client, target);
			if(targetindex > 0)
			{
				ClientAccess(targetindex, Take, Hook);
				ShowActivity2(client, "\x01\x0B\x04[HGR]\x01 ", "%N %t %N", client, "Admin Take", "hook", targetindex);
			}
		}
		else
			ShowActivity2(client, "\x01\x0B\x04[HGR]\x01 ", "%N %t %s", client, "Admin Take", "hook", target);
	}
	else
		ReplyToCommand(client,"\x01\x0B\x04[HGR] Usage:\x01 sm_hgr_givehook <@all/@t/@ct/partial name>");
	return Plugin_Handled;
}

public Action GiveGrab(int client, int args)
{
	if(args > 0)
	{
		char target[64];
		GetCmdArg(1, target, sizeof(target));
		if(Access(target, Give, Grab) == 0)
		{
			int targetindex = FindTarget(client, target);
			if(targetindex > 0)
			{
				ClientAccess(targetindex, Give, Grab);
				ShowActivity2(client, "\x01\x0B\x04[HGR]\x01 ", "%N %t %N", client, "Admin Give", "grab", targetindex);
			}
		}
		else
			ShowActivity2(client, "\x01\x0B\x04[HGR]\x01 ", "%N %t %s", client, "Admin Give", "grab", target);
	}
	else
		ReplyToCommand(client,"\x01\x0B\x04[HGR] Usage:\x01 sm_hgr_givehook <@all/@t/@ct/partial name>");
	return Plugin_Handled;
}

public Action TakeGrab(int client, int args)
{
	if(args > 0)
	{
		char target[64];
		GetCmdArg(1, target, sizeof(target));
		if(Access(target, Take, Grab) == 0)
		{
			int targetindex = FindTarget(client, target);
			if(targetindex > 0)
			{
				ClientAccess(targetindex, Take, Grab);
				ShowActivity2(client, "\x01\x0B\x04[HGR]\x01 ", "%N %t %N", client, "Admin Take", "grab", targetindex);
			}
		}
		else
			ShowActivity2(client, "\x01\x0B\x04[HGR]\x01 ", "%N %t %s", client, "Admin Take", "grab", target);
	}
	else
		ReplyToCommand(client,"\x01\x0B\x04[HGR] Usage:\x01 sm_hgr_givehook <@all/@t/@ct/partial name>");
	return Plugin_Handled;
}

public Action GiveRope(int client, int args)
{
	if(args > 0)
	{
		char target[64];
		GetCmdArg(1, target, sizeof(target));
		if(Access(target, Give, Rope) == 0)
		{
			int targetindex = FindTarget(client, target);
			if(targetindex > 0)
			{
				ClientAccess(targetindex, Give, Rope);
				ShowActivity2(client, "\x01\x0B\x04[HGR]\x01 ", "%N %t %N", client, "Admin Give", "rope", targetindex);
			}
		}
		else
			ShowActivity2(client, "\x01\x0B\x04[HGR]\x01 ", "%N %t %s", client, "Admin Give", "rope", target);
	}
	else
		ReplyToCommand(client,"\x01\x0B\x04[HGR] Usage:\x01 sm_hgr_givehook <@all/@t/@ct/partial name>");
	return Plugin_Handled;
}

public Action TakeRope(int client, int args)
{
	if(args > 0)
	{
		char target[64];
		GetCmdArg(1, target, sizeof(target));
		if(Access(target, Take, Rope) == 0)
		{
			int targetindex = FindTarget(client, target);
			if(targetindex > 0)
			{
				ClientAccess(targetindex, Take, Rope);
				ShowActivity2(client, "\x01\x0B\x04[HGR]\x01 ", "%N %t %N", client, "Admin Take", "rope", targetindex);
			}
		}
		else
			ShowActivity2(client, "\x01\x0B\x04[HGR]\x01 ", "%N %t %s", client, "Admin Take", "rope", target);
	}
	else
		ReplyToCommand(client,"\x01\x0B\x04[HGR] Usage:\x01 sm_hgr_givehook <@all/@t/@ct/partial name>");
	return Plugin_Handled;
}

/********
 *Access*
*********/

public int Access(const char[] target, HGRAccess access, HGRAction action)
{
	int clients[MAXPLAYERS];
	int count = FindMatchingPlayers(target, clients);
	if(count == 0)
		return 0;
	for(int x = 0; x < count; x++)
		ClientAccess(clients[x], access, action);
	return count;
}

public int ClientAccess(int client, HGRAccess access, HGRAction action)
{
	if(IsFakeClient(client))
		return 0;
	char actionName[64];
	if(action == Hook)
		actionName = "Hook";
	else if(action == Grab)
		actionName = "Grab";
	else if(action == Rope)
		actionName = "Rope";
	if(access == Give)
	{
		g_AllowedClients[client][action] = true;
		if(IsClientInGame(client))
			PrintToChat(client, "\x01\x0B\x04[HGR]\x01 %t", "Given Access", actionName);
	}
	else
	{
		g_AllowedClients[client][action] = false;
		if(IsClientInGame(client))
			PrintToChat(client, "\x01\x0B\x04[HGR]\x01 %t", "Taken Access", actionName);
	}
	return 1;
}

public bool HasAccess(int client, HGRAction action)
{
	// Hook, Grab, or Rope is disabled
	if(!g_cvarEnable[action])
		return false;
	// If Override Mode is active, client only has access if it has been given to him
	if(g_cvarOverrideMode)
		return g_AllowedClients[client][action];
	// Check for admin flags if selected HGR action is admin only
	if(g_cvarAdminOnly[action])
	{
		char actionName[24];
		if(action == Hook)
			actionName = "+hook";
		else if(action == Grab)
			actionName = "+grab";
		else if(action == Rope)
			actionName = "+rope";
		if(CheckCommandAccess(client, actionName, ADMFLAG_GENERIC, true))
			return true;
		// If user does not have proper admin access, check if admin
		// has specially allowed the client to use HGR anyway
		else
			return g_AllowedClients[client][action];
	}
	return true;
}

/*********
 *Convars*
**********/

public void ConvarChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	// General convars
	if(cvar == h_cvarAnnounce)
		g_cvarAnnounce        = GetConVarBool(h_cvarAnnounce);
	else if(cvar == h_cvarSoundAmplify)
		g_cvarSoundAmplify    = GetConVarInt(h_cvarSoundAmplify);
	else if(cvar == h_cvarOverrideMode)
		g_cvarOverrideMode    = GetConVarBool(h_cvarOverrideMode);
	else if(cvar == h_cvarRopeOldMode)
		g_cvarRopeOldMode     = GetConVarBool(h_cvarRopeOldMode);
	else if(cvar == h_cvarUpButton)
		g_cvarUpButton        = GetButtonBitString(newVal, 1 << 1);
	else if(cvar == h_cvarDownButton)
		g_cvarDownButton      = GetButtonBitString(newVal, 1 << 2);

	// Hook convars
	else if(cvar == h_cvarHookEnable)
		g_cvarEnable[Hook]    = GetConVarBool(h_cvarHookEnable);
	else if(cvar == h_cvarHookAdminOnly)
		g_cvarAdminOnly[Hook] = GetConVarBool(h_cvarHookAdminOnly);
	else if(cvar == h_cvarHookFreeze)
		g_cvarFreeze[Hook]    = GetConVarBool(h_cvarHookFreeze);
	else if(cvar == h_cvarHookSlide)
		g_cvarSlide[Hook]     = GetConVarBool(h_cvarHookSlide);
	else if(cvar == h_cvarHookSpeed)
		g_cvarSpeed[0]        = GetConVarFloat(h_cvarHookSpeed);
	else if(cvar == h_cvarHookInitWidth)
		g_cvarInitWidth[0]    = GetConVarFloat(h_cvarHookInitWidth);
	else if(cvar == h_cvarHookEndWidth)
		g_cvarEndWidth[0]     = GetConVarFloat(h_cvarHookEndWidth);
	else if(cvar == h_cvarHookAmplitude)
		g_cvarAmplitude[0]    = GetConVarFloat(h_cvarHookAmplitude);
	else if(cvar == h_cvarHookBeamColor)
		g_cvarBeamColor[Hook] = GetConVarInt(h_cvarHookBeamColor);
	else if(cvar == h_cvarHookRed)
		g_cvarBeamRed[Hook]   = GetConVarInt(h_cvarHookRed);
	else if(cvar == h_cvarHookGreen)
		g_cvarBeamGreen[Hook] = GetConVarInt(h_cvarHookGreen);
	else if(cvar == h_cvarHookBlue)
		g_cvarBeamBlue[Hook]  = GetConVarInt(h_cvarHookBlue);
	else if(cvar == h_cvarHookAlpha)
		g_cvarBeamAlpha[Hook] = GetConVarInt(h_cvarHookAlpha);
	else if(cvar == h_cvarHookSound)
		GetConVarString(h_cvarHookSound, g_cvarSound[Hook], sizeof(g_cvarSound[]));

	// Grab convars
	else if(cvar == h_cvarGrabEnable)
		g_cvarEnable[Grab]    = GetConVarBool(h_cvarGrabEnable);
	else if(cvar == h_cvarGrabAdminOnly)
		g_cvarAdminOnly[Grab] = GetConVarBool(h_cvarGrabAdminOnly);
	else if(cvar == h_cvarGrabFreeze)
		g_cvarFreeze[Grab]    = GetConVarBool(h_cvarGrabFreeze);
	else if(cvar == h_cvarGrabSlide)
		g_cvarSlide[Grab]     = GetConVarBool(h_cvarGrabSlide);
	else if(cvar == h_cvarGrabSpeed)
		g_cvarSpeed[1]        = GetConVarFloat(h_cvarGrabSpeed);
	else if(cvar == h_cvarGrabInitWidth)
		g_cvarInitWidth[1]    = GetConVarFloat(h_cvarGrabInitWidth);
	else if(cvar == h_cvarGrabEndWidth)
		g_cvarEndWidth[1]     = GetConVarFloat(h_cvarGrabEndWidth);
	else if(cvar == h_cvarGrabAmplitude)
		g_cvarAmplitude[1]    = GetConVarFloat(h_cvarGrabAmplitude);
	else if(cvar == h_cvarGrabBeamColor)
		g_cvarBeamColor[Grab] = GetConVarInt(h_cvarGrabBeamColor);
	else if(cvar == h_cvarGrabRed)
		g_cvarBeamRed[Grab]   = GetConVarInt(h_cvarGrabRed);
	else if(cvar == h_cvarGrabGreen)
		g_cvarBeamGreen[Grab] = GetConVarInt(h_cvarGrabGreen);
	else if(cvar == h_cvarGrabBlue)
		g_cvarBeamBlue[Grab]  = GetConVarInt(h_cvarGrabBlue);
	else if(cvar == h_cvarGrabAlpha)
		g_cvarBeamAlpha[Grab] = GetConVarInt(h_cvarGrabAlpha);
	else if(cvar == h_cvarGrabSound)
		GetConVarString(h_cvarGrabSound, g_cvarSound[Grab], sizeof(g_cvarSound[]));

	// Rope convars
	else if(cvar == h_cvarRopeEnable)
		g_cvarEnable[Rope]    = GetConVarBool(h_cvarRopeEnable);
	else if(cvar == h_cvarRopeAdminOnly)
		g_cvarAdminOnly[Rope] = GetConVarBool(h_cvarRopeAdminOnly);
	else if(cvar == h_cvarRopeFreeze)
		g_cvarFreeze[Rope]    = GetConVarBool(h_cvarRopeFreeze);
	else if(cvar == h_cvarRopeSlide)
		g_cvarSlide[Rope]     = GetConVarBool(h_cvarRopeSlide);
	else if(cvar == h_cvarRopeSpeed)
		g_cvarSpeed[2]        = GetConVarFloat(h_cvarRopeSpeed);
	else if(cvar == h_cvarRopeInitWidth)
		g_cvarInitWidth[2]    = GetConVarFloat(h_cvarRopeInitWidth);
	else if(cvar == h_cvarRopeEndWidth)
		g_cvarEndWidth[2]     = GetConVarFloat(h_cvarRopeEndWidth);
	else if(cvar == h_cvarRopeAmplitude)
		g_cvarAmplitude[2]    = GetConVarFloat(h_cvarRopeAmplitude);
	else if(cvar == h_cvarRopeBeamColor)
		g_cvarBeamColor[Rope] = GetConVarInt(h_cvarRopeBeamColor);
	else if(cvar == h_cvarRopeRed)
		g_cvarBeamRed[Rope]   = GetConVarInt(h_cvarRopeRed);
	else if(cvar == h_cvarRopeGreen)
		g_cvarBeamGreen[Rope] = GetConVarInt(h_cvarRopeGreen);
	else if(cvar == h_cvarRopeBlue)
		g_cvarBeamBlue[Rope]  = GetConVarInt(h_cvarRopeBlue);
	else if(cvar == h_cvarRopeAlpha)
		g_cvarBeamAlpha[Rope] = GetConVarInt(h_cvarRopeAlpha);
	else if(cvar == h_cvarRopeSound)
		GetConVarString(h_cvarRopeSound, g_cvarSound[Rope], sizeof(g_cvarSound[]));
}

public void UpdateAllConvars()
{
	// General convars
	g_cvarAnnounce        = GetConVarBool(h_cvarAnnounce);
	g_cvarSoundAmplify    = GetConVarInt(h_cvarSoundAmplify);
	g_cvarOverrideMode    = GetConVarBool(h_cvarOverrideMode);
	g_cvarRopeOldMode     = GetConVarBool(h_cvarRopeOldMode);
	char UpButton[24];
	GetConVarString(h_cvarUpButton, UpButton, sizeof(UpButton));
	g_cvarUpButton = GetButtonBitString(UpButton, 1 << 1);
	char DownButton[24];
	GetConVarString(h_cvarDownButton, DownButton, sizeof(DownButton));
	g_cvarDownButton = GetButtonBitString(DownButton, 1 << 2);

	// Hook convars
	g_cvarEnable[Hook]    = GetConVarBool(h_cvarHookEnable);
	g_cvarAdminOnly[Hook] = GetConVarBool(h_cvarHookAdminOnly);
	g_cvarFreeze[Hook]    = GetConVarBool(h_cvarHookFreeze);
	g_cvarSlide[Hook]     = GetConVarBool(h_cvarHookSlide);
	g_cvarSpeed[0]        = GetConVarFloat(h_cvarHookSpeed);
	g_cvarInitWidth[0]    = GetConVarFloat(h_cvarHookInitWidth);
	g_cvarEndWidth[0]     = GetConVarFloat(h_cvarHookEndWidth);
	g_cvarAmplitude[0]    = GetConVarFloat(h_cvarHookAmplitude);
	g_cvarBeamColor[Hook] = GetConVarInt(h_cvarHookBeamColor);
	g_cvarBeamRed[Hook]   = GetConVarInt(h_cvarHookRed);
	g_cvarBeamGreen[Hook] = GetConVarInt(h_cvarHookGreen);
	g_cvarBeamBlue[Hook]  = GetConVarInt(h_cvarHookBlue);
	g_cvarBeamAlpha[Hook] = GetConVarInt(h_cvarHookAlpha);
	GetConVarString(h_cvarHookSound, g_cvarSound[Hook], sizeof(g_cvarSound[]));

	// Grab convars
	g_cvarEnable[Grab]    = GetConVarBool(h_cvarGrabEnable);
	g_cvarAdminOnly[Grab] = GetConVarBool(h_cvarGrabAdminOnly);
	g_cvarFreeze[Grab]    = GetConVarBool(h_cvarGrabFreeze);
	g_cvarSlide[Grab]     = GetConVarBool(h_cvarGrabSlide);
	g_cvarSpeed[1]        = GetConVarFloat(h_cvarGrabSpeed);
	g_cvarInitWidth[1]    = GetConVarFloat(h_cvarGrabInitWidth);
	g_cvarEndWidth[1]     = GetConVarFloat(h_cvarGrabEndWidth);
	g_cvarAmplitude[1]    = GetConVarFloat(h_cvarGrabAmplitude);
	g_cvarBeamColor[Grab] = GetConVarInt(h_cvarGrabBeamColor);
	g_cvarBeamRed[Grab]   = GetConVarInt(h_cvarGrabRed);
	g_cvarBeamGreen[Grab] = GetConVarInt(h_cvarGrabGreen);
	g_cvarBeamBlue[Grab]  = GetConVarInt(h_cvarGrabBlue);
	g_cvarBeamAlpha[Grab] = GetConVarInt(h_cvarGrabAlpha);
	GetConVarString(h_cvarGrabSound, g_cvarSound[Grab], sizeof(g_cvarSound[]));

	// Rope convars
	g_cvarEnable[Rope]    = GetConVarBool(h_cvarRopeEnable);
	g_cvarAdminOnly[Rope] = GetConVarBool(h_cvarRopeAdminOnly);
	g_cvarFreeze[Rope]    = GetConVarBool(h_cvarRopeFreeze);
	g_cvarSlide[Rope]     = GetConVarBool(h_cvarRopeSlide);
	g_cvarSpeed[2]        = GetConVarFloat(h_cvarRopeSpeed);
	g_cvarInitWidth[2]    = GetConVarFloat(h_cvarRopeInitWidth);
	g_cvarEndWidth[2]     = GetConVarFloat(h_cvarRopeEndWidth);
	g_cvarAmplitude[2]    = GetConVarFloat(h_cvarRopeAmplitude);
	g_cvarBeamColor[Rope] = GetConVarInt(h_cvarRopeBeamColor);
	g_cvarBeamRed[Rope]   = GetConVarInt(h_cvarRopeRed);
	g_cvarBeamGreen[Rope] = GetConVarInt(h_cvarRopeGreen);
	g_cvarBeamBlue[Rope]  = GetConVarInt(h_cvarRopeBlue);
	g_cvarBeamAlpha[Rope] = GetConVarInt(h_cvarRopeAlpha);
	GetConVarString(h_cvarRopeSound, g_cvarSound[Rope], sizeof(g_cvarSound[]));
	
	// Freezetime variables
	for(HGRAction i = Hook; i <= Rope; i++)
	{
		if(!g_HookedRoundStart || !g_HookedFreeze)
			g_Frozen[i] = true;
		else
			g_Frozen[i] = g_cvarFreeze[i];
	}
}

public void GetBeamColor(int client, HGRAction action, int color[4])
{
	// Custom beam color
    if(g_cvarBeamColor[action] == 2)
    {
		color[0] = g_cvarBeamRed[action];
		color[1] = g_cvarBeamGreen[action];
		color[2] = g_cvarBeamBlue[action];
		color[3] = g_cvarBeamAlpha[action];
	}
	// Teamcolor beam color
	else if(g_cvarBeamColor[action] == 1)
	{
		if(GetClientTeam(client) == 2)
		{
			color[0]=255;color[1]=0;color[2]=0;color[3]=255;
		}
		else if(GetClientTeam(client) == 3)
		{
			color[0]=0;color[1]=0;color[2]=255;color[3]=255;
		}
	}
	// Reverse teamcolor beam color
	else if(g_cvarBeamColor[action] == 3)
	{
		if(GetClientTeam(client) == 3)
		{
			color[0]=255;color[1]=0;color[2]=0;color[3]=255;
		}
		else if(GetClientTeam(client) == 2)
		{
			color[0]=0;color[1]=0;color[2]=255;color[3]=255;
		}
	}
	// White beam color
	else
	{
		color[0]=255;color[1]=255;color[2]=255;color[3]=255;
	}
}

/******
 *Hook*
*******/

public void Action_Hook(int client)
{
	if(g_cvarEnable[Hook] && g_Frozen[Hook])
	{
		if( client > 0 &&
			client <= MaxClients &&
			IsPlayerAlive(client) &&
			!g_Status[client][Hook] &&
			!g_Status[client][Rope] &&
			!g_Grabbed[client])
		{
			if(HasAccess(client, Hook))
			{
				// Init variables
				float clientloc[3], clientang[3];
				GetClientEyePosition(client, clientloc);
				GetClientEyeAngles(client, clientang);
				
				// Hook traceray
				TR_TraceRayFilter(clientloc, clientang, MASK_SOLID, RayType_Infinite, TraceRayTryToHit); // Create a ray that tells where the player is looking
				TR_GetEndPosition(g_Location[client][0]); // Get the end xyz coordinate of where a player is looking
				g_Targetindex[client][Hook] = TR_GetEntityIndex(); // Set hook end target
				g_Distance[client][0] = GetVectorDistance(clientloc, g_Location[client][0]); // Get hook distance
				
				// Push traceray
				float temp[3];
				GetAngleVectors(clientang, temp, NULL_VECTOR, NULL_VECTOR);
				NegateVector(temp);
				GetVectorAngles(temp, clientang);
				TR_TraceRayFilter(clientloc, clientang, MASK_SOLID, RayType_Infinite, TraceRayTryToHit); // Create a ray in opposite direction where player is looking
				TR_GetEndPosition(g_Location[client][3]); // Get the end xyz coordinate opposite of where a player is looking
				g_Targetindex[client][3] = TR_GetEntityIndex(); // Set push end target
				g_Distance[client][3] = GetVectorDistance(clientloc, g_Location[client][3]); // Get push distance
				
				// Change client status
				g_Gravity[client] = GetEntityGravity(client);
				g_Status[client][Hook] = true; // Tell plugin the player has landed hook
				
				// Call hook forward
				int ret;
				Call_StartForward(FwdClientHook);
				Call_PushCell(client);
				Call_Finish(ret);
				if(ret)
				{
					Action_UnHook(client);
					return;
				}
				
				// Finish hooking
				SetEntityGravity(client, 0.0); // Set gravity to 0 so client floats in a straight line
				EmitSoundFromOrigin(g_cvarSound[Hook], g_Location[client][0]); // Emit sound from where the hook landed
				Hook_Push(client);
				CreateTimer(0.1, Hooking, client, TIMER_REPEAT); // Create hooking loop
			}
			else
				PrintToChat(client,"\x01\x0B\x04[HGR]\x01 %t\x04 hook", "No Permission");
		}
		else if(client > 0 && client <= MaxClients && IsPlayerAlive(client))
			PrintToChat(client,"\x01\x0B\x04[HGR]\x01 %t", "Error");
	}
	else
		PrintToChat(client,"\x01\x0B\x04[HGR] Hook\x01 %t", "Disabled");
}

public void Hook_Push(int client)
{
	// Init variables
	float clientloc[3], velocity[3];
	GetClientEyePosition(client, clientloc); // Get the xyz coordinate of the player
	
	// Calculate velocity vector
	if(!g_Backward[client])
		SubtractVectors(g_Location[client][0], clientloc, velocity);
	else
		SubtractVectors(g_Location[client][3], clientloc, velocity);
	NormalizeVector(velocity, velocity);
	ScaleVector(velocity, g_cvarSpeed[0] * 140.0);
	
	// Create beam effect
	int color[4];
	clientloc[2] -= 18.0;
	GetBeamColor(client, Hook, color);
	BeamEffect(clientloc, g_Location[client][0], 0.2, g_cvarInitWidth[0], g_cvarEndWidth[0], color, g_cvarAmplitude[0], 0);
		
	// Move player
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity); // Push the client
	
	// If client has reached the end of the hook
	g_Distance[client][0] = GetVectorDistance(clientloc, g_Location[client][0]);
	if(g_Distance[client][0] < 40.0 && !g_Backward[client])
	{
		SetEntityMoveType(client, MOVETYPE_NONE); // Freeze client
		SetEntityGravity(client, g_Gravity[client]); // Set gravity to normal
	}
	
	// If client has reached the end of the push
	float pdistance = GetVectorDistance(clientloc, g_Location[client][3]);
	if(pdistance < 40.0 && g_Backward[client])
	{
		SetEntityMoveType(client, MOVETYPE_NONE); // Freeze client
		SetEntityGravity(client, g_Gravity[client]); // Set gravity to normal
	}
}

public Action Hooking(Handle timer, any client)
{
	if( IsClientInGame(client) &&
		IsPlayerAlive(client) &&
		g_Status[client][Hook] &&
		!g_Grabbed[client])
	{
		Hook_Push(client);
		return Plugin_Continue;
	}
	else
	{
		Action_UnHook(client);
		return Plugin_Stop; // Stop the timer
	}
}

public void Action_UnHook(int client)
{
	if( IsClientInGame(client) &&
		IsPlayerAlive(client) &&
		g_Status[client][Hook] )
	{
		g_Status[client][Hook] = false; // Tell plugin the client is not hooking
		g_Targetindex[client][Hook] = -1; // Tell plugin that the hook is not attached to an entity
		SetEntityGravity(client, g_Gravity[client]); // Set gravity to normal
		SetEntityMoveType(client, MOVETYPE_WALK); // Unfreeze client
	}
}

/******
 *Grab*
*******/

public void Action_Grab(int client)
{
	if(g_cvarEnable[Grab] && g_Frozen[Grab])
	{
		if( client > 0 &&
			client <= MaxClients &&
			IsPlayerAlive(client) &&
			!g_Status[client][Grab] &&
			!g_Grabbed[client])
		{
			if(HasAccess(client, Grab))
			{
				g_Status[client][Grab] = true; // Tell plugin the seeker is grabbing a player
				
				// Call grab search forward
				int ret;
				Call_StartForward(FwdClientGrabSearch);
				Call_PushCell(client);
				Call_Finish(ret);
				if(ret)
				{
					g_Status[client][Grab] = false;
					return;
				}
				
				// Start grab search timer
				CreateTimer(0.1, GrabSearch, client, TIMER_REPEAT); // Start a timer that searches for a client to grab
			}
			else
				PrintToChat(client,"\x01\x0B\x04[HGR]\x01 %t\x04 grab.", "No Permission");
		}
		else if(client > 0 && client <= MaxClients && IsPlayerAlive(client))
			PrintToChat(client, "\x01\x0B\x04[HGR]\x01 %t", "Error");
    }
	else
		PrintToChat(client, "\x01\x0B\x04[HGR] Grab\x01 %t", "Disabled");
}

public Action GrabSearch(Handle timer, any client)
{
	PrintCenterText(client, "%t", "Searching"); // Tell client the plugin is searching for a target
	if( client > 0 &&
		IsClientInGame(client) &&
		IsPlayerAlive(client) &&
		g_Status[client][Grab] &&
		!g_Grabbed[client])
	{
		// Init variables
		float clientloc[3], clientang[3];
		GetClientEyePosition(client, clientloc);
		GetClientEyeAngles(client, clientang);
		
		// Grab search traceray
		TR_TraceRayFilter(clientloc, clientang, MASK_ALL, RayType_Infinite, TraceRayGrabEnt); // Create a ray that tells where the player is looking
		g_Targetindex[client][Grab] = TR_GetEntityIndex(); // Set the seekers targetindex to the person he picked up
		
		// Found a player or object
		if(g_Targetindex[client][Grab] > 0 && IsValidEntity(g_Targetindex[client][Grab]))
		{
			// Init variables
			float targetloc[3];
			GetEntityOrigin(g_Targetindex[client][Grab], targetloc); // Find the target's xyz coordinate
			g_Distance[client][1] = GetVectorDistance(targetloc, clientloc); // Tell plugin the distance between the two to maintain
			if( g_Targetindex[client][Grab] > 0 &&
				g_Targetindex[client][Grab] <= MaxClients &&
				IsClientInGame(g_Targetindex[client][Grab]))
			{
				g_MaxSpeed[client] = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
				g_Grabbed[g_Targetindex[client][Grab]] = true; // If target is a player, tell plugin player is being grabbed
				SetEntPropFloat(g_Targetindex[client][Grab], Prop_Send, "m_flMaxspeed", 0.01); // Slow grab target
			}
			
			// Call grab forward
			int ret;
			Call_StartForward(FwdClientGrab);
			Call_PushCell(client);
			Call_Finish(ret);
			if(ret)
			{
				Action_Drop(client);
				return Plugin_Stop;
			}
			
			// Finish grabbing
			EmitSoundFromOrigin(g_cvarSound[Grab], targetloc); // Emit sound from the entity being grabbed
			CreateTimer(0.05, Grabbing, client, TIMER_REPEAT); // Start a repeating timer that will reposition the target in the grabber's crosshairs
			return Plugin_Stop; // Stop the search timer
		}
	}
	else
	{
		Action_Drop(client);
		return Plugin_Stop; // Stop the timer
	}
	return Plugin_Continue;
}

public Action Grabbing(Handle timer, any client)
{
	PrintCenterText(client, "%t", "Found");
	if( IsClientInGame(client) &&
		IsPlayerAlive(client) &&
		g_Status[client][Grab] &&
		!g_Grabbed[client] &&
		IsValidEntity(g_Targetindex[client][Grab]))
	{
		if( g_Targetindex[client][Grab] > MaxClients ||
			g_Targetindex[client][Grab] > 0 &&
			g_Targetindex[client][Grab] <= MaxClients &&
			IsClientInGame(g_Targetindex[client][Grab]) &&
			IsPlayerAlive(g_Targetindex[client][Grab]))
		{
			// Init variables
			float clientloc[3], clientang[3], targetloc[3], velocity[3];
			GetClientEyePosition(client, clientloc);
			GetClientEyeAngles(client, clientang);
			GetEntityOrigin(g_Targetindex[client][Grab], targetloc);

			// Grab traceray
			g_TRIgnore[client] = true;
			TR_TraceRayFilter(clientloc, clientang, MASK_ALL, RayType_Infinite, TraceRayTryToHit); // Find where the player is aiming
			TR_GetEndPosition(velocity); // Get the end position of the trace ray
			g_TRIgnore[client] = false;
			
			// Calculate velocity vector
			SubtractVectors(velocity, clientloc, velocity);
			NormalizeVector(velocity, velocity);
			if(g_Attracting[client][0])
				g_Distance[client][1] += g_cvarSpeed[1] * 10.0;
			else if(g_Attracting[client][1])
			{
				g_Distance[client][1] -= g_cvarSpeed[1] * 10.0;
				if(g_Distance[client][1] <= 30.0)
					g_Distance[client][1] = 30.0;
			}
			ScaleVector(velocity, g_Distance[client][1]);
			AddVectors(velocity, clientloc, velocity);
			SubtractVectors(velocity, targetloc, velocity);
			ScaleVector(velocity, g_cvarSpeed[1] * 3 / 5);
			
			// Move grab target
			TeleportEntity(g_Targetindex[client][Grab], NULL_VECTOR, NULL_VECTOR, velocity);
			
			// Make a beam from grabber to grabbed
			int color[4];
			if(g_Targetindex[client][Grab] <= MaxClients)
				targetloc[2] += 45;
			clientloc[2] -= 5;
			GetBeamColor(client, Grab, color);
			BeamEffect(clientloc, targetloc, 0.2, g_cvarInitWidth[1], g_cvarEndWidth[1], color, g_cvarAmplitude[1], 0);
		}
		else
		{
			Action_Drop(client);
			return Plugin_Stop; // Stop the timer
		}
	}
	else
	{
		Action_Drop(client);
		return Plugin_Stop; // Stop the timer
	}
	return Plugin_Continue;
}

public void Action_Drop(int client)
{
	if( IsClientInGame(client) &&
		IsPlayerAlive(client) &&
		g_Status[client][Grab] )
	{
		g_Status[client][Grab] = false; // Tell plugin the grabber has dropped his target
		if(g_Targetindex[client][Grab] > 0)
		{
			PrintCenterText(client, "%t", "Dropped");
			if( g_Targetindex[client][Grab] > 0 &&
				g_Targetindex[client][Grab] <= MaxClients &&
				IsClientInGame(g_Targetindex[client][Grab]))
			{
				g_Grabbed[g_Targetindex[client][Grab]] = false; // Tell plugin the target is no longer being grabbed
				SetEntPropFloat(g_Targetindex[client][Grab], Prop_Send, "m_flMaxspeed", g_MaxSpeed[client]); // Set speed back to normal
			}
			g_Targetindex[client][Grab] = -1;
		}
		else
			PrintCenterText(client, "%t", "Not Found");
	}
}

/******
 *Rope*
*******/

public void Action_Rope(int client)
{
	if(g_cvarEnable[Rope] && g_Frozen[Rope])
	{
		if( client > 0 &&
			client <= MaxClients &&
			IsPlayerAlive(client) &&
			!g_Status[client][Rope] &&
			!g_Status[client][Hook] &&
			!g_Grabbed[client])
		{
		if(HasAccess(client,Rope))
		{
			// Init variables
			float clientloc[3], clientang[3];
			GetClientEyePosition(client, clientloc); // Get the position of the player's eyes
			GetClientEyeAngles(client, clientang); // Get the angle the player is looking
			
			// Rope traceray
			TR_TraceRayFilter(clientloc, clientang, MASK_ALL, RayType_Infinite, TraceRayTryToHit); // Create a ray that tells where the player is looking
			TR_GetEndPosition(g_Location[client][2]); // Get the end xyz coordinate of where a player is looking
			g_Targetindex[client][Rope] = TR_GetEntityIndex();
			
			// Change client status
			g_Status[client][Rope] = true; // Tell plugin the player is roping
			g_Distance[client][2] = GetVectorDistance(clientloc, g_Location[client][2]);
			
			// Call rope forward
			int ret;
			Call_StartForward(FwdClientRope);
			Call_PushCell(client);
			Call_Finish(ret);
			if(ret)
			{
				Action_Detach(client);
				return;
			}
			
			// Finish roping
			EmitSoundFromOrigin(g_cvarSound[Rope], g_Location[client][2]); // Emit sound from the end of the rope
			CreateTimer(0.1, Roping, client, TIMER_REPEAT); // Create roping loop
		}
		else
			PrintToChat(client,"\x01\x0B\x04[HGR]\x01 %t\x04 rope.", "No Permission");
		}
		else if(client > 0 && client <= MaxClients && IsPlayerAlive(client))
			PrintToChat(client,"\x01\x0B\x04[HGR]\x01 %t", "Error");
	}
	else
		PrintToChat(client,"\x01\x0B\x04[HGR] Rope\x01 %t", "Disabled");
}

public Action Roping(Handle timer, any client)
{
	if( IsClientInGame(client) &&
		g_Status[client][Rope] &&
		IsPlayerAlive(client) &&
		!g_Grabbed[client])
	{
		// Init variables
		float clientloc[3], velocity[3], direction[3], ascension[3], climb = 3.0;
		GetClientEyePosition(client, clientloc);
		SubtractVectors(g_Location[client][2], clientloc, direction);
		if(g_Climbing[client][0])
		{
				climb *= g_cvarSpeed[2];
				g_Distance[client][2] -= climb;
				if(g_Distance[client][2] <= 10.0)
					g_Distance[client][2] = 10.0;
			}
			else if(g_Climbing[client][1])
			{
				climb *= -g_cvarSpeed[2];
				g_Distance[client][2] -= climb;
			}
			else
				climb = 0.0;
		
		// Don't move player if rope is slack
		if(g_cvarRopeOldMode || GetVectorLength(direction) - 5 >= g_Distance[client][2])
		{
			// Calculate velocity vector
			GetVelocity(client, velocity);
			NormalizeVector(direction, direction);
			ascension[0] = direction[0] * climb;
			ascension[1] = direction[1] * climb;
			ascension[2] = direction[2] * climb;
			ScaleVector(direction, g_cvarSpeed[2] * 60.0);
			velocity[0] += direction[0] + ascension[0];
			velocity[1] += direction[1] + ascension[1];
			if(ascension[2] > 0.0)
				velocity[2] += direction[2] + ascension[2]; // Move client up if they are climbing the rope
			if(g_Location[client][2][2] - clientloc[2] >= g_Distance[client][2] && velocity[2] < 0.0)
				velocity[2] *= -1; // Reverse vertical component of velocity if rope is taut
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
		}
		
		// Create beam effect
		int color[4];
		clientloc[2] -= 10;
		GetBeamColor(client, Rope, color);
		BeamEffect(clientloc, g_Location[client][2], 0.2, g_cvarInitWidth[2], g_cvarEndWidth[2], color, g_cvarAmplitude[2], 0);
	}
	else
	{
		Action_Detach(client);
		return Plugin_Stop; // Stop the timer
	}
	return Plugin_Continue;
}

public void Action_Detach(int client)
{
	if( IsClientInGame(client) &&
		IsPlayerAlive(client) &&
		g_Status[client][Rope] )
	{
		g_Status[client][Rope] = false; // Tell plugin the client is not hooking
		g_Targetindex[client][Rope] = -1;
	}
}

/***************
 *Trace Filters*
****************/

public bool TraceRayTryToHit(int entity, int mask)
{
	// Check if the beam hit a player and tell it to keep tracing if it did
	if(entity > 0 && entity <= MaxClients)
		return false;
	return true;
}

public bool TraceRayGrabEnt(int entity, int mask)
{
	// Check if the beam hit an entity other than the grabber, and stop if it does
	if(entity > 0)
	{
		if(entity > MaxClients) 
			return true;
		if(entity <= MaxClients && !g_Status[entity][Grab] && !g_Grabbed[entity] && !g_TRIgnore[entity])
			return true;
	}
	return false;
}

/*********
 *Helpers*
**********/

public void EmitSoundFromOrigin(const char[] sound, const float orig[3])
{
	// Amplify sound
	for(int i = 0; i < g_cvarSoundAmplify; i++)
		EmitSoundToAll(sound, SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, orig, NULL_VECTOR, true, 0.0);
}

public void GetEntityOrigin(int entity, float output[3])
{
	GetEntDataVector(entity, OriginOffset, output);
}

public void GetVelocity(int client, float output[3])
{
	output[0] = GetEntDataFloat(client, GetVelocityOffset_x);
	output[1] = GetEntDataFloat(client, GetVelocityOffset_y);
	output[2] = GetEntDataFloat(client, GetVelocityOffset_z);
}

public void ResetAccess(int client)
{
	g_AllowedClients[client][0] = false;
	g_AllowedClients[client][1] = false;
	g_AllowedClients[client][2] = false;
}

public int FindMatchingPlayers(const char[] matchstr, int[] clients)
{
	int k = 0;
	if(StrEqual(matchstr, "@all", false))
	{
		for(int x = 1; x <= MaxClients; x++)
		{
			if(IsClientInGame(x))
			{
				clients[k] = x;
				k++;
			}
		}
	}
	else if(StrEqual(matchstr, "@t", false))
	{
		for(int x = 1; x <= MaxClients; x++)
		{
			if(IsClientInGame(x) && GetClientTeam(x) == 2)
			{
				clients[k] = x;
				k++;
			}
		}
	}
	else if(StrEqual(matchstr, "@ct", false))
	{
		for(int x = 1; x <= MaxClients; x++)
		{
			if(IsClientInGame(x) && GetClientTeam(x) == 3)
			{
				clients[k] = x;
				k++;
			}
		}
	}
	return k;
}

public int GetButtonBitString(const char[] matchstr, int def)
{
	if(StrEqual(matchstr, "IN_ATTACK"))
		return 1 << 0;
	else if(StrEqual(matchstr, "IN_JUMP"))
		return 1 << 1;
	else if(StrEqual(matchstr, "IN_DUCK"))
		return 1 << 2;
	else if(StrEqual(matchstr, "IN_FORWARD"))
		return 1 << 3;
	else if(StrEqual(matchstr, "IN_BACK"))
		return 1 << 4;
	else if(StrEqual(matchstr, "IN_USE"))
		return 1 << 5;
	else if(StrEqual(matchstr, "IN_CANCEL"))
		return 1 << 6;
	else if(StrEqual(matchstr, "IN_LEFT"))
		return 1 << 7;
	else if(StrEqual(matchstr, "IN_RIGHT"))
		return 1 << 8;
	else if(StrEqual(matchstr, "IN_MOVELEFT"))
		return 1 << 9;
	else if(StrEqual(matchstr, "IN_MOVERIGHT"))
		return 1 << 10;
	else if(StrEqual(matchstr, "IN_ATTACK2"))
		return 1 << 11;
	else if(StrEqual(matchstr, "IN_RUN"))
		return 1 << 12;
	else if(StrEqual(matchstr, "IN_RELOAD"))
		return 1 << 13;
	else if(StrEqual(matchstr, "IN_ALT1"))
		return 1 << 14;
	else if(StrEqual(matchstr, "IN_ALT2"))
		return 1 << 15;
	else if(StrEqual(matchstr, "IN_SCORE"))
		return 1 << 16;
	else if(StrEqual(matchstr, "IN_SPEED"))
		return 1 << 17;
	else if(StrEqual(matchstr, "IN_WALK"))
		return 1 << 18;
	else if(StrEqual(matchstr, "IN_ZOOM"))
		return 1 << 19;
	else if(StrEqual(matchstr, "IN_WEAPON1"))
		return 1 << 20;
	else if(StrEqual(matchstr, "IN_WEAPON2"))
		return 1 << 21;
	else if(StrEqual(matchstr, "IN_BULLRUSH"))
		return 1 << 22;
	else if(StrEqual(matchstr, "IN_GRENADE1"))
		return 1 << 23;
	else if(StrEqual(matchstr, "IN_GRENADE2"))
		return 1 << 24;
	return def;
}

/*********
 *Effects*
**********/

public void BeamEffect(float startvec[3], float endvec[3], float life, float width, float endwidth, const int color[4], float amplitude, int speed)
{
	TE_SetupBeamPoints(startvec, endvec, precache_laser, 0, 0, 66, life, width, endwidth, 0, amplitude, color, speed);
	TE_SendToAll();
}