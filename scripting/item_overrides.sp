#pragma semicolon 1
#include <tf_econ_data>
#include <tf2attributes>
#include <tf2utils>

#pragma newdecls required

#define PLUGIN_VERSION "1.0"
	
public const int iAllowedItems[] = {
	13, 45, 220, 448, 772, 1103, // Scout Primaries
	23, 46, 163, 222, 449, 773, 812, 1121, // Scout Secondaries
	0, 44, 221, 317, 325, 349, 355, 450, 648, // Scout Melees
	
	18, 127, 228, 237, 414, 441, 513, 730, 1104, // Soldier Primaries
	10, 129, 133, 226, 354, 442, 444, // Soldier Secondaries
	6, 128, 416, 447, 775, // Soldier Melees
	
	21, 40, 215, 594,  1178, // Pyro Primaries
	12, 39, 351, 595, 740, 1179, 1180, // Pyro Secondaries
	2, 38, 153, 214, 326, 348, 593, 813, 1181, // Pyro Melees
	
	19, 308, 405, 608, 996, 1151, // Demoman Primaries
	20, 130, 131, 265, 406, 1099, 1150, // Demoman Secondaries
	1, 132, 307, 327, 404, // Demoman Melees
	
	15, 41, 312, 424, 811/*, 850*/, // Heavy Primaries // 850 is the MvM Deflector
	11, 42, 159, 311, 425, 1190, // Heavy Secondaries
	5, 43, 239, 310, 331, 426, 656, // Heavy Melees
	
	9, 141, 527, 588, 997, // Engineer Primaries
	22, 140, 5, // Engineer Secondaries
	7, 142, 155, 329, 589, // Engineer Melees
	
	17, 36, 305, 412, // Medic Primaries
	29, 35, 411, 998, // Medic Secondaries
	8, 37, 173, 304, 413, // Medic Melees
	
	14, 56, 230, 402, 526, 752, 1098, // Sniper Primaries
	16, 57, 58, 231, 642, 751, // Sniper Secondaries
	3, 171, 232, 401, // Sniper Melees
	
	24, 61, 224, 460, 525, // Spy Secondaries
	735, 810, // Spy Sappers
	4, 225, 356, 461, 649, // Spy Melees
	30, 59, 60, // Spy Watches
	
	
	1101, // Multi-class different slots
	154, 357, 415, 1153 // Multi-class Secondaries
};

public Plugin myinfo =
{
	name = "[TF2] Item Overrides",
	author = "PC Gamer & Doclic",
	description = "Modified version of Gimme for shounic's server.",
	version = PLUGIN_VERSION,
	url = "www.sourcemod.com"
}

ConVar g_hPluginEnabled;
ConVar g_hLoadoutEditEnabled;
Handle g_hEquipWearable;
StringMap g_hItemInfoTrie;
bool g_bMedieval;
int g_iLoadouts[MAXPLAYERS + 1][TFClassType + 1][TFWeaponSlot_PDA];

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	g_hPluginEnabled = CreateConVar("sm_item_overrides_enabled", "1", "Enables/disables the Item Overrides plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hLoadoutEditEnabled = CreateConVar("sm_item_overrides_loadout_enabled", "1", "Enables/disables the modification of loadouts", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	
	RegConsoleCmd("sm_loadout", Command_GetLoadout, "Gives you the specified loadout" );
	RegConsoleCmd("sm_lr", Command_LoadoutReset, "Resets your loadout" );
	
	GameData hTF2 = new GameData("sm-tf2.games"); // sourcemod's tf2 gamedata

	if (!hTF2)
	SetFailState("This plugin is designed for a TF2 dedicated server only.");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(hTF2.GetOffset("RemoveWearable") - 1);    // EquipWearable offset is always behind RemoveWearable, subtract its value by 1
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hEquipWearable = EndPrepSDKCall();

	if (!g_hEquipWearable)
	SetFailState("Failed to create call: CBasePlayer::EquipWearable");

	delete hTF2;
	
	if (g_hItemInfoTrie != null)
	{
		delete g_hItemInfoTrie;
	}
	g_hItemInfoTrie = new StringMap();
	char strBuffer[256];
	BuildPath(Path_SM, strBuffer, sizeof(strBuffer), "configs/tf2items.givecustom.txt");
	if (FileExists(strBuffer))
	{
		CustomItemsTrieSetup(g_hItemInfoTrie);
	}
	
	HookEvent("post_inventory_application", OnInventoryApplication);	
}

public void OnMapStart()
{
	if (GameRules_GetProp("m_bPlayingMedieval"))
	{
		g_bMedieval = true;
	}	
}

public void OnInventoryApplication(Handle hEvent, const char[] sName, bool bDontBroadcast) {
	
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	CreateTimer(0.6, GivePermItems, iClient);
}

public Action GivePermItems(Handle hTimer, int iClient)
{
	for (int i = 0; i < TFWeaponSlot_PDA; i++) {
		if (g_iLoadouts[iClient][view_as<int>(TF2_GetPlayerClass(iClient))][i] > 0) {
			RemoveWearableWeapon(iClient, i);
			
			int iItemId = g_iLoadouts[iClient][view_as<int>(TF2_GetPlayerClass(iClient))][i] - 1;
				
			int trieweaponSlot;
			char formatBuffer[32];
			Format(formatBuffer, 32, "%d_%s", iItemId, "slot");
			bool isValidItem = GetTrieValue(g_hItemInfoTrie, formatBuffer, trieweaponSlot);
			if(isValidItem) {
				//PrintToChatAll("valid %i %i", i, iItemId);
				GiveWeaponCustom(iClient, iItemId);
			} else {
				//PrintToChatAll("invalid %i %i", i, iItemId);
				EquipItemByItemIndex(iClient, iItemId);
			}
		}
	}

	
	return Plugin_Handled;	
}

int GetWeaponId(char sWeaponId[32]) {
	
	if (StrEqual(sWeaponId, "x", false) || StrEqual(sWeaponId, "n", false) || StrEqual(sWeaponId, "", false)) return -1;
	
	return StringToInt(sWeaponId);
	
}

stock bool GiveItemToClient(int iClient, int iId, int iSlot = -1) {
	
	TFClassType iClass = TF2_GetPlayerClass(iClient);
	g_iLoadouts[iClient][view_as<int>(iClass)][iSlot] = -1;
	
	if (iId < 0) return true;
	
	char sFormatBuffer[32];
	Format(sFormatBuffer, 32, "%d_%s", iId, "slot");
	int iTrieSlot;
	bool bIsValidItem = g_hItemInfoTrie.GetValue(sFormatBuffer, iTrieSlot);
	
	if (!bIsValidItem) {
		if (!TF2Econ_IsValidItemDefinition(iId)) {
			ReplyToCommand(iClient, "Unknown item index number: %i", iId);
			ReplyToCommand(iClient, "Something fucked up, tell an admin"); 	
		
			return false; 		
		}

		iTrieSlot = TF2Econ_GetItemDefaultLoadoutSlot(iId);
	}
	
	if (iSlot < 0) {
		iSlot = iTrieSlot;
	}
	
	bool bInvalidSlot = false;
	if (iId == 1101) bInvalidSlot = !((iClass == TFClass_Soldier && iSlot == TFWeaponSlot_Secondary) || (iClass == TFClass_DemoMan && iSlot == TFWeaponSlot_Primary)); // The base jumper broke me
	else bInvalidSlot = iTrieSlot != iSlot;
	if (bInvalidSlot) {
			ReplyToCommand(iClient, "Invalid slot: %i", iSlot);
		
			return false;
	}
	
	if (TF2Econ_GetItemLoadoutSlot(iId, TF2_GetPlayerClass(iClient)) < 0) {
		PrintToChat(iClient, "Item %d is blocked!", iId);

		return false; 			
	}

	if (iSlot < TFWeaponSlot_Item1) {
		if (TF2Econ_GetItemLoadoutSlot(iId, TF2_GetPlayerClass(iClient)) < 0) {
			PrintToChat(iClient, "Item %d is an invalid weapon for your current class", iId);
			PrintToChat(iClient, "Something fucked up, tell an admin"); 

			return false; 			
		}
	}

	if (iSlot > TFWeaponSlot_PDA) {
		if (TF2Econ_GetItemLoadoutSlot(iId, TF2_GetPlayerClass(iClient)) < 0) {
			PrintToChat(iClient, "Item %d is an invalid weapon for your current class", iId);
			PrintToChat(iClient, "Something fucked up, tell an admin");

			return false;  			
		}
	}
	
	if (g_bMedieval && iSlot < TFWeaponSlot_Item1) {
		if(iSlot != TFWeaponSlot_Melee) {
			ReplyToCommand(iClient, "You can only use melee weapons in Medieval mode.");
			
			return false;
		}
	}

	if (iSlot < TFWeaponSlot_Item1 && iId > 49999) {
		ReplyToCommand(iClient, "Gimme weapon index number must be under 40000.");

		return false;
	}
	
	g_iLoadouts[iClient][view_as<int>(TF2_GetPlayerClass(iClient))][iSlot] = iId + 1;
	
	return true;
	
}

Action Command_GetLoadout(int iClient, int iArgs) {
	
	if (!g_hPluginEnabled.BoolValue || !g_hLoadoutEditEnabled.BoolValue) {
		ReplyToCommand(iClient, "This command is currently disabled!");
		return Plugin_Handled;
	}
	
	if (iArgs < 1)
	{
		ReplyToCommand(iClient, "Visit tfitem.pages.dev to generate a loadout command");
		ReplyToCommand(iClient, "(also linked in !discord)");
		ReplyToCommand(iClient, "!lr to reset and stop the plugin from managing your weapons");

		return Plugin_Handled;
	}

	char sArg1[32];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	if (StrEqual(sArg1, "reset", false)) {
		for (int i = 0; i < TFWeaponSlot_PDA; i++) {
			g_iLoadouts[iClient][view_as<int>(TF2_GetPlayerClass(iClient))][i] = -1;
		}
	
		ReplyToCommand(iClient, "Reset your loadout!");
		return Plugin_Handled;
	}
	
	int iPrimaryIndex = GetWeaponId(sArg1);

	char sArg2[32];
	GetCmdArg(2, sArg2, sizeof(sArg2));
	int iSecondaryIndex = GetWeaponId(sArg2);	
	
	char sArg3[32];
	GetCmdArg(3, sArg3, sizeof(sArg3));
	int iMeleeIndex = GetWeaponId(sArg3);

	char sArg4[32];
	GetCmdArg(4, sArg4, sizeof(sArg4));
	int iCloakIndex = GetWeaponId(sArg4);
	
	bool bSuccessful = GiveItemToClient(iClient, iPrimaryIndex, TFWeaponSlot_Primary);
	bSuccessful = bSuccessful && GiveItemToClient(iClient, iSecondaryIndex, TFWeaponSlot_Secondary);
	bSuccessful = bSuccessful && GiveItemToClient(iClient, iMeleeIndex, TFWeaponSlot_Melee);
	bSuccessful = bSuccessful && GiveItemToClient(iClient, iCloakIndex, TFWeaponSlot_Grenade);
	if (bSuccessful) {
		ReplyToCommand(iClient, "Gave you your items successfully!");
		ReplyToCommand(iClient, "Touch a resupply cabinet to get them.");
	} else {
		ReplyToCommand(iClient, "An error occured when giving you at least one of your items. Tell an admin!");
	}
	
	return Plugin_Handled;
}

Action Command_LoadoutReset(int iClient, int iArgs) {
	
	if (!g_hPluginEnabled.BoolValue || !g_hLoadoutEditEnabled.BoolValue) {
		ReplyToCommand(iClient, "This command is currently disabled!");
		return Plugin_Handled;
	}
	
	for (int i = 0; i < TFWeaponSlot_PDA; i++) {
		g_iLoadouts[iClient][view_as<int>(TF2_GetPlayerClass(iClient))][i] = -1;
	}
	
	ReplyToCommand(iClient, "Reset your loadout!");
	
	return Plugin_Handled;
}

void EquipItemByItemIndex(int client, int itemindex)
{
	if (!TF2Econ_IsValidItemDefinition(itemindex))
	{
		PrintToChat(client, "Unknown item index number: %i", itemindex);
		PrintToChat(client, "Check !loadout"); 	
		return;
	}

	int itemSlot = TF2Econ_GetItemDefaultLoadoutSlot(itemindex);
	
	if (TF2Econ_GetItemLoadoutSlot(itemindex, TF2_GetPlayerClass(client)) !=-1)
	{
		itemSlot = TF2Econ_GetItemLoadoutSlot(itemindex, TF2_GetPlayerClass(client));
	}	
	
	int itemQuality = 6;

	char itemClassname[64];
	TF2Econ_GetItemClassName(itemindex, itemClassname, sizeof(itemClassname));
	TF2Econ_TranslateWeaponEntForClass(itemClassname, sizeof(itemClassname), TF2_GetPlayerClass(client));
	int itemLevel = 1972/*GetRandomUInt(1, 100)*/;


	if (StrContains(itemClassname, "shotgun", false) != -1)
	{
		TFClassType class = TF2_GetPlayerClass(client);
		if(class == TFClass_Unknown || class == TFClass_Scout || class == TFClass_Sniper || class == TFClass_DemoMan || class == TFClass_Medic || class == TFClass_Spy)
		{
			itemClassname = "tf_weapon_shotgun_primary";
		}
	}
	
	Items_CreateNamedItem(client, itemindex, itemClassname, itemLevel, itemQuality, itemSlot);
	
	return;
}

int Items_CreateNamedItem(int client, int itemindex, const char[] classname, int level, int quality, int weaponSlot)
{
	int newitem = CreateEntityByName(classname);
	
	if (!IsValidEntity(newitem))
	{
		PrintToChat(client, "Item %i : %s is invalid for current class", itemindex, classname);
		return false;
	}

	if (StrEqual(classname, "tf_weapon_invis"))
	{
		weaponSlot = 4;
	}
	
	if (itemindex == 735 || itemindex == 736 || StrEqual(classname, "tf_weapon_sapper"))
	{
		weaponSlot = 1;
	}
	
	if (StrEqual(classname, "tf_weapon_revolver"))
	{
		weaponSlot = 0;
	}	

	if (TF2_GetPlayerClass(client) == TFClass_Engineer && weaponSlot > 2 && weaponSlot < 8)
	{
		return newitem;
	}
	
	if(weaponSlot < 6)
	{
		//PrintToChatAll("slot %i", weaponSlot);
		TF2_RemoveWeaponSlot(client, weaponSlot);		
	}
	
	char entclass[64];

	GetEntityNetClass(newitem, entclass, sizeof(entclass));	
	SetEntData(newitem, FindSendPropInfo(entclass, "m_iItemDefinitionIndex"), itemindex);
	SetEntData(newitem, FindSendPropInfo(entclass, "m_bInitialized"), 1);
	SetEntData(newitem, FindSendPropInfo(entclass, "m_iEntityLevel"), level);
	SetEntData(newitem, FindSendPropInfo(entclass, "m_iEntityQuality"), quality);
	SetEntProp(newitem, Prop_Send, "m_bValidatedAttachedEntity", 1);
	
	SetEntProp(newitem, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
	SetEntPropEnt(newitem, Prop_Send, "m_hOwnerEntity", client);
	
	/*if (level > 0)
	{
		SetEntData(newitem, FindSendPropInfo(entclass, "m_iEntityLevel"), level);
	}
	else
	{
		SetEntData(newitem, FindSendPropInfo(entclass, "m_iEntityLevel"), GetRandomUInt(1,99));
	}*/

	switch (itemindex)
	{
	case 735, 736, 810, 831, 933, 1080, 1102: // Sappers
		{
			SetEntProp(newitem, Prop_Send, "m_iObjectType", 3);
			SetEntProp(newitem, Prop_Data, "m_iSubType", 3);
			SetEntProp(newitem, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
			SetEntProp(newitem, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
			SetEntProp(newitem, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
			SetEntProp(newitem, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
		}
	case 998: // Vaccinator
		{
			SetEntData(newitem, FindSendPropInfo(entclass, "m_nChargeResistType"), GetRandomInt(0,2));
		}
	}
	
	if(weaponSlot < 2)
	{
		TF2Attrib_SetByDefIndex(newitem, 725, 0.0);
	}

	DispatchSpawn(newitem);
	
	if (StrContains(classname, "tf_wearable", false) !=-1)
	{
		RemoveConflictWearables(client, itemindex);

		SDKCall(g_hEquipWearable, client, newitem);
	}
	else
	{
		EquipPlayerWeapon(client, newitem);
	}

	ResetAmmo(client, newitem);
	
	if (g_bMedieval)
	{
		TF2_SwitchtoSlot(client, 2);
	}
	else
	{
		TF2_SwitchtoSlot(client, 2);
		TF2_SwitchtoSlot(client, 0);	
	}

	char itemname[64];
	TF2Econ_GetItemName(itemindex, itemname, sizeof(itemname));
	
	return newitem;
} 

stock void TF2_SwitchtoSlot(int client, int slot)
{
	if (slot >= 0 && slot <= 5 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		char wepclassname[64];
		int wep = GetPlayerWeaponSlot(client, slot);
		if (wep > MaxClients && IsValidEdict(wep) && GetEdictClassname(wep, wepclassname, sizeof(wepclassname)))
		{
			FakeClientCommandEx(client, "use %s", wepclassname);
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", wep);
		}
	}
}

int GetRandomUInt(int min, int max)
{
	return RoundToFloor(GetURandomFloat() * (max - min + 1)) + min;
}

bool IsItemAllowed(const int def)
{
	for(int i = 0; i < sizeof(iAllowedItems); i++)
	{
		if(iAllowedItems[i] == def)
		return false;
	}

	return true;
}

bool RemoveConflictWearables(int client, int newindex)
{
	int wearable = -1;
	while ((wearable = FindEntityByClassname(wearable, "tf_wearable*")) != -1)
	{
		if(GetEntPropEnt(wearable, Prop_Send, "m_hOwnerEntity") == client)
		{
			int oldindex = GetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex");
			
			if(TF2Econ_IsValidItemDefinition(oldindex))
			{
				if(TF2Econ_GetItemEquipRegionMask(oldindex) & TF2Econ_GetItemEquipRegionMask(newindex) > 0) {
					TF2_RemoveWearable (client, wearable);			
				}
			}
		}
	}
	
	return true;
}

stock Action CustomItemsTrieSetup(StringMap trie)
{
	char strBuffer[256], strBuffer2[256], strBuffer3[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, strBuffer, sizeof(strBuffer), "configs/tf2items.givecustom.txt");
	KeyValues kv = new KeyValues("Gimme");
	if(FileToKeyValues(kv, strBuffer) == true)
	{
		kv.GetSectionName(strBuffer, sizeof(strBuffer));
		if (StrEqual("custom_give_weapons_vlolz", strBuffer) == true)
		{
			if (kv.GotoFirstSubKey())
			{
				do
				{
					kv.GetSectionName(strBuffer, sizeof(strBuffer));
					if (strBuffer[0] != '*')
					{
						Format(strBuffer2, 32, "%s_%s", strBuffer, "classname");
						kv.GetString("classname", strBuffer3, sizeof(strBuffer3));
						trie.SetString(strBuffer2, strBuffer3);
						Format(strBuffer2, 32, "%s_%s", strBuffer, "index");
						trie.SetValue(strBuffer2, kv.GetNum("index"));
						Format(strBuffer2, 32, "%s_%s", strBuffer, "slot");
						trie.SetValue(strBuffer2, kv.GetNum("slot"));
						Format(strBuffer2, 32, "%s_%s", strBuffer, "quality");
						trie.SetValue(strBuffer2, kv.GetNum("quality"));
						Format(strBuffer2, 32, "%s_%s", strBuffer, "level");
						trie.SetValue(strBuffer2, kv.GetNum("level"));
						Format(strBuffer2, 256, "%s_%s", strBuffer, "attribs");
						kv.GetString("attribs", strBuffer3, sizeof(strBuffer3));
						trie.SetString(strBuffer2, strBuffer3);
						Format(strBuffer2, 32, "%s_%s", strBuffer, "ammo");
						trie.SetValue(strBuffer2, kv.GetNum("ammo", -1));
					}
				}
				while (kv.GotoNextKey());
				kv.GoBack();
			}
		}
	}
	delete kv;
	
	return Plugin_Handled;	
}

public int GiveWeaponCustom(int client, int configindex)
{
	int index;
	int slot;
	int quality;
	int level;
	int ammo;
	char weaponClass[64];
	char attribs[256];
	char formatBuffer[64];
	
	Format(formatBuffer, 32, "%d_%s", configindex, "classname");
	g_hItemInfoTrie.GetString(formatBuffer, weaponClass, sizeof(weaponClass));
	Format(formatBuffer, 32, "%d_%s", configindex, "index");
	g_hItemInfoTrie.GetValue(formatBuffer, index);
	Format(formatBuffer, 32, "%d_%s", configindex, "slot");
	g_hItemInfoTrie.GetValue(formatBuffer, slot);
	Format(formatBuffer, 32, "%d_%s", configindex, "quality");
	g_hItemInfoTrie.GetValue(formatBuffer, quality);	
	Format(formatBuffer, 32, "%d_%s", configindex, "level");
	g_hItemInfoTrie.GetValue(formatBuffer, level);	
	Format(formatBuffer, 32, "%d_%s", configindex, "ammo");
	g_hItemInfoTrie.GetValue(formatBuffer, ammo);
	Format(formatBuffer, 32, "%d_%s", configindex, "attribs");
	g_hItemInfoTrie.GetString(formatBuffer, attribs, sizeof(attribs));
	char weaponAttribsArray[32][32];
	int attribCount = ExplodeString(attribs, " ; ", weaponAttribsArray, 32, 32);

	if(StrEqual(weaponClass, "tf_weapon_shotgun"))
	{
		TFClassType class = TF2_GetPlayerClass(client);
		if(class == TFClass_Unknown || class == TFClass_Scout || class == TFClass_Sniper || class == TFClass_DemoMan || class == TFClass_Medic || class == TFClass_Spy)
		{
			strcopy(weaponClass, 64, "tf_weapon_shotgun_primary");
		}
		else if(class == TFClass_Soldier) strcopy(weaponClass, 64, "tf_weapon_shotgun_soldier");
		else if(class == TFClass_Heavy) strcopy(weaponClass, 64, "tf_weapon_shotgun_hwg");
		else if(class == TFClass_Pyro) strcopy(weaponClass, 64, "tf_weapon_shotgun_pyro");
		else if(class == TFClass_Engineer) strcopy(weaponClass, 64, "tf_weapon_shotgun_primary");
	}
	if(StrEqual(weaponClass, "saxxy"))
	{
		TFClassType class = TF2_GetPlayerClass(client);
		switch(class)
		{
		case TFClass_Scout: strcopy(weaponClass, sizeof(weaponClass), "tf_weapon_bat");
		case TFClass_Sniper: strcopy(weaponClass, sizeof(weaponClass), "tf_weapon_club");
		case TFClass_Soldier: strcopy(weaponClass, sizeof(weaponClass), "tf_weapon_shovel");
		case TFClass_DemoMan: strcopy(weaponClass, sizeof(weaponClass), "tf_weapon_bottle");
		case TFClass_Engineer: strcopy(weaponClass, sizeof(weaponClass), "tf_weapon_wrench");
		case TFClass_Pyro: strcopy(weaponClass, sizeof(weaponClass), "tf_weapon_fireaxe");
		case TFClass_Heavy: strcopy(weaponClass, sizeof(weaponClass), "tf_weapon_fireaxe");
		case TFClass_Spy: strcopy(weaponClass, sizeof(weaponClass), "tf_weapon_knife");
		case TFClass_Medic: strcopy(weaponClass, sizeof(weaponClass), "tf_weapon_bonesaw");
		}
	}

	int newitem = CreateEntityByName(weaponClass);	
	
	if (!IsValidEntity(newitem))
	{
		return false;
	}

	if (StrEqual(weaponClass, "tf_weapon_invis"))
	{
		slot = 4;
	}
	
	if (index == 735 || index == 736 || StrEqual(weaponClass, "tf_weapon_sapper"))
	{
		slot = 1;
	}
	
	if (StrEqual(weaponClass, "tf_weapon_revolver"))
	{
		slot = 0;
	}	

	if(slot < 6)
	{
		TF2_RemoveWeaponSlot(client, slot);		
	}	
	
	char entclass[64];

	GetEntityNetClass(newitem, entclass, sizeof(entclass));	
	SetEntData(newitem, FindSendPropInfo(entclass, "m_iItemDefinitionIndex"), index);
	SetEntData(newitem, FindSendPropInfo(entclass, "m_bInitialized"), 1);
	SetEntData(newitem, FindSendPropInfo(entclass, "m_iEntityLevel"), level);
	SetEntProp(newitem, Prop_Send, "m_bValidatedAttachedEntity", 1);
	
	if (level > 0)
	{
		SetEntData(newitem, FindSendPropInfo(entclass, "m_iEntityLevel"), level);
	}
	else
	{
		level = GetRandomUInt(1,99);
		SetEntData(newitem, FindSendPropInfo(entclass, "m_iEntityLevel"), level);
	}

	if (quality > 0)
	{
		SetEntData(newitem, FindSendPropInfo(entclass, "m_iEntityQuality"), quality);
	}
	else
	{
		SetEntData(newitem, FindSendPropInfo(entclass, "m_iEntityQuality"), 6);
	}	

	if (index == 735 || index == 736 || StrEqual(weaponClass, "tf_weapon_sapper"))
	{
		SetEntProp(newitem, Prop_Send, "m_iObjectType", 3);
		SetEntProp(newitem, Prop_Data, "m_iSubType", 3);
		SetEntProp(newitem, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
		SetEntProp(newitem, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
		SetEntProp(newitem, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
		SetEntProp(newitem, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
	}
	
	DispatchSpawn(newitem);

	if (attribCount > 1) 
	{
		int attrIdx;
		float attrVal;
		int i2 = 0;
		for (int i = 0; i < attribCount; i+=2) {
			attrIdx = StringToInt(weaponAttribsArray[i]);
			if (attrIdx <= 0)
			{
				LogError("Tried to set attribute index to %d on item index %d, attrib string was '%s', count was %d", attrIdx, index, attribs, attribCount);
				continue;
			}
			switch (attrIdx)
			{
			case 133, 143, 147, 152, 184, 185, 186, 192, 193, 194, 198, 211, 214, 227, 228, 229, 262, 294, 302, 372, 373, 374, 379, 381, 383, 403, 420:
				{
					attrVal = float(StringToInt(weaponAttribsArray[i+1]));
				}
			case 134:
				{
					attrVal = StringToFloat(weaponAttribsArray[i+1]);

					if (attrVal > 900)
					{
						SetEntData(newitem, FindSendPropInfo(entclass, "m_iEntityQuality"), 5);
						attrVal = (GetRandomInt(1,223) + 0.0);
					}
				}
			default:
				{
					attrVal = StringToFloat(weaponAttribsArray[i+1]);
				}
			}
			TF2Attrib_SetByDefIndex(newitem, attrIdx, attrVal);
			i2++;
		}
	}

	if (StrContains(weaponClass, "tf_wearable", false) !=-1)
	{
		RemoveConflictWearables(client, index);

		SDKCall(g_hEquipWearable, client, newitem);
	}	
	else
	{
		EquipPlayerWeapon(client, newitem);
	}
	
	ResetAmmo(client, newitem);
	
	char itemname[64];
	TF2Econ_GetItemName(index, itemname, sizeof(itemname));
	PrintToChat(client, "%N received custom item %i (%s)", client, index, itemname);
	
	return newitem;
}

stock void ResetAmmo(int iClient, int iWeapon) {
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType != -1) {
		SetEntProp(iWeapon, Prop_Send, "m_iClip1", TF2Util_GetWeaponMaxClip(iWeapon));
		SetEntProp(iClient, Prop_Send, "m_iAmmo", 0, _, iAmmoType);
		GivePlayerAmmo(iClient, 9999, iAmmoType, true);
	}
}

stock Action RemoveWearable(int client, char[] classname, char[] networkclass)
{
	if (IsPlayerAlive(client))
	{
		int edict = -1;
		while((edict = FindEntityByClassname(edict, classname)) != -1)
		{
			char netclass[32];
			if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && StrEqual(netclass, networkclass))
			{
				if (GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client)
				{
					AcceptEntityInput(edict, "Kill"); 
				}
			}
		}
	}
	
	return Plugin_Handled;	
}

public Action RemoveWearableWeapon(int iClient, int iSlot) {
	if (IsPlayerAlive(iClient)) {
		int iEntity = TF2Util_GetPlayerLoadoutEntity(iClient, iSlot);
		if (TF2Util_IsEntityWearable(iEntity)) TF2_RemoveWearable(iClient, iEntity);
	}
	
	return Plugin_Handled;	
}

/*stock void RemoveAllWearableWeapons(int iClient) {
	for (int iSlot = 0; iSlot <= TFWeaponSlot_Melee; iSlot++) {
		RemoveWearableWeapon(iClient, iSlot);
	}
}*/

float TF2_GetRuntimeAttribValue(int entity, int attribute) 
{
	if (!IsValidEntity(entity))
	{
		return 0.0;
	}

	int iAttribIndices[16];
	float flAttribValues[16];
	
	int nAttribs = TF2Attrib_GetSOCAttribs(entity, iAttribIndices, flAttribValues);
	
	for (int i = 0; i < nAttribs; i++) 
	{
		if (iAttribIndices[i] == attribute) 
		{
			return flAttribValues[i];
		}
	}

	return 0.00;
}
