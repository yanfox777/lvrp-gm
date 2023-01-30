#include <a_samp>
#include <fix>
#include <a_mysql>
#include <streamer>
#include <Pawn.CMD>
#include <sscanf2>
#include <foreach>
#include <Pawn.Regex>
#include <TOTP>
#include <geolocation>
#include <crashdetect>

#define     MYSQL_HOST  "127.0.0.1"
#define     MYSQL_USER  "root"
#define     MYSQL_PASS  ""
#define     MYSQL_BASE  "lvrp"

#define 	SCM     SendClientMessage
#define 	SCMTA   SendClientMessageToAll
#define     SPD     ShowPlayerDialog
new format_string[128];
#define SCMF(%0,%1,%2,%3) format(format_string,sizeof(format_string),%2,%3);SendClientMessage(%0,%1,format_string)
#define     SERVER_NAME 	"LasVenturas RolePlay"
#define     SITE_URl 		"lasventuras-rp.com"


#define COLOR_WHITE 		0xFFFFFFFF
#define	COLOR_GREY			0x999999FF
#define COLOR_RED 			0xFF0000FF
#define COLOR_NOTIFICATION 	0xFF8C00FF
#define COLOR_LIGHTRED      0xe93230FF
#define COLOR_TOMATO      	0xFF6347FF
#define COLOR_BLUE          0x3657FFFF
#define COLOR_LIGHTBLUE     0x3399FFFF
#define COLOR_YELLOW		0xFFFF00FF

#define     SCMError(%0,%1) SCM(%0, COLOR_RED, %1), PlayerPlaySound(%0, 1085, 0.0, 0.0, 0.0)
#define     SCMNotification(%0,%1) SCM(%0, COLOR_NOTIFICATION, %1), PlayerPlaySound(%0, 1083, 0.0, 0.0, 0.0)

#define     pName(%0)   player_info[%0][NAME]
new NonLasVenturasGZ[7];
//��� ���������� ���������� ����������� string ��� ���������� ���������
new PlayerText:gInventoryGTextDrawNow[MAX_PLAYERS][2];

//inventory
#define     INVENTORY_SPACE_SLOTS                   40.0
#define     INVENTORY_WIDTH                         6
#define     INVENTORY_HEIGHT                        4
#define     INVENTORY_SIZE                          (INVENTORY_HEIGHT * INVENTORY_WIDTH)
#define     INVENTORY_MAX_SLOT                      INVENTORY_SIZE

#define     INVALID_INVENTORY_CLICK_SLOT            -1
#define     INVALID_INVENTORY_ITEM_ID               0

enum {
    /*
        ���������� TextDraws Inventory
    */
    Text: INVENTORY_GTD_BG,
    Text: INVENTORY_GTD_TEXT,
    Text: INVENTORY_GTD_CLOSE,
    MAX_INVENTORY_GTEXTDRAWS
}

enum {
    /*
         TextDraws ������: ���� ������ USE, INFO, DRO
    */
    PlayerText: INVENTORY_PTD_USE_BG,
    PlayerText: INVENTORY_PTD_USE,
    PlayerText: INVENTORY_PTD_INFO_BG,
    PlayerText: INVENTORY_PTD_INFO,
    MAX_INVENTORY_PTD_CLICKSLOT
}

enum {
    /*
        TextDraws ������: ����� ��� ������
    */
    PlayerText: INVENTORY_PTD_AMOUNT     [INVENTORY_SIZE],
    PlayerText: INVENTORY_PTD_NAME       [INVENTORY_SIZE],
    MAX_INVENTORY_PTD_TEXT
}

new
    Text: gInventoryGTextDraw            [MAX_INVENTORY_GTEXTDRAWS],
	Text:gInventoryGTextDrawBG[9],                 								/* ���������� TextDraw Inventory: ������ ���, �����, �������� */

    PlayerText: gInventoryPTDClickSlot   [MAX_PLAYERS][MAX_INVENTORY_PTD_CLICKSLOT], /* TextDraws ������: ���� ������ USE, INFO, DROP */
    PlayerText: gInventoryPTDSlots       [MAX_PLAYERS][INVENTORY_SIZE],              /* TextDraws ������: ����� */
    PlayerText: gInventoryPTDTextSlots   [MAX_PLAYERS][MAX_INVENTORY_PTD_TEXT],      /* TextDraws ������: ����� ��� ������ */

    bool: gInventoryOpen                 [MAX_PLAYERS char],
    gInventoryClickSlot                  [MAX_PLAYERS]
;

enum {
    ITEM_TYPE_SKIN = 0,
	ITEM_TYPE_WEAPON = 1,     // ����
    __DUMMY_ELEMENT_,
    ITEM_TYPE_COUNT = __DUMMY_ELEMENT_
}

enum e_InventoryItems {
    /*
        Enum, ���������� ���������� � ��������� ���������
    */
    iItemID,
    iModel,
    iUse[10],
    iName[60],
    iDesc[110],
    iType,

    Float: iItemPosX,
    Float: iItemPosY,
    Float: iItemPosZ,
    Float: iItemPosC
};
#include <MODULES/inventory_data.pwn>


enum e_InventoryData {
    idItem      [INVENTORY_MAX_SLOT],
    idAmount    [INVENTORY_MAX_SLOT]
}
new pInventoryData[MAX_PLAYERS][e_InventoryData];


main()
{
	print("\n-----------------------------------");
	print("--------"SERVER_NAME" STARTED--------");
	print("-----------------------------------\n");
}

//===============================   ����������   ===============================

//----------------------------   ������ �����/������  --------------------------
new mineenter, //���� � �����
	mineexit; //����� �� �����
//------------------------------------------------------------------------------

//---------------------------------   ������   ---------------------------------
new Pmine[4];//������ �����
//------------------------------------------------------------------------------

//-------------------------------   3D ������   --------------------------------
new Text3D:storagemineinfo[4];
//------------------------------------------------------------------------------

//---------------------------   ������������ ����   ----------------------------
new nojump[2];
//------------------------------------------------------------------------------

//----------------------------   ���������� �������   --------------------------
new minefirstlift[4], //���� ������� ��������� �� �����
	minesecondlift[4]; //���� ��������� ��������� �� �����
//------------------------------------------------------------------------------

//--------------------------------   ����������   ------------------------------
new Text:GraphicPIN_TD;
new PlayerText:GraphicPIN_PTD[MAX_PLAYERS][4];
new Text:ServerLogo_TD[2];
new Text:Mine_TD[5];
new PlayerText:MineMoney_PTD[MAX_PLAYERS];
new PlayerText:MineAmount_PTD[MAX_PLAYERS];
new Text:IntLoad_TD[5];
//------------------------------------------------------------------------------

//---------------------------------   �������   --------------------------------
static pPickupID[MAX_PLAYERS];//���� ����� �������
new MySQL:dbHandle;
new PlayerAFK[MAX_PLAYERS];
new expmultiply = 4;
new LoginTimer[MAX_PLAYERS];
new usedweather[20] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 18, 19, 20};
new weather;
new bool:statictime = false;
new inadmcar[MAX_PLAYERS];
//------------------------------------------------------------------------------

#define MAX_ADMINS 50
new Iterator:Admins_ITER<MAX_ADMINS>;
new Iterator:Question_ITER<MAX_PLAYERS/2>; //��������! ���� ���-�� �������� ��������� 500, �� �������� ��������������� ������ �������. ���� ���������, ��� ����� ��������, �� ������� "/2"

//==============================================================================

enum player
{
	ID,
	NAME[MAX_PLAYER_NAME],
	PASSWORD[65],
	SALT[11],
	EMAIL[65],
	REF,
	REFMONEY,
	SEX,
	RACE,
	AGE,
	SKIN,
	REGDATA[13],
	REGIP[16],
	ADMIN,
	MONEY,
	LVL,
	EXP,
	MINS,
	PIN[2],
	LASTIP[16],
	tempPINCHECK[4],
	tempENTEREDPIN[4],
	GOOGLEAUTH[17],
	GOOGLEAUTHSETTING,
	tempQUESTION[98],
	LOWWORKSKILL[2],
}
new player_info[MAX_PLAYERS][player];

enum temporary
{
	LOWWORK,
	MINELOW,
	MINEHIGH,
	MINEPROGRESS,
	MINENUMBER,
}
new temp_info[MAX_PLAYERS][temporary];

enum storage
{
	MINELOW,
 	MINEHIGH,
 	MINELOWREADY,
 	MINEHIGHREADY
}
new storages[storage];

enum dialogs
{
	DLG_NONE,
	DLG_REG,
	DLG_REGEMAIL,
	DLG_REGREF,
	DLG_REGSEX,
	DLG_REGRACE,
	DLG_REGAGE,
	DLG_LOG,
	DLG_MAINMENU,
	DLG_STATS,
	DLG_SECURESETTINGS,
	DLG_NEWPASS1,
	DLG_NEWPASS2,
	DLG_SECRETPINCONTROL,
	DLG_SECRETPINSET,
	DLG_SECRETPINRESET,
	DLG_GOOGLEAUTHINSTALL,
	DLG_GOOGLEAUTHINSTALLCHECK,
	DLG_GOOGLEAUTHCONTROL,
	DLG_CHECKGOOGLEAUTH,
	DLG_INFORMADM,
	DLG_REPORT,
	DLG_AHELP,
	DLG_AHELPCMD,
	DLG_QUESTION,
	DLG_ANSWERPLAYER,
	DLG_ADDFASTANSWER,
	DLG_MINELOWJOIN,
	DLG_MINEHIGHJOIN,
	DLG_MINELOWLEFT,
	DLG_MINEHIGHLEFT,
	DLG_WEAPON,
	DLG_MAYOR_LIFT_1,
	DLG_MAYOR_LIFT_2,
	DLG_MAYOR_LIFT_3
}

new PlayerRaces[3][] = {"����������", "������������", "������������/���������"};

public OnGameModeInit()
{
	ConnectMySQL();
	SetGameModeText("LasVenturas RP");
	SendRconCommand("weburl "SITE_URl"");
	SendRconCommand("hostname "SERVER_NAME" | Test | ����������");
	
	LoadTextDraws();
	LoadMapping();
	LoadPickups();
	Load3DText();
	LoadDynamicZones();
	
	Iter_Clear(Admins_ITER);
	Iter_Clear(Question_ITER);
	
	DisableInteriorEnterExits();
	EnableStuntBonusForAll(0);
	LimitPlayerMarkerRadius(45.0);
	
	mysql_tquery(dbHandle, "SELECT * FROM `storages`", "LoadStorages", "");
	
	SetTimer("SecondUpdate", 1000, true);
	SetTimer("MinuteUpdate", 60000, true);
	AddPlayerClass(1, 1432.6733,2653.3237,11.3926, 180.0, 0, 0, 0, 0, 0, 0);
 	SetWeatherEx(usedweather[random(20)]);
 	
 	CreateInventoryGTextDraws();
 	
 	NonLasVenturasGZ[0] = GangZoneCreate(-3000, -3000, -1583, 1633);
 	NonLasVenturasGZ[1] = GangZoneCreate(-1586, -3000, -1181, 1419);
 	NonLasVenturasGZ[2] = GangZoneCreate(-1184, -3000, -957, 705);
 	NonLasVenturasGZ[3] = GangZoneCreate(-1068, -3000, 3000, 343);
 	NonLasVenturasGZ[4] = GangZoneCreate(448, 341, 3000, 441);
 	NonLasVenturasGZ[5] = GangZoneCreate(859, 439, 1660, 539);
 	NonLasVenturasGZ[6] = GangZoneCreate(979, 536, 1322, 608);
	return 1;
}

stock LoadRemovedObjects(playerid)
{
	//mineext.inc
	RemoveBuildingForPlayer(playerid, 865, -793.1094, -1863.3672, 11.8281, 0.25);
	RemoveBuildingForPlayer(playerid, 865, -788.6875, -1861.7266, 10.5547, 0.25);
	RemoveBuildingForPlayer(playerid, 865, -787.2422, -1863.3672, 10.5391, 0.25);
	RemoveBuildingForPlayer(playerid, 865, -780.5703, -1856.9688, 10.6875, 0.25);
	RemoveBuildingForPlayer(playerid, 865, -776.3750, -1857.6719, 10.9141, 0.25);
	
	//
}

stock LoadMapping()
{
    new tmpobjid;
    #include <Maps/mineext.inc> //����� �������
	#include <Maps/mineint.inc> //����� ������
}

stock LoadTextDraws()
{
    #include <TextDraws/GraphicPIN>
   	#include <TextDraws/ServerLogo>
   	#include <TextDraws/Mine>
   	#include <TextDraws/IntLoad>
}

stock LoadPickups()
{
    #include <Pickups/EnterExit>
    #include <Pickups/Other>
    #include <Pickups/FixedPickups>
}

stock Load3DText()
{
    #include <3DTexts/all>
}

stock LoadDynamicZones()
{
    #include <DynamicZones/all>
}

stock ConnectMySQL()
{
    dbHandle = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_BASE);
	switch(mysql_errno())
	{
	    case 0: print("����������� � MySQL �������");
	    default: print("MYSQL �� ��������!1!!");
	}
	mysql_log(ERROR | WARNING);
	mysql_set_charset("cp1251");
}

forward LoadStorages();
public LoadStorages()
{
    cache_get_value_name_int(0, "minelow", storages[MINELOW]);
    cache_get_value_name_int(0, "minehigh", storages[MINEHIGH]);
    cache_get_value_name_int(0, "minelowready", storages[MINELOWREADY]);
    cache_get_value_name_int(0, "minehighready", storages[MINEHIGHREADY]);
    for(new i = 0; i < 4; i++)
    {
        UpdateStorages(i);
    }
	print("������ ������� ���������");
	return 1;
}

public OnGameModeExit()
{
	mysql_close();
	return 1;
}
SetWeatherEx(weatherid) {
	weather = weatherid;
    SetWeather(weatherid);
}
forward MinuteUpdate();
public MinuteUpdate()
{
    new hour, minute;
	gettime(hour, minute);
	if(minute == 0)
	{
		if(hour == 0 || hour == 3 || hour == 6 || hour == 9 || hour == 12 || hour == 15 || hour == 18 || hour == 21) SetWeatherEx(usedweather[random(20)]);
	}
    foreach(new i:Player)
	{
	    if(statictime == false) SetPlayerTime(i, hour, minute);
		if(PlayerAFK[i] < 2)
	    {
	        player_info[i][MINS]++;
	        if(player_info[i][MINS] >= 60)
	        {
	            player_info[i][MINS] = 0;
	            PayDay(i);
	        }
	    }
	}
	if(storages[MINELOW] >= 10)
	{
	    AddStorage(1, -10);
	    AddStorage(2, 1);
	}
	if(storages[MINEHIGH] >= 10)
	{
	    AddStorage(3, -10);
	    AddStorage(4, 1);
	}
}

stock PayDay(playerid)
{
    new needexp = (player_info[playerid][LVL]+1)*expmultiply;
    SCM(playerid, COLOR_WHITE, "");
	SCM(playerid, COLOR_WHITE, "{84B579}________���������� ���________");
	SCMF(playerid, COLOR_WHITE, "��������: $%d", 0);
	SCMF(playerid, COLOR_WHITE, "������� � �����: $%d", 0);
	SCMF(playerid, COLOR_WHITE, "����� �������� � �����: $%d", 0);
	GiveExp(playerid, 2);
	SCMF(playerid, COLOR_WHITE, "�� ������ ������ � ��� %d ������� � %d/%d exp", player_info[playerid][LVL], player_info[playerid][EXP], needexp);
	SCMF(playerid, COLOR_WHITE, "�����������������: %d (+%d)", 99, 1);
	SCM(playerid, COLOR_WHITE, "{84B579}______________________________");
	SCM(playerid, COLOR_WHITE, "");
	return 1;
}

forward SecondUpdate();
public SecondUpdate()
{
	foreach(new i:Player)
	{
	    if(GetPlayerMoney(i) != player_info[i][MONEY])
		{
		    ResetPlayerMoney(i);
		    GivePlayerMoney(i, player_info[i][MONEY]);
		}
	    PlayerAFK[i]++;
	    if(PlayerAFK[i] == 2)
	    {
	        if(GetPlayerState(i) == PLAYER_STATE_ONFOOT) ApplyAnimation(i, !"CRACK", !"crckidle2", 4.1, 1, 0, 0, 0, 0, 1);
	    }
	    if(PlayerAFK[i] >= 2)
	    {
	        new string[29] = "{FF0000}AFK: ";
	        if(PlayerAFK[i] < 60)
	        {
	            format(string, sizeof(string), "%s%d ���.", string, PlayerAFK[i]);
	        }
	        else
	        {
	            new minute = floatround(PlayerAFK[i]/60, floatround_floor);
	            new second = PlayerAFK[i] % 60;
	            format(string, sizeof(string), "%s%d ���. %d ���.", string, minute, second);
	        }
	        SetPlayerChatBubble(i, string, -1, 20, 1050);
	    }
	}
	return 1;
}

stock PreloadAnimLib(playerid, animlib[])
{
	ApplyAnimation(playerid, animlib, "null", 0.0, 0, 0, 0, 0, 0);
	return 1;
}
stock PreloadAnim(playerid)
{
    PreloadAnimLib(playerid, "PED");
    PreloadAnimLib(playerid, "CRIB");
    PreloadAnimLib(playerid, "ON_LOOKERS");
    PreloadAnimLib(playerid, "BASEBALL");
    PreloadAnimLib(playerid, "CARRY");
    PreloadAnimLib(playerid, "CRACK");
	return 1;
}

stock UpdateStorages(id)
{
	new string[63+(-2+8)];
	switch(id)
	{
	    case 1:
	    {
	        format(string, sizeof(string), "������������ �� ��������������\n���� �� ������: {C0C0C0}%d ��", storages[MINELOW]);
	        UpdateDynamic3DTextLabelText(storagemineinfo[0], 0x3399FF95, string);
	    }
	    case 2:
	    {
	        format(string, sizeof(string), "������� ������������\n���� �� ������: {C0C0C0}%d ��", storages[MINELOWREADY]);
	        UpdateDynamic3DTextLabelText(storagemineinfo[1], 0x3399FF95, string);
	    }
	    case 3:
	    {
	        format(string, sizeof(string), "������������� �� ��������������\n���� �� ������: {F4A460}%d ��", storages[MINEHIGH]);
	        UpdateDynamic3DTextLabelText(storagemineinfo[2], 0x3399FF95, string);
	    }
	    case 4:
	    {
	        format(string, sizeof(string), "������� �������������\n���� �� ������: {F4A460}%d ��", storages[MINEHIGHREADY]);
	        UpdateDynamic3DTextLabelText(storagemineinfo[3], 0x3399FF95, string);
	    }
	}
}
stock AddStorage(id, number)
{
    UpdateStorages(id);
    switch(id)
	{
	    case 1: storages[MINELOW]+=number;
	    case 2: storages[MINELOWREADY]+=number;
	    case 3: storages[MINEHIGH]+=number;
	    case 4: storages[MINEHIGHREADY]+=number;
	}
	static const fmt_query[] = "UPDATE `storages` SET `minelow` = '%d', `minelowready` = '%d', `minehigh` = '%d', `minehighready` = '%d'";
	new query[sizeof(fmt_query)+(-2+8)+(-2+8)+(-2+8)+(-2+8)];
	mysql_format(dbHandle, query, sizeof(query), fmt_query, storages[MINELOW], storages[MINELOWREADY], storages[MINEHIGH], storages[MINEHIGHREADY]);
	mysql_tquery(dbHandle, query);
}

public OnPlayerRequestClass(playerid, classid)
{
	SetPlayerSkin(playerid, player_info[playerid][SKIN]);
	SpawnPlayer(playerid);
	SetPlayerSkin(playerid, player_info[playerid][SKIN]);
	return 1;
}

stock ResetVariables(playerid)
{
    inadmcar[playerid] = -1;
}

CMD:additem(playerid, params[]) {
    extract params -> new itemid, amount; else return 1;

    new item = AddInventoryItem(playerid, itemid, amount);

    if(item == -1)
        SendClientMessage(playerid, -1, !"������� �� ����������");
    return 1;
}

CMD:remove(playerid, params[]) {
    extract params -> new itemid, amount; else return 1;

    RemoveInventoryItem(playerid, itemid, amount);
    return 1;
}

CMD:inventory(playerid) {
    ShowPlayerInventory(playerid);
    return 1;
}
public OnPlayerConnect(playerid)
{
	for(new i = 0; i < sizeof(NonLasVenturasGZ); i++) GangZoneShowForPlayer(playerid, NonLasVenturasGZ[i], 0x000000FF);
	GetPlayerName(playerid, player_info[playerid][NAME], MAX_PLAYER_NAME);
	TogglePlayerSpectating(playerid, 1);
	
	ResetVariables(playerid);
	
	SetPlayerColor(playerid, 0x99999900);
	
	LoadPlayerTextDraws(playerid);
	LoadRemovedObjects(playerid);
	
	TextDrawShowForPlayer(playerid, ServerLogo_TD[0]);
	TextDrawShowForPlayer(playerid, ServerLogo_TD[1]);
	
	static const fmt_query[] = "SELECT `password`, `salt`, `pin`, `lastip`, `googleauth`, `gs` FROM `users` WHERE `name` = '%e'";
	new query[sizeof(fmt_query)+(-2+MAX_PLAYER_NAME)];
	mysql_format(dbHandle, query, sizeof(query), fmt_query, pName(playerid));
	mysql_tquery(dbHandle, query, "CheckRegistration", "i", playerid);
	
	
	
	SetPVarInt(playerid, "WrongPassword", 3);
	
	for(new slot = 0; slot < INVENTORY_MAX_SLOT; slot++) {
        SetPlayerInventoryItemByIDX(playerid, slot, INVALID_INVENTORY_ITEM_ID);
        SetPlayerInventoryAmountByIDX(playerid, slot, 0);
    }

    SetStatusInventory(playerid, false);
    SetClickedSlot(playerid, INVALID_INVENTORY_CLICK_SLOT);
	return 1;
}

stock LoadPlayerTextDraws(playerid)
{
    #include <PlayerTextDraws/GraphicPIN>
}


forward CheckRegistration(playerid);
public CheckRegistration(playerid)
{
	new rows;
	cache_get_row_count(rows);
	if(rows)
	{
	    cache_get_value_name(0, "password", player_info[playerid][PASSWORD], 65);
	    cache_get_value_name(0, "salt", player_info[playerid][SALT], 11);
	    new buffer[32];
        cache_get_value_name(0, "pin", buffer, 16);
        sscanf(buffer, "p<,>a<i>[2]", player_info[playerid][PIN]);
        cache_get_value_name(0, "lastip", player_info[playerid][LASTIP], 16);
        cache_get_value_name(0, "googleauth", player_info[playerid][GOOGLEAUTH], 17);
        cache_get_value_name_int(0, "gs", player_info[playerid][GOOGLEAUTHSETTING]);
        
		ShowLogin(playerid);
	}
	else ShowRegistration(playerid);
	
	new hour, minute;
	gettime(hour, minute);
 	SetPlayerTime(playerid, hour, minute);
	InterpolateCameraPos(playerid, 1280.6528,-2037.6846,75.6408+5.0, 13.4005,-2087.5444,35.9909, 25000);
	InterpolateCameraLookAt(playerid, 446.5704,-2036.8873,35.9909-5.0, 367.5072,-1855.4072,11.2948, 25000);
}

stock ShowLogin(playerid)
{
	new dialog[171+(-2+MAX_PLAYER_NAME)];
	format(dialog, sizeof(dialog),
		"{FFFFFF}��������� {0089ff}%s{FFFFFF}, � ������������ �� {0089ff}"SERVER_NAME"{FFFFFF}\n\
		\t\t�� ���� ����� ������ ���!\n\n\
		��� ����������� ������� ���� ������ � ���� ����:",
    pName(playerid)
	);
	SPD(playerid, DLG_LOG, DIALOG_STYLE_PASSWORD, !"{ff9300}�����������{FFFFFF}", dialog, !"�����", !"�����");
	KillTimer(LoginTimer[playerid]);
	LoginTimer[playerid] = SetTimerEx("LoginTimeExpired", 60000, false, "d", playerid);
}

forward LoginTimeExpired(playerid);
public LoginTimeExpired(playerid)
{
	if(GetPVarInt(playerid, "logged") == 0)
	{
	    SCM(playerid, COLOR_LIGHTRED, "����� �� ����������� ����������");
	    SCM(playerid, COLOR_LIGHTRED, "������� /q(/quit) ����� �����");
	    SPD(playerid, -1, 0, " ", " ", " ", " ");
	    Kick(playerid);
	}
}

stock ShowRegistration(playerid)
{
	new dialog[403+(-2+MAX_PLAYER_NAME)];
	format(dialog, sizeof(dialog),
		"{FFFFFF}��������� {0089ff}%s{FFFFFF}, �� ���� ������ ��� �� {0089ff}"SERVER_NAME"{FFFFFF}\n\
		������� � ����� ����� �� ���������������\n\
		��� ���� �� ������� �� ������ ������ �����������\n\n\
		���������� ������� ������ ��� ������ �������� �������� � ������� \"�����\"\n\
		{ff9300}\t� ������ ������ ���� �� 8-�� �� 32-�� ��������\n\
		\t� ������ ������ �������� ������ �� ����� � ��������� �������� ������ ��������",
	pName(playerid)
	);
 	SPD(playerid, DLG_REG, DIALOG_STYLE_INPUT, !"{ff9300}�����������{FFFFFF} � ���� ������", dialog, !"�����", !"�����");
}

public OnPlayerDisconnect(playerid, reason)
{
    KillTimer(LoginTimer[playerid]);
    DestroyTD(playerid);
    if(GetPVarInt(playerid, "logged") != 0)
	{
	    if(player_info[playerid][ADMIN] > 0) Iter_Remove(Admins_ITER, playerid);
	    static const fmt_query[] = "UPDATE `users` SET `mins` = '%d', `lastip` = '%e' WHERE `id` = '%d'";
		new query[sizeof(fmt_query)+(-2+2)+(-2+15)+(-2+8)];
		mysql_format(dbHandle, query, sizeof(query), fmt_query, player_info[playerid][MINS], player_info[playerid][LASTIP], player_info[playerid][ID]);
		mysql_tquery(dbHandle, query);
		if(strlen(player_info[playerid][tempQUESTION]) > 0)
		{
		    player_info[playerid][tempQUESTION] = EOS;
		    Iter_Remove(Question_ITER, playerid);
		}
	}
	if(temp_info[playerid][MINELOW] == 1)
	{
	    temp_info[playerid][LOWWORK] = 0;
	    temp_info[playerid][MINELOW] = 0;
	    if(temp_info[playerid][MINENUMBER] > 0)
		{
		    GiveMoney(playerid, temp_info[playerid][MINENUMBER]*2);
		}
		SaveLowWorkSkills(playerid);
		temp_info[playerid][MINEPROGRESS] = 0;
	    temp_info[playerid][MINENUMBER] = 0;
	}
	if(temp_info[playerid][MINEHIGH] == 1)
	{
	    temp_info[playerid][LOWWORK] = 0;
	    temp_info[playerid][MINEHIGH] = 0;
	    if(temp_info[playerid][MINENUMBER] > 0)
		{
		    GiveMoney(playerid, temp_info[playerid][MINENUMBER]*3);
		}
		SaveLowWorkSkills(playerid);
		temp_info[playerid][MINEPROGRESS] = 0;
	    temp_info[playerid][MINENUMBER] = 0;
	}
	if(inadmcar[playerid] != -1)
    {
        DestroyVehicle(inadmcar[playerid]);
        inadmcar[playerid] = -1;
    }
    SavePlayerInventory(playerid);
	return 1;
}

stock DestroyTD(playerid)
{
    TextDrawHideForPlayer(playerid, GraphicPIN_TD);
    PlayerTextDrawDestroy(playerid, GraphicPIN_PTD[playerid][0]);
    PlayerTextDrawDestroy(playerid, GraphicPIN_PTD[playerid][1]);
    PlayerTextDrawDestroy(playerid, GraphicPIN_PTD[playerid][2]);
    PlayerTextDrawDestroy(playerid, GraphicPIN_PTD[playerid][3]);
    
    TextDrawHideForPlayer(playerid, ServerLogo_TD[0]);
	TextDrawHideForPlayer(playerid, ServerLogo_TD[1]);

    TextDrawHideForPlayer(playerid, Mine_TD[0]);
    TextDrawHideForPlayer(playerid, Mine_TD[1]);
    TextDrawHideForPlayer(playerid, Mine_TD[2]);
    TextDrawHideForPlayer(playerid, Mine_TD[3]);
    TextDrawHideForPlayer(playerid, Mine_TD[4]);
    PlayerTextDrawDestroy(playerid, MineMoney_PTD[playerid]);
    PlayerTextDrawDestroy(playerid, MineAmount_PTD[playerid]);
}

public OnPlayerSpawn(playerid)
{
	if(GetPVarInt(playerid, "logged") == 0)
	{
	    SCMError(playerid, !"[������] {FFFFFF}��� ���� �� ������� �� ������ ��������������");
		return Kick(playerid);
	}
	SetPlayerColor(playerid, 0xFFFFFF60);
	PreloadAnim(playerid);
	SetPlayerSkin(playerid, player_info[playerid][SKIN]);
	SetPlayerScore(playerid, player_info[playerid][LVL]);
	/*switch(random(2))
	{
	    case 0:
	    {
	        SetPlayerPos(playerid, 1432.6733,2653.3237,11.3926);
	        SetPlayerFacingAngle(playerid, 180.0);
	    }
	    case 1:
	    {
	        SetPlayerPos(playerid, 1433.3832,2620.2297,11.3926);
	        SetPlayerFacingAngle(playerid, 360.0);
	    }
	}*/
	SetCameraBehindPlayer(playerid);
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    PlayerAFK[playerid] = -2;
	return 1;
}

public OnVehicleSpawn(vehicleid)
{
    SetVehicleHealth(vehicleid, 1500);
	return 1;
}

public OnVehicleDeath(vehicleid, killerid)
{
	return 1;
}

public OnPlayerText(playerid, text[])
{
    if(GetPVarInt(playerid, "logged") == 0)
	{
	    SCMError(playerid, !"[������] {FFFFFF}��� ��������� ��������� � ���� �� ������ ��������������");
	    Kick(playerid);
		return 0;
	}
	new string[144];
	if(strlen(text) < 113)
	{
		format(string, sizeof(string), "%s[%d]: %s", pName(playerid), playerid, text);
		ProxDetector(20.0, playerid, string, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE);
		SetPlayerChatBubble(playerid, text, COLOR_WHITE, 20, 7500);
		if(GetPlayerState(playerid) == PLAYER_STATE_ONFOOT)
		{
		    ApplyAnimation(playerid, "PED", "IDLE_chat", 4.1, 0, 1, 1, 1, 1);
		    SetTimerEx("StopChatAnim", 3200, false, "d", playerid);
		}
	}
	else
	{
	    SCM(playerid, COLOR_GREY, !"������� ������� ���������");
	    return 0;
	}
	return 0;
}

forward StopChatAnim(playerid);
public StopChatAnim(playerid)
{
	ApplyAnimation(playerid, "PED", "facanger", 4.1, 0, 1, 1, 1, 1);
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	return 0;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
	return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
	return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
	if(oldstate == PLAYER_STATE_DRIVER)
	{
	    if(inadmcar[playerid] != -1)
	    {
	        DestroyVehicle(inadmcar[playerid]);
	        inadmcar[playerid] = -1;
	    }
	}
    
	return 1;
}

forward StopMine(playerid);
public StopMine(playerid)
{
 	ClearAnimations(playerid);
    TogglePlayerControllable(playerid, 1);
	if(temp_info[playerid][MINELOW] == 1)
	{
	    SetPlayerCheckpoint(playerid, -758.1867,-1794.3585,-39.0421-1.0, 2.0);
	    temp_info[playerid][MINEPROGRESS] = 1;
	}
	if(temp_info[playerid][MINEHIGH] == 1)
	{
	    SetPlayerCheckpoint(playerid, -764.2901,-1783.2814,-89.0200-1.0, 2.0);
	    temp_info[playerid][MINEPROGRESS] = 2;
	}
}

stock UpdateMineProgress(playerid, ruda)
{
    new buffer[8];
    format(buffer, sizeof(buffer), "%d kg", ruda);
    PlayerTextDrawSetString(playerid, MineAmount_PTD[playerid], buffer);
    if(temp_info[playerid][MINELOW] == 1) format(buffer, sizeof(buffer), "%d$", ruda*2);
	else if(temp_info[playerid][MINEHIGH] == 1) format(buffer, sizeof(buffer), "%d$", ruda*3);
    PlayerTextDrawSetString(playerid, MineMoney_PTD[playerid], buffer);
}

public OnPlayerEnterCheckpoint(playerid)
{
    if(temp_info[playerid][MINELOW] == 1 || temp_info[playerid][MINEHIGH] == 1)
	{
	    if(temp_info[playerid][MINEPROGRESS] == 0)
	    {
	        DisablePlayerCheckpoint(playerid);
		    SetTimerEx("StopMine", 15000, false, "d", playerid);
		    TogglePlayerControllable(playerid, 0);
		    ApplyAnimation(playerid, "BASEBALL", "Bat_4", 4.1, 1, 0, 0, 0, 15000, 1);
	    }
	    else if(temp_info[playerid][MINEPROGRESS] == 1) //����� ����� ������� ���������
	    {
	        DisablePlayerCheckpoint(playerid);
	        new number = 5+(random(6));
	        temp_info[playerid][MINENUMBER]+=number;
	        AddStorage(1, number);
	        UpdateMineProgress(playerid, temp_info[playerid][MINENUMBER]);
	        player_info[playerid][LOWWORKSKILL][0]+=number;
		    ApplyAnimation(playerid, "CARRY", "PUTDWN", 4.0, 0, 0, 0, 0, 0, 1);
		    switch(random(4))
			{
			    case 0: SetPlayerCheckpoint(playerid, -732.7345,-1816.6523,-39.0421-1.0, 2.0);
			    case 1: SetPlayerCheckpoint(playerid, -727.9667,-1816.1974,-39.0421-1.0, 2.0);
			    case 2: SetPlayerCheckpoint(playerid, -724.5775,-1815.4325,-39.0421-1.0, 2.0);
			    case 3: SetPlayerCheckpoint(playerid, -724.8226,-1813.5508,-39.0421-1.0, 2.0);
			}
	        temp_info[playerid][MINEPROGRESS] = 0;
	    }
	    else if(temp_info[playerid][MINEPROGRESS] == 2) //����� ����� ��������� ���������
	    {
	        DisablePlayerCheckpoint(playerid);
	        new number = 5+(random(6));
	        temp_info[playerid][MINENUMBER]+=number;
	        AddStorage(3, number);
	        UpdateMineProgress(playerid, temp_info[playerid][MINENUMBER]);
	        player_info[playerid][LOWWORKSKILL][0]+=number;
	        ApplyAnimation(playerid, "CARRY", "PUTDWN", 4.0, 0, 0, 0, 0, 0, 1);
		    switch(random(3))
			{
			    case 0: SetPlayerCheckpoint(playerid, -801.7944,-1794.7133,-89.0200-1.0, 2.0);
			    case 1: SetPlayerCheckpoint(playerid, -799.5901,-1796.3623,-89.0200-1.0, 2.0);
			    case 2: SetPlayerCheckpoint(playerid, -799.8171,-1798.7997,-89.0200-1.0, 2.0);
			}
	        temp_info[playerid][MINEPROGRESS] = 0;
	    }
	}
	return 1;
}

public OnPlayerLeaveCheckpoint(playerid)
{
	return 1;
}

public OnPlayerEnterRaceCheckpoint(playerid)
{
	return 1;
}

public OnPlayerLeaveRaceCheckpoint(playerid)
{
	return 1;
}

public OnPlayerEnterDynamicCP(playerid, checkpointid)
{
	return 1;
}
public OnPlayerLeaveDynamicCP(playerid, checkpointid)
{
	return 1;
}
public OnPlayerEnterDynamicRaceCP(playerid, checkpointid)
{
	return 1;
}
public OnPlayerLeaveDynamicRaceCP(playerid, checkpointid)
{
	return 1;
}

public OnRconCommand(cmd[])
{
	return 1;
}

public OnPlayerRequestSpawn(playerid)
{
    SetPlayerSkin(playerid, player_info[playerid][SKIN]);
	return 1;
}

public OnObjectMoved(objectid)
{
	return 1;
}

public OnPlayerObjectMoved(playerid, objectid)
{
	return 1;
}

public OnDynamicObjectMoved(objectid)
{
	if(objectid == minefirstlift[0])
	{
	    new Float:pos_z;
	    Streamer_GetFloatData(STREAMER_TYPE_OBJECT, objectid, E_STREAMER_Z, pos_z);
	    if(pos_z > 0)
	    {
	        MoveDynamicObject(minefirstlift[1], -771.5177, -1786.4376, 14.2662, 0.7);
    		SetTimer("MineFirstLiftUpDoorsOpen", 5000, false);
	    }
		else
		{
		    MoveDynamicObject(minefirstlift[2], -771.5177, -1786.4376, -37.3100, 0.7);
    		SetTimer("MineFirstLiftDownDoorsOpen", 5000, false);
		}
	}
	else if(objectid == minesecondlift[0])
	{
	    new Float:pos_z;
	    Streamer_GetFloatData(STREAMER_TYPE_OBJECT, objectid, E_STREAMER_Z, pos_z);
	    if(pos_z > 0)
	    {
	        MoveDynamicObject(minesecondlift[1], -749.9438, -1776.8419, 14.2662, 0.7);
    		SetTimer("MineSecondLiftUpDoorsOpen", 5000, false);
	    }
		else
		{
		    MoveDynamicObject(minesecondlift[2], -749.9438, -1776.8419, -87.3062, 0.7);
    		SetTimer("MineSecondLiftDownDoorsOpen", 5000, false);
		}
	}
	return 1;
}

public OnPlayerPickUpDynamicPickup(playerid, STREAMER_TAG_PICKUP pickupid)
{
    if(!IsValidDynamicPickup(pickupid) || pPickupID[playerid]) return 0;
    pPickupID[playerid] = pickupid;
	if(pickupid == Pmine[0])
	{
	    if(temp_info[playerid][MINELOW] == 1)
		{
		    if(IsPlayerAttachedObjectSlotUsed(playerid, 9)) return SCM(playerid, COLOR_GREY, !"������� �������� ���������� �� �����!");
			SPD(playerid, DLG_MINELOWLEFT, DIALOG_STYLE_MSGBOX, !"{ff9300}���������� ������", !"{FFFFFF}�� ������ ��������� ������?", !"��", !"���");
		}
	    else
	    {
	        if(temp_info[playerid][LOWWORK] == 1) return SCM(playerid, COLOR_GREY, !"�� ��� ��������� � ������ �����!");
	        SPD(playerid, DLG_MINELOWJOIN, DIALOG_STYLE_MSGBOX, !"{ff9300}���������� �� ������ �������", !"{FFFFFF}�� ������ ���������� �� ������ ������� �������?", !"��", !"���");
	    }
	}
	else if(pickupid == Pmine[1])
	{
	    if(temp_info[playerid][MINELOW] == 1)
		{
			if(IsPlayerAttachedObjectSlotUsed(playerid, 9))
			{
		    	RemovePlayerAttachedObject(playerid, 9);
		    	DisablePlayerCheckpoint(playerid);
		    }
		    else
		    {
		        SetPlayerAttachedObject(playerid, 9, 18634, 6, 0.112000, 0.022000, 0.181000, 91.799827, -81.699905, 5.900005, 1.000000, 1.000000, 1.000000, 0, 0);
				switch(random(4))
				{
				    case 0: SetPlayerCheckpoint(playerid, -732.7345,-1816.6523,-39.0421-1.0, 2.0);
				    case 1: SetPlayerCheckpoint(playerid, -727.9667,-1816.1974,-39.0421-1.0, 2.0);
				    case 2: SetPlayerCheckpoint(playerid, -724.5775,-1815.4325,-39.0421-1.0, 2.0);
				    case 3: SetPlayerCheckpoint(playerid, -724.8226,-1813.5508,-39.0421-1.0, 2.0);
				}
				SCM(playerid, COLOR_LIGHTBLUE, !"�������� � ������������� ��� ������ ����.");
		    }
		}
		else SCM(playerid, COLOR_GREY, !"��� ������ ����������� �� ������ ���� �������");
	}
	else if(pickupid == Pmine[2])
	{
	    if(player_info[playerid][LOWWORKSKILL][0] < 5000) return SCM(playerid, COLOR_GREY, !"��� ���������� ������ �����. ������� ����������� ������� (�������� ����� 5000��)");
	    if(temp_info[playerid][MINEHIGH] == 1)
		{
		    if(IsPlayerAttachedObjectSlotUsed(playerid, 9)) return SCM(playerid, COLOR_GREY, !"������� �������� ���������� �� �����!");
		    SPD(playerid, DLG_MINEHIGHLEFT, DIALOG_STYLE_MSGBOX, !"{ff9300}���������� ������", !"{FFFFFF}�� ������ ��������� ������?", !"��", !"���");
		}
	    else
	    {
	        if(temp_info[playerid][LOWWORK] == 1) return SCM(playerid, COLOR_GREY, !"�� ��� ��������� � ������ �����!");
	        SPD(playerid, DLG_MINEHIGHJOIN, DIALOG_STYLE_MSGBOX, !"{ff9300}���������� �� ������ ����������� �������", !"{FFFFFF}�� ������ ���������� �� ������ ����������� �������?", !"��", !"���");
	    }
	}
	else if(pickupid == Pmine[3])
	{
	    if(temp_info[playerid][MINEHIGH] == 1)
	    {
		    if(IsPlayerAttachedObjectSlotUsed(playerid, 9))
			{
		    	RemovePlayerAttachedObject(playerid, 9);
		    	DisablePlayerCheckpoint(playerid);
		    }
		    else
		    {
		        SetPlayerAttachedObject(playerid, 9, 18634, 6, 0.112000, 0.022000, 0.181000, 91.799827, -81.699905, 5.900005, 1.000000, 1.000000, 1.000000, 0, 0);
		        switch(random(3))
				{
				    case 0: SetPlayerCheckpoint(playerid, -801.7944,-1794.7133,-89.0200-1.0, 2.0);
				    case 1: SetPlayerCheckpoint(playerid, -799.5901,-1796.3623,-89.0200-1.0, 2.0);
				    case 2: SetPlayerCheckpoint(playerid, -799.8171,-1798.7997,-89.0200-1.0, 2.0);
				}
				SCM(playerid, COLOR_LIGHTBLUE, !"�������� � ������������� ��� ������ ����.");
		    }
		}
		else SCM(playerid, COLOR_GREY, !"��� ������ ����������� �� ������ ���� �������");
	}
	/*
	
	temp_info[playerid][LOWWORK] = 1;
 	temp_info[playerid][MINELOW] = 1;
 	
	if(pickupid == )
	{
	}
	*/
	return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
    if(pickupid == mineenter)
	{
	    SetPlayerPos(playerid, -769.7730,-1792.7549,13.9054);
	    SetPlayerFacingAngle(playerid, 0.0);
	    SetPlayerVirtualWorld(playerid, 1);
	    SetPlayerInterior(playerid, 1);
	    SetCameraBehindPlayer(playerid);
	    LoadInterior(playerid);
	}
	else if(pickupid == mineexit)
	{
	    SetPlayerPos(playerid, -777.2842,-1856.8042,11.8699);
	    SetPlayerFacingAngle(playerid, 200.0);
	    SetPlayerVirtualWorld(playerid, 0);
	    SetPlayerInterior(playerid, 0);
	    SetCameraBehindPlayer(playerid);
	}
	return 1;
}

forward LoadInterior(playerid);
public LoadInterior(playerid)
{
	TogglePlayerControllable(playerid, 0);
	TextDrawShowForPlayer(playerid, IntLoad_TD[0]);
	TextDrawShowForPlayer(playerid, IntLoad_TD[1]);
	TextDrawShowForPlayer(playerid, IntLoad_TD[2]);
	TextDrawShowForPlayer(playerid, IntLoad_TD[3]);
	new interval;
	if(GetPlayerPing(playerid) > 500) interval = 3500;
	else if(GetPlayerPing(playerid) > 200) interval = 2500;
	else if(GetPlayerPing(playerid) > 100) interval = 2000;
	else if(GetPlayerPing(playerid) > 0) interval = 1500;
	SetTimerEx("LoadInteriorNext", interval, false, "d", playerid);
}

forward LoadInteriorNext(playerid);
public LoadInteriorNext(playerid)
{
    TextDrawHideForPlayer(playerid, IntLoad_TD[3]);
    TextDrawShowForPlayer(playerid, IntLoad_TD[4]);
    new interval;
	if(GetPlayerPing(playerid) > 500) interval = 3500;
	else if(GetPlayerPing(playerid) > 200) interval = 2500;
	else if(GetPlayerPing(playerid) > 100) interval = 2000;
	else if(GetPlayerPing(playerid) > 0) interval = 1500;
	SetTimerEx("LoadInteriorFinished", interval, false, "d", playerid);
	return 1;
}

forward LoadInteriorFinished(playerid);
public LoadInteriorFinished(playerid)
{
    TextDrawHideForPlayer(playerid, IntLoad_TD[0]);
	TextDrawHideForPlayer(playerid, IntLoad_TD[1]);
	TextDrawHideForPlayer(playerid, IntLoad_TD[2]);
	TextDrawHideForPlayer(playerid, IntLoad_TD[4]);
	TogglePlayerControllable(playerid, 1);
	return 1;
}

public OnVehicleMod(playerid, vehicleid, componentid)
{
	return 1;
}

public OnVehiclePaintjob(playerid, vehicleid, paintjobid)
{
	return 1;
}

public OnVehicleRespray(playerid, vehicleid, color1, color2)
{
	return 1;
}

public OnPlayerSelectedMenuRow(playerid, row)
{
	return 1;
}

public OnPlayerExitedMenu(playerid)
{
	return 1;
}

public OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid)
{
	return 1;
}
//2342.0417,1554.0525,10.8203 - ����� �����
public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
    if(newkeys == KEY_WALK)//������ Alt
	{
	    if(IsPlayerInRangeOfPoint(playerid, 1.5, 2342.0417,1554.0525,10.8203)) //���� � �����
	    {
		    SetPlayerPos(playerid,1482.1394, -1780.5322, 2981.3540); //�� �� ������ ���� �����
	     	SetPlayerInterior(playerid, 1);
	     	LoadInterior(playerid);
		}
		if(IsPlayerInRangeOfPoint(playerid, 1.5, 1482.1394, -1780.5322, 2981.3540)) //����� �� �����
	    {
		    SetPlayerPos(playerid, 2342.0417,1554.0525,10.8203); //�� �� �����
	     	SetPlayerInterior(playerid, 0);
	     	LoadInterior(playerid);
		}
		if(IsPlayerInRangeOfPoint(playerid, 1.5, 1493.3627, -1791.1742, 2981.3540)) //���� ������� ����� ������
		{
            SPD(playerid, DLG_MAYOR_LIFT_1, DIALOG_STYLE_LIST, !"{FFFFFF}����{FFFFFF} � 1 ����", !"2 ����\n3 ����\n", !"�������", !"������");
		}
		if(IsPlayerInRangeOfPoint(playerid, 1.5, 1492.2074, -1786.5863, 2676.0129)) //���� ������� ����� ������
		{
            SPD(playerid, DLG_MAYOR_LIFT_2, DIALOG_STYLE_LIST, !"{FFFFFF}����{FFFFFF} � 2 ����", !"1 ����\n3 ����\n", !"�������", !"������");
		}
		if(IsPlayerInRangeOfPoint(playerid, 1.5, 1483.1909, -1848.8917, 3645.6270)) //���� �������� ����� ������
		{
            SPD(playerid, DLG_MAYOR_LIFT_3, DIALOG_STYLE_LIST, !"{FFFFFF}����{FFFFFF} � 3 ����", !"1 ����\n2 ����\n", !"�������", !"������");
		}
 	}
    if(newkeys == KEY_YES)//������ H
	{
	    ShowPlayerInventory(playerid);
	}
	if(newkeys == KEY_CTRL_BACK)//������ H
	{
		if(GetPlayerVirtualWorld(playerid) == 1)
		{
			if(IsPlayerInRangeOfPoint(playerid, 1.5, -769.2567,-1783.8904,13.9054)) //������ ����������� ����� ����� ������
			{
				if(minefirstlift[3] == 1) return SCM(playerid, COLOR_GREY, !"���� ��� ��������� �� ����� ������.");
				if(minefirstlift[3] == 2) return SCM(playerid, COLOR_GREY, !"���� ��� � ����.");
				if(minefirstlift[3] == 3)
				{
				    MoveDynamicObject(minefirstlift[2], -769.6777, -1783.7776, -37.3100, 0.7);
        			minefirstlift[3] = 2;
				    SetTimer("MineFirstLiftUp", 5000, false);
				    SCM(playerid, COLOR_LIGHTBLUE, !"�� ������� ����. ��������!");
				    SetPlayerFacingAngle(playerid, 36.0);
				    ApplyAnimation(playerid, "CRIB", "CRIB_Use_Switch", 4.0,0,0,0,0,0, 1);
				    PlayerPlaySound(playerid, 4203, 0.0, 0.0, 0.0);
				}
			}
			else if(IsPlayerInRangeOfPoint(playerid, 1.5, -768.4301,-1784.1610,-39.0421)) //������ ����������� ����� ����� �����
			{
			    if(minefirstlift[3] == 2) return SCM(playerid, COLOR_GREY, !"���� ��� � ����.");
				if(minefirstlift[3] == 3) return SCM(playerid, COLOR_GREY, !"���� ��� ��������� �� ����� ������.");
			    if(minefirstlift[3] == 1)
			    {
			        MoveDynamicObject(minefirstlift[1], -769.6777, -1783.7776, 14.2662, 0.7);
        			minefirstlift[3] = 2;
			        SetTimer("MineFirstLiftDown", 5000, false);
			        SCM(playerid, COLOR_LIGHTBLUE, !"�� ������� ����. ��������!");
			        SetPlayerFacingAngle(playerid, 356.0);
				    ApplyAnimation(playerid, "CRIB", "CRIB_Use_Switch", 4.0,0,0,0,0,0, 1);
				    PlayerPlaySound(playerid, 4203, 0.0, 0.0, 0.0);
				}
			}
			else if(IsPlayerInRangeOfPoint(playerid, 1.5, -749.7958,-1779.8812,13.9060)) //������ ��������� ����� ����� ������
			{
				if(player_info[playerid][LOWWORKSKILL][0] < 5000) return SCM(playerid, COLOR_GREY, !"��� ���������� ������ �����. ������� ����������� ������� (�������� ����� 5000��)");
			    if(minesecondlift[3] == 1) return SCM(playerid, COLOR_GREY, !"���� ��� ��������� �� ����� ������.");
				if(minesecondlift[3] == 2) return SCM(playerid, COLOR_GREY, !"���� ��� � ����.");
				if(minesecondlift[3] == 3)
				{
				    MoveDynamicObject(minesecondlift[2], -748.9438, -1779.9019, -87.3062, 0.7);
        			minesecondlift[3] = 2;
				    SetTimer("MineSecondLiftUp", 5000, false);
				    SCM(playerid, COLOR_LIGHTBLUE, !"�� ������� ����. ��������!");
				    SetPlayerFacingAngle(playerid, 210.0);
				    ApplyAnimation(playerid, "CRIB", "CRIB_Use_Switch", 4.0,0,0,0,0,0, 1);
				    PlayerPlaySound(playerid, 4203, 0.0, 0.0, 0.0);
				}
			}
			else if(IsPlayerInRangeOfPoint(playerid, 1.5, -750.0234,-1780.4724,-89.0200)) //������ ��������� ����� ����� �����
			{
			    if(player_info[playerid][LOWWORKSKILL][0] < 5000) return SCM(playerid, COLOR_GREY, !"��� ���������� ������ �����. ������� ����������� ������� (�������� ����� 5000��)");
			    if(minesecondlift[3] == 2) return SCM(playerid, COLOR_GREY, !"���� ��� � ����.");
				if(minesecondlift[3] == 3) return SCM(playerid, COLOR_GREY, !"���� ��� ��������� �� ����� ������.");
			    if(minesecondlift[3] == 1)
			    {
			        MoveDynamicObject(minesecondlift[1], -748.9438, -1779.9019, 14.2662, 0.7);
        			minesecondlift[3] = 2;
			        SetTimer("MineSecondLiftDown", 5000, false);
			        SCM(playerid, COLOR_LIGHTBLUE, !"�� ������� ����. ��������!");
			        SetPlayerFacingAngle(playerid, 238.0);
				    ApplyAnimation(playerid, "CRIB", "CRIB_Use_Switch", 4.0,0,0,0,0,0, 1);
				    PlayerPlaySound(playerid, 4203, 0.0, 0.0, 0.0);
				}
			}
		}
	}
	if(newkeys == KEY_JUMP)//������ ������
	{
	    if(GetPlayerVirtualWorld(playerid) == 1)
	    {
		    if(IsPlayerInDynamicArea(playerid, nojump[0]) || IsPlayerInDynamicArea(playerid, nojump[1]))
		    {
    			ClearAnimations(playerid);
		    }
	    }
	}
	return 1;
}

public OnRconLoginAttempt(ip[], password[], success)
{
	return 1;
}

public OnPlayerUpdate(playerid)
{
	if(PlayerAFK[playerid] >= 2)
	{
	    ClearAnimations(playerid);
	}
    if(pPickupID[playerid])
    {
        new pickupid = pPickupID[playerid];
        if(!IsValidDynamicPickup(pickupid)) pPickupID[playerid] = 0;
        else
        {
            new Float:pos_x, Float:pos_y, Float:pos_z;
            Streamer_GetFloatData(STREAMER_TYPE_PICKUP, pickupid, E_STREAMER_X, pos_x);
            Streamer_GetFloatData(STREAMER_TYPE_PICKUP, pickupid, E_STREAMER_Y, pos_y);
            Streamer_GetFloatData(STREAMER_TYPE_PICKUP, pickupid, E_STREAMER_Z, pos_z);
            if(!IsPlayerInRangeOfPoint(playerid, 2.0, pos_x, pos_y, pos_z)) pPickupID[playerid] = 0;
        }
    }
    PlayerAFK[playerid] = 0;
    if(GetPlayerInterior(playerid) != 0) SetPlayerWeather(playerid,1);
	else SetPlayerWeather(playerid, weather);
	return 1;
}

public OnPlayerStreamIn(playerid, forplayerid)
{
	return 1;
}

public OnPlayerStreamOut(playerid, forplayerid)
{
	return 1;
}

public OnVehicleStreamIn(vehicleid, forplayerid)
{
	return 1;
}

public OnVehicleStreamOut(vehicleid, forplayerid)
{
	return 1;
}

/*case 1: {
	        SetPlayerPos(playerid,1482.1394, -1780.5322, 2981.3540); //�� �� ������ ����
	        SetPlayerInterior(playerid, 1);
	        return 1;
    	}
    	case 2: {
	        SetPlayerPos(playerid,1492.2074,-1786.5863,2676.0129); //�� �� ������ ����
        	SetPlayerInterior(playerid, 1);
	        return 1;
    	}
    	case 3: {
	        SetPlayerPos(playerid,1483.1909, -1848.8917, 3645.6270); //�� �� ������ ����
        	SetPlayerInterior(playerid, 1);
	        return 1;
    	}*/
    	
public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	new str_len = strlen(inputtext);
	switch(dialogid)
	{
	    case DLG_MAYOR_LIFT_1: {
	        if(response)
	        {
	            switch(listitem)
	            {
	                case 0: {
                        SetPlayerPos(playerid,1492.2074,-1786.5863,2676.0129);
	        			SetPlayerInterior(playerid, 1);
	                }
	                case 1: {
                        SetPlayerPos(playerid,1483.1909, -1848.8917, 3645.6270);
        				SetPlayerInterior(playerid, 1);
	                }
	            }
	        }
	    }
	    case DLG_MAYOR_LIFT_2: {
	        if(response)
	        {
	            switch(listitem)
	            {
	                case 0: {
                        SetPlayerPos(playerid,1493.3627, -1791, 2981.3540); //�� �� ������ ����
	        			SetPlayerInterior(playerid, 1);
	                }
	                case 1: {
                        SetPlayerPos(playerid,1483.1909, -1848.8917, 3645.6270); //�� �� ������ ����
       					SetPlayerInterior(playerid, 1);
	                }
	            }
	        }
	    }
	    case DLG_MAYOR_LIFT_3: {
	        if(response)
	        {
	            switch(listitem)
	            {
	                case 0: {
                        SetPlayerPos(playerid,1493.3627, -1791, 2981.3540); //�� �� ������ ����
	        			SetPlayerInterior(playerid, 1);
	                }
	                case 1: {
                        SetPlayerPos(playerid,1492.2074,-1786.5863,2676.0129); //�� �� ������ ����
        				SetPlayerInterior(playerid, 1);
	                }
	            }
	        }
	    }
	    case DLG_WEAPON:
	    {
	        if(response && str_len)
	        {
	            new count;
				if(sscanf(inputtext, "d", count)) return 1;
				new ammo = strval(inputtext);
				if(count > GetPlayerInventoryAmount(playerid, GetPVarInt(playerid, "weapon_itemid")) || count < 1) return 1;
  		 		if(GetPVarInt(playerid, "weapon_itemid") >= 312 && GetPVarInt(playerid, "weapon_itemid") <= 330) GivePlayerWeapon(playerid, GetPVarInt(playerid, "weapon_itemid")-311, ammo);
  		 		if(GetPVarInt(playerid, "weapon_itemid") >= 331 && GetPVarInt(playerid, "weapon_itemid") <= 355) GivePlayerWeapon(playerid, GetPVarInt(playerid, "weapon_itemid")-309, ammo);
        		RemoveInventoryItem(playerid, GetPVarInt(playerid, "weapon_itemid"), ammo);

			}
		}
	    case DLG_REG:
	    {
	        if(response)
	        {
	            if(!str_len)
	            {
	                ShowRegistration(playerid);
	                return SCMError(playerid, !"[������] {FFFFFF}������� ������ � ���� ���� � ������� \"�����\"");
	            }
	            if(!(8 <= str_len <= 32))
	            {
	                ShowRegistration(playerid);
	                return SCMError(playerid, !"[������] {FFFFFF}����� ������ ������ ���� �� 8-�� �� 32-�� ��������");
	            }
	            new regex:rg_passwordcheck = regex_new("^[a-zA-Z0-9]{1,}$");
	            if(regex_check(inputtext, rg_passwordcheck))
	            {
					new salt[11];
					for(new i; i < 10; i++)
					{
					    salt[i] = random(43) + 48;
					}
					salt[10] = 0;
					SHA256_PassHash(inputtext, salt, player_info[playerid][PASSWORD], 65);
					strmid(player_info[playerid][SALT], salt, 0, 11, 11);
					SPD(playerid, DLG_REGEMAIL, DIALOG_STYLE_INPUT, !"{ff9300}�����������{FFFFFF} � ���� Email",
				 		!"{FFFFFF}\t\t\t������� ��� ��������� Email �����\n\
				 		���� �� ��������� ������ � ��������, �� �� ������� ������������ ��� ����� Email\n\
						\t\t������� ��� Email � ���� ���� � ������� \"�����\"",
					!"�����", "");
	            }
	            else
	            {
	                ShowRegistration(playerid);
	                regex_delete(rg_passwordcheck);
	                return SCMError(playerid, !"[������] {FFFFFF}������ ����� �������� ������ �� ����� � ��������� �������� ������ ��������");
	            }
	            regex_delete(rg_passwordcheck);
	        }
	        else
	        {
	            SCM(playerid, COLOR_RED, !"����������� \"/q\", ����� �������� ������");
				return Kick(playerid);
	        }
	    }
	    case DLG_REGEMAIL:
	    {
	        if(!str_len)
            {
                SPD(playerid, DLG_REGEMAIL, DIALOG_STYLE_INPUT, !"{ff9300}�����������{FFFFFF} � ���� Email",
			 		!"{FFFFFF}\t\t\t������� ��� ��������� Email �����\n\
			 		���� �� ��������� ������ � ��������, �� �� ������� ������������ ��� ����� Email\n\
					\t\t������� ��� Email � ���� ���� � ������� \"�����\"",
				!"�����", "");
				return SCMError(playerid, !"[������] {FFFFFF}������� ��� Email � ���� ���� � ������� \"�����\"");
            }
            new regex:rg_emailcheck = regex_new("^[a-zA-Z0-9.-_]{1,43}@[a-zA-Z]{1,12}\\.[a-zA-Z]{1,8}$");
            if(regex_check(inputtext, rg_emailcheck))
            {
                strmid(player_info[playerid][EMAIL], inputtext, 0, str_len, 64);
                SPD(playerid, DLG_REGREF, DIALOG_STYLE_INPUT, !"{ff9300}�����������{FFFFFF} � ���� �������������",
					!"{FFFFFF}���� �� ����� �� ������ �� �����������, ��\n\
					������ ������� ��� ������������� � ���� ����:",
				!"�����", !"����������");
            }
            else
            {
                SPD(playerid, DLG_REGEMAIL, DIALOG_STYLE_INPUT, !"{ff9300}�����������{FFFFFF} � ���� Email",
			 		!"{FFFFFF}\t\t\t������� ��� ��������� Email �����\n\
			 		���� �� ��������� ������ � ��������, �� �� ������� ������������ ��� ����� Email\n\
					\t\t������� ��� Email � ���� ���� � ������� \"�����\"",
				!"�����", "");
				regex_delete(rg_emailcheck);
                return SCMError(playerid, !"[������] {FFFFFF}������� ��������� ��� Email �����");
            }
            regex_delete(rg_emailcheck);
	    }
	    case DLG_REGREF:
	    {
	        if(response)
	        {
				static const fmt_query[] = "SELECT * FROM `users` WHERE `name` = '%e'";
				new query[sizeof(fmt_query)+(-2+MAX_PLAYER_NAME)];
				mysql_format(dbHandle, query, sizeof(query), fmt_query, inputtext);
				mysql_tquery(dbHandle, query, "CheckReferal", "is", playerid, inputtext);
	        }
	        else
	        {
	            SPD(playerid, DLG_REGSEX, DIALOG_STYLE_MSGBOX, !"{ff9300}�����������{FFFFFF} � ����� ���� ���������",
					!"{FFFFFF}�������� ��� ������ �������� ���������:",
				!"�������", !"�������");
	        }
	    }
	    case DLG_REGSEX:
	    {
			player_info[playerid][SEX] = (response) ? (1) : (2);
	        SPD(playerid, DLG_REGRACE, DIALOG_STYLE_LIST, !"{ff9300}�����������{FFFFFF} � ����� ���� ���������",
				!"����������\n\
				������������\n\
				������������/���������",
			!"�����", "");
	    }
	    case DLG_REGRACE:
	    {
	        player_info[playerid][RACE] = listitem+1;
	        SPD(playerid, DLG_REGAGE, DIALOG_STYLE_INPUT, !"{ff9300}�����������{FFFFFF} � ����� �������� ���������",
				!"{FFFFFF}������� ������� ������ �������� ���������:\n\
				{ff9300}\t� ������� ������� �� 18-�� �� 60-��",
			!"�����", "");
	    }
		case DLG_REGAGE:
		{
		    if(!str_len)
            {
                SPD(playerid, DLG_REGAGE, DIALOG_STYLE_INPUT, !"{ff9300}�����������{FFFFFF} � ����� �������� ���������",
					!"{FFFFFF}������� ������� ������ �������� ���������:\n\
					{ff9300}\t� ������� ������� �� 18-�� �� 60-��",
				!"�����", "");
				return SCMError(playerid, !"[������] {FFFFFF}������� ��� ������� � ���� ���� � ������� \"�����\"");
			}
			if(!(18 <= strval(inputtext) <= 60))
			{
			    SPD(playerid, DLG_REGAGE, DIALOG_STYLE_INPUT, !"{ff9300}�����������{FFFFFF} � ����� �������� ���������",
					!"{FFFFFF}������� ������� ������ �������� ���������:\n\
					{ff9300}\t� ������� ������� �� 18-�� �� 60-��",
				!"�����", "");
				return SCMError(playerid, !"[������] {FFFFFF}������� ������� �� 18-�� �� 60-��");
			}
			player_info[playerid][AGE] = strval(inputtext);
			/*��� ��� ������
			� ������� 3 ����, �� ������ �������� �������� - ���� �����
			����: ����������, ������������, ������������ (���������)
			���������: 18-29, 30-45, 46-60
			*/
			new regmaleskins[9][4] =
			{
				{19,21,22,28},//���������� 18-29
				{24,25,36,67},//���������� 30-45
				{14,142,182,183},//���������� 46-60
				{29,96,101,26},//������������ 18-29
				{2,37,72,202},// � �.�...
				{1,3,234,290},
				{23,60,170,180},
				{20,47,48,206},
				{44,58,132,229}
			};
			new regfemaleskins[9][2] = //���������� � ��������
			{
				{13,69},
				{9,190},
				{10,218},
				{41,56},
				{31,151},
				{39,89},
				{169,193},
				{207,225},
				{54,130}
			};
			new newskinindex;
			switch(player_info[playerid][RACE])
			{
				case 2: newskinindex+=3;
				case 3: newskinindex+=6;
			}
			switch(player_info[playerid][AGE])
			{
			    case 30..45: newskinindex++;
			    case 46..60: newskinindex+=2;
			}
			player_info[playerid][SKIN] = (player_info[playerid][SEX] == 1) ? (regmaleskins[newskinindex][random(4)]) : (regfemaleskins[newskinindex][random(2)]);
			new Year, Month, Day;
			getdate(Year, Month, Day);
			new date[13];
			format(date, sizeof(date), "%02d.%02d.%d", Day, Month, Year);
			new ip[16];
			GetPlayerIp(playerid, ip, sizeof(ip));
			static const fmt_query[] = "INSERT INTO `users` (`name`, `password`, `salt`, `email`, `ref`, `sex`, `race`, `age`, `skin`, `regdata`, `regip`) VALUES ('%e', '%e', '%e', '%e', '%d', '%d', '%d', '%d', '%d', '%e', '%e')";
			new query[sizeof(fmt_query)+(-2+MAX_PLAYER_NAME)+(-2+64)+(-2+10)+(-2+64)+(-2+8)+(-2+1)+(-2+1)+(-2+2)+(-2+3)+(-2+12)+(-2+15)];
			mysql_format(dbHandle, query, sizeof(query), fmt_query, pName(playerid), player_info[playerid][PASSWORD], player_info[playerid][SALT], player_info[playerid][EMAIL], player_info[playerid][REF], player_info[playerid][SEX], player_info[playerid][RACE], player_info[playerid][AGE], player_info[playerid][SKIN], date, ip);
			mysql_query(dbHandle, query, false);
		    PlayerGoLogin(playerid);
		}
		case DLG_LOG:
		{
		    if(response)
	        {
	            if(!str_len)
	            {
	                ShowLogin(playerid);
	                return 1;
	            }
	            new checkpass[65];
	            SHA256_PassHash(inputtext, player_info[playerid][SALT], checkpass, 65);
				if(strcmp(player_info[playerid][PASSWORD], checkpass, false, 64) == 0)
				{
				    if(player_info[playerid][PIN][0] != 0)
					{
						if(player_info[playerid][PIN][1] == 0)
						{
							if(CheckSubnet(playerid) == 1)//������� ���������
							{
							    if(strlen(player_info[playerid][GOOGLEAUTH]) > 2)
								{
								    if(player_info[playerid][GOOGLEAUTHSETTING] == 0)
									{
										if(CheckSubnet(playerid) == 1) PlayerGoLogin(playerid);
										else SPD(playerid, DLG_CHECKGOOGLEAUTH, DIALOG_STYLE_INPUT, !"{ff9300}Google Authenticator", !"{FFFFFF}������� ��� �� ���������� Google Authenticator � ���� ����:", !"�����", "");
									}
									else
									{
									    SPD(playerid, DLG_CHECKGOOGLEAUTH, DIALOG_STYLE_INPUT, !"{ff9300}Google Authenticator", !"{FFFFFF}������� ��� �� ���������� Google Authenticator � ���� ����:", !"�����", "");
									}
								}
								else PlayerGoLogin(playerid);
							}
							else
							{
                                TextDrawShowForPlayer(playerid, GraphicPIN_TD);
                                GeneratePinCheck(playerid, GetPVarInt(playerid, "pinpos"));
                                SelectTextDraw(playerid, 0x00000030);
							}
						    return 1;
						}
						else
						{
						    TextDrawShowForPlayer(playerid, GraphicPIN_TD);
							GeneratePinCheck(playerid, GetPVarInt(playerid, "pinpos"));
                            SelectTextDraw(playerid, 0x00000030);
							return 1;
						}
					}
				    if(strlen(player_info[playerid][GOOGLEAUTH]) > 2)
					{
					    if(player_info[playerid][GOOGLEAUTHSETTING] == 0)
						{
							if(CheckSubnet(playerid) == 1) PlayerGoLogin(playerid);
							else SPD(playerid, DLG_CHECKGOOGLEAUTH, DIALOG_STYLE_INPUT, !"{ff9300}Google Authenticator", !"{FFFFFF}������� ��� �� ���������� Google Authenticator � ���� ����:", !"�����", "");
						}
						else
						{
						    SPD(playerid, DLG_CHECKGOOGLEAUTH, DIALOG_STYLE_INPUT, !"{ff9300}Google Authenticator", !"{FFFFFF}������� ��� �� ���������� Google Authenticator � ���� ����:", !"�����", "");
						}
					}
					else PlayerGoLogin(playerid);
				}
				else
				{
				    new string[87];
				    SetPVarInt(playerid, "WrongPassword", GetPVarInt(playerid, "WrongPassword")-1);
				    if(GetPVarInt(playerid, "WrongPassword") > 0)
				    {
				    	format(string, sizeof(string), "[������] {FFFFFF}�� ����� �������� ������ �� ��������. � ��� �������� %d ������� �����.", GetPVarInt(playerid, "WrongPassword"));
				    	SCMError(playerid, string);
				    }
				    if(GetPVarInt(playerid, "WrongPassword") == 0)
				    {
				        SCMError(playerid, !"[������] {FFFFFF}�� ��������� ����� ������� ����� � ���� ��������� �� �������.");
				        SPD(playerid, -1, 0, " ", " ", " ", " ");
				        return Kick(playerid);
				    }
				    ShowLogin(playerid);
				}
		    }
	        else
	        {
	            SCM(playerid, COLOR_RED, !"����������� \"/q\", ����� �������� ������");
				return Kick(playerid);
	        }
		}
		case DLG_MAINMENU:
		{
		    if(response)
	        {
	            switch(listitem)
	            {
	                case 0: ShowStats(playerid, 0);
					case 1: SPD(playerid, DLG_SECURESETTINGS, DIALOG_STYLE_LIST, !"{ff9300}��������� ������������", !"�������� ������\n����������� PIN ���\nGoogle Authenticator", !"�������", !"�����");
					case 2: SPD(playerid, DLG_INFORMADM, DIALOG_STYLE_LIST, !"{ff9300}����� � ��������������", !"�������� {e93230}������\n������ {11dd77}������", !"�������", !"�����");
				}
	        }
		}
		case DLG_STATS:
		{
		    if(response) callcmd::menu(playerid);
		}
		case DLG_SECURESETTINGS:
		{
		    if(response)
	        {
	            switch(listitem)
	            {
	                case 0: SPD(playerid, DLG_NEWPASS1, DIALOG_STYLE_INPUT, !"{ff9300}��������� ������{FFFFFF} � ��� ������", !"{FFFFFF}������� ��� ������� ������ � ���� ����:", !"�����", !"�������");
	                case 1:
					{
					    new dialog[81];
					    format(dialog, sizeof(dialog),
							"���������� PIN ���\n\
							������� PIN ���\n\
							���������� PIN ��� %s",
						(player_info[playerid][PIN][1] == 0) ? ("{32CD32}[��� ����� IP]") : ("{0089ff}[������]"));
						SPD(playerid, DLG_SECRETPINCONTROL, DIALOG_STYLE_LIST, !"{ff9300}���������� ����������� PIN �����", dialog, !"�������", !"�������");
					}
					case 2:
					{
					    new dialog[120];
					    format(dialog, sizeof(dialog),
							"���������� Google Authenticator\n\
							������� Google Authenticator\n\
							���������� Google Authenticator %s",
						(player_info[playerid][GOOGLEAUTHSETTING] == 0) ? ("{32CD32}[��� ����� IP]") : ("{0089ff}[������]"));
						SPD(playerid, DLG_GOOGLEAUTHCONTROL, DIALOG_STYLE_LIST, !"{ff9300}���������� Google Authenticator", dialog, !"�������", !"�������");
					}
	            }
			}
			else callcmd::menu(playerid);
		}
		case DLG_NEWPASS1:
		{
		    if(response)
	        {
			    if(!str_len) return SPD(playerid, DLG_NEWPASS1, DIALOG_STYLE_INPUT, !"{ff9300}��������� ������{FFFFFF} � ��� ������", !"{FFFFFF}������� ��� ������� ������ � ���� ����:", !"�����", !"�������");
			    new checkpass[65];
	            SHA256_PassHash(inputtext, player_info[playerid][SALT], checkpass, 65);
				if(strcmp(player_info[playerid][PASSWORD], checkpass, false, 64) == 0)
				{
				    SPD(playerid, DLG_NEWPASS2, DIALOG_STYLE_INPUT, !"{ff9300}��������� ������{FFFFFF} � ��� ������", !"{FFFFFF}������� ��� ����� ������ � ���� ����:", !"���������", !"�������");
				}
				else
				{
	  				SCMError(playerid, !"[������] {FFFFFF}�� ����� �������� ������ �� ��������");
	  				return SPD(playerid, DLG_NEWPASS1, DIALOG_STYLE_INPUT, !"{ff9300}��������� ������{FFFFFF} � ��� ������", !"{FFFFFF}������� ��� ������� ������ � ���� ����:", !"�����", !"�������");
				}
			}
		}
		case DLG_NEWPASS2:
		{
		    if(response)
	        {
			    if(!str_len) return SPD(playerid, DLG_NEWPASS2, DIALOG_STYLE_INPUT, !"{ff9300}��������� ������{FFFFFF} � ��� ������", !"{FFFFFF}������� ��� ����� ������ � ���� ����:", !"���������", !"�������");
	            if(!(8 <= str_len <= 32))
	            {
	                SPD(playerid, DLG_NEWPASS2, DIALOG_STYLE_INPUT, !"{ff9300}��������� ������{FFFFFF} � ��� ������", !"{FFFFFF}������� ��� ����� ������ � ���� ����:", !"���������", !"�������");
	                return SCMError(playerid, !"[������] {FFFFFF}����� ������ ������ ���� �� 8-�� �� 32-�� ��������");
	            }
	            new regex:rg_passwordcheck = regex_new("^[a-zA-Z0-9]{1,}$");
	            if(regex_check(inputtext, rg_passwordcheck))
	            {
					new salt[11];
					for(new i; i < 10; i++)
					{
					    salt[i] = random(43) + 48;
					}
					salt[10] = 0;
					SHA256_PassHash(inputtext, salt, player_info[playerid][PASSWORD], 65);
					strmid(player_info[playerid][SALT], salt, 0, 11, 11);
					new string[51+(-2+32)];
					format(string, sizeof(string), "[�����������] {FFFFFF}��� ����� ������: {0089ff}%s", inputtext);
					SCMNotification(playerid, string);
					SCM(playerid, COLOR_NOTIFICATION, !"[�����������] {FFFFFF}�������� �������� ������� {0089ff}F8{FFFFFF} ��� �������� ����� ������");
					static const fmt_query[] = "UPDATE `users` SET `password` = '%e', `salt` = '%e' WHERE `id` = '%d'";
					new query[sizeof(fmt_query)+(-2+64)+(-2+10)+(-2+8)];
					mysql_format(dbHandle, query, sizeof(query), fmt_query, player_info[playerid][PASSWORD], player_info[playerid][SALT], player_info[playerid][ID]);
					mysql_tquery(dbHandle, query);
	            }
	            else
	            {
	                SPD(playerid, DLG_NEWPASS2, DIALOG_STYLE_INPUT, !"{ff9300}��������� ������{FFFFFF} � ��� ������", !"{FFFFFF}������� ��� ����� ������ � ���� ����:", !"���������", !"�������");
	                regex_delete(rg_passwordcheck);
	                return SCMError(playerid, !"[������] {FFFFFF}������ ����� �������� ������ �� ����� � ��������� �������� ������ ��������");
	            }
	            regex_delete(rg_passwordcheck);
			}
		}
		case DLG_SECRETPINCONTROL:
		{
		    if(response)
	        {
	            switch(listitem)
	            {
					case 0:
					{
					    if(player_info[playerid][PIN][0] != 0)
					    {
					        new dialog[81];
						    format(dialog, sizeof(dialog),
								"���������� PIN ���\n\
								������� PIN ���\n\
								���������� PIN ��� %s",
							(player_info[playerid][PIN][1] == 0) ? ("{32CD32}[��� ����� IP]") : ("{0089ff}[������]"));
							SPD(playerid, DLG_SECRETPINCONTROL, DIALOG_STYLE_LIST, !"{ff9300}���������� ����������� PIN �����", dialog, !"�������", !"�������");
							return SCMError(playerid, !"[������] {FFFFFF}� ��� ��� ���������� ����������� PIN ���");
					    }
						SPD(playerid, DLG_SECRETPINSET, DIALOG_STYLE_INPUT, !"{ff9300}��������� ������������ PIN ����{FFFFFF}", !"{FFFFFF}������� ��� ������� ����������� PIN ��� � ���� ����:\n\n����������: PIN ��� ������ ���� 4-�� ������� � �� ��������� �� 0", !"���������", !"�������");
					}
					case 1:
					{
					    if(player_info[playerid][PIN][0] == 0)
					    {
					        new dialog[81];
						    format(dialog, sizeof(dialog),
								"���������� PIN ���\n\
								������� PIN ���\n\
								���������� PIN ��� %s",
							(player_info[playerid][PIN][1] == 0) ? ("{32CD32}[��� ����� IP]") : ("{0089ff}[������]"));
							SPD(playerid, DLG_SECRETPINCONTROL, DIALOG_STYLE_LIST, !"{ff9300}���������� ����������� PIN �����", dialog, !"�������", !"�������");
							return SCMError(playerid, !"[������] {FFFFFF}� ��� �� ���������� ����������� PIN ���");
					    }
					    SPD(playerid, DLG_SECRETPINRESET, DIALOG_STYLE_INPUT, !"{ff9300}�������� ������������ PIN ����{FFFFFF}", !"{FFFFFF}������� ��� ������� ����������� PIN ��� � ���� ����:", !"�������", !"�������");
					}
					case 2:
					{
					    player_info[playerid][PIN][1] = !player_info[playerid][PIN][1];
						if(player_info[playerid][PIN][1] == 0) SCMNotification(playerid, !"[�����������] {FFFFFF}��� ����������� PIN ��� ������ ����� ������������� ��� ������ ����� IP");
						else SCMNotification(playerid, !"[�����������] {FFFFFF}��� ����������� PIN ��� ������ ����� ������������� ��� ������ �����");
						static const fmt_query[] = "UPDATE `users` SET `pin` = '%d,%d' WHERE `id` = '%d'";
						new query[sizeof(fmt_query)+(-2+4)+(-2+1)+(-2+8)];
						format(query, sizeof(query), fmt_query, player_info[playerid][PIN][0], player_info[playerid][PIN][1], player_info[playerid][ID]);
						mysql_tquery(dbHandle, query);
						new dialog[81];
					    format(dialog, sizeof(dialog),
							"���������� PIN ���\n\
							������� PIN ���\n\
							���������� PIN ��� %s",
						(player_info[playerid][PIN][1] == 0) ? ("{32CD32}[��� ����� IP]") : ("{0089ff}[������]"));
						SPD(playerid, DLG_SECRETPINCONTROL, DIALOG_STYLE_LIST, !"{ff9300}���������� ����������� PIN �����", dialog, !"�������", !"�������");
					}
	            }
			}
		}
		case DLG_SECRETPINSET:
		{
		    if(!str_len) SPD(playerid, DLG_SECRETPINSET, DIALOG_STYLE_INPUT, !"{ff9300}��������� ������������ PIN ����{FFFFFF}", !"{FFFFFF}������� ��� ������� ����������� PIN ��� � ���� ����:\n\n����������: PIN ��� ������ ���� 4-�� ������� � �� ��������� �� 0", !"���������", !"�������");
		    new regex:rg_secretpincheck = regex_new("^[1-9]{1}[0-9]{3}$");
            if(regex_check(inputtext, rg_secretpincheck))
            {
                player_info[playerid][PIN][0] = strval(inputtext);
                player_info[playerid][PIN][1] = 0;
                static const fmt_query[] = "UPDATE `users` SET `pin` = '%d,%d' WHERE `id` = '%d'";
				new query[sizeof(fmt_query)+(-2+4)+(-2+1)+(-2+8)];
				format(query, sizeof(query), fmt_query, player_info[playerid][PIN][0], player_info[playerid][PIN][1], player_info[playerid][ID]);
				mysql_tquery(dbHandle, query);
				new string[58+(-2+4)];
				format(string, sizeof(string), "[�����������] {FFFFFF}��� ����������� PIN ���: {0089ff}%s", inputtext);
				SCMNotification(playerid, string);
				SCM(playerid, COLOR_NOTIFICATION, !"[�����������] {FFFFFF}�������� �������� ������� {0089ff}F8{FFFFFF} ��� �������� ����� ����������� PIN ���");
            }
            else
            {
                SPD(playerid, DLG_SECRETPINSET, DIALOG_STYLE_INPUT, !"{ff9300}��������� ������������ PIN ����{FFFFFF}", !"{FFFFFF}������� ��� ������� ����������� PIN ��� � ���� ����:\n\n����������: PIN ��� ������ ���� 4-�� ������� � �� ��������� �� 0", !"���������", !"�������");
                regex_delete(rg_secretpincheck);
                return SCMError(playerid, !"[������] {FFFFFF}������� ��������� PIN ���");
            }
            regex_delete(rg_secretpincheck);
		}
		case DLG_SECRETPINRESET:
		{
		    if(response)
	        {
			    if(!str_len) SPD(playerid, DLG_SECRETPINRESET, DIALOG_STYLE_INPUT, !"{ff9300}�������� ������������ PIN ����{FFFFFF}", !"{FFFFFF}������� ��� ������� ����������� PIN ��� � ���� ����:", !"�������", !"�������");
				if(strval(inputtext) == player_info[playerid][PIN][0])
				{
				    player_info[playerid][PIN][0] = 0;
	                player_info[playerid][PIN][1] = 0;
	                static const fmt_query[] = "UPDATE `users` SET `pin` = '%d,%d' WHERE `id` = '%d'";
					new query[sizeof(fmt_query)+(-2+4)+(-2+1)+(-2+8)];
					format(query, sizeof(query), fmt_query, player_info[playerid][PIN][0], player_info[playerid][PIN][1], player_info[playerid][ID]);
					mysql_tquery(dbHandle, query);
					SCMNotification(playerid, !"[�����������] {FFFFFF}��� ����������� PIN ��� �����");
				}
				else
				{
				    SPD(playerid, DLG_SECRETPINRESET, DIALOG_STYLE_INPUT, !"{ff9300}�������� ������������ PIN ����{FFFFFF}", !"{FFFFFF}������� ��� ������� ����������� PIN ��� � ���� ����:", !"�������", !"�������");
	                return SCMError(playerid, !"[������] {FFFFFF}�� ����� ������������ PIN ���");
				}
			}
		}
		case DLG_GOOGLEAUTHCONTROL:
		{
		    if(response)
	        {
	            switch(listitem)
	            {
					case 0:
					{
					    if(strlen(player_info[playerid][GOOGLEAUTH]) > 1)
					    {
					        new dialog[120];
						    format(dialog, sizeof(dialog),
								"���������� Google Authenticator\n\
								������� Google Authenticator\n\
								���������� Google Authenticator %s",
							(player_info[playerid][GOOGLEAUTHSETTING] == 0) ? ("{32CD32}[��� ����� IP]") : ("{0089ff}[������]"));
							SPD(playerid, DLG_GOOGLEAUTHCONTROL, DIALOG_STYLE_LIST, !"{ff9300}���������� Google Authenticator", dialog, !"�������", !"�������");
							return SCMError(playerid, !"[������] {FFFFFF}� ��� ��� ���������� Google Authenticator");
					    }
						player_info[playerid][GOOGLEAUTH] = EOS;
						for(new i; i < 16; i++)
						{
						    player_info[playerid][GOOGLEAUTH][i] = random(25) + 65;
						}
						new dialog[531+(-2+MAX_PLAYER_NAME)+(-2+16)];
					 	format(dialog, sizeof(dialog),
					 		"{FFFFFF}�������� � ���������� ���������� Google Authenticator �� ���� ��������� ����������\n\n\
						 	���� � ��� Android, �� ������� ������ '+' � ������ ������� ���� � �������� \"������ ����\"\n\
						 	���� � ��� IOS, �� ������� ������ '+' � ������ ������� ���� � �������� \"���� �������\"\n\n\
						 	� ���� \"�������\" �������: {0089ff}%s@foundationrp{FFFFFF}\n\
						 	� ���� \"����\" �������: {0089ff}%s{FFFFFF}\n\n\
					 		����� ���������� �������� ������� ������ \"�����\"\n\
						 	������� ���� ������������� �� ��������, ������ ��������� ����, ��� ���������� �� �������",
						pName(playerid),
						player_info[playerid][GOOGLEAUTH]);
						SPD(playerid, DLG_GOOGLEAUTHINSTALL, DIALOG_STYLE_MSGBOX, !"{ff9300}��������� Google Authenticator{FFFFFF} � ��� ������", dialog, !"�����", "");
					}
					case 1:
					{
					    if(strlen(player_info[playerid][GOOGLEAUTH]) == 1)
						{
						    new dialog[120];
						    format(dialog, sizeof(dialog),
								"���������� Google Authenticator\n\
								������� Google Authenticator\n\
								���������� Google Authenticator %s",
							(player_info[playerid][GOOGLEAUTHSETTING] == 0) ? ("{32CD32}[��� ����� IP]") : ("{0089ff}[������]"));
							SPD(playerid, DLG_GOOGLEAUTHCONTROL, DIALOG_STYLE_LIST, !"{ff9300}���������� Google Authenticator", dialog, !"�������", !"�������");
							return SCMError(playerid, !"[������] {FFFFFF}� ��� �� ���������� Google Authenticator");
						}
						if(player_info[playerid][ADMIN] != 0)
						{
						    new dialog[120];
						    format(dialog, sizeof(dialog),
								"���������� Google Authenticator\n\
								������� Google Authenticator\n\
								���������� Google Authenticator %s",
							(player_info[playerid][GOOGLEAUTHSETTING] == 0) ? ("{32CD32}[��� ����� IP]") : ("{0089ff}[������]"));
							SPD(playerid, DLG_GOOGLEAUTHCONTROL, DIALOG_STYLE_LIST, !"{ff9300}���������� Google Authenticator", dialog, !"�������", !"�������");
							return SCMError(playerid, !"[������] {FFFFFF}��������������� ��������� ������� Google Authenticator");
						}
                        player_info[playerid][GOOGLEAUTH] = EOS;
                        strcat(player_info[playerid][GOOGLEAUTH], "0");
                        SCMNotification(playerid, !"[�����������] {FFFFFF}Google Authenticator �����");
			            static const fmt_query[] = "UPDATE `users` SET `googleauth` = '%s' WHERE `id` = '%d'";
						new query[sizeof(fmt_query)+(-2+16)+(-2+8)];
						format(query, sizeof(query), fmt_query, player_info[playerid][GOOGLEAUTH], player_info[playerid][ID]);
						mysql_tquery(dbHandle, query);
					}
					case 2:
					{
					    player_info[playerid][GOOGLEAUTHSETTING] = !player_info[playerid][GOOGLEAUTHSETTING];
						if(player_info[playerid][GOOGLEAUTHSETTING] == 0) SCMNotification(playerid, !"[�����������] {FFFFFF}��� Google Authenticator ������ ����� ������������� ��� ������ ����� IP");
                        else SCMNotification(playerid, !"[�����������] {FFFFFF}��� Google Authenticator ��� ������ ����� ������������� ��� ������ �����");
						static const fmt_query[] = "UPDATE `users` SET `gs` = '%d' WHERE `id` = '%d'";
						new query[sizeof(fmt_query)+(-2+1)+(-2+8)];
						format(query, sizeof(query), fmt_query, player_info[playerid][GOOGLEAUTHSETTING], player_info[playerid][ID]);
						mysql_tquery(dbHandle, query);
						new dialog[120];
					    format(dialog, sizeof(dialog),
							"���������� Google Authenticator\n\
							������� Google Authenticator\n\
							���������� Google Authenticator %s",
						(player_info[playerid][GOOGLEAUTHSETTING] == 0) ? ("{32CD32}[��� ����� IP]") : ("{0089ff}[������]"));
						SPD(playerid, DLG_GOOGLEAUTHCONTROL, DIALOG_STYLE_LIST, !"{ff9300}���������� Google Authenticator", dialog, !"�������", !"�������");
					}
				}
			}
		}
		case DLG_GOOGLEAUTHINSTALL:
		{
			if(response)
			{
		    	SPD(playerid, DLG_GOOGLEAUTHINSTALLCHECK, DIALOG_STYLE_INPUT, !"{ff9300}��������� Google Authenticator{FFFFFF} � ��� ������", !"{FFFFFF}��� ���������� ��������� Google Authenticator\n������� ��� �� ���������� � ���� ����:", !"�����", "������");
			}
			else
		    {
		        player_info[playerid][GOOGLEAUTH] = EOS;
		    }
		}
		case DLG_GOOGLEAUTHINSTALLCHECK:
		{
		    if(response)
		    {
		        new getcode = GoogleAuthenticatorCode(player_info[playerid][GOOGLEAUTH], gettime());
		        if(strval(inputtext) == getcode)
		        {
		            SCMNotification(playerid, !"[�����������] {FFFFFF}Google Authenticator �����������");
		            static const fmt_query[] = "UPDATE `users` SET `googleauth` = '%s' WHERE `id` = '%d'";
					new query[sizeof(fmt_query)+(-2+16)+(-2+8)];
					format(query, sizeof(query), fmt_query, player_info[playerid][GOOGLEAUTH], player_info[playerid][ID]);
					mysql_tquery(dbHandle, query);
		        }
		        else
		        {
		            SPD(playerid, DLG_GOOGLEAUTHINSTALLCHECK, DIALOG_STYLE_INPUT, !"{ff9300}��������� Google Authenticator{FFFFFF} � ��� ������", !"{FFFFFF}��� ���������� ��������� Google Authenticator\n������� ��� �� ���������� � ���� ����:", !"�����", "������");
		            return SCMError(playerid, !"[������] {FFFFFF}��� �� ���������");
		        }
		    }
		    else
		    {
		        player_info[playerid][GOOGLEAUTH] = EOS;
		    }
		}
		case DLG_CHECKGOOGLEAUTH:
		{
		    new getcode = GoogleAuthenticatorCode(player_info[playerid][GOOGLEAUTH], gettime());
	        if(strval(inputtext) == getcode) PlayerGoLogin(playerid);
	        else
	        {
	            Kick(playerid);
	            return SCMError(playerid, !"[������] {FFFFFF}��� �� ���������");
	        }
		
		}
		case DLG_INFORMADM:
		{
		    if(response)
		    {
		        switch(listitem)
	            {
					case 0:
					{
					    SPD(playerid, DLG_REPORT, DIALOG_STYLE_INPUT, !"{FFFFFF}�������� {e93230}������",
							!"{FFFFFF}����� ���, ��� ���������� ������ �������������, �������������� ��� �� �� ��������� ������������� �������:\n\n\
							\t\t\t{e91432}���������:\n\
							\t\t\t1. �������� ������� (��� ����� ���� ������ \"{FFFFFF}������ {11dd77}������{e91432}\")\n\
							\t\t\t2. ����, ����, �����������, ������.\n\
							\t\t\t3. ������� �� ���� - \"����� �����, ����� ���\"\n\
							\t\t\t4. ������ ���������\n\n\
							{FFFFFF}��� ��������� ������������� ������ ������������� ����� �������� ��� ���������� ��� ����� ����������.\n\
							�������, ��� ���� ������ �� ������������, ������������� ����� ����� �� ��������� ���� ����������� �����",
						!"���������", !"�����");
					}
					case 1:
					{
						SPD(playerid, DLG_QUESTION, DIALOG_STYLE_INPUT, !"{FFFFFF}������{11dd77} ������",
							!"{FFFFFF}����� ���, ��� ���������� ������ �������������, �������������� ��� �� �� ��������� ������������� �������:\n\n\
							\t\t\t{e91432}���������:\n\
							\t\t\t1. ������ ������ (��� ����� ���� ������ \"{FFFFFF}�������� {e93230}������{e91432}\")\n\
							\t\t\t2. ����, ����, �����������, ������.\n\
							\t\t\t3. ������� �� ���� - \"����� �����, ����� ���\"\n\n\
							{FFFFFF}��� ��������� ������������� ������ ������������� ����� �������� ��� ���������� ��� ����� ����������.\n\
							�������, ��� ��� ������ �� ������������, ������������� ����� ����� �� ��������� ���� ����������� ��������",
						!"���������", !"�����");
					}
				}
			}
			else callcmd::menu(playerid);
		}
		case DLG_REPORT:
		{
		    if(response)
		    {
				if(!str_len)
				{
				    SPD(playerid, DLG_REPORT, DIALOG_STYLE_INPUT, !"{FFFFFF}�������� {e93230}������",
						!"{FFFFFF}����� ���, ��� ���������� ������ �������������, �������������� ��� �� �� ��������� ������������� �������:\n\n\
						\t\t\t{e91432}���������:\n\
						\t\t\t1. �������� ������� (��� ����� ���� ������ \"{FFFFFF}������ {11dd77}������{e91432}\")\n\
						\t\t\t2. ����, ����, �����������, ������.\n\
						\t\t\t3. ������� �� ���� - \"����� �����, ����� ���\"\n\
						\t\t\t4. ������ ���������\n\n\
						{FFFFFF}��� ��������� ������������� ������ ������������� ����� �������� ��� ���������� ��� ����� ����������.\n\
						�������, ��� ���� ������ �� ������������, ������������� ����� ����� �� ��������� ���� ����������� �����",
					!"���������", !"�����");
				}
				if(str_len > 97)
				{
				    SPD(playerid, DLG_REPORT, DIALOG_STYLE_INPUT, !"{FFFFFF}�������� {e93230}������",
						!"{FFFFFF}����� ���, ��� ���������� ������ �������������, �������������� ��� �� �� ��������� ������������� �������:\n\n\
						\t\t\t{e91432}���������:\n\
						\t\t\t1. �������� ������� (��� ����� ���� ������ \"{FFFFFF}������ {11dd77}������{e91432}\")\n\
						\t\t\t2. ����, ����, �����������, ������.\n\
						\t\t\t3. ������� �� ���� - \"����� �����, ����� ���\"\n\
						\t\t\t4. ������ ���������\n\n\
						{FFFFFF}��� ��������� ������������� ������ ������������� ����� �������� ��� ���������� ��� ����� ����������.\n\
						�������, ��� ���� ������ �� ������������, ������������� ����� ����� �� ��������� ���� ����������� �����",
					!"���������", !"�����");
				    return SCMError(playerid, !"[������] {FFFFFF}������� ������� ���������");
				}
				new string[144];
				format(string, sizeof(string), "�� ��������� {e93230}������{FFFFFF}: %s", inputtext);
				SCM(playerid, COLOR_WHITE, string);
				format(string, sizeof(string), "[������]{FFFFFF} %s[%d]: %s", pName(playerid), playerid, inputtext);
				SCMA(COLOR_LIGHTRED, string);
		    }
		    else SPD(playerid, DLG_INFORMADM, DIALOG_STYLE_LIST, !"{ff9300}����� � ��������������", !"�������� {e93230}������\n������ {11dd77}������", !"�������", !"�����");
		}
		case DLG_AHELP:
		{
		    if(response)
		    {
		        switch(listitem)
	            {
					case 0:
					{
					    SPD(playerid, DLG_AHELPCMD, DIALOG_STYLE_MSGBOX, !"{ff9300}������� {FFFFFF}������� ������",
							!"{ff9300}/admins{FFFFFF} - ���������� ������������� � ����\n\
							{ff9300}/a{FFFFFF} - ��� �������������\n\
							{ff9300}/rep{FFFFFF} - �������� �� ������\n\
							{ff9300}/ans{FFFFFF} - �������� �� ������",
						!"�����", "�������");
					}
					case 1:
					{
					    SPD(playerid, DLG_AHELPCMD, DIALOG_STYLE_MSGBOX, !"{ff9300}������� {FFFFFF}������� ������",
							!"",
						!"�����", "�������");
					}
					case 2:
					{
					    SPD(playerid, DLG_AHELPCMD, DIALOG_STYLE_MSGBOX, !"{ff9300}������� {FFFFFF}�������� ������",
							!"{ff9300}/tpcor{FFFFFF} - ������������� �� ����������\n\
							{ff9300}/setint{FFFFFF} - ������������� � id ���������\n\
							{ff9300}/setworld{FFFFFF} - ������������� � id ����. ����\n\
							{ff9300}/goto{FFFFFF} - ����������������� � ������\n\
							{ff9300}/gethere{FFFFFF} - ��������������� ������ � ����\n\
							{ff9300}/plveh{FFFFFF} - ������ ������ ����������",
						!"�����", "�������");
					}
					case 3:
					{
					    SPD(playerid, DLG_AHELPCMD, DIALOG_STYLE_MSGBOX, !"{ff9300}������� {FFFFFF}��������� ������",
							!"{ff9300}/setweather{FFFFFF} - ���������� ������ �� �������\n\
							{ff9300}/setstatictime{FFFFFF} - ���������� �� ���������� ����� �� �������\n\
							{ff9300}/resetstatictime{FFFFFF} - ������� ���������� �����\n\
							{ff9300}/reginfo{FFFFFF} - �������� ��������������� ������ ������ � ��������",
						!"�����", "�������");
					}
					case 4:
					{
					    SPD(playerid, DLG_AHELPCMD, DIALOG_STYLE_MSGBOX, !"{ff9300}������� {FFFFFF}������ ������",
							!"",
						!"�����", "�������");
					}
					case 5:
					{
					    SPD(playerid, DLG_AHELPCMD, DIALOG_STYLE_MSGBOX, !"{ff9300}������� {FFFFFF}������� ������",
							!"{ff9300}/resetadm{FFFFFF} - ����� ��������������\n\
							{ff9300}/resetadmoff{FFFFFF} - ����� �������������� � ��������",
						!"�����", "�������");
					}
				}
			}
		}
		case DLG_AHELPCMD:
		{
		    if(response) callcmd::ahelp(playerid);
		}
		case DLG_QUESTION:
		{
		    if(response)
		    {
		        if(!str_len)
				{
				    SPD(playerid, DLG_QUESTION, DIALOG_STYLE_INPUT, !"{FFFFFF}������{11dd77} ������",
						!"{FFFFFF}����� ���, ��� ���������� ������ �������������, �������������� ��� �� �� ��������� ������������� �������:\n\n\
						\t\t\t{e91432}���������:\n\
						\t\t\t1. ������ ������ (��� ����� ���� ������ \"{FFFFFF}�������� {e93230}������{e91432}\")\n\
						\t\t\t2. ����, ����, �����������, ������.\n\
						\t\t\t3. ������� �� ���� - \"����� �����, ����� ���\"\n\n\
						{FFFFFF}��� ��������� ������������� ������ ������������� ����� �������� ��� ���������� ��� ����� ����������.\n\
						�������, ��� ��� ������ �� ������������, ������������� ����� ����� �� ��������� ���� ����������� ��������",
					!"���������", !"�����");
				}
				if(str_len > 97)
				{
				    SPD(playerid, DLG_QUESTION, DIALOG_STYLE_INPUT, !"{FFFFFF}������{11dd77} ������",
						!"{FFFFFF}����� ���, ��� ���������� ������ �������������, �������������� ��� �� �� ��������� ������������� �������:\n\n\
						\t\t\t{e91432}���������:\n\
						\t\t\t1. ������ ������ (��� ����� ���� ������ \"{FFFFFF}�������� {e93230}������{e91432}\")\n\
						\t\t\t2. ����, ����, �����������, ������.\n\
						\t\t\t3. ������� �� ���� - \"����� �����, ����� ���\"\n\n\
						{FFFFFF}��� ��������� ������������� ������ ������������� ����� �������� ��� ���������� ��� ����� ����������.\n\
						�������, ��� ��� ������ �� ������������, ������������� ����� ����� �� ��������� ���� ����������� ��������",
					!"���������", !"�����");
				    return SCMError(playerid, !"[������] {FFFFFF}������� ������� ���������");
				}
				static const fmt_query[] = "SELECT * FROM `fastanswers` WHERE `faquestion` = '%e'";
				new query[sizeof(fmt_query)+(-2+97)];
				mysql_format(dbHandle, query, sizeof(query), fmt_query, inputtext);
				mysql_tquery(dbHandle, query, "CheckFastAnswer", "is", playerid, inputtext);
		    }
		    else SPD(playerid, DLG_INFORMADM, DIALOG_STYLE_LIST, !"{ff9300}����� � ��������������", !"�������� {e93230}������\n������ {11dd77}������", !"�������", !"�����");
		}
		case DLG_ANSWERPLAYER:
		{
		    new questionfrom = GetPVarInt(playerid, "questionfrom");
		    if(response)
		    {
		        if(!str_len || str_len > 60)
		        {
                    new dialog[45+(-2+MAX_PLAYER_NAME)+(-2+3)+(-2+97)];
					format(dialog, sizeof(dialog),
						"{11dd77}������{FFFFFF} �� ������ %s[%d]:\n\
						%s",
					pName(questionfrom),
					questionfrom,
					player_info[questionfrom][tempQUESTION]);
					SetPVarInt(playerid, "questionfrom", questionfrom);
					SPD(playerid, DLG_ANSWERPLAYER, DIALOG_STYLE_INPUT, !"{FFFFFF}����� �� {11dd77}������", dialog, !"��������", !"������");
					if(str_len > 60) return SCMError(playerid, !"[������] {FFFFFF}������� ������� ����� ������");
					return 1;
		        }
		        new string[144];
		        format(string, sizeof(string), "������������� %s[%d] ������� ���:{FFFFFF} %s", pName(playerid), playerid, inputtext);
		        SCM(questionfrom, 0x11dd77FF, string);
		        format(string, sizeof(string), "[questANS] %s[%d] ��� %s[%d]:{FFFFFF} %s", pName(playerid), playerid, pName(questionfrom), questionfrom, inputtext);
				SCMA(COLOR_TOMATO, string);
				if(player_info[playerid][ADMIN] >= 2)
				{
					SetPVarString(playerid, "fastanswer", inputtext);
				    SPD(playerid, DLG_ADDFASTANSWER, DIALOG_STYLE_MSGBOX, !"{FFFFFF}������� �����", !"{FFFFFF}�� ������ ������� ������ ����� ��� ������� �����?", !"��", !"���");
				}
				else
				{
				    DeletePVar(playerid, "questionfrom");
					player_info[questionfrom][tempQUESTION] = EOS;
				}
		    }
		    else
		    {
		        new string[144];
		        format(string, sizeof(string), "������������� %s[%d] �� ������� �� ��� ������: %s", pName(playerid), playerid, player_info[questionfrom][tempQUESTION]);
				SCM(questionfrom, 0x11dd77FF, string);
				format(string, sizeof(string), "[questANS] %s[%d] �� ������� ������ %s[%d] �� ������:{FFFFFF} %s", pName(playerid), playerid, pName(questionfrom), questionfrom, player_info[questionfrom][tempQUESTION]);
				SCMA(COLOR_TOMATO, string);
				DeletePVar(playerid, "questionfrom");
				player_info[questionfrom][tempQUESTION] = EOS;
			}
		}
		case DLG_ADDFASTANSWER:
		{
		    if(response)
			{
			    new questionfrom = GetPVarInt(playerid, "questionfrom");
			    new answer[61];
 				GetPVarString(playerid, "fastanswer", answer, sizeof(answer));
 				FixSVarString(answer);
			    static const fmt_query[] = "INSERT INTO `fastanswers` (`faquestion`, `faanswer`, `faadmadd`) VALUES ('%e', '%e', '%d')";
				new query[sizeof(fmt_query)+(-2+97)+(-2+60)+(-2+8)];
				mysql_format(dbHandle, query, sizeof(query), fmt_query, player_info[questionfrom][tempQUESTION], answer, player_info[playerid][ID]);
				mysql_query(dbHandle, query, false);
				DeletePVar(playerid, "questionfrom");
				player_info[questionfrom][tempQUESTION] = EOS;
				DeletePVar(playerid, "fastanswer");
			}
		}
		case DLG_MINELOWJOIN:
		{
		    if(response)
			{
			    SCM(playerid, COLOR_LIGHTBLUE, "�� ���������� �� ������ ������� �������. �������� ���������� ������ ���.");
			    SetPlayerSkin(playerid, 260);
			    temp_info[playerid][LOWWORK] = 1;
			    temp_info[playerid][MINELOW] = 1;
			    temp_info[playerid][MINEPROGRESS] = 0;
			    temp_info[playerid][MINENUMBER] = 0;
			    
			    CreatePlayerMineTD(playerid);
			    PlayerTextDrawShow(playerid, MineMoney_PTD[playerid]);
			    PlayerTextDrawShow(playerid, MineAmount_PTD[playerid]);
			    TextDrawShowForPlayer(playerid, Mine_TD[0]);
			    TextDrawShowForPlayer(playerid, Mine_TD[1]);
			    TextDrawShowForPlayer(playerid, Mine_TD[2]);
			    TextDrawShowForPlayer(playerid, Mine_TD[3]);
			}
		}
		case DLG_MINEHIGHJOIN:
		{
		    if(response)
			{
			    SCM(playerid, COLOR_LIGHTBLUE, "�� ���������� �� ������ ������� �������. �������� ���������� ������ ���.");
			    SetPlayerSkin(playerid, 260);
			    temp_info[playerid][LOWWORK] = 1;
			    temp_info[playerid][MINEHIGH] = 1;
			    temp_info[playerid][MINEPROGRESS] = 0;
			    temp_info[playerid][MINENUMBER] = 0;
			    
			    CreatePlayerMineTD(playerid);
			    PlayerTextDrawShow(playerid, MineMoney_PTD[playerid]);
			    PlayerTextDrawShow(playerid, MineAmount_PTD[playerid]);
			    TextDrawShowForPlayer(playerid, Mine_TD[0]);
			    TextDrawShowForPlayer(playerid, Mine_TD[1]);
			    TextDrawShowForPlayer(playerid, Mine_TD[2]);
			    TextDrawShowForPlayer(playerid, Mine_TD[4]);
			}
		}
		case DLG_MINELOWLEFT:
		{
		    if(response)
			{
			    temp_info[playerid][LOWWORK] = 0;
			    temp_info[playerid][MINELOW] = 0;
				SCM(playerid, COLOR_LIGHTBLUE, "�� ��������� ������ �������.");
				if(temp_info[playerid][MINENUMBER] > 0)
				{
			        new string[82+(-2+6)+(-2+5)];
			        format(string, sizeof(string), "�� �������� {00FF00}%d${3399FF} �� ������� {FFFF00}%d ��{3399FF} ���� � ��������.", temp_info[playerid][MINENUMBER]*2, temp_info[playerid][MINENUMBER]);
			        SCM(playerid, COLOR_LIGHTBLUE, string);
			        GiveMoney(playerid, temp_info[playerid][MINENUMBER]*2);
				}
				SaveLowWorkSkills(playerid);
			    temp_info[playerid][MINEPROGRESS] = 0;
			    temp_info[playerid][MINENUMBER] = 0;
			    SetPlayerSkin(playerid, player_info[playerid][SKIN]);
			    
			    TextDrawHideForPlayer(playerid, Mine_TD[0]);
			    TextDrawHideForPlayer(playerid, Mine_TD[1]);
			    TextDrawHideForPlayer(playerid, Mine_TD[2]);
			    TextDrawHideForPlayer(playerid, Mine_TD[3]);
			    PlayerTextDrawDestroy(playerid, MineMoney_PTD[playerid]);
			    PlayerTextDrawDestroy(playerid, MineAmount_PTD[playerid]);
			}
		}
		case DLG_MINEHIGHLEFT:
		{
		    if(response)
			{
			    temp_info[playerid][LOWWORK] = 0;
			    temp_info[playerid][MINEHIGH] = 0;
			    SCM(playerid, COLOR_LIGHTBLUE, "�� ��������� ������ �������.");
			    if(temp_info[playerid][MINENUMBER] > 0)
				{
			        new string[82+(-2+6)+(-2+5)];
			        format(string, sizeof(string), "�� �������� {00FF00}%d${3399FF} �� ������� {FFFF00}%d ��{3399FF} ���� � ��������.", temp_info[playerid][MINENUMBER]*3, temp_info[playerid][MINENUMBER]);
			        SCM(playerid, COLOR_LIGHTBLUE, string);
			        GiveMoney(playerid, temp_info[playerid][MINENUMBER]*3);
				}
				SaveLowWorkSkills(playerid);
			    temp_info[playerid][MINEPROGRESS] = 0;
			    temp_info[playerid][MINENUMBER] = 0;
			    SetPlayerSkin(playerid, player_info[playerid][SKIN]);
			    
			    TextDrawHideForPlayer(playerid, Mine_TD[0]);
			    TextDrawHideForPlayer(playerid, Mine_TD[1]);
			    TextDrawHideForPlayer(playerid, Mine_TD[2]);
			    TextDrawHideForPlayer(playerid, Mine_TD[4]);
			    PlayerTextDrawDestroy(playerid, MineMoney_PTD[playerid]);
			    PlayerTextDrawDestroy(playerid, MineAmount_PTD[playerid]);
			}
		}
		
	}
	return 1;
}

forward PlayerLogin(playerid);
public PlayerLogin(playerid)
{
    new rows;
	cache_get_row_count(rows);
	if(rows)
	{
        cache_get_value_name_int(0, "id", player_info[playerid][ID]);
        cache_get_value_name(0, "email", player_info[playerid][EMAIL], 65);
        cache_get_value_name_int(0, "ref", player_info[playerid][REF]);
        cache_get_value_name_int(0, "refmoney", player_info[playerid][REFMONEY]);
        cache_get_value_name_int(0, "sex", player_info[playerid][SEX]);
        cache_get_value_name_int(0, "race", player_info[playerid][RACE]);
        cache_get_value_name_int(0, "age", player_info[playerid][AGE]);
        cache_get_value_name_int(0, "skin", player_info[playerid][SKIN]);
        cache_get_value_name(0, "regdata", player_info[playerid][REGDATA], 13);
        cache_get_value_name(0, "regip", player_info[playerid][REGIP], 16);
        cache_get_value_name_int(0, "admin", player_info[playerid][ADMIN]);
        cache_get_value_name_int(0, "money", player_info[playerid][MONEY]);
        cache_get_value_name_int(0, "lvl", player_info[playerid][LVL]);
        cache_get_value_name_int(0, "exp", player_info[playerid][EXP]);
        cache_get_value_name_int(0, "mins", player_info[playerid][MINS]);
        GetPlayerIp(playerid, player_info[playerid][LASTIP], 16);
        new buffer[32];
        cache_get_value_name(0, "lowworkskill", buffer, 32);
        sscanf(buffer, "p<,>a<i>[2]", player_info[playerid][LOWWORKSKILL]);
        
        if(player_info[playerid][REFMONEY] != 0)
        {
            SCM(playerid, COLOR_LIGHTBLUE, "�� �������� �������������� �� ������������ �� ������ �������.");
            GiveMoney(playerid, player_info[playerid][REFMONEY]);
            player_info[playerid][REFMONEY] = 0;
            static const fmt_query[] = "UPDATE `users` SET `refmoney` = '0' WHERE `id` = '%d'";
			new query[sizeof(fmt_query)+(-2+8)];
			mysql_format(dbHandle, query, sizeof(query), fmt_query, player_info[playerid][ID]);
			mysql_tquery(dbHandle, query);
        }
        
        if(player_info[playerid][ADMIN] > 0) Iter_Add(Admins_ITER, playerid);
        switch(random(2))
		{
		    case 0:
		    {
		        
   				SetSpawnInfo(playerid, 0, player_info[playerid][SKIN], 1432.6733,2653.3237,11.3926, 180.0, 0, 0, 0, 0, 0, 0);
		    }
		    case 1:
		    {
		        SetSpawnInfo(playerid, 0, player_info[playerid][SKIN], 1433.3832,2620.2297,11.3926, 360.0, 0, 0, 0, 0, 0, 0);
		    }
		}
		
		
		SetPVarInt(playerid, "logged", 1);
	    TogglePlayerSpectating(playerid, 0);
	    for(new slot = 0; slot < INVENTORY_MAX_SLOT; slot++) {
            static const fmt_query[] = "SELECT * FROM `inventory_data` WHERE `owner_id` = '%d' and `type` = %d and `slot_id` = %d";
			new query[sizeof(fmt_query)+(-2+55)];
			mysql_format(dbHandle, query, sizeof(query), fmt_query, player_info[playerid][ID], 1, slot);
			mysql_tquery(dbHandle, query, "LoadPlayerInventory", "ii", slot, playerid);
    	}

	 	gInventoryGTextDrawNow[playerid][0] = CreatePlayerTextDraw(playerid, 258.000000, 173.000000, "Preview_Model");
		PlayerTextDrawFont(playerid, gInventoryGTextDrawNow[playerid][0], 5);
		PlayerTextDrawLetterSize(playerid, gInventoryGTextDrawNow[playerid][0], 0.600000, 2.000000);
		PlayerTextDrawTextSize(playerid, gInventoryGTextDrawNow[playerid][0], 62.000000, 59.500000);
		PlayerTextDrawSetOutline(playerid, gInventoryGTextDrawNow[playerid][0], 0);
		PlayerTextDrawSetShadow(playerid, gInventoryGTextDrawNow[playerid][0], 0);
		PlayerTextDrawAlignment(playerid, gInventoryGTextDrawNow[playerid][0], 1);
		PlayerTextDrawColor(playerid, gInventoryGTextDrawNow[playerid][0], -1);
		PlayerTextDrawBackgroundColor(playerid, gInventoryGTextDrawNow[playerid][0], 0);
		PlayerTextDrawBoxColor(playerid, gInventoryGTextDrawNow[playerid][0], 0);
		PlayerTextDrawUseBox(playerid, gInventoryGTextDrawNow[playerid][0], 0);
		PlayerTextDrawSetProportional(playerid, gInventoryGTextDrawNow[playerid][0], 1);
		PlayerTextDrawSetSelectable(playerid, gInventoryGTextDrawNow[playerid][0], 1);
		PlayerTextDrawSetPreviewModel(playerid, gInventoryGTextDrawNow[playerid][0], player_info[playerid][SKIN]);
		PlayerTextDrawSetPreviewRot(playerid, gInventoryGTextDrawNow[playerid][0], -17.000000, 0.000000, 0.000000, 0.970000);
		PlayerTextDrawSetPreviewVehCol(playerid, gInventoryGTextDrawNow[playerid][0], 1, 1);

		gInventoryGTextDrawNow[playerid][1] = CreatePlayerTextDraw(playerid, 291.000000, 154.000000, pName(playerid));
		PlayerTextDrawFont(playerid, gInventoryGTextDrawNow[playerid][1], 2);
		PlayerTextDrawLetterSize(playerid, gInventoryGTextDrawNow[playerid][1], 0.329166, 1.450000);
		PlayerTextDrawTextSize(playerid, gInventoryGTextDrawNow[playerid][1], 400.000000, 17.000000);
		PlayerTextDrawSetOutline(playerid, gInventoryGTextDrawNow[playerid][1], 1);
		PlayerTextDrawSetShadow(playerid, gInventoryGTextDrawNow[playerid][1], 0);
		PlayerTextDrawAlignment(playerid, gInventoryGTextDrawNow[playerid][1], 2);
		PlayerTextDrawColor(playerid, gInventoryGTextDrawNow[playerid][1], -1);
		PlayerTextDrawBackgroundColor(playerid, gInventoryGTextDrawNow[playerid][1], 0);
		PlayerTextDrawBoxColor(playerid, gInventoryGTextDrawNow[playerid][1], 50);
		PlayerTextDrawUseBox(playerid, gInventoryGTextDrawNow[playerid][1], 0);
		PlayerTextDrawSetProportional(playerid, gInventoryGTextDrawNow[playerid][1], 1);
		PlayerTextDrawSetSelectable(playerid, gInventoryGTextDrawNow[playerid][1], 0);
	}
	return 1;
}

forward LoadPlayerInventory(slot, playerid);
public LoadPlayerInventory(slot, playerid)
{
    new rows;
	cache_get_row_count(rows);
	if(rows)
	{
	    cache_get_value_name_int(0, "item_id", pInventoryData[playerid][idItem][slot]);
	    cache_get_value_name_int(0, "amount", pInventoryData[playerid][idAmount][slot]);
	}
}

forward CheckReferal(playerid, referal[]);
public CheckReferal(playerid, referal[])
{
	new rows;
	cache_get_row_count(rows);
	if(rows)
	{
	    cache_get_value_name_int(0, "id", player_info[playerid][REF]);
	    SPD(playerid, DLG_REGSEX, DIALOG_STYLE_MSGBOX, !"{ff9300}�����������{FFFFFF} � ����� ���� ���������",
			!"{FFFFFF}�������� ��� ������ ���������:",
		!"�������", !"�������");
	}
	else
	{
	    SPD(playerid, DLG_REGREF, DIALOG_STYLE_INPUT, !"{ff9300}�����������{FFFFFF} � ���� �������������",
			!"{FFFFFF}���� �� ����� �� ������ �� �����������, ��\n\
			������ ������� ��� ������������� � ���� ����:",
		!"�����", !"����������");
        return SCMError(playerid, !"[������] {FFFFFF}�������� � ����� ����� �� ����������");
	}
	return 1;
}

forward CheckFastAnswer(playerid, answer[]);
public CheckFastAnswer(playerid, answer[])
{
	new rows;
	cache_get_row_count(rows);
	new string[144];
	if(rows)
	{
	    new faid, faanswer[60];
	    cache_get_value_name_int(0, "faid", faid);
	    cache_get_value_name(0, "faanswer", faanswer, 60);
        format(string, sizeof(string), "������� �������� ���:{FFFFFF} %s", faanswer);
        SCM(playerid, 0x11dd77FF, string);
        format(string, sizeof(string), "[questANS] �������[FAID: %d] ��� %s[%d]:{FFFFFF} %s", faid, pName(playerid), playerid, faanswer);
		SCMA(COLOR_TOMATO, string);
	}
	else
	{
		format(string, sizeof(string), "�� ��������� {11dd77}������{FFFFFF}: %s", answer);
		SCM(playerid, COLOR_WHITE, string);
		format(string, sizeof(string), "[������]{FFFFFF} %s[%d]: %s", pName(playerid), playerid, answer);
		SCMA(0x11dd77FF, string);
		strmid(player_info[playerid][tempQUESTION], answer, 0, strlen(answer), 97);
		Iter_Add(Question_ITER, playerid);
	}
}

stock SaveLowWorkSkills(playerid)
{
    static const fmt_query[] = "UPDATE `users` SET `lowworkskill` = '%d,%d' WHERE `id` = '%d'";
	new query[sizeof(fmt_query)+(-2+7)+(-2+7)+(-2+8)];
	mysql_format(dbHandle, query, sizeof(query), fmt_query, player_info[playerid][LOWWORKSKILL][0], player_info[playerid][LOWWORKSKILL][1], player_info[playerid][ID]);
	mysql_tquery(dbHandle, query);
}

stock CreatePlayerMineTD(playerid)
{
    #include <PlayerTextDraws/Mine>
}

public OnPlayerClickPlayer(playerid, clickedplayerid, source)
{
	return 1;
}

public OnPlayerClickMap(playerid, Float:fX, Float:fY, Float:fZ)
{
    if(player_info[playerid][ADMIN] >= 4)
    {
        if(GetPlayerState(playerid) == PLAYER_STATE_DRIVER)
        {
            SetVehiclePos(GetPlayerVehicleID(playerid), fX, fY, fZ);
            PutPlayerInVehicle(playerid, GetPlayerVehicleID(playerid), 0);
        }
        else
        {
            SetPlayerPos(playerid, fX, fY, fZ);
        }
        SetPlayerVirtualWorld(playerid, 0);
        SetPlayerInterior(playerid, 0);
    }
    return 1;
}
public OnPlayerClickTextDraw(playerid, Text:clickedid) {
    if(_:clickedid == INVALID_TEXT_DRAW) {
        if(IsPlayerOpenInventory(playerid)) {
            HidePlayerInventory(playerid);
        }
    }

    if(clickedid == gInventoryGTextDrawBG[8]) {
        HidePlayerInventory(playerid);
    }
    return 1;
}
public OnPlayerClickPlayerTextDraw(playerid, PlayerText:playertextid)
{
	if(IsPlayerOpenInventory(playerid)) {
        new clickedslot = ClickedSlot(playerid);

        for(new slot; slot < INVENTORY_SIZE; slot++) {
            if(playertextid == gInventoryPTDSlots[playerid][slot]) {
                new item_idx = GetPlayerInventoryItemByIDX(playerid, slot);
                if(clickedslot == INVALID_INVENTORY_CLICK_SLOT && item_idx == 0)
                    break;

                if(clickedslot == INVALID_INVENTORY_CLICK_SLOT) {
                    SetClickedSlot(playerid, slot);
                    PlayerClickSlot(playerid, slot);
                    break;
                }

                if(clickedslot != INVALID_INVENTORY_CLICK_SLOT && playertextid == gInventoryPTDSlots[playerid][clickedslot]) {
                    InventorDestroysClickedSlot(playerid);
                    break;
                }

                if(clickedslot != INVALID_INVENTORY_CLICK_SLOT && clickedslot != slot) {
                    new
                        save_amount = GetPlayerInventoryAmountByIDX(playerid, slot),

                        item_clicked_slot = GetPlayerInventoryItemByIDX(playerid, clickedslot),
                        item_amount_clicked_slot = GetPlayerInventoryAmountByIDX(playerid, clickedslot)
                    ;

                    SetPlayerInventoryItemByIDX(playerid, slot, item_clicked_slot);
                    SetPlayerInventoryAmountByIDX(playerid, slot, item_amount_clicked_slot);
                    RelogSlot(playerid, slot);

                    SetPlayerInventoryItemByIDX(playerid, clickedslot, item_idx);
                    SetPlayerInventoryAmountByIDX(playerid, clickedslot, save_amount);
                    RelogSlot(playerid, clickedslot);

                    InventorDestroysClickedSlot(playerid);

                    SetClickedSlot(playerid, slot);
                    PlayerClickSlot(playerid, slot);
                    break;
                }
            }
        }
        if(playertextid == gInventoryGTextDrawNow[playerid][0]) {
            if(player_info[playerid][SKIN] == 154 || player_info[playerid][SKIN] == 140) return 1;
            AddInventoryItem(playerid, player_info[playerid][SKIN], 1);
            player_info[playerid][SKIN] = (player_info[playerid][SEX] == 1) ? (154) : (140);
            SetPlayerSkin(playerid, player_info[playerid][SKIN]);
            UpdatePlayerDataInt(playerid, "skin", player_info[playerid][SKIN]);
            
            PlayerTextDrawHide(playerid, gInventoryGTextDrawNow[playerid][0]);
            PlayerTextDrawSetPreviewModel(playerid, gInventoryGTextDrawNow[playerid][0], player_info[playerid][SKIN]);
            PlayerTextDrawShow(playerid, gInventoryGTextDrawNow[playerid][0]);
            
        }
        if(playertextid == gInventoryPTDClickSlot[playerid][INVENTORY_PTD_USE]) {
            new
                item_idx = GetPlayerInventoryItemByIDX(playerid, clickedslot),
                item_id = GetInventoryItemID(item_idx)
            ;

            UseInventoryItem(playerid, clickedslot, item_idx, gInventoryItem[item_id][iType]);
        }

        if(playertextid == gInventoryPTDClickSlot[playerid][INVENTORY_PTD_INFO]) {
            new
                item_id = GetInventoryItemID(GetPlayerInventoryItemByIDX(playerid, clickedslot)),
                str[400]
            ;

            format(str, sizeof(str),
                "{FFFFFF}�������: {31B404}%s\
                \n{FFFFFF}����������: {31B404}%d{FFFFFF}\
                \n\n%s",
                gInventoryItem[item_id][iName],
                GetPlayerInventoryAmountByIDX(playerid, clickedslot),
                gInventoryItem[item_id][iDesc]
            );
            ShowPlayerDialog(playerid, 0, DIALOG_STYLE_MSGBOX,
                !"����������",
                str,
                !"�������", !""
            );
        }
    }
	if(playertextid == GraphicPIN_PTD[playerid][0] || playertextid == GraphicPIN_PTD[playerid][1] || playertextid == GraphicPIN_PTD[playerid][2] || playertextid == GraphicPIN_PTD[playerid][3])
    {
        if(playertextid == GraphicPIN_PTD[playerid][0]) player_info[playerid][tempENTEREDPIN][GetPVarInt(playerid, "pinpos")] = player_info[playerid][tempPINCHECK][0];
        else if(playertextid == GraphicPIN_PTD[playerid][1]) player_info[playerid][tempENTEREDPIN][GetPVarInt(playerid, "pinpos")] = player_info[playerid][tempPINCHECK][1];
        else if(playertextid == GraphicPIN_PTD[playerid][2]) player_info[playerid][tempENTEREDPIN][GetPVarInt(playerid, "pinpos")] = player_info[playerid][tempPINCHECK][2];
        else if(playertextid == GraphicPIN_PTD[playerid][3]) player_info[playerid][tempENTEREDPIN][GetPVarInt(playerid, "pinpos")] = player_info[playerid][tempPINCHECK][3];
        PlayerPlaySound(playerid, 4203, 0.0, 0.0, 0.0);
        if(GetPVarInt(playerid, "pinpos") == 3)
		{
		    new truepin[5];
			valstr(truepin, player_info[playerid][PIN][0]);
			new enteredpin[5];
			format(enteredpin, sizeof(enteredpin), "%d%d%d%d", player_info[playerid][tempENTEREDPIN][0], player_info[playerid][tempENTEREDPIN][1], player_info[playerid][tempENTEREDPIN][2], player_info[playerid][tempENTEREDPIN][3]);
            for(new i = 0; i < 4; i++)
		    {
		        PlayerTextDrawDestroy(playerid, GraphicPIN_PTD[playerid][i]);
		    }
		    TextDrawHideForPlayer(playerid, GraphicPIN_TD);
		    DeletePVar(playerid, "pinpos");
		    CancelSelectTextDraw(playerid);
			if(strcmp(truepin, enteredpin, false) == 0)
			{
				if(strlen(player_info[playerid][GOOGLEAUTH]) > 2)
				{
				    if(player_info[playerid][GOOGLEAUTHSETTING] == 0)
					{
						if(CheckSubnet(playerid) == 1) PlayerGoLogin(playerid);
						else SPD(playerid, DLG_CHECKGOOGLEAUTH, DIALOG_STYLE_INPUT, !"{ff9300}Google Authenticator", !"{FFFFFF}������� ��� �� ���������� Google Authenticator � ���� ����:", !"�����", "");
					}
					else if(player_info[playerid][GOOGLEAUTHSETTING] == 1)
					{
					    SPD(playerid, DLG_CHECKGOOGLEAUTH, DIALOG_STYLE_INPUT, !"{ff9300}Google Authenticator", !"{FFFFFF}������� ��� �� ���������� Google Authenticator � ���� ����:", !"�����", "");
					}
				}
				else PlayerGoLogin(playerid);
			}
			else
			{
			    SCMError(playerid, !"[������] {FFFFFF}�� ����� �������� ����������� PIN ���");
			    return Kick(playerid);
			}
		}
		else
		{
		    SetPVarInt(playerid, "pinpos", GetPVarInt(playerid, "pinpos")+1);
		    GeneratePinCheck(playerid, GetPVarInt(playerid, "pinpos"));
		}
    }
    return 1;
}

public OnPlayerCommandReceived(playerid, cmd[], params[], flags)
{
    if(GetPVarInt(playerid, "logged") == 0) return 0;
    return 1;
}

stock GiveMoney(playerid, money)
{
	player_info[playerid][MONEY] += money;
	static const fmt_query[] = "UPDATE `users` SET `money` = '%d' WHERE `id` = '%d'";
	new query[sizeof(fmt_query)+(-2+9)+(-2+8)];
	format(query, sizeof(query), fmt_query, player_info[playerid][MONEY], player_info[playerid][ID]);
	mysql_tquery(dbHandle, query);
}

stock ProxDetector(Float:radi, playerid, string[],col1,col2,col3,col4,col5)
{
	new Float:posx;new Float:posy;new Float:posz;new Float:oldposx;new Float:oldposy;new Float:oldposz;new Float:tempposx;new Float:tempposy;new Float:tempposz;
	GetPlayerPos(playerid, oldposx, oldposy, oldposz);
	foreach(new i: Player)
	{
		if(IsPlayerConnected(i))
		{
		    if(GetPlayerVirtualWorld(playerid) == GetPlayerVirtualWorld(i))
			{
				GetPlayerPos(i, posx, posy, posz);
				tempposx = (oldposx -posx);
				tempposy = (oldposy -posy);
				tempposz = (oldposz -posz);
				if(((tempposx < radi/16) && (tempposx > -radi/16)) && ((tempposy < radi/16) && (tempposy > -radi/16)) && ((tempposz < radi/16) && (tempposz > -radi/16))) SCM(i, col1, string);
				else if(((tempposx < radi/8) && (tempposx > -radi/8)) && ((tempposy < radi/8) && (tempposy > -radi/8)) && ((tempposz < radi/8) && (tempposz > -radi/8))) SCM(i, col2, string);
				else if(((tempposx < radi/4) && (tempposx > -radi/4)) && ((tempposy < radi/4) && (tempposy > -radi/4)) && ((tempposz < radi/4) && (tempposz > -radi/4))) SCM(i, col3, string);
				else if(((tempposx < radi/2) && (tempposx > -radi/2)) && ((tempposy < radi/2) && (tempposy > -radi/2)) && ((tempposz < radi/2) && (tempposz > -radi/2))) SCM(i, col4, string);
				else if(((tempposx < radi) && (tempposx > -radi)) && ((tempposy < radi) && (tempposy > -radi)) && ((tempposz < radi) && (tempposz > -radi))) SCM(i, col5, string);
			}
		}
	}
	return 1;
}

stock GiveExp(playerid, exp)
{
	player_info[playerid][EXP] += exp;
	new needexp = (player_info[playerid][LVL]+1)*expmultiply;
    if(player_info[playerid][EXP] >= needexp)
    {
        player_info[playerid][EXP]-=needexp;
        player_info[playerid][LVL]++;
        SCM(playerid, COLOR_WHITE, !"��� ������� �������!");
        if(player_info[playerid][LVL] == 3 && player_info[playerid][REF] != 0)
        {
            SCM(playerid, COLOR_BLUE, "�� �������� �������� ������. �����, ������������ ��� �� ������ ������� ��������������.");
			new newquery[71+(-2+8)];
			format(newquery, sizeof(newquery), "UPDATE `users` SET `refmoney` =  `refmoney` + '5000' WHERE `id` = '%d'", player_info[playerid][REF]);
			mysql_tquery(dbHandle, newquery);
        }
        SetPlayerScore(playerid, player_info[playerid][LVL]);
    }
    static const fmt_query[] = "UPDATE `users` SET `lvl` = '%d', `exp` = '%d' WHERE `id` = '%d'";
	new query[sizeof(fmt_query)+(-2+10)+(-2+6)+(-2+8)];
	format(query, sizeof(query), fmt_query, player_info[playerid][LVL], player_info[playerid][EXP], player_info[playerid][ID]);
	mysql_tquery(dbHandle, query);
}

stock ShowStats(playerid, checkadm)
{
    new needexp = (player_info[playerid][LVL]+1)*expmultiply;
	new dialog[256];
	format(dialog, sizeof(dialog),
		"{FFFFFF}���:\t\t{0089ff}%s\n\
		{FFFFFF}���:\t\t{0089ff}%s\n\
		{FFFFFF}����:\t\t{0089ff}%s\n\
		{FFFFFF}�������:\t{0089ff}%d ���/���\n\
		{FFFFFF}�������:\t{0089ff}%d\n\
		{FFFFFF}����:\t\t{0089ff}%d/%d\n",
	pName(playerid),
	(player_info[playerid][SEX] == 1) ? ("�������") : ("�������"),
	PlayerRaces[player_info[playerid][RACE]-1],
	player_info[playerid][AGE],
	player_info[playerid][LVL],
	player_info[playerid][EXP],needexp
	);
	if(checkadm == 0) SPD(playerid, DLG_STATS, DIALOG_STYLE_MSGBOX, !"{ff9300}���������� ���������", dialog, !"�����", !"�������");
	else SPD(playerid, DLG_NONE, DIALOG_STYLE_MSGBOX, !"{ff9300}���������� ���������", dialog, !"�������", "");
}

stock GetPlayerSubnet(buffer[])
{// by Daniel_Cortez \\ pro-pawn.ru
    for(new i=0,dots=0; ; ++i)
        switch(buffer[i])
        {
            case '\0':
                break;
            case '.':
                if(++dots == 2)
                {
                    buffer[i] = '\0';
                    break;
                }
        }
}

stock GeneratePinCheck(playerid, pos)
{
	new pinstr[5];
	valstr(pinstr, player_info[playerid][PIN][0]);
	new value[2];
    strmid(value, pinstr, pos, pos+1);
    new right = strval(value);
    player_info[playerid][tempPINCHECK][0] = randomEx(9, right);
    player_info[playerid][tempPINCHECK][1] = randomEx(9, right, player_info[playerid][tempPINCHECK][0]);
    player_info[playerid][tempPINCHECK][2] = randomEx(9, right, player_info[playerid][tempPINCHECK][0], player_info[playerid][tempPINCHECK][1]);
    player_info[playerid][tempPINCHECK][3] = randomEx(9, right, player_info[playerid][tempPINCHECK][0], player_info[playerid][tempPINCHECK][1], player_info[playerid][tempPINCHECK][2]);
    player_info[playerid][tempPINCHECK][random(4)] = right;
    for(new i = 0; i < 4; i++)
    {
        new buffer[2];
        valstr(buffer, player_info[playerid][tempPINCHECK][i]);
        PlayerTextDrawSetString(playerid, GraphicPIN_PTD[playerid][i], buffer);
    }
}

forward randomEx(const max_value, ...);
public randomEx(const max_value, ...)
{
    new result;
    rerandom: result = random(max_value + 1);

    for(new i = numargs() + 1; --i != 0;)
        if(result == getarg(i))
            goto rerandom;

    return result;
}

stock CheckSubnet(playerid)
{
    new nowip[16], oldip[16];
	GetPlayerIp(playerid, nowip, sizeof(nowip));
	GetPlayerSubnet(nowip);
	strmid(oldip, player_info[playerid][LASTIP], 0, 16, 16);
	GetPlayerSubnet(oldip);
	if(strcmp(nowip, oldip, true) == 0) return 1;//������� ���������
	else return 0;
}

stock PlayerGoLogin(playerid)
{
    static const fmt_query[] = "SELECT * FROM `users` WHERE `name` = '%e' AND `password` = '%e'";
    new query[sizeof(fmt_query)+(-2+MAX_PLAYER_NAME)+(-2+64)];
	mysql_format(dbHandle, query, sizeof(query), fmt_query, pName(playerid), player_info[playerid][PASSWORD]);
	mysql_tquery(dbHandle, query, "PlayerLogin", "i", playerid);
	
	
}

stock SCMA(color, text[])
{
	foreach(new i: Admins_ITER) SCM(i, color, text);
}

stock FixSVarString(str[], size = sizeof(str))
{
    for (new i = 0; ((str[i] &= 0xFF) != '\0') && (++i != size);) {}
}

//=====================================================   ������� ������   =====================================================
CMD:jp(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 1) return 1;
    if(GetPlayerSpecialAction(playerid) != SPECIAL_ACTION_USEJETPACK )
    {
        return SetPlayerSpecialAction( playerid, SPECIAL_ACTION_USEJETPACK );
    }
    return printf("GetPlayerSpecialAction = %d", GetPlayerSpecialAction(playerid));
}
CMD:test(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 6) return 1;
    new test = strval(params[0]);
    switch(test)
	{
	    case 1: {
	        SetPlayerPos(playerid,1482.1394, -1780.5322, 2981.3540); //�� �� ������ ����
	        SetPlayerInterior(playerid, 1);
	        return 1;
    	}
    	case 2: {
	        SetPlayerPos(playerid,1492.2074,-1786.5863,2676.0129); //�� �� ������ ����
        	SetPlayerInterior(playerid, 1);
	        return 1;
    	}
    	case 3: {
	        SetPlayerPos(playerid,1483.1909, -1848.8917, 3645.6270); //�� �� ������ ����
        	SetPlayerInterior(playerid, 1);
	        return 1;
    	}
	    default: {SCMF(playerid, COLOR_GREY, "�������� %d - ����������", test);}
	}
    return 0;
}

CMD:paydayme(playerid)
{
    if(player_info[playerid][ADMIN] < 6) return 1;
    return PayDay(playerid);
}
CMD:ahelp(playerid)
{
    if(player_info[playerid][ADMIN] < 1) return 1;
	new dialog[97];
	format(dialog, sizeof(dialog),
		"������ �������%s%s%s%s%s",
    (player_info[playerid][ADMIN] >= 2) ? ("\n������ �������") : (""),
    (player_info[playerid][ADMIN] >= 3) ? ("\n������ �������") : (""),
    (player_info[playerid][ADMIN] >= 4) ? ("\n�������� �������") : (""),
    (player_info[playerid][ADMIN] >= 5) ? ("\n����� �������") : (""),
    (player_info[playerid][ADMIN] >= 6) ? ("\n������ �������") : ("")
	);
	return SPD(playerid, DLG_AHELP, DIALOG_STYLE_LIST, !"{ff9300}������� ��������������", dialog, !"�������", !"�������");
}

CMD:rep(playerid, params[])
{
	if(player_info[playerid][ADMIN] < 1) return 1;
	if(sscanf(params, "ds[62]", params[0], params[1])) return SCM(playerid, COLOR_GREY, !"����������� /rep [id ������] [�����]");
	if(GetPVarInt(params[0], "logged") == 0) return SCM(playerid, COLOR_GREY, !"����� �� �����������");
	new string[144];
	format(string, sizeof(string), "������������� %s[%d] ������� ���:{FFFFFF} %s", pName(playerid), playerid, params[1]);
	SCM(playerid, COLOR_LIGHTRED, string);
	format(string, sizeof(string), "[repANS] %s[%d] ��� %s[%d]:{FFFFFF} %s", pName(playerid), playerid, pName(params[0]), params[0], params[1]);
	SCMA(COLOR_TOMATO, string);
	return 1;
}
CMD:ans(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 1) return 1;
    if(Iter_Count(Question_ITER) == 0) return SCM(playerid, COLOR_GREY, "��� ����������� ��������");
	new questionfrom = Iter_Random(Question_ITER);
    Iter_Remove(Question_ITER, questionfrom);
	new dialog[45+(-2+MAX_PLAYER_NAME)+(-2+3)+(-2+97)];
	format(dialog, sizeof(dialog),
		"{11dd77}������{FFFFFF} �� ������ %s[%d]:\n\
		%s",
	pName(questionfrom),
	questionfrom,
	player_info[questionfrom][tempQUESTION]);
	SetPVarInt(playerid, "questionfrom", questionfrom);
	return SPD(playerid, DLG_ANSWERPLAYER, DIALOG_STYLE_INPUT, !"{FFFFFF}����� �� {11dd77}������", dialog, !"��������", !"������");
}
CMD:tpcor(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 3) return 1;
	new Float:tpX, Float:tpY, Float:tpZ;
	if(sscanf(params, "fff", tpX, tpY, tpZ)) return SCM(playerid, COLOR_GREY, !"����������� /tpcor [x] [y] [z]");
	if(GetPlayerState(playerid) == PLAYER_STATE_DRIVER)
    {
        SetVehiclePos(GetPlayerVehicleID(playerid), tpX, tpY, tpZ);
        PutPlayerInVehicle(playerid, GetPlayerVehicleID(playerid), 0);
    }
    else
    {
        SetPlayerPos(playerid, tpX, tpY, tpZ);
    }
    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerInterior(playerid, 0);
	return 1;
}
CMD:setworld(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 3) return 1;
    if(sscanf(params, "dd", params[0], params[1])) return SCM(playerid, COLOR_GREY, !"����������� /setworld [id ������] [id ����. ����]");
    if(GetPVarInt(params[0], "logged") == 0) return SCM(playerid, COLOR_GREY, !"����� �� �����������");
    if(params[1] < 0 || params[1] > 999) return SCM(playerid, COLOR_GREY, !"������� id ����. ���� �� 0 �� 999");
    SetPlayerVirtualWorld(params[0], params[1]);
    new string[59+(-2+MAX_PLAYER_NAME)+(-2+3)+(-2+3)];
    format(string, sizeof(string), "�� ��������������� ������ %s[%d] � ����������� ��� � ID %d", pName(params[0]), params[0], params[1]);
	return SCM(playerid, COLOR_WHITE, string);
}
CMD:setint(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 3) return 1;
    if(sscanf(params, "dd", params[0], params[1])) return SCM(playerid, COLOR_GREY, !"����������� /setint [id ������] [id ���������]");
    if(GetPVarInt(params[0], "logged") == 0) return SCM(playerid, COLOR_GREY, !"����� �� �����������");
    if(params[1] < 0 || params[1] > 50) return SCM(playerid, COLOR_GREY, !"������� id ��������� �� 0 �� 50");
    SetPlayerInterior(params[0], params[1]);
    new string[52+(-2+MAX_PLAYER_NAME)+(-2+3)+(-2+2)];
    format(string, sizeof(string), "�� ��������������� ������ %s[%d] � �������� � ID %d", pName(params[0]), params[0], params[1]);
	return SCM(playerid, COLOR_WHITE, string);
}
CMD:resetadm(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 6) return 1;
    if(sscanf(params, "d", params[0])) return SCM(playerid, COLOR_GREY, !"����������� /resetadm [id ������]");
    if(GetPVarInt(params[0], "logged") == 0) return SCM(playerid, COLOR_GREY, !"����� �� �����������");
    if(player_info[params[0]][ADMIN] == 0) return SCM(playerid, COLOR_GREY, !"����� �� �������� ���������������");
	player_info[params[0]][ADMIN] = 0;
 	static const fmt_query[] = "UPDATE `users` SET `admin` = '%d' WHERE `id` = '%d'";
	new query[sizeof(fmt_query)+(-2+2)+(-2+8)];
	mysql_format(dbHandle, query, sizeof(query), fmt_query, player_info[params[0]][ADMIN], player_info[params[0]][ID]);
	mysql_tquery(dbHandle, query);
	new string[46+(-2+MAX_PLAYER_NAME)+(-2+3)+(-2+MAX_PLAYER_NAME)+(-2+3)];
	format(string, sizeof(string), "[A] %s[%d] ���� � ����� �������������� %s[%d]", pName(playerid), playerid, pName(params[0]), params[0]);
	SCMA(COLOR_TOMATO, string);
	SCM(params[0], COLOR_RED, !"�� ���� ����� � ����� ��������������.");
	return Kick(params[0]);
}
CMD:resetadmoff(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 6) return 1;
    if(sscanf(params, "s", params[0])) return SCM(playerid, COLOR_GREY, !"����������� /resetadmoff [��� ������]");
    foreach(new i:Player)
	{
		if(strcmp(pName(i), params[0], true, 24) == 0) return SCM(playerid, COLOR_GREY, "����� �� ������ ���� ���������. ����������� /resetadm");
	}
    static const fmt_query[] = "SELECT `id`, `admin` FROM `users` WHERE `name` = '%e'";
    new query[sizeof(fmt_query)+(-2+MAX_PLAYER_NAME)];
	mysql_format(dbHandle, query, sizeof(query), fmt_query, params[0]);
	mysql_tquery(dbHandle, query, "CheckAdmin", "is", playerid, params[0]);
	return 1;
}
forward CheckAdmin(playerid, name[]);
public CheckAdmin(playerid, name[])
{
    new rows;
	cache_get_row_count(rows);
	if(rows)
	{
	    new leveladm;
	    cache_get_value_name_int(0, "admin", leveladm);
	    if(leveladm > 0)
	    {
	        new accid;
	        cache_get_value_name_int(0, "id", accid);
	        static const fmt_query[] = "UPDATE `users` SET `admin` = '0' WHERE `id` = '%d'";
			new query[sizeof(fmt_query)+(-2+8)];
			mysql_format(dbHandle, query, sizeof(query), fmt_query, accid);
			mysql_tquery(dbHandle, query);
			new string[53+(-2+MAX_PLAYER_NAME)+(-2+3)+(-2+MAX_PLAYER_NAME)];
			format(string, sizeof(string), "[A] %s[%d] ���� � �������� � ����� �������������� %s", pName(playerid), playerid, name);
			SCMA(COLOR_TOMATO, string);
	    }
	    else SCM(playerid, COLOR_GREY, !"����� �� �������� ���������������.");
	}
	else SCM(playerid, COLOR_GREY, !"������ � ����� ����� �� ����������.");
	return 1;
}
CMD:adm(playerid)
{
    static const fmt_query[] = "SELECT * FROM `newadm` WHERE `name` = '%e'";
    new query[sizeof(fmt_query)+(-2+MAX_PLAYER_NAME)];
	mysql_format(dbHandle, query, sizeof(query), fmt_query, pName(playerid));
	mysql_tquery(dbHandle, query, "CheckNewAdmin", "i", playerid);
}
forward CheckNewAdmin(playerid);
public CheckNewAdmin(playerid)
{
    new rows;
	cache_get_row_count(rows);
	if(rows)
	{
	    if(strlen(player_info[playerid][GOOGLEAUTH]) == 1) return SCM(playerid, COLOR_GREY, "��� ��������� ����� �������������� �������� Google Authenticator");
	    new level;
	    cache_get_value_name_int(0, "level", level);
	    player_info[playerid][ADMIN] = level;
	    static const fmt_query[] = "DELETE FROM `newadm` WHERE `name` = '%e'";
	    new query[sizeof(fmt_query)+(-2+MAX_PLAYER_NAME)];
		mysql_format(dbHandle, query, sizeof(query), fmt_query, pName(playerid));
		mysql_tquery(dbHandle, query);
	    static const fmt_query2[] = "UPDATE `users` SET `admin` = '%d' WHERE `id` = '%d'";
		mysql_format(dbHandle, query, sizeof(query), fmt_query2, player_info[playerid][ADMIN], player_info[playerid][ID]);
		mysql_tquery(dbHandle, query);
		new string[36+(-2+MAX_PLAYER_NAME)];
		format(string, sizeof(string), "[A] �������� ����� ������������� %s", pName(playerid));
		SCMA(COLOR_TOMATO, string);
		Iter_Add(Admins_ITER, playerid);
	}
	return 1;
}
CMD:a(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 1) return 1;
    if(sscanf(params, "s[104]", params[0])) return SCM(playerid, COLOR_GREY, !"����������� /a [���������]");
    if(strlen(params[0]) > 104) return SCM(playerid, COLOR_GREY, !"������� ������� ���������");
    new string[144];
	format(string, sizeof(string), "[A-���] %s[%d]: %s", pName(playerid), playerid, params[0]);
    SCMA(COLOR_TOMATO, string);
	return 1;
}
CMD:admins(playerid)
{
    if(player_info[playerid][ADMIN] < 1) return 1;
    new dialog[1536] = "{FFFFFF}";
    foreach(new i: Admins_ITER)
	{
	    format(dialog, sizeof(dialog), "%s%s[%d] [%d adm lvl]%s\n", dialog, pName(i), i, player_info[i][ADMIN], (PlayerAFK[i] >= 2) ? (" {FF0000}AFK{FFFFFF}") : (""));
	}
	return SPD(playerid, DLG_NONE, DIALOG_STYLE_MSGBOX, !"{ff9300}������������� � ����", dialog, "�������", "");
}
CMD:goto(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 3) return 1;
    if(sscanf(params, "d", params[0])) return SCM(playerid, COLOR_GREY, !"����������� /goto [id ������]");
    if(GetPVarInt(params[0], "logged") == 0) return SCM(playerid, COLOR_GREY, !"����� �� �����������");
    if(params[0] == playerid) return SCM(playerid, COLOR_GREY, !"�� �� ������ ���� ���������������");
    new Float:x, Float:y, Float:z;
    GetPlayerPos(params[0], x, y, z);
    new vw = GetPlayerVirtualWorld(params[0]);
    new int = GetPlayerInterior(params[0]);
    SetPlayerPos(playerid, x+1.0, y+1.0, z);
    SetPlayerVirtualWorld(playerid, vw);
    SetPlayerInterior(playerid, int);
	return 1;
}
CMD:gethere(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 3) return 1;
    if(sscanf(params, "d", params[0])) return SCM(playerid, COLOR_GREY, !"����������� /gethere [id ������]");
    if(GetPVarInt(params[0], "logged") == 0) return SCM(playerid, COLOR_GREY, !"����� �� �����������");
    if(params[0] == playerid) return SCM(playerid, COLOR_GREY, !"�� �� ������ ���� ���������������");
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    new vw = GetPlayerVirtualWorld(playerid);
    new int = GetPlayerInterior(playerid);
    SetPlayerPos(params[0], x+1.0, y+1.0, z);
    SetPlayerVirtualWorld(params[0], vw);
    SetPlayerInterior(params[0], int);
	new string[47+(-2+MAX_PLAYER_NAME)+(-2+3)];
	format(string, sizeof(string), "��� �������������� � ���� ������������� %s[%d]", pName(playerid), playerid);
	return SCM(params[0], COLOR_WHITE, string);
}
CMD:setweather(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 4) return 1;
    if(sscanf(params, "d", params[0])) return SCM(playerid, COLOR_GREY, !"����������� /setweather [id ������ (0-45)]");
	if(!(0 <= params[0] <= 45)) return SCM(playerid, COLOR_GREY, !"����������� id ������ �� 0 �� 45");
 	SetWeatherEx(params[0]);
	new string[54+(-2+2)+(-2+MAX_PLAYER_NAME)+(-2+3)];
	format(string, sizeof(string), "[A] ������ � id:%d ����������� ��������������� %s[%d]", params[0], pName(playerid), playerid);
	SCMA(COLOR_TOMATO, string);
	return 1;
}
CMD:setstatictime(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 4) return 1;
    if(sscanf(params, "d", params[0])) return SCM(playerid, COLOR_GREY, !"����������� /setstatictime [����� (0-23)]");
    if(!(0 <= params[0] <= 23)) return SCM(playerid, COLOR_GREY, !"����������� ����� �� 0 �� 23");
    SetWorldTime(params[0]);
    statictime = true;
    new string[63+(-2+2)+(-2+MAX_PLAYER_NAME)+(-2+3)];
	format(string, sizeof(string), "[A] ����������� ����� %02d:00 ����������� ��������������� %s[%d]", params[0], pName(playerid), playerid);
	SCMA(COLOR_TOMATO, string);
	return 1;
}
CMD:resetstatictime(playerid)
{
    if(player_info[playerid][ADMIN] < 4) return 1;
    new string[52+(-2+MAX_PLAYER_NAME)+(-2+3)];
	format(string, sizeof(string), "[A] ���������� ����� ������� ��������������� %s[%d]", pName(playerid), playerid);
	SCMA(COLOR_TOMATO, string);
	statictime = false;
	new hour, minute;
	gettime(hour, minute);
    foreach(new i:Player)
	{
	    SetPlayerTime(i, hour, minute);
	}
 	return 1;
}
CMD:reginfo(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 3) return 1;
    if(sscanf(params, "d", params[0])) return SCM(playerid, COLOR_GREY, !"����������� /reginfo [id ������]");
    if(GetPVarInt(params[0], "logged") == 0) return SCM(playerid, COLOR_GREY, !"����� �� �����������");

	new regcountry[20], regcity[30], regprovider[30];
    GetIPCountry(player_info[params[0]][REGIP], regcountry);
	GetIPCity(player_info[params[0]][REGIP], regcity);
	GetIPISP(player_info[params[0]][REGIP], regprovider);
	new nowcountry[20], nowcity[30], nowprovider[30];
	GetPlayerCountry(params[0], nowcountry);
	GetPlayerCity(params[0], nowcity);
	GetPlayerISP(params[0], nowprovider);
	new nowip[16];
 	GetPlayerIp(playerid, nowip, sizeof(nowip));
    
	new dialog[512];
	format(dialog, sizeof(dialog),
	"{FFFFFF}�������� ������: {ff9300}%s[%d]{FFFFFF}\n\n\
	���� ��� �����������: %s\n\
	IP ��� �����������: %s\n\
	������ ��� �����������: %s\n\
	����� ��� �����������: %s\n\
	��������� ��� �����������: %s\n\n\
	������� IP: %s\n\
	������� ������: %s\n\
	������� �����: %s\n\
	������� ���������: %s",
	pName(params[0]), params[0],
	player_info[params[0]][REGDATA],
	player_info[params[0]][REGIP],
	regcountry,
	regcity,
	regprovider,
	nowip,
	nowcountry,
	nowcity,
	nowprovider);
	return SPD(playerid, DLG_NONE, DIALOG_STYLE_MSGBOX, !"{ff9300}��������� ��������������� ������ � ��������", dialog, !"�������", "");
}
CMD:plveh(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 3) return 1;
    if(sscanf(params, "dddd", params[0], params[1], params[2], params[3])) return SCM(playerid, COLOR_GREY, !"����������� /plveh [id ������] [id ����] [id ������� �����] [id ������� �����]");
    if(GetPVarInt(params[0], "logged") == 0) return SCM(playerid, COLOR_GREY, !"����� �� �����������");
    if(GetPlayerInterior(params[0]) != 0) return SCM(playerid, COLOR_GREY, !"����� �� ������ ���������� � ���������");
    //if(!(400 <= params[1] <= 700)) return SCM(playerid, COLOR_GREY, !"ID ���������� ������ ���� �� 400 �� 700");
    if(!(0 <= params[2] <= 255)) return SCM(playerid, COLOR_GREY, !"ID ������� ����� ������ ���� �� 0 �� 255");
    if(!(0 <= params[3] <= 255)) return SCM(playerid, COLOR_GREY, !"ID ������� ����� ������ ���� �� 0 �� 255");
    new Float:x, Float:y, Float:z;
    GetPlayerPos(params[0], x, y, z);
    new Float:Angle;
	GetPlayerFacingAngle(playerid, Angle);
    inadmcar[params[0]] = CreateVehicle(params[1], x, y, z, Angle, params[2], params[3], -1);
	PutPlayerInVehicle(params[0], inadmcar[params[0]], 0);
	return 1;
}

CMD:setskin(playerid, params[])
{
    if(player_info[playerid][ADMIN] < 3) return 1;
    if(sscanf(params, "dd", params[0], params[1])) return SCM(playerid, COLOR_GREY, !"����������� /setskin [id ������] [id �����]");
    if(GetPVarInt(params[0], "logged") == 0) return SCM(playerid, COLOR_GREY, !"����� �� �����������");
	SetPlayerSkin(params[0], params[1]);
	return 1;
}
//==============================================================================================================================

//=====================================================   ������� ������   =====================================================
CMD:me(playerid, params[])
{
	if(sscanf(params, "s[118]", params[0])) return SCM(playerid, COLOR_GREY, !"����������� /me [�����]");
	new string[144];
	format(string, sizeof(string), "%s %s", pName(playerid), params[0]);
	SetPlayerChatBubble(playerid, params[0], 0xDE92FFFF, 20, 7500);
	return ProxDetector(20.0, playerid, string, 0xDE92FFFF, 0xDE92FFFF, 0xDE92FFFF, 0xDE92FFFF, 0xDE92FFFF);
}
CMD:ame(playerid, params[])
{
	if(sscanf(params, "s[144]", params[0])) return SCM(playerid, COLOR_GREY, !"����������� /ame [�����]");
	SetPlayerChatBubble(playerid, params[0], 0xDE92FFFF, 20, 7500);
	return 1;
}

CMD:do(playerid, params[])
{
	if(sscanf(params, "s[116]", params[0])) return SCM(playerid, COLOR_GREY, !"����������� /do [�����]");
	new string[144];
	format(string, sizeof(string), "%s (%s)", params[0], pName(playerid));
	SetPlayerChatBubble(playerid, params[0], 0xDE92FFFF, 20, 7500);
	return ProxDetector(20.0, playerid, string, 0xDE92FFFF, 0xDE92FFFF, 0xDE92FFFF, 0xDE92FFFF, 0xDE92FFFF);
}

CMD:try(playerid, params[])
{
	if(sscanf(params, "s[99]", params[0])) return SCM(playerid, COLOR_GREY, !"����������� /try [�����]");
	new string[144];
	format(string, sizeof(string), "%s %s | %s", pName(playerid), params[0], (!random(2)) ? ("{FF0000}��������") : ("{32CD32}������"));
	return ProxDetector(20.0, playerid, string, 0xDE92FFFF, 0xDE92FFFF, 0xDE92FFFF, 0xDE92FFFF, 0xDE92FFFF);
}

CMD:todo(playerid, params[])
{
    if(strlen(params) > 95) return SCM(playerid, COLOR_GREY, !"������� ������� ����� � ��������");
    new message[48], action[49];
	if(sscanf(params, "p<*>s[47]s[48]", message, action)) return SCM(playerid, COLOR_GREY, !"����������� /todo [�����*��������]");
	if(strlen(message) < 2 || strlen(action) < 2) return SCM(playerid, COLOR_GREY, !"����������� /todo [�����*��������]");
	new string[144];
	format(string, sizeof(string), "- '%s' - {DE92FF}������%s %s, %s", message, (player_info[playerid][SEX] == 1) ? ("") : ("�"), pName(playerid), action);
	return ProxDetector(20.0, playerid, string, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE);
}

CMD:n(playerid, params[])
{
    if(sscanf(params, "s[107]", params[0])) return SCM(playerid, COLOR_GREY, !"����������� /n [���������]");
    new string[144];
    format(string, sizeof(string), "(( %s[%d]: %s ))", pName(playerid), playerid, params[0]);
	return ProxDetector(20.0, playerid, string, 0xCCCC99FF, 0xCCCC99FF, 0xCCCC99FF, 0xCCCC99FF, 0xCCCC99FF);
}

CMD:s(playerid, params[])
{
	if(sscanf(params, "s[105]", params[0])) return SCM(playerid, COLOR_GREY, !"����������� /s [�����]");
	new string[144];
    format(string, sizeof(string), "%s[%d] �������: %s", pName(playerid), playerid, params[0]);
	if(GetPlayerState(playerid) == PLAYER_STATE_ONFOOT)
	{
	    ApplyAnimation(playerid, "ON_LOOKERS", "shout_01", 4.1,0,0,0,0,0);
	}
	SetPlayerChatBubble(playerid, params[0], COLOR_WHITE, 25, 7500);
	return ProxDetector(30.0, playerid, string, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE);
}

CMD:menu(playerid)
{
	SPD(playerid, DLG_MAINMENU, DIALOG_STYLE_LIST, !"{ff9300}������� ����",
		!"{0089ff}[1]{FFFFFF} ���������� ���������\n\
		{0089ff}[2]{FFFFFF} ��������� ������������\n\
		{0089ff}[3]{FFFFFF} ����� � ��������������",
	!"�������", !"�������");
	return 1;
}
alias:menu("mn", "mm");

CMD:lift(playerid)
{
	if(IsPlayerInRangeOfPoint(playerid, 2.5, -773.5633,-1782.9663,13.9770) && minefirstlift[3] == 1)
	{
	    MoveDynamicObject(minefirstlift[1], -769.6777, -1783.7776, 14.2662, 0.7);
   	 	minefirstlift[3] = 2;
	    SetTimer("MineFirstLiftDown", 5000, false);
	}
	if(IsPlayerInRangeOfPoint(playerid, 2.5, -746.2267,-1777.1226,13.9770) && minesecondlift[3] == 1)
	{
	    if(player_info[playerid][LOWWORKSKILL][0] < 5000) return SCM(playerid, COLOR_GREY, !"��� ���������� ������ �����. ������� ����������� ������� (�������� ����� 5000��)");
     	MoveDynamicObject(minesecondlift[1], -748.9438, -1779.9019, 14.2662, 0.7);
     	minesecondlift[3] = 2;
	    SetTimer("MineSecondLiftDown", 5000, false);
	}
	if(IsPlayerInRangeOfPoint(playerid, 2.5, -773.4855,-1782.7478,-38.9230) && minefirstlift[3] == 3)
	{
	    MoveDynamicObject(minefirstlift[2], -769.6777, -1783.7776, -37.3100, 0.7);
     	minefirstlift[3] = 2;
	    SetTimer("MineFirstLiftUp", 5000, false);
	}
	if(IsPlayerInRangeOfPoint(playerid, 2.5, -745.9865,-1777.3615,-88.9030) && minesecondlift[3] == 3)
	{
	    if(player_info[playerid][LOWWORKSKILL][0] < 5000) return SCM(playerid, COLOR_GREY, !"��� ���������� ������ �����. ������� ����������� ������� (�������� ����� 5000��)");
     	MoveDynamicObject(minesecondlift[2], -748.9438, -1779.9019, -87.3062, 0.7);
     	minesecondlift[3] = 2;
	    SetTimer("MineSecondLiftUp", 5000, false);
	}
	return 1;
}
forward MineFirstLiftDown();
public MineFirstLiftDown()
{
	MoveDynamicObject(minefirstlift[0], -773.5040, -1783.1396, -38.5600, 3.0);
}
forward MineFirstLiftDownDoorsOpen();
public MineFirstLiftDownDoorsOpen()
{
    minefirstlift[3] = 3;
}
forward MineSecondLiftDown();
public MineSecondLiftDown()
{
 	MoveDynamicObject(minesecondlift[0], -746.1660, -1777.1144, -88.5400, 3.0);
}
forward MineSecondLiftDownDoorsOpen();
public MineSecondLiftDownDoorsOpen()
{
    minesecondlift[3] = 3;
}
forward MineFirstLiftUp();
public MineFirstLiftUp()
{
    MoveDynamicObject(minefirstlift[0], -773.5040, -1783.1396, 14.3400, 3.0);
}
forward MineFirstLiftUpDoorsOpen();
public MineFirstLiftUpDoorsOpen()
{
    minefirstlift[3] = 1;
}
forward MineSecondLiftUp();
public MineSecondLiftUp()
{
    MoveDynamicObject(minesecondlift[0], -746.1660, -1777.1144, 14.3400, 3.0);
}
forward MineSecondLiftUpDoorsOpen();
public MineSecondLiftUpDoorsOpen()
{
    minesecondlift[3] = 1;
}
CMD:myreferals(playerid)
{
    static const fmt_query[] = "SELECT `name`, `lvl` FROM `users` WHERE `ref` = '%d'";
	new query[sizeof(fmt_query)+(-2+8)];
	mysql_format(dbHandle, query, sizeof(query), fmt_query, player_info[playerid][ID]);
	mysql_tquery(dbHandle, query, "FindMyReferals", "i", playerid);
	return 1;
}
forward FindMyReferals(playerid);
public FindMyReferals(playerid)
{
    new rows;
	cache_get_row_count(rows);
	if(rows)
	{
	    new dialog[2048] = "�������\t�������", refname[MAX_PLAYER_NAME], reflvl;
	    for(new i = 0; i < rows; i++)
	    {
	        cache_get_value_name(i, "name", refname, MAX_PLAYER_NAME);
	        cache_get_value_name_int(i, "lvl", reflvl);
			format(dialog, sizeof(dialog), "%s\n%s\t%d", dialog, refname, reflvl);
	    }
	    SPD(playerid, DLG_NONE, DIALOG_STYLE_TABLIST_HEADERS, !"{ff9300}���� ��������", dialog, "�������", "");
	}
	else
	{
	    SPD(playerid, DLG_NONE, DIALOG_STYLE_MSGBOX, !"{ff9300}���� ��������", "{FFFFFF}� ��� ��� ���������", "�������", "");
	}
}

//inventory
stock GetPlayerInventoryItemByIDX(playerid, slot) {
    if(!(0 <= slot <= INVENTORY_MAX_SLOT - 1))
        return -1;

    return pInventoryData[playerid][idItem][slot];
}



stock GetPlayerInventoryAmountByIDX(playerid, slot) {
    if(!(0 <= slot <= INVENTORY_MAX_SLOT - 1))
        return -1;

    return pInventoryData[playerid][idAmount][slot];
}

stock SetPlayerInventoryItemByIDX(playerid, slot, itemid) {
    if(!(0 <= slot <= INVENTORY_MAX_SLOT - 1))
        return 0;

    pInventoryData[playerid][idItem][slot] = itemid;

    if(IsPlayerOpenInventory(playerid)) {
        RelogSlot(playerid, slot);
    }
    return 1;
}

stock SetPlayerInventoryAmountByIDX(playerid, slot, amount) {
    if(!(0 <= slot <= INVENTORY_MAX_SLOT - 1))
        return -1;

    pInventoryData[playerid][idAmount][slot] = amount;

    if(IsPlayerOpenInventory(playerid)) {
        RelogSlot(playerid, slot);
    }
    return 1;
}

stock AddPlayerInventoryAmountByIDX(playerid, slot, amount) {
    if(!(0 <= slot <= INVENTORY_MAX_SLOT - 1))
        return -1;

    pInventoryData[playerid][idAmount][slot] += amount;

    if(IsPlayerOpenInventory(playerid)) {
        RelogSlot(playerid, slot);
    }
    return 1;
}

stock DelPlayerInventoryAmountByIDX(playerid, slot, amount) {
    if(!(0 <= slot <= INVENTORY_MAX_SLOT - 1))
        return -1;
    pInventoryData[playerid][idAmount][slot] -= amount;
    if(IsPlayerOpenInventory(playerid)) {
        RelogSlot(playerid, slot);
    }
    return 1;
}


stock IsPlayerOpenInventory(playerid) {
    return gInventoryOpen{playerid};
}

stock SetStatusInventory(playerid, bool: status) {
    return gInventoryOpen{playerid} = status;
}

stock IsPlayrClickSlot(playerid) {
    return gInventoryClickSlot[playerid] != INVALID_INVENTORY_CLICK_SLOT;
}

stock SetClickedSlot(playerid, slot) {
    return gInventoryClickSlot[playerid] = slot;
}

stock ClickedSlot(playerid) {
    return gInventoryClickSlot[playerid];
}

stock GetInventoryItemID(item) {
    for(new item_id; item_id < sizeof(gInventoryItem); item_id++) {
        if(gInventoryItem[item_id][iItemID] != item)
              continue;

        return item_id;
    }
    return 0;
}

stock AddInventoryItem(playerid, itemid, amount) {
    new item_id = GetInventoryItemID(itemid);
    if(gInventoryItem[item_id][iItemID] == INVALID_INVENTORY_ITEM_ID)
        return -1;

    new bool: no_full;
    for(new slot; slot < INVENTORY_SIZE; slot++) {
        if(GetPlayerInventoryItemByIDX(playerid, slot) != itemid) {
            if(GetPlayerInventoryItemByIDX(playerid, slot))
                continue;

            SetPlayerInventoryItemByIDX(playerid, slot, itemid);
            SetPlayerInventoryAmountByIDX(playerid, slot, amount);

            no_full = true;
            break;
        }
        else {
            AddPlayerInventoryAmountByIDX(playerid, slot, amount);

            no_full = true;
            break;
        }
    }
    new string[300];
   	format(string, sizeof(string), "{FFFF00}[���������] {FFFFFF}������� {CCCCCC}\"%s\" {FFFFFF}�������� � ��� � ��������� � ����������: %d ��.", gInventoryItem[itemid][iName], amount);
   	SCM(playerid, COLOR_WHITE, string);
   	SavePlayerInventory(playerid);
    if(!no_full) {
        return SendClientMessage(playerid, -1, !"{FFFF00}[���������] {FFFFFF}� ��� ������ ���������, �������� ������� ����������!");

    }

    return 0;
}

stock RemoveInventoryItem(playerid, itemid, amount = 1) {
    for(new slot; slot < INVENTORY_SIZE; slot++) {
        if(GetPlayerInventoryItemByIDX(playerid, slot) != itemid)
            continue;
        new string[300];
    	format(string, sizeof(string), "{FFFF00}[���������] {FFFFFF}������� {CCCCCC}\"%s\" {FFFFFF}������ �� ������ ��������� � ����������: %d ��.", gInventoryItem[pInventoryData[playerid][idItem][slot]][iName], amount);
    	SCM(playerid, COLOR_WHITE, string);
        DelPlayerInventoryAmountByIDX(playerid, slot, amount);
        SavePlayerInventory(playerid);
        if(GetPlayerInventoryAmountByIDX(playerid, slot) < 1) {
            SetPlayerInventoryItemByIDX(playerid, slot, INVALID_INVENTORY_ITEM_ID);
        }
    }
}

stock CreateInventoryGTextDraws() {
    gInventoryGTextDraw[INVENTORY_GTD_BG] =
    TextDrawCreate            (449.9, 247.1, !"_");
    TextDrawLetterSize        (gInventoryGTextDraw[INVENTORY_GTD_BG], 0.0, 20.9);
    TextDrawTextSize          (gInventoryGTextDraw[INVENTORY_GTD_BG], 600.6, 5.0);
    TextDrawUseBox            (gInventoryGTextDraw[INVENTORY_GTD_BG], 1);
    TextDrawBoxColor          (gInventoryGTextDraw[INVENTORY_GTD_BG], 112);

    gInventoryGTextDraw[INVENTORY_GTD_TEXT] =
    TextDrawCreate            (500.9, 235.5, !"Inventory");
    TextDrawLetterSize        (gInventoryGTextDraw[INVENTORY_GTD_TEXT], 0.2, 1.3);
    TextDrawFont              (gInventoryGTextDraw[INVENTORY_GTD_TEXT], 2);
    TextDrawSetShadow         (gInventoryGTextDraw[INVENTORY_GTD_TEXT], 0);

    gInventoryGTextDraw[INVENTORY_GTD_CLOSE] =
    TextDrawCreate            (595.6, 235.3, !"X");
    TextDrawLetterSize        (gInventoryGTextDraw[INVENTORY_GTD_CLOSE], 0.3, 1.0);
    TextDrawTextSize          (gInventoryGTextDraw[INVENTORY_GTD_CLOSE], 8.0, 8.0);
    TextDrawColor             (gInventoryGTextDraw[INVENTORY_GTD_CLOSE], -16777104);
    TextDrawAlignment         (gInventoryGTextDraw[INVENTORY_GTD_CLOSE], 2);
    TextDrawSetShadow         (gInventoryGTextDraw[INVENTORY_GTD_CLOSE], 0);
    TextDrawSetSelectable     (gInventoryGTextDraw[INVENTORY_GTD_CLOSE], true);
    
    gInventoryGTextDrawBG[0] = TextDrawCreate(419.000000, 148.000000, "_");
	TextDrawFont(gInventoryGTextDrawBG[0], 1);
	TextDrawLetterSize(gInventoryGTextDrawBG[0], 0.733333, 21.399944);
	TextDrawTextSize(gInventoryGTextDrawBG[0], 309.500000, 381.500000);
	TextDrawSetOutline(gInventoryGTextDrawBG[0], 1);
	TextDrawSetShadow(gInventoryGTextDrawBG[0], 0);
	TextDrawAlignment(gInventoryGTextDrawBG[0], 2);
	TextDrawColor(gInventoryGTextDrawBG[0], 255);
	TextDrawBackgroundColor(gInventoryGTextDrawBG[0], 255);
	TextDrawBoxColor(gInventoryGTextDrawBG[0], 336860927);
	TextDrawUseBox(gInventoryGTextDrawBG[0], 1);
	TextDrawSetProportional(gInventoryGTextDrawBG[0], 1);
	TextDrawSetSelectable(gInventoryGTextDrawBG[0], 0);

	gInventoryGTextDrawBG[1] = TextDrawCreate(352.000000, 148.000000, "_");
	TextDrawFont(gInventoryGTextDrawBG[1], 1);
	TextDrawLetterSize(gInventoryGTextDrawBG[1], 0.600000, 21.399942);
	TextDrawTextSize(gInventoryGTextDrawBG[1], 298.500000, -1.500000);
	TextDrawSetOutline(gInventoryGTextDrawBG[1], 1);
	TextDrawSetShadow(gInventoryGTextDrawBG[1], 0);
	TextDrawAlignment(gInventoryGTextDrawBG[1], 2);
	TextDrawColor(gInventoryGTextDrawBG[1], -1);
	TextDrawBackgroundColor(gInventoryGTextDrawBG[1], 370546431);
	TextDrawBoxColor(gInventoryGTextDrawBG[1], 135);
	TextDrawUseBox(gInventoryGTextDrawBG[1], 1);
	TextDrawSetProportional(gInventoryGTextDrawBG[1], 1);
	TextDrawSetSelectable(gInventoryGTextDrawBG[1], 0);

	gInventoryGTextDrawBG[2] = TextDrawCreate(289.000000, 238.000000, "menu");
	TextDrawFont(gInventoryGTextDrawBG[2], 2);
	TextDrawLetterSize(gInventoryGTextDrawBG[2], 0.300000, 1.100000);
	TextDrawTextSize(gInventoryGTextDrawBG[2], 8.000000, 106.000000);
	TextDrawSetOutline(gInventoryGTextDrawBG[2], 0);
	TextDrawSetShadow(gInventoryGTextDrawBG[2], 0);
	TextDrawAlignment(gInventoryGTextDrawBG[2], 2);
	TextDrawColor(gInventoryGTextDrawBG[2], -1);
	TextDrawBackgroundColor(gInventoryGTextDrawBG[2], 255);
	TextDrawBoxColor(gInventoryGTextDrawBG[2], 454761471);
	TextDrawUseBox(gInventoryGTextDrawBG[2], 1);
	TextDrawSetProportional(gInventoryGTextDrawBG[2], 1);
	TextDrawSetSelectable(gInventoryGTextDrawBG[2], 1);

	gInventoryGTextDrawBG[3] = TextDrawCreate(289.000000, 257.000000, "Settings");
	TextDrawFont(gInventoryGTextDrawBG[3], 2);
	TextDrawLetterSize(gInventoryGTextDrawBG[3], 0.300000, 1.100000);
	TextDrawTextSize(gInventoryGTextDrawBG[3], 8.000000, 106.000000);
	TextDrawSetOutline(gInventoryGTextDrawBG[3], 0);
	TextDrawSetShadow(gInventoryGTextDrawBG[3], 0);
	TextDrawAlignment(gInventoryGTextDrawBG[3], 2);
	TextDrawColor(gInventoryGTextDrawBG[3], -1);
	TextDrawBackgroundColor(gInventoryGTextDrawBG[3], 255);
	TextDrawBoxColor(gInventoryGTextDrawBG[3], 454761471);
	TextDrawUseBox(gInventoryGTextDrawBG[3], 1);
	TextDrawSetProportional(gInventoryGTextDrawBG[3], 1);
	TextDrawSetSelectable(gInventoryGTextDrawBG[3], 1);

	gInventoryGTextDrawBG[4] = TextDrawCreate(289.000000, 277.000000, "rewards");
	TextDrawFont(gInventoryGTextDrawBG[4], 2);
	TextDrawLetterSize(gInventoryGTextDrawBG[4], 0.300000, 1.100000);
	TextDrawTextSize(gInventoryGTextDrawBG[4], 8.000000, 106.000000);
	TextDrawSetOutline(gInventoryGTextDrawBG[4], 0);
	TextDrawSetShadow(gInventoryGTextDrawBG[4], 0);
	TextDrawAlignment(gInventoryGTextDrawBG[4], 2);
	TextDrawColor(gInventoryGTextDrawBG[4], -1);
	TextDrawBackgroundColor(gInventoryGTextDrawBG[4], 255);
	TextDrawBoxColor(gInventoryGTextDrawBG[4], 454761471);
	TextDrawUseBox(gInventoryGTextDrawBG[4], 1);
	TextDrawSetProportional(gInventoryGTextDrawBG[4], 1);
	TextDrawSetSelectable(gInventoryGTextDrawBG[4], 1);

	gInventoryGTextDrawBG[5] = TextDrawCreate(289.000000, 296.000000, "Vehicles");
	TextDrawFont(gInventoryGTextDrawBG[5], 2);
	TextDrawLetterSize(gInventoryGTextDrawBG[5], 0.300000, 1.100000);
	TextDrawTextSize(gInventoryGTextDrawBG[5], 8.000000, 106.000000);
	TextDrawSetOutline(gInventoryGTextDrawBG[5], 0);
	TextDrawSetShadow(gInventoryGTextDrawBG[5], 0);
	TextDrawAlignment(gInventoryGTextDrawBG[5], 2);
	TextDrawColor(gInventoryGTextDrawBG[5], -1);
	TextDrawBackgroundColor(gInventoryGTextDrawBG[5], 255);
	TextDrawBoxColor(gInventoryGTextDrawBG[5], 454761471);
	TextDrawUseBox(gInventoryGTextDrawBG[5], 1);
	TextDrawSetProportional(gInventoryGTextDrawBG[5], 1);
	TextDrawSetSelectable(gInventoryGTextDrawBG[5], 1);

	gInventoryGTextDrawBG[6] = TextDrawCreate(289.000000, 315.000000, "House");
	TextDrawFont(gInventoryGTextDrawBG[6], 2);
	TextDrawLetterSize(gInventoryGTextDrawBG[6], 0.300000, 1.100000);
	TextDrawTextSize(gInventoryGTextDrawBG[6], 8.000000, 106.000000);
	TextDrawSetOutline(gInventoryGTextDrawBG[6], 0);
	TextDrawSetShadow(gInventoryGTextDrawBG[6], 0);
	TextDrawAlignment(gInventoryGTextDrawBG[6], 2);
	TextDrawColor(gInventoryGTextDrawBG[6], -1);
	TextDrawBackgroundColor(gInventoryGTextDrawBG[6], 255);
	TextDrawBoxColor(gInventoryGTextDrawBG[6], 454761471);
	TextDrawUseBox(gInventoryGTextDrawBG[6], 1);
	TextDrawSetProportional(gInventoryGTextDrawBG[6], 1);
	TextDrawSetSelectable(gInventoryGTextDrawBG[6], 1);

	gInventoryGTextDrawBG[7] = TextDrawCreate(489.000000, 148.000000, "INVENTORY");
	TextDrawFont(gInventoryGTextDrawBG[7], 2);
	TextDrawLetterSize(gInventoryGTextDrawBG[7], 0.416666, 1.300000);
	TextDrawTextSize(gInventoryGTextDrawBG[7], 400.000000, 17.000000);
	TextDrawSetOutline(gInventoryGTextDrawBG[7], 0);
	TextDrawSetShadow(gInventoryGTextDrawBG[7], 0);
	TextDrawAlignment(gInventoryGTextDrawBG[7], 2);
	TextDrawColor(gInventoryGTextDrawBG[7], -1061109505);
	TextDrawBackgroundColor(gInventoryGTextDrawBG[7], 255);
	TextDrawBoxColor(gInventoryGTextDrawBG[7], 50);
	TextDrawUseBox(gInventoryGTextDrawBG[7], 0);
	TextDrawSetProportional(gInventoryGTextDrawBG[7], 1);
	TextDrawSetSelectable(gInventoryGTextDrawBG[7], 0);

	gInventoryGTextDrawBG[8] = TextDrawCreate(583.000000, 326.000000, "close");
	TextDrawFont(gInventoryGTextDrawBG[8], 2);
	TextDrawLetterSize(gInventoryGTextDrawBG[8], 0.300000, 1.100000);
	TextDrawTextSize(gInventoryGTextDrawBG[8], 7.000000, 38.500000);
	TextDrawSetOutline(gInventoryGTextDrawBG[8], 0);
	TextDrawSetShadow(gInventoryGTextDrawBG[8], 0);
	TextDrawAlignment(gInventoryGTextDrawBG[8], 2);
	TextDrawColor(gInventoryGTextDrawBG[8], -1);
	TextDrawBackgroundColor(gInventoryGTextDrawBG[8], 255);
	TextDrawBoxColor(gInventoryGTextDrawBG[8], 0);
	TextDrawUseBox(gInventoryGTextDrawBG[8], 1);
	TextDrawSetProportional(gInventoryGTextDrawBG[8], 1);
	TextDrawSetSelectable(gInventoryGTextDrawBG[8], 1);
}


stock InventoryDestroySlots(playerid) {
    
    
    for(new slot; slot < INVENTORY_SIZE; slot++) {
        PlayerTextDrawDestroy(playerid, gInventoryPTDSlots[playerid][slot]);
        gInventoryPTDSlots[playerid][slot] = PlayerText: INVALID_TEXT_DRAW;

        PlayerTextDrawDestroy(playerid, gInventoryPTDTextSlots[playerid][INVENTORY_PTD_AMOUNT][slot]);

        gInventoryPTDTextSlots[playerid][INVENTORY_PTD_AMOUNT][slot] = PlayerText: INVALID_TEXT_DRAW;

    }
    
    
}

stock InventorDestroysClickedSlot(playerid) {
    SetClickedSlot(playerid, INVALID_INVENTORY_CLICK_SLOT);

    for(new slot; slot < MAX_INVENTORY_PTD_CLICKSLOT; slot++) {
        PlayerTextDrawDestroy(playerid, gInventoryPTDClickSlot[playerid][slot]);
        gInventoryPTDClickSlot[playerid][slot] = PlayerText: INVALID_TEXT_DRAW;
    }
}

stock ShowPlayerInventory(playerid) {
    if(IsPlayerOpenInventory(playerid)) {
        InventoryDestroySlots(playerid);

        if(IsPlayrClickSlot(playerid)) {
            InventorDestroysClickedSlot(playerid);
        }
    }
    new Float:vx, Float:vy, Float:vz, Float:velocity;
    GetPlayerVelocity(playerid, vx, vy, vz);
    velocity = floatsqroot(vx * vx + vy * vy + vz * vz);
    //printf("Player velocity = %f", velocity);
    if(velocity > 0.07) return SCM(playerid, COLOR_WHITE, "{BE2D2D}[������] {FFFFFF}����� ������� ���������, ����� ������������.");
    	
    //TextDrawShowForPlayer(playerid, gInventoryGTextDraw[INVENTORY_GTD_BG]);
    //TextDrawShowForPlayer(playerid, gInventoryGTextDraw[INVENTORY_GTD_TEXT]);
    //TextDrawShowForPlayer(playerid, gInventoryGTextDraw[INVENTORY_GTD_CLOSE]);
    for(new i; i < 9; i++) {
        TextDrawShowForPlayer(playerid, Text:gInventoryGTextDrawBG[i]);
    }
    PlayerTextDrawSetPreviewModel(playerid, gInventoryGTextDrawNow[playerid][0], player_info[playerid][SKIN]);
    new amount[5];
    for(new slot, x, y; slot < INVENTORY_SIZE; slot++) {
        gInventoryPTDSlots[playerid][slot] =
        CreatePlayerTextDraw            (playerid, 360 + (x * INVENTORY_SPACE_SLOTS), 168 + (y * INVENTORY_SPACE_SLOTS), !"_");
        PlayerTextDrawTextSize          (playerid, gInventoryPTDSlots[playerid][slot], 39.0, 38.0);
        PlayerTextDrawBackgroundColor   (playerid, gInventoryPTDSlots[playerid][slot], 125);
        PlayerTextDrawBoxColor   		(playerid, gInventoryPTDSlots[playerid][slot], 255);
        PlayerTextDrawFont              (playerid, gInventoryPTDSlots[playerid][slot], 5);
        PlayerTextDrawSetSelectable     (playerid, gInventoryPTDSlots[playerid][slot], true);

        new
            item_idx = GetPlayerInventoryItemByIDX(playerid, slot),
            item_id = GetInventoryItemID(item_idx),

            item_amount_idx = GetPlayerInventoryAmountByIDX(playerid, slot)
        ;

        PlayerTextDrawSetPreviewRot     (playerid, gInventoryPTDSlots[playerid][slot],
            gInventoryItem[item_id][iItemPosX], gInventoryItem[item_id][iItemPosY], gInventoryItem[item_id][iItemPosZ], gInventoryItem[item_id][iItemPosC]
        );

        PlayerTextDrawSetPreviewModel   (playerid, gInventoryPTDSlots[playerid][slot],
            (item_idx != INVALID_INVENTORY_ITEM_ID) ? (18670) : (gInventoryItem[item_id][iModel])
        );

        PlayerTextDrawShow(playerid, gInventoryPTDSlots[playerid][slot]);

        format(amount, sizeof(amount),
            "%d",
            item_amount_idx
        );

        gInventoryPTDTextSlots[playerid][INVENTORY_PTD_AMOUNT][slot] =
        CreatePlayerTextDraw            (playerid, 396 + (x * INVENTORY_SPACE_SLOTS), 200  + (y * INVENTORY_SPACE_SLOTS), amount);
        PlayerTextDrawAlignment         (playerid, gInventoryPTDTextSlots[playerid][INVENTORY_PTD_AMOUNT][slot], 3);
        PlayerTextDrawLetterSize        (playerid, gInventoryPTDTextSlots[playerid][INVENTORY_PTD_AMOUNT][slot], 0.0961, 0.5712);
        PlayerTextDrawSetShadow         (playerid, gInventoryPTDTextSlots[playerid][INVENTORY_PTD_AMOUNT][slot], 0);

		
        if(item_amount_idx > 1) {
            PlayerTextDrawShow(playerid, gInventoryPTDTextSlots[playerid][INVENTORY_PTD_AMOUNT][slot]);
        }
        PlayerTextDrawShow(playerid, gInventoryGTextDrawNow[playerid][0]);
        PlayerTextDrawShow(playerid, gInventoryGTextDrawNow[playerid][1]);
        if( ++ x >= INVENTORY_WIDTH) {
            x = 0;
            y ++;
        }
    }

    SetStatusInventory(playerid, true);
    SelectTextDraw(playerid, 0xFAAC58FF);
	return 1;
}

stock HidePlayerInventory(playerid) {
    InventoryDestroySlots(playerid);

    if(IsPlayrClickSlot(playerid)) {
        InventorDestroysClickedSlot(playerid);
    }

    //TextDrawHideForPlayer(playerid, gInventoryGTextDraw[INVENTORY_GTD_BG]);
   // TextDrawHideForPlayer(playerid, gInventoryGTextDraw[INVENTORY_GTD_TEXT]);
    //TextDrawHideForPlayer(playerid, gInventoryGTextDraw[INVENTORY_GTD_CLOSE]);
    
    for(new i; i < 9; i++) {
        TextDrawHideForPlayer(playerid, Text:gInventoryGTextDrawBG[i]);
    }
    PlayerTextDrawHide(playerid, gInventoryGTextDrawNow[playerid][0]);
    PlayerTextDrawHide(playerid, gInventoryGTextDrawNow[playerid][1]);
    
    SetStatusInventory(playerid, false);
    CancelSelectTextDraw(playerid);
}
stock CountPlayerInventoryItem(playerid, itemid)
{
    for(new slot; slot < INVENTORY_SIZE; slot++) {
        PlayerTextDrawDestroy(playerid, gInventoryPTDSlots[playerid][slot]);
        gInventoryPTDSlots[playerid][slot] = PlayerText: INVALID_TEXT_DRAW;

        PlayerTextDrawDestroy(playerid, gInventoryPTDTextSlots[playerid][INVENTORY_PTD_AMOUNT][slot]);

        gInventoryPTDTextSlots[playerid][INVENTORY_PTD_AMOUNT][slot] = PlayerText: INVALID_TEXT_DRAW;

    }
}
stock GetPlayerInventoryAmount(playerid, itemid) {
    for(new slot; slot < INVENTORY_SIZE; slot++) {
        if(pInventoryData[playerid][idItem][slot] == itemid) return pInventoryData[playerid][idAmount][slot];
	}
    return 0;
}
stock UseInventoryItem(playerid, slot, itemid, type) {
    switch(type) {
    	case ITEM_TYPE_WEAPON: {
    	    SetPVarInt(playerid, "weapon_itemid", itemid);
    	    //SetPVarInt(playerid, "weapon_slot", slot);
            SPD(playerid, DLG_WEAPON, DIALOG_STYLE_INPUT,  gInventoryItem[itemid][iName], "������� ���������� ��������, ������� ������� ������������", !"�����", !"�����");
    	    InventorDestroysClickedSlot(playerid);
    	    return 1;
    	}
        case ITEM_TYPE_SKIN: {
        	if (IsPlayerInAnyVehicle(playerid)) return SCM(playerid, COLOR_WHITE, "{BE2D2D}[������] {FFFFFF}���� ������� ������ ������������ � ������");
            if(GetPlayerSkin(playerid) == gInventoryItem[itemid][iModel])
                return 1;
            if(player_info[playerid][SKIN] != 154 && player_info[playerid][SKIN] != 140) return SCM(playerid, COLOR_WHITE, "{BE2D2D}[������] {FFFFFF}�� ��� ��� ���� �����-�� ������, ����� ����� ������, ����� ����� �������.");

            SetPlayerSkin(playerid, gInventoryItem[itemid][iModel]);
            player_info[playerid][SKIN] = gInventoryItem[itemid][iModel];
            UpdatePlayerDataInt(playerid, "skin", player_info[playerid][SKIN]);
            PlayerTextDrawHide(playerid, gInventoryGTextDrawNow[playerid][0]);
            PlayerTextDrawSetPreviewModel(playerid, gInventoryGTextDrawNow[playerid][0], player_info[playerid][SKIN]);
            PlayerTextDrawShow(playerid, gInventoryGTextDrawNow[playerid][0]);
		}
    }

    if(GetPlayerInventoryAmountByIDX(playerid, slot) > 1) {
        DelPlayerInventoryAmountByIDX(playerid, slot, 1);
    }
    else {
        new string[300];
    	format(string, sizeof(string), "{FFFF00}[���������] {FFFFFF}������� {CCCCCC}\"%s\" {FFFFFF}������ �� ������ ��������� � ����������: %d ��.", gInventoryItem[pInventoryData[playerid][idItem][slot]][iName], 1);
    	SCM(playerid, COLOR_WHITE, string);
        SetPlayerInventoryItemByIDX(playerid, slot, INVALID_INVENTORY_ITEM_ID);
        SetPlayerInventoryAmountByIDX(playerid, slot, 0);
    }

    InventorDestroysClickedSlot(playerid);
    SavePlayerInventory(playerid);
    return 1;
}

stock RelogSlot(playerid, slot) {
    PlayerTextDrawHide(playerid, gInventoryPTDSlots[playerid][slot]);

    new
        item_idx = GetPlayerInventoryItemByIDX(playerid, slot),
        item_id = GetInventoryItemID(item_idx),

        item_amount_idx = GetPlayerInventoryAmountByIDX(playerid, slot)
    ;

    PlayerTextDrawSetPreviewRot     (playerid, gInventoryPTDSlots[playerid][slot],
        gInventoryItem[item_id][iItemPosX], gInventoryItem[item_id][iItemPosY], gInventoryItem[item_id][iItemPosZ], gInventoryItem[item_id][iItemPosC]
    );

    PlayerTextDrawSetPreviewModel   (playerid, gInventoryPTDSlots[playerid][slot],
        (item_idx == INVALID_INVENTORY_ITEM_ID) ? (18670) : (gInventoryItem[item_id][iModel])
    );
    PlayerTextDrawShow(playerid, gInventoryPTDSlots[playerid][slot]);

    PlayerTextDrawHide(playerid, gInventoryPTDTextSlots[playerid][INVENTORY_PTD_AMOUNT][slot]);

    new amount[5];
    format(amount, sizeof(amount),
        "%d",
        item_amount_idx
    );
    PlayerTextDrawSetString(playerid, gInventoryPTDTextSlots[playerid][INVENTORY_PTD_AMOUNT][slot], amount);

    if(item_amount_idx > 1) {
        PlayerTextDrawShow(playerid, gInventoryPTDTextSlots[playerid][INVENTORY_PTD_AMOUNT][slot]);
    }
}

stock PlayerClickSlot(playerid, slot) {
    new
        Float:pos_X = (slot % INVENTORY_WIDTH) * (INVENTORY_SPACE_SLOTS + 2.0),
        Float:pos_Y = (slot / INVENTORY_WIDTH) * (INVENTORY_SPACE_SLOTS + 2.0),

        item_id = GetInventoryItemID(GetPlayerInventoryItemByIDX(playerid, slot))
    ;

    gInventoryPTDClickSlot[playerid][INVENTORY_PTD_USE_BG] =
    CreatePlayerTextDraw          (playerid, 390.0 + pos_X, 195.0 + pos_Y, !"_");
    PlayerTextDrawLetterSize      (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_USE_BG], 0.0, 1.0);
    PlayerTextDrawTextSize        (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_USE_BG], 0.0, 42.0);
    PlayerTextDrawColor           (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_USE_BG], -1);
    PlayerTextDrawBoxColor        (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_USE_BG], 255);
    PlayerTextDrawUseBox          (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_USE_BG], 1);
    PlayerTextDrawAlignment       (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_USE_BG], 2);

    gInventoryPTDClickSlot[playerid][INVENTORY_PTD_USE] =
    CreatePlayerTextDraw          (playerid, 387.9 + pos_X, 195.7 + pos_Y, gInventoryItem[item_id][iUse]);
    PlayerTextDrawLetterSize      (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_USE], 0.1, 0.9);
    PlayerTextDrawTextSize        (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_USE], 8.0, 41.0);
    PlayerTextDrawAlignment       (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_USE], 2);
    PlayerTextDrawFont            (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_USE], 2);
    PlayerTextDrawSetShadow       (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_USE], 0);
    PlayerTextDrawSetSelectable   (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_USE], true);

    gInventoryPTDClickSlot[playerid][INVENTORY_PTD_INFO_BG] =
    CreatePlayerTextDraw          (playerid, 390.0 + pos_X, 208.0 + pos_Y, !"_");
    PlayerTextDrawLetterSize      (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_INFO_BG], 0.0, 1.0);
    PlayerTextDrawTextSize        (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_INFO_BG], 0.0, 42.0);
    PlayerTextDrawColor           (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_INFO_BG], -1);
    PlayerTextDrawBoxColor        (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_INFO_BG], 255);
    PlayerTextDrawUseBox          (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_INFO_BG], 1);
    PlayerTextDrawAlignment       (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_INFO_BG], 2);

    gInventoryPTDClickSlot[playerid][INVENTORY_PTD_INFO] =
    CreatePlayerTextDraw          (playerid, 388.2 + pos_X, 208.0 + pos_Y, !"Information");
    PlayerTextDrawLetterSize      (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_INFO], 0.1, 0.9);
    PlayerTextDrawTextSize        (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_INFO], 8.0, 41.0);
    PlayerTextDrawAlignment       (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_INFO], 2);
    PlayerTextDrawFont            (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_INFO], 2);
    PlayerTextDrawSetShadow       (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_INFO], 0);
    PlayerTextDrawSetSelectable   (playerid, gInventoryPTDClickSlot[playerid][INVENTORY_PTD_INFO], true);


    for(new clicked_slot; clicked_slot < MAX_INVENTORY_PTD_CLICKSLOT; clicked_slot++) {
        PlayerTextDrawShow(playerid, gInventoryPTDClickSlot[playerid][clicked_slot]);
    }
}
SavePlayerInventory(playerid) {
	//������� ��� ���������� �������� ������
    static const del_query[] = "DELETE FROM `inventory_data` WHERE `owner_id` = %d and `type` = %d;";
	new query_del[sizeof(del_query)+(55)];
	mysql_format(dbHandle, query_del, sizeof(query_del), del_query, player_info[playerid][ID], 1);
	mysql_query(dbHandle, query_del, false);
	
	
	//��������� ������� �������� ������
	for(new slot; slot < INVENTORY_SIZE; slot++) {
		if(pInventoryData[playerid][idItem][slot] > 0)
		{
	 		static const fmt_query[] = "INSERT INTO `inventory_data` (`slot_id`, `owner_id`, `type`, `item_id`, `amount`) VALUES ('%d', '%d', '%d', '%d', '%d')";
			new query[sizeof(fmt_query)+(55)];
			mysql_format(dbHandle, query, sizeof(query), fmt_query, slot, player_info[playerid][ID], 1, pInventoryData[playerid][idItem][slot], pInventoryData[playerid][idAmount][slot]);
			mysql_query(dbHandle, query, false);
		}
    }
	
}
stock UpdatePlayerDataInt(const playerid, const field[], data)
{
	if(!GetPVarInt(playerid, "logged")) return 0;
	static const fmt_query[] = "UPDATE `users` SET `%s` = '%i' WHERE `id` = '%i' LIMIT 1";
	new query[sizeof(fmt_query)+(80)];
	mysql_format(dbHandle, query, sizeof(query), fmt_query, field, data, player_info[playerid][ID]);
	mysql_query(dbHandle, query, false);
	return 1;
}
//==============================================================================================================================
