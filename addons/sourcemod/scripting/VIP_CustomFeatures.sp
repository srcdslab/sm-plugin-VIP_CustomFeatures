/**
 * =============================================================================
 * [VIP] Custom Features
 * Custom Items in VIP Menu.
 *
 * File: VIP_CustomFeatures.sp
 * Role: -
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#include <vip_core>

#pragma newdecls required
#pragma semicolon 1

/**
 * @section Constants
 */
#define PLUGIN_DESCRIPTION  "Custom Items in VIP Menu."
#define PLUGIN_VERSION      "1.3"
#define PLUGIN_AUTHOR       "CrazyHackGUT aka Kruzya"
#define PLUGIN_NAME         "[VIP] Custom Features"
#define PLUGIN_URL          "https://kruzefag.ru/"

#define SZFS(%0)            %0, sizeof(%0)
#define SZFA(%0,%1)         %0[%1], sizeof(%0[])
#define SGT(%0)             SetGlobalTransTarget(%0)
#define CID(%0)             GetClientOfUserId(%0)
#define CUD(%0)             GetClientUserId(%0)

#define IsEmptyString(%0)   %0[0] == 0

#define PMP                 PLATFORM_MAX_PATH
#define MTL                 MAX_TARGET_LENGTH
#define MPL                 MAXPLAYERS
#define MCL                 MaxClients

#define nullvct             NULL_VECTOR
#define nullstr             NULL_STRING
#define nullptr             null

/**
 * @section Global Variables
 */
Handle  g_hFeatures;    /**< All registered features. ArrayList contains StringMaps. */
int     g_iID;

/**
 * @section Plugin Information.
 */
public Plugin myinfo = {
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    author      = PLUGIN_AUTHOR,
    name        = PLUGIN_NAME,
    url         = PLUGIN_URL
};

/**
 * @section Events
 */
public void OnPluginStart() {
    RegServerCmd("sm_reloadvipci", ReloadCustomItems_Cmd);
    g_hFeatures = CreateArray(4);

    LoadTranslations("vip_modules.phrases");

    if (CanTestFeatures() && GetFeatureStatus(FeatureType_Capability, "FEATURECAP_COMMANDLISTENER") == FeatureStatus_Unavailable) {
        SetFailState("CommandListener Feature is not available on this gamemode. Engine Version %d. Report this incident to developer.", GetEngineVersion());
    }
}

public void OnPluginEnd() {
    VIP_UnloadFeatures();
}

public void OnMapStart() {
    VIP_LoadFeatures();
}

public void OnMapEnd() {
    VIP_UnloadFeatures();
}

public void VIP_OnVIPLoaded() {
    int iLength = GetArraySize(g_hFeatures);
    if (iLength == 0)
        return;

    for (int i; i < iLength; i++) {
        Handle hFeatureInformation = GetArrayCell(g_hFeatures, i);

        char szTemp[64];
        GetTrieString(hFeatureInformation, "Feature", SZFS(szTemp));

        // Register feature, if not exists.
        if (!VIP_IsValidFeature(szTemp)) {
            VIP_FeatureType eFType;
            if (!GetTrieValue(hFeatureInformation, "FeatureType", eFType)) {
                eFType = SELECTABLE;
            }

            ItemSelectCallback fCallback;
            switch (eFType) {
                case TOGGLABLE:     fCallback = VIP_OnItemPressed;
                case SELECTABLE:    fCallback = VIP_OnItemTouched;
            }
            VIP_RegisterFeature(szTemp, BOOL, eFType, fCallback, VIP_OnRenderTextItem);

            // Register listener.
            char szCmd[2][64];
            GetTrieString(hFeatureInformation, "Command", SZFS(szTemp));
            ExplodeString(szTemp, " ", szCmd, sizeof(szCmd), sizeof(szCmd[]), false);
            AddCommandListener(OnCommandExecuted, szCmd[0]);
        } else {
            LogError("Feature %s already registered! Skipping...", szTemp);
        }
    }
}

/**
 * @section Commands
 */
public Action ReloadCustomItems_Cmd(int iArgc) {
    VIP_UnloadFeatures();
    VIP_LoadFeatures();

    return Plugin_Handled;
}

/**
 * @section Features Loader
 */
void VIP_LoadFeatures() {
    static Handle hSMC = nullptr;
    static char szPath[PMP];

    if (!hSMC) {
        hSMC = SMC_CreateParser();
        SMC_SetReaders(hSMC, OnNewSection, OnKeyValue, OnEndSection);
    }

    if (IsEmptyString(szPath)) {
        BuildPath(Path_SM, SZFS(szPath), "data/vip/modules/custom_items.cfg");
    }

    if (!FileExists(szPath)) {
        SetFailState("Couldn't find configuration file: %s", szPath);
    }

    g_iID = -1;
    SMCError eError = SMC_ParseFile(hSMC, szPath);
    if (eError != SMCError_Okay) {
        SetFailState("Couldn't parse configuration file: %s. Error code %d.", szPath, eError);
    }

    if (VIP_IsVIPLoaded()) {
        VIP_OnVIPLoaded();
    }
}

void VIP_UnloadFeatures() {
    int iLength = GetArraySize(g_hFeatures);
    if (iLength == 0)
        return;

    for (int i; i < iLength; i++) {
        Handle hFeatureInformation = GetArrayCell(g_hFeatures, i);

        char szTemp[2][64];
        GetTrieString(hFeatureInformation, "Feature", SZFA(szTemp, 0));

        // Unregister feature, if exists.
        VIP_IsValidFeature(szTemp[0]) && VIP_UnregisterFeature(szTemp[0]);

        // Unregister listener, if registered.
        int iListenerState;
        GetTrieValue(hFeatureInformation, "RestrictAccess", iListenerState);

        if (iListenerState > 0) {
            GetTrieString(hFeatureInformation, "Command", SZFA(szTemp, 0));
            ExplodeString(szTemp[0], " ", szTemp, sizeof(szTemp), sizeof(szTemp[]), false);
            RemoveCommandListener(OnCommandExecuted, szTemp[0]);
        }

        // Close Handle.
        delete hFeatureInformation;
    }

    // Clear array.
    ClearArray(g_hFeatures);
}

/**
 * @section Touch/Press/Renderer callbacks.
 */
public Action VIP_OnItemPressed(int iClient, const char[] szFeatureName, VIP_ToggleState eOldStatus, VIP_ToggleState &eNewStatus) {
    VIP_ExecuteFeature(iClient, szFeatureName);
    return Plugin_Handled;
}

public bool VIP_OnItemTouched(int iClient, const char[] szFeatureName) {
    VIP_ExecuteFeature(iClient, szFeatureName);
    return false;
}

public bool VIP_OnRenderTextItem(int iClient, const char[] szFeatureName, char[] szDisplay, int iMaxLength) {
    FormatEx(szDisplay, iMaxLength, "%T", szFeatureName, iClient);
    return true;
}

/**
 * @section Executor
 */
void VIP_ExecuteFeature(int iClient, const char[] szFeatureName) {
    int iLength = GetArraySize(g_hFeatures);
    if (iLength == 0)
        return;

    char szFeature[64];
    for (int i; i < iLength; i++) {
        Handle hFeatureInformation = GetArrayCell(g_hFeatures, i);
        GetTrieString(hFeatureInformation, "Feature", SZFS(szFeature));

        if (strcmp(szFeature, szFeatureName, true) == 0) {
            char szCommand[256];
            GetTrieString(hFeatureInformation, "Command", SZFS(szCommand));

            FakeClientCommand(iClient, "%s", szCommand);
            return;
        }
    }

    LogError("Couldn't execute VIP feature %s for client %L", szFeatureName, iClient);
}

/**
 * @section Config Parsers.
 */
public SMCResult OnNewSection(Handle hSMC, const char[] szSectionName, bool bOptQuotes) {
    if (strcmp(szSectionName, "CustomFeatures") == 0)
        return SMCParse_Continue;

    g_iID = PushArrayCell(g_hFeatures, CreateTrie());
    SetTrieString(GetArrayCell(g_hFeatures, g_iID), "Feature", szSectionName);

    return SMCParse_Continue;
}

public SMCResult OnKeyValue(Handle hSMC, const char[] szKey, const char[] szValue, bool bKeyQuotes, bool bValueQuotes) {
    if (g_iID == -1) {
        SetFailState("Invalid Config");
    }

    /**
     * Trigger.
     */
    if (strcmp(szKey, "Trigger") == 0) {
        SetTrieString(GetArrayCell(g_hFeatures, g_iID), "Command", szValue);
        return SMCParse_Continue;
    }

    /**
     * Trigger Type.
     */
    if (strcmp(szKey, "TriggerType") == 0) {
        VIP_FeatureType eFType;

        if (strcmp(szValue, "select") == 0) {
            eFType = SELECTABLE;
        } else if (strcmp(szValue, "toggle") == 0) {
            eFType = TOGGLABLE;
        } else {
            SetFailState("Invalid Config");
        }

        SetTrieValue(GetArrayCell(g_hFeatures, g_iID), "FeatureType", eFType);
        return SMCParse_Continue;
    }

    /**
     * Restrict Access.
     */
    if (strcmp(szKey, "RestrictAccess") == 0) {
        SetTrieValue(GetArrayCell(g_hFeatures, g_iID), "RestrictAccess", StringToInt(szValue));
        return SMCParse_Continue;
    }

    /**
     * PrintToChat
     */
    if (strcmp(szKey, "SendNotify") == 0) {
        SetTrieValue(GetArrayCell(g_hFeatures, g_iID), "Notify", (szValue[0] != '0'));
        return SMCParse_Continue;
    }

    /**
     * Other unknown stuff.
     */
    SetFailState("Invalid Config");
    return SMCParse_HaltFail;
}

public SMCResult OnEndSection(Handle hSMC) {}

/**
 * @section Command Listener
 */
public Action OnCommandExecuted(int iClient, const char[] szCommand, int iArgC) {
    if (iClient == 0)
        return Plugin_Continue;

    char szBuffer[2][64];
    int iLength = GetArraySize(g_hFeatures);

    int iListenerState;
    bool bNotify;

    for (int i; i < iLength; i++) {
        Handle hFeatureInformation = GetArrayCell(g_hFeatures, i);
        GetTrieString(hFeatureInformation, "Command", SZFA(szBuffer, 0));
        ExplodeString(szBuffer[0], " ", szBuffer, sizeof(szBuffer), sizeof(szBuffer[]), false);

        if (strcmp(szBuffer[0], szCommand) == 0) {
            GetTrieValue(hFeatureInformation, "RestrictAccess", iListenerState);
            GetTrieValue(hFeatureInformation, "Notify", bNotify);
            GetTrieString(hFeatureInformation, "Feature", szBuffer[0], sizeof(szBuffer[]));
            break;
        }
    }

    if (VIP_IsClientFeatureUse(iClient, szBuffer[0]))
        return Plugin_Continue;

    if (iListenerState == 0 || (iListenerState == 2 && GetUserAdmin(iClient) != INVALID_ADMIN_ID))
        return Plugin_Continue;

    if (bNotify) {
        // VIP_PrintToChatClient(iClient, "%T", "CF_BuyVip", iClient);
        PrintToChat(iClient, "\x04[VIP] \x01%T", "CF_BuyVip", iClient);
    }

    return Plugin_Stop;
}