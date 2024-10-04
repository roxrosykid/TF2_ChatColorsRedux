#include <sourcemod>
#include <clientprefs>
#include <basecomm>
#include <sdktools>
#include <sdkhooks>
#include <string>

#pragma semicolon 1
#pragma newdecls required

#define NAME   0
#define TEXT   1
#define PREFIX 2

// Define the cookie handles
Handle g_hNameColorEnabled;
Handle g_hNameColor1;
Handle g_hNameColor2;

Handle g_hTextColorEnabled;
Handle g_hTextColor;

Handle g_hPrefixEnabled;
Handle g_hPrefixText;
Handle g_hPrefixColor1;
Handle g_hPrefixColor2;

// Color Picker Variables
#define MAX_PLAYERS	  65
#define MAX_WORLDTEXT 7
#define BUTTON_DELAY  0.5	 // 0.5 seconds delay
#define INPUT_DELAY	  0.02

enum struct PlayerData
{
	int	  hue;
	int	  saturation;
	int	  brightness;
	int	  worldTexts[MAX_WORLDTEXT];
	bool  inGUI;
	int	  selectedInput;		  // New variable to track the selected input
	float lastButtonPressTime;	  // New variable to track the last time a button was pressed
	float lastInputChangeTime;	  // New variable to track the last time an input was changed
}

PlayerData g_PlayerData[MAX_PLAYERS];
char	   g_InputToSave[MAX_PLAYERS][64];
char	   g_HexColor[MAX_PLAYERS][8];	  // Global variable to store the HEX color code
public Plugin myinfo =
{
	name		= "[TF2] Chat Colors Redux",
	author		= "roxrosykid",
	description = "Change players' nickname colors in chat.",
	version		= "1.0.0",
	url			= "https://github.com/roxrosykid"
};

public void OnPluginStart()
{
	// Initialize the cookies
	g_hNameColorEnabled = RegClientCookie("name_enabled", "", CookieAccess_Public);
	g_hNameColor1		= RegClientCookie("name_color1", "", CookieAccess_Public);
	g_hNameColor2		= RegClientCookie("name_color2", "", CookieAccess_Public);

	g_hTextColorEnabled = RegClientCookie("text_enabled", "", CookieAccess_Public);
	g_hTextColor		= RegClientCookie("text_color", "", CookieAccess_Public);

	g_hPrefixEnabled	= RegClientCookie("prefix_enabled", "", CookieAccess_Public);
	g_hPrefixText		= RegClientCookie("prefix_text", "", CookieAccess_Public);
	g_hPrefixColor1		= RegClientCookie("prefix_color1", "", CookieAccess_Public);
	g_hPrefixColor2		= RegClientCookie("prefix_color2", "", CookieAccess_Public);

	// Register commands
	RegConsoleCmd("sm_customchat", Command_CustomChatMenu, "Open the custom chat menu");
	RegConsoleCmd("sm_setcolor", Command_SetColor, "Set a color");
	RegConsoleCmd("sm_guicolor", Command_GUIColor, "Open the GUI color picker");
	RegConsoleCmd("sm_setprefix", Command_SetPrefix, "Set prefix");

	DeleteEntitiesWithTargetname("guicolor_entity");
}

public Action Command_CustomChatMenu(int client, int args)
{
	Menu menu = new Menu(MenuHandler_CustomChat);
	menu.SetTitle("Custom Chat Settings");

	char szNameEnabled[8];
	GetClientCookie(client, g_hNameColorEnabled, szNameEnabled, sizeof(szNameEnabled));
	bool bNameEnabled = szNameEnabled[0] == '1';

	char szTextEnabled[8];
	GetClientCookie(client, g_hTextColorEnabled, szTextEnabled, sizeof(szTextEnabled));
	bool bTextEnabled = szTextEnabled[0] == '1';

	char szPrefixEnabled[8];
	GetClientCookie(client, g_hPrefixEnabled, szPrefixEnabled, sizeof(szPrefixEnabled));
	bool bPrefixEnabled = szPrefixEnabled[0] == '1';

	menu.AddItem("name", bNameEnabled ? "Disable Name Color" : "Enable Name Color");
	menu.AddItem("text", bTextEnabled ? "Disable Text Color" : "Enable Text Color");
	menu.AddItem("prefix", bPrefixEnabled ? "Disable Prefix" : "Enable Prefix");
	menu.AddItem("guicolor", "Open Color Picker");
	menu.AddItem("setprefix", "Set Custom Prefix");

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int MenuHandler_CustomChat(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));

		if (StrEqual(info, "name"))
		{
			char szNameEnabled[8];
			GetClientCookie(param1, g_hNameColorEnabled, szNameEnabled, sizeof(szNameEnabled));
			bool bNameEnabled = szNameEnabled[0] == '1';
			SetClientCookie(param1, g_hNameColorEnabled, bNameEnabled ? "0" : "1");
			PrintToChat(param1, "Name color %s", bNameEnabled ? "disabled" : "enabled");
		}
		else if (StrEqual(info, "text"))
		{
			char szTextEnabled[8];
			GetClientCookie(param1, g_hTextColorEnabled, szTextEnabled, sizeof(szTextEnabled));
			bool bTextEnabled = szTextEnabled[0] == '1';
			SetClientCookie(param1, g_hTextColorEnabled, bTextEnabled ? "0" : "1");
			PrintToChat(param1, "Text color %s", bTextEnabled ? "disabled" : "enabled");
		}
		else if (StrEqual(info, "prefix"))
		{
			char szPrefixEnabled[8];
			GetClientCookie(param1, g_hPrefixEnabled, szPrefixEnabled, sizeof(szPrefixEnabled));
			bool bPrefixEnabled = szPrefixEnabled[0] == '1';
			SetClientCookie(param1, g_hPrefixEnabled, bPrefixEnabled ? "0" : "1");
			PrintToChat(param1, "Prefix %s", bPrefixEnabled ? "disabled" : "enabled");
		}
		else if (StrEqual(info, "guicolor"))
		{
			Command_GUIColor(param1, 0);
		}
		else if (StrEqual(info, "setprefix")) {
			ReplyToCommand(param1, "Type !setprefix <prefix> in chat.");
		}

		// Reopen the menu
		if (!StrEqual(info, "guicolor"))
		{
			Command_CustomChatMenu(param1, 0);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 1;
}

public void OnClientCookiesCached(int client)
{
	// Check if the cookies are set, if not, set default values
	char szStartColor[12];
	char szEndColor[12];
	char szEnabled[8];
	char szText[256];

	// Name Color Cookies
	GetClientCookie(client, g_hNameColor1, szStartColor, sizeof(szStartColor));
	GetClientCookie(client, g_hNameColor2, szEndColor, sizeof(szEndColor));
	GetClientCookie(client, g_hNameColorEnabled, szEnabled, sizeof(szEnabled));

	if (szStartColor[0] == '\0')
	{
		SetClientCookie(client, g_hNameColor1, "FFFFFF");	 // Default start color: White
	}

	if (szEndColor[0] == '\0')
	{
		SetClientCookie(client, g_hNameColor2, "FFFFFF");	 // Default end color: White
	}

	if (szEnabled[0] == '\0')
	{
		SetClientCookie(client, g_hNameColorEnabled, "0");	  // Default enabled: false
	}

	// Text Color Cookies
	GetClientCookie(client, g_hTextColor, szStartColor, sizeof(szStartColor));
	GetClientCookie(client, g_hTextColorEnabled, szEnabled, sizeof(szEnabled));

	if (szStartColor[0] == '\0')
	{
		SetClientCookie(client, g_hTextColor, "FFFFFF");	// Default start color: White
	}

	if (szEnabled[0] == '\0')
	{
		SetClientCookie(client, g_hTextColorEnabled, "0");	  // Default enabled: false
	}

	// Prefix Cookies
	GetClientCookie(client, g_hPrefixText, szText, sizeof(szText));
	GetClientCookie(client, g_hPrefixColor1, szStartColor, sizeof(szStartColor));
	GetClientCookie(client, g_hPrefixColor2, szEndColor, sizeof(szEndColor));
	GetClientCookie(client, g_hPrefixEnabled, szEnabled, sizeof(szEnabled));

	if (szText[0] == '\0')
	{
		SetClientCookie(client, g_hPrefixText, "");
	}
	if (szStartColor[0] == '\0')
	{
		SetClientCookie(client, g_hPrefixColor1, "FFFFFF");	   // Default start color: White
	}

	if (szEndColor[0] == '\0')
	{
		SetClientCookie(client, g_hPrefixColor2, "FFFFFF");	   // Default end color: White
	}

	if (szEnabled[0] == '\0')
	{
		SetClientCookie(client, g_hPrefixEnabled, "0");	   // Default enabled: false
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	char formattedMessage[512];
	// Get the player's name
	char szName[MAX_NAME_LENGTH];
	GetClientName(client, szName, sizeof(szName));

	char szText[256];
	strcopy(szText, sizeof(szText), sArgs);
	TrimString(szText);
	StripQuotes(szText);

	if (BaseComm_IsClientGagged(client) || strlen(szText) == 0) return Plugin_Handled;

	// Get the player's start and end colors from cookies
	char szNameColor1[12];
	char szNameColor2[12];
	char szTextColor[12];
	char szPrefixText[256];
	char szPrefixColor1[12];
	char szPrefixColor2[12];

	GetClientCookie(client, g_hNameColor1, szNameColor1, sizeof(szNameColor1));
	GetClientCookie(client, g_hNameColor2, szNameColor2, sizeof(szNameColor2));
	GetClientCookie(client, g_hTextColor, szTextColor, sizeof(szTextColor));
	GetClientCookie(client, g_hPrefixText, szPrefixText, sizeof(szPrefixText));
	GetClientCookie(client, g_hPrefixColor1, szPrefixColor1, sizeof(szPrefixColor1));
	GetClientCookie(client, g_hPrefixColor2, szPrefixColor2, sizeof(szPrefixColor2));

	// Check if name color is enabled
	char szNameEnabled[8];
	GetClientCookie(client, g_hNameColorEnabled, szNameEnabled, sizeof(szNameEnabled));
	bool bNameEnabled = szNameEnabled[0] == '1';

	// Check if text color is enabled
	char szTextEnabled[8];
	GetClientCookie(client, g_hTextColorEnabled, szTextEnabled, sizeof(szTextEnabled));
	bool bTextEnabled = szTextEnabled[0] == '1';

	// Check if prefix is enabled
	char szPrefixEnabled[8];
	GetClientCookie(client, g_hPrefixEnabled, szPrefixEnabled, sizeof(szPrefixEnabled));
	bool bPrefixEnabled = szPrefixEnabled[0] == '1';

	// Create the gradient name
	// Each character can be up to 7 characters long (e.g. "\x07FF0000")
	char szGradientName[MAX_NAME_LENGTH * 7];
	if (bNameEnabled)
	{
		CreateGradientString(szName, szNameColor1, szNameColor2, szGradientName, sizeof(szGradientName));
	}
	else {
		Format(szGradientName, sizeof(szGradientName), "\x03%s", szName);
	}

	// Create the gradient prefix
	char szGradientPrefix[256];
	szGradientPrefix = "\0";
	if (bPrefixEnabled && strlen(szPrefixText) > 0)
	{
		CreateGradientString(szPrefixText, szPrefixColor1, szPrefixColor2, szGradientPrefix, sizeof(szGradientPrefix));
		Format(szGradientPrefix, sizeof(szGradientPrefix), "%s ", szGradientPrefix);
	}

	char szColoredText[256];
	Format(szColoredText, sizeof(szColoredText), "\x01%s", szText);
	if (bTextEnabled)
	{
		Format(szColoredText, sizeof(szColoredText), "\x07%s%s", szTextColor, szText);
	}

	Format(formattedMessage, sizeof(formattedMessage), "%s%s\x01: %s", szGradientPrefix, szGradientName, szColoredText);

	int iTeam;
	iTeam = GetClientTeam(client);

	if (!StrEqual(command, "say"))
	{
		Format(formattedMessage, sizeof(formattedMessage), "\x01(TEAM) %s", formattedMessage);
	}

	Format(formattedMessage, 252, "%s", formattedMessage);

	// Send the chat message with the formatted message
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && (StrEqual(command, "say") ? true : iTeam == GetClientTeam(i)))
		{
			Handle h = StartMessageOne("SayText2", i);
			if (h != null)
			{
				BfWriteByte(h, client);				   // The client index (who sent the message)
				BfWriteByte(h, true);				   // Chat message flag
				BfWriteString(h, formattedMessage);	   // The formatted message
				EndMessage();
			}
		}
	}

	return Plugin_Handled;
}

public Action Command_SetPrefix(int client, int args)
{
	if (client > 0)
	{
		char sPrefix[32];
		GetCmdArgString(sPrefix, sizeof(sPrefix));
		SetClientCookie(client, g_hPrefixText, sPrefix);
		ReplyToCommand(client, "Prefix set: %s", sPrefix);
	}
	return Plugin_Handled;
}

void CreateGradientString(const char[] szString, const char[] szStartColor, const char[] szEndColor, char[] szGradientString, int maxlen)
{
	int len		  = CountUTF8Characters(szString);	  // Get the length of the string in characters
	int byteIndex = 0;								  // To track the current byte index
	int startColor[3];
	int endColor[3];

	// Parse the start and end colors
	HexToRGB(szStartColor, startColor);
	HexToRGB(szEndColor, endColor);

	// Determine the jump size based on the string length
	int jumpSize = 1;
	if (len > 16) jumpSize = 4;
	else if (len > 8) jumpSize = 2;

	// Temporary buffer to hold the current character
	char currentChar[5];

	// Calculate the gradient for every nth character
	for (int charCount = 0; charCount < len; charCount++)
	{
		int charBytes = GetCharBytesAt(szString, byteIndex);
		if (charBytes == 0) break;	  // Invalid UTF-8 sequence

		// Copy the current character to the buffer
		strcopy(currentChar, charBytes + 1, szString[byteIndex]);

		// Only apply gradient to every nth character
		if (charCount % jumpSize == 0)
		{
			float t = float(charCount) / float(len - 1);
			int	  r = RoundToFloor(startColor[0] + t * (endColor[0] - startColor[0]));
			int	  g = RoundToFloor(startColor[1] + t * (endColor[1] - startColor[1]));
			int	  b = RoundToFloor(startColor[2] + t * (endColor[2] - startColor[2]));

			char  szColor[12];

			Format(szColor, sizeof(szColor), "\x07%02X%02X%02X%s", r, g, b, currentChar);
			Format(szGradientString, maxlen, "%s%s", szGradientString, szColor);
		}
		else
		{
			// Append the character without color
			Format(szGradientString, maxlen, "%s%s", szGradientString, currentChar);
		}

		byteIndex += charBytes;
	}
}

// Helper function to count the number of characters in a UTF-8 string
int CountUTF8Characters(const char[] szString)
{
	int len		  = strlen(szString);
	int charCount = 0;
	int byteIndex = 0;

	while (byteIndex < len)
	{
		int charBytes = GetCharBytesAt(szString, byteIndex);
		if (charBytes == 0) break;	  // Invalid UTF-8 sequence
		byteIndex += charBytes;
		charCount++;
	}

	return charCount;
}

// Helper function to get the number of bytes for the character at a specific byte index in a UTF-8 string
int GetCharBytesAt(const char[] szString, int byteIndex)
{
	int c = szString[byteIndex];
	if (c == 0) return 0;
	if (c < 0x80) return 1;
	if (c < 0xE0) return 2;
	if (c < 0xF0) return 3;
	return 4;
}

void HexToRGB(const char[] hex, int[] rgb)
{
	char szHex[3];
	szHex[0] = hex[0];
	szHex[1] = hex[1];
	szHex[2] = '\0';
	rgb[0]	 = StringToInt(szHex, 16);

	szHex[0] = hex[2];
	szHex[1] = hex[3];
	rgb[1]	 = StringToInt(szHex, 16);

	szHex[0] = hex[4];
	szHex[1] = hex[5];
	rgb[2]	 = StringToInt(szHex, 16);
}

public Action Command_SetColor(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "Usage: sm_setcolor <type> <color> [color2]");
		return Plugin_Handled;
	}

	char szType[32];
	char szColor[12];
	char szColor2[12];
	GetCmdArg(1, szType, sizeof(szType));
	GetCmdArg(2, szColor, sizeof(szColor));
	if (args > 2)
	{
		GetCmdArg(3, szColor2, sizeof(szColor2));
	}

	if (!IsValidHexColor(szColor) || (args > 2 && !IsValidHexColor(szColor2)))
	{
		ReplyToCommand(client, "Invalid color format. Use HEX format (e.g., FF0000 for red).");
		return Plugin_Handled;
	}

	if (StrEqual(szType, "name"))
	{
		SetClientCookie(client, g_hNameColor1, szColor);
		if (args > 2)
		{
			SetClientCookie(client, g_hNameColor2, szColor2);
		}
		PrintToChat(client, "Name color set to %s", szColor);
	}
	else if (StrEqual(szType, "text"))
	{
		SetClientCookie(client, g_hTextColor, szColor);
		PrintToChat(client, "Text color set to %s", szColor);
	}
	else if (StrEqual(szType, "prefix"))
	{
		SetClientCookie(client, g_hPrefixColor1, szColor);
		if (args > 2)
		{
			SetClientCookie(client, g_hPrefixColor2, szColor2);
		}
		PrintToChat(client, "Prefix color set to %s", szColor);
	}
	else
	{
		ReplyToCommand(client, "Invalid type. Use 'name', 'text', or 'prefix'.");
	}

	return Plugin_Handled;
}

bool IsValidHexColor(const char[] hex)
{
	if (strlen(hex) != 6)
	{
		return false;
	}

	for (int i = 0; i < 6; i++)
	{
		if (!IsCharHex(hex[i]))
		{
			return false;
		}
	}

	return true;
}

bool IsCharHex(int c)
{
	return (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f');
}

public Action Command_GUIColor(int client, int args)
{
	if (!client || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	Menu menu = new Menu(MenuHandler_GUIColor);
	menu.SetTitle("Select Color Type");

	menu.AddItem("name", "Name Color");
	menu.AddItem("prefix", "Prefix Color");
	menu.AddItem("text", "Text Color");

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int MenuHandler_GUIColor(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));

		if (StrEqual(info, "name"))
		{
			Menu colorMenu = new Menu(MenuHandler_NameColor);
			colorMenu.SetTitle("Select Name Color");

			colorMenu.AddItem("color1", "Starting color");
			colorMenu.AddItem("color2", "Ending color");
			colorMenu.AddItem("plain", "Plain color");

			colorMenu.ExitButton = true;
			colorMenu.Display(param1, MENU_TIME_FOREVER);
		}
		else if (StrEqual(info, "prefix"))
		{
			Menu colorMenu = new Menu(MenuHandler_PrefixColor);
			colorMenu.SetTitle("Select Prefix Color");

			colorMenu.AddItem("color1", "Starting color");
			colorMenu.AddItem("color2", "Ending color");
			colorMenu.AddItem("plain", "Plain color");

			colorMenu.ExitButton = true;
			colorMenu.Display(param1, MENU_TIME_FOREVER);
		}
		else if (StrEqual(info, "text")) {
			OpenGUI(param1, "text_color");
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 1;
}

public int MenuHandler_NameColor(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));

		if (StrEqual(info, "color1"))
		{
			OpenGUI(param1, "name_color1");
		}
		else if (StrEqual(info, "color2"))
		{
			OpenGUI(param1, "name_color2");
		}
		else if (StrEqual(info, "plain"))
		{
			OpenGUI(param1, "name_plain");
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 1;
}

public int MenuHandler_PrefixColor(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));

		if (StrEqual(info, "color1"))
		{
			OpenGUI(param1, "prefix_color1");
		}
		else if (StrEqual(info, "color2"))
		{
			OpenGUI(param1, "prefix_color2");
		}
		else if (StrEqual(info, "plain"))
		{
			OpenGUI(param1, "prefix_plain");
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 1;
}

void OpenGUI(int client, const char[] type)
{
	ResetPlayerData(client);
	SetEntityMoveType(client, MOVETYPE_NONE);
	g_PlayerData[client].inGUI				 = true;
	g_PlayerData[client].selectedInput		 = 0;	   // Initialize selected input to the first one
	g_PlayerData[client].lastButtonPressTime = 0.0;	   // Initialize last button press time
	g_PlayerData[client].lastInputChangeTime = 0.0;
	// Ensure inputToSave is an array and use strcopy to copy the string
	strcopy(g_InputToSave[client], sizeof(g_InputToSave[]), type);
	CreateWorldTexts(client);
	SDKHook(client, SDKHook_PreThink, OnClientPreThink);
}

void CloseGUI(int client)
{
	SetEntityMoveType(client, MOVETYPE_WALK);
	g_PlayerData[client].inGUI = false;
	RemoveWorldTexts(client);
	SDKUnhook(client, SDKHook_PreThink, OnClientPreThink);

	// Save the color in HEX format
	SaveColorToHex(client);

	// Apply the selected color to the appropriate cookie
	char szHexColor[8];
	strcopy(szHexColor, sizeof(szHexColor), g_HexColor[client]);

	if (StrEqual(g_InputToSave[client], "prefix_color1"))
	{
		SetClientCookie(client, g_hPrefixColor1, szHexColor);
	}
	else if (StrEqual(g_InputToSave[client], "prefix_color2"))
	{
		SetClientCookie(client, g_hPrefixColor2, szHexColor);
	}
	else if (StrEqual(g_InputToSave[client], "prefix_plain"))
	{
		SetClientCookie(client, g_hPrefixColor1, szHexColor);
		SetClientCookie(client, g_hPrefixColor2, szHexColor);
	}
	else if (StrEqual(g_InputToSave[client], "name_color1"))
	{
		SetClientCookie(client, g_hNameColor1, szHexColor);
	}
	else if (StrEqual(g_InputToSave[client], "name_color2"))
	{
		SetClientCookie(client, g_hNameColor2, szHexColor);
	}
	else if (StrEqual(g_InputToSave[client], "name_plain"))
	{
		SetClientCookie(client, g_hNameColor1, szHexColor);
		SetClientCookie(client, g_hNameColor2, szHexColor);
	}
	else if (StrEqual(g_InputToSave[client], "text_color")) {
		SetClientCookie(client, g_hTextColor, szHexColor);
	}
}

void SaveColorToHex(int client)
{
	int color[3];
	HSVtoRGB(g_PlayerData[client].hue, g_PlayerData[client].saturation, g_PlayerData[client].brightness, color);

	// Convert RGB to HEX
	Format(g_HexColor[client], sizeof(g_HexColor[]), "%02X%02X%02X", color[0], color[1], color[2]);

	// Print to console for debugging
	PrintToConsole(client, "Saved Color: #%s", g_HexColor[client]);
}

void CreateWorldTexts(int client)
{
	float pos[3];
	GetClientEyePosition(client, pos);

	for (int i = 0; i < MAX_WORLDTEXT; i++)
	{
		int entity = CreateEntityByName("point_worldtext");
		if (IsValidEntity(entity))
		{
			DispatchKeyValue(entity, "message", " ");
			DispatchKeyValue(entity, "orientation", "2");
			DispatchKeyValue(entity, "font", "8");
			DispatchKeyValue(entity, "color", "255 255 255 255");
			DispatchKeyValue(entity, "targetname", "guicolor_entity");
			DispatchKeyValueFloat(entity, "textsize", 8.0);
			DispatchKeyValueFloat(entity, "textspacingX", -7.0);
			DispatchSpawn(entity);
			TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
			g_PlayerData[client].worldTexts[i] = EntIndexToEntRef(entity);
			SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
			SetEntityRenderColor(entity, 255, 255, 255, 255);
			SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
		}
	}

	UpdateWorldTexts(client);
}

void RemoveWorldTexts(int client)
{
	for (int i = 0; i < MAX_WORLDTEXT; i++)
	{
		int entity = EntRefToEntIndex(g_PlayerData[client].worldTexts[i]);
		if (IsValidEntity(entity))
		{
			AcceptEntityInput(entity, "Kill");
		}
	}
}

void UpdateWorldTexts(int client)
{
	char buffer[64];
	int	 hue			   = g_PlayerData[client].hue;
	int	 saturation		   = g_PlayerData[client].saturation;
	int	 brightness		   = g_PlayerData[client].brightness;

	char[] sGuideSelection = "Press W/S to choose active input";
	char[] sGuideApply	   = "Press R to apply color";
	char[] sGuideInput	   = "Hold A/D to change values";

	Format(buffer, sizeof(buffer), "Hue: %d", hue);
	SetWorldTextMessage(client, 0, buffer, g_PlayerData[client].selectedInput == 0);

	Format(buffer, sizeof(buffer), "Saturation: %d", saturation);
	SetWorldTextMessage(client, 1, buffer, g_PlayerData[client].selectedInput == 1);

	Format(buffer, sizeof(buffer), "Brightness: %d", brightness);
	SetWorldTextMessage(client, 2, buffer, g_PlayerData[client].selectedInput == 2);

	int color[3];
	HSVtoRGB(hue, saturation, brightness, color);
	Format(buffer, sizeof(buffer), "Color: %d %d %d", color[0], color[1], color[2]);
	SetWorldTextMessage(client, 3, buffer, g_PlayerData[client].selectedInput == 3, color);

	SetWorldTextMessage(client, 4, sGuideApply);
	SetWorldTextMessage(client, 5, sGuideInput);
	SetWorldTextMessage(client, 6, sGuideSelection);
}

void SetWorldTextMessage(int client, int index, const char[] message, bool selected = false, int color[3] = { 0, 0, 0 })
{
	int entity = EntRefToEntIndex(g_PlayerData[client].worldTexts[index]);
	if (IsValidEntity(entity))
	{
		char finalMessage[128];
		if (selected)
		{
			Format(finalMessage, sizeof(finalMessage), "> %s", message);
		}
		else
		{
			Format(finalMessage, sizeof(finalMessage), "  %s", message);
		}
		DispatchKeyValue(entity, "message", finalMessage);
		if (index == 3)
		{
			char sColor[16];
			Format(sColor, sizeof(sColor), "%i %i %i 255", color[0], color[1], color[2]);
			DispatchKeyValue(entity, "color", sColor);
		}
	}
}

public void OnClientPreThink(int client)
{
	if (!g_PlayerData[client].inGUI)
	{
		return;
	}

	int	  buttons	  = GetClientButtons(client);
	float currentTime = GetGameTime();

	// Check if enough time has passed since the last button press

	if (currentTime - g_PlayerData[client].lastButtonPressTime >= BUTTON_DELAY)
	{
		if (buttons & IN_FORWARD && g_PlayerData[client].selectedInput != 0)	// Assuming IN_ATTACK is used to cycle through inputs
		{
			g_PlayerData[client].selectedInput		 = (g_PlayerData[client].selectedInput - 1);
			g_PlayerData[client].lastButtonPressTime = currentTime;	   // Update last button press time
		}
		if (buttons & IN_BACK && g_PlayerData[client].selectedInput != 2)	 // Assuming IN_ATTACK is used to cycle through inputs
		{
			g_PlayerData[client].selectedInput		 = (g_PlayerData[client].selectedInput + 1);
			g_PlayerData[client].lastButtonPressTime = currentTime;	   // Update last button press time
		}
	}

	if (buttons & IN_RELOAD) CloseGUI(client);

	// Adjust the selected input with jumping or crouching
	if (currentTime - g_PlayerData[client].lastInputChangeTime >= INPUT_DELAY)
	{
		if (g_PlayerData[client].selectedInput == 0)
		{
			if (buttons & IN_MOVERIGHT)
			{
				g_PlayerData[client].hue				 = (g_PlayerData[client].hue + 1) % 360;
				g_PlayerData[client].lastInputChangeTime = currentTime;	   // Update last button press time
			}
			if (buttons & IN_MOVELEFT)
			{
				g_PlayerData[client].hue				 = (g_PlayerData[client].hue - 1 + 360) % 360;
				g_PlayerData[client].lastInputChangeTime = currentTime;	   // Update last button press time
			}
		}
		else if (g_PlayerData[client].selectedInput == 1)
		{
			if (buttons & IN_MOVERIGHT)
			{
				g_PlayerData[client].saturation			 = Clamp(g_PlayerData[client].saturation + 1, 0, 100);
				g_PlayerData[client].lastInputChangeTime = currentTime;	   // Update last button press time
			}
			if (buttons & IN_MOVELEFT)
			{
				g_PlayerData[client].saturation			 = Clamp(g_PlayerData[client].saturation - 1, 0, 100);
				g_PlayerData[client].lastInputChangeTime = currentTime;	   // Update last button press time
			}
		}
		else if (g_PlayerData[client].selectedInput == 2)
		{
			if (buttons & IN_MOVERIGHT)
			{
				g_PlayerData[client].brightness			 = Clamp(g_PlayerData[client].brightness + 1, 0, 100);
				g_PlayerData[client].lastInputChangeTime = currentTime;	   // Update last button press time
			}
			if (buttons & IN_MOVELEFT)
			{
				g_PlayerData[client].brightness			 = Clamp(g_PlayerData[client].brightness - 1, 0, 100);
				g_PlayerData[client].lastInputChangeTime = currentTime;	   // Update last button press time
			}
		}
	}

	UpdateWorldTexts(client);

	// Update the position of the world texts in front of the player's screen
	float eyePos[3];
	float eyeAngles[3];
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAngles);

	float forwardVec[3];
	GetAngleVectors(eyeAngles, forwardVec, NULL_VECTOR, NULL_VECTOR);
	float distance = 100.0;	   // Distance in front of the player
	for (int i = 0; i < MAX_WORLDTEXT; i++)
	{
		int entity = EntRefToEntIndex(g_PlayerData[client].worldTexts[i]);
		if (IsValidEntity(entity))
		{
			float newPos[3];
			newPos[0] = eyePos[0] + forwardVec[0] * distance;
			newPos[1] = eyePos[1] + forwardVec[1] * distance;
			newPos[2] = eyePos[2] + forwardVec[2] * distance;

			if (i < 4)
			{
				newPos[2] -= i * 7.5;
			}
			else {
				newPos[2] += (i - 2) * 7.5;
			}

			TeleportEntity(entity, newPos, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

public Action Hook_SetTransmit(int entity, int client)
{
	for (int i = 0; i < MAX_WORLDTEXT; i++)
	{
		if (EntRefToEntIndex(g_PlayerData[client].worldTexts[i]) == entity)
		{
			return Plugin_Continue;
		}
	}
	return Plugin_Handled;
}

void ResetPlayerData(int client)
{
	g_PlayerData[client].hue				 = 0;
	g_PlayerData[client].saturation			 = 100;
	g_PlayerData[client].brightness			 = 100;
	g_PlayerData[client].inGUI				 = false;
	g_PlayerData[client].selectedInput		 = 0;	   // Reset selected input
	g_PlayerData[client].lastButtonPressTime = 0.0;	   // Reset last button press time
	for (int i = 0; i < MAX_WORLDTEXT; i++)
	{
		g_PlayerData[client].worldTexts[i] = INVALID_ENT_REFERENCE;
	}
}

float fabs(float value)
{
	return value < 0 ? -value : value;
}

float fmod(float x, float y)
{
	return x - y * RoundToFloor(x / y);
}

void HSVtoRGB(int h, int s, int v, int rgb[3])
{
	float H = float(h);
	float S = float(s) / 100.0;
	float V = float(v) / 100.0;

	float C = V * S;
	float X = C * (1 - fabs(fmod(H / 60.0, 2.0) - 1.0));
	float m = V - C;

	float r, g, b;

	if (H >= 0 && H < 60)
	{
		r = C;
		g = X;
		b = 0.0;
	}
	else if (H >= 60 && H < 120) {
		r = X;
		g = C;
		b = 0.0;
	}
	else if (H >= 120 && H < 180) {
		r = 0.0;
		g = C;
		b = X;
	}
	else if (H >= 180 && H < 240) {
		r = 0.0;
		g = X;
		b = C;
	}
	else if (H >= 240 && H < 300) {
		r = X;
		g = 0.0;
		b = C;
	}
	else {
		r = C;
		g = 0.0;
		b = X;
	}

	rgb[0] = RoundToNearest((r + m) * 255);
	rgb[1] = RoundToNearest((g + m) * 255);
	rgb[2] = RoundToNearest((b + m) * 255);
}

int Clamp(int value, int min, int max)
{
	if (value < min) return min;
	if (value > max) return max;
	return value;
}

void DeleteEntitiesWithTargetname(const char[] targetname)
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "point_worldtext")) != -1)
	{
		char entTargetname[64];
		GetEntPropString(entity, Prop_Data, "m_iName", entTargetname, sizeof(entTargetname));
		if (StrEqual(entTargetname, targetname))
		{
			RemoveEntity(entity);
		}
	}
}