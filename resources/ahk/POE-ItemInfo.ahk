; Path of Exile ItemInfo
;
; Script is currently maintained by various people and kept up to date by aRTy42 / IGN: Erinyen
; Forum thread: https://www.pathofexile.com/forum/view-thread/1678678
; GitHub: https://github.com/aRTy42/POE-ItemInfo

#SingleInstance force
#NoEnv ; Recommended for performance and compatibility with future AutoHotkey releases.
#Persistent ; Stay open in background
SetWorkingDir, %A_ScriptDir%
SendMode Input ; Recommended for new scripts due to its superior speed and reliability.

;Define window criteria for the regular and steam version, for later use at the very end of the script. This needs to be done early, in the "auto-execute section".
GroupAdd, PoEWindowGrp, Path of Exile ahk_class POEWindowClass ahk_exe PathOfExile.exe
GroupAdd, PoEWindowGrp, Path of Exile ahk_class POEWindowClass ahk_exe PathOfExileSteam.exe
GroupAdd, PoEWindowGrp, Path of Exile ahk_class POEWindowClass ahk_exe PathOfExile_x64.exe
GroupAdd, PoEWindowGrp, Path of Exile ahk_class POEWindowClass ahk_exe PathOfExile_x64Steam.exe
GroupAdd, PoEWindowGrp, Path of Exile ahk_class POEWindowClass ahk_exe PathOfExile_KG.exe
GroupAdd, PoEWindowGrp, Path of Exile ahk_class POEWindowClass ahk_exe PathOfExile_x64_KG.exe

#Include, %A_ScriptDir%\resources\Version.txt
#Include, %A_ScriptDir%\lib\JSON.ahk
#Include, %A_ScriptDir%\lib\EasyIni.ahk
#Include, %A_ScriptDir%\lib\DebugPrintArray.ahk
#Include, %A_ScriptDir%\lib\ConvertKeyToKeyCode.ahk
#Include, %A_ScriptDir%\lib\Class_GdipTooltip.ahk
#Include, %A_ScriptDir%\lib\Class_ColorPicker.ahk
#Include, %A_ScriptDir%\lib\Class_SplashUI.ahk
#Include, %A_ScriptDir%\lib\AdvancedHotkey.ahk
IfNotExist, %A_ScriptDir%\temp
FileCreateDir, %A_ScriptDir%\temp

; Instead of polluting the default namespace with Globals, create our own Globals "namespace".
class Globals {

	Set(name, value) {
		Globals[name] := value
	}

	Get(name, value_default="") {
		result := Globals[name]
		If (result == "") {
			result := value_default
		}
		return result
	}
}

Globals.Set("AHKVersionRequired", AHKVersionRequired)
Globals.Set("ReleaseVersion", ReleaseVersion)
Globals.Set("DataDir", A_ScriptDir . "\data")
Globals.Set("SettingsUIWidth", 963)
Globals.Set("SettingsUIHeight", 665)
Globals.Set("AboutWindowHeight", 340)
Globals.Set("AboutWindowWidth", 435)
Globals.Set("SettingsUITitle", "PoE ItemInfo Settings")
Globals.Set("GithubRepo", "POE-ItemInfo")
Globals.Set("GithubUser", "aRTy42")
Globals.Set("ScriptList", [A_ScriptDir "\POE-ItemInfo"])
Globals.Set("UpdateNoteFileList", [[A_ScriptDir "\resources\updates.txt","ItemInfo"]])
Globals.Set("SettingsScriptList", ["ItemInfo", "Additional Macros", "Lutbot"])
Globals.Set("ScanCodes", GetScanCodes())
Globals.Set("AssignedHotkeys", GetObjPropertyCount(Globals.Get("AssignedHotkeys")) ? Globals.Get("AssignedHotkeys") : {})	; initializes the object only if it hasn't any properties already
argumentProjectName		= %1%
argumentUserDirectory	= %2%
argumentIsDevVersion	= %3%
argumentOverwrittenFiles = %4%
Globals.Set("ProjectName", argumentProjectName)
; make sure not to overwrite these variables if set from another script
global userDirectory		:= userDirectory ? userDirectory : argumentUserDirectory
global isDevVersion			:= isDevVersion  ? isDevVersion  : argumentIsDevVersion
global overwrittenUserFiles	:= overwrittenUserFiles ? overwrittenUserFiles : argumentOverwrittenFiles

global SuspendPOEItemScript = 0

/*
	Import item bases
*/
ItemBaseList := {}
FileRead, JSONFile, %A_ScriptDir%\data\item_bases.json
parsedJSON := JSON.Load(JSONFile)
ItemBaseList.general := parsedJSON.item_bases

FileRead, JSONFile, %A_ScriptDir%\data\item_bases_weapon.json
parsedJSON := JSON.Load(JSONFile)
ItemBaseList.weapons := parsedJSON.item_bases_weapon

FileRead, JSONFile, %A_ScriptDir%\data\item_bases_armour.json
parsedJSON := JSON.Load(JSONFile)
ItemBaseList.armours := parsedJSON.item_bases_armour

Globals.Set("ItemBaseList", ItemBaseList)
Globals.Set("ItemFilterObj", [])
Globals.Set("CurrentItemFilter", "")
/*
*/

; Parse metamorph data
global MetamorphData := { "mapToOrgan" : ReadJSONDataFromFile(A_ScriptDir "\data\metamorph_mapToOrgan.json", "mapToOrgan"), "organToMap" : ReadJSONDataFromFile(A_ScriptDir "\data\metamorph_organToMap.json", "organToMap")}

class UserOptions {	
	ScanUI()
	{
		For key, val in this {
			_get := GuiGet(key, "", Error)
			this[key] := not Error ? _get : this[key]
		}
	}
}

class ItemInfoOptions extends UserOptions {
	; Hotkey to invoke ItemInfo. Default: Ctrl+C.
	ParseItemHotKey := "^c"
	
	; When checked (1) the script only activates while you are ingame (technically while the game window is the frontmost). This is handy for have the script parse
	; textual item representations appearing somewhere Else, like in the forums or text files.
	OnlyActiveIfPOEIsFront := 1
	
	; Put result text on clipboard (overwriting the textual representation the game put there to begin with)
	PutResultsOnClipboard := 0
	
	ShowUpdateNotifications := 1
	UpdateSkipSelection := 0
	UpdateSkipBackup := 0
	
	; Enable/disable the entire AdditionalMacros. The individual settings are in the AdditionalMacros.ini
	;EnableAdditionalMacros := 1
	; Enable/disable the entire MapModWarnings functionality. The individual settings are in the MapModWarnings.ini
	EnableMapModWarnings := 1
	
	; Include a header above the affix overview: TierRange ilvl   Total ilvl  Tier
	ShowHeaderForAffixOverview := 1
	
	; Explain abbreviations and special notation symbols at the end of the tooltip when they are used
	ShowExplanationForUsedNotation := 1
	
	; If the mirrored affix text is longer than the field length the affix line will be cut off and
	;   this text will be appended at the end to indicate that the line was truncated.
	; Usually this is set to the ASCII or Unicode value of the three dot ellipsis (alt code: 0133).
	; Note that the correct display of text characters outside the ASCII standard depend on the file encoding and
	;   the AHK version used. For best results, save this file as ANSI encoding which can be read and
	;   displayed correctly by either ANSI based AutoHotkey or Unicode based AutoHotkey.
	; Example: Assume the affix line to be mirrored is '50% increased Spell Damage'.
	;   The field width is hardcoded (assume 20), this text would be shown as '50% increased Spell…'
	AffixTextEllipsis := "…"
	
	; Separator for affix overview columns. This is put in at three places. Example with \\ instead of spaces:
	; 50% increased Spell…\\50-59 (46)\\75-79 (84)\\T4 P
	; Default: 2 spaces
	AffixColumnSeparator := "  "
	
	; Select separator for double ranges from 'added damage' mods: a-b to c-d is displayed as a-b|c-d
	DoubleRangeSeparator := "|"
	
	; Shorten double ranges: a-b to c-d becomes a-d
	UseCompactDoubleRanges := 0
	
	; Only use compact double ranges for the second range column in the affix overview (with the header 'total')
	OnlyCompactForTotalColumn := 0
	
	; Separator for a multi tier roll range with uncertainty, such as:
	;   83% increased Light…   73-85…83-95   102-109 (84)  T1-4 P + T1-6 S
	;   	                 There--^
	MultiTierRangeSeparator := "…"
	
	; Font size for the tooltip.
	FontSize := 9
	
	; Hide tooltip when the mouse cursor moved x pixels away from the initial position.
	; Effectively permanent tooltip when using a value larger than the monitor diameter.
	MouseMoveThreshold := 40
	
	; Set this to 1 if you want to have the tooltip disappear after the time frame set below.
	; Otherwise you will have to move the mouse by x pixels for the tip to disappear.
	UseTooltipTimeout := 0

	;How many seconds to wait before removing tooltip.
	ToolTipTimeoutSeconds := 15
	
	; Displays the tooltip in virtual screen space at fixed coordinates.
	; Virtual screen space means the complete desktop frame, including any secondary monitors.
	DisplayToolTipAtFixedCoords := 0

	; Coordinates relative to top left corner, increasing by going down and to the right.
	; Only used if DisplayToolTipAtFixedCoords is 1.
	ScreenOffsetX := 0
	ScreenOffsetY := 0
	
	; Set this to 1 to enable GDI+ rendering
	UseGDI := 0

	; Format: RRGGBB
	GDIWindowColor			:= "000000"
	GDIBorderColor			:= "654025"
	GDITextColor			:= "FEFEFE"
	GDIWindowOpacity		:= 90
	GDIBorderOpacity		:= 90
	GDITextOpacity			:= 100
	GDIRenderingFix		:= 1
	GDIConditionalColors	:= 0
}
Opts := new ItemInfoOptions()

class Fonts {
	__New(FontSizeFixed, FontSizeUI = 9)
	{
		this.FontSizeFixed	:= FontSizeFixed
		this.FontSizeUI	:= FontSizeUI
		this.FixedFont		:= this.CreateFixedFont(this.FontSizeFixed)
		this.UIFont		:= this.CreateUIFont(this.FontSizeUI)
	}

	CreateFixedFont(FontSize_, Options = "")
	{
		; Q5 = Windows XP and later: If set, text is rendered (when possible) using ClearType antialiasing method.
		Options .= " q5 "
		If (!(FontSize_ == ""))
		{
			Options .= "s" FontSize_
		}
		Gui Font, %Options%, Courier New
		Gui Font, %Options%, Consolas
		Gui Add, Text, HwndHidden h0 w0 x0 y0,
		SendMessage, 0x31,,,, ahk_id %Hidden%
		return ErrorLevel
	}

	CreateUIFont(FontSize_, Options = "")
	{
		; Q5 = Windows XP and later: If set, text is rendered (when possible) using ClearType antialiasing method.
		Options .= " q5 "
		If (!(FontSize_ == ""))
		{
			Options .= "s" FontSize_
		}		
		Gui, SettingsUI:Font, %Options%, Arial
		Gui, SettingsUI:Font, %Options%, Tahoma
		Gui, SettingsUI: Font, %Options%, Segoe UI
		Gui, SettingsUI: Font, %Options%, Verdana
		Gui, SettingsUI: Add, Text, HwndHidden h0 w0 x0 y0,
		SendMessage, 0x31,,,, ahk_id %Hidden%
		return ErrorLevel
	}

	Set(NewFont)
	{
		AhkExe := GetAhkExeFilename()
		SendMessage, 0x30, NewFont, 1,, ahk_class tooltips_class32 ahk_exe %AhkExe%
		; Development versions of AHK
		SendMessage, 0x30, NewFont, 1,, ahk_class tooltips_class32 ahk_exe AutoHotkeyA32.exe
		SendMessage, 0x30, NewFont, 1,, ahk_class tooltips_class32 ahk_exe AutoHotkeyU32.exe
		SendMessage, 0x30, NewFont, 1,, ahk_class tooltips_class32 ahk_exe AutoHotkeyU64.exe
	}

	SetFixedFont(FontSize_=-1, Options = "")
	{		
		If (FontSize_ != -1) {
			FontSize_ := this.FontSizeFixed
		} Else {
			this.FontSizeFixed := FontSize_
		}
		FixedFont := this.CreateFixedFont(FontSize_, Options)
		
		If (FixedFont) {		
			this.Set(this.FixedFont)
			this.FontSizeFixed := FixedFont
		}		
	}

	SetUIFont(FontSize_=-1, Options = "")
	{		
		If (FontSize_ == -1) {
			FontSize_ := this.FontSizeUI
		} Else {
			this.FontSizeUI := FontSize_
		}		
		UIFont := this.CreateUIFont(FontSize_, Options)
		
		If (UIFont and (this.UIFont != UIFont)) {
			this.Set(this.UIFont)
			this.UIFont := UIFont
		}		
	}

	GetFixedFont()
	{
		return this.FixedFont
	}

	GetUIFont()
	{
		return this.UIFont
	}
}

class ItemData_ {
	Init()
	{
		This.Links	:= ""
		This.Sockets		:= ""
		This.Stats	:= ""
		This.NamePlate		:= ""
		This.Affixes		:= ""
		This.AffixTextLines		:= []
		This.UncertainAffixes	:= {}
		This.UncAffTmpAffixLines := []
		This.LastAffixLineNumber := 0
		This.HasMultipleCrafted	:= 0
		This.SpecialCaseNotation := ""
		This.FullText		:= ""
		This.IndexAffixes 	:= -1
		This.IndexLast		:= -1
		This.PartsLast		:= ""
		This.Rarity	:= ""
		This.Parts	:= []
	}
}
Global ItemData := new ItemData_
ItemData.Init()

class Item_ {
	; Initialize all the Item object attributes to default values
	Init()
	{
		This.Name			:= ""
		This.BaseName		:= ""
		This.Quality		:= ""
		This.QualityType	:= ""
		This.BaseLevel		:= ""
		This.RarityLevel	:= ""
		This.BaseType		:= ""
		This.GripType		:= ""
		This.Level		:= ""
		This.Experience	:= ""
		This.ExperienceFlat	:= ""
		This.MapLevel		:= ""
		This.MapTier		:= ""
		This.MaxSockets	:= ""
		This.MaxSocketsNormal := ""
		This.Sockets		:= ""
		This.AbyssalSockets	:= ""
		This.SocketGroups	:= []
		This.SocketString	:= ""
		This.Links		:= ""
		This.SubType		:= ""		
		This.DifficultyRestriction := ""
		This.Implicit		:= []
		This.Enchantment	:= []
		This.Charges		:= []
		This.AreaMonsterLevelReq := []
		This.BeastData 	:= {}
		This.GemColor		:= ""
		This.veiledPrefixCount	:= ""
		This.veiledSuffixCount	:= ""
		This.fracturedModsCount	:= ""
		
		This.HasImplicit	:= False
		This.HasEnchantment	:= False
		This.HasEffect		:= False
		This.IsWeapon		:= False
		This.IsArmour 		:= False
		This.IsHybridBase	:= False
		This.IsQuiver 		:= False
		This.IsFlask 		:= False
		This.IsGem		:= False
		This.IsCurrency 	:= False
		This.IsUnidentified := False
		This.IsBelt 		:= False
		This.IsRing 		:= False
		This.IsUnsetRing 	:= False
		This.IsBow		:= False
		This.IsAmulet 		:= False
		This.IsSingleSocket := False
		This.IsFourSocket 	:= False
		This.IsThreeSocket 	:= False
		This.IsMap		:= False
		This.IsTalisman 	:= False
		This.IsJewel 		:= False
		This.IsLeaguestone	:= False
		This.IsScarab		:= False
		This.IsDivinationCard := False
		This.IsProphecy	:= False
		This.IsUnique 		:= False
		This.IsRare		:= False
		This.IsCorrupted	:= False
		This.IsMirrored	:= False
		This.IsMapFragment	:= False
		This.IsEssence		:= False
		This.IsRelic		:= False
		This.IsMetamorphSample := False
		
		This.IsElderBase	:= False
		This.IsShaperBase	:= False
		This.IsCrusaderBase := False
		This.IsHunterBase	:= False
		This.IsWarlordBase	:= False
		This.IsRedeemerBase	:= False
		Item.HasInfluence	:= []
		
		This.IsSynthesisedBase:= False
		This.IsFracturedBase:= False
		
		This.IsAbyssJewel	:= False
		This.IsClusterJewel	:= False
		This.IsBeast		:= False
		This.IsHideoutObject:= False
		This.IsFossil		:= False		
	}
}
Global Item := new Item_
Item.Init()

class AffixTotals_ {

	NumPrefixes := 0
	NumSuffixes := 0
	NumPrefixesMax := 0
	NumSuffixesMax := 0
	NumTotal := 0
	NumTotalMax := 0

	Reset()
	{
		this.NumPrefixes := 0
		this.NumSuffixes := 0
		this.NumPrefixesMax := 0
		this.NumSuffixesMax := 0
		this.NumTotal := 0
		this.NumTotalMax := 0
	}
	
	FormatAll()
	{
		this.NumPrefixes := NumFormatPointFiveOrInt(this.NumPrefixes)
		this.NumSuffixes := NumFormatPointFiveOrInt(this.NumSuffixes)
		this.NumPrefixesMax := NumFormatPointFiveOrInt(this.NumPrefixesMax)
		this.NumSuffixesMax := NumFormatPointFiveOrInt(this.NumSuffixesMax)
		this.NumTotal := NumFormatPointFiveOrInt(this.NumTotal)
		this.NumTotalMax := NumFormatPointFiveOrInt(this.NumTotalMax)
	}
}
AffixTotals := new AffixTotals_()

class AffixLines_ {

	__New()
	{
		this.Length := 0
	}

	; Sets fields to empty string
	Clear(Index)
	{
		this[Index] := ""
	}

	ClearAll()
	{
		Loop, % this.MaxIndex()
		{
			this.Clear(A_Index)
		}
	}

	; Actually removes fields
	Reset()
	{
		Loop, % this.MaxIndex()
		{
			this.Remove(this.MaxIndex())
		}
		this.Length := 0
	}

	Set(Index, Contents)
	{
		this[Index] := Contents
		this.Length := this.MaxIndex()
	}
}
AffixLines := new AffixLines_()

IfNotExist, %userDirectory%\config.ini
{
	CopyDefaultConfig()
}

; Windows system tray icon
; possible values: poe.ico, poe-bw.ico, poe-web.ico, info.ico
; set before creating the settings UI so it gets used for the settings dialog as well
Menu, Tray, Icon, %A_ScriptDir%\resources\images\poe-bw.ico

ReadConfig()
Sleep, 100

; Use some variables to skip the update check or enable/disable update check feedback.
; The first call on script start shouldn't have any feedback and including ItemInfo in other scripts should call the update once from that other script.
; Under no circumstance set the variable "SkipItemInfoUpdateCall" in this script.
; This code block should only be called when ItemInfo runs by itself, not when it's included in other scripts like PoE-TradeMacro.
; "SkipItemInfoUpdateCall" should be set outside by other scripts.
global firstUpdateCheck := true
If (!SkipItemInfoUpdateCall) {
	global SplashUI := new SplashUI("on", "PoE-ItemInfo", "Initializing PoE-ItemInfo...", "", ReleaseVersion, A_ScriptDir "\resources\images\greydot.png")
	GoSub, CheckForUpdates
}
firstUpdateCheck := false

CreateSettingsUI()
If (StrLen(overwrittenUserFiles)) {
	ShowChangedUserFiles()
}
GoSub, AM_AssignHotkeys
SplashUI.SetSubMessage("Fetching currency data from poe.ninja for all leagues...")
GoSub, FetchCurrencyData
GoSub, InitGDITooltip


/*
	Item data translation, won't be used for now.
	Todo: remove test/debug code
*/
If (false) {
	global currentLocale := ""
	_Debug := true
	SplashUI.SetSubMessage("Downloading language files...")
	global translationData := PoEScripts_DownloadLanguageFiles(currentLocale, false, "PoE-ItemInfo", "Updating and parsing language files...", _Debug)
}

Menu, TextFiles, Add, Additional Macros Settings, EditAdditionalMacrosSettings
Menu, TextFiles, Add, Map Mod Warnings, EditMapModWarningsConfig
Menu, TextFiles, Add, Custom Macros Example, EditCustomMacrosExample
Menu, PreviewTextFiles, Add, Additional Macros, PreviewAdditionalMacros

; Menu tooltip
RelVer := Globals.Get("ReleaseVersion")
Menu, Tray, Tip, Path of Exile Item Info %RelVer%

Menu, Tray, NoStandard
Menu, Tray, Add, Reload Script (Use only this), ReloadScript
Menu, Tray, Add ; Separator
Menu, Tray, Add, About..., MenuTray_About
/*
	;Item data Translation, won't be used for now.
	Menu, Tray, Add, Translate Item, ShowTranslationUI
*/
Menu, Tray, Add, Show all assigned Hotkeys, ShowAssignedHotkeys
Menu, Tray, Add, % Globals.Get("SettingsUITitle", "PoE ItemInfo Settings"), ShowSettingsUI
Menu, Tray, Add, Check for updates, CheckForUpdates
Menu, Tray, Add, Show Update Notes, ShowUpdateNotes
Menu, Tray, Add ; Separator
Menu, Tray, Add, Edit Files, :TextFiles
Menu, Tray, Add, Preview Files, :PreviewTextFiles
Menu, Tray, Add, Open User Folder, EditOpenUserSettings
Menu, Tray, Add ; Separator
Menu, Tray, Standard
Menu, Tray, Default, % Globals.Get("SettingsUITitle", "PoE ItemInfo Settings")


#Include %A_ScriptDir%\data\MapList.txt
#Include %A_ScriptDir%\data\DivinationCardList.txt
#Include %A_ScriptDir%\data\GemQualityList.txt

Fonts := new Fonts(Opts.FontSize, 9)

If (Opts.Lutbot_CheckScript) {	
	SetTimer, StartLutbot, 2000
}

CheckForGameHotkeyConflicts()
SplashUI.DestroyUI() ; init finished

; ----------------------------------------------------------- Functions and Labels ----------------------------------------------------------------

GetAhkExeFilename(Default_="AutoHotkey.exe")
{
	AhkExeFilename := Default_
	If (A_AhkPath)
	{
		StringSplit, AhkPathParts, A_AhkPath, \
		Loop, % AhkPathParts0
		{
			IfInString, AhkPathParts%A_Index%, .exe
			{
				AhkExeFilename := AhkPathParts%A_Index%
				Break
			}
		}
	}
	return AhkExeFilename
}

OpenCreateDataTextFile(Filename)
{
	Filepath := A_ScriptDir . "\data\" . Filename
	IfExist, % Filepath
	{
		Run, % Filepath
	}
	Else
	{
		File := FileOpen(Filepath, "w")
		IF !IsObject(File)
		{
			MsgBox, 16, Error, File not found and can't write new file.
			return
		}
		File.Close()
		Run, % Filepath
	}
	return

}

OpenTextFileReadOnly(FilePath)
{
	ExecuteString := FilePath
	if (FileExist(FilePath)) {
		openWith := AssociatedProgram("txt")
		if (openWith) {
			if (InStr(openWith, "system32\NOTEPAD.exe")) {
				if (InStr(openWith, "SystemRoot")) {
					; because `Run` cannot expand environment variable for some reason
					EnvGet, SystemRoot, SystemRoot
					StringReplace, openWith, openWith, `%SystemRoot`%, %SystemRoot%
				}
			}
			if (InStr(openWith, " %1")) {
				; trim `%1`
				StringTrimRight, openWith, openWith, 2
			}
			ExecuteString := openWith " " FilePath
		}
		FileSetAttrib, +R, %FilePath%
		RunWait, %ExecuteString%
		FileSetAttrib, -R, %FilePath%
	}
	else {
		MsgBox, 16, Error, File not found.
	}
	return
}

OpenUserDirFile(Filename)
{
	Filepath := userDirectory . "\" . Filename
	IfExist, % Filepath
	{
		Run, % Filepath
	}
	Else
	{
		MsgBox, 16, Error, File not found.
		return
	}
	return

}

OpenUserSettingsFolder(ProjectName, Dir = "")
{
	If (!StrLen(Dir)) {
		Dir := userDirectory
	}

	If (!InStr(FileExist(Dir), "D")) {
		FileCreateDir, %Dir%
	}
	Run, Explorer %Dir%
	return
}

; Function that checks item type name against entries
; from ItemList.txt to get the item's base level
; Added by kongyuyu, changed by hazydoc, vdorie
CheckBaseLevel(ItemBaseName)
{
	ItemListArray = 0
	Loop, Read, %A_ScriptDir%\data\ItemList.txt
	{
		; This loop retrieves each line from the file, one at a time.
		ItemListArray += 1  ; Keep track of how many items are in the array.
		StringSplit, NameLevel, A_LoopReadLine, |,
		Array%ItemListArray%1 := NameLevel1  ; Store this line in the next array element.
		Array%ItemListArray%2 := NameLevel2
	}

	ResultLength := 0
	ResultIndex := 0

	Loop %ItemListArray% {
		element := Array%A_Index%1

		IF (InStr(ItemBaseName, element) != 0 && StrLen(element) > ResultLength)
		{
			ResultIndex := A_Index
			ResultLength := StrLen(element)
		}
	}

	BaseLevel := ""
	IF (ResultIndex > 0) {
		BaseLevel := Array%ResultIndex%2
	}
	return BaseLevel
}

CheckRarityLevel(RarityString)
{
	IfInString, RarityString, Normal
		return 1
	IfInString, RarityString, Magic
		return 2
	IfInString, RarityString, Rare
		return 3
	IfInString, RarityString, Unique
		return 4
	return 0 ; unknown rarity. shouldn't happen!
}

ParseItemType(ItemDataStats, ItemDataNamePlate, ByRef BaseType, ByRef SubType, ByRef GripType, RarityLevel, IsMetamorphSample)
{
	; Grip type only matters for weapons at this point. For all others it will be 'None'.
	; Note that shields are armour and not weapons, they are not 1H.
	GripType = None

	; Check stats section first as weapons usually have their sub type as first line
	Loop, Parse, ItemDataStats, `n, `r
	{
		If (RegExMatch(A_LoopField, "i)\b((One Handed|Two Handed) (Axe|Sword|Mace)|Sceptre|Warstaff|Staff|Rune Dagger|Dagger|Claw|Bow|Wand|Fishing Rod)\b", match))
		{
			BaseType	:= "Weapon"
			If (RegExMatch(match1, "i)(Sword|Axe|Mace)", subMatch)) {
				SubType	:= subMatch1
			} Else {
				SubType	:= match1
			}
			GripType	:= (RegExMatch(match1, "i)\b(Two Handed|Warstaff|Staff|Bow)\b")) ? "2H" : "1H"
			return
		}
	}

	; Check name plate section
	Loop, Parse, ItemDataNamePlate, `n, `r
	{		
		; Get third line in case of rare or unique item and retrieve the base item name
		LoopField := RegExReplace(A_LoopField, "<<.*>>", "")
		If (RarityLevel > 2)
		{
			Loop, Parse, ItemDataNamePlate, `n, `r
			{
				If (A_Index = 3) {
				   LoopField := Trim(A_LoopField) ? Trim(A_LoopField) : LoopField
				}
			}
		}

		; Belts, Amulets, Rings, Quivers, Flasks
		If (RegExMatch(LoopField, "i)\b(Belt|Stygian Vise|Rustic Sash)\b"))
		{
			BaseType = Item
			SubType = Belt
			return
		}		
		If (RegExMatch(LoopField, "i)\b(Amulet|Talisman)\b")) and not (RegExMatch(LoopField, "i)\bLeaguestone\b"))
		{
			BaseType = Item
			SubType = Amulet
			return
		}
		If (RegExMatch(LoopField, "\b(Ring|Quiver|Flask)\b", match))
		{
			BaseType := "Item"
			SubType := match1
			return
		}
		If (RegExMatch(LoopField, "i)\b(Map)\b"))
		{
			Global mapMatchList
			BaseType = Map
			Loop % mapMatchList.MaxIndex()
			{
				mapMatch := mapMatchList[A_Index]
				IfInString, LoopField, %mapMatch%
				{
					If (RegExMatch(LoopField, "\b(Shaped|Blighted|Elder) " . mapMatch, subTypeMatch)) {
						SubType = %subTypeMatch1% %mapMatch%
					}
					Else {
						SubType = %mapMatch%
					}
					return
				}
			}
			
			SubType = Unknown%A_Space%Map
			return
		}
		
		; Jewels
		If (RegExMatch(LoopField, "i)(Cobalt|Crimson|Viridian|Prismatic) Jewel", match)) {
			BaseType = Jewel
			SubType := match1 " Jewel"
			return
		}
		; Abyss Jewels
		If (RegExMatch(LoopField, "i)(Murderous|Hypnotic|Searching|Ghastly) Eye Jewel", match)) {
			BaseType = Jewel
			SubType := match1 " Eye Jewel"
			return
		}
		; Jewels
		If (RegExMatch(LoopField, "i)(Small|Medium|Large) Cluster Jewel", match)) {
			BaseType = Jewel
			SubType := match1 " Cluster Jewel"
			return
		}
		
		; Metamorph samples
		If (IsMetamorphSample and RegExMatch(Loopfield, "i)(Eye|Liver|Heart|Lung|Brain)$", match)) {
			BaseType := "Metamorph"
			SubType := "Metamorph " match1
			return
		}
		
		; Leaguestones and Scarabs
		If (RegExMatch(Loopfield, "i)\b(Leaguestone|Scarab)\b"))
		{
			RegexMatch(LoopField, "i)(.*)(Leaguestone|Scarab)", typeMatch)
			RegexMatch(Trim(typeMatch1), "i)\b(\w+)\W*$", match) ; match last word
			BaseType := Trim(typeMatch2)
			SubType := Trim(match1) " " Trim(typeMatch2)
			return
		}


		; Matching armour types with regular expressions for compact code

		; Shields
		If (RegExMatch(LoopField, "\b(Buckler|Bundle|Shield)\b"))
		{
			BaseType = Armour
			SubType = Shield
			return
		}

		; Gloves
		If (RegExMatch(LoopField, "\b(Gauntlets|Gloves|Mitts)\b"))
		{
			BaseType = Armour
			SubType = Gloves
			return
		}

		; Boots
		If (RegExMatch(LoopField, "\b(Boots|Greaves|Slippers)\b"))
		{
			BaseType = Armour
			SubType = Boots
			return
		}

		; Helmets
		If (RegExMatch(LoopField, "\b(Bascinet|Burgonet|Cage|Circlet|Crown|Hood|Helm|Helmet|Mask|Sallet|Tricorne)\b"))
		{
			BaseType = Armour
			SubType = Helmet
			return
		}

		; Note: Body armours can have "Pelt" in their randomly assigned name,
		;    explicitly matching the three pelt base items to be safe.

		If (RegExMatch(LoopField, "\b(Iron Hat|Leather Cap|Rusted Coif|Wolf Pelt|Ursine Pelt|Lion Pelt)\b"))
		{
			BaseType = Armour
			SubType = Helmet
			return
		}

		; BodyArmour
		; Note: Not using "$" means "Leather" could match "Leather Belt", therefore we first check that the item is not a belt. (belts are currently checked earlier so this is redundant, but the order might change)
		If (!RegExMatch(LoopField, "\b(Belt)\b"))
		{
			If (RegExMatch(LoopField, "\b(Armour|Brigandine|Chainmail|Coat|Doublet|Garb|Hauberk|Jacket|Lamellar|Leather|Plate|Raiment|Regalia|Ringmail|Robe|Tunic|Vest|Vestment)\b"))
			{
				BaseType = Armour
				SubType = BodyArmour
				return
			}
		}

		If (RegExMatch(LoopField, "\b(Chestplate|Full Dragonscale|Full Wyrmscale|Necromancer Silks|Shabby Jerkin|Silken Wrap)\b"))
		{
			BaseType = Armour
			SubType = BodyArmour
			return
		}
	}
}

GetClipboardContents(DropNewlines=False)
{
	Result =
	Note =
	If Not DropNewlines
	{
		Loop, Parse, Clipboard, `n, `r
		{
			IfInString, A_LoopField, note:
			
			; new code added by Bahnzo - The ability to add prices to items causes issues. 
			; Building the code sent from the clipboard differently, and ommiting the line with "Note:" on it partially fixes this.
			; We also have to omit the \newline \return that gets added at the end.
			; Not adding the note to ClipboardContents but its own variable should solve all problems.
			{
				Note := A_LoopField
				; We drop the "note:", but the "--------" has already been added and we don't want it, so we delete the last 8 chars.
				Result := SubStr(Result, 1, -8)
				break                       
			}
			IfInString, A_LoopField, Map drop
			{
				; We drop the "Map drop", but the "--------" has already been added and we don't want it, so we delete the last 8 chars.
				Result := SubStr(Result, 1, -8)
				break
			}
			If A_Index = 1                  ; so we start with just adding the first line w/o either a `n or `r
			{
				Result := Result . A_LoopField
			}
			Else
			{
				Result := Result . "`r`n" . A_LoopField  ; and then adding those before adding lines. This makes sure there are no trailing `n or `r.
				;Result := Result . A_LoopField . "`r`n"  ; the original line, left in for clarity.
			}
		}
	}
	Else
	{
		Loop, Parse, Clipboard, `n, `r
		{
			IfInString, A_LoopField, note:
			{
				Note := A_LoopField
				Result := SubStr(Result, 1, -8)
				break
			}
			Result := Result . A_LoopField
		}
	}

	RegExMatch(Trim(Note), "i)^Note: (.*)", match)
	Globals.Set("ItemNote", match1)

	return Result
}

SetClipboardContents(String)
{
	Clipboard := String
	; Temp, I used this for debugging and considering adding it to UserOptions
	; append the result for easier comparison and debugging
	; Clipboard = %Clipboard%`n*******************************************`n`n%String%
}

/* See ArrayFromDatafile()
*/
ArrayFromDataobject(Obj)
{
	If (Obj = False)
	{
		return False
	}

	ModDataArray := []
	
	For Idx, Line in Obj
	{
		min		:= ""
		max		:= ""
		minLo	:= ""
		minHi	:= ""
		maxLo	:= ""
		maxHi	:= ""
		
		StringSplit, AffixDataParts, Line, |,
		RangeItemLevel := AffixDataParts1
		RangeValues := AffixDataParts2
		
		IfInString, RangeValues, `,
		{
			; Example lines from txt file database for double range lookups:
			;  3|1,14-15
			; 13|1-3,35-37
			StringSplit, DoubleRangeParts, RangeValues, `,
			LB := DoubleRangeParts1
			UB := DoubleRangeParts2
			
			IfInString, LB, -
			{
				; Lower bound is a range: #-#
				SplitRange(LB, minLo, minHi)
			}
			Else
			{
				; Lower bound is a single value. Gets assigned to both min.
				minLo := LB
				minHi := LB
			}
			IfInString, UB, -
			{
				; Upper bound is a range: #-#
				SplitRange(UB, maxLo, maxHi)
			}
			Else
			{
				; Upper bound is a single value. Gets assigned to both min.
				maxLo := UB
				maxHi := UB
			}
		}
		Else
		{
			; The whole bracket in RangeValues is in the #-# format (it is no double range). This is the case for most mods.
			SplitRange(RangeValues, min, max)
		}
		
		element := {"ilvl":RangeItemLevel, "values":RangeValues, "min":min, "max":max, "minLo":minLo, "minHi":minHi, "maxLo":maxLo, "maxHi":maxHi}
		ModDataArray.InsertAt(1, element)
	}
	
	return ModDataArray
}

/*
Puts the data from a file into an array in inverted order, so that tier1 is at array position 1.
Each array element is an object with 8 keys:
	
	Always assinged:
		ilvl: Itemlevel of the bracket/tier
		values: The complete value line from the file
	
	In case of the simple range "1-2" format, otherwise empty string:
		min: min value (1)
		max: min value (2)
	
	In case of the double range "1-2,3-4" format, otherwise empty string:
		minLo: lower min value (1)
		minHi: upper min value (2)
		maxLo: lower max value (3)
		maxHi: upper max value (4)

*/
ArrayFromDatafile(Filename, AffixMode="Native")
{
	If (Filename = False)
	{
		return False
	}
	
	ReadType := "Native"
	
	ModDataArray_Native  := []
	ModDataArray_Essence := []
	
	Loop, Read, %A_ScriptDir%\%Filename%
	{
		min		:= ""
		max		:= ""
		minLo	:= ""
		minHi	:= ""
		maxLo	:= ""
		maxHi	:= ""
		
		If (A_LoopReadLine ~= "--Essence--")
		{
			ReadType := "Essence"
			Continue
		}
		
		StringSplit, AffixDataParts, A_LoopReadLine, |,
		RangeItemLevel := AffixDataParts1
		RangeValues := AffixDataParts2
		
		IfInString, RangeValues, `,
		{
			; Example lines from txt file database for double range lookups:
			;  3|1,14-15
			; 13|1-3,35-37
			StringSplit, DoubleRangeParts, RangeValues, `,
			LB := DoubleRangeParts1
			UB := DoubleRangeParts2
			
			IfInString, LB, -
			{
				; Lower bound is a range: #-#
				SplitRange(LB, minLo, minHi)
			}
			Else
			{
				; Lower bound is a single value. Gets assigned to both min.
				minLo := LB
				minHi := LB
			}
			IfInString, UB, -
			{
				; Upper bound is a range: #-#
				SplitRange(UB, maxLo, maxHi)
			}
			Else
			{
				; Upper bound is a single value. Gets assigned to both min.
				maxLo := UB
				maxHi := UB
			}
		}
		Else
		{
			; The whole bracket in RangeValues is in the #-# format (it is no double range). This is the case for most mods.
			SplitRange(RangeValues, min, max)
		}
		
		element := {"ilvl":RangeItemLevel, "values":RangeValues, "min":min, "max":max, "minLo":minLo, "minHi":minHi, "maxLo":maxLo, "maxHi":maxHi}
		ModDataArray_%ReadType%.InsertAt(1, element)
	}
	
	If (AffixMode = "essence" or AffixMode = "ess")
	{
		return ModDataArray_Essence
	}
	Else{
		return ModDataArray_Native
	}
}

/*
Parameters:
1) Finds all matching tiers for Value (either number or value range).
2) Uses the ModDataArray provided by ArrayFromDatafile().
3) ItemLevel optional but usually needed for the function to make sense. Tiers that require a higher itemlevel than provided are skipped.

Returns an object with 3 keys:
	tier: The matching tier found for the provided "Value". Empty string if no match or more than one matching tier is found.
	
	If more than one matching tier is found, otherwise empty strings:
	Top: The "best"  tier that matches, so the numerically lowest (!) tier.
	Btm: The "worst" tier that matches, so the numerically highest (!) tier.
*/
LookupTierByValue(Value, ModDataArray, ItemLevel=100)
{
	If (ModDataArray = False)
	{
		return False
	}
	
	tier	:= ""
	tierTop	:= ""
	tierBtm	:= ""
	
	Loop
	{
		If ( A_Index > ModDataArray.Length() )
		{
			Break
		}
		
		CheckTier := A_Index
		
		If ( ModDataArray[CheckTier].ilvl > ItemLevel)
		{
			; Skip line if the ItemLevel is too low for the tier
			Continue
		}
		Else
		{
			IfInString, Value, -
			{
				; Value is a range (due to a double range mod)
				SplitRange(Value, ValueLo, ValueHi)
				
				If ( (ModDataArray[CheckTier].minLo <= ValueLo) and (ValueLo <= ModDataArray[CheckTier].minHi) and (ModDataArray[CheckTier].maxLo <= ValueHi) and (ValueHi <= ModDataArray[CheckTier].maxHi) )
				{
					; Both values fit in the brackets
					If (tier="")
					{
						; tier not assigned yet, so fill it. This is put into tierTop later if more than one tier fits.
						tier := CheckTier
					}
					Else
					{
						; otherwise fill tierBtm (and have it potentially overwritten if an even lower match is found later).
						tierBtm := CheckTier
					}
				}
				Continue
			}
			Else
			{
				; Value is a number, not a range
				If ( (ModDataArray[CheckTier].min <= Value) and (Value <= ModDataArray[CheckTier].max) )
				{
					; Value fits in the bracket
					If (tier="")
					{
						; tier not assigned yet, so fill it. This is put into tierTop later if more than one tier fits.
						tier := CheckTier
					}
					Else
					{
						; otherwise fill tierBtm (and have it potentially overwritten if an even lower match is found later).
						tierBtm := CheckTier
					}
				}
				Continue
			}
		}
	}
	If (tierBtm)
	{
		; tierBtm was actually used, so more than one tier fits. Thus putting tier into tierTop instead.
		tierTop := tier
		tier := ""
	}
	
	return {"Tier":tier,"Top":tierTop,"Btm":tierBtm}
}

LookupImplicitValue(ItemBaseName)
{
	Global Opts
	FileRead, FileImplicits, data\Implicits.json
	Implicits := JSON.Load(FileImplicits)
	ImplicitText := Implicits[ItemBaseName]["Implicit"]
	
	IfInString, ImplicitText, `,
	{
		StringSplit, Part, ImplicitText, `,
		return [GetActualValue(Part1), GetActualValue(Part2)]
	}
	Else If (RegExMatch(ImplicitText, "Adds \((\d+\-\d+)\) to \((\d+\-\d+)\)", match))
	{
		return [match1  Opts.DoubleRangeSeparator  match2]
	}
	Else If (RegExMatch(ImplicitText, "Adds (\d+\) to (\d+\)", match))
	{
		return [match1  Opts.DoubleRangeSeparator  match2]
	}
	Else If (RegExMatch(ImplicitText, "\((.*?)\)", match))
	{
		return [match1]
	}
	Else{
		return [GetActualValue(ImplicitText)]
	}
}

LookupAffixData(DataSource, ItemLevel, Value, ByRef Tier="")
{
	If (IsObject(DataSource)){
		ModDataArray := ArrayFromDataobject(DataSource)
	}
	Else{
		ModDataArray := ArrayFromDatafile(DataSource)
	}
	
	ModTiers := LookupTierByValue(Value, ModDataArray, ItemLevel)
	
	If (ModTiers.Tier)
	{
		Tier := ModTiers.Tier
	}
	Else If (ModTiers.Top and ModTiers.Btm)
	{
		Tier := [ModTiers.Top, ModTiers.Btm]
	}
	Else If (Value contains "-")
	{
		SplitRange(Value, Lo, Hi)
		If (Lo > ModDataArray[1].maxLo and Hi > ModDataArray[1].maxHi)
		{
			Tier := 0
		}
		Else
		{
			Tier := "?"
		}
	}
	Else
	{
		If (Value > ModDataArray[1].max)
		{
			Tier := 0
		}
		Else
		{
			Tier := "?"
		}
	}
	
	return FormatValueRangesAndIlvl(ModDataArray, Tier)
}

ParseRarity(ItemData_NamePlate)
{
	Loop, Parse, ItemData_NamePlate, `n, `r
	{
		IfInString, A_LoopField, Rarity:
		{
			StringReplace, RarityReplace, A_LoopField, :%A_Space%, :, All
			StringSplit, RarityParts, RarityReplace, :
			Break
		}
	}

	return RarityParts%RarityParts%2
}

Assert(expr, msg)
{
	If (Not (expr))
	{
		MsgBox, 4112, Assertion Failure, %msg%
		ExitApp
	}
}

GetItemDataChunk(ItemDataText, MatchWord)
{
	Assert(StrLen(MatchWord) > 0, "GetItemDataChunk: parameter 'MatchWord' can't be empty")

	StringReplace, TempResult, ItemDataText, --------`r`n, ``, All
	StringSplit, ItemDataChunks, TempResult, ``
	Loop, %ItemDataChunks0%
	{
		IfInString, ItemDataChunks%A_Index%, %MatchWord%
		{
			return ItemDataChunks%A_Index%
		}
	}
}

ParseQuality(ItemDataNamePlate, ByRef QualityType)
{
	ItemQuality := 0
	Loop, Parse, ItemDataNamePlate, `n, `r
	{
		If (StrLen(A_LoopField) = 0)
		{
			Break
		}
		IfInString, A_LoopField, Unidentified
		{
			Break
		}
		RegExMatch(A_LoopField, "Quality(?: \((.*?)\))?: \+(\d+)% .*", qmatch)
		If (qmatch)		{			
			ItemQuality := qmatch2
			QualityType := qmatch1
			Break
		}
	}
	return ItemQuality
}

ParseAugmentations(ItemDataChunk, ByRef AffixCSVList)
{
	CurAugment := ItemDataChunk
	Loop, Parse, ItemDataChunk, `n, `r
	{
		CurAugment := A_LoopField
		Globals.Set("CurAugment", A_LoopField)
		IfInString, A_LoopField, Requirements:
		{
			; too far - Requirements: is already the next chunk
			Break
		}
		IfInString, A_LoopField, (augmented)
		{
			StringSplit, LineParts, A_LoopField, :
			AffixCSVList := AffixCSVList . "'"  . LineParts%LineParts%1 . "'"
			AffixCSVList := AffixCSVList . ", "
		}
	}
	AffixCSVList := SubStr(AffixCSVList, 1, -2)
}

ParseRequirements(ItemDataChunk, ByRef Level, ByRef Attributes, ByRef Values="")
{
	IfNotInString, ItemDataChunk, Requirements
	{
		return
	}
	Attr =
	AttrValues =
	Delim := ","
	DelimLen := StrLen(Delim)
	Loop, Parse, ItemDataChunk, `n, `r
	{
		If StrLen(A_LoopField) = 0
		{
			Break ; Not interested in blank lines
		}
		IfInString, A_LoopField, Str
		{
			Attr := Attr . "Str" . Delim
			AttrValues := AttrValues . GetColonValue(A_LoopField) . Delim
		}
		IfInString, A_LoopField, Dex
		{
			Attr := Attr . "Dex" . Delim
			AttrValues := AttrValues . GetColonValue(A_LoopField) . Delim
		}
		IfInString, A_LoopField, Int
		{
			Attr := Attr . "Int" . Delim
			AttrValues := AttrValues . GetColonValue(A_LoopField) . Delim
		}
		IfInString, A_LoopField, Level
		{
			Level := GetColonValue(A_LoopField)
		}
	}
	; Chop off last Delim
	If (SubStr(Attr, -(DelimLen-1)) == Delim)
	{
		Attr := SubStr(Attr, 1, -(DelimLen))
	}
	If (SubStr(AttrValues, -(DelimLen-1)) == Delim)
	{
		AttrValues := SubStr(AttrValues, 1, -(DelimLen))
	}
	Attributes := Attr
	Values := AttrValues
}

; Parses #low-#high and sets Hi to #high and Lo to #low
; if RangeChunk is just a single value (#) it will set both
; Hi and Lo to this single value (effectively making the range 1-1 if # was 1)
SplitRange(RangeChunk, ByRef Lo, ByRef Hi)
{
	IfInString, RangeChunk, -
	{
		StringSplit, RangeParts, RangeChunk, -
		Lo := RegExReplace(RangeParts1, "(\d+?)", "$1")
		Hi := RegExReplace(RangeParts2, "(\d+?)", "$1")
	}
	Else
	{
		Lo := RangeChunk
		Hi := RangeChunk
	}
}

FormatDoubleRanges(BtmMin, BtmMax, TopMin, TopMax, StyleOverwrite="")
{
	Global Opts
	
	If (StyleOverwrite = "compact" or (Opts.UseCompactDoubleRanges and StyleOverwrite = "") )
	{
		ValueRange := BtmMin "-" TopMax
	}
	Else
	{
		; Other Variant: Simplify ranges like 1-1 to 1
		; LowerRange := (BtmMin = BtmMax) ? BtmMin : BtmMin "-" BtmMax
		; UpperRange := (TopMin = TopMax) ? TopMax : TopMin "-" TopMax
		; ValueRange := LowerRange "|" UpperRange
		
		ValueRange := BtmMin "-" BtmMax  Opts.DoubleRangeSeparator  TopMin "-" TopMax
	}
	
	return ValueRange
}

FormatMultiTierRange(BtmMin, BtmMax, TopMin, TopMax)
{
	Global Opts
	
	If (BtmMin = TopMin and BtmMax = TopMax)
	{
		return BtmMin "-" TopMax
	}
	Else 
	{
		return BtmMin "-" BtmMax  Opts.MultiTierRangeSeparator  TopMin "-" TopMax
	}
}

ParseItemLevel(ItemDataText)
{
	; XXX
	; Add support for The Awakening Closed Beta
	; Once TA is released we won't need to support both occurences of
	; the word "Item level" any more...
	ItemDataChunk := GetItemDataChunk(ItemDataText, "Itemlevel:")
	If (StrLen(ItemDataChunk) <= 0)
	{
		ItemDataChunk := GetItemDataChunk(ItemDataText, "Item Level:")
	}

	Assert(StrLen(ItemDataChunk) > 0, "ParseItemLevel: couldn't parse item data chunk")

	Loop, Parse, ItemDataChunk, `n, `r
	{
		IfInString, A_LoopField, Itemlevel:
		{
			StringSplit, ItemLevelParts, A_LoopField, %A_Space%
			Result := StrTrimWhitespace(ItemLevelParts2)
			return Result
		}
		IfInString, A_LoopField, Item Level:
		{
			StringSplit, ItemLevelParts, A_LoopField, %A_Space%
			Result := StrTrimWhitespace(ItemLevelParts3)
			return Result
		}
	}
}

;;hixxie fixed. Shows MapLevel for any map base.
ParseMapTier(ItemDataText)
{
	ItemDataChunk := GetItemDataChunk(ItemDataText, "MapTier:")
	If (StrLen(ItemDataChunk) <= 0)
	{
		ItemDataChunk := GetItemDataChunk(ItemDataText, "Map Tier:")
	}

	Assert(StrLen(ItemDataChunk) > 0, "ParseMapTier: couldn't parse item data chunk")

	Loop, Parse, ItemDataChunk, `n, `r
	{
		IfInString, A_LoopField, MapTier:
		{
			StringSplit, MapLevelParts, A_LoopField, %A_Space%
			Result := StrTrimWhitespace(MapLevelParts2)
			return Result
		}
		IfInString, A_LoopField, Map Tier:
		{
			StringSplit, MapLevelParts, A_LoopField, %A_Space%
			Result := StrTrimWhitespace(MapLevelParts3)
			return Result
		}
	}
}

MapMetamorphOrganToMap(ItemName) {
	organ := RegExReplace(ItemName, "i).*(Brain|Liver|Lung|Eye|Heart)$", "$1")
	mapList := ""
	For key, val in MetamorphData.organToMap {
		If (key = organ) {
			i := 0
			For Index, Value In val {
				i++
				mapList .= ", " . RegExReplace(Value, "i)\s?Map")				
				If (i >= 7) {
					mapList .= "`n"
					i := 0
				}
			}
			mapList := LTrim(mapList, ", ")
		}
	}
	Return { "default" : mapList, "sorted" : MapMetamorphOrganToMapSorted(ItemName)}
}

MapMetamorphOrganToMapSorted(ItemName) {
	organ := RegExReplace(ItemName, "i).*(Brain|Liver|Lung|Eye|Heart)$", "$1")
	mapList := ""
	
	sortedList := [[],[],[],[]]
	For key, val in MetamorphData.mapToOrgan {
		If (IsInArray(organ, val)) {
			sortedList[val.MaxIndex()-1].push(key)
		}
	}
	
	listStr := ""
	For i, organLimit in sortedList {
		k := 0
		lineStr := ""
		For j, map in organLimit {
			k++
			lineStr .= RegExReplace(map, "i)\s?Map") ", "
			If (k >= 8) {				
				If (j > 1) {
					lineStr .= "`n" . "       "
				} Else {
					lineStr .= "`n"
				}
				k := 0
			}		
		}
		listStr .= "`n`n" . "[ " i " ]: " RegExReplace(lineStr,"i),\s+?$")
	}

	Return listStr
}

MapMetamorphMapToOrgan(map) {
	organList := ""
	For key, val in MetamorphData.mapToOrgan {
		If (key = map) {
			For Index, Value In val
				organList .= ", " . Value
			organList := LTrim(organList, ", ")
		}
	}
	Return organList
}

ParseGemLevel(ItemDataText, PartialString="Level:")
{
	ItemDataChunk := GetItemDataChunk(ItemDataText, PartialString)
	Loop, Parse, ItemDataChunk, `n, `r
	{
		IfInString, A_LoopField, %PartialString%
		{
			StringSplit, ItemLevelParts, A_LoopField, %A_Space%
			Result := StrTrimWhitespace(ItemLevelParts2)
			return Result
		}
	}
}

ParseGemColor(ItemDataText)
{
	RegExMatch(ItemDataText, "ims)Requirements.*?(Str\s?:\s?(\d+))", str)
	RegExMatch(ItemDataText, "ims)Requirements.*?(Dex\s?:\s?(\d+))", dex)
	RegExMatch(ItemDataText, "ims)Requirements.*?(Int\s?:\s?(\d+))", int)
	
	highestRequirement := ""
	If (not str2 and not dex2 and not int2) {
		Return "WHITE"
	}
	Else If (str2 > dex2 and str2 > int2) {
		Return "RED"
	}
	Else If (dex2 > str2 and dex2 > int2) {
		Return "GREEN"
	}
	Else If (int2 > dex2 and int2 > str2) {
		Return "BLUE"
	}
}

ParseGemXP(ItemDataText, PartialString="Experience:", ByRef Flat = "")
{
	ItemDataChunk := GetItemDataChunk(ItemDataText, PartialString)
	Loop, Parse, ItemDataChunk, `n, `r
	{
		IfInString, A_LoopField, %PartialString%
		{
			StringSplit, ItemLevelParts, A_LoopField, %A_Space%
			_Flat := StrTrimWhitespace(ItemLevelParts2)
			XP := RegExReplace(_Flat, "\.")			
		}
	}
	If (XP) {
		RegExMatch(XP, "i)([0-9.,]+)\/([0-9.,]+)", xpPart)
		If (StrLen(xpPart1) and StrLen(xpPart2)) {
			Percent := Round((xpPart1 / xpPart2) * 100)
			Flat := _Flat
			Return Percent
		}
	}
}

; For Debug purposes. Can be used to unravel an object into a printable format.
ExploreObj(Obj, NewRow="`n", Equal="  =  ", Indent="`t", Depth=12, CurIndent="")
{ 
	for k,v in Obj
		ToReturn .= CurIndent . k . (IsObject(v) && depth>1 ? NewRow . ExploreObj(v, NewRow, Equal, Indent, Depth-1, CurIndent . Indent) : Equal . v) . NewRow

	return RTrim(ToReturn, NewRow)
}


DebugMode := False

DebugFile(Content, LineEnd="`n", StartNewFile=False)
{
	Global DebugMode
	
	If ( not isDevVersion){
	DebugMode := False 
	}
	
	If (DebugMode = False)
		return
	
	If (StartNewFile){
		FileDelete, DebugFile.txt
	}
	
	If (IsObject(Content))
	{
		Print := "`n>>`n" ExploreObj(Content) "`n<<`n"
	}
	Else If (StrLen(Content) > 100)
	{
		Print := "`n" Content "`n`n"
	}
	Else
	{
		Print := Content . LineEnd
	}
	
	FileAppend, %Print%, DebugFile.txt, UTF-8
}

StrMult(Char, Times)
{
	Result =
	Loop, %Times%
	{
		Result := Result . Char
	}
	return Result
}

StrTrimSpaceLeft(String)
{
	return RegExReplace(String, " *(.+?)", "$1")
}

StrTrimSpaceRight(String)
{
	return RegExReplace(String, "(.+?) *$", "$1")
}

StrTrimSpace(String)
{
	return RegExReplace(String, " *(.+?) *", "$1")
}

StrTrimWhitespace(String)
{
	return RegExReplace(String, "[ \r\n\t]*(.+?)[ \r\n\t]*", "$1")
}

; Pads a string with a multiple of PadChar to become a wanted total length.
; Note that Side is the side that is padded not the anchored side.
; Meaning, if you pad right side, the text will move left. If Side was an
; anchor instead, the text would move right if anchored right.
StrPad(String, Length, Side="right", PadChar=" ")
{
	StringLen, Len, String
	AddLen := Length-Len
	If (AddLen <= 0)
	{
		return String
	}
	Pad := StrMult(PadChar, AddLen)
	If (Side == "right")
	{
		Result := String . Pad
	}
	Else
	{
		Result := Pad . String
	}
	return Result
}

; Prefix a string s with another string prefix.
; Does nothing if s is already prefixed.
StrPrefix(s, prefix) {
	If (s == "") {
		return ""
	} Else {
		If (SubStr(s, 1, StrLen(prefix)) == prefix) {
			return s ; Nothing to do
		} Else {
			return prefix . s
		}
	}
}

; Formats a number with SetFormat (leaving A_FormatFloat unchanged)
; Returns formatted Num as string.
NumFormat(Num, Format)
{
	oldFormat := A_FormatFloat
	newNum := Num
	SetFormat, FloatFast, %Format%
	newNum += 0.0 ; convert to float, which applies SetFormat
	newNum := newNum . "" ; convert to string so the next SetFormat doesn't apply
	SetFormat, FloatFast, %oldFormat%
	return newNum
}

; Formats floating values such as 2.50000 or 3.00000 into 2.5 and 3
NumFormatPointFiveOrInt(Value){
	If ( not Mod(Value, 1) )
	{
		return Round(Value)
	}
	Else
	{
		return NumFormat(Value, 0.1)
	}
}

; Pads a number with prefixed 0s and optionally rounds or appends to specified decimal places width.
NumPad(Num, TotalWidth, DecimalPlaces=0)
{
	myFormat = 0%TotalWidth%.%DecimalPlaces%
	newNum := NumFormat(Num, myFormat)
	return newNum
}

AffixTypeShort(AffixType)
{
	result := RegExReplace(AffixType, "Hybrid Defence Prefix", "HDP")
	result := RegExReplace(result, "Crafted ", "Cr")		; not fully supported yet.
	result := RegExReplace(result, "Hybrid ", "Hyb")
	result := RegExReplace(result, "Prefix", "P")
	result := RegExReplace(result, "Suffix", "S")
	
	return result
}

MakeAffixDetailLine(AffixLine, AffixType, ValueRange, Tier, CountAffixTotals=True)
{
	Global ItemData, AffixTotals
	
	If (CountAffixTotals)
	{
		If (AffixType = "Hybrid Prefix" or AffixType = "Hybrid Defence Prefix"){
			AffixTotals.NumPrefixes += 0.5
		}
		Else If (AffixType = "Hybrid Suffix"){
			AffixTotals.NumSuffixes += 0.5
		}
		Else If (AffixType ~= "Prefix"){	; using ~= to match all that contains "Prefix", such as "Crafted Prefix".
			AffixTotals.NumPrefixes += 1
		}
		Else If (AffixType ~= "Suffix"){
			AffixTotals.NumSuffixes += 1
		}
	}
	
	If (Item.IsJewel and not (Item.IsAbyssJewel or Item.IsClusterJewel))
	{
		TierAndType := AffixTypeShort(AffixType)	; Discard tier since it's always T1
		
		return [AffixLine, ValueRange, TierAndType]
	}
	
	If (IsObject(AffixType))
	{
		; Multiple mods in one line
		TierAndType := ""
		
		For n, AfTy in AffixType
		{
			If (IsObject(Tier[A_Index]))
			{
				; Tier has a range
				If (Tier[A_Index][1] = Tier[A_Index][2])
				{
					Ti := Tier[A_Index][1]
				}
				Else
				{
					Ti := Tier[A_Index][1] "-" Tier[A_Index][2]
				}
			}
			Else
			{
				Ti := Tier[A_Index]
			}
			
			TierAndType .= "T" Ti " " AffixTypeShort(AfTy) " + "
		}
		
		TierAndType := SubStr(TierAndType, 1, -3)	; Remove trailing " + " at line end
	}
	Else If (IsObject(Tier))
	{
		; Just one mod in the line, but Tier has a range
		If (Tier[1] = Tier[2])
		{
			Ti := Tier[1]
		}
		Else
		{
			Ti := Tier[1] "-" Tier[2]
		}
		
		TierAndType := "T" Ti " " AffixTypeShort(AffixType)
	}
	Else
	{
		If (IsNum(Tier) or Tier = "?")
		{
			; Just one mod and a single numeric tier
			TierAndType := "T" Tier " " AffixTypeShort(AffixType)
		}
		Else
		{
			; Some special mods like meta crafts provide no Tier, don't use the "T" in that case.
			TierAndType := AffixTypeShort(AffixType)
		}
	}
	
	return [AffixLine, ValueRange, TierAndType]
}

MakeMapAffixLine(AffixLine, MapAffixCount)
{
	Line := [AffixLine, MapAffixCount]
	return Line
}

AppendAffixInfo(Line, AffixPos)
{
	Global AffixLines
	AffixLines.Set(AffixPos, Line)
}

AssembleAffixDetails()
{
	Global Opts, AffixLines, Itemdata
	
	Result := ""
	NumAffixLines := AffixLines.MaxIndex()		; ( Itemdata.AffixTextLines.MaxIndex() > AffixLines.MaxIndex() ) ? Itemdata.AffixTextLines.MaxIndex() : AffixLines.MaxIndex()
	
	TextLineWidth := 23
	TextLineWidthUnique := TextLineWidth + 10
	TextLineWidthJewel  := TextLineWidth + 10
	
	ValueRange1Width := 4
	ValueRange2Width := 5
	
	Separator := Opts.AffixColumnSeparator
	Ellipsis := Opts.AffixTextEllipsis
	
	If (Item.IsUnique)
	{
		Loop, %NumAffixLines%
		{
			CurLine := AffixLines[A_Index]
			AffixText := CurLine[1]
			ValueRange := CurLine[2]
			
			If (StrLen(AffixText) > TextLineWidthUnique)
			{
				AffixText := SubStr(AffixText, 1, TextLineWidthUnique - StrLen(Ellipsis)) . Ellipsis
			}
			Else
			{
				AffixText := StrPad(AffixText, TextLineWidthUnique)
			}
			
			ProcessedLine := AffixText . Separator . ValueRange
			
			Result .= "`n" ProcessedLine
		}
		
		return Result
	}
	Else
	{
		Loop, %NumAffixLines%
		{
			CurLine := AffixLines[A_Index]
			
			ValueRange := CurLine[2]
			If ( ! IsObject(ValueRange) )
			{
				; Text as ValueRange
				continue
			}
			
			If ( StrLen(ValueRange[1]) > ValueRange1Width )
			{
				If (ValueRange[2])
				{
					ValueRange1Width := StrLen(ValueRange[1])
				}
				Else
				{	; TierRange has no ilvl entry, can expand a bit.
					; Moving more the longer the range text is. Until 9 chars: +2, 10-11 chars: +3, 12-13 chars: +4, then: +5.
					; This keeps the "…" of a multi tier range aligned with the "-" of most normal ranges,
					;   but also keeps slightly larger normal ranges aligned as usual, like so:
					/*        28-32 (44)
					       48-62…58-72  
					        104-117     
					          30-35 (49)
					       84-97…94-108 
					     119-261…201-361
					          40-44 (35)
					*/
					extra := StrLen(ValueRange[1]) <= 7 ? 0 : (StrLen(ValueRange[1]) <= 9 ? 2 : ( StrLen(ValueRange[1]) <= 11 ? 3 : ( StrLen(ValueRange[1]) <= 13 ? 4 : 5)))
					
					If ( StrLen(ValueRange[1]) > ValueRange1Width + extra )
					{
						ValueRange1Width := StrLen(ValueRange[1]) - extra
					}
				}
			}
			
			If ( StrLen(ValueRange[3]) > ValueRange2Width )
			{
				ValueRange2Width := StrLen(ValueRange[3])
			}
		}
		
		If ( not ((Item.IsJewel and not (Item.IsAbyssJewel or Item.IsClusterJewel)) or Item.IsFlask) and Opts.ShowHeaderForAffixOverview)
		{
			; Add a header line above the affix infos.			
			ProcessedLine := "`n"
			ProcessedLine .= StrPad("TierRange", TextLineWidth + ValueRange1Width + StrLen(Separator), "left")
			ProcessedLine .= " ilvl" Separator
			ProcessedLine .= StrPad("Total", ValueRange2Width, "left")
			ProcessedLine .= " ilvl" Separator
			ProcessedLine .= "Tier"
			
			Result .= ProcessedLine
		}
		
		Loop, %NumAffixLines%
		{
			CurLine := AffixLines[A_Index]
			; Any empty line is considered as an Unprocessed Mod
			If (IsObject(CurLine))
			{
				AffixText := CurLine[1]
				ValueRange := CurLine[2]
				TierAndType := CurLine[3]
				
				If (AffixText = "or")
				{
					AffixText := "--or--"
					AffixText := StrPad(AffixText, round( (TextLineWidth + StrLen(AffixText))/2 ), "left")	; align mid
				}
				
				If ((Item.IsJewel and (Item.IsAbyssJewel or Item.IsClusterJewel)) or Item.IsFlask)
				{
					If (StrLen(AffixText) > TextLineWidthJewel)
					{
						ProcessedLine := SubStr(AffixText, 1, TextLineWidthJewel - StrLen(Ellipsis))  Ellipsis
					}
					Else
					{
						ProcessedLine := StrPad(AffixText, TextLineWidthJewel)
					}
					
					; Jewel mods don't have tiers. Display only the ValueRange and the AffixType. TierAndType already holds only the Type here, due to a check in MakeAffixDetailLine().
					ProcessedLine .= Separator " " StrPad(ValueRange[1], ValueRange1Width, "left")
					ProcessedLine .= Separator  TierAndType
				}
				Else
				{
					If (StrLen(AffixText) > TextLineWidth)
					{
						ProcessedLine := SubStr(AffixText, 1, TextLineWidth - StrLen(Ellipsis))  Ellipsis
					}
					Else
					{
						ProcessedLine := StrPad(AffixText, TextLineWidth)
					}
					
					If ( ! IsObject(ValueRange) )
					{
						; Text as ValueRange. Right-aligned to tier range column and with separator if it fits.
						If (StrLen(ValueRange) > ValueRange1Width + 5)
						{
							; wider than the TierRange column (with ilvl space), content is allowed to also move in the second column but we can't put the Separator in.
							ProcessedLine .= Separator  StrPad(StrPad(ValueRange, ValueRange1Width + 5, "left"), ValueRange1Width + 5 + StrLen(Separator) + ValueRange2Width + 5, "right")
						}
						Else
						{
							; Fits into TierRange column (with ilvl space), so we set the Separator and an empty column two.
							ProcessedLine .= Separator  StrPad(StrPad(ValueRange, ValueRange1Width + 5, "left") . Separator, ValueRange1Width + 5 + StrLen(Separator) + ValueRange2Width + 5, "right")
						}
						
						If (RegExMatch(TierAndType, "^T\d.*"))
						{
							ProcessedLine .= Separator  TierAndType
						}
						Else
						{
							; If TierAndType does not start with T and a number, then there is just the affix type (or other text) stored. Add 3 spaces to align affix type with the others.
							ProcessedLine .= Separator  "   " TierAndType
						}
					}
					Else
					{
						If (IsNum(ValueRange[2]))
						{	; Has ilvl entry for tier range
							ProcessedLine .= Separator  StrPad(ValueRange[1], ValueRange1Width, "left") " " StrPad("(" ValueRange[2] ")", 4, "left")
							ProcessedLine .= Separator  StrPad(ValueRange[3], ValueRange2Width, "left") " " StrPad("(" ValueRange[4] ")", 4, "left")
							ProcessedLine .= Separator  TierAndType
						}
						Else If (ValueRange[2] != "")
						{	; Has some kind of ilvl entry that is not a number, likely a space. Format as above but without brackets.
							ProcessedLine .= Separator  StrPad(ValueRange[1], ValueRange1Width, "left") " " StrPad(ValueRange[2] , 4, "left")
							ProcessedLine .= Separator  StrPad(ValueRange[3], ValueRange2Width, "left") " " StrPad(ValueRange[4] , 4, "left")
							ProcessedLine .= Separator  TierAndType
						}
						Else
						{	; Has no ilvl entry for tier range, can expand a bit.
							; The "extra" calculation and reasoning has an explanation about 100 code lines above.
							extra := StrLen(ValueRange[1]) <= 7 ? 0 : (StrLen(ValueRange[1]) <= 9 ? 2 : ( StrLen(ValueRange[1]) <= 11 ? 3 : ( StrLen(ValueRange[1]) <= 13 ? 4 : 5)))
							
							ProcessedLine .= Separator  StrPad(ValueRange[1] . StrMult(" ", 5 - extra), ValueRange1Width + 5, "left")
							ProcessedLine .= Separator  StrPad(ValueRange[3], ValueRange2Width, "left") " " StrPad("(" ValueRange[4] ")", 4, "left")
							ProcessedLine .= Separator  TierAndType
						}
					}
				}
			}
			Else
			{
				ProcessedLine := "   Essence Mod, unknown Mod or unsolved case"
			}
			
			Result .= "`n" ProcessedLine
		}
	}
	
	return Result
}

AssembleMapAffixes()
{
	Global Opts, AffixLines

	AffixLine =
	NumAffixLines := AffixLines.MaxIndex()
	AffixLineParts := 0
	Loop, %NumAffixLines%
	{
		CurLine := AffixLines[A_Index]
		; Any empty line is considered as an Unprocessed Mod
		If (IsObject(CurLine))
		{
			AffixLine := CurLine[1]
			MapAffixCount := CurLine[2]
			
			ProcessedLine := Format("{1: 2s}) {2:s}", MapAffixCount, AffixLine)
		}
		Else
		{
			ProcessedLine := "   Unknown Mod"
		}
		
		Result := Result . "`n" . ProcessedLine
	}
	return Result
}

; Checks ActualValue against ValueRange, returning 1 if
; ActualValue is within bounds of ValueRange, 0 otherwise.
WithinBounds(ValueRange, ActualValue)
{
	VHi := 0
	VLo := 0
	SplitRange(ValueRange, VLo, VHi)
	Result := 1
	IfInString, ActualValue, -
	{
		AVHi := 0
		AVLo := 0
		SplitRange(ActualValue, AVLo, AVHi)
		If ((AVLo < VLo) or (AVHi > VHi))
		{
			Result := 0
		}
	}
	Else
	{
		If ((ActualValue < VLo) or (ActualValue > VHi))
		{
			Result := 0
		}
	}
	return Result
}

; Get actual value from a line of the ingame tooltip as a number
; that can be used in calculations.
GetActualValue(ActualValueLine)
{
	; Leaves "-" in for negative values, example: "Ventor's Gamble"
	Result := RegExReplace(ActualValueLine, ".*?\+?(-?\d+(?: to -?\d+|\.\d+)?).*", "$1")
	; Formats "1 to 2" as "1-2"
	StringReplace, Result, Result, %A_SPACE%to%A_SPACE%, -
	return Result
}

; Get value from a colon line, e.g. given the line "Level: 57", returns the number 57
GetColonValue(Line)
{
	IfInString, Line, :
	{
		StringSplit, LineParts, Line, :
		Result := StrTrimSpace(LineParts%LineParts%2)
		return Result
	}
}

AddRange(Range1, Range2)
{
	R1Hi := 0
	R1Lo := 0
	R2Hi := 0
	R2Lo := 0
	SplitRange(Range1, R1Lo, R1Hi)
	SplitRange(Range2, R2Lo, R2Hi)
	FinalHi := R1Hi + R2Hi
	FinalLo := R1Lo + R2Lo
	FinalRange = %FinalLo%-%FinalHi%
	return FinalRange
}

/*
ParseProphecy(ItemData, ByRef Difficulty = "", ByRef SealingCost = "")
{
	; Will have to be reworked for 3.0
	For key, part in ItemData.Parts {
		RegExMatch(part, "i)(Normal)|(Cruel)|(Merciless) Difficulty", match)
		If (match) {
			Difficulty := match1 . match2 . match3
		}
	}
}
*/


ParseFlaskAffixes(ItemDataAffixes)
{
	IfInString, ItemDataChunk, Unidentified
	{
		return ; Not interested in unidentified items
	}
	
	Loop, Parse, ItemDataAffixes, `n, `r
	{
		If StrLen(A_LoopField) = 0
		{
			Continue ; Not interested in blank lines
		}
		
		
		IfInString, A_LoopField, `% increased Charge Recovery
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Prefix", ["20-40"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, Maximum Charges
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Prefix", ["10-20"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, `% reduced Charges used
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Prefix", ["20-25"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, 50`% increased Amount Recovered
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Prefix", ["50"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, 33`% reduced Recovery Rate
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Prefix", ["33"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, 100`% increased Recovery when on Low Life
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Prefix", ["100"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, 40`% increased Life Recovered
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Prefix", ["40"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, Removes 10`% of Life Recovered from Mana when used
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Prefix", ["10"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, 60`% increased Mana Recovered
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Prefix", ["60"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, Removes 15`% of Mana Recovered from Life when used
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Prefix", ["15"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, 25`% reduced Amount Recovered
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Prefix", ["25"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, Instant Recovery when on Low Life
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Prefix", [""], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, 66`% reduced Amount Recovered
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Prefix", ["66"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, Instant Recovery
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Prefix", [""], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, 50`% reduced Amount Recovered
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Prefix", ["50"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, 135`% increased Recovery Rate
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Prefix", ["135"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, 50`% of Recovery applied Instantly
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Prefix", ["50"], "", False), A_Index)
			Continue
		}
		IfInString, A_LoopField, 50`% increased Recovery Rate
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Prefix", ["50"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, `% increased Duration
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Prefix", ["30-40"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, 25`% increased effect 
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Prefix", ["25"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, 33`% reduced Duration 
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Prefix", ["33"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, 20`% chance to gain a Flask Charge when you deal a Critical Strike
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Prefix", ["20"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, Recharges 1 Charge when you deal a Critical Strike
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Prefix", ["Legacy"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, Recharges 3 Charges when you take a Critical Strike 
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Prefix", ["3"], ""), A_Index)
			Continue
		}
		
		
		IfInString, A_LoopField, Adds Knockback to Melee Attacks during Flask effect 
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Suffix", [""], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, `% increased Armour during Flask effect 
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Suffix", ["60-100"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, `% increased Evasion Rating during Flask effect 
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Suffix", ["60-100"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, 0.4`% of Physical Attack Damage Leeched as Life during Flask effect
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Suffix", ["0.4"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, 0.4`% of Physical Attack Damage Leeched as Mana during Flask effect
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Suffix", ["0.4"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, `% of Life Recovery to Minions
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Suffix", ["40-60"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, `% increased Movement Speed during Flask effect
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Suffix", ["20-30"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, `% additional Elemental Resistances during Flask effect
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Suffix", ["20-30"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, `% increased Block and Stun Recovery during Flask effect 
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Suffix", ["40-60"], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, Immun
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Suffix", [""], ""), A_Index)
			Continue
		}
		IfInString, A_LoopField, Removes
		{
			AppendAffixInfo(MakeAffixDetailLine(A_LoopField, "Hybrid Suffix", [""], ""), A_Index)
			Continue
		}
	}
}

SetMapInfoLine(AffixType, ByRef MapAffixCount, EnumLabel="")
{
	Global AffixTotals
	
	If (AffixType =="Prefix")
	{
		AffixTotals.NumPrefixes += 1
	}
	Else If (AffixType =="Suffix")
	{
		AffixTotals.NumSuffixes += 1
	}
	
	MapAffixCount += 1
	AppendAffixInfo(MakeMapAffixLine(A_LoopField, MapAffixCount . EnumLabel), A_Index)
}

ParseMapAffixes(ItemDataAffixes)
{
	Global Globals, Opts, AffixTotals, AffixLines
	
	MapModWarn := class_EasyIni(userDirectory "\MapModWarnings.ini").Affixes
	; FileRead, File_MapModWarn, %userDirectory%\MapModWarnings.txt
	; MapModWarn := JSON.Load(File_MapModWarn)
	
	ItemDataChunk	:= ItemDataAffixes
	
	ItemBaseType	:= Item.BaseType
	ItemSubType	:= Item.SubType
	
	
	; Reset the AffixLines "array" and other vars
	ResetAffixDetailVars()
	
	IfInString, ItemDataChunk, Unidentified
	{
		return ; Not interested in unidentified items
	}
	
	MapAffixCount := 0
	TempAffixCount := 0
	
	Index_RareMonst :=
	Index_MonstSlowedTaunted :=
	Index_BossDamageAttackCastSpeed :=
	Index_BossLifeAoE :=
	Index_MonstChaosEleRes :=
	Index_MonstStunLife :=
	Index_MagicMonst :=
	Index_MonstCritChanceMult :=
	Index_PlayerDodgeMonstAccu :=
	Index_PlayerBlockArmour :=
	Index_CannotLeech :=
	Index_MonstMoveAttCastSpeed :=

	Count_DmgMod := 0
	String_DmgMod := ""

	Flag_TwoAdditionalProj := 0
	Flag_SkillsChain := 0

	MapModWarnings := ""

	Loop, Parse, ItemDataAffixes, `n, `r
	{
		If StrLen(A_LoopField) = 0
		{
			Continue ; Not interested in blank lines
		}		
		
		; --- ONE LINE AFFIXES ---		
		
		If (RegExMatch(A_LoopField, "Area is inhabited by 2 additional Rogue Exiles|Area has increased monster variety"))
		{
			SetMapInfoLine("Prefix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Area is inhabited by .*"))
		{
			SetMapInfoLine("Prefix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Monsters deal \d+% extra Damage as (Fire|Cold|Lightning)"))
		{
			MapModWarnings .= MapModWarn.MonstExtraEleDmg ? "`nExtra Ele Damage" : ""			
			SetMapInfoLine("Prefix", MapAffixCount)
			Count_DmgMod += 1
			String_DmgMod := String_DmgMod . ", Extra Ele"
			Continue
		}
		If (RegExMatch(A_LoopField, "Monsters reflect \d+% of Elemental Damage"))
		{
			MapModWarnings .= MapModWarn.EleReflect ? "`nEle reflect" : ""
			SetMapInfoLine("Prefix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Monsters reflect \d+% of Physical Damage"))
		{
			MapModWarnings .= MapModWarn.PhysReflect ? "`nPhys reflect" : ""
			SetMapInfoLine("Prefix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "\+\d+% Monster Physical Damage Reduction"))
		{
			MapModWarnings .= MapModWarn.MonstPhysDmgReduction ? "`nPhys Damage Reduction" : ""
			SetMapInfoLine("Prefix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "\d+% less effect of Curses on Monsters"))
		{
			MapModWarnings .= MapModWarn.MonstLessCurse ? "`nLess Curse Effect" : ""
			SetMapInfoLine("Prefix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Monsters have a \d+% chance to avoid Poison, Blind, and Bleed"))
		{
			MapModWarnings .= MapModWarn.MonstAvoidPoisonBlindBleed ? "`nAvoid Poison/Blind/Bleed" : ""
			SetMapInfoLine("Prefix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Monsters have a \d+% chance to cause Elemental Ailments on Hit"))
		{
			MapModWarnings .= MapModWarn.MonstCauseElementalAilments ? "`nCause Elemental Ailments" : ""
			SetMapInfoLine("Prefix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "\d+% increased Monster Damage"))
		{
			MapModWarnings .= MapModWarn.MonstIncrDmg ? "`nIncreased Damage" : ""
			SetMapInfoLine("Prefix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Area contains many Totems"))
		{
			MapModWarnings .= MapModWarn.ManyTotems ? "`nTotems" : ""
			SetMapInfoLine("Prefix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Monsters' skills Chain 2 additional times"))
		{
			MapModWarnings .= MapModWarn.MonstSkillsChain ? "`nSkills Chain" : ""
			SetMapInfoLine("Prefix", MapAffixCount)
			Flag_SkillsChain := 1
			Continue
		}
		If (RegExMatch(A_LoopField, "All Monster Damage from Hits always Ignites"))
		{
			MapModWarnings .= MapModWarn.MonstHitsIgnite ? "`nHits Ignite" : ""
			SetMapInfoLine("Prefix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Slaying Enemies close together has a \d+% chance to attract monsters from Beyond"))
		{
			MapModWarnings .= MapModWarn.Beyond ? "`nBeyond" : ""
			SetMapInfoLine("Prefix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Area contains two Unique Bosses"))
		{
			MapModWarnings .= MapModWarn.BossTwinned ? "`nTwinned Boss" : ""
			SetMapInfoLine("Prefix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Monsters are Hexproof"))
		{
			MapModWarnings .= MapModWarn.MonstHexproof ? "`nHexproof" : ""
			SetMapInfoLine("Prefix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Monsters fire 2 additional Projectiles"))
		{
			MapModWarnings .= MapModWarn.MonstTwoAdditionalProj ? "`nAdditional Projectiles" : ""
			SetMapInfoLine("Prefix", MapAffixCount)
			Flag_TwoAdditionalProj := 1
			Continue
		}
		
		
		If (RegExMatch(A_LoopField, "Players are Cursed with Elemental Weakness"))
		{
			MapModWarnings .= MapModWarn.EleWeakness ? "`nEle Weakness" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Players are Cursed with Enfeeble"))
		{
			MapModWarnings .= MapModWarn.Enfeeble ? "`nEnfeeble" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Players are Cursed with Temporal Chains"))
		{
			MapModWarnings .= MapModWarn.TempChains ? "`nTemp Chains" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Players are Cursed with Vulnerability"))
		{
			MapModWarnings .= MapModWarn.Vulnerability ? "`nVulnerability" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			
			Count_DmgMod += 0.5
			String_DmgMod := String_DmgMod . ", Vuln"
			Continue
		}
		If (RegExMatch(A_LoopField, "Area has patches of burning ground"))
		{
			MapModWarnings .= MapModWarn.BurningGround ? "`nBurning ground" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Area has patches of chilled ground"))
		{
			MapModWarnings .= MapModWarn.ChilledGround ? "`nChilled ground" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Area has patches of shocking ground"))
		{
			MapModWarnings .= MapModWarn.ShockingGround ? "`nShocking ground" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			
			Count_DmgMod += 0.5
			String_DmgMod := String_DmgMod . ", Shocking"
			Continue
		}
		If (RegExMatch(A_LoopField, "Area has patches of desecrated ground"))
		{
			MapModWarnings .= MapModWarn.DesecratedGround ? "`nDesecrated ground" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Players gain \d+% reduced Flask Charges"))
		{
			MapModWarnings .= MapModWarn.PlayerReducedFlaskCharge ? "`nReduced Flask Charges" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Monsters have \d+% increased Area of Effect"))
		{
			MapModWarnings .= MapModWarn.MonstIncrAoE ? "`nIncreased Monster AoE" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Players have \d+% less Area of Effect"))
		{
			MapModWarnings .= MapModWarn.PlayerLessAoE ? "`nLess Player AoE" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Monsters have \d+% chance to Avoid Elemental Ailments"))
		{
			MapModWarnings .= MapModWarn.MonstAvoidElementalAilments ? "`nMonsters Avoid Elemental Ailments" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Players have \d+% less Recovery Rate of Life and Energy Shield"))
		{
			MapModWarnings .= MapModWarn.LessRecovery ? "`nLess Recovery" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Monsters take \d+% reduced Extra Damage from Critical Strikes"))
		{
			MapModWarnings .= MapModWarn.MonstTakeReducedCritDmg ? "`nReduced Crit Damage" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "-\d+% maximum Player Resistances"))
		{
			MapModWarnings .= MapModWarn.PlayerReducedMaxRes ? "`n-Max Res" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			
			Count_DmgMod += 0.5
			String_DmgMod := String_DmgMod . ", -Max Res"
			Continue
		}
		If (RegExMatch(A_LoopField, "Players have Elemental Equilibrium"))
		{
			MapModWarnings .= MapModWarn.PlayerEleEquilibrium ? "`nEle Equilibrium" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Players have Point Blank"))
		{
			MapModWarnings .= MapModWarn.PlayerPointBlank ? "`nPoint Blank" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Monsters Poison on Hit"))
		{
			MapModWarnings .= MapModWarn.MonstHitsPoison ? "`nHits Poison" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Players cannot Regenerate Life, Mana or Energy Shield"))
		{
			MapModWarnings .= MapModWarn.NoRegen ? "`nNo Regen" : ""
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		If (RegExMatch(A_LoopField, "Monsters gain (an Endurance|a Frenzy|a Power) Charge on Hit"))
		{
			SetMapInfoLine("Suffix", MapAffixCount)
			Continue
		}
		
		
		; --- SIMPLE TWO LINE AFFIXES ---
		
		
		If (RegExMatch(A_LoopField, "Rare Monsters each have a Nemesis Mod|\d+% more Rare Monsters"))
		{
			If (Not Index_RareMonst)
			{
				MapModWarnings .= MapModWarn.MonstRareNemesis ? "`nNemesis" : ""
				SetMapInfoLine("Prefix", MapAffixCount, "a")
				Index_RareMonst := MapAffixCount
				Continue
			}
			Else
			{
				AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_RareMonst . "b"), A_Index)
				Continue
			}
		}
		If (RegExMatch(A_LoopField, "Monsters cannot be slowed below base speed|Monsters cannot be Taunted"))
		{
			If (Not Index_MonstSlowedTaunted)
			{
				MapModWarnings .= MapModWarn.MonstNotSlowedTaunted ? "`nNot Slowed/Taunted" : ""
				SetMapInfoLine("Prefix", MapAffixCount, "a")
				Index_MonstSlowedTaunted := MapAffixCount
				Continue
			}
			Else
			{
				AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_MonstSlowedTaunted . "b"), A_Index)
				Continue
			}
		}
		If (RegExMatch(A_LoopField, "Unique Boss deals \d+% increased Damage|Unique Boss has \d+% increased Attack and Cast Speed"))
		{
			If (Not Index_BossDamageAttackCastSpeed)
			{
				MapModWarnings .= MapModWarn.BossDmgAtkCastSpeed ? "`nBoss Damage & Attack/Cast Speed" : ""
				SetMapInfoLine("Prefix", MapAffixCount, "a")
				Index_BossDamageAttackCastSpeed := MapAffixCount
				Continue
			}
			Else
			{
				AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_BossDamageAttackCastSpeed . "b"), A_Index)
				Continue
			}
		}
		If (RegExMatch(A_LoopField, "Unique Boss has \d+% increased Life|Unique Boss has \d+% increased Area of Effect"))
		{
			If (Not Index_BossLifeAoE)
			{
				MapModWarnings .= MapModWarn.BossLifeAoE ? "`nBoss Life & AoE" : ""
				SetMapInfoLine("Prefix", MapAffixCount, "a")
				Index_BossLifeAoE := MapAffixCount
				Continue
			}
			Else
			{
				AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_BossLifeAoE . "b"), A_Index)
				Continue
			}
		}
		If (RegExMatch(A_LoopField, "\+\d+% Monster Chaos Resistance|\+\d+% Monster Elemental Resistance"))
		{
			If (Not Index_MonstChaosEleRes)
			{
				MapModWarnings .= MapModWarn.MonstChaosEleRes ? "`nChaos/Ele Res" : ""
				SetMapInfoLine("Prefix", MapAffixCount, "a")
				Index_MonstChaosEleRes := MapAffixCount
				Continue
			}
			Else
			{
				AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_MonstChaosEleRes . "b"), A_Index)
				Continue
			}
		}
		If (RegExMatch(A_LoopField, "\d+% more Magic Monsters|Magic Monster Packs each have a Bloodline Mod"))
		{
			If (Not Index_MagicMonst)
			{
				MapModWarnings .= MapModWarn.MonstMagicBloodlines ? "`nBloodlines" : ""
				SetMapInfoLine("Suffix", MapAffixCount, "a")
				Index_MagicMonst := MapAffixCount
				Continue
			}
			Else
			{
				AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_MagicMonst . "b"), A_Index)
				Continue
			}
		}
		If (RegExMatch(A_LoopField, "Monsters have \d+% increased Critical Strike Chance|\+\d+% to Monster Critical Strike Multiplier"))
		{
			If (Not Index_MonstCritChanceMult)
			{
				MapModWarnings .= MapModWarn.MonstCritChanceMult ? "`nCrit Chance & Multiplier" : ""
				SetMapInfoLine("Suffix", MapAffixCount, "a")
				
				Count_DmgMod += 1
				String_DmgMod := String_DmgMod . ", Crit"
				Index_MonstCritChanceMult := MapAffixCount
				Continue
			}
			Else
			{
				AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_MonstCritChanceMult . "b"), A_Index)
				Continue
			}
		}
		If (RegExMatch(A_LoopField, "Player Dodge chance is Unlucky|Monsters have \d+% increased Accuracy Rating"))
		{
			If (Not Index_PlayerDodgeMonstAccu)
			{
				MapModWarnings .= MapModWarn.PlayerDodgeMonstAccu ? "`nDodge unlucky / Monster Accuracy" : ""
				SetMapInfoLine("Suffix", MapAffixCount, "a")
				Index_PlayerDodgeMonstAccu := MapAffixCount
				Continue
			}
			Else
			{
				AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_PlayerDodgeMonstAccu . "b"), A_Index)
				Continue
			}
		}
		If (RegExMatch(A_LoopField, "Players have \d+% reduced Block Chance|Players have \d+% less Armour"))
		{
			If (Not Index_PlayerBlockArmour)
			{
				MapModWarnings .= MapModWarn.PlayerReducedBlockLessArmour ? "`nReduced Block / Less Armour" : ""
				SetMapInfoLine("Suffix", MapAffixCount, "a")
				Index_PlayerBlockArmour := MapAffixCount
				Continue
			}
			Else
			{
				AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_PlayerBlockArmour . "b"), A_Index)
				Continue
			}
		}
		If (RegExMatch(A_LoopField, "Cannot Leech Life from Monsters|Cannot Leech Mana from Monsters"))
		{
			If (Not Index_CannotLeech)
			{
				MapModWarnings .= MapModWarn.NoLeech ? "`nNo Leech" : ""
				SetMapInfoLine("Suffix", MapAffixCount, "a")
				Index_CannotLeech := MapAffixCount
				Continue
			}
			Else
			{
				AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_CannotLeech . "b"), A_Index)
				Continue
			}
		}
		; Second part of this affix is further below at complex affixes
		If (RegExMatch(A_LoopField, "Monsters cannot be Stunned"))
		{
			MapModWarnings .= MapModWarn.MonstNotStunned ? "`nNot Stunned" : ""
			
			If (Not Index_MonstStunLife)
			{
				SetMapInfoLine("Prefix", MapAffixCount, "a")
				Index_MonstStunLife := MapAffixCount
				Continue
			}
			Else
			{
				AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_MonstStunLife . "b"), A_Index)
				Continue
			}
		}
		
		; --- SIMPLE THREE LINE AFFIXES ---
		
		
		If (RegExMatch(A_LoopField, "\d+% increased Monster Movement Speed|\d+% increased Monster Attack Speed|\d+% increased Monster Cast Speed"))
		{
			If (Not Index_MonstMoveAttCastSpeed)
			{
				MapModWarnings .= MapModWarn.MonstMoveAtkCastSpeed ? "`nMove/Attack/Cast Speed" : ""
				
				Count_DmgMod += 0.5
				String_DmgMod := String_DmgMod . ", Move/Attack/Cast"
				
				MapAffixCount += 1
				Index_MonstMoveAttCastSpeed := MapAffixCount . "a"
				AffixTotals.NumPrefixes += 1
				AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_MonstMoveAttCastSpeed), A_Index)
				Continue
			}
			Else If InStr(Index_MonstMoveAttCastSpeed, "a")
			{
				Index_MonstMoveAttCastSpeed := StrReplace(Index_MonstMoveAttCastSpeed, "a", "b")
				AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_MonstMoveAttCastSpeed), A_Index)
				Continue
			}
			Else If InStr(Index_MonstMoveAttCastSpeed, "b")
			{
				Index_MonstMoveAttCastSpeed := StrReplace(Index_MonstMoveAttCastSpeed, "b", "c")
				AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_MonstMoveAttCastSpeed), A_Index)
				Continue
			}
		}
		
		
		; --- COMPLEX AFFIXES ---
		
		; Pure life:  (20-29)/(30-39)/(40-49)% more Monster Life
		; Hybrid mod: (15-19)/(20-24)/(25-30)% more Monster Life, Monsters cannot be Stunned
		
		If (RegExMatch(A_LoopField, "(\d+)% more Monster Life", match))
		{
			RegExMonsterLife := match1
			MapModWarnings .= MapModWarn.MonstMoreLife ? "`nMore Life" : ""
			
			RegExMatch(ItemData.FullText, "Map Tier: (\d+)", RegExMapTier)
			
			; only hybrid mod
			If ((RegExMapTier1 >= 11 and RegExMonsterLife <= 30) or (RegExMapTier1 >= 6 and RegExMonsterLife <= 24) or RegExMonsterLife <= 19)
			{
				If (Not Index_MonstStunLife)
				{
					MapAffixCount += 1
					Index_MonstStunLife := MapAffixCount
					AffixTotals.NumPrefixes += 1
					AppendAffixInfo(MakeMapAffixLine(A_LoopField, MapAffixCount . "a"), A_Index)
					Continue
				}
				Else
				{
					AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_MonstStunLife . "b"), A_Index)
					Continue
				}
			}
			
			; pure life mod
			Else If ((RegExMapTier1 >= 11 and RegExMonsterLife <= 49) or (RegExMapTier1 >= 6 and RegExMonsterLife <= 39) or RegExMonsterLife <= 29)
			{
				MapAffixCount += 1
				AffixTotals.NumPrefixes += 1
				AppendAffixInfo(MakeMapAffixLine(A_LoopField, MapAffixCount), A_Index)
				Continue
			}
			
			; both mods
			Else
			{
				If (Not Index_MonstStunLife)
				{
					TempAffixCount := MapAffixCount + 1
					MapAffixCount += 2
					Index_MonstStunLife := TempAffixCount
					AffixTotals.NumPrefixes += 2
					AppendAffixInfo(MakeMapAffixLine(A_LoopField, TempAffixCount . "a+" . MapAffixCount), A_Index)
					Continue
				}
				Else
				{
					MapAffixCount += 1
					AffixTotals.NumPrefixes += 1
					AppendAffixInfo(MakeMapAffixLine(A_LoopField, Index_MonstStunLife . "b+" . MapAffixCount), A_Index)
					Continue
				}
			}
		}
	}
	
	If (Flag_TwoAdditionalProj and Flag_SkillsChain)
	{
		MapModWarnings := MapModWarnings . "`nAdditional Projectiles & Skills Chain"
	}
	
	If (Count_DmgMod >= 1.5)
	{
		If (MapModWarn.MultiDmgWarning)
		{
			String_DmgMod := SubStr(String_DmgMod, 3)
			MapModWarnings := MapModWarnings . "`nMulti Damage: " . String_DmgMod
		}
	}
	
	If (Not Opts.EnableMapModWarnings)
	{
		MapModWarnings := " disabled"
	}

	return MapModWarnings
}

ParseLeagueStoneAffixes(ItemDataAffixes, Item) {
	; Placeholder
}

LookupAffixAndSetInfoLine(DataSource, AffixType, ItemLevel, Value, AffixLineText:="", AffixLineNum:="")
{	
	If ( ! AffixLineText){
		AffixLineText := A_LoopField
	}
	If ( ! AffixLineNum){
		AffixLineNum := A_Index
	}
	
	AffixMode := "Native"
	If (AffixType ~= ".*Craft.*")
	{
		AffixMode := "Crafted"
	}
	Else If (AffixType ~= ".*Essence.*")
	{
		AffixMode := "Essence"
	}
	
	ValueRanges := LookupAffixData(DataSource, ItemLevel, Value, CurrTier)
	
	If (RegexMatch(AffixLineText, "Adds (\d+) to (\d+) (.+)", match) and ValueRanges[5])
	{
		NormalRow := MakeAffixDetailLine(AffixLineText, AffixType, ValueRanges, CurrTier)
		
		avgDmg := NumFormatPointFiveOrInt((match1 + match2)/2)
		AvgLineText := "   Average: "  StrPad(avgDmg, 4, "left")
		
		AppendAffixInfo([NormalRow, [AvgLineText, [ValueRanges[5], " ", ValueRanges[7], " "], ""]], AffixLineNum)
	}
	Else
	{
		AppendAffixInfo(MakeAffixDetailLine(AffixLineText, AffixType, ValueRanges, CurrTier), AffixLineNum)
	}
}
	
/*
Finds possible tier combinations for a single value (thus from a single affix line) assuming that the value is a combination of two non-hybrid mods (so with no further clues).
*/
SolveTiers_Mod1Mod2(Value, Mod1DataArray, Mod2DataArray, ItemLevel)
{
	If ((Mod1DataArray = False) or (Mod2DataArray = False))
	{
		return False
	}
	
	Mod1MinVal := Mod1DataArray[Mod1DataArray.MaxIndex()].min
	Mod2MinVal := Mod2DataArray[Mod2DataArray.MaxIndex()].min
	
	If (Mod1MinVal + Mod2MinVal > Value)
	{
		; Value is smaller than smallest possible sum, so it can't be composite
		return
	}
	
	Mod1MinIlvl := Mod1DataArray[Mod1DataArray.MaxIndex()].ilvl
	Mod2MinIlvl := Mod2DataArray[Mod2DataArray.MaxIndex()].ilvl
	
	If ( (Mod1MinIlvl > ItemLevel) or (Mod2MinIlvl > ItemLevel) )
	{
		; The ItemLevel is too low to roll both affixes
		return
	}
	
	; Remove the minimal Mod2 value from Value and try to fit the remainder into Mod1 tiers.
	TmpValue := Value - Mod2MinVal
	Mod1Tiers := LookupTierByValue(TmpValue, Mod1DataArray, ItemLevel)
	
	If (Mod1Tiers.Tier)
	{
		; Tier exists, so we already found a working combination
		Mod1TopTier := Mod1Tiers.Tier
		Mod2BtmTier := Mod2DataArray.MaxIndex()
	}
	Else
	{
		; Assuming the min portion for Mod2 was not enough, so look up the highest tier for Mod1, limited by ItemLevel
		Loop
		{
			If ( Mod1DataArray[A_Index].ilvl <= ItemLevel )
			{
				Mod1TopTier := A_Index
				Break
			}
		}
		
		; Remove the maximal Mod1 value from Value and try to fit the remainder into Mod2 tiers (giving us the bottom tier for Mod2)
		TmpValue := Value - Mod1DataArray[Mod1TopTier].max
		Mod2Tiers := LookupTierByValue(TmpValue, Mod2DataArray, ItemLevel)
		
		If (Mod2Tiers.Tier)
		{
			; Tier exists, we found a working combination
			Mod2BtmTier := Mod2Tiers.Tier
		}
		Else
		{
			; Can't find a fitting tier. This should only happen when the sum of the max values for both mods is not enough to reach Value (legacy/essence cases)
			return "Legacy?"
		}
	}
	
	; Repeat the same the other way around.
	
	TmpValue := Value - Mod1MinVal
	Mod2Tiers := LookupTierByValue(TmpValue, Mod2DataArray, ItemLevel)
	
	If (Mod2Tiers.Tier)
	{
		Mod2TopTier := Mod2Tiers.Tier
		Mod1BtmTier := Mod1DataArray.MaxIndex()
	}
	Else
	{
		Loop
		{
			If ( Mod2DataArray[A_Index].ilvl <= ItemLevel )
			{
				Mod2TopTier := A_Index
				Break
			}
		}
		
		TmpValue := Value - Mod2DataArray[Mod2TopTier].max
		Mod1Tiers := LookupTierByValue(TmpValue, Mod1DataArray, ItemLevel)
		
		If (Mod1Tiers.Tier)
		{
			Mod1BtmTier := Mod1Tiers.Tier
		}
		Else
		{
			return "Legacy?"
		}
	}
	
	return {"Mod1Top":Mod1TopTier,"Mod1Btm":Mod1BtmTier,"Mod2Top":Mod2TopTier,"Mod2Btm":Mod2BtmTier}
}

/*
Finds possible tier combinations for the following case/paramenters:
	ModHybValue: There is one value which is a combination of a normal mod and a hybrid mod.
	HybOnlyValue: The other part of the hybrid mod is plain, so there is no second normal mod combining with the other hybrid part.
	
	ModDataArray: DataArray for the normal mod.
	HybWithModDataArray: DataArray for the part of the hybrid mod that is combined with the normal mod.
	HybOnlyDataArray: DataArray for the plain part of the hybrid mod.
*/
SolveTiers_ModHyb(ModHybValue, HybOnlyValue, ModDataArray, HybWithModDataArray, HybOnlyDataArray, ItemLevel)
{
	If ((ModDataArray = False) or (HybWithModDataArray = False) or (HybOnlyDataArray = False))
	{
		return False
	}
	
	HybTiers := LookupTierByValue(HybOnlyValue, HybOnlyDataArray, ItemLevel)
	
	If (not(HybTiers.Tier))
	{
		; HybOnlyValue can't be found as a bare hybrid mod.
		return
	}
	
	; Remove hybrid portion from ModHybValue
	RemainLo := ModHybValue - HybWithModDataArray[HybTiers.Tier].max
	RemainHi := ModHybValue - HybWithModDataArray[HybTiers.Tier].min
	
	RemainHiTiers := LookupTierByValue(RemainHi, ModDataArray, ItemLevel)
	RemainLoTiers := LookupTierByValue(RemainLo, ModDataArray, ItemLevel)
	
	If ( RemainHiTiers.Tier and RemainLoTiers.Tier )
	{
		; Both RemainLo/Hi result in a possible tier
		ModTopTier := RemainHiTiers.Tier
		ModBtmTier := RemainLoTiers.Tier
	}
	Else If (RemainHiTiers.Tier)
	{
		; Only RemainHi gives a possible tier, assign that tier to both Top/Btm output results
		ModTopTier := RemainHiTiers.Tier
		ModBtmTier := RemainHiTiers.Tier
	}
	Else If (RemainLoTiers.Tier)
	{
		; Only RemainLo gives a possible tier, assign that tier to both Top/Btm output results
		ModTopTier := RemainLoTiers.Tier
		ModBtmTier := RemainLoTiers.Tier
	}
	Else If (RemainHi > ModDataArray[1].max)
	{
		; Legacy cases
		ModTopTier := 0
		ModBtmTier := 0
	}
	Else
	{
		; No matching tier found for both RemainLo/Hi values.
		return
	}
	
	return {"ModTop":ModTopTier,"ModBtm":ModBtmTier,"Hyb":HybTiers.Tier}
}

/*
Finds possible tier combinations for the following case/paramenters:
	There are three mods: two normal ones in different affix lines and a hybrid mod that combines with both.
	
	Value1/Value2: Values.
	Mod1DataArray: DataArray for the normal mod part of Value1.
	Mod2DataArray: DataArray for the normal mod part of Value2.
	Hyb1DataArray: DataArray for the hybrid mod part of Value1.
	Hyb2DataArray: DataArray for the hybrid mod part of Value2.
*/
SolveTiers_Mod1Mod2Hyb(Value1, Value2, Mod1DataArray, Mod2DataArray, Hyb1DataArray, Hyb2DataArray, ItemLevel, TierCombinationArray=False)
{
	If ((Mod1DataArray = False) or (Mod2DataArray = False) or (Hyb1DataArray = False) or (Hyb2DataArray = False))
	{
		return False
	}
	
	Mod1HybTiers := SolveTiers_Mod1Mod2(Value1, Mod1DataArray, Hyb1DataArray, ItemLevel)
	Mod2HybTiers := SolveTiers_Mod1Mod2(Value2, Mod2DataArray, Hyb2DataArray, ItemLevel)
	
	If (not( IsObject(Mod1HybTiers) and IsObject(Mod2HybTiers) ))
	{
		; Checking that both results are objects and thus contain tiers
		return
	}
	
	; Assign non-hybrid tiers into local variables because they might need to be corrected/overwritten.
	; It is always a ".Mod1" key that contains the tier here due to the order of SolveTiers_Mod1Mod2() from above.
	Mod1TopTier := Mod1HybTiers.Mod1Top
	Mod1BtmTier := Mod1HybTiers.Mod1Btm
	Mod2TopTier := Mod2HybTiers.Mod1Top
	Mod2BtmTier := Mod2HybTiers.Mod1Btm
	
	; Get the overlap of both theoretical hybrid tier ranges, because the actual hybrid tier(s) must be valid for both.
	; It is always a ".Mod2" key which contains the hybrid tier here due to the order of SolveTiers_Mod1Mod2() from above.
	; Picking the worse (numerically greater) "top" and the better (numerically lesser) "btm".
	HybTopTier := (Mod1HybTiers.Mod2Top > Mod2HybTiers.Mod2Top) ? Mod1HybTiers.Mod2Top : Mod2HybTiers.Mod2Top
	HybBtmTier := (Mod1HybTiers.Mod2Btm < Mod2HybTiers.Mod2Btm) ? Mod1HybTiers.Mod2Btm : Mod2HybTiers.Mod2Btm
	
	If (HybTopTier > HybBtmTier)
	{
		; Check that HybTopTier is not worse (numerically higher) than HybBtmTier.
		return
	}
	
	; Check if any hybrid tier was actually changed and re-calculate the corresponding non-hybrid tier.
	If (Mod1HybTiers.Mod2Top != HybTopTier)
	{
		TmpValue := Value1 - Hyb1DataArray[HybTopTier].max
		Mod1BtmTier := LookupTierByValue(TmpValue, Mod1DataArray, ItemLevel).Tier
	}
	Else If (Mod2HybTiers.Mod2Top != HybTopTier)
	{
		TmpValue := Value2 - Hyb2DataArray[HybTopTier].max
		Mod2BtmTier := LookupTierByValue(TmpValue, Mod2DataArray, ItemLevel).Tier
	}
	
	If (Mod1HybTiers.Mod2Btm != HybBtmTier)
	{
		TmpValue := Value1 - Hyb1DataArray[HybBtmTier].min
		Mod1TopTier := LookupTierByValue(TmpValue, Mod1DataArray, ItemLevel).Tier
	}
	Else If (Mod2HybTiers.Mod2Btm != HybBtmTier)
	{
		TmpValue := Value2 - Hyb2DataArray[HybBtmTier].min
		Mod2TopTier := LookupTierByValue(TmpValue, Mod2DataArray, ItemLevel).Tier
	}
	
	If (TierCombinationArray = True)
	{
		TierArray := []
		Mod1Tier := Mod1TopTier
		While Mod1Tier <= Mod1BtmTier
		{
			Mod2Tier := Mod2TopTier
			While Mod2Tier <= Mod2BtmTier
			{
				HybTier := HybTopTier
				While HybTier <= HybBtmTier
				{
					If ( Mod1DataArray[Mod1Tier].min + Hyb1DataArray[HybTier].min < Value1
					and Mod1DataArray[Mod1Tier].max + Hyb1DataArray[HybTier].max > Value1
					and Mod2DataArray[Mod2Tier].min + Hyb2DataArray[HybTier].min < Value2
					and Mod2DataArray[Mod2Tier].max + Hyb2DataArray[HybTier].max > Value2)
					{
						TierArray.push([Mod1Tier, Mod2Tier, HybTier])
					}
					++HybTier
				}
				++Mod2Tier
			}
			++Mod1Tier
		}
	}
	
	return {"Mod1Top":Mod1TopTier,"Mod1Btm":Mod1BtmTier,"Mod2Top":Mod2TopTier,"Mod2Btm":Mod2BtmTier,"HybTop":HybTopTier,"HybBtm":HybBtmTier, "TierCombinationArray":TierArray}
}

SolveTiers_Hyb1Hyb2(HybOverlapValue, Hyb1OnlyValue, Hyb2OnlyValue, Hyb1OverlapDataArray, Hyb2OverlapDataArray, Hyb1OnlyDataArray, Hyb2OnlyDataArray, ItemLevel)
{
	If ((Hyb1OverlapDataArray = False) or (Hyb2OverlapDataArray = False) or (Hyb1OnlyDataArray = False) or (Hyb2OnlyDataArray = False))
	{
		return False
	}
	
	Hyb1Tiers := LookupTierByValue(Hyb1OnlyValue, Hyb1OnlyDataArray, ItemLevel)
	Hyb2Tiers := LookupTierByValue(Hyb2OnlyValue, Hyb2OnlyDataArray, ItemLevel)
	
	If (not(Hyb1Tiers.Tier) or not(Hyb2Tiers.Tier))
	{
		; Value can't be found as a bare hybrid mod.
		return
	}
	
	OverlapValueMin := Hyb1OverlapDataArray[Hyb1Tiers.Tier].min + Hyb2OverlapDataArray[Hyb2Tiers.Tier].min
	OverlapValueMax := Hyb1OverlapDataArray[Hyb1Tiers.Tier].max + Hyb2OverlapDataArray[Hyb2Tiers.Tier].max
	
	If (not( (OverlapValueMin < HybOverlapValue) and (HybOverlapValue < OverlapValueMax) ))
	{
		; Combined Value can't be explained.
		return
	}
	
	return {"Hyb1":Hyb1Tiers.Tier,"Hyb2":Hyb2Tiers.Tier}
}

ReviseTierCombinationArray(TierCombinationArray, ReviseValue, ReviseIndex)
{
	RevisedTierCombinationArray := []
	Loop % TierCombinationArray.MaxIndex()
	{
		If (TierCombinationArray[A_Index][ReviseIndex] = ReviseValue)
		{
			RevisedTierCombinationArray.push(TierCombinationArray[A_Index])
		}
	}
	If (not RevisedTierCombinationArray[1][1]){
		return False
	}
	return RevisedTierCombinationArray
}

GetTierRangesFromTierCombinationArray(TierCombinationArray)
{
	If (not IsObject(TierCombinationArray)){
		return False
	}
	
	ResultArray := []
	
	TierIdxToCheck := 1
	; We loop over all first entries of all combinations, then over all second and so forth.
	; Consequently the outer loop is the amount of entries per combination and the inner loop the amount of combinations.
	; Check how many tier entries there are per tier combination by checking the first array.
	Loop % TierCombinationArray[1].MaxIndex()
	{
		TopTier := 100
		BtmTier := 0
		Loop % TierCombinationArray.MaxIndex()
		{
			If (TierCombinationArray[A_Index][TierIdxToCheck] < TopTier)
			{
				TopTier := TierCombinationArray[A_Index][TierIdxToCheck]
			}
			If (TierCombinationArray[A_Index][TierIdxToCheck] > BtmTier)
			{
				BtmTier := TierCombinationArray[A_Index][TierIdxToCheck]
			}
		}
		ResultArray.push([TopTier,BtmTier])
		
		++TierIdxToCheck
	}
	
	return ResultArray
}

FormatValueRangesAndIlvl(Mod1DataArray, Mod1Tiers, Mod2DataArray="", Mod2Tier="")
{
	Global Opts, Itemdata
	
	result := []
	
	If (IsObject(Mod2DataArray) and Mod2Tier)
	{
		If (IsObject(Mod1Tiers))
		{
			BtmMin := Mod1DataArray[Mod1Tiers[2]].min + Mod2DataArray[Mod2Tier].min
			BtmMax := Mod1DataArray[Mod1Tiers[2]].max + Mod2DataArray[Mod2Tier].max
			TopMin := Mod1DataArray[Mod1Tiers[1]].min + Mod2DataArray[Mod2Tier].min
			TopMax := Mod1DataArray[Mod1Tiers[1]].max + Mod2DataArray[Mod2Tier].max
			
			result[1] := FormatMultiTierRange(BtmMin, BtmMax, TopMin, TopMax)
			result[2] := ""
		}
		Else
		{
			result[1] := Mod1DataArray[Mod1Tiers].min + Mod2DataArray[Mod2Tier].min "-" Mod1DataArray[Mod1Tiers].max + Mod2DataArray[Mod2Tier].max
			result[2] := Mod1DataArray[Mod1Tiers].ilvl
		}
		
		result[3] := Mod1DataArray[Mod1DataArray.MaxIndex()].min + Mod2DataArray[Mod2DataArray.MaxIndex()].min "-" Mod1DataArray[1].max + Mod2DataArray[1].max
		result[4] := (Mod1DataArray[1].ilvl > Mod2DataArray[1].ilvl) ? Mod1DataArray[1].ilvl : Mod2DataArray[1].ilvl
	}
	Else
	{
		If (Mod1DataArray[1].maxHi)	; arbitrary pick to check whether mod has double ranges
		{
			If (IsObject(Mod1Tiers))
			{
				WorstBtmMin := Mod1DataArray[Mod1Tiers[2]].minLo
				WorstBtmMax := Mod1DataArray[Mod1Tiers[2]].minHi
				WorstTopMin := Mod1DataArray[Mod1Tiers[2]].maxLo
				WorstTopMax := Mod1DataArray[Mod1Tiers[2]].maxHi
				BestBtmMin := Mod1DataArray[Mod1Tiers[1]].minLo
				BestBtmMax := Mod1DataArray[Mod1Tiers[1]].minHi
				BestTopMin := Mod1DataArray[Mod1Tiers[1]].maxLo
				BestTopMax := Mod1DataArray[Mod1Tiers[1]].maxHi
				
				TmpFullrange := WorstBtmMin "-" WorstBtmMax " to " WorstTopMin "-" WorstTopMax " " Opts.MultiTierRangeSeparator " " BestBtmMin "-" BestBtmMax " to " BestTopMin "-" BestTopMax
				Itemdata.SpecialCaseNotation .= "`nWe have a rare case of a double range mod with multi tier uncertainty here.`n The entire TierRange is: " TmpFullrange
				
				result[1] := WorstBtmMin  Opts.DoubleRangeSeparator  WorstTopMin  Opts.MultiTierRangeSeparator  BestBtmMax  Opts.DoubleRangeSeparator  BestTopMax
				result[2] := " "
			}
			Else If (IsNum(Mod1Tiers))
			{
				BtmMin := Mod1DataArray[Mod1Tiers].minLo
				BtmMax := Mod1DataArray[Mod1Tiers].minHi
				TopMin := Mod1DataArray[Mod1Tiers].maxLo
				TopMax := Mod1DataArray[Mod1Tiers].maxHi
				
				result[1] := FormatDoubleRanges(BtmMin, BtmMax, TopMin, TopMax)
				result[2] := Mod1DataArray[Mod1Tiers].ilvl
				result[5] := NumFormatPointFiveOrInt((BtmMin + TopMin)/2) "-" StrPad(NumFormatPointFiveOrInt((BtmMax + TopMax)/2), StrLen(TopMin) + 1 + StrLen(TopMax) )
			}
			Else
			{
				result[1] := "n/a"
				result[2] := ""
			}
			
			BtmMin := Mod1DataArray[Mod1DataArray.MaxIndex()].minLo
			BtmMax := Mod1DataArray[1].minHi
			TopMin := Mod1DataArray[Mod1DataArray.MaxIndex()].maxLo
			TopMax := Mod1DataArray[1].maxHi
			
			If (Opts.OnlyCompactForTotalColumn and not Opts.UseCompactDoubleRanges){
				result[3] := FormatDoubleRanges(BtmMin, BtmMax, TopMin, TopMax, "compact")
			}
			Else{
				result[3] := FormatDoubleRanges(BtmMin, BtmMax, TopMin, TopMax)
			}
			
			result[4] := Mod1DataArray[1].ilvl
			result[7] := NumFormatPointFiveOrInt((BtmMin + TopMin)/2) "-" StrPad(NumFormatPointFiveOrInt((BtmMax + TopMax)/2), StrLen(TopMin) + 1 + StrLen(TopMax) )
		}
		Else
		{
			If (IsObject(Mod1Tiers))
			{
				BtmMin := Mod1DataArray[Mod1Tiers[2]].min
				BtmMax := Mod1DataArray[Mod1Tiers[2]].max
				TopMin := Mod1DataArray[Mod1Tiers[1]].min
				TopMax := Mod1DataArray[Mod1Tiers[1]].max
				
				result[1] := FormatMultiTierRange(BtmMin, BtmMax, TopMin, TopMax)
				result[2] := ""
			}
			Else If (IsNum(Mod1Tiers))
			{
				result[1] := Mod1DataArray[Mod1Tiers].values
				result[2] := Mod1DataArray[Mod1Tiers].ilvl
			}
			Else
			{
				result[1] := "n/a"
				result[2] := ""
			}
			
			result[3] := Mod1DataArray[Mod1DataArray.MaxIndex()].min "-" Mod1DataArray[1].max
			result[4] := Mod1DataArray[1].ilvl
		}
	}
	
	If (Mod1Tiers = 0 or Mod1Tiers[1] = 0 or Mod1Tiers[2] = 0 or Mod2Tier = 0){
		result[1] := "Legacy?"
	}
	return result
}


FormatValueRangesAndIlvl_MultiTiers(Value, Mod1DataArray, Mod2DataArray, Mod1TopTier, Mod1BtmTier, Mod2TopTier, Mod2BtmTier)
{
	If ( (Mod1TopTier = Mod1BtmTier) and (Mod2TopTier = Mod2BtmTier) )
	{
		result := []
		result[1] := (Mod1DataArray[Mod1TopTier].min + Mod2DataArray[Mod2BtmTier].min) "-" (Mod1DataArray[Mod1TopTier].max + Mod2DataArray[Mod2BtmTier].max)
		result[2] := ""
		result[3] := Mod1DataArray[Mod1DataArray.MaxIndex()].min + Mod2DataArray[Mod2DataArray.MaxIndex()].min "-" Mod1DataArray[1].max + Mod2DataArray[1].max
		result[4] := (Mod1DataArray[1].ilvl > Mod2DataArray[1].ilvl) ? Mod1DataArray[1].ilvl : Mod2DataArray[1].ilvl
		
		return result
	}
	
	; Concept:
	; Inner loop t: Start with Mod1TopTier and get worse (numerically higher).
	; Outer loop b: Start with Mod2BtmTier and get better (numerically lower).
	; Record lowest/highest range found where value still fits. The outer values take precedence here,
	;   so RangeTop is primarily defined by RangeTopMax (e.g. 100-109 is "higher" than 105-108) and RangeBtm by RangeBtmMin (e.g. 50-59 is "lower" than 51-54).
	
	RangeBtmMin := Mod1DataArray[Mod1TopTier].min + Mod2DataArray[Mod2BtmTier].min
	RangeBtmMax := Mod1DataArray[Mod1TopTier].max + Mod2DataArray[Mod2BtmTier].max
	RangeTopMin := RangeBtmMin
	RangeTopMax := RangeBtmMax
	
	; Start at t+1 because we assigned the t/b combination as the initial range values already.
	t := Mod1TopTier + 1
	b := Mod2BtmTier
	
	; We don't need to check t starting from Mod1TopTier each loop, we can use the best/first t from the previous b loop.
	t_RestartIndex := Mod1TopTier
	
	While(b >= Mod2TopTier)
	{
		While(t <= Mod1BtmTier)
		{
			TmpMin := Mod1DataArray[t].min + Mod2DataArray[b].min
			TmpMax := Mod1DataArray[t].max + Mod2DataArray[b].max
			; Increment t here because we might break/continue the loop just below.
			++t
			
			If (not( (TmpMin <= Value) and (Value <= TmpMax) ))
			{
				If (t_RestartIndex)
				{
					; Value not within Tmp-Range, but we have a t_RestartIndex, so we had matching Tmp-Ranges for this b value
					;   but the Tmp-Ranges are getting too low for "Value" now. Break t loop to check next b, start t at t_RestartIndex and set t_RestartIndex to 0 (see loop end).
					break
				}
				; Value not within Tmp-Range and we have no t_RestartIndex, so the Tmp-Range is still too high for "Value". Restart t loop with continue.
				Else continue
			}
			
			If (not(t_RestartIndex))
			{
				; Value is within Tmp-Range (because section above was passed) and we have no t_RestartIndex yet.
				; This means this is the first matching range found for this b. Record this t (and remove the increment from the loop start).
				t_RestartIndex := (t-1)
			}
			
			If (TmpMin <= RangeBtmMin)
			{
				If (TmpMin < RangeBtmMin)
				{
					RangeBtmMin := TmpMin
					RangeBtmMax := TmpMax
				}
				Else If (TmpMax < RangeBtmMax)
				{
					RangeBtmMax := TmpMax
				}
			}
			
			If (TmpMax >= RangeTopMax)
			{
				If (TmpMax > RangeTopMax)
				{
					RangeTopMax := TmpMax
					RangeTopMin := TmpMin
				}
				Else If (TmpMin > RangeTopMin)
				{
					RangeTopMin := TmpMin
				}
			}
		}
		
		--b
		t := t_RestartIndex
		t_RestartIndex := 0
	}
	
	result := []
	result[1] := FormatMultiTierRange(RangeBtmMin, RangeBtmMax, RangeTopMin, RangeTopMax)
	result[2] := ""
	result[3] := Mod1DataArray[Mod1DataArray.MaxIndex()].min + Mod2DataArray[Mod2DataArray.MaxIndex()].min "-" Mod1DataArray[1].max + Mod2DataArray[1].max
	result[4] := (Mod1DataArray[1].ilvl > Mod2DataArray[1].ilvl) ? Mod1DataArray[1].ilvl : Mod2DataArray[1].ilvl
	
	return result
}

SolveAffixes_HybBase_FlatDefLife(Keyname, LineNumDef1, LineNumDef2, LineNumLife, ValueDef1, ValueDef2, ValueLife, Filename_HybDualDef_Def1, Filename_HybDualDef_Def2, Filename_Life, Filename_HybDefLife_Def1, Filename_HybDefLife_Def2, Filename_HybDefLife_Life, ItemLevel)
{
	Global Itemdata
	Itemdata.UncertainAffixes[Keyname] := {}
	
	DualDef_D1_DataArray := ArrayFromDatafile(Filename_HybDualDef_Def1)
	DualDef_D2_DataArray := ArrayFromDatafile(Filename_HybDualDef_Def2)
	DefLife_D1_DataArray := ArrayFromDatafile(Filename_HybDefLife_Def1)
	DefLife_D2_DataArray := ArrayFromDatafile(Filename_HybDefLife_Def2)
	Life_DataArray		 := ArrayFromDatafile(Filename_Life)
	DefLife_Li_DataArray := ArrayFromDatafile(Filename_HybDefLife_Life)
	
	DualDef_D1_Tiers	:= LookupTierByValue(ValueDef1, DualDef_D1_DataArray, ItemLevel)
	DualDef_D2_Tiers	:= LookupTierByValue(ValueDef2, DualDef_D2_DataArray, ItemLevel)
	DefLife_D1_Tiers	:= LookupTierByValue(ValueDef1, DefLife_D1_DataArray, ItemLevel)
	DefLife_D2_Tiers	:= LookupTierByValue(ValueDef2, DefLife_D2_DataArray, ItemLevel)
	LifeTiers			:= LookupTierByValue(ValueLife, Life_DataArray, ItemLevel)
	DefLife_Li_Tiers	:= LookupTierByValue(ValueLife, DefLife_Li_DataArray, ItemLevel)
	
	Def1LifeTiers := SolveTiers_Hyb1Hyb2(ValueDef1, ValueDef2, ValueLife, DualDef_D1_DataArray, DefLife_D1_DataArray, DualDef_D2_DataArray, DefLife_Li_DataArray, ItemLevel)
	Def2LifeTiers := SolveTiers_Hyb1Hyb2(ValueDef2, ValueDef1, ValueLife, DualDef_D2_DataArray, DefLife_D2_DataArray, DualDef_D1_DataArray, DefLife_Li_DataArray, ItemLevel)
	
	
	/*           --------- Overlap1Case ---------    --------- Overlap2Case ---------
	ValueDef1 =          DefLife_D1 + DualDef_D1                         (DualDef_D1)
	ValueDef2 =                      (DualDef_D2)            DefLife_D2 + DualDef_D2
	ValueLife =   Life + DefLife_Li                   Life + DefLife_Li                  
	*/
	Overlap1Tiers := SolveTiers_Mod1Mod2Hyb(ValueDef1, ValueLife, DualDef_D1_DataArray, Life_DataArray, DefLife_D1_DataArray, DefLife_Li_DataArray, ItemLevel, True)
	Overlap2Tiers := SolveTiers_Mod1Mod2Hyb(ValueDef2, ValueLife, DualDef_D2_DataArray, Life_DataArray, DefLife_D2_DataArray, DefLife_Li_DataArray, ItemLevel, True)
	
	
	If (IsObject(Overlap1Tiers))
	{
		Overlap1TierCombinationArray := ReviseTierCombinationArray(Overlap1Tiers.TierCombinationArray, DualDef_D2_Tiers.Tier, 1)
		
		If (Overlap1TierCombinationArray = False){
			Overlap1Tiers := False
		}
		Else
		{
			NewOverlap1Tiers := GetTierRangesFromTierCombinationArray(Overlap1TierCombinationArray)
			
			Overlap1Tiers := {}
			Overlap1Tiers.Mod1Top := NewOverlap1Tiers[1][1]
			Overlap1Tiers.Mod1Btm := NewOverlap1Tiers[1][2]
			Overlap1Tiers.Mod2Top := NewOverlap1Tiers[2][1]
			Overlap1Tiers.Mod2Btm := NewOverlap1Tiers[2][2]
			Overlap1Tiers.HybTop  := NewOverlap1Tiers[3][1]
			Overlap1Tiers.HybBtm  := NewOverlap1Tiers[3][2]
		}
	}
	
	If (IsObject(Overlap2Tiers))
	{
		Overlap2TierCombinationArray := ReviseTierCombinationArray(Overlap2Tiers.TierCombinationArray, DualDef_D1_Tiers.Tier, 1)
		
		If (Overlap2TierCombinationArray = False){
			Overlap2Tiers := False
		}
		Else
		{
			NewOverlap2Tiers := GetTierRangesFromTierCombinationArray(Overlap2TierCombinationArray)
			
			Overlap2Tiers := {}
			Overlap2Tiers.Mod1Top := NewOverlap2Tiers[1][1]
			Overlap2Tiers.Mod1Btm := NewOverlap2Tiers[1][2]
			Overlap2Tiers.Mod2Top := NewOverlap2Tiers[2][1]
			Overlap2Tiers.Mod2Btm := NewOverlap2Tiers[2][2]
			Overlap2Tiers.HybTop  := NewOverlap2Tiers[3][1]
			Overlap2Tiers.HybBtm  := NewOverlap2Tiers[3][2]
		}
	}
	
	
	If (DualDef_D1_Tiers.Tier and DualDef_D2_Tiers.Tier and (DualDef_D1_Tiers.Tier = DualDef_D2_Tiers.Tier) and LifeTiers.Tier)
	{
		ValueRange1 := FormatValueRangesAndIlvl(DualDef_D1_DataArray, DualDef_D1_Tiers.Tier)
		LineTxt1    := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNumDef1].Text, "Hybrid Defence Prefix", ValueRange1, DualDef_D1_Tiers.Tier, False)
		
		ValueRange2 := FormatValueRangesAndIlvl(DualDef_D2_DataArray, DualDef_D2_Tiers.Tier)
		LineTxt2    := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNumDef2].Text, "Hybrid Defence Prefix", ValueRange2, DualDef_D2_Tiers.Tier, False)
		
		ValueRange3 := FormatValueRangesAndIlvl(Life_DataArray, LifeTiers.Tier)
		LineTxt3    := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNumLife].Text, "Prefix", ValueRange3, LifeTiers.Tier, False)
		
		Itemdata.UncertainAffixes[Keyname]["1_ModHyb"] := [2, 0, LineNumDef1, LineTxt1, LineNumDef2, LineTxt2, LineNumLife, LineTxt3]
	}
	
	If (IsObject(Def1LifeTiers) or IsObject(Def2LifeTiers))
	{
		If (IsObject(Def1LifeTiers))
		{
			ValueRange1 := FormatValueRangesAndIlvl(DualDef_D1_DataArray, Def1LifeTiers.Hyb1, DefLife_D1_DataArray, Def1LifeTiers.Hyb2)
			LineTxt1    := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNumDef1].Text, ["Hybrid Defence Prefix", "Hybrid Prefix"], ValueRange1, [Def1LifeTiers.Hyb1, Def1LifeTiers.Hyb2], False)
			
			ValueRange2 := FormatValueRangesAndIlvl(DualDef_D2_DataArray, Def1LifeTiers.Hyb1)
			LineTxt2    := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNumDef2].Text, "Hybrid Defence Prefix", ValueRange2, Def1LifeTiers.Hyb1, False)
			
			ValueRange3 := FormatValueRangesAndIlvl(DefLife_Li_DataArray, Def1LifeTiers.Hyb2)
			LineTxt3    := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNumLife].Text, "Hybrid Prefix", ValueRange3, Def1LifeTiers.Hyb2, False)
		}
		
		If (IsObject(Def2LifeTiers))
		{
			ValueRange4 := FormatValueRangesAndIlvl(DualDef_D1_DataArray, Def2LifeTiers.Hyb1)
			LineTxt4    := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNumDef2].Text, "Hybrid Defence Prefix", ValueRange4, Def2LifeTiers.Hyb1, False)
			
			ValueRange5 := FormatValueRangesAndIlvl(DualDef_D2_DataArray, Def2LifeTiers.Hyb1, DefLife_D2_DataArray, Def2LifeTiers.Hyb2)
			LineTxt5    := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNumDef1].Text, ["Hybrid Defence Prefix", "Hybrid Prefix"], ValueRange5, [Def2LifeTiers.Hyb1, Def2LifeTiers.Hyb2], False)
			
			ValueRange6 := FormatValueRangesAndIlvl(DefLife_Li_DataArray, Def2LifeTiers.Hyb2)
			LineTxt6    := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNumLife].Text, "Hybrid Prefix", ValueRange6, Def2LifeTiers.Hyb2, False)
		}
		
		If (IsObject(Def1LifeTiers) and IsObject(Def2LifeTiers))
		{
			Itemdata.UncertainAffixes[Keyname]["2_Hyb1Hyb2"] := [2, 0, LineNumDef1, LineTxt1, LineNumDef2, LineTxt2, LineNumLife, LineTxt3, LineNumDef1, LineTxt4, LineNumDef2, LineTxt5, LineNumLife, LineTxt6]
		}
		Else If (IsObject(Def1LifeTiers))
		{
			Itemdata.UncertainAffixes[Keyname]["2_Hyb1Hyb2"] := [2, 0, LineNumDef1, LineTxt1, LineNumDef2, LineTxt2, LineNumLife, LineTxt3]
		}
		Else If (IsObject(Def2LifeTiers))
		{
			Itemdata.UncertainAffixes[Keyname]["2_Hyb1Hyb2"] := [2, 0, LineNumDef1, LineTxt4, LineNumDef2, LineTxt5, LineNumLife, LineTxt6]
		}	
	}
	
	If (IsObject(Overlap1Tiers) or IsObject(Overlap2Tiers))
	{
		If (IsObject(Overlap1Tiers))
		{
			ValueRange1 := FormatValueRangesAndIlvl_MultiTiers(ValueDef1, DualDef_D1_DataArray, DefLife_D1_DataArray, Overlap1Tiers.Mod1Top, Overlap1Tiers.Mod1Btm, Overlap1Tiers.HybTop, Overlap1Tiers.HybBtm)
			LineTxt1    := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNumDef1].Text, ["Hybrid Defence Prefix", "Hybrid Prefix"], ValueRange1, [[Overlap1Tiers.Mod1Top, Overlap1Tiers.Mod1Btm], [Overlap1Tiers.HybTop, Overlap1Tiers.HybBtm]], False)
			
			ValueRange2 := FormatValueRangesAndIlvl(DualDef_D2_DataArray, DualDef_D2_Tiers.Tier)
			LineTxt2    := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNumDef2].Text, "Hybrid Defence Prefix", ValueRange2, DualDef_D2_Tiers.Tier, False)
			
			ValueRange3 := FormatValueRangesAndIlvl_MultiTiers(ValueLife, Life_DataArray, DefLife_Li_DataArray, Overlap1Tiers.Mod2Top, Overlap1Tiers.Mod2Btm, Overlap1Tiers.HybTop, Overlap1Tiers.HybBtm)
			LineTxt3    := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNumLife].Text, ["Prefix", "Hybrid Prefix"], ValueRange3, [[Overlap1Tiers.Mod2Top, Overlap1Tiers.Mod2Btm], [Overlap1Tiers.HybTop, Overlap1Tiers.HybBtm]], False)
		}
		
		If (IsObject(Overlap2Tiers))
		{
			ValueRange4 := FormatValueRangesAndIlvl(DualDef_D1_DataArray, DualDef_D1_Tiers.Tier)
			LineTxt4    := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNumDef1].Text, "Hybrid Defence Prefix", ValueRange4, DualDef_D1_Tiers.Tier, False)
			
			ValueRange5 := FormatValueRangesAndIlvl_MultiTiers(ValueDef2, DualDef_D2_DataArray, DefLife_D2_DataArray, Overlap2Tiers.Mod1Top, Overlap2Tiers.Mod1Btm, Overlap2Tiers.HybTop, Overlap2Tiers.HybBtm)
			LineTxt5    := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNumDef1].Text, ["Hybrid Defence Prefix", "Hybrid Prefix"], ValueRange5, [[Overlap2Tiers.Mod1Top, Overlap2Tiers.Mod1Btm], [Overlap2Tiers.HybTop, Overlap2Tiers.HybBtm]], False)
			
			ValueRange6 := FormatValueRangesAndIlvl_MultiTiers(ValueLife, Life_DataArray, DefLife_Li_DataArray, Overlap2Tiers.Mod2Top, Overlap2Tiers.Mod2Btm, Overlap2Tiers.HybTop, Overlap2Tiers.HybBtm)
			LineTxt6    := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNumLife].Text, ["Prefix", "Hybrid Prefix"], ValueRange6, [[Overlap2Tiers.Mod2Top, Overlap2Tiers.Mod2Btm], [Overlap2Tiers.HybTop, Overlap2Tiers.HybBtm]], False)
		}
		
		If (IsObject(Overlap1Tiers) and IsObject(Overlap2Tiers))
		{
			Itemdata.UncertainAffixes[Keyname]["3_ModHyb1Hyb2"] := [3, 0, LineNumDef1, LineTxt1, LineNumDef2, LineTxt2, LineNumLife, LineTxt3, LineNumDef1, LineTxt4, LineNumDef2, LineTxt5, LineNumLife, LineTxt6]
		}
		Else If (IsObject(Overlap1Tiers))
		{
			Itemdata.UncertainAffixes[Keyname]["3_ModHyb1Hyb2"] := [3, 0, LineNumDef1, LineTxt1, LineNumDef2, LineTxt2, LineNumLife, LineTxt3]
		}
		Else If (IsObject(Overlap2Tiers))
		{
			Itemdata.UncertainAffixes[Keyname]["3_ModHyb1Hyb2"] := [3, 0, LineNumDef1, LineTxt4, LineNumDef2, LineTxt5, LineNumLife, LineTxt6]
		}	
	}
}

SolveAffixes_Mod1Mod2Hyb(Keyname, LineNum1, LineNum2, Value1, Value2, Mod1Type, Mod2Type, HybType, Filename1, Filename2, FilenameHyb1, FilenameHyb2, ItemLevel)
{
	Global Itemdata
	Itemdata.UncertainAffixes[Keyname] := {}
	
	Mod1DataArray := ArrayFromDatafile(Filename1)
	Mod2DataArray := ArrayFromDatafile(Filename2)
	Hyb1DataArray := ArrayFromDatafile(FilenameHyb1)
	Hyb2DataArray := ArrayFromDatafile(FilenameHyb2)
	
	Mod1Tiers := LookupTierByValue(Value1, Mod1DataArray, ItemLevel)
	Mod2Tiers := LookupTierByValue(Value2, Mod2DataArray, ItemLevel)
	Hyb1Tiers := LookupTierByValue(Value1, Hyb1DataArray, ItemLevel)
	Hyb2Tiers := LookupTierByValue(Value2, Hyb2DataArray, ItemLevel)
	
	Mod1HybTiers := SolveTiers_ModHyb(Value1, Value2, Mod1DataArray, Hyb1DataArray, Hyb2DataArray, ItemLevel)
	Mod2HybTiers := SolveTiers_ModHyb(Value2, Value1, Mod2DataArray, Hyb2DataArray, Hyb1DataArray, ItemLevel)
	
	Mod1Mod2HybTiers := SolveTiers_Mod1Mod2Hyb(Value1, Value2, Mod1DataArray, Mod2DataArray, Hyb1DataArray, Hyb2DataArray, ItemLevel)
	
	
	If (Mod1Tiers.Tier and Mod2Tiers.Tier)
	{
		PrefixCount := 0
		SuffixCount := 0
		PrefixCount += (Mod1Type ~= "Prefix") ? 1 : 0
		PrefixCount += (Mod2Type ~= "Prefix") ? 1 : 0
		SuffixCount += (Mod1Type ~= "Suffix") ? 1 : 0
		SuffixCount += (Mod2Type ~= "Suffix") ? 1 : 0
		
		ValueRange1 := FormatValueRangesAndIlvl(Mod1DataArray, Mod1Tiers.Tier)
		LineTxt1 := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNum1].Text, Mod1Type, ValueRange1, Mod1Tiers.Tier, False)
		
		ValueRange2 := FormatValueRangesAndIlvl(Mod2DataArray, Mod2Tiers.Tier)
		LineTxt2 := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNum2].Text, Mod2Type, ValueRange2, Mod2Tiers.Tier, False)
		
		Itemdata.UncertainAffixes[Keyname]["1_Mod1Mod2"] := [PrefixCount, SuffixCount, LineNum1, LineTxt1, LineNum2, LineTxt2]
	}
	
	If (Hyb1Tiers.Tier and Hyb2Tiers.Tier and (Hyb1Tiers.Tier = Hyb2Tiers.Tier))
	{
		PrefixCount := 0
		SuffixCount := 0
		PrefixCount += (HybType ~= "Hybrid Prefix") ? 1 : 0
		SuffixCount += (HybType ~= "Hybrid Suffix") ? 1 : 0
		
		ValueRange1 := FormatValueRangesAndIlvl(Hyb1DataArray, Hyb1Tiers.Tier)
		LineTxt1 := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNum1].Text, HybType, ValueRange1, Hyb1Tiers.Tier, False)
		
		ValueRange2 := FormatValueRangesAndIlvl(Hyb2DataArray, Hyb2Tiers.Tier)
		LineTxt2 := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNum2].Text, HybType, ValueRange2, Hyb2Tiers.Tier, False)
		
		Itemdata.UncertainAffixes[Keyname]["2_OnlyHyb"] := [PrefixCount, SuffixCount, LineNum1, LineTxt1, LineNum2, LineTxt2]
	}
	
	If (IsObject(Mod1HybTiers))
	{
		PrefixCount := 0
		SuffixCount := 0
		PrefixCount += (Mod1Type ~= "Prefix") ? 1 : 0
		PrefixCount += (HybType ~= "Hybrid Prefix") ? 1 : 0
		SuffixCount += (Mod1Type ~= "Suffix") ? 1 : 0
		SuffixCount += (HybType ~= "Hybrid Suffix") ? 1 : 0
		
		ValueRange1 := FormatValueRangesAndIlvl(Mod1DataArray, [Mod1HybTiers.ModTop, Mod1HybTiers.ModBtm], Hyb1DataArray, Mod1HybTiers.Hyb)
		LineTxt1 := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNum1].Text, [Mod1Type, HybType], ValueRange1, [[Mod1HybTiers.ModTop, Mod1HybTiers.ModBtm], Mod1HybTiers.Hyb], False)
		
		ValueRange2 := FormatValueRangesAndIlvl(Hyb2DataArray, Hyb2Tiers.Tier)
		LineTxt2 := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNum2].Text, HybType, ValueRange2, Mod1HybTiers.Hyb, False)
		
		Itemdata.UncertainAffixes[Keyname]["3_Mod1Hyb"] := [PrefixCount, SuffixCount, LineNum1, LineTxt1, LineNum2, LineTxt2]
	}
	
	If (IsObject(Mod2HybTiers))
	{
		PrefixCount := 0
		SuffixCount := 0
		PrefixCount += (Mod2Type ~= "Prefix") ? 1 : 0
		PrefixCount += (HybType ~= "Hybrid Prefix") ? 1 : 0
		SuffixCount += (Mod2Type ~= "Suffix") ? 1 : 0
		SuffixCount += (HybType ~= "Hybrid Suffix") ? 1 : 0
		
		ValueRange1 := FormatValueRangesAndIlvl(Hyb1DataArray, Hyb1Tiers.Tier)
		LineTxt1 := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNum1].Text, HybType, ValueRange1, Mod2HybTiers.Hyb, False)
		
		ValueRange2 := FormatValueRangesAndIlvl(Mod2DataArray, [Mod2HybTiers.ModTop, Mod2HybTiers.ModBtm], Hyb2DataArray, Mod2HybTiers.Hyb)
		LineTxt2 := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNum2].Text, [Mod2Type, HybType], ValueRange2, [[Mod2HybTiers.ModTop, Mod2HybTiers.ModBtm], Mod2HybTiers.Hyb], False)
		
		Itemdata.UncertainAffixes[Keyname]["4_Mod2Hyb"] := [PrefixCount, SuffixCount, LineNum1, LineTxt1, LineNum2, LineTxt2]
	}
	
	If (IsObject(Mod1Mod2HybTiers))
	{
		PrefixCount := 0
		SuffixCount := 0
		PrefixCount += (Mod1Type ~= "Prefix") ? 1 : 0
		PrefixCount += (Mod2Type ~= "Prefix") ? 1 : 0
		PrefixCount += (HybType ~= "Hybrid Prefix") ? 1 : 0
		SuffixCount += (Mod1Type ~= "Suffix") ? 1 : 0
		SuffixCount += (Mod2Type ~= "Suffix") ? 1 : 0
		SuffixCount += (HybType ~= "Hybrid Suffix") ? 1 : 0
		
		ValueRange1 := FormatValueRangesAndIlvl_MultiTiers(Value1, Mod1DataArray, Hyb1DataArray, Mod1Mod2HybTiers.Mod1Top, Mod1Mod2HybTiers.Mod1Btm, Mod1Mod2HybTiers.HybTop, Mod1Mod2HybTiers.HybBtm)
		LineTxt1 := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNum1].Text, [Mod1Type, HybType], ValueRange1, [[Mod1Mod2HybTiers.Mod1Top, Mod1Mod2HybTiers.Mod1Btm], [Mod1Mod2HybTiers.HybTop, Mod1Mod2HybTiers.HybBtm]], False)
		
		ValueRange2 := FormatValueRangesAndIlvl_MultiTiers(Value2, Mod2DataArray, Hyb2DataArray, Mod1Mod2HybTiers.Mod2Top, Mod1Mod2HybTiers.Mod2Btm, Mod1Mod2HybTiers.HybTop, Mod1Mod2HybTiers.HybBtm)
		LineTxt2 := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNum2].Text, [Mod2Type, HybType], ValueRange2, [[Mod1Mod2HybTiers.Mod2Top, Mod1Mod2HybTiers.Mod2Btm], [Mod1Mod2HybTiers.HybTop, Mod1Mod2HybTiers.HybBtm]], False)
		
		Itemdata.UncertainAffixes[Keyname]["5_Mod1Mod2Hyb"] := [PrefixCount, SuffixCount, LineNum1, LineTxt1, LineNum2, LineTxt2]
	}
}

SolveAffixes_PreSuf(Keyname, LineNum, Value, Filename1, Filename2, ItemLevel)
{
	Global Itemdata
	Itemdata.UncertainAffixes[Keyname] := {}
	
	Mod1DataArray := ArrayFromDatafile(Filename1)
	Mod2DataArray := ArrayFromDatafile(Filename2)
	
	Mod1Tiers := LookupTierByValue(Value, Mod1DataArray, ItemLevel)
	Mod2Tiers := LookupTierByValue(Value, Mod2DataArray, ItemLevel)
	Mod1Mod2Tiers := SolveTiers_Mod1Mod2(Value, Mod1DataArray, Mod2DataArray, ItemLevel)
	
	If (Mod1Tiers.Tier)
	{
		ValueRange := FormatValueRangesAndIlvl(Mod1DataArray, Mod1Tiers.Tier)
		LineTxt := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNum].Text, "Prefix", ValueRange, Mod1Tiers.Tier, False)
		Itemdata.UncertainAffixes[Keyname]["1_Pre"] := [1, 0, LineNum, LineTxt]
	}
	
	If (Mod2Tiers.Tier)
	{
		ValueRange := FormatValueRangesAndIlvl(Mod2DataArray, Mod2Tiers.Tier)
		LineTxt := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNum].Text, "Suffix", ValueRange, Mod2Tiers.Tier, False)
		Itemdata.UncertainAffixes[Keyname]["2_Suf"] := [0, 1, LineNum, LineTxt]
	}
	
	If (IsObject(Mod1Mod2Tiers))
	{
		ValueRange := FormatValueRangesAndIlvl_MultiTiers(Value, Mod1DataArray, Mod2DataArray, Mod1Mod2Tiers.Mod1Top, Mod1Mod2Tiers.Mod1Btm, Mod1Mod2Tiers.Mod2Top, Mod1Mod2Tiers.Mod2Btm)
		LineTxt := MakeAffixDetailLine(Itemdata.AffixTextLines[LineNum].Text, ["Prefix", "Suffix"], ValueRange, [[Mod1Mod2Tiers.Mod1Top, Mod1Mod2Tiers.Mod1Btm] , [Mod1Mod2Tiers.Mod2Top, Mod1Mod2Tiers.Mod2Btm]], False)
		Itemdata.UncertainAffixes[Keyname]["3_PreSuf"] := [1, 1, LineNum, LineTxt]
	}
}

GetVeiledModCount(ItemDataAffixes, AffixType) {
	vCount := 0
	
	IfInString, ItemDataAffixes, Unidentified
	{
		Return ; Not interested in unidentified items
	}
	
	Loop, Parse, ItemDataAffixes, `n, `r 
	{
		If (RegExMatch(A_LoopField, "i)Veiled (Prefix|Suffix)", match)) {
			If (match1 = AffixType) {
				vCount := vCount + 1	
			}			
		}
	}
	
	Return vCount  
}

ParseAffixes(ItemDataAffixes, Item)
{
	Global Globals, Opts, AffixTotals, AffixLines, Itemdata
	
	ItemDataChunk	:= ItemDataAffixes
	
	IfInString, ItemDataChunk, Unidentified
	{
		Return ; Not interested in unidentified items
	}
	
	
	ItemBaseType		:= Item.BaseType
	ItemSubType		:= Item.SubType
	ItemGripType		:= Item.GripType
	ItemLevel			:= Item.Level
	ItemQuality		:= Item.Quality
	ItemIsHybridBase	:= Item.IsHybridBase
	ItemNamePlate		:= Itemdata.NamePlate
	
	; Reset the AffixLines "array" and other vars
	ResetAffixDetailVars()
	
	; Composition flags
	;
	; The pre-pass loop sets line numbers or markers for potentially ambiguous affixes,
	; so that the composition of these affixes can be checked later.
	
	If ( ! Item.IsJewel)
	{
		HasToArmour			:= 0
		HasToEvasion			:= 0
		HasToMaxES			:= 0
		HasToMaxLife			:= 0
		HasToArmourCraft		:= 0
		HasToEvasionCraft		:= 0
		HasToMaxESCraft		:= 0
		HasToMaxLifeCraft		:= 0
		
		HasIncrDefences 		:= 0
		HasIncrDefencesType 	:= ""
		HasIncrDefencesCraft 	:= 0
		HasIncrDefencesCraftType := ""
		HasStunBlockRecovery	:= 0
		HasChanceToBlockStrShield := 0
		; pure str shields ("tower shields") can have a hybrid prefix "#% increased Armour / +#% Chance to Block"
		; This means those fuckers can have 5 mods that combine:
		; Prefix:
		;   #% increased Armour
		;   #% increased Armour / #% increased Stun and Block Recovery
		;   #% increased Armour / +#% Chance to Block
		; Suffix:
		;   #% increased Stun and Block Recovery
		;   +#% Chance to Block
		
		HasToAccuracyRating		:= 0
		HasIncrPhysDmg			:= 0
		HasToAccuracyRatingCraft	:= 0
		HasIncrPhysDmgCraft		:= 0
		
		HasIncrRarity			:= 0
		HasIncrRarityCraft		:= 0
		
		HasMaxMana			:= 0
		HasMaxManaCraft		:= 0
		
		HasIncrSpellDamage		:= 0
		HasIncrFireDamage		:= 0
		HasIncrColdDamage		:= 0
		HasIncrLightningDamage	:= 0
		HasIncrSpellDamageCraft		:= 0
		HasIncrFireDamageCraft		:= 0
		HasIncrColdDamageCraft		:= 0
		HasIncrLightningDamageCraft	:= 0
		
		HasIncrSpellDamagePrefix	:= 0
		HasIncrSpellOrElePrefix	:= 0
		
		HasMultipleCrafted		:= 0
		HasLastLineNumber		:= 0
		
		; these two for jewels
		HasIncreasedAccuracyRating   := 0
		HasIncreasedGlobalCritChance := 0
		
		
		; --- PRE-PASS ---
		Loop, Parse, ItemDataChunk, `n, `r
		{			
			LoopField := RegExReplace(Trim(A_LoopField), "i) \(fractured|crafted|enchant\)$")
			If StrLen(LoopField) = 0
			{
				Continue ; Not interested in blank lines
			}
			
			Itemdata.AffixTextLines.Push( {"Text":LoopField, "Value":GetActualValue(LoopField)} )
			; AffixTextLines[1].Text stores the full text of the first line (yes, with index 1 and not 0)
			; AffixTextLines[1].Value stores just the extracted value
			
			++HasLastLineNumber		; Counts the affix text lines so that the last line can be checked for being a craft
			
			IfInString, LoopField, to Armour
			{
				If (HasToArmour){
					HasToArmourCraft := A_Index
				}Else{
					HasToArmour := A_Index
				}
				Continue
			}
			IfInString, LoopField, to Evasion Rating
			{
				If (HasToEvasion){
					HasToEvasionCraft := A_Index
				}Else{
					HasToEvasion := A_Index
				}
				Continue
			}
			IfInString, LoopField, to maximum Energy Shield
			{
				If (HasToMaxES){
					HasToMaxESCraft := A_Index
				}Else{
					HasToMaxES := A_Index
				}
				Continue
			}
			IfInString, LoopField, to maximum Life
			{
				If (HasToMaxLife){
					HasToMaxLifeCraft := A_Index
				}Else{
					HasToMaxLife := A_Index
				}
				Continue
			}
			IfInString, LoopField, increased Armour and Evasion	; it's indeed "Evasion" and not "Evasion Rating" here
			{
				If (HasIncrDefences){
					HasIncrDefencesCraftType := "Defences_HybridBase"
					HasIncrDefencesCraft := A_Index
				}Else{
					HasIncrDefencesType := "Defences_HybridBase"
					HasIncrDefences := A_Index
				}
				Continue
			}
			IfInString, LoopField, increased Armour and Energy Shield
			{
				If (HasIncrDefences){
					HasIncrDefencesCraftType := "Defences_HybridBase"
					HasIncrDefencesCraft := A_Index
				}Else{
					HasIncrDefencesType := "Defences_HybridBase"
					HasIncrDefences := A_Index
				}
				Continue
			}
			IfInString, LoopField, increased Evasion and Energy Shield	; again "Evasion" and not "Evasion Rating"
			{
				If (HasIncrDefences){
					HasIncrDefencesCraftType := "Defences_HybridBase"
					HasIncrDefencesCraft := A_Index
				}Else{
					HasIncrDefencesType := "Defences_HybridBase"
					HasIncrDefences := A_Index
				}
				Continue
			}
			IfInString, LoopField, increased Armour
			{
				If (HasIncrDefences){
					HasIncrDefencesCraftType := "Armour"
					HasIncrDefencesCraft := A_Index
				}Else{
					HasIncrDefencesType := "Armour"
					HasIncrDefences := A_Index
				}
				Continue
			}
			IfInString, LoopField, increased Evasion Rating
			{
				If (HasIncrDefences){
					HasIncrDefencesCraftType := "Evasion"
					HasIncrDefencesCraft := A_Index
				}Else{
					HasIncrDefencesType := "Evasion"
					HasIncrDefences := A_Index
				}
				Continue
			}
			IfInString, LoopField, increased Energy Shield
			{
				If (HasIncrDefences){
					HasIncrDefencesCraftType := "EnergyShield"
					HasIncrDefencesCraft := A_Index
				}Else{
					HasIncrDefencesType := "EnergyShield"
					HasIncrDefences := A_Index
				}
				Continue
			}
			IfInString, LoopField, increased Stun and Block Recovery
			{
				HasStunBlockRecovery := A_Index
				Continue
			}
			IfInString, LoopField, Chance to Block
			{
				IfInString, ItemNamePlate, Tower Shield
				{
					HasChanceToBlockStrShield := A_Index
				}
				Continue
			}
			IfInString, LoopField, to Accuracy Rating
			{
				If (HasToAccuracyRating){
					HasToAccuracyRatingCraft := A_Index
				}Else{
					HasToAccuracyRating := A_Index
				}
				Continue
			}
			IfInString, LoopField, increased Physical Damage
			{
				If (HasIncrPhysDmg){
					HasIncrPhysDmgCraft := A_Index
				}Else{
					HasIncrPhysDmg := A_Index
				}
				Continue
			}
			IfInString, LoopField, increased Rarity of Items found
			{
				If (HasIncrRarity){
					HasIncrRarityCraft := A_Index
				}Else{
					HasIncrRarity := A_Index
				}
				Continue
			}
			IfInString, LoopField, to maximum Mana
			{
				If (HasMaxMana){
					HasMaxManaCraft := A_Index
				}Else{
					HasMaxMana := A_Index
				}
				Continue
			}
			IfInString, LoopField, increased Light Radius
			{
				HasIncrLightRadius := A_Index
				Continue
			}
			IfInString, LoopField, increased Spell Damage
			{
				If (HasIncrSpellDamage){
					HasIncrSpellDamageCraft := A_Index
					HasIncrSpellDamagePrefix := A_Index
					HasIncrSpellOrElePrefix := A_Index
				}Else{
					HasIncrSpellDamage := A_Index
				}
				
				If ((ItemGripType = "1H") or (ItemSubType = "Shield")){
					Found := LookupTierByValue(GetActualValue(LoopField), ArrayFromDatafile("data\SpellDamage_MaxMana_1H.txt"), ItemLevel).Tier
				}Else{
					Found := LookupTierByValue(GetActualValue(LoopField), ArrayFromDatafile("data\SpellDamage_MaxMana_Staff.txt"), ItemLevel).Tier
				}
				If ( ! Found){
					HasIncrSpellDamagePrefix := A_Index
					HasIncrSpellOrElePrefix := A_Index
				}
				Continue
			}
			IfInString, LoopField, increased Fire Damage
			{
				If (HasIncrFireDamage){
					HasIncrFireDamageCraft := A_Index
					HasIncrFireDamagePrefix := HasIncrFireDamage
					HasIncrSpellOrElePrefix := HasIncrFireDamagePrefix
				}Else{
					HasIncrFireDamage := A_Index
				}
				
				If ( ! LookupTierByValue(GetActualValue(LoopField), ArrayFromDatafile("data\IncrFireDamage_Suffix_Weapon.txt"), ItemLevel).Tier )
				{
					HasIncrFireDamagePrefix := A_Index
					HasIncrSpellOrElePrefix := A_Index
				}
				Continue
			}
			IfInString, LoopField, increased Cold Damage
			{
				If (HasIncrColdDamage){
					HasIncrColdDamageCraft := A_Index
					HasIncrColdDamagePrefix := HasIncrColdDamage
					HasIncrSpellOrElePrefix := HasIncrColdDamagePrefix
				}Else{
					HasIncrColdDamage := A_Index
				}
				
				If ( ! LookupTierByValue(GetActualValue(LoopField), ArrayFromDatafile("data\IncrColdDamage_Suffix_Weapon.txt"), ItemLevel).Tier )
				{
					HasIncrColdDamagePrefix := A_Index
					HasIncrSpellOrElePrefix := A_Index
				}
				Continue
			}
			IfInString, LoopField, increased Lightning Damage
			{
				If (HasIncrLightningDamage){
					HasIncrLightningDamageCraft := A_Index
					HasIncrLightningDamagePrefix := HasIncrLightningDamage
					HasIncrSpellOrElePrefix := HasIncrLightningDamagePrefix
				}Else{
					HasIncrLightningDamage := A_Index
				}
				
				If ( ! LookupTierByValue(GetActualValue(LoopField), ArrayFromDatafile("data\IncrLightningDamage_Suffix_Weapon.txt"), ItemLevel).Tier )
				{
					HasIncrLightningDamagePrefix := A_Index
					HasIncrSpellOrElePrefix := A_Index
				}
				Continue
			}
			IfInString, LoopField, Can have multiple Crafted Mods
			{
				HasMultipleCrafted := A_Index
				Itemdata.HasMultipleCrafted := A_Index
				Continue
			}
		}
	}
	Else
	{
		; Jewels get their own Pre-Pass
		
		; --- PRE-PASS ---
		Loop, Parse, ItemDataChunk, `n, `r
		{
			LoopField := RegExReplace(Trim(A_LoopField), "i) \(fractured|crafted|enchant\)$")
			If StrLen(LoopField) = 0
			{
				Continue ; Not interested in blank lines
			}
			
			Itemdata.AffixTextLines.Push( {"Text":LoopField, "Value":GetActualValue(LoopField)} )
			++HasLastLineNumber
			
			IfInString, LoopField, increased Accuracy Rating
			{
				If (Item.SubType = "Viridian Jewel" or Item.SubType = "Prismatic Jewel")
				{
					HasIncreasedAccuracyRating := A_Index
					Continue
				}
			}
			
			IfInString, LoopField, increased Global Critical Strike Chance
			{
				If (Item.SubType = "Viridian Jewel" or Item.SubType = "Prismatic Jewel" )
				{
					HasIncreasedGlobalCritChance := A_Index
					Continue
				}
			}
		}
	}
	
	Itemdata.LastAffixLineNumber := HasLastLineNumber
	
	; Prepare AffixLines. If a line isn't matched, it will later be recognized as unmatched because the entry is empty instead of undefined.
	Loop, %HasLastLineNumber%
	{
		AffixLines.Set(A_Index, "")
	}
	
	
	; --- SIMPLE AFFIXES ---
	
	Loop, Parse, ItemDataChunk, `n, `r
	{		
		LoopField := RegExReplace(Trim(A_LoopField), "i) \(fractured|crafted\)$")
		If StrLen(LoopField) = 0
		{
			Continue ; Not interested in blank lines
		}
		IfInString, ItemDataChunk, Unidentified
		{
			Break ; Not interested in unidentified items
		}
		
		CurrValue := GetActualValue(LoopField)
		CurrTier := 0
		
		
		; --- SIMPLE JEWEL AFFIXES ---
		
		If (Item.IsJewel)
		{
			If (Item.IsAbyssJewel)
			{
				If RegExMatch(LoopField, "Adds \d+? to \d+? (Physical|Fire|Cold|Lightning|Chaos) Damage")
				{
					If RegExMatch(LoopField, "Adds \d+? to \d+? (Physical|Fire|Cold|Lightning|Chaos) Damage to \w+ Attacks", match)
					{
						LookupAffixAndSetInfoLine("data\abyss_jewel\Adds" match1 "DamageToWeaponTypeAttacks.txt", "Prefix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Adds \d+? to \d+? (Physical|Fire|Cold|Lightning|Chaos) Damage to Attacks", match)
					{
						LookupAffixAndSetInfoLine("data\abyss_jewel\Adds" match1 "DamageToAttacks.txt", "Suffix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Adds \d+? to \d+? (Physical|Fire|Cold|Lightning|Chaos) Damage to Spells while", match)
					{
						LookupAffixAndSetInfoLine("data\abyss_jewel\Adds" match1 "DamageToSpellsWhile.txt", "Prefix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Adds \d+? to \d+? (Physical|Fire|Cold|Lightning|Chaos) Damage to Spells", match)
					{
						LookupAffixAndSetInfoLine("data\abyss_jewel\Adds" match1 "DamageToSpells.txt", "Suffix", ItemLevel, CurrValue)
						Continue
					}
				}
				
				IfInString, LoopField, to maximum Life
				{
					LookupAffixAndSetInfoLine("data\abyss_jewel\MaxLife.txt", "Prefix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, to maximum Mana
				{
					LookupAffixAndSetInfoLine("data\abyss_jewel\MaxMana.txt", "Prefix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, to Armour
				{
					LookupAffixAndSetInfoLine("data\abyss_jewel\ToArmour.txt", "Prefix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, to Evasion Rating
				{
					LookupAffixAndSetInfoLine("data\abyss_jewel\ToEvasionRating.txt", "Prefix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, to maximum Energy Shield
				{
					LookupAffixAndSetInfoLine("data\abyss_jewel\ToMaximumEnergyShield.txt", "Prefix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, Energy Shield Regenerated per second
				{
					LookupAffixAndSetInfoLine("data\abyss_jewel\EnergyShieldRegenerated.txt", "Prefix", ItemLevel, CurrValue)
					Continue
				}
				If RegExMatch(LoopField, "^[\d\.]+ Life Regenerated per second$")
				{
					LookupAffixAndSetInfoLine("data\abyss_jewel\LifeRegenerated.txt", "Prefix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, Mana Regenerated per second
				{
					LookupAffixAndSetInfoLine("data\abyss_jewel\ManaRegenerated.txt", "Prefix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, increased Damage over Time while
				{
					LookupAffixAndSetInfoLine(["1|10-14"], "Prefix", ItemLevel, CurrValue)
					Continue
				}
				
				IfInString, LoopField, Minion
				{
					If RegExMatch(LoopField, "Minions deal \d+? to \d+? additional (Physical|Fire|Cold|Lightning|Chaos) Damage", match)
					{
						LookupAffixAndSetInfoLine("data\abyss_jewel\MinionsDealAdditional" match1 "Damage.txt", "Prefix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Minions Regenerate \d+? Life per second")
					{
						LookupAffixAndSetInfoLine("data\abyss_jewel\MinionsRegenerateLife.txt", "Prefix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Minions have \d+% chance to Blind on Hit with Attacks")
					{
						LookupAffixAndSetInfoLine(["32|3-4","65|5-6"], "Suffix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Minions have \d+% chance to Taunt on Hit with Attacks")
					{
						LookupAffixAndSetInfoLine(["32|3-5","65|6-8"], "Suffix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Minions have \d+% chance to Hinder Enemies on Hit with Spells, with 30% reduced Movement Speed")
					{
						LookupAffixAndSetInfoLine(["32|3-5","65|6-8"], "Suffix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Minions deal \d+% increased Damage against Abyssal Monsters")
					{
						LookupAffixAndSetInfoLine(["1|30-40"], "Suffix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Minions have \d+% increased (Attack|Cast) Speed")
					{
						LookupAffixAndSetInfoLine(["1|4-6"], "Hybrid Suffix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Minions Regenerate \d+% Life per second")
					{
						LookupAffixAndSetInfoLine(["1|0.4-0.8"], "Suffix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Minions Leech [\d\.]+% of Damage as Life")
					{
						LookupAffixAndSetInfoLine(["1|0.3-0.5"], "Suffix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Minions have \d+% increased Movement Speed")
					{
						LookupAffixAndSetInfoLine(["1|6-10"], "Suffix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Minions have \d+% increased maximum Life")
					{
						LookupAffixAndSetInfoLine(["1|8-12"], "Suffix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Minions have +\d+% to all Elemental Resistances")
					{
						LookupAffixAndSetInfoLine(["1|6-10"], "Suffix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Minions have +\d+% to Chaos Resistance")
					{
						LookupAffixAndSetInfoLine(["1|7-12"], "Suffix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "Minions have \d+% increased Attack and Cast Speed if you or your Minions have Killed Recently")
					{
						LookupAffixAndSetInfoLine(["1|6-8"], "Suffix", ItemLevel, CurrValue)
						Continue
					}
					If RegExMatch(LoopField, "increased Minion Damage if you've used a Minion Skill Recently")
					{
						LookupAffixAndSetInfoLine(["1|15-20"], "Suffix", ItemLevel, CurrValue)
						Continue
					}					
				}
				
				IfInString, LoopField, to Accuracy Rating
				{
					LookupAffixAndSetInfoLine("data\abyss_jewel\AccuracyRating.txt", "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, chance to Blind Enemies on Hit with Attacks
				{
					LookupAffixAndSetInfoLine(["32|3-4","65|5-6"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, chance to Taunt Enemies on Hit with Attacks
				{
					LookupAffixAndSetInfoLine(["32|3-5","65|6-8"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				If RegExMatch(LoopField, "chance to Hinder Enemies on Hit with Spells, with 30% reduced Movement Speed")
				{
					LookupAffixAndSetInfoLine(["32|3-5","65|6-8"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				If RegExMatch(LoopField, "chance to Avoid being (Ignited|Shocked)")
				{
					LookupAffixAndSetInfoLine(["1|6-8","30|9-10"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				If RegExMatch(LoopField, "chance to Avoid being (Chilled|Frozen)")
				{
					LookupAffixAndSetInfoLine(["1|6-8","30|9-10"], "Hybrid Suffix", ItemLevel, CurrValue)
					Continue
				}
				If RegExMatch(LoopField, "chance to [Aa]void (being Poisoned|Bleeding)")
				{
					LookupAffixAndSetInfoLine(["20|6-8","50|9-10"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, chance to Avoid being Stunned
				{
					LookupAffixAndSetInfoLine(["1|6-8","20|9-10"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, increased Damage against Abyssal Monsters
				{
					LookupAffixAndSetInfoLine(["1|30-40"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, additional Physical Damage Reduction against Abyssal Monsters
				{
					LookupAffixAndSetInfoLine(["1|4-6"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				If RegExMatch(LoopField, "increased Effect of (Chill|Shock)")
				{
					LookupAffixAndSetInfoLine(["30|6-10"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, chance to Block Spells if you were Damaged by a Hit Recently
				{
					LookupAffixAndSetInfoLine(["1|2"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, additional Physical Damage Reduction if you weren't Damaged by a Hit Recently
				{
					LookupAffixAndSetInfoLine(["1|2"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, increased Movement Speed if you haven't taken Damage Recently
				{
					LookupAffixAndSetInfoLine(["1|3-4"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, increased Damage if you've Killed Recently
				{
					LookupAffixAndSetInfoLine(["1|10-20"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, to Critical Strike Multiplier if you've Killed Recently
				{
					LookupAffixAndSetInfoLine(["25|8-14"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, increased Armour if you haven't Killed Recently
				{
					LookupAffixAndSetInfoLine(["1|20-30"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, increased Accuracy Rating if you haven't Killed Recently
				{
					LookupAffixAndSetInfoLine(["1|20-30"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				If RegExMatch(LoopField, "Damage Penetrates \d+% Elemental Resistance if you haven't Killed Recently")
				{
					LookupAffixAndSetInfoLine(["1|2"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, increased Evasion Rating while moving
				{
					LookupAffixAndSetInfoLine(["1|25-35"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, increased Mana Regeneration Rate while moving
				{
					LookupAffixAndSetInfoLine(["1|20-25"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, of Life Regenerated per second while moving
				{
					LookupAffixAndSetInfoLine(["1|0.5-1"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				If RegExMatch(LoopField, "Gain \d+% of Physical Damage as Extra Fire Damage if you've dealt a Critical Strike Recently")
				{
					LookupAffixAndSetInfoLine(["40|2-4"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, increased Attack Speed if you've dealt a Critical Strike Recently
				{
					LookupAffixAndSetInfoLine(["25|6-8"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, increased Cast Speed if you've dealt a Critical Strike Recently
				{
					LookupAffixAndSetInfoLine(["25|5-7"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, increased Critical Strike Chance if you haven't dealt a Critical Strike Recently
				{
					LookupAffixAndSetInfoLine(["1|20-30"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, chance to Dodge Attacks and Spells if you've been Hit Recently
				{
					LookupAffixAndSetInfoLine(["1|2"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, increased Movement Speed if you've Killed Recently
				{
					LookupAffixAndSetInfoLine(["1|2-4"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, additional Block Chance if you were Damaged by a Hit Recently
				{
					LookupAffixAndSetInfoLine(["1|2"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, chance to gain Onslaught for 4 seconds on Kill
				{
					LookupAffixAndSetInfoLine(["10|3-5","50|6-8"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, chance to gain Phasing for 4 seconds on Kill
				{
					LookupAffixAndSetInfoLine(["10|3-5","50|6-8"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
				IfInString, LoopField, chance to gain Unholy Might for 4 seconds on Melee Kill
				{
					LookupAffixAndSetInfoLine(["40|2-3","80|4-5"], "Suffix", ItemLevel, CurrValue)
					Continue
				}
			}
			
			IfInString, LoopField, increased Area Damage
			{
				LookupAffixAndSetInfoLine("data\jewel\AreaDamage.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Attack and Cast Speed
			{
				LookupAffixAndSetInfoLine("data\jewel\AttackAndCastSpeed.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, ".*increased Attack Speed with (One|Two) Handed Melee Weapons")
			{
				LookupAffixAndSetInfoLine("data\jewel\AttackSpeedWith1H2HMelee.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Attack Speed while holding a Shield
			{
				LookupAffixAndSetInfoLine("data\jewel\AttackSpeedWhileHoldingShield.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Attack Speed while Dual Wielding
			{
				LookupAffixAndSetInfoLine("data\jewel\AttackSpeedWhileDualWielding.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, ".*increased Attack Speed with (Axes|Bows|Claws|Daggers|Maces|Staves|Swords|Wands)")
			{
				LookupAffixAndSetInfoLine("data\jewel\AttackSpeedWithWeapontype.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			
			; Pure Attack Speed must be checked last if RegEx line end isn't used
			If RegExMatch(LoopField, ".*increased Attack Speed$")
			{
				LookupAffixAndSetInfoLine("data\jewel\AttackSpeed_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			
			IfInString, LoopField, increased Accuracy Rating
			{
				If (Item.SubType = "Cobalt Jewel" or Item.SubType = "Crimson Jewel")
				{
					; Cobalt and Crimson jewels can't get the combined increased accuracy/crit chance affix
					LookupAffixAndSetInfoLine("data\jewel\IncrAccuracyRating_Jewels.txt", "Suffix", ItemLevel, CurrValue)
					Continue
				}
				Else
				{
					; increased Accuracy Rating on Viridian and Prismatic jewels is a complex affix and handled later
					Continue
				}
			}
			
			IfInString, LoopField, to all Attributes
			{
				LookupAffixAndSetInfoLine("data\jewel\ToAllAttributes_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			
			If RegExMatch(LoopField, ".*to (Strength|Dexterity|Intelligence) and (Strength|Dexterity|Intelligence)")
			{
				LookupAffixAndSetInfoLine("data\jewel\To2Attributes_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, ".*to (Strength|Dexterity|Intelligence)")
			{
				LookupAffixAndSetInfoLine("data\jewel\To1Attribute_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, ".*increased Cast Speed (with|while) .*")
			{
				LookupAffixAndSetInfoLine("data\jewel\CastSpeedWithWhile.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			
			; pure Cast Speed must be checked last if RegEx line end isn't used
			If RegExMatch(LoopField, ".*increased Cast Speed$")
			{
				LookupAffixAndSetInfoLine("data\jewel\CastSpeed_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Critical Strike Chance for Spells
			{
				LookupAffixAndSetInfoLine("data\jewel\CritChanceSpells_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Melee Critical Strike Chance
			{
				LookupAffixAndSetInfoLine("data\jewel\MeleeCritChance.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Critical Strike Chance with Elemental Skills
			{
				LookupAffixAndSetInfoLine("data\jewel\CritChanceElementalSkills.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, ".*increased Critical Strike Chance with (Fire|Cold|Lightning) Skills")
			{
				LookupAffixAndSetInfoLine("data\jewel\CritChanceFireColdLightningSkills.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, ".*increased Critical Strike Chance with (One|Two) Handed Melee Weapons")
			{
				LookupAffixAndSetInfoLine("data\jewel\CritChanceWith1H2HMelee.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Weapon Critical Strike Chance while Dual Wielding
			{
				LookupAffixAndSetInfoLine("data\jewel\WeaponCritChanceDualWielding.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Global Critical Strike Chance
			{
				If not (Item.SubType = "Viridian Jewel" or Item.SubType = "Prismatic Jewel")
				{
					; Only Viridian and Prismatic jewels can get the combined increased accuracy/crit chance affix
					LookupAffixAndSetInfoLine("data\jewel\CritChanceGlobal_Jewels.txt", "Suffix", ItemLevel, CurrValue)
					Continue
				}
				Else
				{
					; Crit chance on Viridian and Prismatic Jewels is a complex affix that is handled later
					Continue
				}
			}
			IfInString, LoopField, to Melee Critical Strike Multiplier
			{
				LookupAffixAndSetInfoLine("data\jewel\CritMeleeMultiplier.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, to Critical Strike Multiplier for Spells
			{
				LookupAffixAndSetInfoLine("data\jewel\CritMultiplierSpells.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, to Critical Strike Multiplier with Elemental Skills
			{
				LookupAffixAndSetInfoLine("data\jewel\CritMultiplierElementalSkills.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, ".*to Critical Strike Multiplier with (Fire|Cold|Lightning) Skills")
			{
				LookupAffixAndSetInfoLine("data\jewel\CritMultiplierFireColdLightningSkills.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, ".*to Critical Strike Multiplier with (One|Two) Handed Melee Weapons")
			{
				LookupAffixAndSetInfoLine("data\jewel\CritMultiplierWith1H2HMelee.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, to Critical Strike Multiplier while Dual Wielding
			{
				LookupAffixAndSetInfoLine("data\jewel\CritMultiplierWhileDualWielding.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, Critical Strike Multiplier
			{
				LookupAffixAndSetInfoLine("data\jewel\CritMultiplierGlobal_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, chance to Ignite
			{
				LookupAffixAndSetInfoLine("data\jewel\ChanceToIgnite.txt", "Hybrid Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Ignite Duration on Enemies
			{
				LookupAffixAndSetInfoLine("data\jewel\IgniteDurationOnEnemies.txt", "Hybrid Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, chance to Freeze
			{
				LookupAffixAndSetInfoLine("data\jewel\ChanceToFreeze.txt", "Hybrid Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Freeze Duration on Enemies
			{
				LookupAffixAndSetInfoLine("data\jewel\FreezeDurationOnEnemies.txt", "Hybrid Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, chance to Shock
			{
				LookupAffixAndSetInfoLine("data\jewel\ChanceToShock.txt", "Hybrid Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Shock Duration on Enemies
			{
				LookupAffixAndSetInfoLine("data\jewel\ShockDurationOnEnemies.txt", "Hybrid Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, chance to Poison
			{
				LookupAffixAndSetInfoLine("data\jewel\ChanceToPoison.txt", "Hybrid Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Poison Duration on Enemies
			{
				LookupAffixAndSetInfoLine("data\jewel\PoisonDuration.txt", "Hybrid Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, chance to cause Bleeding
			{
				LookupAffixAndSetInfoLine("data\jewel\ChanceToBleed.txt", "Hybrid Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Bleed duration
			{
				LookupAffixAndSetInfoLine("data\jewel\BleedingDurationOnEnemies.txt", "Hybrid Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Burning Damage
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrBurningDamage.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Damage with Bleeding
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrBleedingDamage.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Damage with Poison
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrPoisonDamage.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, ".*increased (Fire|Cold|Lightning) Damage")
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrFireColdLightningDamage_Jewels.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, "Minions have .* Chance to Block")
			{
				LookupAffixAndSetInfoLine("data\jewel\MinionBlockChance.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, ".*(Chance to Block|Block Chance).*")
			{
				LookupAffixAndSetInfoLine("data\jewel\BlockChance_ChanceToBlock_Jewels.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Damage over Time
			{
				LookupAffixAndSetInfoLine("data\jewel\DamageOverTime.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, "Minions deal .* increased Damage")
			{
				LookupAffixAndSetInfoLine("data\jewel\MinionsDealIncrDamage.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, ".*increased Damage$")
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrDamage.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, chance to Knock Enemies Back on hit
			{
				LookupAffixAndSetInfoLine("data\jewel\KnockBackOnHit.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, Life gained for each Enemy hit by your Attacks
			{
				LookupAffixAndSetInfoLine("data\jewel\LifeOnHit_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, Energy Shield gained for each Enemy hit by your Attacks
			{
				LookupAffixAndSetInfoLine("data\jewel\ESOnHit.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, Mana gained for each Enemy hit by your Attacks
			{
				LookupAffixAndSetInfoLine("data\jewel\ManaOnHit.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, reduced Mana Cost of Skills
			{
				LookupAffixAndSetInfoLine("data\jewel\ReducedManaCost.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Mana Regeneration Rate
			{
				LookupAffixAndSetInfoLine("data\jewel\ManaRegen_Jewels.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Melee Damage
			{
				LookupAffixAndSetInfoLine("data\jewel\MeleeDamage.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Projectile Damage
			{
				LookupAffixAndSetInfoLine("data\jewel\ProjectileDamage.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Projectile Speed
			{
				LookupAffixAndSetInfoLine("data\jewel\ProjectileSpeed_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, to all Elemental Resistances
			{
				; "to all Elemental Resistances" matches multiple affixes
				If InStr(LoopField, "Minions have"){
					File := "data\jewel\ToAllResist_Jewels_Minions.txt"
				}
				Else If InStr(LoopField, "Totems gain"){
					File := "data\jewel\ToAllResist_Jewels_Totems.txt"
				}
				Else{
					File := "data\jewel\ToAllResist_Jewels.txt"
				}
				LookupAffixAndSetInfoLine(File, "Suffix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, ".*to (Fire|Cold|Lightning) and (Fire|Cold|Lightning) Resistances")
			{
				LookupAffixAndSetInfoLine("data\jewel\To2Resist_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, ".*to (Fire|Cold|Lightning) Resistance")
			{
				LookupAffixAndSetInfoLine("data\jewel\To1Resist_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, to Chaos Resistance
			{
				LookupAffixAndSetInfoLine("data\jewel\ToChaosResist_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Stun Duration on Enemies
			{
				LookupAffixAndSetInfoLine("data\jewel\StunDuration_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, ".*increased Physical Damage with (Axes|Bows|Claws|Daggers|Maces|Staves|Swords|Wands)")
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrPhysDamageWithWeapontype.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Melee Physical Damage while holding a Shield
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrMeleePhysDamageWhileHoldingShield.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Physical Weapon Damage while Dual Wielding
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrPhysWeaponDamageDualWielding.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			If RegExMatch(LoopField, ".*increased Physical Damage with (One|Two) Handed Melee Weapons")
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrPhysDamageWith1H2HMelee.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Global Physical Damage
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrPhysDamage_Jewels.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Totem Damage
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrTotemDamage.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Totem Life
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrTotemLife.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Trap Throwing Speed
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrTrapThrowingSpeed.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Trap Damage
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrTrapDamage.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Mine Laying Speed
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrMineLayingSpeed.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Mine Damage
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrMineDamage.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Chaos Damage
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrChaosDamage.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			If ( InStr(LoopField,"increased maximum Life"))
			{
				If InStr(LoopField,"Minions have")
				{
					FilePath := "data\jewel\MinionIncrMaximumLife.txt"
				}
				Else
				{
					FilePath := "data\jewel\IncrMaximumLife.txt"
				}
				LookupAffixAndSetInfoLine(FilePath, "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Armour
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrArmour_Jewels.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Evasion Rating
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrEvasion_Jewels.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Energy Shield Recharge Rate
			{
				LookupAffixAndSetInfoLine("data\jewel\EnergyShieldRechargeRate.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, faster start of Energy Shield Recharge
			{
				LookupAffixAndSetInfoLine("data\jewel\FasterStartOfEnergyShieldRecharge.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased maximum Energy Shield
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrMaxEnergyShield_Jewels.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, Physical Attack Damage Leeched as
			{
				LookupAffixAndSetInfoLine("data\jewel\PhysicalAttackDamageLeeched_Jewels.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Spell Damage while Dual Wielding
			{
				LookupAffixAndSetInfoLine("data\jewel\SpellDamageDualWielding_Jewels.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Spell Damage while holding a Shield
			{
				LookupAffixAndSetInfoLine("data\jewel\SpellDamageHoldingShield_Jewels.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Spell Damage while wielding a Staff
			{
				LookupAffixAndSetInfoLine("data\jewel\SpellDamageWieldingStaff_Jewels.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Spell Damage
			{
				LookupAffixAndSetInfoLine("data\jewel\SpellDamage_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased maximum Mana
			{
				LookupAffixAndSetInfoLine("data\jewel\IncrMaximumMana_Jewel.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Stun and Block Recovery
			{
				LookupAffixAndSetInfoLine("data\jewel\StunRecovery_Suffix_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Rarity
			{
				LookupAffixAndSetInfoLine("data\jewel\IIR_Suffix_Jewels.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
		} ; End of Jewel Affixes
		
		
		
		
		; Suffixes
		
		IfInString, LoopField, increased Attack Speed
		{
			If (ItemSubType = "Wand" or ItemSubType = "Bow"){
				File := "data\AttackSpeed_BowsAndWands.txt"
			}
			Else If (ItemBaseType = "Weapon"){
				File := "data\AttackSpeed_Weapons.txt"
			}
			Else If (ItemSubType = "Shield"){
				File := "data\AttackSpeed_Shield.txt"
			}
			Else{
				File := "data\AttackSpeed_ArmourAndItems.txt"
			}
			LookupAffixAndSetInfoLine(File, "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, to all Attributes
		{
			If (ItemSubType = "Amulet"){
				LookupAffixAndSetInfoLine("data\ToAllAttributes_Amulet.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			Else{
				LookupAffixAndSetInfoLine("data\ToAllAttributes.txt", "Suffix", ItemLevel, CurrValue)
				Continue	
			}
		}
		If RegExMatch(LoopField, ".*to (Strength|Dexterity|Intelligence)", match)
		{
			If ((match1 = "Strength" and ItemSubType = "Belt") or (match1 = "Dexterity" and (ItemSubType = "Gloves" or ItemSubType = "Quiver")) or (match1 = "Intelligence" and ItemSubType = "Helmet"))
			{
				LookupAffixAndSetInfoLine("data\To1Attribute_ilvl85.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			Else
			{
				LookupAffixAndSetInfoLine("data\To1Attribute.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
		}
		IfInString, LoopField, increased Cast Speed
		{
			If (ItemGripType = "1H"){
				; wands and scepters
				File := "data\CastSpeed_1H.txt"
			}
			Else If (ItemGripType = "2H"){
				; staves
				File := "data\CastSpeed_2H.txt"
			}
			Else If (Item.IsAmulet){
				File := "data\CastSpeedAmulet.txt"
			}
			Else If (Item.IsRing){
				File := "data\CastSpeedRing.txt"
			}
			Else If (ItemSubType = "Shield"){
				; The native mod only appears on bases with ES
				File := "data\CastSpeedShield.txt"
			}
			Else {
				; All shields can receive a cast speed master mod.
				; Leaving this as non shield specific if the master mod ever becomes applicable on something else
				File := "data\CastSpeedCraft.txt"
			}
			LookupAffixAndSetInfoLine(File, "Suffix", ItemLevel, CurrValue)
			Continue
		}
		
		IfInString, LoopField, increased Critical Strike Chance for Spells
		{
			LookupAffixAndSetInfoLine("data\CritChanceSpells.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		
		; Pure Critical Strike Chance must be checked last
		IfInString, LoopField, Critical Strike Chance
		{
			If (ItemBaseType = "Weapon"){
				File := "data\CritChance_Weapon.txt"
			}
			Else If (ItemSubType = "Quiver"){
				File := "data\CritChance_Quiver.txt"
			}
			Else{
				File := "data\CritChance_Amulet.txt"
			}
			LookupAffixAndSetInfoLine(File, "Suffix", ItemLevel, CurrValue)
			Continue
		}
		
		IfInString, LoopField, Critical Strike Multiplier
		{
			If (ItemBaseType = "Weapon"){
				File := "data\CritMultiplierLocal.txt"
			}
			Else{
				File := "data\CritMultiplierGlobal.txt"
			}
			LookupAffixAndSetInfoLine(File, "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, increased Light Radius
		{
			; T1 comes with "#% increased Accuracy Rating", T2-3 with "+# to Accuracy Rating"
			; This part can always be assigned now. The Accuracy will be solved later in case it's T2-3 and it forms a complex affix.
			
			; Taking the complicated function call here to use MakeAffixDetailLine with "CountAffixTotals=False".
			; This way the mod is already written in case it's T1 and gets overwritten in case it's T2-3.
			; We don't want to overcount the affixes by 0.5 when overwriting though,
			;   so we don't count them here (see also "increased Accuracy" right below).
			ValueRanges := LookupAffixData("data\LightRadius_AccuracyRating.txt", ItemLevel, CurrValue, CurrTier)
			AppendAffixInfo(MakeAffixDetailLine(LoopField, "Hybrid Suffix", ValueRanges, CurrTier, False), A_Index)
			Continue
		}
		IfInString, LoopField, increased Accuracy Rating
		{
			; This variant comes always with Light Radius, see part right above.
			HasIncrLightRadius := False	; Second part is accounted for, no need to involve "+# to Accuracy Rating" or complex affixes.
			LookupAffixAndSetInfoLine("data\IncrAccuracyRating_LightRadius.txt", "Hybrid Suffix", ItemLevel, CurrValue)
			; Now that we know that it's certainly T1 for "Light Radius" and complex affixes won't be involved,
			;   we count the 0.5 that we skipped at "Light Radius".
			AffixTotals.NumSuffixes += 0.5
			Continue
		}
		IfInString, LoopField, Chance to Block
		{
			If (not HasChanceToBlockStrShield){
				LookupAffixAndSetInfoLine("data\BlockChance.txt", "Suffix", ItemLevel, CurrValue)
			}
			Continue
		}
		; Flask affixes (on belts)
		IfInString, LoopField, reduced Flask Charges used
		{
			LookupAffixAndSetInfoLine("data\FlaskChargesUsed.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, increased Flask Charges gained
		{
			LookupAffixAndSetInfoLine("data\FlaskChargesGained.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, increased Flask effect duration
		{
			LookupAffixAndSetInfoLine("data\FlaskDuration.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		
		IfInString, LoopField, increased Quantity of Items found
		{
			If (Item.IsShaperBase)
			{
				File := ["75|4-7","85|8-10"]
			}
			Else
			{
				File := "data\IncrQuantity.txt"
			}
			LookupAffixAndSetInfoLine(File, "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, Life gained on Kill
		{
			LookupAffixAndSetInfoLine("data\LifeOnKill.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, Life gained for each Enemy hit ; Cuts off the rest to accommodate both "by Attacks" and "by your Attacks"
		{
			If (ItemBaseType = "Weapon") {
				File := "data\LifeOnHit_Weapon.txt"
			}
			Else If (ItemSubType = "Amulet"){
				File := "data\LifeOnHit_Amulet.txt"
			}
			Else {
				File := "data\LifeOnHit_GlovesRing.txt"
			}
			LookupAffixAndSetInfoLine(File, "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, of Life Regenerated per second
		{
			LookupAffixAndSetInfoLine("data\LifeRegenPercent.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, Life Regenerated per second
		{
			If (ItemSubType = "BodyArmour"){
				LookupAffixAndSetInfoLine("data\LifeRegen_BodyArmour.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			Else{
				LookupAffixAndSetInfoLine("data\LifeRegen.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
		}
		IfInString, LoopField, Mana Gained on Kill
		{
			LookupAffixAndSetInfoLine("data\ManaOnKill.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, increased Mana Regeneration Rate
		{
			LookupAffixAndSetInfoLine("data\ManaRegen.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, increased Projectile Speed
		{
			LookupAffixAndSetInfoLine("data\ProjectileSpeed.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, reduced Attribute Requirements
		{
			LookupAffixAndSetInfoLine("data\ReducedAttrReqs.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, to all Elemental Resistances
		{
			If (ItemSubType = "Amulet"){
				LookupAffixAndSetInfoLine("data\ToAllResist_Amulet.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			Else{
				LookupAffixAndSetInfoLine("data\ToAllResist.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
		}
		IfInString, LoopField, to Fire Resistance
		{
			LookupAffixAndSetInfoLine("data\ToFireResist.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, to Cold Resistance
		{
			LookupAffixAndSetInfoLine("data\ToColdResist.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, to Lightning Resistance
		{
			LookupAffixAndSetInfoLine("data\ToLightningResist.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, to Chaos Resistance
		{
			LookupAffixAndSetInfoLine("data\ToChaosResist.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, increased Stun Duration on Enemies
		{
			LookupAffixAndSetInfoLine("data\StunDuration.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, reduced Enemy Stun Threshold
		{
			LookupAffixAndSetInfoLine("data\StunThreshold.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, additional Physical Damage Reduction
		{
			LookupAffixAndSetInfoLine("data\AdditionalPhysicalDamageReduction.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, chance to Dodge Attacks
		{
			If (ItemSubType = "BodyArmour")
			{
				LookupAffixAndSetInfoLine("data\ChanceToDodgeAttacks_BodyArmour.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			Else If (ItemSubType = "Shield")
			{
				LookupAffixAndSetInfoLine("data\ChanceToDodgeAttacks_Shield.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
		}
		IfInString, LoopField, of Energy Shield Regenerated per second
		{
			LookupAffixAndSetInfoLine("data\EnergyShieldRegeneratedPerSecond.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, additional Block Chance against Projectiles
		{
			LookupAffixAndSetInfoLine("data\AdditionalBlockChanceAgainstProjectiles.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, chance to Avoid being Stunned
		{
			LookupAffixAndSetInfoLine("data\ChanceToAvoidBeingStunned.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, chance to Avoid Elemental Ailments
		{
			LookupAffixAndSetInfoLine("data\ChanceToAvoidElementalAilments.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, chance to Dodge Spell Damage
		{
			LookupAffixAndSetInfoLine("data\ChanceToDodgeSpellDamage.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, Chance to Block Spells
		{
			LookupAffixAndSetInfoLine("data\ChanceToBlockSpells.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, Life gained when you Block
		{
			LookupAffixAndSetInfoLine("data\LifeOnBlock.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, Mana gained when you Block
		{
			LookupAffixAndSetInfoLine("data\ManaOnBlock.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, increased Attack and Cast Speed
		{
			LookupAffixAndSetInfoLine("data\AttackAndCastSpeed_Shield.txt", "Suffix", ItemLevel, CurrValue)
			Continue
		}
		If (ItemBaseType = "Weapon")
		{
			IfInString, LoopField, Chance to Ignite
			{
				LookupAffixAndSetInfoLine("data\ChanceToIgnite.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, Chance to Freeze
			{
				LookupAffixAndSetInfoLine("data\ChanceToFreeze.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, Chance to Shock
			{
				LookupAffixAndSetInfoLine("data\ChanceToShock.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, chance to cause Bleeding on Hit
			{
				If (CurrValue = 25)
				{
					; Vagan/Tora prefix
					AppendAffixInfo(MakeAffixDetailLine(LoopField, "Prefix", "Vagan 7 or Buy:Tora 4", ""), A_Index)
					Continue
				}
				
				LookupAffixAndSetInfoLine("data\ChanceToBleed.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, chance to Poison on Hit
			{
				LookupAffixAndSetInfoLine("data\ChanceToPoison.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Burning Damage
			{
				LookupAffixAndSetInfoLine("data\IncrBurningDamage.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Damage with Poison
			{
				LookupAffixAndSetInfoLine("data\IncrPoisonDamage.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Damage with Bleeding
			{
				LookupAffixAndSetInfoLine("data\IncrBleedingDamage.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Poison Duration
			{
				LookupAffixAndSetInfoLine("data\PoisonDuration.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Bleed duration
			{
				LookupAffixAndSetInfoLine("data\BleedDuration.txt", "Suffix", ItemLevel, CurrValue)
				Continue
			}
		}
		
		
		; Prefixes
		
		If RegExMatch(LoopField, "Adds \d+? to \d+? Physical Damage")
		{
			If (ItemBaseType = "Weapon")
			{
				If (ItemGripType = "1H"){
					File := "data\AddsPhysDamage_1H.txt"
				}
				Else{
					File := "data\AddsPhysDamage_2H.txt"
				}
			}
			Else If (ItemSubType = "Amulet"){
				File := "data\AddsPhysDamage_Amulet.txt"
			}
			Else If (ItemSubType = "Quiver"){
				File := "data\AddsPhysDamage_Quivers.txt"
			}
			Else If (ItemSubType = "Ring"){
				File := "data\AddsPhysDamage_Ring.txt"
			}
			Else If (ItemSubType = "Gloves"){
				File := "data\AddsPhysDamage_Gloves.txt"
			}
			Else{
				; There is no Else for rare items. Just lookup in 1H for now...
				File := "data\AddsPhysDamage_1H.txt"
			}
			LookupAffixAndSetInfoLine(File, "Prefix", ItemLevel, CurrValue)
			Continue
		}
		
		If RegExMatch(LoopField, "Adds \d+? to \d+? Cold Damage")
		{
			If RegExMatch(LoopField, "Adds \d+? to \d+? Cold Damage to Spells")
			{
				If (ItemGripType = "1H"){
					File := "data\SpellAddsCold_1H.txt"
				}
				Else{
					File := "data\SpellAddsCold_2H.txt"
				}
			}
			Else If (ItemSubType = "Amulet" or ItemSubType = "Ring"){
				File := "data\AddsColdDamage_AmuletRing.txt"
			}
			Else If (ItemSubType = "Gloves"){
				File := "data\AddsColdDamage_Gloves.txt"
			}
			Else If (ItemSubType = "Quiver"){
				File := "data\AddsColdDamage_Quivers.txt"
			}
			Else If ((ItemGripType = "1H") or (ItemSubType = "Bow")){
				; Added damage for bows follows 1H tiers
				File := "data\AddsColdDamage_1H.txt"
			}
			Else{
				File := "data\AddsColdDamage_2H.txt"
			}
			LookupAffixAndSetInfoLine(File, "Prefix", ItemLevel, CurrValue)
			Continue
		}
		
		If RegExMatch(LoopField, "Adds \d+? to \d+? Fire Damage")
		{
			If RegExMatch(LoopField, "Adds \d+? to \d+? Fire Damage to Spells")
			{
				If (ItemGripType = "1H"){
					File := "data\SpellAddsFire_1H.txt"
				}
				Else{
					File := "data\SpellAddsFire_2H.txt"
				}	
			}
			Else If (ItemSubType = "Amulet" or ItemSubType = "Ring"){
				File := "data\AddsFireDamage_AmuletRing.txt"
			}
			Else If (ItemSubType = "Gloves"){
				File := "data\AddsFireDamage_Gloves.txt"
			}
			Else If (ItemSubType = "Quiver"){
				File := "data\AddsFireDamage_Quivers.txt"
			}
			Else If ((ItemGripType = "1H") or (ItemSubType = "Bow")){
				; Added damage for bows follows 1H tiers
				File := "data\AddsFireDamage_1H.txt"
			}
			Else{
				File := "data\AddsFireDamage_2H.txt"
			}
			LookupAffixAndSetInfoLine(File, "Prefix", ItemLevel, CurrValue)
			Continue
		}
		
		If RegExMatch(LoopField, "Adds \d+? to \d+? Lightning Damage")
		{
			If RegExMatch(LoopField, "Adds \d+? to \d+? Lightning Damage to Spells")
			{
				If (ItemGripType = "1H"){
					File := "data\SpellAddsLightning_1H.txt"
				}
				Else{
					File := "data\SpellAddsLightning_2H.txt"
				}
			}
			Else If (ItemSubType = "Amulet" or ItemSubType = "Ring"){
				File := "data\AddsLightningDamage_AmuletRing.txt"
			}
			Else If (ItemSubType = "Gloves"){
				File := "data\AddsLightningDamage_Gloves.txt"
			}
			Else If (ItemSubType = "Quiver"){
				File := "data\AddsLightningDamage_Quivers.txt"
			}
			Else If ((ItemGripType = "1H") or (ItemSubType = "Bow")){
				; Added damage for bows follows 1H tiers
				File := "data\AddsLightningDamage_1H.txt"
			}
			
			Else{
				File := "data\AddsLightningDamage_2H.txt"
			}
			LookupAffixAndSetInfoLine(File, "Prefix", ItemLevel, CurrValue)
			Continue
		}
		
		If RegExMatch(LoopField, "Adds \d+? to \d+? Chaos Damage")
		{
			If ((ItemGripType = "1H") or (ItemSubType = "Bow")){
				; Added damage for bows follows 1H tiers
				File := "data\AddsChaosDamage_1H.txt"
			}
			Else If (ItemGripType = "2H"){
				File := "data\AddsChaosDamage_2H.txt"
			}
			Else If (ItemSubType = "Amulet" or ItemSubType = "Ring"){
				; Master modded prefix
				File := "data\AddsChaosDamage_AmuletRing.txt"
			}
			LookupAffixAndSetInfoLine(File, "Prefix", ItemLevel, CurrValue)
			Continue
		}
		
		IfInString, LoopField, increased maximum Energy Shield
		{
			; Contrary to %Armour and %Evasion this one has a unique wording due to "maximum" and is clearly from Amulets (or Legacy Rings)
			LookupAffixAndSetInfoLine("data\IncrMaxEnergyShield_Amulet.txt", "Prefix", ItemLevel, CurrValue)
			Continue
		}
		
		IfInString, LoopField, Physical Damage to Melee Attackers
		{
			LookupAffixAndSetInfoLine("data\PhysDamagereturn.txt", "Prefix", ItemLevel, CurrValue)
			Continue
		}
		
		IfInString, LoopField, to Level of Socketed
		{
			If RegExMatch(LoopField, "(Fire|Cold|Lightning)"){
				File := "data\GemLevel_Elemental.txt"
			}
			Else If (InStr(LoopField, "Chaos")){
				File := "data\GemLevel_Chaos.txt"
			}
			Else If (InStr(LoopField, "Bow")){
				File := "data\GemLevel_Bow.txt"
			}
			Else If (InStr(LoopField, "Melee")){
				File := "data\GemLevel_Melee.txt"
			}
			Else If (InStr(LoopField, "Minion")){
				File := "data\GemLevel_Minion.txt"
			}
			; Catarina prefix
			Else If (InStr(LoopField, "Support")){
				File := "data\GemLevel_Support.txt"
			}
			Else If (InStr(LoopField, "Socketed Gems"))
			{
				If (ItemSubType = "Ring"){
					File := "data\GemLevel_UnsetRing.txt"
				}
				Else{
					File := "data\GemLevel.txt"
				}
			}
			LookupAffixAndSetInfoLine(File, "Prefix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, Physical Attack Damage Leeched as
		{
			LookupAffixAndSetInfoLine("data\PhysicalAttackDamageLeeched.txt", "Prefix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, Movement Speed
		{
			If (ItemSubType = "Boots")
			{
				LookupAffixAndSetInfoLine("data\MovementSpeed_Boots.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			Else If (ItemSubType = "Belt")
			{
				LookupAffixAndSetInfoLine("data\MovementSpeed_Belt.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
		}
		IfInString, LoopField, increased Elemental Damage with Attack Skills
		{
			If (ItemBaseType = "Weapon"){
				; Because GGG apparently thought having the exact same iLvls and tiers except for one single percentage point is necessary. T1-2: 31-37|38-42 vs. 31-36|37-42
				LookupAffixAndSetInfoLine("data\IncrElementalDamageWithAttackSkills_Weapon.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			Else If (ItemSubType = "Ring"){
				LookupAffixAndSetInfoLine("data\IncrElementalDamageWithAttackSkills_Ring.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			Else{
				; Amulet, Belt, Quiver
				LookupAffixAndSetInfoLine("data\IncrElementalDamageWithAttackSkills.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
		}
		; Flask effects (on belts)
		IfInString, LoopField, increased Flask Mana Recovery rate
		{
			LookupAffixAndSetInfoLine("data\FlaskManaRecoveryRate.txt", "Prefix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, increased Flask Life Recovery rate
		{
			LookupAffixAndSetInfoLine("data\FlaskLifeRecoveryRate.txt", "Prefix", ItemLevel, CurrValue)
			Continue
		}
		If (ItemSubType = "Shield"){
			IfInString, LoopField, increased Global Physical Damage
			{
				HasIncrPhysDmg := False	; No worries about hybrid here.
				LookupAffixAndSetInfoLine("data\IncrPhysDamage_Shield.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Elemental Damage
			{
				LookupAffixAndSetInfoLine("data\IncrEleDamage_Shield.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
			IfInString, LoopField, increased Attack Damage
			{
				LookupAffixAndSetInfoLine("data\IncrAttackDamage_Shield.txt", "Prefix", ItemLevel, CurrValue)
				Continue
			}
		}
		
		; --- MASTER CRAFT/BUY ONLY AFFIXES ---
		
		; Can be either Leo prefix or jewel suffix. Jewels are checked already, so it's Leo.
		If RegExMatch(LoopField, ".*increased Damage$")
		{
			LookupAffixAndSetInfoLine("data\IncrDamageLeo.txt", "Prefix", ItemLevel, CurrValue)
			Continue
		}
		; Haku prefix
		IfInString, LoopField, to Quality of Socketed Support Gems
		{
			LookupAffixAndSetInfoLine("data\GemQuality_Support.txt", "Prefix", ItemLevel, CurrValue)
			Continue
		}
		; Elreon prefix
		IfInString, LoopField, to Mana Cost of Skills
		{
			CurrValue := Abs(CurrValue)	; Turn potentially negative number into positive.
			LookupAffixAndSetInfoLine("data\ManaCostOfSkills.txt", "Prefix", ItemLevel, CurrValue)
			Continue
		}
		; Vorici prefix
		IfInString, LoopField, increased Life Leeched per Second
		{
			LookupAffixAndSetInfoLine("data\LifeLeechedPerSecond.txt", "Prefix", ItemLevel, CurrValue)
			Continue
		}
		; Tora dual suffixes
		IfInString, LoopField, increased Trap Throwing Speed
		{
			LookupAffixAndSetInfoLine("data\IncrTrapThrowingMineLayingSpeed.txt", "Hybrid Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, increased Mine Laying Speed
		{
			LookupAffixAndSetInfoLine("data\IncrTrapThrowingMineLayingSpeed.txt", "Hybrid Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, increased Trap Damage
		{
			LookupAffixAndSetInfoLine("data\IncrTrapMineDamage.txt", "Hybrid Suffix", ItemLevel, CurrValue)
			Continue
		}
		IfInString, LoopField, increased Mine Damage
		{
			LookupAffixAndSetInfoLine("data\IncrTrapMineDamage.txt", "Hybrid Suffix", ItemLevel, CurrValue)
			Continue
		}
		; Vagan suffix
		IfInString, LoopField, to Weapon range
		{
			LookupAffixAndSetInfoLine("data\ToWeaponRange.txt", "Suffix", ItemLevel, CurrValue)
		}
		
		
		
		IfInString, LoopField, Gems in this item are Supported by Lvl 1 Blood Magic
		{
			AppendAffixInfo(MakeAffixDetailLine(LoopField, "Prefix", "", ""), A_Index)
			Continue
		}
		IfInString, LoopField, Hits can't be Evaded
		{
			AppendAffixInfo(MakeAffixDetailLine(LoopField, "Prefix", "", ""), A_Index)
			Continue
		}
		
		
		; Meta Craft Mods
		
		IfInString, LoopField, Can have multiple Crafted Mods
		{
			AppendAffixInfo(MakeAffixDetailLine(LoopField, "Suffix", "", ""), A_Index)
			Continue
		}
		IfInString, LoopField, Prefixes Cannot Be Changed
		{
			AppendAffixInfo(MakeAffixDetailLine(LoopField, "Suffix", "", ""), A_Index)
			Continue
		}
		IfInString, LoopField, Suffixes Cannot Be Changed
		{
			AppendAffixInfo(MakeAffixDetailLine(LoopField, "Prefix", "", ""), A_Index)
			Continue
		}
		IfInString, LoopField, Cannot roll Attack Mods
		{
			AppendAffixInfo(MakeAffixDetailLine(LoopField, "Suffix", "", ""), A_Index)
			Continue
		}
		IfInString, LoopField, Cannot roll Caster Mods
		{
			AppendAffixInfo(MakeAffixDetailLine(LoopField, "Suffix", "", ""), A_Index)
			Continue
		}
		IfInString, LoopField, Cannot roll Mods with Required Lvl above Lvl 28
		{
			AppendAffixInfo(MakeAffixDetailLine(LoopField, "Suffix", "", ""), A_Index)
			Continue
		}
	}
	
	
	; --- COMPLEX AFFIXES ---
	
	If (HasIncreasedAccuracyRating or HasIncreasedGlobalCritChance and (Item.SubType = "Viridian Jewel" or Item.SubType = "Prismatic Jewel") )
	{
		FileAccu := "data\jewel\IncrAccuracyRating_Jewels.txt"
		FileCrit := "data\jewel\CritChanceGlobal_Jewels.txt"
		FileAccuHyb := "data\jewel\CritChanceGlobal_IncrAcc_Jewels.txt"
		FileCritHyb := "data\jewel\IncrAccuracyRating_CritChance_Jewels.txt"
		
		If (HasIncreasedAccuracyRating and HasIncreasedGlobalCritChance)
		{
			LineNum1 := HasIncreasedAccuracyRating
			Value1   := Itemdata.AffixTextLines[LineNum1].Value
			LineNum2 := HasIncreasedGlobalCritChance
			Value2   := Itemdata.AffixTextLines[LineNum2].Value
			SolveAffixes_Mod1Mod2Hyb("AccuCritJewel", LineNum1, LineNum2, Value1, Value2, "Suffix", "Suffix", "Hybrid Suffix", FileAccu, FileCrit, FileAccuHyb, FileCritHyb, ItemLevel)
		}
		Else If (HasIncreasedAccuracyRating)
		{
			LineNum := HasIncreasedAccuracyRating
			LineTxt := Itemdata.AffixTextLines[LineNum].Text
			Value   := Itemdata.AffixTextLines[LineNum].Value
			LookupAffixAndSetInfoLine(FileAccu, "Suffix", ItemLevel, Value, LineTxt, LineNum)
		}
		Else If (HasIncreasedGlobalCritChance)
		{
			LineNum := HasIncreasedGlobalCritChance
			LineTxt := Itemdata.AffixTextLines[LineNum].Text
			Value   := Itemdata.AffixTextLines[LineNum].Value
			LookupAffixAndSetInfoLine(FileCrit, "Suffix", ItemLevel, Value, LineTxt, LineNum)
		}
	}
	
	
	If (HasIncrRarity)
	{
		If (ItemSubType = "Amulet" or ItemSubType = "Ring")
		{
			FilePrefix := "data\IncrRarity_Prefix_AmuletRing.txt"
			FileSuffix := "data\IncrRarity_Suffix_AmuletRingHelmet.txt"
			
			If (HasIncrRarityCraft)
			{
				FileSuffix := "data\IncrRarity_Suffix_Craft.txt"
				
				LineNum := HasIncrRarityCraft
				LineTxt := Itemdata.AffixTextLines[LineNum].Text
				Value   := Itemdata.AffixTextLines[LineNum].Value
				LookupAffixAndSetInfoLine(FileSuffix, "Suffix", ItemLevel, Value, LineTxt, LineNum)
				
				LineNum := HasIncrRarity
				LineTxt := Itemdata.AffixTextLines[LineNum].Text
				Value   := Itemdata.AffixTextLines[LineNum].Value
				LookupAffixAndSetInfoLine(FilePrefix, "Prefix", ItemLevel, Value, LineTxt, LineNum)
			}
			
			Else
			{
				LineNum := HasIncrRarity
				LineTxt := Itemdata.AffixTextLines[LineNum].Text
				Value   := Itemdata.AffixTextLines[LineNum].Value
				
				SolveAffixes_PreSuf("Rarity", LineNum, Value, FilePrefix, FileSuffix, ItemLevel)
			}
		}
		
		Else If (ItemSubType = "Helmet")
		{
			FilePrefix := "data\IncrRarity_Prefix_Helmet.txt"
			FileSuffix := "data\IncrRarity_Suffix_AmuletRingHelmet.txt"
			
			LineNum := HasIncrRarity
			LineTxt := Itemdata.AffixTextLines[LineNum].Text
			Value   := Itemdata.AffixTextLines[LineNum].Value
			
			SolveAffixes_PreSuf("Rarity", LineNum, Value, FilePrefix, FileSuffix, ItemLevel)
		}
		
		Else If (ItemSubType = "Gloves" or ItemSubType = "Boots")
		{
			FilePrefix := "data\IncrRarity_Prefix_GlovesBoots.txt"
			FileSuffix := "data\IncrRarity_Suffix_GlovesBoots.txt"
			
			LineNum := HasIncrRarity
			LineTxt := Itemdata.AffixTextLines[LineNum].Text
			Value   := Itemdata.AffixTextLines[LineNum].Value
			
			SolveAffixes_PreSuf("Rarity", LineNum, Value, FilePrefix, FileSuffix, ItemLevel)
		}
	}
	
	
	If (HasToMaxLife or (HasToArmour or HasToEvasion or HasToMaxES) )
	{
		If (ItemSubType = "BodyArmour" or ItemSubType = "Shield")
		{
			FileToArmour		:= "data\ToArmour_BodyArmourShield.txt"
			FileToArmourHyb	:= "data\ToArmour_BodyArmourShield_HybridBase.txt"
			FileToEvasion		:= "data\ToEvasion_BodyArmourShield.txt"
			FileToEvasionHyb	:= "data\ToEvasion_BodyArmourShield_HybridBase.txt"
			FileToMaxES		:= (ItemSubType = "BodyArmour") ? "data\ToMaxES_BodyArmour.txt" : "data\ToMaxES_Shield.txt"
			FileToMaxESHyb		:= "data\ToMaxES_BodyArmourShield_HybridBase.txt"
		}
		Else If (ItemSubType = "Helmet")
		{
			FileToArmour		:= "data\ToArmour_Helmet.txt"
			FileToArmourHyb	:= "data\ToArmour_Helmet_HybridBase.txt"
			FileToEvasion		:= "data\ToEvasion_Helmet.txt"
			FileToEvasionHyb	:= "data\ToEvasion_Helmet_HybridBase.txt"
			FileToMaxES		:= "data\ToMaxES_Helmet.txt"
			FileToMaxESHyb		:= "data\ToMaxES_Helmet_HybridBase.txt"
		}
		Else If (ItemSubType = "Gloves" or ItemSubType = "Boots")
		{
			FileToArmour		:= "data\ToArmour_GlovesBoots.txt"
			FileToArmourHyb	:= "data\ToArmour_GlovesBoots_HybridBase.txt"
			FileToEvasion		:= "data\ToEvasion_GlovesBoots.txt"
			FileToEvasionHyb	:= "data\ToEvasion_GlovesBoots_HybridBase.txt"
			FileToMaxES		:= "data\ToMaxES_GlovesBoots.txt"
			FileToMaxESHyb		:= "data\ToMaxES_GlovesBoots_HybridBase.txt"
		}
		Else
		{
			FileToArmour		:= "data\ToArmour_Belt.txt"
			FileToEvasion		:= "data\ToEvasion_Ring.txt"
			FileToMaxES		:= (ItemSubType = "Ring") ? "data\ToMaxES_Ring.txt" : "data\ToMaxES_AmuletBelt.txt"
		}
		
		If (ItemSubType = "BodyArmour")
		{
			FileToArmourMaxLife		:= "data\ToArmour_MaxLife_BodyArmour.txt"
			FileToEvasionMaxLife	:= "data\ToEvasion_MaxLife_BodyArmour.txt"
			FileToMaxESMaxLife		:= "data\ToMaxES_MaxLife_BodyArmour.txt"
			FileMaxLifeToDef		:= "data\MaxLife_ToDef_BodyArmour.txt"
		}
		Else If (ItemSubType = "Shield" or ItemSubType = "Helmet")
		{
			FileToArmourMaxLife		:= "data\ToArmour_MaxLife_ShieldHelmet.txt"
			FileToEvasionMaxLife	:= "data\ToEvasion_MaxLife_ShieldHelmet.txt"
			FileToMaxESMaxLife		:= "data\ToMaxES_MaxLife_ShieldHelmet.txt"
			FileMaxLifeToDef		:= "data\MaxLife_ToDef_ShieldHelmet.txt"
		}
		Else If (ItemSubType = "Gloves" or ItemSubType = "Boots")
		{
			FileToArmourMaxLife		:= "data\ToArmour_MaxLife_GlovesBoots.txt"
			FileToEvasionMaxLife	:= "data\ToEvasion_MaxLife_GlovesBoots.txt"
			FileToMaxESMaxLife		:= "data\ToMaxES_MaxLife_GlovesBoots.txt"
			FileMaxLifeToDef		:= "data\MaxLife_ToDef_GlovesBoots.txt"
		}
		
		If (ItemSubType = "Amulet" or ItemSubType = "Boots" or ItemSubType = "Gloves"){
			FileMaxLife := "data\MaxLife_AmuletBootsGloves.txt"
		}
		Else If (ItemSubType = "Belt" or ItemSubType = "Helmet" or ItemSubType = "Quiver"){
			FileMaxLife := "data\MaxLife_BeltHelmetQuiver.txt"
		}
		Else If (ItemSubType = "BodyArmour"){
			FileMaxLife := "data\MaxLife_BodyArmour.txt"
		}
		Else If (ItemSubType = "Shield"){
			FileMaxLife := "data\MaxLife_Shield.txt"
		}
		Else If (ItemSubType = "Ring"){
			FileMaxLife := "data\MaxLife_Ring.txt"
		}
		Else{
			FileMaxLife := "data\MaxLife.txt"
		}
		
		If (HasToMaxLife and (HasToArmour or HasToEvasion or HasToMaxES) and (ItemBaseType = "Armour"))
		{
			If (HasToMaxLifeCraft)
			{
				LineNum := HasToMaxLifeCraft
				LineTxt := Itemdata.AffixTextLines[LineNum].Text
				Value   := Itemdata.AffixTextLines[LineNum].Value
				LookupAffixAndSetInfoLine(FileMaxLife, "Crafted Prefix", ItemLevel, Value, LineTxt, LineNum)
				
				FileMaxLife := False	; indirectly invalidating the pure life mod for other calculations.
			}
			If (HasToArmourCraft)
			{
				LineNum := HasToArmourCraft
				LineTxt := Itemdata.AffixTextLines[LineNum].Text
				Value   := Itemdata.AffixTextLines[LineNum].Value
				LookupAffixAndSetInfoLine(FileToArmour, "Crafted Prefix", ItemLevel, Value, LineTxt, LineNum)
				
				FileToArmour := False	; indirectly invalidating the pure Armour mod for other calculations.
			}
			If (HasToEvasionCraft)
			{
				LineNum := HasToEvasionCraft
				LineTxt := Itemdata.AffixTextLines[LineNum].Text
				Value   := Itemdata.AffixTextLines[LineNum].Value
				LookupAffixAndSetInfoLine(FileToEvasion, "Crafted Prefix", ItemLevel, Value, LineTxt, LineNum)
				
				FileToEvasion := False	; indirectly invalidating the pure Evasion mod for other calculations.
			}
			If (HasToMaxESCraft)
			{
				LineNum := HasToMaxESCraft
				LineTxt := Itemdata.AffixTextLines[LineNum].Text
				Value   := Itemdata.AffixTextLines[LineNum].Value
				LookupAffixAndSetInfoLine(FileToMaxES, "Crafted Prefix", ItemLevel, Value, LineTxt, LineNum)
				
				FileToMaxES := False	; indirectly invalidating the pure MaxES mod for other calculations.
			}
			
			
			If (HasToArmour and HasToEvasion and HasToMaxES)
			{
				
			}
			Else If (HasToArmour and HasToEvasion)
			{
				LineNum1 := HasToArmour
				LineNum2 := HasToEvasion
				LineNum3 := HasToMaxLife
				Value1   := Itemdata.AffixTextLines[LineNum1].Value
				Value2   := Itemdata.AffixTextLines[LineNum2].Value
				Value3   := Itemdata.AffixTextLines[LineNum3].Value
				SolveAffixes_HybBase_FlatDefLife("FlatDefMaxLife", LineNum1, LineNum2, LineNum3, Value1, Value2, Value3, FileToArmourHyb, FileToEvasionHyb, FileMaxLife, FileToArmourMaxLife, FileToEvasionMaxLife, FileMaxLifeToDef, ItemLevel)
			}
			Else If (HasToArmour and HasToMaxES)
			{
				LineNum1 := HasToArmour
				LineNum2 := HasToMaxES
				LineNum3 := HasToMaxLife
				Value1   := Itemdata.AffixTextLines[LineNum1].Value
				Value2   := Itemdata.AffixTextLines[LineNum2].Value
				Value3   := Itemdata.AffixTextLines[LineNum3].Value
				SolveAffixes_HybBase_FlatDefLife("FlatDefMaxLife", LineNum1, LineNum2, LineNum3, Value1, Value2, Value3, FileToArmourHyb, FileToMaxESHyb, FileMaxLife, FileToArmourMaxLife, FileToMaxESMaxLife, FileMaxLifeToDef, ItemLevel)
			}
			Else If (HasToEvasion and HasToMaxES)
			{
				LineNum1 := HasToEvasion
				LineNum2 := HasToMaxES
				LineNum3 := HasToMaxLife
				Value1   := Itemdata.AffixTextLines[LineNum1].Value
				Value2   := Itemdata.AffixTextLines[LineNum2].Value
				Value3   := Itemdata.AffixTextLines[LineNum3].Value
				SolveAffixes_HybBase_FlatDefLife("FlatDefMaxLife", LineNum1, LineNum2, LineNum3, Value1, Value2, Value3, FileToEvasionHyb, FileToMaxESHyb, FileMaxLife, FileToEvasionMaxLife, FileToMaxESMaxLife, FileMaxLifeToDef, ItemLevel)
			}
			Else If (HasToArmour)
			{
				LineNum1 := HasToArmour
				LineNum2 := HasToMaxLife
				Value1   := Itemdata.AffixTextLines[LineNum1].Value
				Value2   := Itemdata.AffixTextLines[LineNum2].Value
				SolveAffixes_Mod1Mod2Hyb("FlatDefMaxLife", LineNum1, LineNum2, Value1, Value2, "Prefix", "Prefix", "Hybrid Prefix", FileToArmour, FileMaxLife, FileToArmourMaxLife, FileMaxLifeToDef, ItemLevel)
			}
			Else If (HasToEvasion)
			{
				LineNum1 := HasToEvasion
				LineNum2 := HasToMaxLife
				Value1   := Itemdata.AffixTextLines[LineNum1].Value
				Value2   := Itemdata.AffixTextLines[LineNum2].Value
				SolveAffixes_Mod1Mod2Hyb("FlatDefMaxLife", LineNum1, LineNum2, Value1, Value2, "Prefix", "Prefix", "Hybrid Prefix", FileToEvasion, FileMaxLife, FileToEvasionMaxLife, FileMaxLifeToDef, ItemLevel)
			}
			Else If (HasToMaxES)
			{
				LineNum1 := HasToMaxES
				LineNum2 := HasToMaxLife
				Value1   := Itemdata.AffixTextLines[LineNum1].Value
				Value2   := Itemdata.AffixTextLines[LineNum2].Value
				SolveAffixes_Mod1Mod2Hyb("FlatDefMaxLife", LineNum1, LineNum2, Value1, Value2, "Prefix", "Prefix", "Hybrid Prefix", FileToMaxES, FileMaxLife, FileToMaxESMaxLife, FileMaxLifeToDef, ItemLevel)
			}
		}
		Else
		{
			If (HasToMaxLife)
			{
				LineNum := HasToMaxLife
				LineTxt := Itemdata.AffixTextLines[LineNum].Text
				Value   := Itemdata.AffixTextLines[LineNum].Value
				LookupAffixAndSetInfoLine(FileMaxLife, "Prefix", ItemLevel, Value, LineTxt, LineNum)
			}
			
			If ( (HasToArmour or HasToEvasion or HasToMaxES) and (ItemBaseType = "Armour") )
			{
				If (HasToArmour and HasToEvasion)
				{
					LineNum := HasToArmour
					LineTxt := Itemdata.AffixTextLines[LineNum].Text
					Value   := Itemdata.AffixTextLines[LineNum].Value
					LookupAffixAndSetInfoLine(FileToArmourHyb, "Hybrid Defence Prefix", ItemLevel, Value, LineTxt, LineNum)
					
					LineNum := HasToEvasion
					LineTxt := Itemdata.AffixTextLines[LineNum].Text
					Value   := Itemdata.AffixTextLines[LineNum].Value
					LookupAffixAndSetInfoLine(FileToEvasionHyb, "Hybrid Defence Prefix", ItemLevel, Value, LineTxt, LineNum)
				}
				Else If (HasToArmour and HasToMaxES)
				{
					LineNum := HasToArmour
					LineTxt := Itemdata.AffixTextLines[LineNum].Text
					Value   := Itemdata.AffixTextLines[LineNum].Value
					LookupAffixAndSetInfoLine(FileToArmourHyb, "Hybrid Defence Prefix", ItemLevel, Value, LineTxt, LineNum)
					
					LineNum := HasToMaxES
					LineTxt := Itemdata.AffixTextLines[LineNum].Text
					Value   := Itemdata.AffixTextLines[LineNum].Value
					LookupAffixAndSetInfoLine(FileToMaxESHyb, "Hybrid Defence Prefix", ItemLevel, Value, LineTxt, LineNum)
				}
				Else If (HasToEvasion and HasToMaxES)
				{
					LineNum := HasToEvasion
					LineTxt := Itemdata.AffixTextLines[LineNum].Text
					Value   := Itemdata.AffixTextLines[LineNum].Value
					LookupAffixAndSetInfoLine(FileToEvasionHyb, "Hybrid Defence Prefix", ItemLevel, Value, LineTxt, LineNum)
					
					LineNum := HasToMaxES
					LineTxt := Itemdata.AffixTextLines[LineNum].Text
					Value   := Itemdata.AffixTextLines[LineNum].Value
					LookupAffixAndSetInfoLine(FileToMaxESHyb, "Hybrid Defence Prefix", ItemLevel, Value, LineTxt, LineNum)
				}
				Else If (HasToArmour)
				{
					LineNum := HasToArmour
					LineTxt := Itemdata.AffixTextLines[LineNum].Text
					Value   := Itemdata.AffixTextLines[LineNum].Value
					LookupAffixAndSetInfoLine(FileToArmour, "Prefix", ItemLevel, Value, LineTxt, LineNum)
				}
				Else If (HasToEvasion)
				{
					LineNum := HasToEvasion
					LineTxt := Itemdata.AffixTextLines[LineNum].Text
					Value   := Itemdata.AffixTextLines[LineNum].Value
					LookupAffixAndSetInfoLine(FileToEvasion, "Prefix", ItemLevel, Value, LineTxt, LineNum)
				}
				Else If (HasToMaxES)
				{
					LineNum := HasToMaxES
					LineTxt := Itemdata.AffixTextLines[LineNum].Text
					Value   := Itemdata.AffixTextLines[LineNum].Value
					LookupAffixAndSetInfoLine(FileToMaxES, "Prefix", ItemLevel, Value, LineTxt, LineNum)
				}
			}
			Else If (HasToArmour or HasToEvasion or HasToMaxES)	; Not an Armour, case for Belt/Ring/Amulet. Belts can have multiple single flat mods while Armours can't.
			{
				If (HasToArmour)
				{
					LineNum := HasToArmour
					LineTxt := Itemdata.AffixTextLines[LineNum].Text
					Value   := Itemdata.AffixTextLines[LineNum].Value
					LookupAffixAndSetInfoLine(FileToArmour, "Prefix", ItemLevel, Value, LineTxt, LineNum)
				}
				
				If (HasToEvasion)
				{
					LineNum := HasToEvasion
					LineTxt := Itemdata.AffixTextLines[LineNum].Text
					Value   := Itemdata.AffixTextLines[LineNum].Value
					LookupAffixAndSetInfoLine(FileToEvasion, "Prefix", ItemLevel, Value, LineTxt, LineNum)
				}
				
				If (HasToMaxES)
				{
					LineNum := HasToMaxES
					LineTxt := Itemdata.AffixTextLines[LineNum].Text
					Value   := Itemdata.AffixTextLines[LineNum].Value
					LookupAffixAndSetInfoLine(FileToMaxES, "Prefix", ItemLevel, Value, LineTxt, LineNum)
				}
			}
		}
	}
	
	
	If (HasStunBlockRecovery or HasIncrDefences)
	{
		If (ItemSubType = "BodyArmour" or ItemSubType = "Shield"){
			BodyArmourShieldOrNot := "_BodyArmourShield"
		}
		Else{
			BodyArmourShieldOrNot := ""
		}
		
		If (HasStunBlockRecovery and HasIncrDefences and (ItemBaseType = "Armour") )
		{
			If (HasChanceToBlockStrShield)
			{
				; TODO: UNHANDLED CASE. Special case: 5 mods can combine into 3 lines here. Implementing this later, because it is so rare.
			}
			Else If (HasIncrDefencesCraft)
			{
				; If there are two separate %def mod lines visible, then the first pre-pass match has to be the part from the hybrid mod
				;   and the second match has to be the pure mod in crafted form.
				
				If (HasIncrDefencesType = "Armour" or HasIncrDefencesType = "Evasion" or HasIncrDefencesType = "EnergyShield"){
					FileHybDef  := "data\Incr" . HasIncrDefencesType . "_StunRecovery.txt"
					FileHybStun := "data\StunBlockRecovery_" . HasIncrDefencesType . ".txt"
				}
				Else{
					FileHybDef  := "data\IncrDefences_HybridBase_StunRecovery.txt"
					FileHybStun := "data\StunBlockRecovery_HybridBase.txt"
				}
				
				FileCraft   := "data\Incr" . HasIncrDefencesCraftType . BodyArmourShieldOrNot . ".txt"
				
				LineNum := HasIncrDefencesCraft
				LineTxt := Itemdata.AffixTextLines[LineNum].Text
				Value   := Itemdata.AffixTextLines[LineNum].Value
				LookupAffixAndSetInfoLine(FileCraft, "Crafted Prefix", ItemLevel, Value, LineTxt, LineNum)
				
				
				LineNum1 := HasIncrDefences
				LineNum2 := HasStunBlockRecovery
				Value1   := Itemdata.AffixTextLines[LineNum1].Value
				Value2   := Itemdata.AffixTextLines[LineNum2].Value
				SolveAffixes_Mod1Mod2Hyb("IncrDefStunBlock", LineNum1, LineNum2, Value1, Value2, "Prefix", "Suffix", "Hybrid Prefix", False, False, FileHybDef, FileHybStun, ItemLevel)
			}
			Else
			{
				If (HasIncrDefencesType = "Armour" or HasIncrDefencesType = "Evasion" or HasIncrDefencesType = "EnergyShield"){
					FileHybDef  := "data\Incr" . HasIncrDefencesType . "_StunRecovery.txt"
					FileHybStun := "data\StunBlockRecovery_" . HasIncrDefencesType . ".txt"
				}
				Else{
					FileHybDef  := "data\IncrDefences_HybridBase_StunRecovery.txt"
					FileHybStun := "data\StunBlockRecovery_HybridBase.txt"
				}
				
				FileDef  := "data\Incr" . HasIncrDefencesType . BodyArmourShieldOrNot . ".txt"
				FileStun := "data\StunBlockRecovery_Suffix.txt"
				
				LineNum1 := HasIncrDefences
				LineNum2 := HasStunBlockRecovery
				Value1   := Itemdata.AffixTextLines[LineNum1].Value
				Value2   := Itemdata.AffixTextLines[LineNum2].Value
				SolveAffixes_Mod1Mod2Hyb("IncrDefStunBlock", LineNum1, LineNum2, Value1, Value2, "Prefix", "Suffix", "Hybrid Prefix", FileDef, FileStun, FileHybDef, FileHybStun, ItemLevel)
			}
			
		}
		Else
		{
			If (HasStunBlockRecovery)
			{
				FileStun := "data\StunBlockRecovery_Suffix.txt"
				LineNum := HasStunBlockRecovery
				LineTxt := Itemdata.AffixTextLines[LineNum].Text
				Value   := Itemdata.AffixTextLines[LineNum].Value
				LookupAffixAndSetInfoLine(FileStun, "Suffix", ItemLevel, Value, LineTxt, LineNum)
			}
			
			If (HasIncrDefences)
			{
				If (ItemSubType = "Amulet")
				{
					File := "data\Incr" . HasIncrDefencesType . "_Amulet.txt"	; "Armour" or "Evasion". ES has a "maximum" in the Amulet wording and was already checked in simple affixes.
				}
				Else
				{
					File := "data\Incr" . HasIncrDefencesType . BodyArmourShieldOrNot . ".txt"
				}
				
				LineNum := HasIncrDefences
				LineTxt := Itemdata.AffixTextLines[LineNum].Text
				Value   := Itemdata.AffixTextLines[LineNum].Value
				LookupAffixAndSetInfoLine(File, "Prefix", ItemLevel, Value, LineTxt, LineNum)
			}
		}
	}
	
	; Note: The "HasIncrPhysDmg" can either come from a shield or weapon. The shield case has already been dealt with in the simple affix section though and
	;   "HasIncrPhysDmg" gets disabled in that case. Consequently this flag is certainly from a weapon.
	
	If ((HasIncrPhysDmg or HasIncrLightRadius) or HasToAccuracyRating)
	{
		FilePhys := "data\IncrPhysDamage.txt"
		
		If (ItemSubType = "Bow" or ItemSubType = "Wand"){
			FileAccu := "data\AccuracyRating_BowWand.txt"
		}
		Else If (ItemBaseType = "Weapon"){
			FileAccu := "data\AccuracyRating_Weapon.txt"
		}
		Else If (ItemSubType = "Helmet" or ItemSubType = "Gloves"){
			FileAccu := "data\AccuracyRating_HelmetGloves.txt"
		}
		Else{
			FileAccu := "data\AccuracyRating_Global.txt"
		}
		
		FileHybPhys := "data\IncrPhysDamage_AccuracyRating.txt"
		FileHybAccuPhys := "data\AccuracyRating_IncrPhysDamage.txt"
		
		FileHybLight := "data\LightRadius_AccuracyRating.txt"
		FileHybAccuLight := "data\AccuracyRating_LightRadius.txt"
		
		
		If ((HasIncrPhysDmg or HasIncrLightRadius) and HasToAccuracyRating)
		{
			If (HasIncrPhysDmg and HasIncrLightRadius and HasToAccuracyRating)
			{
				; TODO: UNHANDLED CASE
			}
			
			Else If (HasIncrPhysDmg and HasToAccuracyRating)
			{
				LineNum1 := HasIncrPhysDmg
				LineNum2 := HasToAccuracyRating
				Value1   := Itemdata.AffixTextLines[LineNum1].Value
				Value2   := Itemdata.AffixTextLines[LineNum2].Value
				
				SolveAffixes_Mod1Mod2Hyb("IncrPhysToAcc", LineNum1, LineNum2, Value1, Value2, "Prefix", "Suffix", "Hybrid Prefix", FilePhys, FileAccu, FileHybPhys, FileHybAccuPhys, ItemLevel)
			}
			
			Else If (HasIncrLightRadius and HasToAccuracyRating)
			{
				LineNum1 := HasIncrLightRadius
				LineNum2 := HasToAccuracyRating
				Value1   := Itemdata.AffixTextLines[LineNum1].Value
				Value2   := Itemdata.AffixTextLines[LineNum2].Value
				
				; there is no "pure" Light Radius mod, hence the False
				
				SolveAffixes_Mod1Mod2Hyb("LightRadiusToAcc", LineNum1, LineNum2, Value1, Value2, "Prefix", "Suffix", "Hybrid Suffix", False, FileAccu, FileHybLight, FileHybAccuLight, ItemLevel)
			}
		}
		
		Else If (HasIncrPhysDmg)
		{
			LineNum := HasIncrPhysDmg
			LineTxt := Itemdata.AffixTextLines[LineNum].Text
			Value   := Itemdata.AffixTextLines[LineNum].Value
			LookupAffixAndSetInfoLine(FilePhys, "Prefix", ItemLevel, Value, LineTxt, LineNum)
		}
		
		Else If (HasToAccuracyRating)
		{
			LineNum := HasToAccuracyRating
			LineTxt := Itemdata.AffixTextLines[LineNum].Text
			Value   := Itemdata.AffixTextLines[LineNum].Value
			LookupAffixAndSetInfoLine(FileAccu, "Suffix", ItemLevel, Value, LineTxt, LineNum)
		}
	}
	
	
	If (HasIncrSpellDamage or HasMaxMana)
	{
		If (ItemGripType = "1H" or ItemSubType = "Shield"){
			FileSpell    := "data\SpellDamage_1H.txt"
			FileHybSpell := "data\SpellDamage_MaxMana_1H.txt"
		}
		Else If (ItemSubType = "Amulet"){
			FileSpell    := "data\SpellDamage_Amulet.txt"
		}
		Else{
			FileSpell    := "data\SpellDamage_Staff.txt"
			FileHybSpell := "data\SpellDamage_MaxMana_Staff.txt"
		}
		
		If (ItemSubType = "Amulet" or ItemSubType = "Ring"){
			FileMana := "data\MaxMana_AmuletRing.txt"
		}
		Else{
			FileMana := "data\MaxMana.txt"
		}
		
		FileHybMana := "data\MaxMana_SpellDamage.txt"
		
		
		; Shields and Amulets can't have the hybrid mod.
		If (HasIncrSpellDamage and HasMaxMana and not((ItemSubType = "Shield") or (ItemSubType = "Amulet")) )
		{
			If (HasIncrSpellOrElePrefix and (HasIncrSpellOrElePrefix != HasIncrSpellDamage))
			{
				FileSpell := False	; There is an increased Fire, Cold or Lightning Prefix, so SpellDamage can't have the pure mod.
			}
			
			LineNum1 := HasIncrSpellDamage
			LineNum2 := HasMaxMana
			Value1   := Itemdata.AffixTextLines[LineNum1].Value
			Value2   := Itemdata.AffixTextLines[LineNum2].Value
			
			SolveAffixes_Mod1Mod2Hyb("SpellMana", LineNum1, LineNum2, Value1, Value2, "Prefix", "Prefix", "Hybrid Prefix", FileSpell, FileMana, FileHybSpell, FileHybMana, ItemLevel)
		}
		Else
		{
			; Checking these in separate ifs and not an else-if chain to cover the case where a shield or amulet has both mods (which are certainly simple mods).
			If (HasIncrSpellDamage)
			{
				LineNum := HasIncrSpellDamage
				LineTxt := Itemdata.AffixTextLines[LineNum].Text
				Value   := Itemdata.AffixTextLines[LineNum].Value
				LookupAffixAndSetInfoLine(FileSpell, "Prefix", ItemLevel, Value, LineTxt, LineNum)
			}
			
			If (HasMaxMana)
			{
				LineNum := HasMaxMana
				LineTxt := Itemdata.AffixTextLines[LineNum].Text
				Value   := Itemdata.AffixTextLines[LineNum].Value
				LookupAffixAndSetInfoLine(FileMana, "Prefix", ItemLevel, Value, LineTxt, LineNum)
			}
		}
	}
	
	If (HasIncrFireDamage or HasIncrColdDamage or HasIncrLightningDamage)
	{
		If (ItemSubType = "Staff"){
			FilePrefix := "data\IncrEleTypeDamage_Prefix_Staff.txt"
			FileSuffixEnd := "_Weapon.txt"
		}
		Else If (ItemSubType = "Wand" or ItemSubType = "Sceptre"){
			FilePrefix := "data\IncrEleTypeDamage_Prefix_WandSceptreFocus.txt"
			FileSuffixEnd := "_Weapon.txt"
		}
		Else If (ItemSubType = "Amulet"){
			FilePrefix := False
			FileSuffixEnd := "_Amulet.txt"
		}
		Else If (ItemSubType = "Ring"){
			FilePrefix := False
			FileSuffixEnd := "_Ring.txt"
		}
		
		IfInString, ItemNamePlate, Spirit Shield
		{
			FilePrefix := "data\IncrEleTypeDamage_Prefix_WandSceptreFocus.txt"
			FileSuffixEnd := False
		}
		
		
		If (HasIncrFireDamage)
		{
			FileSuffix := "data\IncrFireDamage_Suffix" . FileSuffixEnd
			LineNum := HasIncrFireDamage
			LineTxt := Itemdata.AffixTextLines[LineNum].Text
			Value   := Itemdata.AffixTextLines[LineNum].Value
			
			If (HasIncrSpellOrElePrefix and (HasIncrSpellOrElePrefix != HasIncrFireDamage))
			{
				LookupAffixAndSetInfoLine(FileSuffix, "Suffix", ItemLevel, Value, LineTxt, LineNum)
			}
			Else
			{
				SolveAffixes_PreSuf("IncrFire", LineNum, Value, FilePrefix, FileSuffix, ItemLevel)
			}
		}
		If (HasIncrColdDamage)
		{
			FileSuffix := "data\IncrColdDamage_Suffix" . FileSuffixEnd
			LineNum := HasIncrColdDamage
			LineTxt := Itemdata.AffixTextLines[LineNum].Text
			Value   := Itemdata.AffixTextLines[LineNum].Value
			
			If (HasIncrSpellOrElePrefix and (HasIncrSpellOrElePrefix != HasIncrColdDamage))
			{
				LookupAffixAndSetInfoLine(FileSuffix, "Suffix", ItemLevel, Value, LineTxt, LineNum)
			}
			Else
			{
				SolveAffixes_PreSuf("IncrCold", LineNum, Value, FilePrefix, FileSuffix, ItemLevel)
			}
		}
		If (HasIncrLightningDamage)
		{
			FileSuffix := "data\IncrLightningDamage_Suffix" . FileSuffixEnd
			LineNum := HasIncrLightningDamage
			LineTxt := Itemdata.AffixTextLines[LineNum].Text
			Value   := Itemdata.AffixTextLines[LineNum].Value
			
			If (HasIncrSpellOrElePrefix and (HasIncrSpellOrElePrefix != HasIncrLightningDamage))
			{
				LookupAffixAndSetInfoLine(FileSuffix, "Suffix", ItemLevel, Value, LineTxt, LineNum)
			}
			Else
			{
				SolveAffixes_PreSuf("IncrLightning", LineNum, Value, FilePrefix, FileSuffix, ItemLevel)
			}
		}
	}	
	
	
	i := AffixLines.MaxIndex()
	
	; Just using := is not enough for a full copy, so we do all entries per loop.
	Loop, %i%
	{
		Itemdata.UncAffTmpAffixLines[A_Index] := AffixLines[A_Index]
	}
	If (Itemdata.Rarity = "Magic"){
		PrefixLimit := 1
		SuffixLimit := 1
	} Else {
		PrefixLimit := 3
		SuffixLimit := 3
	}
	
	; Set max estimated number to current number. From now on we possibly deal with affix count ranges.
	AffixTotals.NumPrefixesMax := AffixTotals.NumPrefixes
	AffixTotals.NumSuffixesMax := AffixTotals.NumSuffixes
	AffixTotals.NumTotal := AffixTotals.NumPrefixes + AffixTotals.NumSuffixes
	AffixTotals.NumTotalMax := AffixTotals.NumTotal
	
	; THIS FUNCTION IS QUITE COMPLICATED. IT INVOLVES FOUR LOOPS THAT FULFILL DIFFERENT JOBS AT DIFFERENT TIMES.
	;   CONSEQUENTLY THE CODE CAN'T BE SIMPLY READ FROM TOP TO BOTTOM. IT IS HEAVILY COMMENTED THOUGH.
	; READ THE REST OF THE INTRODUCTION HERE. IN THE FUNCTION ITSELF SKIP ALL "PHASE2" UNTIL YOU'VE READ ALL "PHASE1"
	;
	; Phase 1:
	; Check each possible mod if it alone breaks the affix count limit. Discard these from Itemdata.UncertainAffixes.
	; Check if discarding possibilities leaves a mod group with a single choice. Finalize these now certain outcomes.
	; Loop through these checks until nothing changes for one complete pass.
	; Phase 2:
	; Check whether a group will certainly bring an affix type but is not finalized yet. We can use that info to
	;   potentially discard mods from other groups.
	ReloopAll := True
	ConsiderAllRemainingAffixes := False
	CheckAgainForGoodMeasure := False
	While ReloopAll
	{
		; No infinite looping. We re-enable ReloopAll below when it is warranted.
		ReloopAll := False
		
		If (ConsiderAllRemainingAffixes = False)
		{
			; Phase 1:
			; Store each grp's affix min count for a later check.
			; When the outer loop would not repeat due to ReloopAll False,
			;   we have completed a full loopthrough without changes and these numbers are current.
			;
			; Phase 2:
			; ConsiderAllRemainingAffixes is now activated and we start using these values,
			;   so we don't want to reset them once ConsiderAllRemainingAffixes is True.
			
			GrpPrefixMinCount := {"Total":0}
			GrpSuffixMinCount := {"Total":0}
			GrpTotalMinCount  := {"Total":0}
		}
		
		For key_grp, grp in Itemdata.UncertainAffixes
		{
			PrefixMinCount := 10	; Start arbitrary high enough and then lower them with comparisons.
			SuffixMinCount := 10
			TotalMinCount  := 10
			
			; We enable ReloopGrp here because when we are at this point, we want to enter the loop. The only time we don't want to
			;  loop here is when we went through the whole "For key_entry..." loop (below) without any events/changes. 
			ReloopGrp := True
			
			While ReloopGrp
			{
				; Again, no infinite looping.
				ReloopGrp := False
				
				; Counting the entries in grp for checks further below. Since the keys are named .MaxIndex() won't work.
				grp_len := 0
				
				For key_entry, entry in grp
				{
					++grp_len
					
					; Phase 1:
					; Figure out whether all entries of a group have at least a certain prefix or suffix amount.
					; If no entry lowers the respective min to 0, we have that many prefixes or suffixes regardless which entry is correct.
					; Phase 2:
					; Even though we might not be able to finalize the group itself yet, we can now use 
					;   that information to make decisions about the entries of other groups.
					
					If (entry[1] < PrefixMinCount){
						PrefixMinCount := entry[1]
					}
					If (entry[2] < SuffixMinCount){
						SuffixMinCount := entry[2]
					}
					If (entry[1] + entry[2] < TotalMinCount){
						TotalMinCount := entry[1] + entry[2]
					}
					
					If (ConsiderAllRemainingAffixes = False)
					{
						; Phase 1:
						; No fancy affix assumptions yet, just the certain count due to what we have added to AffixLines already.
						AssumePrefixCount := AffixTotals.NumPrefixes
						AssumeSuffixCount := AffixTotals.NumSuffixes
						AssumeTotalCount  := 0	; not used in this phase.
					}
					Else
					{
						; Phase 2:
						; Now we add the summed up mins of all groups into the comparison.
						; Since a group's entry is not supposed to be discarded because of the groups own min portion (that is in the total), we subtract the respective group's share.
						AssumePrefixCount := AffixTotals.NumPrefixes + GrpPrefixMinCount["total"] - GrpPrefixMinCount[key_grp]
						AssumeSuffixCount := AffixTotals.NumSuffixes + GrpSuffixMinCount["total"] - GrpSuffixMinCount[key_grp]
						AssumeTotalCount  := AffixTotals.NumPrefixes + AffixTotals.NumSuffixes + GrpTotalMinCount["total"] - GrpTotalMinCount[key_grp]
					}
					
					If ( (AssumePrefixCount + entry[1] > PrefixLimit) or (AssumeSuffixCount + entry[2] > SuffixLimit) or (AssumeTotalCount + entry[1] + entry[2] > PrefixLimit + SuffixLimit) )
					{
						; Mod does not work because of affix number limit
						; Remove mod entry from "grp"
						grp.Delete(key_entry)
						
						; Use ReloopGrp and break to restart the "For key_entry..." loop, because the indexes changed with the deletion.
						ReloopGrp := True
						break
					}
				}
			}
			
			If (ConsiderAllRemainingAffixes = False)
			{
				; Phase 1:
				; We've finished the whole "For key_entry..." loop for a grp, so the Prefix/Suffix/TotalMinCount actually represents that grp.
				; Record that value (by "key_grp") and also add it to a total.
				; Phase 2:
				; While ConsiderAllRemainingAffixes is True and we are consequently actively using these values, we don't touch them.
				; Otherwise we would add a group's portion a second time to the total, since the total was not reset to 0 at the start.
				GrpPrefixMinCount[key_grp] := PrefixMinCount
				GrpSuffixMinCount[key_grp] := SuffixMinCount
				GrpTotalMinCount[key_grp]  := TotalMinCount
				GrpPrefixMinCount["total"] += PrefixMinCount
				GrpSuffixMinCount["total"] += SuffixMinCount
				GrpTotalMinCount["total"]  += TotalMinCount
			}
			
			
			If (grp_len=1)
			{
				; Only one mod in this grp, so there is no ambiguity. Put the mod in and remove grp.
				FinalizeUncertainAffixGroup(grp)
				Itemdata.UncertainAffixes.Delete(key_grp)
				
				; Phase 2:
				; By finalizing a group their affixes are now included in AffixTotals.NumPrefixes/Suffixes, which adds into AssumePrefix/Suffix/TotalCount.
				; Consequently we don't want that min value to remain in the total, because it would effectively get added twice.
				GrpPrefixMinCount["total"] -= GrpPrefixMinCount[key_grp]
				GrpSuffixMinCount["total"] -= GrpSuffixMinCount[key_grp]
				GrpTotalMinCount["total"]  -= GrpTotalMinCount[key_grp]
				
				; Restart at outer "for" loop because grp is gone and outer indexes are shifted due to deletion.
				ReloopAll := True
				break
			}
			Else If (grp_len=0)
			{
				Itemdata.UncertainAffixes.Delete(key_grp)
				
				; Restart at outer "for" loop because grp is gone and outer indexes are shifted due to deletion.
				ReloopAll := True
				break
			}
		}
		
		
		If (ReloopAll = False)
		{
			; Phase 1:
			; Basic checks are done. Now we can check if a group is not solved yet but is guaranteed to bring a certain affix type
			;   which we can count against the limit and then rule out entries from other groups.
			
			If (ConsiderAllRemainingAffixes = False)
			{
				; We enable Phase 2 of affix count comparison here.
				
				ConsiderAllRemainingAffixes = True
				ReloopAll = True
				; ...and ReloopAll obviously. (Continue reading Phase 2 from the top again)
			}
			Else If (CheckAgainForGoodMeasure = False)
			{
				; Phase 2:
				; If we arrive here we've checked everything with the Phase 2 comparison.
				; Reset flags to run through a whole Phase1+Phase2 iteration again, just to be sure that we
				;   can't figure anything more out. When that is done we finally get out of the loops because:
				;     ConsiderAllRemainingAffixes is True and
				;     CheckAgainForGoodMeasure is True
				
				CheckAgainForGoodMeasure = True
				ConsiderAllRemainingAffixes = False
				ReloopAll = True
			}
		}
	}
	
	; Now also accept whatever is still remaining.
	For idx1, grp in Itemdata.UncertainAffixes
	{
		FinalizeUncertainAffixGroup(grp)
	}
	
	; Remove lines with identical entries (coming from different mod-combinations)
	; For example if line1 can be either "T1 HybP" or "T6 P + T1 HybP" but the corresponding
	;   line2 is "T1 HybP" in both cases, we don't want that double entry in line2.
	For key1, line in Itemdata.UncAffTmpAffixLines{
		For key2, subline in line{
			If (IsObject(subline)){
				; Check line possibilities starting from the last index (safer when removing entries)
				i := line.MaxIndex()
				While(i > key2)
				{
					; Check all entries after our current entry at line[key2] if they are duplicates of it
					;   (by comparing "TypeAndTier" and line index 3). Remove if identical.
					If (line[i][3] = line[key2][3])
					{
						line.RemoveAt(i)
					}
					--i
				}
			}Else{
				break
			}
		}
	}
	
	AffixLines.Reset()
	
	; Go through Itemdata.UncAffTmpAffixLines and write lines that have multiple possibilities stored in an array
	;   as several single lines into AffixLines. So for example:
	;	[
	;	  [Line1Data],
	;	  [ [Line2Data_#1], [Line2Data_#2] ],
	;	  [Line3Data]
	;	]
	;	becomes
	;	[
	;	  [Line1Data],
	;	  [Line2Data_#1],
	;	  [Line2Data_#2],
	;	  [Line3Data]
	;	]
	
	i := 1
	For key1, line in Itemdata.UncAffTmpAffixLines{
		If (IsObject(line)){
			For key2, subline in line{
				If (IsObject(subline)){
					AffixLines.Set(i, subline)
					++i
				}Else{
					AffixLines.Set(i, line)
					++i
					break
				}
			}
		}
		Else{
			AffixLines.Set(i, line)
			++i
		}
	}
	return
}

FinalizeUncertainAffixGroup(grp)
{
	Global Itemdata, AffixTotals

	PrefixMin := 10
	PrefixMax := 0
	SuffixMin := 10
	SuffixMax := 0
	TotalMin	:= 10
	TotalMax  := 0

	For key_entry, entry in grp
	{
		; entry[1] is PrefixCount and entry[2] is SuffixCount for that entry.
		
		If (entry[1] < PrefixMin){
			PrefixMin := entry[1]
		}
		If (entry[1] > PrefixMax){
			PrefixMax := entry[1]
		}
		If (entry[2] < SuffixMin){
			SuffixMin := entry[2]
		}
		If (entry[2] > SuffixMax){
			SuffixMax := entry[2]
		}
		If (entry[1] + entry[2] < TotalMin){
			TotalMin := entry[1] + entry[2]
		}
		If (entry[1] + entry[2] > TotalMax){
			TotalMax := entry[1] + entry[2]
		}
		
		For junk, val in [3,5,7,9,11,13]	; these are the potential line number entries, the +1's are the line texts.
		{
			If (entry[val])
			{
				If (IsObject(Itemdata.UncAffTmpAffixLines[entry[val]]))
				{
					; There already is a mod for that line. Append this alternative to the array of the line.
					; Overwrite the line text with "or"
					entry[val+1][1] := "or"
					Itemdata.UncAffTmpAffixLines[entry[val]].Push(entry[val+1])
				}
				Else
				{
					; First entry for that line, start array and put the whole line as entry 1.
					Itemdata.UncAffTmpAffixLines[entry[val]] := [entry[val+1]]
				}
			}
		}
	}
	
	AffixTotals.NumPrefixes    += PrefixMin
	AffixTotals.NumPrefixesMax += PrefixMax
	AffixTotals.NumSuffixes    += SuffixMin
	AffixTotals.NumSuffixesMax += SuffixMax
	AffixTotals.NumTotal       += TotalMin
	AffixTotals.NumTotalMax    += TotalMax
}

ResetAffixDetailVars()
{
	Global AffixLines, AffixTotals, Globals
	AffixLines.Reset()
	AffixTotals.Reset()
}

IsEmptyString(String)
{
	If (StrLen(String) == 0)
	{
		return True
	}
	Else
	{
		String := RegExReplace(String, "[\r\n ]", "")
		If (StrLen(String) < 1)
		{
			return True
		}
	}
	return False
}

IsNum(Var){
	If (++Var)
		return true
	return false
}

PreProcessContents(CBContents)
{
; --- Place fixes for data inconsistencies here ---
	
; Remove the line that indicates an item cannot be used due to missing character stats	
	; Matches "Rarity: ..." + anything until "--------"\r\n
	CBContents:= SubStr(CBContents, InStr(CBContents,"`n") + 1)
	If (RegExMatch(CBContents, "s)^(.+?:.+?\r\n)(.+?-{8}\r\n)(.*)", match)) {
		; Matches any ".", looking for the 2 sentences saying "You cannot use this item. Its stats will be ignored."
		; Could be improved, should suffice though because the alternative would be the item name/type, which can't have any dots.
		; This should work regardless of the selected language.
		If (RegExMatch(match2, "\.")) {
			CBContents := match1 . match3	
		}		
	}
	
     Needle := "--------`r`n--------`r`n"
	StringReplace, CBContents, CBContents, %Needle%, --------`r`n, All
	
	return CBContents
}

PostProcessData(ParsedData)
{
	Global Opts
	
	Result := ParsedData
	
	StringReplace, TempResult, ParsedData, --------`n, ``, All
	StringSplit, ParsedDataChunks, TempResult, ``
	
	Result =
	Loop, %ParsedDataChunks0%
	{
		CurrChunk := ParsedDataChunks%A_Index%
		If IsEmptyString(CurrChunk)
		{
			Continue
		}
		If (A_Index < ParsedDataChunks0)
		{
			Result := Result . CurrChunk . "--------`r`n"
		}
		Else
		{
			Result := Result . CurrChunk
		}
	}
	
	return Result
}

ParseClipBoardChanges(debug = false)
{
	Global Opts, Globals, Item
	
	CBContents := GetClipboardContents()
	CBContents := PreProcessContents(CBContents)
	/*
		;Item Data Translation, won't be used for now.
		CBContents := PoEScripts_TranslateItemData(CBContents, translationData, currentLocale, retObj, retCode)
	*/	
	
	Globals.Set("ItemText", CBContents)
	
	ParsedData := ParseItemData(CBContents)
	ParsedData := PostProcessData(ParsedData)
	
	If (Opts.PutResultsOnClipboard && ParsedData)
	{
		SetClipboardContents(ParsedData)
	}
	
	If (StrLen(ParsedData) and !Opts.OnlyActiveIfPOEIsFront and debug) {
		AddLogEntry(ParsedData, CBContents)
	}
	
	ShowToolTip(ParsedData, false, Opts.GDIConditionalColors)
}

AddLogEntry(ParsedData, RawData) {
	logFileRaw	:= userDirectory "\parsingLogRaw.txt"
	logFileParsed	:= userDirectory "\parsingLog.txt"

	line		:= "----------------------------------------------------------"
	timeStamp	:= ""
	ID 		:= MD5(RawData)
	UTCTimestamp := GetTimestampUTC()
	UTCFormatStr := "yyyy-MM-dd'T'HH:mm'Z'"
	FormatTime, TimeStr, %UTCTimestamp%, %UTCFormatStr%
	
	entry	:= line "`n" TimeStr " - ID: " ID "`n" line "`n`n"
	entryRaw	:= entry . RawData "`n`n"
	entryParsed := entry . ParsedData "`n`n"

	FileAppend, %entryRaw%, %logFileRaw%
	FileAppend, %entryParsed%, %logFileParsed%
}

MD5(string, case := False)    ; by SKAN | rewritten by jNizM
{
	static MD5_DIGEST_LENGTH := 16
	hModule := DllCall("LoadLibrary", "Str", "advapi32.dll", "Ptr")
, VarSetCapacity(MD5_CTX, 104, 0), DllCall("advapi32\MD5Init", "Ptr", &MD5_CTX)
, DllCall("advapi32\MD5Update", "Ptr", &MD5_CTX, "AStr", string, "UInt", StrLen(string))
, DllCall("advapi32\MD5Final", "Ptr", &MD5_CTX)
	loop % MD5_DIGEST_LENGTH
		o .= Format("{:02" (case ? "X" : "x") "}", NumGet(MD5_CTX, 87 + A_Index, "UChar"))
	return o, DllCall("FreeLibrary", "Ptr", hModule)
}

GetTimestampUTC() { ; http://msdn.microsoft.com/en-us/library/ms724390
	VarSetCapacity(ST, 16, 0) ; SYSTEMTIME structure
	DllCall("Kernel32.dll\GetSystemTime", "Ptr", &ST)
	Return NumGet(ST, 0, "UShort")                        ; year   : 4 digits until 10000
	. SubStr("0" . NumGet(ST,  2, "UShort"), -1)     ; month  : 2 digits forced
	. SubStr("0" . NumGet(ST,  6, "UShort"), -1)     ; day    : 2 digits forced
	. SubStr("0" . NumGet(ST,  8, "UShort"), -1)     ; hour   : 2 digits forced
	. SubStr("0" . NumGet(ST, 10, "UShort"), -1)     ; minute : 2 digits forced
	. SubStr("0" . NumGet(ST, 12, "UShort"), -1)     ; second : 2 digits forced
}

WriteToLogFile(data, file, project) {
	logFile	:= A_ScriptDir "\temp\" file
	If (not FileExist(logFile)) {
		FileAppend, Starting up %project%....`n`n, %logFile%
	}

	line		:= "----------------------------------------------------------"
	timeStamp	:= ""
	UTCTimestamp := GetTimestampUTC()
	UTCFormatStr := "yyyy-MM-dd'T'HH:mm'Z'"
	FormatTime, TimeStr, %UTCTimestamp%, %UTCFormatStr%

	entry	:= line "`n" TimeStr "`n" line "`n`n"
	entry	:= entry . data "`n`n"

	FileAppend, %entry%, %logFile%
}

ParseAddedDamage(String, DmgType, ByRef DmgLo, ByRef DmgHi)
{
	If (RegExMatch(String, "Adds (\d+) to (\d+) " DmgType " Damage", Match))
	{
	;StringSplit, Arr, Match, %A_Space%
	;StringSplit, Arr, Arr2, -
		DmgLo := Match1
		DmgHi := Match2
	}
}

AssembleDamageDetails(FullItemData)
{
	Quality := 0
	AttacksPerSecond := 0
	AttackSpeedIncr := 0
	PhysIncr := 0
	PhysLo := 0
	PhysHi := 0
	FireLo := 0
	FireHi := 0
	ColdLo := 0
	ColdHi := 0
	LighLo := 0
	LighHi := 0
	ChaoLo := 0
	ChaoHi := 0
	
	MainHFireLo := 0
	MainHFireHi := 0
	MainHColdLo := 0
	MainHColdHi := 0
	MainHLighLo := 0
	MainHLighHi := 0
	MainHChaoLo := 0
	MainHChaoHi := 0
	
	OffHFireLo := 0
	OffHFireHi := 0
	OffHColdLo := 0
	OffHColdHi := 0
	OffHLighLo := 0
	OffHLighHi := 0
	OffHChaoLo := 0
	OffHChaoHi := 0
	
	
	Loop, Parse, FullItemData, `n, `r
	{
		; Get quality
		IfInString, A_LoopField, Quality:
		{
			StringSplit, Arr, A_LoopField, %A_Space%, +`%
			Quality := Arr2
			Continue
		}
		
		; Get total physical damage
		IfInString, A_LoopField, Physical Damage:
		{
			StringSplit, Arr, A_LoopField, %A_Space%
			StringSplit, Arr, Arr3, -
			PhysLo := Arr1
			PhysHi := Arr2
			Continue
		}
		
		; Get attack speed
		IfInString, A_LoopField, Attacks per Second:
		{
			StringSplit, Arr, A_LoopField, %A_Space%
			AttacksPerSecond := Arr4
			Continue
		}
		
		; Get percentage attack speed increase
		IfInString, A_LoopField, increased Attack Speed
		{
			StringSplit, Arr, A_LoopField, %A_Space%, `%
			AttackSpeedIncr += Arr1		; There are a few weapons with an AS implicit, so we ADD all relevant lines here
			Continue
		}
		
		; Get percentage physical damage increase
		IfInString, A_LoopField, increased Physical Damage
		{
			StringSplit, Arr, A_LoopField, %A_Space%, `%
			PhysIncr := Arr1
			Continue
		}
		
		; Skip "ele/chaos damage to spells" being counted as "added damage" (implying to attacks)
		IfNotInString, A_LoopField, Damage to Spells
		{
			; Parse added damage
			; Differentiate general mods from main hand and off hand only
			; Examples for main/off: Dyadus, Wings of Entropy
			
			IfInString, A_LoopField, in Main Hand
			{
				ParseAddedDamage(A_LoopField, "Fire", MainHFireLo, MainHFireHi)
				ParseAddedDamage(A_LoopField, "Cold", MainHColdLo, MainHColdHi)
				ParseAddedDamage(A_LoopField, "Lightning", MainHLighLo, MainHLighHi)
				ParseAddedDamage(A_LoopField, "Chaos", MainHChaoLo, MainHChaoHi)
			}
			Else IfInString, A_LoopField, in Off Hand
			{
				ParseAddedDamage(A_LoopField, "Fire", OffHFireLo, OffHFireHi)
				ParseAddedDamage(A_LoopField, "Cold", OffHColdLo, OffHColdHi)
				ParseAddedDamage(A_LoopField, "Lightning", OffHLighLo, OffHLighHi)
				ParseAddedDamage(A_LoopField, "Chaos", OffHChaoLo, OffHChaoHi)
			}
			Else
			{
				ParseAddedDamage(A_LoopField, "Fire", FireLo, FireHi)
				ParseAddedDamage(A_LoopField, "Cold", ColdLo, ColdHi)
				ParseAddedDamage(A_LoopField, "Lightning", LighLo, LighHi)
				ParseAddedDamage(A_LoopField, "Chaos", ChaoLo, ChaoHi)
			}
		}
		
	}
	
	Result =
	
	If ( AttackSpeedIncr > 0 )
	{
		BaseAttackSpeed := AttacksPerSecond / (AttackSpeedIncr / 100 + 1)
		; The BaseAttackSpeed's second decimal place is always 0 or 5, so for example 1.24 should actually be 1.25
		; We check how far off it is
		ModVal := Mod(BaseAttackSpeed, 0.05)
		; And effectively round to the nearest 0.05
		BaseAttackSpeed += (ModVal > 0.025) ? (0.05 - ModVal) : (- ModVal)
		; Now we put the AttacksPerSecond back together
		AttacksPerSecond := BaseAttackSpeed * (AttackSpeedIncr / 100 + 1)	
	}
	
	
	SetFormat, FloatFast, 5.1
	PhysDps	:= ((PhysLo + PhysHi) / 2) * AttacksPerSecond
	EleDps		:= ((FireLo + FireHi + ColdLo + ColdHi + LighLo + LighHi) / 2) * AttacksPerSecond
	MainHEleDps	:= ((MainHFireLo + MainHFireHi + MainHColdLo + MainHColdHi + MainHLighLo + MainHLighHi) / 2) * AttacksPerSecond
	OffHEleDps	:= ((OffHFireLo + OffHFireHi + OffHColdLo + OffHColdHi + OffHLighLo + OffHLighHi) / 2) * AttacksPerSecond
	ChaosDps		:= ((ChaoLo + ChaoHi) / 2) * AttacksPerSecond
	MainHChaosDps	:= ((MainHChaoLo + MainHChaoHi) / 2) * AttacksPerSecond
	OffHChaosDps	:= ((OffHChaoLo + OffHChaoHi) / 2) * AttacksPerSecond
	TotalDps		:= PhysDps + EleDps + ChaosDps
	
	If (Quality < 20) {
		Q20Dps := Q20PhysDps := PhysDps * (PhysIncr + 120) / (PhysIncr + Quality + 100)
		Q20Dps := Q20Dps + EleDps + ChaosDps	
	}
	
	If ( MainHEleDps > 0 or OffHEleDps > 0 or MainHChaosDps > 0 or OffHChaosDps > 0 ) {
		MainH_OffH_Display	:= true
		TotalMainHEleDps	:= MainHEleDps + EleDps
		TotalOffHEleDps	:= OffHEleDps + EleDps
		TotalMainHChaosDps	:= MainHChaosDps + ChaosDps
		TotalOffHChaosDps	:= OffHChaosDps + ChaosDps
		TotalMainHDps		:= PhysDps + TotalMainHEleDps + TotalMainHChaosDps
		TotalOffHDps		:= PhysDps + TotalOffHEleDps + TotalOffHChaosDps
		Q20MainHDps		:= Q20Dps + TotalMainHEleDps + TotalMainHChaosDps
		Q20OffHDps		:= Q20Dps + TotalOffHEleDps + TotalOffHChaosDps
		
		Result = %Result%`nPhys DPS:   %PhysDps%
		
		If (Quality < 20)
		{
			Result = %Result%`nQ20 Phys:   %Q20PhysDps%
		}
		
		If ( MainHEleDps > 0 or OffHEleDps > 0 )
		{
			Result = %Result%`nEle DPS:    %TotalMainHEleDps% MainH | %TotalOffHEleDps% OffH
		}
		Else Result = %Result%`nEle DPS:    %EleDps%
		
		If ( MainHChaosDps > 0 or OffHChaosDps > 0 )
		{
			Result = %Result%`nChaos DPS:  %TotalMainHChaosDps% MainH | %TotalOffHChaosDps% OffH
		}
		Else Result = %Result%`nChaos DPS:  %ChaosDps%
		
		Result = %Result%`nTotal DPS:  %TotalMainHDps% MainH | %TotalOffHDps% OffH
		
		If (Quality < 20)
		{
			Result		= %Result%`nQ20 Total:  %Q20MainHDps% MainH | %Q20OffHDps% OffH
		}
	}
	Else
	{
		Result = %Result%`nEle DPS:    %EleDps%     Chaos DPS:  %ChaosDps%
		
		; Only show Q20 values if item is not Q20
		Result = %Result%`nPhys DPS:   %PhysDps%
		If (Quality < 20)
		{
			Result = %Result%     Q20 Phys:   %Q20PhysDps%
		}
		
		Result = %Result%`nTotal DPS:  %TotalDps%
		
		If (Quality < 20)
		{
			Result	= %Result%     Q20 Total:  %Q20Dps%
		}
	}

	
	Item.DamageDetails					:= {}
	Item.DamageDetails.MainHEleDps		:= MainHEleDps
	Item.DamageDetails.OffHEleDps			:= OffHEleDps
	Item.DamageDetails.MainHChaosDps		:= MainHChaosDps
	Item.DamageDetails.OffHChaosDps		:= OffHChaosDps
	Item.DamageDetails.TotalMainHDps		:= TotalMainHDps
	Item.DamageDetails.TotalOffHDps		:= TotalOffHDps
	Item.DamageDetails.TotalMainHEleDps	:= TotalMainHEleDps
	Item.DamageDetails.TotalOffHEleDps		:= TotalOffHEleDps
	Item.DamageDetails.TotalMainHChaosDps	:= TotalMainHChaosDps
	Item.DamageDetails.TotalOffHChaosDps	:= TotalOffHChaosDps
	Item.DamageDetails.Q20MainHDps		:= Q20MainHDps
	Item.DamageDetails.Q20OffHDps			:= Q20OffHDps
	
	Item.DamageDetails.Quality			:= Quality
	Item.DamageDetails.PhysDps			:= PhysDps
	Item.DamageDetails.EleDps			:= EleDps
	Item.DamageDetails.ChaosDps			:= ChaosDps
	Item.DamageDetails.TotalDps			:= TotalDps
	Item.DamageDetails.Q20PhysDps			:= Q20PhysDps
	Item.DamageDetails.Q20Dps			:= Q20Dps
	
	return Result
}

AssembleProphecyDetails(name) {
	parsedJSON := {}
	prophecy := {}
	
	If (not Globals.Get("ProphecyData")) {
		Try {
			FileRead, JSONFile, %A_ScriptDir%\data_trade\prophecy_details.json
			parsedJSON := JSON.Load(JSONFile)
			prophecy := parsedJSON.prophecy_details[name]
			
			If (not prophecy.text) {
				Return
			}
		} Catch error {
			Return
		}
		
		Globals.Set("ProphecyData", parsedJSON.prophecy_details)
	} Else {
		prophecy := Globals.Get("ProphecyData")[name]
	}
	
	TT := ""
	If (prophecy.objective) {
		TT .= "`n" "Objective:" "`n" prophecy.objective "`n"
	}
	If (prophecy.reward) {
		TT .= "`n" "Reward:" "`n" prophecy.reward "`n"
	}
	If (StrLen(prophecy["seal cost"])) {
		TT .= "`n" "Seal Cost:" " " prophecy["seal cost"] "`n"
	}
	
	Return TT
}

; ParseItemName fixed by user: uldo_.  Thanks!
ParseItemName(ItemDataChunk, ByRef ItemName, ByRef ItemBaseName, AffixCount = "", ItemData = "")
{
	isVaalGem := false
	If (RegExMatch(Trim(ItemData.Parts[1]), "i)^Rarity: Gem") and RegExMatch(Trim(ItemData.Parts[2]), "i)Vaal")) {
		isVaalGem := true
	}

	If (RegExMatch(ItemData.NamePlate, "i)Rarity\s?+:\s?+(Currency|Divination Card|Gem)", match)) {
		If (RegExMatch(match1, "i)Gem")) {
			ItemBaseName := Trim(RegExReplace(ItemName, "i) Support"))
		} Else {
			ItemBaseName := Trim(ItemName)
		}		
	}
	
	Loop, Parse, ItemDataChunk, `n, `r
	{
		If (A_Index == 1)
		{
			IfNotInString, A_LoopField, Rarity:
			{
				return
			}
			Else
			{
				Continue
			}
		}
		
		If (StrLen(A_LoopField) == 0 or A_LoopField == "--------" or A_Index > 3)
		{
			return
		}
		
		If (A_Index = 2)
		{
			If InStr(A_LoopField, ">>")
			{
				StringGetPos, pos, A_LoopField, >>, R
				ItemName := SubStr(A_LoopField, pos+3)
			}
			Else
			{
				ItemName := A_LoopField
				If (isVaalGem and not RegExMatch(ItemName, "i)^Vaal ")) {
					; examples of name differences
					; summon skeleton - vaal summon skeletons
					; Purity of Lightning - Vaal Impurity of Lightning
					ItemName := ItemData.Parts[6]	; this may be unsafe, the parts index may change in the future

					For k, part in ItemData.Parts {
						If (RegExMatch(part, "im)(^Vaal .*?" ItemName ".*)", vaalName)) {	; TODO: make sure this is safer
							ItemName := vaalName1
							Break
						}
					}
				}
			}

			; Normal items don't have a third line and the item name equals the BaseName if we sanitize it ("superior").
			; Also unidentified items.
			If (RegExMatch(ItemDataChunk, "i)Rarity.*?:.*?Normal") or RegExMatch(ItemData.PartsLast, "i)Unidentified"))
			{
				ItemBaseName := Trim(RegExReplace(ItemName, "i)Superior", ""))
				Return
			}
			; Magic items don't have a third line.
			; Sanitizing the item name is a bit more complicated but should work with the following assumptions:
			;   1. The suffix always begins with " of".
			;   2. The prefix consists of only 1 word, never more.
			; We need to know the AffixCount for this though.
			Else If (AffixCount > 0) {
				If (RegExMatch(ItemDataChunk, "i)Rarity.*?:.*?Magic"))
				{
					ItemBaseName := Trim(RegExReplace(ItemName, "i) of .*", "", matchCount))
					If ((matchCount and AffixCount > 1) or (not matchCount and AffixCount = 1))
					{
						; We replaced the suffix and have 2 affixes, therefore we must also have a prefix that we can replace.
						; OR we didn't replace the suffix but have 1 mod, therefore we must have a prefix that we can replace.
						ItemBaseName := Trim(RegExReplace(ItemBaseName, "iU)^.* ", ""))
						Return
					}
				}
			}
		}
		If (A_Index = 3)
		{
			ItemBaseName := A_LoopField
		}
	}
}

UniqueHasFatedVariant(ItemName)
{
	Loop, Read, %A_ScriptDir%\data\UniqueHasFatedVariant.txt
	{
		Line := StripLineCommentRight(A_LoopReadLine)
		If (SkipLine(Line))
		{
			Continue
		}
		If (ItemName == Line)
		{
			return True
		}
	}
	return False
}

ParseLinks(ItemDataText)
{
	HighestLink := 0
	Loop, Parse, ItemDataText, `n, `r
	{
		IfInString, A_LoopField, Sockets
		{
			LinksString := GetColonValue(A_LoopField)
			If (RegExMatch(LinksString, ".-.-.-.-.-."))
			{
				HighestLink := 6
				Break
			}
			If (RegExMatch(LinksString, ".-.-.-.-."))
			{
				HighestLink := 5
				Break
			}
			If (RegExMatch(LinksString, ".-.-.-."))
			{
				HighestLink := 4
				Break
			}
			If (RegExMatch(LinksString, ".-.-."))
			{
				HighestLink := 3
				Break
			}
			If (RegExMatch(LinksString, ".-."))
			{
				HighestLink := 2
				Break
			}
		}
	}
	return HighestLink
}

ParseSockets(ItemDataText, ByRef AbyssalSockets)
{
	SocketsCount := 0
	
	Loop, Parse, ItemDataText, `n, `r
	{
		If (RegExMatch(A_LoopField, "i)^Sockets\s?+:"))
		{
			LinksString	:= GetColonValue(A_LoopField)
			RegExReplace(LinksString, "i)[RGBWDA]", "", SocketsCount) 	; "D" is being used for Resonator sockets, "A" for Abyssal Sockets
			RegExReplace(LinksString, "i)[A]", "", AbyssalSockets) 	; "A" for Abyssal Sockets
			Break
		}
	}
	return SocketsCount
}

ParseSocketGroups(ItemDataText, ByRef RawSocketString = "")
{
	groups := []
	Loop, Parse, ItemDataText, `n, `r
	{
		IfInString, A_LoopField, Sockets
		{
			RegExMatch(A_LoopField, "i)Sockets:\s?(.*)", socketString)
			
			sockets := socketString1 " "	; add a space at the end for easier regex
			If (StrLen(socketString1)) {
				RawSocketString := socketString1
			}			
			If (StrLen(sockets)) {
				Pos		:= 0
				While Pos	:= RegExMatch(sockets, "i)(.*?)\s+", value, Pos + (StrLen(value) ? StrLen(value) : 1)) {
					s := Trim(value1)
					s := RegExReplace(s, "i)-")
					If (StrLen(Trim(s))) {
						groups.push(s)
					}
				}
			}
		}
	}

	return groups
}

ParseCharges(stats)
{
	charges := {}
	Loop, Parse, stats, `n, `r
	{
		LoopField := RegExReplace(A_Loopfield, "i)\s\(augmented\)", "")
		; Flasks
		RegExMatch(LoopField, "i)Consumes (\d+) of (\d+) Charges on use.*", max)
		If (max) {
			charges.usage	:= max1
			charges.max	:= max2
		}
		RegExMatch(LoopField, "i)Currently has (\d+) Charge.*", current)
		If (current) {
			charges.current:= current1
		}

		; Leaguestones
		RegExMatch(LoopField, "i)Currently has (\d+) of (\d+) Charge.*", max)
		If (max) {
			charges.usage	:= 1
			charges.max	:= max2
			charges.current:= max1
		}
	}

	return charges
}

ParseBeastData(data) {
	a := {}
	
	legendaryBeastsList := ["Farric Wolf Alpha", "Fenumal Scorpion", "Fenumal Plaqued Arachnid", "Farric Frost Hellion Alpha", "Farric Lynx ALpha", "Saqawine Vulture", "Craicic Chimeral", "Saqawine Cobra", "Craicic Maw", "Farric Ape", "Farric Magma Hound", "Craicic Vassal", "Farric Pit Hound", "Craicic Squid" 
	, "Farric Taurus", "Fenumal Scrabbler", "Farric Goliath", "Fenumal Queen", "Saqawine Blood Viper", "Fenumal Devourer", "Farric Ursa", "Fenumal Widow", "Farric Gargantuan", "Farric Chieftain", "Farric Ape", "Farrci Flame Hellion Alpha", "Farrci Goatman", "Craicic Watcher", "Saqawine Retch"
	, "Saqawine Chimeral", "Craicic Shield Crab", "Craicic Sand Spitter", "Craicic Savage Crab", "Saqawine Rhoa"]
	
	portalBeastsList := ["Farric Tiger Alpha", "Craicic Spider Crab", "Fenumal Hybrid Arachnid", "Saqawine Rhex"]
	aspectBeastsList := ["Farrul, First of the Plains", "Craiceann, First of the Deep", "Fenumus, First of the Night", "Saqawal, First of the Sky"]
	
	nameplate := data.nameplate
	Loop, Parse, nameplate, `n, `r
	{
		If (A_Index = 2 and IsInArray(Trim(A_LoopField), aspectBeastsList)) {
			a.IsAspectBeast := true
			a.BeastName := Trim(A_LoopField)
		}	
		
		If (A_Index = 3) {
			a.BeastBase := Trim(A_LoopField)
			If (IsInArray(Trim(A_LoopField), portalBeastsList)) {
				a.IsPortalbeast := true
			}
			Else If (IsInArray(Trim(A_LoopField), legendaryBeastsList)) {
				a.IsLegendaryBeast := true
			}
			
		}		
	}
	
	parts := data.parts[2]
	Loop, Parse, parts, `n, `r
	{
		RegExMatch(A_LoopField, "i)(Genus|Family|Group):\s+?(.*)", match)
		a[match1] := Trim(match2)
	}
	
	parts := data.parts[4]
	a["Mods"] := []
	Loop, Parse, parts, `n, `r
	{
		If (RegExMatch(A_LoopField, "i)(Aspect of the Hellion|Blood Geyser|Churning Claws|Craicic Presence|Crimson Flock|Crushing Claws|Deep One's Presence|Erupting Winds|Farric Presence|Fenumal Presence|Fertile Presence|Hadal Dive|Incendiary Mite|Infested Earth|Putrid Flight|Raven Caller|Saqawine Presence|Satyr Storm|Spectral Stampede|Spectral Swipe|Tiger Prey|Unstable Swarm|Vile Hatchery|Winter Bloom)", match))
		{
			a["Mods"].Push(match1)
		}
	}

	return a
}

ParseAreaMonsterLevelRequirement(stats)
{
	requirements := {}
	Loop,  Parse, stats, `n, `r
	{
		RegExMatch(A_LoopField, "i)Can only be used in Areas with Monster Level(.*)", req)
		RegExMatch(req1, "i)(\d+).*", lvl)
		RegExMatch(req1, "i)below|above|higher|lower", logicalOperator)

		If (lvl) {
			requirements.lvl	:= Trim(lvl1)
		}
		If (logicalOperator) {
			requirements.logicalOperator := Trim(logicalOperator)
		}
	}
	return requirements
}

; Converts a currency stack to Chaos by looking up the
; conversion ratio from CurrencyRates.txt or downloaded ratios from poe.ninja
ConvertCurrency(ItemName, ItemStats, ByRef dataSource)
{
	If (InStr(ItemName, "Shard"))
	{
		IsShard	:= True
		ItemName	:= "Orb of " . SubStr(ItemName, 1, -StrLen(" Shard"))
	}
	If (InStr(ItemName, "Fragment"))
	{
		IsFragment:= True
		ItemName	:= "Scroll of Wisdom"
	}
	StackSize := SubStr(ItemStats, StrLen("Stack Size:  "))
	StringSplit, StackSizeParts, StackSize, /
	If (IsShard or IsFragment)
	{
		SetFormat, FloatFast, 5.3
		StackSize := StackSizeParts1 / StackSizeParts2
	}
	Else
	{
		SetFormat, FloatFast, 5.2
		StackSize := RegExReplace(StackSizeParts1, "i)[^0-9a-z]")
	}

	; Update currency rates from poe.ninja
	last	:= Globals.Get("LastCurrencyUpdate")
	diff	:= A_NowUTC
	EnvSub, diff, %last%, Minutes
	If (diff > 180 or !last) {
		; no data or older than 3 hours
		GoSub, FetchCurrencyData
	}

	; Use downloaded currency rates if they exist, otherwise use hardcoded fallback
	fallback		:= A_ScriptDir . "\data\CurrencyRates.txt"
	result		:= []

	CurrencyDataRates := Globals.Get("CurrencyDataRates")
	For idx, league in ["tmpstandard", "tmphardcore", "Standard", "Hardcore", "eventstandard", "eventhardcore"] {
		ninjaRates	:= CurrencyDataRates[league]
		ChaosRatio	:= ninjaRates[ItemName].OwnQuantity ":" ninjaRates[ItemName].ChaosQuantity
		ChaosMult		:= ninjaRates[ItemName].ChaosQuantity / ninjaRates[ItemName].OwnQuantity
		ValueInChaos	:= (ChaosMult * StackSize)
		
		If (league == "tmpstandard" or league == "tmphardcore" ) {
			leagueName := InStr(league, "standard") ? "Challenge Standard" : "Challenge Hardcore"
		}
		Else If (league = "eventstandard" or league = "eventhardcore") {
			leagueName := InStr(league, "standard") ? "Event Standard    " : "Event Hardcore    "
		}
		Else {
			leagueName := "Permanent " . league
		}
		
		If (ValueInChaos) {
			tmp := [leagueName ": ", ValueInChaos, ChaosRatio]
			result.push(tmp)
		}
	}

	; fallback - condition : no results found so far
	If (!result.Length()) {
		ValueInChaos	:= 0
		dataSource	:= "Fallback <\data\CurrencyRates.txt>`n`n"
		leagueName	:= "Hardcoded rates: "
		
		Loop, Read, %fallback%
		{
			Line := StripLineCommentRight(A_LoopReadLine)
			If (SkipLine(Line))
			{
				Continue
			}
			IfInString, Line, %ItemName%
			{
				StringSplit, LineParts, Line, |
				ChaosRatio	:= LineParts2
				StringSplit, ChaosRatioParts,ChaosRatio, :
				ChaosMult		:= ChaosRatioParts2 / ChaosRatioParts1
				ValueInChaos	:= (ChaosMult * StackSize)
			}
		}

		If (ValueInChaos) {
			tmp := [leagueName, ValueInChaos, ChaosRatio]
			result.push(tmp)
		}
	}

	return result
}

FindUnique(ItemName)
{
	Loop, Read, %A_ScriptDir%\data\Uniques.txt
	{
		Line := StripLineCommentRight(A_LoopReadLine)
		If (SkipLine(Line))
		{
			Continue
		}
		IfInString, Line, %ItemName%
		{
			return True
		}
	}
	return False
}

; Strip comments at line end, e.g. "Bla bla bla ; comment" -> "Bla bla bla"
StripLineCommentRight(Line)
{
	IfNotInString, Line, `;
	{
		return Line
	}
	ProcessedLine := RegExReplace(Line, "(.+?)([ \t]*;.+)", "$1")
	If IsEmptyString(ProcessedLine)
	{
		return Line
	}
	return ProcessedLine
}

; Return True if line begins with comment character (;)
; or if it is blank (that is, it only has 2 characters
; at most (newline and carriage return)
SkipLine(Line)
{
	IfInString, Line, `;
	{
		; Comment
		return True
	}
	If (StrLen(Line) <= 2)
	{
		; Blank line (at most \r\n)
		return True
	}
	return False
}

; Parse unique affixes from text file database.
; Has wanted side effect of populating AffixLines "array" vars.
; return True if the unique was found the database
ParseUnique(ItemName)
{
	Global Opts, AffixLines
	
	ResetAffixDetailVars()
	UniqueFound := False
	Loop, Read, %A_ScriptDir%\data\Uniques.txt
	{
		ALine := StripLineCommentRight(A_LoopReadLine)
		If (SkipLine(ALine))
		{
			Continue
		}
		If (RegExMatch(ALine, "^" ItemName "\|"))
		{
			StringSplit, LineParts, ALine, |
			NumLineParts := LineParts0
			UniqueFound := True
			AppendImplicitSep := False
			Idx := 1
			Loop, % (NumLineParts)
			{
				If (A_Index > 1)
				{
					ProcessedLine =
					CurLinePart := LineParts%A_Index%
					IfInString, CurLinePart, :
					{
						StringSplit, CurLineParts, CurLinePart, :
						AffixLine := CurLineParts2
						ValueRange := CurLineParts1
						IfInString, ValueRange, @
						{
							AppendImplicitSep := True
							StringReplace, ValueRange, ValueRange, @
						}
						
						IfInString, ValueRange, `,
						{
							; Double range
							StringSplit, VRParts, ValueRange, `,
							LowerRange := VRParts1
							UpperRange := VRParts2
							StringSplit, LowerBoundParts, LowerRange, -
							StringSplit, UpperBoundParts, UpperRange, -
							BtmMin := LowerBoundParts1
							BtmMax := LowerBoundParts2
							TopMin := UpperBoundParts1
							TopMax := UpperBoundParts2
							ValueRange := FormatDoubleRanges(BtmMin, BtmMax, TopMin, TopMax)
						}
						
						ValueRange := StrPad(ValueRange, 7, "left")
						
						If (AppendImplicitSep)
						{
							ValueRange .= "`n--------"
							AppendImplicitSep := False
						}
						ProcessedLine := [AffixLine, ValueRange]
					}
					Else{
						ProcessedLine := [CurLinePart, ""]
					}
					AffixLines.Set(Idx, ProcessedLine)
					Idx += 1
				}
			}
			return UniqueFound
		}
	}
	return UniqueFound
}

ItemIsMirrored(ItemDataText)
{
	Loop, Parse, ItemDataText, `n, `r
	{
		RegExMatch(Trim(A_LoopField), "i)^Mirrored$", match)
		If (match) {
			return True
		}
	}
	return False
}

ItemIsHybridBase(ItemDataText)
{
	DefenceStatCount := 0
	Loop, Parse, ItemDataText, `n, `r
	{
		If RegExMatch(Trim(A_LoopField), "^(Armour|Evasion Rating|Energy Shield): \d+( \(augmented\))?$")
		{
			DefenceStatCount += 1
		}
	}
	return (DefenceStatCount > 1) ? True : False
}


/*
########### MAIN PARSE FUNCTION ##############

Invocation stack (simplified) for full item parse:

(timer watches clipboard contents)
(on clipboard changed) ->

ParseClipBoardChanges()
  PreProcessContents()
    ParseItemData()
      (get item details by calling many other Parse... functions)
      ParseAffixes()
        (on affix match found) ->
        Simple affixes:
          LookupAffixAndSetInfoLine()
            AppendAffixInfo(MakeAffixDetailLine()) ; appends to global AffixLines table
        Complex affixes:
          Use functions depending on Pre-Pass flags, set by ParseAffixes()
            Put results into Itemdata.UncertainAffixes
              Decide which ones are possible regarding prefix/suffix limit and append them to global AffixLines table
    PostProcessData()
    ShowToolTip()
*/
ParseItemData(ItemDataText, ByRef RarityLevel="")
{
	Global Opts, AffixTotals, mapList, mapMatchList, uniqueMapList, uniqueMapNameFromBase, divinationCardList, gemQualityList
	
	ItemDataPartsIndexLast =
	ItemDataPartsIndexAffixes =
	ItemDataPartsLast =
	ItemDataNamePlate =
	ItemDataStats =
	ItemDataAffixes =
	ItemDataRequirements =
	ItemDataRarity =
	ItemDataLinks =
	ItemName =
	ItemBaseName =
	ItemQuality =
	ItemLevel =
	ItemMaxSockets =
	ItemBaseType =
	ItemSubType =
	ItemGripType =
	BaseLevel =
	RarityLevel =
	TempResult =
	Variation =
	
	Item.Init()
	ItemData.Init()
	
	ResetAffixDetailVars()
	
	ItemData.FullText := ItemDataText
	
	Loop, Parse, ItemDataText, `n, `r
	{
		RegExMatch(Trim(A_LoopField), "i)^Corrupted$", corrMatch)
		If (corrMatch) {
			Item.IsCorrupted := True
		}
		RegExMatch(Trim(A_LoopField), "i)^(Elder|Shaper|Synthesised|Fractured|Crusader|Hunter|Warlord|Redeemer) Item$", match)
		If (match) {
			Item["Is" match1 "Base"] := True
			Item.HasInfluence.push(match1)
		}
		RegExMatch(Trim(A_LoopField), "i)^Combine this with four other different samples in Tane's Laboratory.", match)
		If (match) {
			Item.IsMetamorphSample := True
		}
	}
	
	; AHK only allows splitting on single chars, so first
	; replace the split string (\r\n--------\r\n) with AHK's escape char (`)
	; then do the actual string splitting...
	StringReplace, TempResult, ItemDataText, `r`n--------`r`n, ``, All
	StringSplit, ItemDataParts, TempResult, ``,
	
	ItemData.NamePlate	:= ItemDataParts1
	ItemData.Stats		:= ItemDataParts2

	ItemDataIndexLast := ItemDataParts0
	ItemDataPartsLast := ItemDataParts%ItemDataIndexLast%
	
	Loop, %ItemDataParts0%
	{
		ItemData.Parts[A_Index] := ItemDataParts%A_Index%
	}
	ItemData.PartsLast := ItemDataPartsLast
	ItemData.IndexLast := ItemDataIndexLast

	; ItemData.Requirements := GetItemDataChunk(ItemDataText, "Requirements:")
	; ParseRequirements(ItemData.Requirements, RequiredLevel, RequiredAttributes, RequiredAttributeValues)

	ParseItemName(ItemData.NamePlate, ItemName, ItemBaseName, "", ItemData)
	If (Not ItemName)
	{
		return
	}

	Item.Name		:= ItemName
	Item.BaseName	:= ItemBaseName
	
	IfInString, ItemDataText, Unidentified
	{
		If (Item.Name != "Scroll of Wisdom")
		{
			Item.IsUnidentified := True
		}
	}

	Item.Quality := ParseQuality(ItemData.Stats, QualityType)
	Item.QualityType := QualityType
	
	; This function should return the second part of the "Rarity: ..." line
	; in the case of "Rarity: Unique" it should return "Unique"
	ItemData.Rarity	:= ParseRarity(ItemData.NamePlate)
	
	ItemData.Links		:= ParseLinks(ItemDataText)
	Item.Links		:= ItemData.Links
	ItemData.Sockets	:= ParseSockets(ItemDataText, ItemAbyssalSockets)
	Item.Sockets		:= ItemData.Sockets
	Item.AbyssalSockets := ItemAbyssalSockets
	Item.SocketGroups	:= ParseSocketGroups(ItemDataText, ItemSocketString)
	Item.SocketString	:= ItemSocketString

	Item.Charges		:= ParseCharges(ItemData.Stats)

	Item.IsUnique := False
	If (InStr(ItemData.Rarity, "Unique"))
	{
		Item.IsUnique := True
	}
	
	If (InStr(ItemData.Rarity, "Rare"))
	{
		Item.IsRare := True
	}
	
	; Divination Card detection = Normal rarity with stack size (100% valid??)
	; Cards like "The Void" don't have a stack size
	If (InStr(ItemData.Rarity, "Divination Card"))
	{
		Item.IsDivinationCard := True
		Item.BaseType := "Divination Card"
	}

	; Prophecy Orb detection
	If (InStr(ItemData.PartsLast, "to add this prophecy to"))
	{
		Item.IsProphecy := True
		Item.BaseType := "Prophecy"
		; ParseProphecy(ItemData, Difficulty)
		; Item.DifficultyRestriction := Difficulty
	}
	
	; Hideout doodad detection
	If (InStr(ItemData.PartsLast, "Creates an object in your hideout"))
	{
		Item.IsHideoutObject := True
	}
	
	; Beast detection
	If (RegExMatch(ItemData.Parts[2], "i)Genus|Family"))
	{
		Item.IsBeast := True
		Item.BeastData := ParseBeastData(ItemData)
		Item.BaseType := "Beast"
	}
	
	Item.IsGem	:= (InStr(ItemData.Rarity, "Gem"))
	Item.IsCurrency:= (InStr(ItemData.Rarity, "Currency"))
	Item.IsFossil	:= (RegExMatch(ItemData.NamePlate, "i)Fossil$")) ? true : false
	Item.IsScarab	:= (RegExMatch(ItemData.NamePlate, "i)Scarab$")) ? true : false
	
	regex := ["^Sacrifice At", "^Fragment of", "^Mortal ", "^Offering to ", "'s Key$", "Ancient Reliquary Key", "Timeworn Reliquary Key", "Breachstone", "Divine Vessel", "^Simulacrum"]
	For key, val in regex {
		If (RegExMatch(Item.Name, "i)" val "")) {
			Item.IsMapFragment := True
			Item.SubType := "Map Fragment"
			Break
		}
	}	

	If (Not (InStr(ItemDataText, "Itemlevel:") or InStr(ItemDataText, "Item Level:")) and not Item.IsGem and not Item.IsCurrency and not Item.IsDivinationCard and not Item.IsProphecy and not Item.IsScarab)
	{
		return Item.Name
	}

	If (Item.IsGem)
	{
		RarityLevel	:= 0
		Item.Level	:= ParseGemLevel(ItemDataText, "Level:")
		Item.GemColor	:= ParseGemColor(ItemDataText)
		ItemExperienceFlat := ""
		Item.Experience:= ParseGemXP(ItemDataText, "Experience:", ItemExperienceFlat)
		Item.ExperienceFlat := ItemExperienceFlat
		ItemLevelWord	:= "Gem Level:"
		ItemXPWord	:= "Experience:"
		Item.BaseType	:= "Gem"
	}
	Else
	{
		If (Item.IsCurrency)
		{
			Item.BaseType := "Currency"
	
			dataSource	:= ""
			ValueInChaos	:= ConvertCurrency(Item.Name, ItemData.Stats, dataSource)
			If (ValueInChaos.Length() and not Item.Name == "Chaos Orb")
			{
				CurrencyDetails := "`n" . dataSource
				CurrencyValueLength := 0
				CurrencyRatioLength := 0
				Loop, % ValueInChaos.Length()
				{
					CurrencyValueLength := CurrencyValueLength < StrLen(ValueInChaos[A_Index][2]) ? StrLen(ValueInChaos[A_Index][2]) : CurrencyValueLength
					CurrencyRatioLength := CurrencyRatioLength < StrLen(ValueInChaos[A_Index][3]) ? StrLen(ValueInChaos[A_Index][3]) : CurrencyRatioLength
				}
				Loop, % ValueInChaos.Length()
				{
					CurrencyDetails .= ValueInChaos[A_Index][1]
					CurrencyDetails .= "" . StrPad(ValueInChaos[A_Index][2], CurrencyValueLength, "left") . " Chaos " 
					CurrencyDetails .= StrPad("(" . ValueInChaos[A_Index][3], CurrencyRatioLength + 1, "left") . "c)`n"
				}
			}
		}

		; Don't do this on Divination Cards or this script crashes on trying to do the ParseItemLevel
		Else If (Not Item.IsCurrency and Not Item.IsDivinationCard and Not Item.IsProphecy)
		{
			RarityLevel	:= CheckRarityLevel(ItemData.Rarity)
			If (not Item.IsScarab) {
				Item.Level	:= ParseItemLevel(ItemDataText)
				ItemLevelWord	:= "Item Level:"	
			}			
			If (Not Item.IsBeast) {
				ParseItemType(ItemData.Stats, ItemData.NamePlate, ItemBaseType, ItemSubType, ItemGripType, RarityLevel, Item.IsMetamorphSample)
				Item.BaseType	:= ItemBaseType
				Item.SubType	:= ItemSubType
				Item.GripType	:= ItemGripType
			}			
		}
	}

	Item.RarityLevel	:= RarityLevel
	
	Item.IsBow		:= (Item.SubType == "Bow")
	Item.IsFlask		:= (Item.SubType == "Flask")
	Item.IsBelt		:= (Item.SubType == "Belt")
	Item.IsRing		:= (Item.SubType == "Ring")
	Item.IsUnsetRing	:= (Item.IsRing and InStr(ItemData.NamePlate, "Unset Ring"))
	Item.IsAmulet		:= (Item.SubType == "Amulet")
	Item.IsTalisman	:= (Item.IsAmulet and InStr(ItemData.NamePlate, "Talisman") and !InStr(ItemData.NamePlate, "Amulet"))
	Item.IsSingleSocket	:= (IsUnsetRing)
	Item.IsFourSocket	:= (Item.SubType == "Gloves" or Item.SubType == "Boots" or Item.SubType == "Helmet")
	Item.IsThreeSocket	:= (Item.GripType == "1H" or Item.SubType == "Shield")
	Item.IsQuiver		:= (Item.SubType == "Quiver")
	Item.IsWeapon		:= (Item.BaseType == "Weapon")
	Item.IsArmour		:= (Item.BaseType == "Armour")
	Item.IsHybridBase	:= (ItemIsHybridBase(ItemDataText))
	Item.IsMap		:= (Item.BaseType == "Map")
	Item.IsLeaguestone	:= (Item.BaseType == "Leaguestone")
	Item.IsJewel		:= (Item.BaseType == "Jewel")
	Item.IsAbyssJewel	:= (Item.IsJewel and RegExMatch(Item.SubType, "i)(Murderous|Hypnotic|Searching|Ghastly) Eye"))
	Item.IsClusterJewel	:= (Item.IsJewel and RegExMatch(Item.SubType, "i)(Small|Medium|Large|) Cluster"))
	Item.IsMirrored	:= (ItemIsMirrored(ItemDataText) and Not Item.IsCurrency)
	Item.IsEssence		:= Item.IsCurrency and RegExMatch(Item.Name, "i)Essence of |Remnant of Corruption")
	Item.Note			:= Globals.Get("ItemNote")

	If (Item.IsLeaguestone) {
		Item.AreaMonsterLevelReq	:= ParseAreaMonsterLevelRequirement(ItemData.Stats)
	}
	
	TempStr := ItemData.PartsLast
	Loop, Parse, TempStr, `n, `r
	{
		RegExMatch(Trim(A_LoopField), "^Has .*(Effect|Skin\.)", match)
		If (match) {
			Item.HasEffect := True
		}
		; parse item variations like relics (variation of it's unique counterpart)
		If (RegExMatch(Trim(A_LoopField), "i)Relic Unique", match)) {
			Item.IsRelic := true
		}
	}
	
	If Item.IsTalisman {
		Loop, Read, %A_ScriptDir%\data\TalismanTiers.txt
		{
			; This loop retrieves each line from the file, one at a time.
			StringSplit, TalismanData, A_LoopReadLine, |,
			If InStr(ItemData.NamePlate, TalismanData1) {
				Item.TalismanTier := TalismanData2
			}
		}
	}
	
	ItemDataIndexAffixes := ItemData.IndexLast - GetNegativeAffixOffset(Item)
	If (ItemDataIndexAffixes <= 0)
	{
		; ItemDataParts doesn't have the parts/text we need. Bail.
		; This might be because the clipboard is completely empty.
		return
	}

	If (Item.IsLeagueStone or Item.IsScarab) {
		ItemDataIndexAffixes := ItemDataIndexAffixes - 1
	}
	Else If (Item.IsProphecy) {
		ItemDataIndexAffixes := ItemDataIndexAffixes - 1
	}
	Else If (Item.IsBeast) {
		ItemDataIndexAffixes := ItemDataIndexAffixes - 1
	}
	ItemData.Affixes := RegExReplace(ItemDataParts%ItemDataIndexAffixes%, "[\r\n]+([a-z])", " $1")
	ItemData.IndexAffixes := ItemDataIndexAffixes
	
	; Retrieve items implicit mod if it has one
	If (Item.IsWeapon or Item.IsQuiver or Item.IsArmour or Item.IsRing or Item.IsBelt or Item.IsAmulet or Item.IsJewel) {
		; Magic and higher rarity
		If (RarityLevel > 1) {
			ItemDataIndexImplicit := ItemData.IndexLast - GetNegativeAffixOffset(Item) - 1
		}
		; Normal rarity
		Else {
			ItemDataIndexImplicit := ItemData.IndexLast - GetNegativeAffixOffset(Item)
		}
		/*
			TODO: rework this after 3.9 hits, implicits are now flagged,  not sure about enchantments
		*/
		; Check that there is no ":" in the retrieved text = can only be an implicit mod
/*
		_implicitFound := !InStr(ItemDataParts%ItemDataIndexImplicit%, ":")
		If (_implicitFound) {
			tempImplicit	:= ItemDataParts%ItemDataIndexImplicit%
			Loop, Parse, tempImplicit, `n, `r
			{
				Item.Implicit.push(RegExReplace(A_LoopField, "i)(.*)\(Implicit\)", "$1"))
			}
			Item.hasImplicit := True
		}

		; Check if there is a second "possible implicit" which means the first one is actually an enchantment
		_ItemDataIndexImplicit := ItemDataIndexImplicit - 1
		If (_implicitFound and !InStr(ItemDataParts%_ItemDataIndexImplicit%, ":")) {			
			tempImplicit	:= ItemDataParts%_ItemDataIndexImplicit%
			Loop, Parse, tempImplicit, `n, `r
			{
				Item.Enchantment.push(RegExReplace(A_LoopField, "i)(.*)\(Implicit\)", "$1"))
			}
			Item.hasImplicit := True
			Item.hasEnchantment := True
		}
		*/
		
		_ItemDataIndexImplicit := ItemDataIndexImplicit - 1
		_implicitsArr := [ItemDataParts%ItemDataIndexImplicit%, ItemDataParts%_ItemDataIndexImplicit%]

		For key, imp in _implicitsArr {
			_implicitFound := RegExMatch(imp, "i)(.*)\(Implicit|Enchant\)")
			If (_implicitFound) {
				Loop, Parse, imp, `n, `r
				{
					If (RegExMatch(A_LoopField, "i)(.*)\(Enchant\)")) {
						Item.Enchantment.push(RegExReplace(A_LoopField, "i)(.*)\(Enchant\)", "$1"))
						Item.hasEnchantment := True
					}
					Else {
						Item.Implicit.push(RegExReplace(A_LoopField, "i)(.*)\(Implicit\)", "$1"))
						Item.hasImplicit := True
					}
				}
			}
		}
		
	}
	
	ItemData.Stats := ItemDataParts2

	If (Item.IsFlask)
	{
		ParseFlaskAffixes(ItemData.Affixes)
	}
	Else If (Item.IsBeast)
	{
		; already parsed
	}
	Else If (RarityLevel > 1 and RarityLevel < 4 and Item.IsMap = False and not (Item.IsLeaguestone or Item.IsScarab))  ; Code added by Bahnzo to avoid maps showing affixes
	{
		ParseAffixes(ItemData.Affixes, Item)
	}
	Else If (Item.IsProphecy) {
		ParseAffixes(ItemData.Affixes, Item)
	}
	Else If (RarityLevel > 1 and RarityLevel < 4 and Item.IsMap = True)
	{
		MapModWarnings := ParseMapAffixes(ItemData.Affixes)
	}
	Else If (RarityLevel > 1 and RarityLevel < 4 and (Item.IsLeaguestone or Item.IsScarab))
	{
		ParseLeagueStoneAffixes(ItemData.Affixes, Item)
	}
	
	If (RarityLevel > 1 and Item.IsMap = False) {
		Item.veiledPrefixCount := GetVeiledModCount(ItemData.Affixes, "Prefix")
		Item.veiledSuffixCount := GetVeiledModCount(ItemData.Affixes, "Suffix")
	}

	AffixTotals.FormatAll()
	
	NumPrefixes	:= AffixTotals.NumPrefixes
	NumPrefixesMax	:= AffixTotals.NumPrefixesMax
	NumSuffixes	:= AffixTotals.NumSuffixes
	NumSuffixesMax	:= AffixTotals.NumSuffixesMax
	NumTotalAffixes	:= NumFormatPointFiveOrInt( (AffixTotals.NumTotal > NumPrefixes + NumSuffixes) ? AffixTotals.NumTotal : NumPrefixes + NumSuffixes )
	AffixTotals.NumTotal    := NumTotalAffixes
	NumTotalAffixesMax	:= NumFormatPointFiveOrInt( (AffixTotals.NumTotalMax > AffixTotals.NumTotal) ? AffixTotals.NumTotalMax : AffixTotals.NumTotal)
	AffixTotals.NumTotalMax := NumTotalAffixesMax
	; We need to call this function a second time because now we know the AffixCount.
	ParseItemName(ItemData.NamePlate, ItemName, ItemBaseName, NumTotalAffixes, ItemData)
	Item.BaseName := ItemBaseName
	
	pseudoMods := PreparePseudoModCreation(ItemData.Affixes, Item.Implicit, RarityLevel, Item.isMap)
	fracturedModsCount :=  ; can't be reliably determined that easily since a hybrid mod (which counts as as single ractured mod) gets displayed as two fractured mods in the item data
	
	; Start assembling the text for the tooltip
	TT := Item.Name
	
	If (Item.BaseName && (Item.BaseName != Item.Name))
	{
		TT := TT . "`n" . Item.BaseName
	}
	
	If (Item.IsGem) {			
		If (Item.GemColor) {
			TT := TT . "`nColor: " . Item.GemColor
		}
	}
	
	If (Item.IsCurrency)
	{
		TT := TT . "`n" . CurrencyDetails
		return TT		; Skip everything else.
	}
	
	If (not (Item.IsMap or Item.IsCurrency or Item.IsDivinationCard))
	{
		TT := TT . "`n"
		TT := TT . ItemLevelWord . "   " . StrPad(Item.Level, 3, Side="left")
		
		If (Item.IsGem) {
			TT := TT . "`n"
			TT := TT . ItemXPWord . "   " . StrPad(Item.Experience "%", 3, Side="left")
		}
		
		If Item.IsTalisman {
			TT := TT . "`nTalisman Tier: " . StrPad(Item.TalismanTier, 2, Side="left")
		}
		If (Not Item.IsFlask)
		{
			;;Item.BaseLevel := CheckBaseLevel(Item.BaseName)
			
			;;Hixxie: fixed! Shows base level for any item rarity, rings/jewelry, etc
			If (Item.RarityLevel < 3)
			{
				Item.BaseLevel := CheckBaseLevel(Item.Name)
			}
			Else If (Item.IsUnidentified)
			{
				Item.BaseLevel := CheckBaseLevel(Item.Name)
			}
			Else
			{
				Item.BaseLevel := CheckBaseLevel(Item.BaseName)
			}
			
			If (Item.BaseLevel)
			{
				TT := TT . "     Base Level:   " . StrPad(Item.BaseLevel, 3, Side="left")
			}
		}
	}
	
	If (Item.IsWeapon or Item.IsArmour)
	{
		If (Item.Level >= 50){
			IlvlSocket := 6
		}
		Else If (Item.Level >= 35){
			IlvlSocket := 5
		}
		Else If (Item.Level >= 25){
			IlvlSocket := 4
		}
		Else If (Item.Level >= 2){
			IlvlSocket := 3
		}
		Else{
			IlvlSocket := 2
		}
		
		If (Item.IsFourSocket){
			Item.MaxSockets := 4
		}
		Else If (Item.IsThreeSocket){
			Item.MaxSockets := 3
		}
		Else If (Item.IsSingleSocket){
			Item.MaxSockets := 1
		}
		Else{
			Item.MaxSockets := 6
		}
		
		
		If (Not Item.IsRing or Item.IsUnsetRing)
		{
			TT := TT . "`n"
			TT := TT . "Max Sockets:    "
			
			If (IlvlSocket < Item.MaxSockets)
			{
				Item.MaxSockets := IlvlSocket
				TT := TT . Item.MaxSockets . " (ilvl impacts max!)"
			}
			Else
			{
				TT := TT . Item.MaxSockets
			}
		}
		
		If (Item.SocketString) {			
			TT := TT . "`n"
			TT := TT . "Sockets:        " . Item.SocketString
		}
		
		Item.MaxSocketsNormal := Item.MaxSockets - Item.AbyssalSockets	; poe.trade doesn't count abyssal sockets as "normal sockets"
	}
	
	If (Item.IsWeapon)
	{
		TT := TT . AssembleDamageDetails(ItemDataText)
	}
	
	If (Item.IsDivinationCard)
	{
		If (divinationCardList[Item.Name] != "")
		{
			CardDescription := divinationCardList[Item.Name]
		}
		Else
		{
			CardDescription := divinationCardList["Unknown Card"]
		}
		
		TT := TT . "`n--------`n" . CardDescription
	}

	If (Item.IsProphecy)
	{
		/*
		Restriction := StrLen(Item.DifficultyRestriction) > 0 ? Item.DifficultyRestriction : "None"
		TT := TT . "`n--------`nDifficulty Restriction: " Restriction
		*/
		TT .= AssembleProphecyDetails(Item.Name)
	}
	
	If (Item.IsMap)
	{
		Item.MapTier  := ParseMapTier(ItemDataText)
		Item.MapLevel := Item.MapTier + 67
		
		MapDescription := " (Tier: " Item.MapTier ", Level: " Item.MapLevel ")`n`n"
		
		If (Item.IsUnique)
		{
			MapDescription .= uniqueMapList[uniqueMapNameFromBase[Item.SubType]]
		}
		Else
		{
			If (RegExMatch(Item.SubType, "Shaped (.+ Map)", match))
			{
				MapDescription .= "Infos from non-shaped version:`n" mapList[match1]
			}
			Else
			{
				MapDescription .= mapList[Item.SubType]
			}
		}
		If (MapDescription)
		{
			TT .= MapDescription
			Metamorph := MapMetamorphMapToOrgan(Item.SubType)
			If (Metamorph) {
				TT .= "`n`nMetamorph organs (boss):`n    " Metamorph
			}			
		}
		
		If (RarityLevel > 1 and RarityLevel < 4 and Not Item.IsUnidentified)
		{
			AffixDetails := AssembleMapAffixes()
			MapAffixCount := AffixTotals.NumPrefixes + AffixTotals.NumSuffixes
			TT = %TT%`n`nMods (%MapAffixCount%):%AffixDetails%
			
			If (MapModWarnings)
			{
				TT = %TT%`n`nMod warnings:%MapModWarnings%
			}
			Else
			{
				TT = %TT%`n`nMod warnings:`nnone
			}
		}
	}
	
	If (Item.IsGem)
	{		
		If (gemQualityList[Item.Name] != "")
		{
			GemQualityDescription := gemQualityList[Item.Name]
		}
		Else
		{
			GemQualityDescription := gemQualityList["Unknown Gem"]
		}
		
		TT := TT . "`nQuality 20%:`n" . GemQualityDescription
	}
	
	If (Item.IsBeast)
	{
		return TT
	}
	
	If (RarityLevel > 1 and RarityLevel < 4)
	{
		; Append affix info if rarity is greater than normal (white)
		; Affix total statistic
		If (Itemdata.Rarity = "Magic"){
			PrefixLimit := 1
			SuffixLimit := 1
		} Else {
			PrefixLimit := 3
			SuffixLimit := 3
		}
		
		WordPrefixes := NumPrefixesMax > PrefixLimit ? "?! " : " "	; Turns "2-4 Prefixes" into "2-4?! Prefixes"
		WordSuffixes := NumSuffixesMax > SuffixLimit ? "?! " : " "
		
		WordPrefixes .= NumPrefixesMax = 1 ? "Prefix" : "Prefixes"
		WordSuffixes .= NumSuffixesMax = 1 ? "Suffix" : "Suffixes"
		
		If (NumPrefixesMax = 0){
			PrefixText := ""
			PreSufComma := ""	; If there are no prefixes, we also don't want the comma.
		}
		Else If (NumPrefixes = NumPrefixesMax){
			PrefixText := NumPrefixes . WordPrefixes
			PreSufComma := ", "
		}
		Else{
			PrefixText := NumPrefixes "-" NumPrefixesMax . WordPrefixes
			PreSufComma := ", "
		}
		
		If (NumSuffixesMax = 0){
			SuffixText := ""
		}
		Else If (NumSuffixes = NumSuffixesMax){
			SuffixText := PreSufComma . NumSuffixes . WordSuffixes
		}
		Else{
			SuffixText := PreSufComma . NumSuffixes "-" NumSuffixesMax . WordSuffixes
		}
		
		TotalsText := NumTotalAffixes = NumTotalAffixesMax ? NumTotalAffixes : NumTotalAffixes "-" NumTotalAffixesMax
		
		If (NumTotalAffixes > 0 and Not Item.IsUnidentified and Not Item.IsMap)
		{
			TT = %TT%`n--------`nAffixes (%TotalsText%): %PrefixText%%SuffixText%
		}
	}
	
	If (Item.hasImplicit and not Item.IsUnique) {
		ImplicitTooltip := ""
		ImplicitValueArray := LookupImplicitValue(Item.BaseName)
		
		maxIndex 	:= Item.Implicit.MaxIndex()
		TextLineWidth := ImplicitValueArray.MaxIndex() and StrLen(ImplicitValueArray[1]) ? 20 : 50
		Ellipsis := Opts.AffixTextEllipsis
		
		Loop, % maxIndex {
			ImplicitText := Item.Implicit[A_Index]
			If (StrLen(ImplicitText) > TextLineWidth)
				{
					ImplicitText := SubStr(ImplicitText, 1, TextLineWidth - StrLen(Ellipsis))  Ellipsis
				}
				Else
				{
					ImplicitText := StrPad(ImplicitText, TextLineWidth)
				}
			ImplicitTooltip .= "`n" ImplicitText "  " StrPad(ImplicitValueArray[A_Index], 5, "left")
		}
		TT = %TT%`n--------%ImplicitTooltip%
	}
	
	If (RarityLevel > 1 and RarityLevel < 4)
	{
		If (Not (Item.IsUnidentified or Item.IsMap))
		{
			AffixDetails := AssembleAffixDetails()
			
			TT = %TT%`n--------%AffixDetails%
		}
	}
	
	Else If (ItemData.Rarity == "Unique" and not Item.IsMetamorphSample)
	{
		If (FindUnique(Item.Name) == False and Not Item.IsUnidentified)
		{
			TT = %TT%`n--------`nUnique item currently not supported
		}
		Else If (Not Item.IsUnidentified)
		{
			ParseUnique(Item.Name)
			AffixDetails := AssembleAffixDetails()
			TT = %TT%`n--------%AffixDetails%
		}
	}
	
	If (Item.IsMetamorphSample) {
		Metamorph := MapMetamorphOrganToMap(Item.Name)	; object
		TT .= "`n--------`n" . "Where to find this organ type, sorted by number of additional types of organs in the drop pool: `n" Metamorph.sorted
	}

	If (pseudoMods.Length())
	{
		TT = %TT%`n--------
		For key, val in pseudoMods
		{
			pseudoMod := "(pseudo) " val.name_orig
			TT = %TT%`n%pseudoMod%
		}
	}
	
	If (Item.IsUnidentified and (Item.Name != "Scroll of Wisdom") and Not Item.IsMap)
	{
		TT = %TT%`n--------`nUnidentified
	}
	
	If (UniqueHasFatedVariant(Item.Name))
	{
		TT = %TT%`n--------`nHas Fated Variant
	}
	
	If (Item.IsMirrored)
	{
		TT = %TT%`n--------`nMirrored
	}
	
	If (Opts.ShowExplanationForUsedNotation)
	{
		Notation := ""
		
		If (RegExMatch(AffixDetails, "(HybP|HybS)")){
			Notation .= "`n Hyb: Hybrid. One mod with two parts in two lines."
		}
		If (RegExMatch(AffixDetails, "HDP")){
			Notation .= "`n HDP: Hybrid Defence Prefix. Flat Def on Hybrid Base Armour."
		}
		If (RegExMatch(AffixDetails, "(CrP|CrS)")){
			Notation .= "`n Cr: Craft. Master tiers not in yet, treated as normal mod."
		}
		matchpattern := "\d\" Opts.DoubleRangeSeparator "\d"
		If (RegExMatch(AffixDetails, matchpattern)){
			Notation .= "`n a-b" Opts.DoubleRangeSeparator "c-d: For added damage mods. (a-b) to (c-d)"
		}
		matchpattern := "\d\" Opts.MultiTierRangeSeparator "\d"
		If (RegExMatch(AffixDetails, matchpattern)){
			Notation .= "`n a-b" Opts.MultiTierRangeSeparator "c-d: Multi tier uncertainty. WorstCaseRange" Opts.MultiTierRangeSeparator "BestCaseRange"
		}
		
		If (Itemdata.SpecialCaseNotation != "")
		{
			Notation .= "`n" Itemdata.SpecialCaseNotation
		}
		
		If (Notation)
		{
			TT .= "`n--------`nNotation:" Notation
		}
	}

	; parsing end
	return TT
}

GetNegativeAffixOffset(Item)
{
	; Certain item types have descriptive text lines at the end,
	; so decrement item index to get to the affix lines.
	NegativeAffixOffset := 0
	If (Item.IsFlask)
	{
		NegativeAffixOffset += 1
	}
	If (Item.IsUnique)
	{
		NegativeAffixOffset += 1
	}
	If (Item.IsTalisman)
	{
		NegativeAffixOffset += 1
	}
	If (Item.IsMap)
	{
		NegativeAffixOffset += 1
	}
	If (Item.IsJewel)
	{
		NegativeAffixOffset += 1
	}
	If (Item.HasEffect)
	{
		NegativeAffixOffset += 1
	}
	If (Item.IsCorrupted)
	{
		NegativeAffixOffset += 1
	}
	If (Item.IsElderBase or Item.IsShaperBase or Item.IsSynthesisedBase or Item.IsFracturedBase or Item.IsCrusaderBase or Item.IsHunterBase or Item.IsWarlordBase or Item.IsRedeemerBase)
	{
		NegativeAffixOffset += 1
	}
	If (Item.IsMirrored)
	{
		NegativeAffixOffset += 1
	}
	If (RegExMatch(Item.Name, "i)Tabula Rasa")) ; no mods, no flavour text
	{
		NegativeAffixOffset -= 2
	}	
	return NegativeAffixOffset
}

; ### TODO: Fix issue for white items, currently receiving duplicate infos (affixes and implicit containing the same line)
; Prepare item affixes to create pseudo mods, taken from PoE-TradeMacro
; Moved from TradeMacro to ItemInfo to avoid duplicate code, please be careful with any changes
PreparePseudoModCreation(Affixes, Implicit, Rarity, isMap = false) {
	; ### TODO: remove blank lines ( rare cases, maybe from crafted mods )

	mods := []
	; ### Append Implicits if any
	modStrings := Implicit
	For i, modString in modStrings {
		tempMods := ModStringToObject(modString, true)
		For i, tempMod in tempMods {
			If (tempMod.name) {
				mods.push(tempMod)
			}
		}
	}

	; ### Convert affix lines to mod objects
	If (Rarity > 1) {
		modStrings := StrSplit(Affixes, "`n")
		For i, modString in modStrings {
			tempMods := ModStringToObject(modString, false)
			For i, tempMod in tempMods {
				If (tempMod.name) {
					mods.push(tempMod)
				}
			}
		}
	}

	; return only pseudoMods, this is changed from PoE-TradeMacro where all mods are returned.
	mods := CreatePseudoMods(mods)

	Return mods
}

; Convert mod strings to objects while separating combined mods like "+#% to Fire and Lightning Resitances"
; Moved from TradeMacro to ItemInfo to avoid duplicate code, please be careful with any changes
ModStringToObject(string, isImplicit) {
	StringReplace, val, string, `r,, All
	StringReplace, val, val, `n,, All
	values := []

	RegExMatch(val, "i) \((fractured|crafted|enchant)\)$", sType)
	spawnType := sType1
	
	val := RegExReplace(val, "i) \((fractured|crafted|enchant)\)$")

	; Collect all numeric values in the mod-string
	Pos        := 0
	While Pos := RegExMatch(val, "i)(-?[.0-9]+)", value, Pos + (StrLen(value) ? StrLen(value) : 1)) {
		values.push(value)
	}

	; Collect all resists/attributes that are combined in one mod
	Matches := []

	If (RegexMatch(val, "i)to (Strength|Dexterity|Intelligence) and (Strength|Dexterity|Intelligence)$", attribute)) {
		IF ( attribute1 AND attribute2 ) {
			Matches.push(attribute1)
			Matches.push(attribute2)
		}
	}

	type := ""
	; Matching "x% fire and cold resistance" or "x% to cold resist", excluding "to maximum cold resistance" and "damage penetrates x% cold resistance" and minion/totem related mods
	If (RegExMatch(val, "i)to ((cold|fire|lightning)( and (cold|fire|lightning))?) resistance") and not RegExMatch(val, "i)Minion|Totem|Enemies")) {
		type := "Resistance"
		If (RegExMatch(val, "i)fire")) {
			Matches.push("Fire")
		}
		If (RegExMatch(val, "i)cold")) {
			Matches.push("Cold")
		}
		If (RegExMatch(val, "i)lightning")) {
			Matches.push("Lightning")
		}
	}
	; Matching "x% fire/cold/lgitning and chaos resistance"
	If (RegExMatch(val, "i)to (cold|fire|lightning) and (chaos) resistance") and not RegExMatch(val, "i)Minion|Totem|Enemies")) {
		type := "Resistance"
		If (RegExMatch(val, "i)fire")) {
			Matches.push("Fire")
		}
		If (RegExMatch(val, "i)cold")) {
			Matches.push("Cold")
		}
		If (RegExMatch(val, "i)lightning")) {
			Matches.push("Lightning")
		}
		If (RegExMatch(val, "i)chaos")) {
			Matches.push("Chaos")
		}
	}

	; Vanguard Belt implicit for example (flat AR + EV)
	If (RegExMatch(val, "i)([.0-9]+) to (Armour|Evasion Rating|Energy Shield) and (Armour|Evasion Rating|Energy Shield)")) {
		type := "Defence"
		If (RegExMatch(val, "i)Armour")) {
			Matches.push("Armour")
		}
		If (RegExMatch(val, "i)Evasion Rating")) {
			Matches.push("Evasion Rating")
		}
		If (RegExMatch(val, "i)Energy Shield")) {
			Matches.push("Energy Shield")
		}
	}

	; Create single mod from every collected resist/attribute
	Loop % Matches.Length() {
		RegExMatch(val, "i)(Resistance)", match)
		; differentiate between negative and positive values; flat and increased attributes
		sign := "+"
		type := RegExMatch(val, "i)increased", inc) ? "% increased " : " to "
		If (inc) {
			sign := ""
		}
		If (RegExMatch(val, "i)^-")) {
			sign := "-"
		}
		Matches[A_Index] := match1 ? sign . "#% to " . Matches[A_Index] . " " . match1 : sign . "#" . type . "" . Matches[A_Index]
	}

	If (RegExMatch(val, "i)to all attributes|to all elemental (Resistances)", match) and not RegExMatch(val, "i)Minion|Totem|Enemies")) {
		resist := match1 ? true : false
		Matches[1] := resist ? "+#% to Fire Resistance" : "+# to Strength"
		Matches[2] := resist ? "+#% to Lightning Resistance" : "+# to Intelligence"
		Matches[3] := resist ? "+#% to Cold Resistance" : "+# to Dexterity"
	}

	; Use original mod-string if no combination is found
	Matches[1] := Matches.Length() > 0 ? Matches[1] : val

	;
	arr := []
	Loop % (Matches.Length() ? Matches.Length() : 1) {
		temp := {}		
		temp.name_orig := Matches[A_Index]
		Loop {
			temp.name_orig := RegExReplace(temp.name_orig, "-?#", values[A_Index], Count, 1)
			If (!Count) {
				break
			}
		}

		temp.values	:= values
		; mods with negative values inputted in the value fields are not supported on poe.trade, so searching for "-1 maximum charges/frenzy charges" is not possible
		; unless there is a mod "-# maximum charges"
		
		; some values shouldn't be replaced because they are fixed, for example "#% chance to gain Onslaught for 4 seconds on Kill"
		; regex, | delimited
		exceptionsList := "recovered every 3 seconds|inflicted with this Weapon to deal 100% more Damage|with 30% reduced Movement Speed|chance to Recover 10% of Maximum Mana|"
		exceptionsList .= "for 3 seconds|for 4 seconds|for 8 seconds|for 10 seconds|over 4 seconds|"
		exceptionsList .= "per (10|12|15|16|50) (Strength|Dexterity|Intelligence)|"
		exceptionsList .= "per 200 Accuracy Rating|if you have at least 500 Strength|per 1% Chance to Block Attack Damage|are at least 5 nearby Enemies|a total of 200 Mana"		
		
		RegExMatch(Matches[A_Index], "i)(" exceptionsList ")", exception) 
		
		s := RegExReplace(Matches[A_Index], "i)(-?)[.0-9]+", "$1#")
		
		; restore certain mod line parts if there are exceptions
		If (exception) {
			replacer_reg := RegExReplace(exception, "i)(-?)[.0-9]+", "(#)")
			s := RegExReplace(s, "i)" replacer_reg "", exception)
		}
		
		temp.name		:= RegExReplace(s, "i)# ?to ? #", "#", isRange)
		temp.isVariable:= false
		If (StrLen(spawnType)) {
			temp.spawnType := spawnType	
		}
		temp.type		:= (isImplicit and Matches.Length() <= 1) ? "implicit" : "explicit"
		arr.push(temp)
	}

	Return arr
}

; Moved from TradeMacro to ItemInfo to avoid duplicate code, please be careful with any changes
CreatePseudoMods(mods, returnAllMods := False) {
	tempMods := []
	lifeFlat := 0
	manaFlat := 0
	energyShieldFlat := 0
	energyShieldPercent := 0
	energyShieldPercentGlobal := 0
	evasionRatingPercentGlobal := 0

	rarityItemsFoundPercent := 0

	accuracyRatingFlat := 0
	globalCritChancePercent := 0
	globalCritMultiplierPercent := 0
	critChanceForSpellsPercent := 0

	spellDmg_Percent := 0
	attackDmg_Percent := 0

	; Attributes
	strengthFlat := 0
	dexterityFlat := 0
	intelligenceFlat := 0
	allAttributesFlat := 0
	strengthPercent := 0
	dexterityPercent := 0
	intelligencePercent := 0
	allAttributesPercent := 0

	; Resistances
	coldResist := 0
	fireResist := 0
	lightningResist := 0
	chaosResist := 0
	toAllElementalResist := 0

	; Damages
	meleePhysDmgGlobal_Percent := 0

	dmgTypes := ["elemental", "fire", "cold", "lightning"]
	For key, type in dmgTypes {
		%type%Dmg_Percent := 0
		%type%Dmg_AttacksPercent := 0
		%type%Dmg_SpellsPercent := 0
		%type%Dmg_AttacksFlatLow := 0
		%type%Dmg_AttacksFlatHi := 0
		%type%Dmg_SpellsFlatLow := 0
		%type%Dmg_SpellsFlatHi := 0
		%type%Dmg_FlatLow := 0
		%type%Dmg_FlatHi := 0
	}

	/* BREAKPOINT
	; ########################################################################
	; ###	Combine values from mods of same types
	; ###		- also assign simplifiedName to the found mod for easier comparison later without duplicating precious regex
	; ########################################################################
	*/

	; Note that at this point combined mods/attributes have already been separated into two mods
	; like '+ x % to fire and lightning resist' would be '+ x % to fire resist' AND '+ x % to lightning resist' as 2 different mods
	For key, mod in mods {
		RegExMatch(mod.name, "i) \((fractured|crafted|enchant)\)$", spawnType)
		If (StrLen(spawnType1)) {
			mod.spawnType := spawnType1	
		}		
		
		mod.name := RegExReplace(mod.name, "i) \((fractured|crafted|enchant)\)$")
		
		; ### Base stats
		; life and mana
		If (RegExMatch(mod.name, "i)to maximum (Life|Mana)$", stat)) {
			%stat1%Flat := %stat1%Flat + mod.values[1]
			mod.simplifiedName := "xToMaximum" stat1
		}
		; flat energy shield
		Else If (RegExMatch(mod.name, "i)to maximum Energy Shield$")) {
			energyShieldFlat := energyShieldFlat + mod.values[1]
			mod.simplifiedName := "xToMaximumEnergyShield"
		}
		; percent energy shield
		Else If (RegExMatch(mod.name, "i)increased maximum Energy Shield$")) {
			energyShieldPercent := energyShieldPercent + mod.values[1]
			mod.simplifiedName := "xIncreasedMaximumEnergyShield"
		}

		; ### Items found
		; rarity
		Else If (RegExMatch(mod.name, "i)increased Rarity of items found$")) {
			rarityItemsFoundPercent := rarityItemsFoundPercent + mod.values[1]
			mod.simplifiedName := "xIncreasedRarityOfItemsFound"
		}

		; ### crits
		Else If (RegExMatch(mod.name, "i)increased Global Critical Strike Chance$")) {
			globalCritChancePercent := globalCritChancePercent + mod.values[1]
			mod.simplifiedName := "xIncreasedGlobalCriticalChance"
		}
		Else If (RegExMatch(mod.name, "i)to Global Critical Strike Multiplier$")) {
			globalCritMultiplierPercent := globalCritMultiplierPercent + mod.values[1]
			mod.simplifiedName := "xIncreasedGlobalCriticalMultiplier"
		}
		Else If (RegExMatch(mod.name, "i)increased Critical Strike Chance for Spells$")) {
			critChanceForSpellsPercent := critChanceForSpellsPercent + mod.values[1]
			mod.simplifiedName := "xIncreasedCriticalSpells"
		}

		; ### Attributes
		; all flat attributes
		Else If (RegExMatch(mod.name, "i)to All Attributes$")) {
			allAttributesFlat := allAttributesFlat + mod.values[1]
			mod.simplifiedName := "xToAllAttributes"
		}
		; single flat attributes
		Else If (RegExMatch(mod.name, "i)to (Intelligence|Dexterity|Strength)$", attribute)) {
			%attribute1%Flat := %attribute1%Flat + mod.values[1]
			mod.simplifiedName := "xTo" . attribute1
		}
		; % increased attributes
		Else If (RegExMatch(mod.name, "i)increased (Intelligence|Dexterity|Strength)$", attribute)) {
			%attribute1%Percent := %attribute1%Percent + mod.values[1]
			mod.simplifiedName := "xIncreased" . attribute1 . "Percentage"
		}

		; ### Resistances
		; % to all resistances ( careful about 'max all resistances' )
		Else If (RegExMatch(mod.name, "i)to all Elemental Resistances$") and not RegExMatch(mod.name, "i)Minion|Totem|Enemies")) {
			toAllElementalResist := toAllElementalResist + mod.values[1]
			mod.simplifiedName := "xToAllElementalResistances"
		}
		; % to base resistances
		Else If (RegExMatch(mod.name, "i)to (Cold|Fire|Lightning|Chaos) Resistance$", resistType) and not RegExMatch(mod.name, "i)Minion|Totem|Enemies")) {
			%resistType1%Resist := %resistType1%Resist + mod.values[1]
			mod.simplifiedName := "xTo" resistType1 "Resistance"
		}
		Else If (RegExMatch(mod.name, "i)to (Cold|Fire|Lightning) and (Chaos) Resistances$") and not RegExMatch(mod.name, "i)Minion|Totem|Enemies")) {
			%resistType1%Resist := %resistType1%Resist + mod.values[1]
			mod.simplifiedName := "xTo" resistType1 "Resistance"
			
			chaosResist := chaosResist + mod.values[1]
			mod.simplifiedName := "xToChaosResistance"
		}

		; ### Percent damages
		; % increased elemental damage
		Else If (RegExMatch(mod.name, "i)increased (Cold|Fire|Lightning|Elemental) damage$", element)) {
			%element1%Dmg_Percent := %element1%Dmg_Percent + mod.values[1]
			mod.simplifiedName := "xIncreased" element1 "Damage"
		}
		; % elemental damage with weapons
		Else If (RegExMatch(mod.name, "i)(Cold|Fire|Lightning|Elemental) damage with attack skills", element)) {
			%element1%Dmg_AttacksPercent := %element1%Dmg_AttacksPercent + mod.values[1]
			mod.simplifiedName := "xIncreased" element1 "DamageAttacks"
		}

		; ### Flat Damages
		; flat 'element' damage; source: weapons
		Else If (RegExMatch(mod.name, "i)adds .* (Cold|Fire|Lightning|Elemental) damage$", element)) {
			element := element1
			%element%Dmg_FlatLow := %element%Dmg_FlatLow + mod.values[1]
			%element%Dmg_FlatHi  := %element%Dmg_FlatHi  + mod.values[2]
			mod.simplifiedName := "xFlat" element "Damage"
		}
		; flat 'element' damage; source: various (wands/rings/amulets etc)
		Else If (RegExMatch(mod.name, "i)adds .* (Cold|Fire|Lightning|Elemental) damage to (Attacks|Spells)$", element)) {
			%element1%Dmg_%element2%FlatLow := %element1%Dmg_%element2%FlatLow + mod.values[1]
			%element1%Dmg_%element2%FlatHi  := %element1%Dmg_%element2%FlatHi  + mod.values[2]
			ElementalDmg_%element2%FlatLow  += %element1%Dmg_%element2%FlatLow
			ElementalDmg_%element2%FlatHi   += %element1%Dmg_%element2%FlatHi
			mod.simplifiedName := "xFlat" element1 "Damage" element2
		}
		; this would catch any * Spell * Damage * ( we might need to be more precise here )
		Else If (RegExMatch(mod.name, "i)spell") and RegExMatch(mod.name, "i)damage") and not RegExMatch(mod.name, "i)chance|multiplier")) {
			spellDmg_Percent := spellDmg_Percent + mod.values[1]
			mod.simplifiedName := "xIncreasedSpellDamage"
		}

		; ### remaining mods that can be derived from attributes (str|dex|int)
		; flat accuracy rating
		Else If (RegExMatch(mod.name, "i)to accuracy rating$")) {
			accuracyRatingFlat := accuracyRatingFlat + mod.values[1]
		}
	}

	/* BREAKPOINT
	; ########################################################################
	; ###	Spread global values to their sub element
	; ### 	- like % all Elemental to the base elementals
	; ########################################################################
	*/

	; ### Attributes
	; flat attributes
	If (allAttributesFlat) {
		strengthFlat		:= strengthFlat + allAttributesFlat
		dexterityFlat		:= dexterityFlat + allAttributesFlat
		intelligenceFlat 	:= intelligenceFlat + allAttributesFlat
	}

	; spread attributes to their corresponding stats they give
	If (strengthFlat) {
		lifeFlat := lifeFlat + Floor(strengthFlat/2)
		meleePhysDmgGlobal_Percent := meleePhysDmgGlobal_Percent + Floor(strengthFlat/5)
	}
	If (intelligenceFlat) {
		manaFlat := manaFlat + Floor(intelligenceFlat/2)
		energyShieldPercentGlobal := Floor(intelligenceFlat/5)
	}
	If (dexterityFlat) {
		accuracyRatingFlat := accuracyRatingFlat + Floor(dexterityFlat*2)
		evasionRatingPercentGlobal := Floor(dexterityFlat/5)
	}

	; ###  Elemental Damage - % increased
	fireDmg_Percent	:= fireDmg_Percent + elementalDmg_Percent
	coldDmg_Percent	:= coldDmg_Percent + elementalDmg_Percent
	lightningDmg_Percent:= lightningDmg_Percent + elementalDmg_Percent

	; ### Elemental damage - attack skills % increased
	; ### - spreads Elemental damage with attack skills to each 'element' damage with attack skills and adds related % increased 'element' damage
	fireDmg_AttacksPercent      	:= fireDmg_AttacksPercent + elementalDmg_AttacksPercent + fireDmg_Percent
	coldDmg_AttacksPercent		:= coldDmg_AttacksPercent + elementalDmg_AttacksPercent + coldDmg_Percent
	lightningDmg_AttacksPercent	:= lightningDmg_AttacksPercent + elementalDmg_AttacksPercent + lightningDmg_Percent

	; ### Elemental damage - Spells % increased
	; ### - spreads % spell damage to each % 'element' spell damage and adds related % increased 'element' damage
	fireDmg_SpellsPercent 		:= fireDmg_SpellsPercent + spellDmg_Percent + fireDmg_Percent
	coldDmg_SpellsPercent 		:= coldDmg_SpellsPercent + spellDmg_Percent + coldDmg_Percent
	lightningDmg_SpellsPercent	:= lightningDmg_SpellsPercent + spellDmg_Percent + lightningDmg_Percent

	; ### Elemental Resistances
	; ### - spreads % to all Elemental Resistances to the base resist
	; ### - also calculates the totalElementalResistance and totalResistance
	totalElementalResistance := 0
	For i, element in ["Fire", "Cold", "Lightning"] {
		%element%Resist := %element%Resist + toAllElementalResist
		totalElementalResistance := totalElementalResistance + %element%Resist
	}
	totalResistance := totalElementalResistance + chaosResist

	/* BREAKPOINT
	; ########################################################################
	; ###	Generate ALL the pseudo mods from the non 0 values combined above
	; ###	- just remember the spreading logic above when assigning the temp mods inherited values references in possibleParentSimplifiedNames
	; ########################################################################
	*/

	; ### Generate Basic Stats pseudos
	If (lifeFlat > 0) {
		temp := {}
		temp.values		:= [lifeFlat]
		temp.name_orig		:= "+" . lifeFlat . " to maximum Life"
		temp.name			:= "+# to maximum Life"
		temp.simplifiedName	:= "xToMaximumLife"
		temp.exception		:= true
		temp.possibleParentSimplifiedNames := ["xToMaximumLife"]
		tempMods.push(temp)
	}
	If (manaFlat > 0) {
		temp := {}
		temp.values		:= [manaFlat]
		temp.name_orig		:= "+" . manaFlat . " to maximum Mana"
		temp.name			:= "+# to maximum Mana"
		temp.simplifiedName	:= "xToMaximumMana"
		temp.possibleParentSimplifiedNames := ["xToMaximumMana"]
		tempMods.push(temp)
	}
	If (energyShieldFlat > 0) {
		temp := {}
		temp.values		:= [energyShieldFlat]
		temp.name_orig		:= "+" . energyShieldFlat . " to maximum Energy Shield"
		temp.name			:= "+# to maximum Energy Shield"
		temp.simplifiedName	:= "xToMaximumEnergyShield"
		temp.possibleParentSimplifiedNames := ["xToMaximumEnergyShield"]
		tempMods.push(temp)
	}
	If (energyShieldPercent > 0) {
		temp := {}
		temp.values		:= [energyShieldPercent]
		temp.name_orig		:= energyShieldPercent . "% increased maximum Energy Shield"
		temp.name			:= "#% increased maximum Energy Shield"
		temp.simplifiedName	:= "xIncreasedMaximumEnergyShield"
		temp.possibleParentSimplifiedNames := ["xIncreasedMaximumEnergyShield"]
		tempMods.push(temp)
	}
	; ### Generate rarity item found pseudo
	If (rarityItemsFoundPercent > 0) {
		temp := {}
		temp.values		:= [rarityItemsFoundPercent]
		temp.name_orig		:= rarityItemsFoundPercent . "% increased Rarity of items found"
		temp.name			:= "#% increased Rarity of items found"
		temp.simplifiedName	:= "xIncreasedRarityOfItemsFound"
		temp.possibleParentSimplifiedNames := ["xIncreasedRarityOfItemsFound"]
		tempMods.push(temp)
	}
	; ### Generate crit pseudos
	If (globalCritChancePercent > 0) {
		temp := {}
		temp.values		:= [globalCritChancePercent]
		temp.name_orig		:= globalCritChancePercent . "% increased Global Critical Strike Chance"
		temp.name			:= "#% increased Global Critical Strike Chance"
		temp.simplifiedName	:= "xIncreasedGlobalCriticalChance"
		temp.possibleParentSimplifiedNames := ["xIncreasedGlobalCriticalChance"]
		tempMods.push(temp)
	}
	If (globalCritMultiplierPercent > 0) {
		temp := {}
		temp.values		:= [globalCritMultiplierPercent]
		temp.name_orig		:= "+" . globalCritMultiplierPercent . "% to Global Critical Strike Multiplier"
		temp.name			:= "+#% to Global Critical Strike Multiplier"
		temp.simplifiedName	:= "xIncreasedGlobalCriticalMultiplier"
		temp.possibleParentSimplifiedNames := ["xIncreasedGlobalCriticalMultiplier"]
		tempMods.push(temp)
	}
	If (critChanceForSpellsPercent > 0) {
		temp := {}
		temp.values		:= [critChanceForSpellsPercent]
		temp.name_orig		:= critChanceForSpellsPercent . "% increased Critical Strike Chance for Spells"
		temp.name			:= "#% increased Critical Strike Chance for Spells"
		temp.simplifiedName	:= "xIncreasedCriticalSpells"
		temp.possibleParentSimplifiedNames := ["xIncreasedCriticalSpells"]
		tempMods.push(temp)
	}
	; ### Generate Attributes pseudos
	For i, attribute in ["Strength", "Dexterity", "Intelligence"] {
		If ( %attribute%Flat > 0 ) {
			temp := {}
			temp.values		:= [%attribute%Flat]
			temp.name_orig		:= "+" .  %attribute%Flat . " to " .  attribute
			temp.name			:= "+# to " . attribute
			temp.simplifiedName	:= "xTo" attribute
			temp.possibleParentSimplifiedNames := ["xTo" attribute, "xToAllAttributes"]
			tempMods.push(temp)
		}
	}
	; cumulative all attributes mods
	If (allAttributesFlat > 0) {
		temp := {}
		temp.values		:= [allAttributesFlat]
		temp.name_orig		:= "+" . allAttributesFlat . " to all Attributes"
		temp.name			:= "+#% to all Attributes"
		temp.simplifiedName	:= "xToAllAttributes"
		temp.possibleParentSimplifiedNames := ["xToAllAttributes"]
		tempMods.push(temp)
	}

	; ### Generate Resists pseudos
	For i, element in ["Fire", "Cold", "Lightning"] {
		If ( %element%Resist > 0) {
			temp := {}
			temp.values		:= [%element%Resist]
			temp.name_orig		:= "+" %element%Resist "% to " element " Resistance"
			temp.name			:= "+#% to " element " Resistance"
			temp.simplifiedName	:= "xTo" element "Resistance"
			temp.possibleParentSimplifiedNames := ["xTo" element "Resistance", "xToAllElementalResistances"]
			temp.hideForTradeMacro := true
			tempMods.push(temp)
		}
	}
	If (toAllElementalResist > 0) {
		temp := {}
		temp.values		:= [toAllElementalResist]
		temp.name_orig		:= "+" . toAllElementalResist . "% to all Elemental Resistances"
		temp.name			:= "+#% to all Elemental Resistances"
		temp.simplifiedName	:= "xToAllElementalResistances"
		temp.exception		:= true
		temp.possibleParentSimplifiedNames := ["xToAllElementalResistances"]
		temp.hideForTradeMacro := true
		tempMods.push(temp)
	}
	; Note that total resistances are calculated values with no possible child mods, so they have no simplifiedName
	If (totalElementalResistance > 0) {
		temp := {}
		temp.values		:= [totalElementalResistance]
		temp.name_orig		:= "+" . totalElementalResistance . "% total Elemental Resistance"
		temp.name			:= "+#% total Elemental Resistance"
		temp.exception		:= true
		temp.possibleParentSimplifiedNames := ["xToFireResistance", "xToColdResistance", "xToLightningResistance", "xToAllElementalResistances"]
		tempMods.push(temp)
	}
	; without chaos resist, this would have the same value as totalElementalResistance
	If ((totalResistance > 0) AND (chaosResist > 0)) {
		temp := {}
		temp.values		:= [totalResistance]
		temp.name_orig		:= "+" . totalResistance . "% total Resistance"
		temp.name			:= "+#% total Resistance"
		temp.exception		:= true
		temp.possibleParentSimplifiedNames := ["xToFireResistance", "xToColdResistance", "xToLightningResistance", "xToAllElementalResistances", "xToChaosResistance"]
		tempMods.push(temp)
	}

	; ### Generate remaining pseudos derived from attributes
	If (meleePhysDmgGlobal_Percent > 0) {
		temp := {}
		temp.values		:= [meleePhysDmgGlobal_Percent]
		temp.name_orig		:= meleePhysDmgGlobal_Percent . "% increased Melee Physical Damage"
		temp.name			:= "#% increased Melee Physical Damage"
		temp.simplifiedName	:= "xIncreasedMeleePhysicalDamage"
		temp.possibleParentSimplifiedNames := ["xIncreasedMeleePhysicalDamage"]
		temp.hideForTradeMacro := true
		tempMods.push(temp)
	}
	If (energyShieldPercentGlobal > 0) {
		temp := {}
		temp.values		:= [energyShieldPercentGlobal]
		temp.name_orig		:= energyShieldPercentGlobal . "% increased Energy Shield (Global)"
		temp.name			:= "#% increased Energy Shield (Global)"
		temp.simplifiedName	:= "xIncreasedEnergyShieldPercentGlobal"
		temp.possibleParentSimplifiedNames := ["xIncreasedEnergyShieldPercentGlobal"]
		temp.hideForTradeMacro := true
		tempMods.push(temp)
	}
	If (evasionRatingPercentGlobal > 0) {
		temp := {}
		temp.values		:= [evasionRatingPercentGlobal]
		temp.name_orig		:= evasionRatingPercentGlobal . "% increased Evasion (Global)"
		temp.name			:= "#% increased Evasion (Global)"
		temp.simplifiedName	:= "xIncreasedEvasionRatingPercentGlobal"
		temp.possibleParentSimplifiedNames := ["xIncreasedEvasionRatingPercentGlobal"]
		temp.hideForTradeMacro := true
		tempMods.push(temp)
	}
	If (accuracyRatingFlat > 0) {
		temp := {}
		temp.values		:= [accuracyRatingFlat]
		temp.name_orig		:= "+" . accuracyRatingFlat . " to Accuracy Rating"
		temp.name			:= "+# to Accuracy Rating"
		temp.simplifiedName	:= "xToAccuracyRating"
		temp.possibleParentSimplifiedNames := ["xToAccuracyRating"]
		tempMods.push(temp)
	}

	; ### Generate Damages pseudos
	; spell damage global
	If (spellDmg_Percent > 0) {
		temp := {}
		temp.values		:= [spellDmg_Percent]
		temp.name_orig		:= spellDmg_Percent . "% increased Spell Damage"
		temp.name			:= "#% increased Spell Damage"
		temp.simplifiedName	:= "xIncreasedSpellDamage"
		temp.possibleParentSimplifiedNames := ["xIncreasedSpellDamage"]
		tempMods.push(temp)
	}

	; other damages
	percentDamageModSuffixes := [" Damage", " Damage with Attack Skills", " Spell Damage"]
	flatDamageModSuffixes    := ["", " to Attacks", " to Spells"]

	For i, element in dmgTypes {
		StringUpper, element, element, T

		For j, dmgType in ["", "Attacks",  "Spells"]	{
			; ### Percentage damages
			If (%element%Dmg_%dmgType%Percent > 0) {
				modSuffix := percentDamageModSuffixes[j]
				temp := {}
				temp.values		:= [%element%Dmg_%dmgType%Percent]
				temp.name_orig		:= %element%Dmg_%dmgType%Percent "% increased " element . modSuffix
				temp.name			:= "#% increased " element . modSuffix
				temp.simplifiedName	:= "xIncreased" element "Damage" dmgType
				temp.possibleParentSimplifiedNames := ["xIncreased" element "Damage" dmgType, "xIncreased" element "Damage"]
				( element != "Elemental" ) ? temp.possibleParentSimplifiedNames.push("xIncreasedElementalDamage" dmgType) : False
				( dmgType == "Spells" ) ? temp.possibleParentSimplifiedNames.push("xIncreasedSpellDamage") : False
				tempMods.push(temp)
			}
			; ### Flat damages
			If (%element%Dmg_%dmgType%FlatLow > 0 or %element%Dmg_%dmgType%FlatHi > 0) {
				modSuffix := flatDamageModSuffixes[j]
				temp := {}
				temp.values		:= [%element%Dmg_%dmgType%FlatLow, %element%Dmg_%dmgType%FlatHi]
				temp.name_orig		:= "Adds " %element%Dmg_%dmgType%FlatLow " to " %element%Dmg_%dmgType%FlatHi " " element " Damage" modSuffix
				temp.name			:= "Adds # " element " Damage" modSuffix
				temp.simplifiedName	:= "xFlat" element "Damage" dmgType
				temp.possibleParentSimplifiedNames := ["xFlat" element "Damage" dmgType]
				If (element != "Elemental") {
					temp.possibleParentSimplifiedNames.push("xFlatElementalDamage" dmgType)
				} Else {
					temp.possibleParentSimplifiedNames := []
					For e, el in dmgTypes {
						StringUpper, upperEl, el, T
						temp.possibleParentSimplifiedNames.push("xFlat" upperEl "Damage" dmgType)
					}
				}
				tempMods.push(temp)
			}
		}
	}

	/* BREAKPOINT
	; ########################################################################
	; ###	Filter/Remove unwanted pseudos
	; ###	Only keep pseudos with values higher than other related mods
	; ###	TODO:	Improve/Simplify this part, so far I just copy/pasted code and doing ALMOST the same thing in each loop
	; ###			We could exit inner loop as soon as higher is set to false, I'll check the docs later
	; ########################################################################
	*/

	; This 1st pass is for TradeMacro
	; remove pseudos that are shadowed by an original mod ONLY if they have the same name
	; inherited values not taken into account for this 1st pass
	; ex ( '25% increased Cold Spell Damage' is shadowed by '%25 increased Spell Damage' ) BUT don't have same name

	allPseudoMods := []
	For i, tempMod in tempMods {
		higher := true
		For j, mod in mods {
			; check for mods with same name
			; Eruyome: Is there any reason to use simplifiedName here? This can fail for pseudo mods like total ele resists
			; Eruyome: It's possible to match empty simplified names and compare the values of different mods with each other that way

			;If ( tempMod.simplifiedName == mod.simplifiedName ) {
			If ( tempMod.name == mod.name ) {
				; check if it's a flat damage mod
				If (mod.values[2]) {
					mv := Round((mod.values[1] + mod.values[2]) / 2, 3)
					tv := Round((tempMod.values[1] + tempMod.values[2]) / 2, 3)
					If (tv <= mv) {
						higher := false
					}
				}
				Else {
					If (tempMod.values[1] <= mod.values[1]) {
						higher := false
					}
				}
			}
		}
		; add the tempMod to pseudos if it has greater values, or no parent
		If (higher or (tempMod.exception and returnAllMods)) {
			tempMod.isVariable:= false
			tempMod.type := "pseudo"
			allPseudoMods.push(tempMod)
		}
	}

	; 2nd pass
	; now we remove pseudos that are shadowed by an original mod they inherited from
	; ex ( '25% increased Cold Spell Damage' is shadowed by '%25 increased Spell Damage' )
	tempPseudoMods := []
	For i, tempMod in allPseudoMods {
		higher := true
		For j, mod in mods {
			; check if it's a parent mod
			isParentMod := false
			For k, simplifiedName in tempMod.possibleParentSimplifiedNames {
				If (mod.simplifiedName == simplifiedName) {
					isParentMod := true
					; TODO: match found we could exit loop here
				}
			}
			If ( isParentMod ) {
				; check if it's a flat damage mod
				If (mod.values[2]) {
					mv := Round((mod.values[1] + mod.values[2]) / 2, 3)
					tv := Round((tempMod.values[1] + tempMod.values[2]) / 2, 3)
					If (tv <= mv) {
						higher := false
					}
				}
				Else {
					If (tempMod.values[1] <= mod.values[1]) {
						higher := false
					}
				}
			}
		}
		; add the tempMod to pseudos if it has greater values, or no parent
		If (higher or (tempMod.exception and returnAllMods)) {
			tempMod.isVariable:= false
			tempMod.type := "pseudo"
			tempPseudoMods.push(tempMod)
		}
	}

	; 3rd Pass
	; same logic as above but compare pseudo with other pseudos
	; remove pseudos that are shadowed by another pseudo
	; ex ( '25% increased Cold Spell Damage' is shadowed by '%25 increased Spell Damage' )
	; must also avoid removing itself

	pseudoMods := []
	For i, tempPseudoA in tempPseudoMods {
		higher := true
		For j, tempPseudoB in tempPseudoMods {
			; skip if its the same object
			If ( i != j ) {
				; check if it's a parent mod
				isParentMod := false
				For k, simplifiedName in tempPseudoA.possibleParentSimplifiedNames {
					if (tempPseudoB.simplifiedName == simplifiedName) {
						isParentMod := true
						; TODO: match found we could exit loop here
					}
				}
				If ( isParentMod ) {
					; check if it's a flat damage mod
					If (tempPseudoB.values[2]) {
						mv := Round((tempPseudoB.values[1] + tempPseudoB.values[2]) / 2, 3)
						tv := Round((tempPseudoA.values[1] + tempPseudoA.values[2]) / 2, 3)
						If (tv <= mv) {
							higher := false
						}
					}
					Else {
						If (tempPseudoA.values[1] <= tempPseudoB.values[1]) {
							higher := false
						}
					}
				}
			}
		}
		; add the tempMod to pseudos if it has greater values, or no parent
		If (higher) {
			tempPseudoA.isVariable:= false
			tempPseudoA.type := "pseudo"
			pseudoMods.push(tempPseudoA)
		}
	}

	; ### This is mostly for TradeMacro
	; returns all original mods and the pseudo mods if requested
	If (returnAllMods) {
		returnedMods := mods
		For i, mod in pseudoMods {
			returnedMods.push(mod)
		}
		Return returnedMods
	}

	Return pseudoMods
}

ChangeTooltipColorByItem(conditionalColors = false) {
	Global Opts, Item
	
	_rarity	:= Item.RarityLevel
	_type	:= Item.BaseType
	
	If (conditionalColors) {
		If (_rarity = 4) {
			_bColor	:= "af5f1c"
			_bOpacity	:= 90
		} Else If (_rarity = 3) {
			_bColor	:= "b3931e"
			_bOpacity	:= 90
		} Else If (_rarity = 2) {
			_bColor	:= "8787fe"
			_bOpacity	:= 90
		} Else If (_rarity = 1) {
			_bColor	:= "9c9285"
			_bOpacity	:= 90
		} Else If (_type = "Gem") {
			_bColor	:= "608376"
			_bOpacity	:= 90
		} Else If (_type = "Prophecy") {
			_bColor	:= "b547fe"
			_bOpacity	:= 90
		} Else If (Item.IsCurrency or Item.IsEssence) {
			_bColor	:= "867951"
			_bOpacity	:= 90
		}	
	}

	If (not StrLen(_bColor) or not conditionalColors) {
		gdipTooltip.UpdateColors(Opts.GDIWindowColor, Opts.GDIWindowOpacity, Opts.GDIBorderColor, Opts.GDIBorderOpacity, Opts.GDITextColor, Opts.GDITextOpacity, 10, 16)	
	} Else {
		gdipTooltip.UpdateColors(Opts.GDIWindowColor, Opts.GDIWindowOpacity, _bColor, _bOpacity, Opts.GDITextColor, Opts.GDITextOpacity, 10, 16)	
	}
}

; Show tooltip, with fixed width font
ShowToolTip(String, Centered = false, conditionalColors = false)
{
	Global X, Y, ToolTipTimeout, Opts, gdipTooltip, Item
	
	; Get position of mouse cursor
	MouseGetPos, X, Y
	WinGet, PoEWindowHwnd, ID, ahk_group PoEWindowGrp
	RelativeToActiveWindow := true	; default tooltip behaviour 
	
	If (not RelativeToActiveWindow) {
		OldCoordMode := A_CoordModeToolTip
		CoordMode, Tooltip, Screen
	}
	
	If (Not Opts.DisplayToolTipAtFixedCoords)
	{
		If (Centered)
		{
			ScreenOffsetY := A_ScreenHeight / 2
			ScreenOffsetX := A_ScreenWidth / 2
			
			XCoord := 0 + ScreenOffsetX
			YCoord := 0 + ScreenOffsetY
			
			If (Opts.UseGDI)
			{
				ChangeTooltipColorByItem(conditionalColors)
				gdipTooltip.ShowGdiTooltip(Opts.FontSize, String, XCoord, YCoord, RelativeToActiveWindow, PoEWindowHwnd)
			}
			Else
			{
				ToolTip, %String%, XCoord, YCoord
				Fonts.SetFixedFont()
				Sleep, 10	
				ToolTip, %String%, XCoord, YCoord
			}
		}
		Else
		{
			XCoord := (X - 135 >= 0) ? X - 135 : 0
			YCoord := (Y +  35 >= 0) ? Y +  35 : 0

			If (Opts.UseGDI) 
			{
				ChangeTooltipColorByItem(conditionalColors)
				gdipTooltip.ShowGdiTooltip(Opts.FontSize, String, XCoord, YCoord, RelativeToActiveWindow, PoEWindowHwnd)
			}
			Else
			{
				ToolTip, %String%, XCoord, YCoord
				Fonts.SetFixedFont()
				Sleep, 10	
				ToolTip, %String%, XCoord, YCoord
			}
		}
	}
	Else
	{
		CoordMode, ToolTip, Screen
		ScreenOffsetY := Opts.ScreenOffsetY
		ScreenOffsetX := Opts.ScreenOffsetX
		
		XCoord := 0 + ScreenOffsetX
		YCoord := 0 + ScreenOffsetY
		
		If (Opts.UseGDI)
		{
			ChangeTooltipColorByItem(conditionalColors)
			gdipTooltip.ShowGdiTooltip(Opts.FontSize, String, XCoord, YCoord, RelativeToActiveWindow, PoEWindowHwnd, true)
		}
		Else
		{
			ToolTip, %String%, XCoord, YCoord
			Fonts.SetFixedFont()
			Sleep, 10
			ToolTip, %String%, XCoord, YCoord
		}
	}
	;Fonts.SetFixedFont()
	
	; Set up count variable and start timer for tooltip timeout
	ToolTipTimeout := 0
	SetTimer, ToolTipTimer, 100
	
	If (OldCoordMode) {
		CoordMode, Tooltip, % OldCoordMode
	}
}

; ############ GUI #############

GuiSet(ControlID, Param3="", SubCmd="")
{
	If (!(SubCmd == "")) {
		GuiControl, %SubCmd%, %ControlID%, %Param3%
	} Else {
		GuiControl,, %ControlID%, %Param3%
	}
}

GuiGet(ControlID, DefaultValue="", ByRef Error = false)
{
	curVal =
	ErrorLevel := 0
	GuiControlGet, curVal,, %ControlID%, %DefaultValue%
	Error := ErrorLevel	
	return curVal
}

GuiAdd(ControlType, Contents, PositionInfo, AssocVar="", AssocHwnd="", AssocLabel="", Param4="", GuiName="")
{
	Global
	Local av, ah, al
	av := StrPrefix(AssocVar, "v")
	al := StrPrefix(AssocLabel, "g")
	ah := StrPrefix(AssocHwnd, "hwnd")

	If (ControlType = "GroupBox") {
		Options := Param4 " cDA4F49 "
	}
	Else If (ControlType = "ListView") {
		Options := Param4
	}
	Else {
		Options := Param4 . " BackgroundTrans "
	}

	GuiName := (StrLen(GuiName) > 0) ? Trim(GuiName) . ":Add" : "Add"
	Gui, %GuiName%, %ControlType%, %PositionInfo% %av% %al% %ah% %Options%, %Contents%
}

GuiAddPicture(Contents, PositionInfo, AssocVar="", AssocHwnd="", AssocLabel="", Options="", GuiName="")
{
	GuiAdd("Picture", Contents, PositionInfo, AssocVar, AssocHwnd, AssocLabel, Options, GuiName)
}

GuiAddListView(ColumnHeaders, PositionInfo, AssocVar="", AssocHwnd="", AssocLabel="", Options="", GuiName="")
{	
	GuiAdd("ListView", ColumnHeaders, PositionInfo, AssocVar, AssocHwnd, AssocLabel, Options, GuiName)
}

GuiAddButton(Contents, PositionInfo, AssocLabel="", AssocVar="", AssocHwnd="", Options="", GuiName="")
{
	GuiAdd("Button", Contents, PositionInfo, AssocVar, AssocHwnd, AssocLabel, Options, GuiName)
}

GuiAddGroupBox(Contents, PositionInfo, AssocVar="", AssocHwnd="", AssocLabel="", Options="", GuiName="")
{
	GuiAdd("GroupBox", Contents, PositionInfo, AssocVar, AssocHwnd, AssocLabel, Options, GuiName)
}

GuiAddCheckbox(Contents, PositionInfo, CheckedState=0, AssocVar="", AssocHwnd="", AssocLabel="", Options="", GuiName="")
{
	GuiAdd("Checkbox", Contents, PositionInfo, AssocVar, AssocHwnd, AssocLabel, "Checked" . CheckedState . " " . Options, GuiName)
}

GuiAddText(Contents, PositionInfo, AssocVar="", AssocHwnd="", AssocLabel="", Options="", GuiName="")
{
	; static controls like Text need "0x0100" added to their options for the tooltip to work
	; either add it always here or don't forget to add it manually when using this function
	GuiAdd("Text", Contents, PositionInfo, AssocVar, AssocHwnd, AssocLabel, Options, GuiName)
}

GuiAddEdit(Contents, PositionInfo, AssocVar="", AssocHwnd="", AssocLabel="", Options="", GuiName="")
{
	GuiAdd("Edit", Contents, PositionInfo, AssocVar, AssocHwnd, AssocLabel, Options, GuiName)
}

GuiAddHotkey(Contents, PositionInfo, AssocVar="", AssocHwnd="", AssocLabel="", Options="", GuiName="")
{
	GuiAdd("Hotkey", Contents, PositionInfo, AssocVar, AssocHwnd, AssocLabel, Options, GuiName)
}

GuiAddDropDownList(Contents, PositionInfo, Selected="", AssocVar="", AssocHwnd="", AssocLabel="", Options="", GuiName="")
{
	; usage : add list items as a | delimited string, for example = "item1|item2|item3"
	ListItems := StrSplit(Contents, "|")
	Contents := ""
	Loop % ListItems.MaxIndex() {
		Contents .= Trim(ListItems[A_Index]) . "|"
		; add second | to mark pre-select list item
		If (Trim(ListItems[A_Index]) == Selected) {
			Contents .= "|"
		}
	}
	GuiAdd("DropDownList", Contents, PositionInfo, AssocVar, AssocHwnd, AssocLabel, Options, GuiName)
}

GuiUpdateDropdownList(Contents="", Selected="", AssocVar="", Options="", GuiName="") {
	GuiName := (StrLen(GuiName) > 0) ? Trim(GuiName) . ":" . AssocVar : "" . AssocVar

	If (StrLen(Contents) > 0) {
		; usage : add list items as a | delimited string, for example = "item1|item2|item3"
		ListItems := StrSplit(Contents, "|")
		; prepend the list with a pipe to re-create the list instead of appending it
		Contents := "|"
		Loop % ListItems.MaxIndex() {
			Contents .= Trim(ListItems[A_Index]) . "|"
			; add second | to mark pre-select list item
			If (Trim(ListItems[A_Index]) == Selected) {
				Contents .= "|"
			}
		}
		GuiControl, , %GuiName%, %Contents%
	}

	If (StrLen(Selected)) > 0 {
		; falls back to "ChooseString" if param3 is not an integer
		GuiControl, Choose, %GuiName% , %Selected%
	}
}

AddToolTip(con, text, Modify=0) {
	Static TThwnd, GuiHwnd
	TInfo =
	UInt := "UInt"
	Ptr := (A_PtrSize ? "Ptr" : UInt)
	PtrSize := (A_PtrSize ? A_PtrSize : 4)
	Str := "Str"
	; defines from Windows MFC commctrl.h
	WM_USER := 0x400
	TTM_ADDTOOL := (A_IsUnicode ? WM_USER+50 : WM_USER+4)           ; used to add a tool, and assign it to a control
	TTM_UPDATETIPTEXT := (A_IsUnicode ? WM_USER+57 : WM_USER+12)    ; used to adjust the text of a tip
	TTM_SETMAXTIPWIDTH := WM_USER+24                                ; allows the use of multiline tooltips
	TTF_IDISHWND := 1
	TTF_CENTERTIP := 2
	TTF_RTLREADING := 4
	TTF_SUBCLASS := 16
	TTF_TRACK := 0x0020
	TTF_ABSOLUTE := 0x0080
	TTF_TRANSPARENT := 0x0100
	TTF_PARSELINKS := 0x1000
	If (!TThwnd) {
		Gui, +LastFound
		GuiHwnd := WinExist()
		TThwnd := DllCall("CreateWindowEx"
					,UInt,0
					,Str,"tooltips_class32"
					,UInt,0
					,UInt,2147483648
					,UInt,-2147483648
					,UInt,-2147483648
					,UInt,-2147483648
					,UInt,-2147483648
					,UInt,GuiHwnd
					,UInt,0
					,UInt,0
					,UInt,0)
	}
	; TOOLINFO structure
	cbSize := 6*4+6*PtrSize
	uFlags := TTF_IDISHWND|TTF_SUBCLASS|TTF_PARSELINKS
	VarSetCapacity(TInfo, cbSize, 0)
	NumPut(cbSize, TInfo)
	NumPut(uFlags, TInfo, 4)
	NumPut(GuiHwnd, TInfo, 8)
	NumPut(con, TInfo, 8+PtrSize)
	NumPut(&text, TInfo, 6*4+3*PtrSize)
	NumPut(0,TInfo, 6*4+6*PtrSize)
	DetectHiddenWindows, On
	If (!Modify) {
		DllCall("SendMessage"
			,Ptr,TThwnd
			,UInt,TTM_ADDTOOL
			,Ptr,0
			,Ptr,&TInfo
			,Ptr)
		DllCall("SendMessage"
			,Ptr,TThwnd
			,UInt,TTM_SETMAXTIPWIDTH
			,Ptr,0
			,Ptr,A_ScreenWidth)
	}
	DllCall("SendMessage"
		,Ptr,TThwnd
		,UInt,TTM_UPDATETIPTEXT
		,Ptr,0
		,Ptr,&TInfo
		,Ptr)

}

; ######### SETTINGS ############

; (Internal: RegExr x-forms)
; GroupBox
;   Gui, Add, GroupBox, (.+?) , (.+) -> ; $2 \n\n    GuiAddGroupBox("$2", "$1")
; Checkbox (with label)
;   Gui, Add, (.+?), (.+?) hwnd(.+?) v(.+?) g(.+?) Checked%(.+)%, (.+) -> GuiAdd$1("$7", "$2", Opts.$6, "$4", "$3", "$5")
; Checkbox /w/o label)
;   Gui, Add, (.+?), (.+?) hwnd(.+?) v(.+?) Checked%(.+)%, (.+) -> GuiAdd$1("$6", "$2", Opts.$5, "$4", "$3")
; Edit
;   Gui, Add, Edit, (.+?) hwnd(.+?) v(.+?), %(.+)% -> GuiAddEdit(Opts.$4, "$1", "$3", "", "$2")
; Text
;   Gui, Add, Text, (.+?) hwnd(.+?) v(.+?), (.+) -> GuiAddText("$4", "$1", "$3", "", "$2")
; Button
;   Gui, Add, Button, (.+?) g(.+?), (.+) -> GuiAddButton("$3", "$1", "", "$2", "")

CreateSettingsUI()
{
	Global
	
	Gui, SettingsUI:Color, ffffff, ffffff
	Gui, SettingsUI:Default

	; ItemInfo is not included in other scripts
	If (not SkipItemInfoUpdateCall) {
		Fonts.SetUIFont(8)
		Scripts := Globals.Get("SettingsScriptList")
		TabNames := ""
		Loop, % Scripts.Length() {
			name := Scripts[A_Index]
			TabNames .= name "|"
		}

		StringTrimRight, TabNames, TabNames, 1
		Gui, SettingsUI:Add, Tab3, Choose1 h660 x0, %TabNames%
	}
	
	; Note: window handles (hwnd) are only needed if a UI tooltip should be attached.
	
	generalHeight := SkipItemInfoUpdateCall ? "150" : "240"		; "180" : "270" with ParseItemHotKey
	topGroupBoxYPos := SkipItemInfoUpdateCall ? "y51" : "y30"
	
	; General
	GuiAddGroupBox("General", "x7 " topGroupBoxYPos " w310 h" generalHeight " Section", "", "", "", "", "SettingsUI")
	GuiAddCheckbox("Only show tooltip if PoE is frontmost", "xs10 yp+20 w250 h30", Opts.OnlyActiveIfPOEIsFront, "OnlyActiveIfPOEIsFront", "OnlyActiveIfPOEIsFrontH", "", "", "SettingsUI")
	AddToolTip(OnlyActiveIfPOEIsFrontH, "When checked the script only activates while you are ingame`n(technically while the game window is the frontmost)")
	
	;GuiAddHotkey(Opts.ParseItemHotKey, "xs75 yp+37 w120 h20", "ParseItemHotKey")
	;GuiAddText("Hotkey:", "xs27 yp+2 w50 h20 0x0100", "LblParseItemHotKey")
	; Change next from yp+30 to yp+25 when this is implemented.
	
	GuiAddCheckbox("Put tooltip results on clipboard", "xs10 yp+30 w250 h30", Opts.PutResultsOnClipboard, "PutResultsOnClipboard", "PutResultsOnClipboardH", "", "", "SettingsUI")
	AddToolTip(PutResultsOnClipboardH, "Put tooltip result text into the system clipboard`n(overwriting the raw text PoE itself put there to begin with)")
	
	GuiAddCheckbox("Enable Map Mod Warnings", "xs10 yp+30 w250 h30", Opts.EnableMapModWarnings, "EnableMapModWarnings", "EnableMapModWarningsH", "", "", "SettingsUI")
	AddToolTip(EnableMapModWarningsH, "Enables or disables the entire Map Mod Warnings function.")

	If (!SkipItemInfoUpdateCall) {
		GuiAddCheckbox("Update: Show Notifications", "xs10 yp+30 w250 h30", Opts.ShowUpdateNotification, "ShowUpdateNotification", "ShowUpdateNotificationH", "", "", "SettingsUI")
		AddToolTip(ShowUpdateNotificationH, "Notifies you when there's a new release available.")
		
		GuiAddCheckbox("Update: Skip folder selection", "xs10 yp+30 w250 h30", Opts.UpdateSkipSelection, "UpdateSkipSelection", "UpdateSkipSelectionH", "", "", "SettingsUI")
		AddToolTip(UpdateSkipSelectionH, "Skips selecting an update location.`nThe current script directory will be used as default.")
		
		GuiAddCheckbox("Update: Skip backup", "xs10 yp+30 w250 h30", Opts.UpdateSkipBackup, "UpdateSkipBackup", "UpdateSkipBackupH", "", "", "SettingsUI")
		AddToolTip(UpdateSkipBackupH, "Skips making a backup of the install location/folder.")
	}	
	
	; GDI+
	GDIShift := SkipItemInfoUpdateCall ? 210 : 300
	GuiAddGroupBox("GDI+", "x7 ym+" GDIShift " w310 h320 Section", "", "", "", "", "SettingsUI")
	
	GuiAddCheckBox("Enable GDI+", "xs10 yp+20 w115", Opts.UseGDI, "UseGDI", "UseGDIH", "SettingsUI_ChkUseGDI", "", "SettingsUI")
	AddToolTip(UseGDIH, "Enables rendering of tooltips using Windows gdip.dll`n(allowing limited styling options).")
	GuiAddCheckBox("Rendering Fix", "xs10 yp+30 w115", Opts.GDIRenderingFix, "GDIRenderingFix", "GDIRenderingFixH", "", "", "SettingsUI")
	AddToolTip(GDIRenderingFixH, "In the case that rendered graphics (window, border and text) are`nunsharp/blurry this should fix the issue.")
	GuiAddText("(Restart script after disabling GDI+. Enabling might cause general FPS drops.)", "xs120 ys+20 w185 cRed", "", "", "", "", "SettingsUI")
	
	GuiAddButton("Edit Window", "xs9 ys80 w80 h23", "SettingsUI_BtnGDIWindowColor", "BtnGDIWindowColor", "", "", "SettingsUI")
	GuiAddText("Color (hex RGB):", "xs100 ys85 w200", "LblGDIWindowColor", "", "", "", "SettingsUI")
	GuiAddEdit(Opts.GDIWindowColor, "xs240 ys82 w60", "GDIWindowColor", "GDIWindowColorH", "", "", "SettingsUI")
	GuiAddText("Opactiy (0-100):", "xs100 ys115 w200", "LblGDIWindowOpacity", "", "", "", "SettingsUI")
	GuiAddEdit(Opts.GDIWindowOpacity, "xs240 ys112 w60", "GDIWindowOpacity", "GDIWindowOpacityH", "", "", "SettingsUI")
	GuiAddButton("Edit Border", "xs9 ys140 w80 h23", "SettingsUI_BtnGDIBorderColor", "BtnGDIBorderColor", "", "", "SettingsUI")
	GuiAddText("Color (hex RGB):", "xs100 ys145 w200", "LblGDIBorderColor", "", "", "", "SettingsUI")
	GuiAddEdit(Opts.GDIBorderColor, "xs240 ys142 w60", "GDIBorderColor", "GDIBorderColorH", "", "", "SettingsUI")
	GuiAddText("Opacity (0-100):", "xs100 ys175 w200", "LblGDIBorderOpacity", "", "", "", "SettingsUI")
	GuiAddEdit(Opts.GDIBorderOpacity, "xs240 ys172 w60", "GDIBorderOpacity", "GDIBorderOpacityH", "", "", "SettingsUI")
	GuiAddButton("Edit Text", "xs9 ys200 w80 h23", "SettingsUI_BtnGDITextColor", "BtnGDITextColor", "", "", "SettingsUI")
	GuiAddText("Color (hex RGB):", "xs100 ys205 w200", "LblGDITextColor", "", "", "", "SettingsUI")
	GuiAddEdit(Opts.GDITextColor, "xs240 ys202 w60", "GDITextColor", "GDITextColorH", "", "", "SettingsUI")
	GuiAddText("Opacity (0-100):", "xs100 ys235 w200", "LblGDITextOpacity", "", "", "", "SettingsUI")
	GuiAddEdit(Opts.GDITextOpacity, "xs240 ys232 w60", "GDITextOpacity", "GDITextOpacityH", "", "", "SettingsUI")
	GuiAddCheckBox("Style border depending on checked item.", "xs10 ys260 w260", Opts.GDIConditionalColors, "GDIConditionalColors", "GDIConditionalColorsH", "", "", "SettingsUI")
	
	GuiAddButton("GDI Defaults", "xs9 ys290 w100 h23", "SettingsUI_BtnGDIDefaults", "BtnGDIDefaults", "BtnGDIDefaultsH", "", "SettingsUI")
	GuiAddButton("Preview", "xs210 ys290 w80 h23", "SettingsUI_BtnGDIPreviewTooltip", "BtnGDIPreviewTooltip", "BtnGDIPreviewTooltipH", "", "SettingsUI")

	; Tooltip
	GuiAddGroupBox("Tooltip", "x327 " topGroupBoxYPos " w310 h140 Section", "", "", "", "", "SettingsUI")

	GuiAddEdit(Opts.MouseMoveThreshold, "xs250 yp+22 w50 h20 Number", "MouseMoveThreshold", "MouseMoveThresholdH", "", "", "SettingsUI")
	GuiAddText("Mouse move threshold (px):", "xs27 yp+3 w200 h20 0x0100", "LblMouseMoveThreshold", "LblMouseMoveThresholdH", "", "", "SettingsUI")
	AddToolTip(LblMouseMoveThresholdH, "Hide tooltip when the mouse cursor moved x pixel away from the initial position.`nEffectively permanent tooltip when using a value larger than the monitor diameter.")
	
	GuiAddEdit(Opts.ToolTipTimeoutSeconds, "xs250 yp+27 w50 Number", "ToolTipTimeoutSeconds", "", "", "", "SettingsUI")
	GuiAddCheckBox("Use tooltip timeout (seconds)", "xs10 yp+3 w200", Opts.UseTooltipTimeout, "UseTooltipTimeout", "UseTooltipTimeoutH", "SettingsUI_ChkUseTooltipTimeout", "", "SettingsUI")
	AddToolTip(UseTooltipTimeoutH, "Hide tooltip automatically after defined time.")
	
	GuiAddCheckbox("Display at fixed coordinates", "xs10 yp+30 w280", Opts.DisplayToolTipAtFixedCoords, "DisplayToolTipAtFixedCoords", "DisplayToolTipAtFixedCoordsH", "SettingsUI_ChkDisplayToolTipAtFixedCoords", "", "SettingsUI")
	AddToolTip(DisplayToolTipAtFixedCoordsH, "Show tooltip in virtual screen space at the fixed`ncoordinates given below. Virtual screen space means`nthe full desktop frame, including any secondary`nmonitors. Coords are relative to the top left edge`nand increase going down and to the right.")
		GuiAddEdit(Opts.ScreenOffsetX, "xs50 yp+22 w50", "ScreenOffsetX", "", "", "", "SettingsUI")
		GuiAddEdit(Opts.ScreenOffsetY, "xs130 yp+0 w50", "ScreenOffsetY", "", "", "", "SettingsUI")
		GuiAddText("X", "xs35 yp+3 w15", "LblScreenOffsetX", "", "", "", "SettingsUI")
		GuiAddText("Y", "xs115 yp+0 w15", "LblScreenOffsetY", "", "", "", "SettingsUI")
	
	
	; Display
	GuiAddGroupBox("Display", "x327 ym+" 200 " w310 h295 Section", "", "", "", "", "SettingsUI")
	
	GuiAddCheckbox("Show header for affix overview", "xs10 yp+20 w260 h30", Opts.ShowHeaderForAffixOverview, "ShowHeaderForAffixOverview", "ShowHeaderForAffixOverviewH", "", "", "SettingsUI")
	AddToolTip(ShowHeaderForAffixOverviewH, "Include a header above the affix overview:`n   TierRange ilvl   Total ilvl  Tier")
	
	GuiAddCheckbox("Show explanation for used notation", "xs10 yp+30 w260 h30", Opts.ShowExplanationForUsedNotation, "ShowExplanationForUsedNotation", "ShowExplanationForUsedNotationH", "", "", "SettingsUI")
	AddToolTip(ShowExplanationForUsedNotationH, "Explain abbreviations and special notation symbols at`nthe end of the tooltip when they are used")
	
	GuiAddEdit(Opts.AffixTextEllipsis, "xs260 y+5 w40 h20", "AffixTextEllipsis", "", "", "", "SettingsUI")
	GuiAddText("Affix text ellipsis:", "xs10 yp+3 w170 h20 0x0100", "LblAffixTextEllipsis", "AffixTextEllipsisH", "", "", "SettingsUI")
	AddToolTip(AffixTextEllipsisH, "Symbol used when affix text is shortened, such as:`n50% increased Spell…")
	
	GuiAddEdit(Opts.AffixColumnSeparator, "xs260 y+7 w40 h20", "AffixColumnSeparator", "", "", "", "SettingsUI")
	GuiAddText("Affix column separator:", "xs10 yp+3 w170 h20 0x0100", "LblAffixColumnSeparator", "AffixColumnSeparatorH", "", "", "SettingsUI")
	AddToolTip(AffixColumnSeparatorH, "Select separator (default: 2 spaces) for the \\ spots:`n50% increased Spell…\\50-59 (46)\\75-79 (84)\\T4 P")
	
	GuiAddEdit(Opts.DoubleRangeSeparator, "xs260 y+7 w40 h20", "DoubleRangeSeparator", "", "", "", "SettingsUI")
	GuiAddText("Double range separator:", "xs10 yp+3 w170 h20 0x0100", "LblDoubleRangeSeparator", "DoubleRangeSeparatorH", "", "", "SettingsUI")
	AddToolTip(DoubleRangeSeparatorH, "Select separator (default: | ) for double ranges from 'added damage' mods:`na-b to c-d is displayed as a-b|c-d")
	
	GuiAddCheckbox("Use compact double ranges", "xs10 y+3 w210 h30", Opts.UseCompactDoubleRanges, "UseCompactDoubleRanges", "UseCompactDoubleRangesH", "SettingsUI_ChkUseCompactDoubleRanges", "", "SettingsUI")
	AddToolTip(UseCompactDoubleRangesH, "Show double ranges from 'added damage' mods as one range,`ne.g. a-b to c-d becomes a-d")
	
	GuiAddCheckbox("Only compact for 'Total' column", "xs30 yp+30 w210 h30", Opts.OnlyCompactForTotalColumn, "OnlyCompactForTotalColumn", "OnlyCompactForTotalColumnH", "", "", "SettingsUI")
	AddToolTip(OnlyCompactForTotalColumnH, "Only use compact double ranges for the second range column`nin the affix overview (with the header 'total')")
	
	GuiAddEdit(Opts.MultiTierRangeSeparator, "xs260 y+6 w40 h20", "MultiTierRangeSeparator", "", "", "", "SettingsUI")
	GuiAddText("Multi tier range separator:", "xs10 yp+3 w170 h20 0x0100", "LblMultiTierRangeSeparator", "MultiTierRangeSeparatorH", "", "", "SettingsUI")
	AddToolTip(MultiTierRangeSeparatorH, "Select separator (default: … ) for a multi tier roll range with uncertainty:`n83% increased Light…   73-85…83-95   102-109 (84)  T1-4 P + T1-6 S`n	                     There--^")
	
	GuiAddEdit(Opts.FontSize, "xs260 y+6 w40 h20 Number", "FontSize", "", "", "", "SettingsUI")
	GuiAddText("Font Size:", "xs10 yp+3 w180 h20 0x0100", "", "", "", "", "SettingsUI")

	; Buttons
	ButtonsShiftX := "x659 "
	GuiAddText("Mouse over settings or see the GitHub Wiki page for comments on what these settings do exactly.", ButtonsShiftX " y63 w290 h30 0x0100", "", "", "", "", "SettingsUI")
	
	GuiAddButton("Defaults", ButtonsShiftX "y+8 w90 h23", "SettingsUI_BtnDefaults", "", "", "", "SettingsUI")
	GuiAddButton("OK", "Default x+5 yp+0 w90 h23", "SettingsUI_BtnOK", "", "", "", "SettingsUI")
	GuiAddButton("Cancel", "x+5 yp+0 w90 h23", "SettingsUI_BtnCancel", "", "", "", "SettingsUI")
	
	If (SkipItemInfoUpdateCall) {
		GuiAddText("Use these buttons to change ItemInfo and AdditionalMacros settings (TradeMacro has it's own buttons).", ButtonsShiftX "y+10 w250 h50 cRed", "", "", "", "", "SettingsUI")
		GuiAddText("", "x10 y10 w250 h10", "", "", "", "", "SettingsUI")
	}
	
	; Begin Additional Macros Tab
	If (SkipItemInfoUpdateCall) {
		Gui, SettingsUI:Tab, 3 
	} Else {
		Gui, SettingsUI:Tab, 2
	}
	
	; AM Hotkeys
	GuiAddGroupBox("[AdditionalMacros] Hotkeys", "x7 " topGroupBoxYPos " w630 h625", "", "", "", "", "SettingsUI")
	
	If (not AM_Config) {
		GoSub, AM_Init
	}
	
	chkBoxWidth := 160
	chkBoxShiftY := 28
	LVWidth := 185

	_AM_sections := StrSplit(AM_Config.GetSections("|", "C"), "|")
	For sectionIndex, sectionName in _AM_sections {	; this enables section sorting		
		If (sectionName != "General") {
			; hotkey checkboxes (enable/disable)
			HKCheckBoxID := "AM_" sectionName "_State"
			GuiAddCheckbox(sectionName ":", "x17 yp+" chkBoxShiftY " w" chkBoxWidth " h20 0x0100", AM_Config[sectionName].State, HKCheckBoxID, HKCheckBoxID "H", "", "", "SettingsUI")
			AddToolTip(%HKCheckBoxID%H, RegExReplace(AM_ConfigDefault[sectionName].Description, "i)(\(Default = .*\))|\\n", "`n$1"))	; read description from default config
			
			For keyIndex, keyValue in StrSplit(AM_Config[sectionName].Hotkeys, ", ") {	
				HotKeyID := "AM_" sectionName "_HotKeys_" keyIndex
				LV_shiftY := keyIndex > 1 ? 1 : 0 
				GuiAddListView("1|2", "x+10 yp+" LV_shiftY " h20 w" LVWidth, HotKeyID, HotKeyID "H", "", "r1 -Hdr -LV0x20 r1 C454444 Backgroundf0f0f0", "SettingsUI")
				LV_ModifyCol(1, 0)
				LV_ModifyCol(2, LVWidth - 5)
				LV_Delete(1)
				LV_Add("","", keyValue)			

				GuiAddButton("Edit", "xp+" LVWidth " yp-1 w30 h22 v" HotKeyID "_Trigger", "LV_HotkeyEdit", "", "", "", "SettingsUI")
			}
			
			For keyIndex, keyValue in AM_Config[sectionName] {
				If (not RegExMatch(keyIndex, "i)State|Hotkeys|Description")) {
					If (RegExMatch(sectionName, "i)HighlightItems|HighlightItemsAlt")) {
						If (keyIndex = "Arg2") {
							CheckBoxID := "AM_" sectionName "_Arg2"
							GuiAddCheckbox("Leave search field.", "x" 17 + chkBoxWidth + 10 " yp+" chkBoxShiftY, keyValue, CheckBoxID, CheckBoxID "H", "", "", "SettingsUI")
						}
						If (keyIndex = "Arg3") {
							CheckBoxID := "AM_" sectionName "_Arg3"
							GuiAddCheckbox("Enable hideout stash search.", "x+10 yp+0", keyValue, CheckBoxID, CheckBoxID "H", "", "", "SettingsUI")
						}
						If (keyIndex = "Arg4") {
							EditID := "AM_" sectionName "_" keyIndex
							GuiAddText("Decoration stash search field coordinates:  ", "x" 17 + chkBoxWidth + 10 " yp+" chkBoxShiftY " w260 h20 0x0100", "LblHighlighting", "LblHighlightingH", "", "", "SettingsUI")
							AddToolTip(LblHighlightingH, "Refers to the decoration stash on the right side`nof the screen, not the master vendor window.`n`nCoordinates are relative to the PoE game window and`nare neccessary to click into/focus the search field.")
							GuiAddPicture(A_ScriptDir "\resources\images\info-blue.png", "x+-15 yp+0 w15 h-1 0x0100", "HighlightInfo", "HighlightH", "", "", "SettingsUI")
							GuiAddText("x= ", "x+5 yp+0 w20 h20 0x0100", "", "", "", "", "SettingsUI")
							GuiAddEdit(keyValue, "x+0 yp-2 w40 h20", EditID, "", "", "", "SettingsUI")
						}
						If (keyIndex = "Arg5") {
							EditID := "AM_" sectionName "_" keyIndex
							GuiAddText("y=", "x+5 yp+2 w20 h20 0x0100", "", "", "", "", "SettingsUI")
							GuiAddEdit(keyValue, "x+0 yp-2 w40 h20", EditID, "", "", "", "SettingsUI")
						}
					}
					Else If (RegExMatch(sectionName, "i)JoinChannel|KickYourself")) {
						EditID := "AM_" sectionName "_" keyIndex
						GuiAddText(keyIndex ":", "x+10 yp+4 w85 h20 0x0100", "", "", "", "", "SettingsUI")
						GuiAddEdit(keyValue, "x+0 yp-2 w99 h20", EditID, "", "", "", "SettingsUI")
					} 
					Else {
						EditID := "AM_" sectionName "_" keyIndex
						GuiAddText(keyIndex ":", "x" 17 + chkBoxWidth + 10 " yp+" chkBoxShiftY " w85 h20 0x0100", "", "", "", "", "SettingsUI")
						GuiAddEdit(keyValue, "x+0 yp-2 w99 h20", EditID, "", "", "", "SettingsUI")
					}					
				}
			}
		}
	}
	
	; AM General

	GuiAddGroupBox("[AdditionalMacros] General", "x647 " topGroupBoxYPos " w310 h60", "", "", "", "", "SettingsUI")
	
	_i := 0
	For keyIndex, keyValue in AM_Config.General {
		If (not RegExMatch(keyIndex, ".*_Description$")) {
			elementYPos := _i > 0 ? 20 : 30

			If (RegExMatch(keyIndex, ".*State$") and not (InStr(keyIndex, "KeyToSC", 0))) {
				RegExMatch(AM_ConfigDefault.General[keyIndex "_Description"], ".*Short\$(.*)Long\$(.*)""", _description)		; read description from default config
				ControlID := "AM_General_" keyIndex
				GuiAddCheckbox(Trim(_description1), "x657 yp+" elementYPos " w250 h30", AM_Config.General[keyIndex], ControlID, ControlID "H", "", "", "SettingsUI")
				AddToolTip(%ControlID%H, Trim(_description2))
			}
			_i++
		}	
	}
	
	; AM Buttons
	
	GuiAddText("Mouse over settings or see the GitHub Wiki page for comments on what these settings do exactly.", ButtonsShiftX "yp+60 w290 h30 0x0100", "", "", "", "", "SettingsUI")
	GuiAddButton("Defaults", "xp-5 y+8 w90 h23", "SettingsUI_AM_BtnDefaults", "", "", "", "SettingsUI")
	GuiAddButton("OK", "Default x+5 yp+0 w90 h23", "SettingsUI_BtnOK", "", "", "", "SettingsUI")
	GuiAddButton("Cancel", "x+5 yp+0 w90 h23", "SettingsUI_BtnCancel", "", "", "", "SettingsUI")
	GuiAddText("Any change here currently requires a script restart!", ButtonsShiftX "y+10 w280 h50 cGreen", "", "", "", "", "SettingsUI")
	
	If (SkipItemInfoUpdateCall) {
		GuiAddText("Use these buttons to change ItemInfo and AdditionalMacros settings (TradeMacro has it's own buttons).", ButtonsShiftX "y+5 w280 h50 cRed", "", "", "", "", "SettingsUI")
	}
	
	GuiAddText("Experimental Feature!", ButtonsShiftX "y+35 w280 h200 cRed", "", "", "", "", "SettingsUI")
	experimentalNotice := "This new feature to assign hotkeys may cause issues for users with non-latin keyboard layouts."
	experimentalNotice .= "`n`n" . "AHKs default UI element for selecting hotkeys doesn't support any special keys and mouse buttons."
	experimentalNotice .= "`n`n" . "Please report any issues that you are experiencing."
	experimentalNotice .= " You can still assign your settings directly using the AdditionalMacros.ini like before."
	experimentalNotice .= " (Right-click system tray icon -> Edit Files)."
	GuiAddText(experimentalNotice, ButtonsShiftX "yp+25 w290", "", "", "", "", "SettingsUI")
	
	; Begin Lutbot Tab
	If (SkipItemInfoUpdateCall) {
		Gui, SettingsUI:Tab, 4 
	} Else {
		Gui, SettingsUI:Tab, 3
	}
	
	GuiAddGroupBox("[Lutbot Logout]", "x7 " topGroupBoxYPos " w630 h625", "", "", "", "", "SettingsUI")

	lb_desc := "Lutbot's macro is a collection of features like TCP disconnect logout, whisper replies, ladder tracker and more.`n"
	lb_desc .= "The included logout macro is the most advanced logout feature currently out there."
	GuiAddText(lb_desc, "x17 yp+28 w600 h40 0x0100", "", "", "", "", "SettingsUI")
	
	lb_desc := "Since running the main version of this script alongside " Globals.Get("Projectname") " can cause some issues`n"
	lb_desc .= "and hotkey conflicts, Lutbot also released a lite version that only contains the logout features."
	GuiAddText(lb_desc, "x17 y+10 w600 h35 0x0100", "", "", "", "", "SettingsUI")
	
	Gui, SettingsUI:Add, Link, x17 y+5 cBlue, <a href="http://lutbot.com/#/ahk">Website and download</a>
	
	lb_desc := Globals.Get("Projectname") " can manage running this lite version for you, keeping it an independant script."
	GuiAddText(lb_desc, "x17 y+20 w600 h20 0x0100", "", "", "", "", "SettingsUI")
	
	GuiAddCheckbox("Run lutbot on script start if the lutbot macro exists (requires you to have run it once before).", "x17 yp+20 w600 h30", Opts.Lutbot_CheckScript, "Lutbot_CheckScript", "Lutbot_CheckScriptH", "", "", "SettingsUI")
	
	GuiAddCheckbox("Warn in case of hotkey conflicts", "x17 yp+30 w290 h30", Opts.Lutbot_WarnConflicts, "Lutbot_WarnConflicts", "Lutbot_WarnConflictsH", "", "", "SettingsUI")
	AddToolTip(Lutbot_CheckScriptH, "Check if the lutbot macro exists and run it.")
	
	GuiAddButton("Open Lutbot folder", "Default x17 y+10 w130 h23", "OpenLutbotDocumentsFolder", "", "", "", "SettingsUI")
	
	lb_desc := "If you have any issues related to"
	GuiAddText(lb_desc, "x17 y+40 w600 h20 0x0100", "", "", "", "", "SettingsUI")
	lb_desc := "- " Globals.Get("Projectname") " starting the lutbot script or checking for conflicts report here:"
	GuiAddText(lb_desc, "x17 y+0 w600 h20 0x0100", "", "", "", "", "SettingsUI")
	Gui, SettingsUI:Add, Link, x35 y+5 cBlue h20, - <a href="https://github.com/PoE-TradeMacro/POE-TradeMacro/issues">Github</a>
	Gui, SettingsUI:Add, Link, x35 y+0 cBlue h20, - <a href="https://discord.gg/taKZqWw">Discord</a>
	Gui, SettingsUI:Add, Link, x35 y+0 cBlue h20, - <a href="https://www.pathofexile.com/forum/view-thread/1757730">Forum</a>

	lb_desc := "- Lutbots script not working correctly in any way report here:"
	GuiAddText(lb_desc, "x17 y+5 w600 h20 0x0100", "", "", "", "", "SettingsUI")
	Gui, SettingsUI:Add, Link, x35 y+5 cBlue h20, - <a href="https://discord.gg/nttekWT">Discord</a>
	
	; Lutbot Buttons
	
	GuiAddText("Mouse over settings to see what these settings do exactly.", ButtonsShiftX "y60 w290 h30 0x0100", "", "", "", "", "SettingsUI")
	GuiAddButton("OK", "Default xp-5 y+8 w90 h23", "SettingsUI_BtnOK", "", "", "", "SettingsUI")
	GuiAddButton("Cancel", "x+5 yp+0 w90 h23", "SettingsUI_BtnCancel", "", "", "", "SettingsUI")
	
	; close tabs
	Gui, SettingsUI:Tab
	
	GoSub, SettingsUI_ChkUseCompactDoubleRanges
	GoSub, SettingsUI_ChkDisplayToolTipAtFixedCoords
	GoSub, SettingsUI_ChkUseTooltipTimeout
	GoSub, SettingsUI_ChkUseGDI
}

UpdateSettingsUI()
{
	Global Opts
	
	; General
	;GuiControl,, ParseItemHotKey, % Opts.ParseItemHotKey
	GuiControl,, OnlyActiveIfPOEIsFront, % Opts.OnlyActiveIfPOEIsFront
	GuiControl,, PutResultsOnClipboard, % Opts.PutResultsOnClipboard
	;GuiControl,, EnableAdditionalMacros, % Opts.EnableAdditionalMacros
	GuiControl,, EnableMapModWarnings, % Opts.EnableMapModWarnings
	If (!SkipItemInfoUpdateCall) {
		GuiControl,, ShowUpdateNotifications, % Opts.ShowUpdateNotifications
		GuiControl,, UpdateSkipSelection, % Opts.UpdateSkipSelection
		GuiControl,, UpdateSkipBackup, % Opts.UpdateSkipBackup
	}
	
	; Tooltip
	GuiControl,, MouseMoveThreshold, % Opts.MouseMoveThreshold
	GuiControl,, UseTooltipTimeout, % Opts.UseTooltipTimeout
	If (Opts.UseTooltipTimeout == False){
		GuiControl, Disable, ToolTipTimeoutSeconds
	}
	Else{
		GuiControl, Enable, ToolTipTimeoutSeconds
	}
	GuiControl,, ToolTipTimeoutSeconds, % Opts.ToolTipTimeoutSeconds
		
	GuiControl,, DisplayToolTipAtFixedCoords, % Opts.DisplayToolTipAtFixedCoords
	If (Opts.DisplayToolTipAtFixedCoords == False)
	{
		GuiControl, Disable, LblScreenOffsetX
		GuiControl, Disable, ScreenOffsetX
		GuiControl, Disable, LblScreenOffsetY
		GuiControl, Disable, ScreenOffsetY
	}
	Else
	{
		GuiControl, Enable, LblScreenOffsetX
		GuiControl, Enable, ScreenOffsetX
		GuiControl, Enable, LblScreenOffsetY
		GuiControl, Enable, ScreenOffsetY
	}
	
	; Display
	GuiControl,, ShowHeaderForAffixOverview, % Opts.ShowHeaderForAffixOverview
	GuiControl,, ShowExplanationForUsedNotation, % Opts.ShowExplanationForUsedNotation
	GuiControl,, AffixTextEllipsis, % Opts.AffixTextEllipsis
	GuiControl,, AffixColumnSeparator, % Opts.AffixColumnSeparator
	GuiControl,, DoubleRangeSeparator, % Opts.DoubleRangeSeparator
	GuiControl,, UseCompactDoubleRanges, % Opts.UseCompactDoubleRanges
	If (Opts.UseCompactDoubleRanges == False) {
		GuiControl, Enable, OnlyCompactForTotalColumn
	}
	Else {
		GuiControl, Disable, OnlyCompactForTotalColumn
	}
	GuiControl,, OnlyCompactForTotalColumn, % Opts.OnlyCompactForTotalColumn
	GuiControl,, MultiTierRangeSeparator, % Opts.MultiTierRangeSeparator
	GuiControl,, FontSize, % Opts.FontSize
	
	
	; GDI+
	GuiControl,, UseGDI, % Opts.UseGDI
	GuiControl,, GDIRenderingFix, % Opts.GDIRenderingFix
	gdipTooltip.SetRenderingFix(Opts.GDIRenderingFix)

	; If the gdipTooltip is not yet initialised use the color value without validation, it will be validated and updated on enabling GDI
	GuiControl,, GDIWindowColor	, % not IsObject(gdipTooltip.window) ? gdipTooltip.ValidateRGBColor(Opts.GDIWindowColor, Opts.GDIWindowColorDefault) : Opts.GDIWindowColor
	GuiControl,, GDIWindowOpacity	, % not IsObject(gdipTooltip.window) ? gdipTooltip.ValidateOpacity(Opts.GDIWindowOpacity, Opts.GDIWindowOpacityDefault, "10", "10") : Opts.GDIWindowOpacity
	GuiControl,, GDIBorderColor	, % not IsObject(gdipTooltip.window) ? gdipTooltip.ValidateRGBColor(Opts.GDIBorderColor, Opts.GDIBorderColorDefault) : Opts.GDIBorderColor
	GuiControl,, GDIBorderOpacity	, % not IsObject(gdipTooltip.window) ? gdipTooltip.ValidateOpacity(Opts.GDIBorderOpacity, Opts.GDIBorderOpacityDefault, "10", "10") : Opts.GDIBorderOpacity
	GuiControl,, GDITextColor	, % not IsObject(gdipTooltip.window) ? gdipTooltip.ValidateRGBColor(Opts.GDITextColor, Opts.GDITextColorDefault) : Opts.GDITextColor
	GuiControl,, GDITextOpacity	, % not IsObject(gdipTooltip.window) ? gdipTooltip.ValidateOpacity(Opts.GDITextOpacity, Opts.GDITextOpacityDefault, "10", "10") : Opts.GDITextOpacity
	gdipTooltip.UpdateColors(Opts.GDIWindowColor, Opts.GDIWindowOpacity, Opts.GDIBorderColor, Opts.GDIBorderOpacity, Opts.GDITextColor, Opts.GDITextOpacity, 10, 16)
	
	If (Opts.UseGDI == False)
	{
		GuiControl, Disable, GDIWindowColor
		GuiControl, Disable, GDIWindowOpacity
		GuiControl, Disable, GDIBorderColor
		GuiControl, Disable, GDIBorderOpacity
		GuiControl, Disable, GDITextColor
		GuiControl, Disable, GDITextOpacity	
		
		GuiControl, Disable, BtnGDIWindowColor
		GuiControl, Disable, BtnGDIBorderColor
		GuiControl, Disable, BtnGDITextColor
		
		GuiControl, Disable, BtnGDIDefaults	
		GuiControl, Disable, BtnGDIPreviewTooltip
		GuiControl, Disable, GDIRenderingFix
		GuiControl, Disable, GDIConditionalColors
	}
	Else 
	{
		GuiControl, Enable, GDIWindowColor
		GuiControl, Enable, GDIWindowOpacity
		GuiControl, Enable, GDIBorderColor
		GuiControl, Enable, GDIBorderOpacity
		GuiControl, Enable, GDITextColor
		GuiControl, Enable, GDITextOpacity	
		
		GuiControl, Enable, BtnGDIWindowColor
		GuiControl, Enable, BtnGDIBorderColor
		GuiControl, Enable, BtnGDITextColor
		
		GuiControl, Enable, BtnGDIDefaults	
		GuiControl, Enable, BtnGDIPreviewTooltip
		GuiControl, Enable, GDIRenderingFix
		GuiControl, Enable, GDIConditionalColors
	}		
	
	; AdditionalMacros 
	AM_UpdateSettingsUI()
}

ShowSettingsUI()
{
	; remove POE-Item-Info tooltip if still visible
	SetTimer, ToolTipTimer, Off
	ToolTip
	Fonts.SetUIFont(9)
	SettingsUIWidth := Globals.Get("SettingsUIWidth", 545)
	; Adjust user option window height depending on whether ItemInfo is used as a Standalone or included in the TradeMacro.
	; The TradeMacro needs much more space for all the options.
	SettingsUIHeight := Globals.Get("SettingsUIHeight", 615)
	SettingsUITitle := Globals.Get("SettingsUITitle", "PoE ItemInfo Settings")
	Gui, SettingsUI:Show, w%SettingsUIWidth% h%SettingsUIHeight%, %SettingsUITitle%
}

ShowUpdateNotes()
{
	; remove POE-Item-Info tooltip if still visible
	SetTimer, ToolTipTimer, Off
	
	If (gdipTooltip.GetVisibility()) {
		gdipTooltip.HideGdiTooltip()
	}
	ToolTip
	Gui, UpdateNotes:Destroy
	Gui, UpdateNotes:Color, ffffff, ffffff
	Fonts.SetUIFont(9)
	Gui, UpdateNotes:Font, , Verdana
	
	Files := Globals.Get("UpdateNoteFileList")

	TabNames := ""
	Loop, % Files.Length() {
		name := Files[A_Index][2]
		TabNames .= name "|"
	}

	StringTrimRight, TabNames, TabNames, 1
	PreSelect := Files.Length()
	Gui, UpdateNotes:Add, Tab3, Choose%PreSelect%, %TabNames%

	Loop, % Files.Length() {
		file := Files[A_Index][1]
		FileRead, notes, %file%
		Gui, UpdateNotes:Add, Edit, r50 ReadOnly w900 BackgroundTrans, %notes%
		NextTab := A_Index + 1
		Gui, UpdateNotes:Tab, %NextTab%
	}
	Gui, UpdateNotes:Tab

	SettingsUIWidth := 945
	SettingsUIHeight := 710
	SettingsUITitle := "Update Notes"
	Gui, UpdateNotes:Show, w%SettingsUIWidth% h%SettingsUIHeight%, %SettingsUITitle%
}

ShowChangedUserFiles()
{
	Gui, ChangedUserFiles:Destroy
	Gui, ChangedUserFiles:Color, ffffff, ffffff

	Gui, ChangedUserFiles:Add, Text, , Following user files were changed in the last update and `nwere overwritten (old files were backed up):

	Loop, Parse, overwrittenUserFiles, `n
	{
		If (StrLen(A_Loopfield) > 0) {
			Gui, ChangedUserFiles:Add, Text, y+5, %A_LoopField%
		}
	}
	Gui, ChangedUserFiles:Add, Button, y+10 gChangedUserFilesWindow_Cancel, Close
	Gui, ChangedUserFiles:Add, Button, x+10 yp+0 gChangedUserFilesWindow_OpenFolder, Open user folder
	Gui, ChangedUserFiles:Show, w300, Changed User Files
	ControlFocus, Close, Changed User Files
}

IniRead(SectionName, KeyName, DefaultVal, ConfigObj)
{	
	If (ConfigObj[SectionName].HasKey(KeyName)) {
		; return value and replace potential leading or trailing 
		return RegExReplace(ConfigObj[SectionName, KeyName], "^""'|'""$")
	}
	Else {
		return DefaultVal
	}
}

IniWrite(Val, SectionName, KeyName, ByRef ConfigObj)
{	
	If (RegExMatch(Val, "^\s|\s$")) {
		Val := """'" Val "'"""
	}
	
	ConfigObj.SetKeyVal(SectionName, KeyName, Val)
}

ReadConfig(ConfigDir = "", ConfigFile = "config.ini")
{
	Global Opts, ItemInfoConfigObj
	
	If (StrLen(ConfigDir) < 1) {
		ConfigDir := userDirectory
	}
	ConfigPath := StrLen(ConfigDir) > 0 ? ConfigDir . "\" . ConfigFile : ConfigFile
	
	ItemInfoConfigObj := class_EasyIni(ConfigPath)
	
	IfExist, %ConfigPath%
	{
		; General
		;Opts.ParseItemHotKey := IniRead("General", "ParseItemHotKey", Opts.ParseItemHotKey)
		Opts.OnlyActiveIfPOEIsFront	:= IniRead("General", "OnlyActiveIfPOEIsFront", Opts.OnlyActiveIfPOEIsFront, ItemInfoConfigObj)
		Opts.PutResultsOnClipboard	:= IniRead("General", "PutResultsOnClipboard", Opts.PutResultsOnClipboard, ItemInfoConfigObj)
		;Opts.EnableAdditionalMacros	:= IniRead("General", "EnableAdditionalMacros", Opts.EnableAdditionalMacros, ItemInfoConfigObj)
		Opts.EnableMapModWarnings	:= IniRead("General", "EnableMapModWarnings", Opts.EnableMapModWarnings, ItemInfoConfigObj)
		Opts.ShowUpdateNotifications	:= IniRead("General", "ShowUpdateNotifications", Opts.ShowUpdateNotifications, ItemInfoConfigObj)
		Opts.UpdateSkipSelection		:= IniRead("General", "UpdateSkipSelection", Opts.UpdateSkipSelection, ItemInfoConfigObj)
		Opts.UpdateSkipBackup		:= IniRead("General", "UpdateSkipBackup", Opts.UpdateSkipBackup, ItemInfoConfigObj)
		
		; Tooltip
		Opts.MouseMoveThreshold	:= IniRead("Tooltip", "MouseMoveThreshold", Opts.MouseMoveThreshold, ItemInfoConfigObj)
		Opts.UseTooltipTimeout	:= IniRead("Tooltip", "UseTooltipTimeout", Opts.UseTooltipTimeout, ItemInfoConfigObj)
		Opts.ToolTipTimeoutSeconds		:= IniRead("Tooltip", "ToolTipTimeoutSeconds", Opts.ToolTipTimeoutSeconds, ItemInfoConfigObj)
		Opts.DisplayToolTipAtFixedCoords 	:= IniRead("Tooltip", "DisplayToolTipAtFixedCoords", Opts.DisplayToolTipAtFixedCoords, ItemInfoConfigObj)
		Opts.ScreenOffsetX		:= IniRead("Tooltip", "ScreenOffsetX", Opts.ScreenOffsetX, ItemInfoConfigObj)
		Opts.ScreenOffsetY		:= IniRead("Tooltip", "ScreenOffsetY", Opts.ScreenOffsetY, ItemInfoConfigObj)
		
		; Display
		Opts.ShowHeaderForAffixOverview		:= IniRead("Display", "ShowHeaderForAffixOverview", Opts.ShowHeaderForAffixOverview, ItemInfoConfigObj)
		Opts.ShowExplanationForUsedNotation	:= IniRead("Display", "ShowExplanationForUsedNotation", Opts.ShowExplanationForUsedNotation, ItemInfoConfigObj)
		Opts.AffixTextEllipsis				:= IniRead("Display", "AffixTextEllipsis", Opts.AffixTextEllipsis, ItemInfoConfigObj)
		Opts.AffixColumnSeparator			:= IniRead("Display", "AffixColumnSeparator", Opts.AffixColumnSeparator, ItemInfoConfigObj)
		Opts.DoubleRangeSeparator			:= IniRead("Display", "DoubleRangeSeparator", Opts.DoubleRangeSeparator, ItemInfoConfigObj)
		Opts.UseCompactDoubleRanges			:= IniRead("Display", "UseCompactDoubleRanges", Opts.UseCompactDoubleRanges, ItemInfoConfigObj)
		Opts.OnlyCompactForTotalColumn		:= IniRead("Display", "OnlyCompactForTotalColumn", Opts.OnlyCompactForTotalColumn, ItemInfoConfigObj)
		Opts.MultiTierRangeSeparator			:= IniRead("Display", "MultiTierRangeSeparator", Opts.MultiTierRangeSeparator, ItemInfoConfigObj)
		Opts.FontSize						:= IniRead("Display", "FontSize", Opts.FontSize, ItemInfoConfigObj)
		
		; GDI+		
		Opts.UseGDI				:= IniRead("GDI", "Enabled", Opts.UseGDI, ItemInfoConfigObj)
		Opts.GDIRenderingFix		:= IniRead("GDI", "RenderingFix", Opts.GDIRenderingFix, ItemInfoConfigObj)
		Opts.GDIConditionalColors	:= IniRead("GDI", "ConditionalColors", Opts.GDIConditionalColors, ItemInfoConfigObj)
		Opts.GDIWindowColor			:= IniRead("GDI", "WindowColor", Opts.GDIWindowColor, ItemInfoConfigObj)
		Opts.GDIWindowColorDefault	:= IniRead("GDI", "WindowColorDefault", Opts.GDIWindowColorDefault, ItemInfoConfigObj)
		Opts.GDIWindowOpacity		:= IniRead("GDI", "WindowOpacity", Opts.GDIWindowOpacity, ItemInfoConfigObj)
		Opts.GDIWindowOpacityDefault	:= IniRead("GDI", "WindowOpacityDefault", Opts.GDIWindowOpacityDefault, ItemInfoConfigObj)
		Opts.GDIBorderColor			:= IniRead("GDI", "BorderColor", Opts.GDIBorderColor, ItemInfoConfigObj)
		Opts.GDIBorderColorDefault	:= IniRead("GDI", "BorderColorDefault", Opts.GDIBorderColorDefault, ItemInfoConfigObj)
		Opts.GDIBorderOpacity		:= IniRead("GDI", "BorderOpacity", Opts.GDIBorderOpacity, ItemInfoConfigObj)
		Opts.GDIBorderOpacityDefault	:= IniRead("GDI", "BorderOpacityDefault", Opts.GDIBorderOpacityDefault, ItemInfoConfigObj)
		Opts.GDITextColor			:= IniRead("GDI", "TextColor", Opts.GDITextColor, ItemInfoConfigObj)
		Opts.GDITextColorDefault		:= IniRead("GDI", "TextColorDefault", Opts.GDITextColorDefault, ItemInfoConfigObj)
		Opts.GDITextOpacity			:= IniRead("GDI", "TextOpacity", Opts.GDITextOpacity, ItemInfoConfigObj)
		Opts.GDITextOpacityDefault	:= IniRead("GDI", "TextOpacityDefault", Opts.GDITextOpacityDefault, ItemInfoConfigObj)
		gdipTooltip.UpdateColors(Opts.GDIWindowColor, Opts.GDIWindowOpacity, Opts.GDIBorderColor, Opts.GDIBorderOpacity, Opts.GDITextColor, Opts.GDITextOpacity, "10", "16")
		
		; Lutbot
		Opts.Lutbot_CheckScript		:= IniRead("Lutbot", "Lutbot_CheckScript", Opts.Lutbot_CheckScript, ItemInfoConfigObj)
		Opts.Lutbot_WarnConflicts	:= IniRead("Lutbot", "Lutbot_WarnConflicts", Opts.Lutbot_WarnConflicts, ItemInfoConfigObj)
	}
}

WriteConfig(ConfigDir = "", ConfigFile = "config.ini")
{
	Global Opts, ItemInfoConfigObj
	
	If (StrLen(ConfigDir) < 1) {
		ConfigDir := userDirectory
	}
	ConfigPath := StrLen(ConfigDir) > 0 ? ConfigDir . "\" . ConfigFile : ConfigFile
	
	ItemInfoConfigObj := class_EasyIni(ConfigPath)
	
	Opts.ScanUI()
	
	; General
	;IniWrite(Opts.ParseItemHotKey, "General", "ParseItemHotKey")
	IniWrite(Opts.OnlyActiveIfPOEIsFront, "General", "OnlyActiveIfPOEIsFront", ItemInfoConfigObj)
	IniWrite(Opts.PutResultsOnClipboard, "General", "PutResultsOnClipboard", ItemInfoConfigObj)
	;IniWrite(Opts.EnableAdditionalMacros, "General", "EnableAdditionalMacros", ItemInfoConfigObj)
	IniWrite(Opts.EnableMapModWarnings, "General", "EnableMapModWarnings", ItemInfoConfigObj)
	IniWrite(Opts.ShowUpdateNotifications, "General", "ShowUpdateNotifications", ItemInfoConfigObj)
	IniWrite(Opts.UpdateSkipSelection, "General", "UpdateSkipSelection", ItemInfoConfigObj)
	IniWrite(Opts.UpdateSkipBackup, "General", "UpdateSkipBackup", ItemInfoConfigObj)
	
	; Display
	IniWrite(Opts.ShowHeaderForAffixOverview, "Display", "ShowHeaderForAffixOverview", ItemInfoConfigObj)
	IniWrite(Opts.ShowExplanationForUsedNotation, "Display", "ShowExplanationForUsedNotation", ItemInfoConfigObj)
	IniWrite("" . Opts.AffixTextEllipsis . "", "Display", "AffixTextEllipsis", ItemInfoConfigObj)
	IniWrite("" . Opts.AffixColumnSeparator . "", "Display", "AffixColumnSeparator", ItemInfoConfigObj)
	IniWrite("" . Opts.DoubleRangeSeparator . "", "Display", "DoubleRangeSeparator", ItemInfoConfigObj)
	IniWrite(Opts.UseCompactDoubleRanges, "Display", "UseCompactDoubleRanges", ItemInfoConfigObj)
	IniWrite(Opts.OnlyCompactForTotalColumn, "Display", "OnlyCompactForTotalColumn", ItemInfoConfigObj)
	IniWrite("" . Opts.MultiTierRangeSeparator . "", "Display", "MultiTierRangeSeparator", ItemInfoConfigObj)
	IniWrite(Opts.FontSize, "Display", "FontSize", ItemInfoConfigObj)
	
	; Tooltip
	IniWrite(Opts.MouseMoveThreshold, "Tooltip", "MouseMoveThreshold", ItemInfoConfigObj)
	IniWrite(Opts.UseTooltipTimeout, "Tooltip", "UseTooltipTimeout", ItemInfoConfigObj)
	IniWrite(Opts.ToolTipTimeoutSeconds, "Tooltip", "ToolTipTimeoutSeconds", ItemInfoConfigObj)
	IniWrite(Opts.DisplayToolTipAtFixedCoords, "Tooltip", "DisplayToolTipAtFixedCoords", ItemInfoConfigObj)
	IniWrite(Opts.ScreenOffsetX, "Tooltip", "ScreenOffsetX", ItemInfoConfigObj)
	IniWrite(Opts.ScreenOffsetY, "Tooltip", "ScreenOffsetY", ItemInfoConfigObj)
	
	; GDI+
	IniWrite(Opts.UseGDI, "GDI", "Enabled", ItemInfoConfigObj)
	IniWrite(Opts.GDIRenderingFix, "GDI", "RenderingFix", ItemInfoConfigObj)
	IniWrite(Opts.GDIConditionalColors, "GDI", "ConditionalColors", ItemInfoConfigObj)
	IniWrite(Opts.GDIWindowColor, "GDI", "WindowColor", ItemInfoConfigObj)
	IniWrite(Opts.GDIWindowOpacity, "GDI", "WindowOpacity", ItemInfoConfigObj)
	IniWrite(Opts.GDIBorderColor, "GDI", "BorderColor", ItemInfoConfigObj)
	IniWrite(Opts.GDIBorderOpacity, "GDI", "BorderOpacity", ItemInfoConfigObj)
	IniWrite(Opts.GDITextColor, "GDI", "TextColor", ItemInfoConfigObj)
	IniWrite(Opts.GDITextOpacity, "GDI", "TextOpacity", ItemInfoConfigObj)
	
	; Lutbot
	IniWrite(Opts.Lutbot_CheckScript, "Lutbot", "Lutbot_CheckScript", ItemInfoConfigObj)
	IniWrite(Opts.Lutbot_WarnConflicts, "Lutbot", "Lutbot_WarnConflicts", ItemInfoConfigObj)
	
	ItemInfoConfigObj.Save(ConfigPath)
}

CopyDefaultConfig(config = "config.ini")
{
	FileCopy, %A_ScriptDir%\resources\default_UserFiles\%config%, %userDirectory%\%config%
}

RemoveConfig(config = "config.ini")
{
	FileDelete, %userDirectory%\%config%
}

StdOutStream(sCmd, Callback = "") {
	/*
		Runs commands in a hidden cmdlet window and returns the output.
	*/
							; Modified  :  Eruyome 18-June-2017
	Static StrGet := "StrGet"	; Modified  :  SKAN 31-Aug-2013 http://goo.gl/j8XJXY
							; Thanks to :  HotKeyIt         http://goo.gl/IsH1zs
							; Original  :  Sean 20-Feb-2007 http://goo.gl/mxCdn
	64Bit := A_PtrSize=8

	DllCall( "CreatePipe", UIntP,hPipeRead, UIntP,hPipeWrite, UInt,0, UInt,0 )
	DllCall( "SetHandleInformation", UInt,hPipeWrite, UInt,1, UInt,1 )

	If 64Bit {
		VarSetCapacity( STARTUPINFO, 104, 0 )		; STARTUPINFO          ;  http://goo.gl/fZf24
		NumPut( 68,         STARTUPINFO,  0 )		; cbSize
		NumPut( 0x100,      STARTUPINFO, 60 )		; dwFlags    =>  STARTF_USESTDHANDLES = 0x100
		NumPut( hPipeWrite, STARTUPINFO, 88 )		; hStdOutput
		NumPut( hPipeWrite, STARTUPINFO, 96 )		; hStdError

		VarSetCapacity( PROCESS_INFORMATION, 32 )	; PROCESS_INFORMATION  ;  http://goo.gl/b9BaI
	} Else {
		VarSetCapacity( STARTUPINFO, 68,  0 )		; STARTUPINFO          ;  http://goo.gl/fZf24
		NumPut( 68,         STARTUPINFO,  0 )		; cbSize
		NumPut( 0x100,      STARTUPINFO, 44 )		; dwFlags    =>  STARTF_USESTDHANDLES = 0x100
		NumPut( hPipeWrite, STARTUPINFO, 60 )		; hStdOutput
		NumPut( hPipeWrite, STARTUPINFO, 64 )		; hStdError

		VarSetCapacity( PROCESS_INFORMATION, 32 )	; PROCESS_INFORMATION  ;  http://goo.gl/b9BaI
	}

	If ! DllCall( "CreateProcess", UInt,0, UInt,&sCmd, UInt,0, UInt,0 ;  http://goo.gl/USC5a
				, UInt,1, UInt,0x08000000, UInt,0, UInt,0
				, UInt,&STARTUPINFO, UInt,&PROCESS_INFORMATION )
	Return ""
	, DllCall( "CloseHandle", UInt,hPipeWrite )
	, DllCall( "CloseHandle", UInt,hPipeRead )
	, DllCall( "SetLastError", Int,-1 )

	hProcess := NumGet( PROCESS_INFORMATION, 0 )
	If 64Bit {
		hThread  := NumGet( PROCESS_INFORMATION, 8 )
	} Else {
		hThread  := NumGet( PROCESS_INFORMATION, 4 )
	}

	DllCall( "CloseHandle", UInt,hPipeWrite )

	AIC := ( SubStr( A_AhkVersion, 1, 3 ) = "1.0" )                   ;  A_IsClassic
	VarSetCapacity( Buffer, 4096, 0 ), nSz := 0

	While DllCall( "ReadFile", UInt,hPipeRead, UInt,&Buffer, UInt,4094, UIntP,nSz, Int,0 ) {
		tOutput := ( AIC && NumPut( 0, Buffer, nSz, "Char" ) && VarSetCapacity( Buffer,-1 ) )
				? Buffer : %StrGet%( &Buffer, nSz, "CP850" )

		Isfunc( Callback ) ? %Callback%( tOutput, A_Index ) : sOutput .= tOutput
	}

	DllCall( "GetExitCodeProcess", UInt,hProcess, UIntP,ExitCode )
	DllCall( "CloseHandle",  UInt,hProcess  )
	DllCall( "CloseHandle",  UInt,hThread   )
	DllCall( "CloseHandle",  UInt,hPipeRead )
	DllCall( "SetLastError", UInt,ExitCode  )

	Return Isfunc( Callback ) ? %Callback%( "", 0 ) : sOutput
}

ReadConsoleOutputFromFile(command, fileName, ByRef error = "") {
	file := "temp\" fileName
	RunWait %comspec% /c "chcp 1251 /f >nul 2>&1 & %command% > %file%", , Hide
	FileRead, io, %file%
	
	If (FileExist(file) and not StrLen(io)) {
		error := "Output file is empty."
	}
	Else If (not FileExist(file)) {
		error := "Output file does not exist."
	}
	
	Return io
}

StrPutVar(Str, ByRef Var, Enc = "") {
	Len := StrPut(Str, Enc) * (Enc = "UTF-16" || Enc = "CP1200" ? 2 : 1)
	VarSetCapacity(Var, Len, 0)
	Return, StrPut(Str, &Var, Enc)
}

UriEncode(Uri, Enc = "UTF-8")	{
	StrPutVar(Uri, Var, Enc)
	f := A_FormatInteger
	SetFormat, IntegerFast, H
	Loop
	{
		Code := NumGet(Var, A_Index - 1, "UChar")
		If (!Code)
			Break
		If (Code >= 0x30 && Code <= 0x39 ; 0-9
			|| Code >= 0x41 && Code <= 0x5A ; A-Z
			|| Code >= 0x61 && Code <= 0x7A) ; a-z
			Res .= Chr(Code)
		Else
			Res .= "%" . SubStr(Code + 0x100, -1)
	}
	SetFormat, IntegerFast, %f%
	Return, Res
}

ScriptInfo(Command) {
	; https://autohotkey.com/boards/viewtopic.php?t=9656
	; Command must be "ListLines", "ListVars", "ListHotkeys" or "KeyHistory".
    static hEdit := 0, pfn, bkp
    if !hEdit {
        hEdit := DllCall("GetWindow", "ptr", A_ScriptHwnd, "uint", 5, "ptr")
        user32 := DllCall("GetModuleHandle", "str", "user32.dll", "ptr")
        pfn := [], bkp := []
        for i, fn in ["SetForegroundWindow", "ShowWindow"] {
            pfn[i] := DllCall("GetProcAddress", "ptr", user32, "astr", fn, "ptr")
            DllCall("VirtualProtect", "ptr", pfn[i], "ptr", 8, "uint", 0x40, "uint*", 0)
            bkp[i] := NumGet(pfn[i], 0, "int64")
        }
    }

    if (A_PtrSize=8) {  ; Disable SetForegroundWindow and ShowWindow.
        NumPut(0x0000C300000001B8, pfn[1], 0, "int64")  ; return TRUE
        NumPut(0x0000C300000001B8, pfn[2], 0, "int64")  ; return TRUE
    } else {
        NumPut(0x0004C200000001B8, pfn[1], 0, "int64")  ; return TRUE
        NumPut(0x0008C200000001B8, pfn[2], 0, "int64")  ; return TRUE
    }

    static cmds := {ListLines:65406, ListVars:65407, ListHotkeys:65408, KeyHistory:65409}
    cmds[Command] ? DllCall("SendMessage", "ptr", A_ScriptHwnd, "uint", 0x111, "ptr", cmds[Command], "ptr", 0) : 0

    NumPut(bkp[1], pfn[1], 0, "int64")  ; Enable SetForegroundWindow.
    NumPut(bkp[2], pfn[2], 0, "int64")  ; Enable ShowWindow.

    ControlGetText, text,, ahk_id %hEdit%
    return text
}

GetContributors(AuthorsPerLine=0)
{
	IfNotExist, %A_ScriptDir%\resources\AUTHORS.txt
	{
		return "`r`n AUTHORS.txt missing `r`n"
	}
	Authors := "`r`n"
	i := 0
	Loop, Read, %A_ScriptDir%\resources\AUTHORS.txt, `r, `n
	{
		Authors := Authors . A_LoopReadLine . " "
		i += 1
		IF (AuthorsPerLine != 0 and mod(i, AuthorsPerLine) == 0) ; every four authors
		{
			Authors := Authors . "`r`n"
		}
	}
	return Authors
}

ShowAssignedHotkeys(returnList = false) {
	scriptInfo	:= ScriptInfo("ListHotkeys")
	hotkeys		:= []

	Loop, Parse, scriptInfo, `n`r,
	{
		line		:= RegExReplace(A_Loopfield, "[\t]", "|")
		line		:= RegExReplace(line, "\|(?!\s)", "| ") . "|"
		fields	:= []

		If (StrLen(line)) {
			Pos		:= 0
			While Pos	:= RegExMatch(line, "i)(.*?\|+)", value, Pos + (StrLen(value) ? StrLen(value) : 1)) {
				fields.push(Trim(RegExReplace(value1, "\|")))
			}
			If (StrLen(fields[1]) and not InStr(fields[1], "--------")) {
				hotkeys.push(fields)
			}
		}
	}

	; supposed that array length wouldn't change, otherwise it's better to switch to associative array
	For key, val in hotkeys {
		If (key = 1) {
			val.Push("NameENG")
			val.Push("NameENGPretty")
		}
		Else {
			_keyName := KeyCodeToKeyName(val[5])
			val.Push(_keyName)
			val.Push(PrettyKeyName(_keyName))
		}
	}


	If (returnList) {
		Return hotkeys
	}

	Gui, ShowHotkeys:Color, ffffff, ffffff
	Gui, ShowHotkeys:Add, Text, , List of this scripts assigned hotkeys.
	Gui, ShowHotkeys:Default
	Gui, ShowHotkeys:Font, , Courier New
	Gui, ShowHotkeys:Font, , Consolas
	Gui, ShowHotkeys:Add, ListView, r25 w800 NoSortHdr Grid ReadOnly, Type | Enabled | Level | Running | Key combination (Code) | Key combination (ENG name) | Key combination (ENG pretty name)
	For key, val in hotkeys {
		If (key != 1) {
			LV_Add("", val*)
			LV_ModifyCol()
		}
	}

	i := 0
	Loop % LV_GetCount("Column")
	{
		i++
		LV_ModifyCol(a_index,"AutoHdr")
	}

	text := "reg: The hotkey is implemented via the operating system's RegisterHotkey() function." . "`n"
	text .= "reg(no): Same as above except that this hotkey is inactive (due to being unsupported, disabled, or suspended)." . "`n"
	text .= "k-hook: The hotkey is implemented via the keyboard hook." . "`n"
	text .= "m-hook: The hotkey is implemented via the mouse hook." . "`n"
	text .= "2-hooks: The hotkey requires both the hooks mentioned above." . "`n"
	text .= "joypoll: The hotkey is implemented by polling the joystick at regular intervals." . "`n"
	text .= "`n"
	text .= "Enabled: Hotkey is assigned but enabled/disabled [on/off] via the Hotkey command." . "`n"

	Gui, ShowHotkeys:Add, Text, , % text
	Gui, ShowHotkeys:Add, Link, x10 y+10 w210 h20 cBlue BackgroundTrans, <a href="http://www.autohotkey.com/docs/Hotkeys.htm">Hotkey Options</a>	
	
	Gui, ShowHotkeys:Show, w820 xCenter yCenter, Assigned Hotkeys
	Gui, SettingsUI:Default
	Gui, Font
}

CloseScripts() {
	; Close all active scripts listed in Globals.Get("ScriptList").
	; Can be used with scripts extending/including ItemInfo (TradeMacro for example) by adding to/altering this list.
	; Shortcut is placed in AdditionalMacros.txt

	scripts := Globals.Get("ScriptList")
	currentScript := A_ScriptDir . "\" . A_ScriptName
	SplitPath, currentScript, , , ext, currentscript_name_no_ext
	currentScript :=  A_ScriptDir . "\" . currentscript_name_no_ext

	DetectHiddenWindows, On

	Loop, % scripts.Length() {
		scriptPath := scripts[A_Index]

		; close current script last (with ExitApp)
		If (currentScript != scriptPath) {
			WinClose, %scriptPath% ahk_class AutoHotkey
		}
	}
	ExitApp
}

ColorBlindSupport() {
	IfWinActive, ahk_group PoEWindowGrp
	{
		Global Item, Opts, Globals, ItemData

		ClipBoardTemp := ClipboardAll
		SuspendPOEItemScript = 1 ; This allows us to handle the clipboard change event
		
		scancode_c := Globals.Get("ScanCodes").c

		; Parse the clipboard contents twice.
		; If the clipboard contains valid item data before we send ctrl + c to try and parse an item via ctrl + f then don't restore that clipboard data later on.
		; This prevents the highlighting function to fill search fields with data from previous item parsings/manual data copying since
		; that clipboard data would always be restored again.
		Loop, 2 {
			If (A_Index = 2) {
				Clipboard :=
				Send ^{%scancode_c%}	; ^{c}
				Sleep 100
			}
			CBContents := GetClipboardContents()
			CBContents := PreProcessContents(CBContents)
			Globals.Set("ItemText", CBContents)
			ParsedData := ParseItemData(CBContents)
			If (A_Index = 1 and Item.Name) {
				dontRestoreClipboard := true
			}
		}
		
		If (Item.Name) {
			Sleep,  100
			If (!dontRestoreClipboard) {
				Clipboard := ClipBoardTemp
			}
			
			If (Item.IsGem) {
				ShowToolTip("Gem color: " Item.GemColor)
			}
			Else If (Item.Sockets > 0) {
				sockets := Item.Sockets

				groups := StrSplit(Trim(Item.SocketString), "")
				groups[2] := groups[2] = "-" ? "--" : "  "
				groups[6] := groups[6] = "-" ? "--" : "  "
				groups[10] := groups[10] = "-" ? "--" : "  "
				
				str := " `n"
				If (sockets <= 2) {
					If (sockets = 1) {
						str .= "  " groups[1] "  "
					} Else {
						str .= " " groups[1] " " groups[2] " " groups[3] " "
					}					
					ShowToolTip(str "`n ")
				}
				Else If (sockets <= 4) {
					groups[7] := StrLen(groups[7]) ? groups[7] : " "
					groups[6] := StrLen(groups[6]) ? groups[6] : " "
					
					str .= " " groups[1] " " groups[2] " " groups[3] " `n"
					str .= (groups[4] = "-") ? "      |" : "      " 
					str .= "`n " groups[7] " " groups[6] " " groups[5] " "
					
					ShowToolTip(str "`n ")
				}
				Else {
					groups[11] := StrLen(groups[11]) ? groups[11] : " "
					groups[9] := StrLen(groups[9]) ? groups[9] : " "
					
					str .= " " groups[1] " " groups[2] " " groups[3] " `n"
					str .= (groups[4] = "-") ? "      |" : "      " 
					str .= "`n " groups[7] " " groups[6] " " groups[5] " `n"
					str .= (groups[8] = "-") ? " |    " : "     " 
					str .= "`n " groups[9] " " groups[10] " " groups[11] " "
					
					ShowToolTip(str "`n ")
					
				}
			}
		}

		SuspendPOEItemScript = 0 ; Allow Item info to handle clipboard change event
	}
}

HighlightItems(broadTerms = false, leaveSearchField = true, focusHideoutFilter = false, hideoutFieldX = 0, hideoutFieldY = 0) {
	; Highlights items via stash search (also in vendor and hideout search)
	IfWinActive, ahk_group PoEWindowGrp
	{
		Global Item, Opts, Globals, ItemData

		ClipBoardTemp := ClipboardAll
		SuspendPOEItemScript = 1 ; This allows us to handle the clipboard change event
		
		scancode_c := Globals.Get("ScanCodes").c
		scancode_v := Globals.Get("ScanCodes").v
		scancode_a := Globals.Get("ScanCodes").a
		scancode_f := Globals.Get("ScanCodes").f
		scancode_enter := Globals.Get("ScanCodes").enter

		; Parse the clipboard contents twice.
		; If the clipboard contains valid item data before we send ctrl + c to try and parse an item via ctrl + f then don't restore that clipboard data later on.
		; This prevents the highlighting function to fill search fields with data from previous item parsings/manual data copying since
		; that clipboard data would always be restored again.
		Loop, 2 {
			If (A_Index = 2) {
				Clipboard :=
				Send ^{%scancode_c%}	; ^{c}
				Sleep 100
			}
			CBContents := GetClipboardContents()
			CBContents := PreProcessContents(CBContents)
			Globals.Set("ItemText", CBContents)
			ParsedData := ParseItemData(CBContents)
			If (A_Index = 1 and Item.Name) {
				dontRestoreClipboard := true
			}
		}

		If (Item.Name) {
			rarity := ""
			If (Item.RarityLevel = 2) {
				rarity := "magic"
			} Else If (Item.RarityLevel = 3) {
				rarity := "rare"
			} Else If (Item.RarityLevel = 4) {
				rarity := "unique"
			}

			terms := []
			; uniques / gems / div cards
			If (Item.IsUnique or Item.IsGem or Item.IsDivinationCard) {
				If (broadTerms) {
					If (Item.IsUnique) {
						terms.push("Rarity: Unique")
					} Else {
						terms.push("Rarity: " Item.BaseType)
					}
				} Else {
					If (Item.IsUnique) {
						terms.push("Rarity: Unique")
					} Else {
						terms.push("Rarity: " Item.BaseType)
					}
					terms.push(Item.Name)
				}
			}
			; prophecies
			Else If (Item.IsProphecy) {
				If (broadTerms) {
					terms.push("this prophecy")
				} Else {
					terms.push("this prophecy")
					terms.push(Item.Name)
				}
			}
			; essences
			Else If (Item.IsEssence) {
				If (broadTerms) {
					terms.push("Rarity: Currency")
					terms.push("Essence")
				} Else {
					terms.push(Item.Name)
				}
			}
			; currency
			Else If (Item.IsCurrency) {
				If (broadTerms) {
					terms.push("Currency")
				} Else {
					terms.push(Item.Name)
				}
			}
			; maps
			Else If (Item.IsMap) {
				If (broadTerms) {
					terms.push(" Map")
				} Else {
					terms.push(Item.SubType)
					terms.push("tier:" Item.MapTier)
				}
			}
			; flasks
			Else If (Item.IsFlask) {
				If (broadTerms) {
					terms.push("Consumes")
					terms.push(Item.SubType)
				} Else {
					terms.push(Item.BaseName)
				}
			}
			; leaguestones and Scarabs
			Else If (Item.IsLeaguestone or Item.IsScarab) {
				If (broadTerms) {
					terms.push(Item.BaseType)
				} Else {
					terms.push(Item.SubType)
				}
			}
			; jewels
			Else If (Item.IsJewel) {
				If (broadTerms) {
					terms.push(Item.BaseType)
				} Else {
					If (Item.BaseName) {
						terms.push(Item.BaseName)	
					} Else {
						terms.push("Jewel")
					}					
					terms.push(rarity)
				}
			}
			; offerings / sacrifice and mortal fragments / guardian fragments / council keys / breachstones / reliquary keys
			Else If (RegExMatch(Item.Name, "i)Sacrifice At") or RegExMatch(Item.Name, "i)Fragment of") or RegExMatch(Item.Name, "i)Mortal ") or RegExMatch(Item.Name, "i)Offering to ") or RegExMatch(Item.Name, "i)'s Key") or RegExMatch(Item.Name, "i)Breachstone") or RegExMatch(Item.Name, "i)Reliquary Key") or RegExMatch(Item.Name, "i)Simulacrum")) {
				If (broadTerms) {
					tmpName := RegExReplace(Item.Name, "i)(Sacrifice At).*|(Fragment of).*|(Mortal).*|.*('s Key)|.*(Breachstone)|(Reliquary Key)|(Simulacrum)", "$1$2$3$4$5$6$7")
					terms.push(tmpName)
				} Else {
					terms.push(Item.Name)
				}
			}
			; other items (weapons, armour pieces, jewelry etc)
			Else {
				If (broadTerms) {
					If (Item.IsWeapon or Item.IsAmulet or Item.IsRing or Item.IsBelt or InStr(Item.SubType, "Shield")) {
						; add the term "Chance to Block" to remove items with "Energy Shield" from "Shield" searches
						If (InStr(Item.SubType, "Shield")) {
							terms.push("Chance to Block")
						}

						; add grip type to differentiate 1 and 2 handed weapons
						If (Item.GripType == "1H" and RegExMatch(Item.Subtype, "i)Sword|Mace|Axe")) {
							prefix := "One Handed"
						} Else If (Item.GripType == "2H") {
							prefix := "Two Handed"
						}

						; Handle Talismans, they have SubType "Amulet" but this won't be found ingame.
						If (Item.IsTalisman) {
							term := "Talisman Tier:"
						} Else {
							; add a space since all these terms have a preceding one, this reduces the chance of accidental matches
							; for example "Ring" found in "Voidbringers" or "during Flask effect"
							term := " " Item.SubType
						}

						terms.push(prefix . term)
					}
					; armour pieces are a bit special, the ingame information doesn't include "armour/body armour" or something alike.
					; we can use the item defences though to match armour pieces with the same defence types (can't differentiate between "Body Armour" and "Helmet").
					Else If (InStr(Item.BaseType, "Armour")) {
						For key, val in ItemData.Parts {
							If (RegExMatch(val, "i)(Energy Shield:)|(Armour:)|(Evasion Rating:)", match)) {
								Loop, 3 {
									If (StrLen(match%A_Index%)) {
										terms.push(match%A_Index%)
									}
								}
							}
						}
					}
				} Else {			
					If (Item.BaseName) {
						terms.push(Item.BaseName)	
					} Else {
						terms.push(Trim(RegExReplace(Item.Name, "Superior")))
					}
				}
			}
		}

		If (terms.length() > 0) {
			focusHideoutFilter := true
			If (Item.IsHideoutObject and focusHideoutFilter) {				
				CoordMode, Mouse, Relative
				MouseGetPos, currentX, currentY
				MouseMove, %hideoutFieldX%, %hideoutFieldY%, 0
				Sleep, 10
				MouseClick
				Sleep, 50
				MouseMove, %currentX%, %currentY%, 0
				Sleep, 10
				SendInput ^{%scancode_a%}
			} Else {
				SendInput ^{%scancode_f%} ; sc021 = f	
			}

			searchText = 
			For key, val in terms {
				If (not Item.IsHideoutObject) {
					searchText = %searchText% "%val%"
				} Else {
					; hideout objects shouldn't use quotation marks
					searchText = %searchText% %val%
				}				
			}

			; search fields have character limits
			; stash search field := 50 chars , we have to close the last term with a quotation mark
			; hideout mtx search field := 23 chars	
			charLimit := Item.IsHideoutObject ? 23 : 50
	
			If (StrLen(searchText) > charLimit) {
				newString := SubStr(searchText, 1, charLimit)

				temp := RegExReplace(newString, "i)""", Replacement = "", QuotationMarks)
				; make sure we have an equal amount of quotation marks (all terms properly enclosed)
				If (QuotationMarks&1) {
					searchText := RegExReplace(newString, "i).$", """")
				} Else {
					searchText := newString
				}
			}

			Clipboard := searchText
	
			Sleep 10
			SendEvent ^{%scancode_v%}		; ctrl + v
			
			If (not (Item.IsHideoutObject and focusHideoutFilter)) {
				If (leaveSearchField) {
					SendInput {%scancode_enter%}	; enter
				} Else {
					SendInput ^{%scancode_a%}	; ctrl + a
				}
			}
		} Else {
			SendInput ^{%scancode_f%}		; send ctrl + f in case we don't have information to input
		}

		Sleep,  500
		If (!dontRestoreClipboard) {
			Clipboard := ClipBoardTemp
		}
		SuspendPOEItemScript = 0 ; Allow Item info to handle clipboard change event
	}
}

AdvancedItemInfoExt() {
	IfWinActive, ahk_group PoEWindowGrp
	{
		Global Item, Opts, Globals, ItemData

		ClipBoardTemp := ClipboardAll
		SuspendPOEItemScript = 1 ; This allows us to handle the clipboard change event

		Clipboard :=
		scancode_c := Globals.Get("Scancodes").c
		Send ^{%scancode_c%}	; ^{c}
		Sleep 100

		CBContents := GetClipboardContents()
		CBContents := PreProcessContents(CBContents)
		Globals.Set("ItemText", CBContents)
		ParsedData := ParseItemData(CBContents)

		If (Item.Name) {			
			url 	:= "http://pathof.info/?item=" StringToBase64UriEncoded(CBContents)
			openWith := AssociatedProgram("html")
			OpenWebPageWith(openWith, Url)
		}
		SuspendPOEItemScript = 0
	}
}

OpenItemOnPoEAntiquary() {
	IfWinActive, ahk_group PoEWindowGrp
	{
		Global Item, Opts, Globals, ItemData

		ClipBoardTemp := ClipboardAll
		SuspendPOEItemScript = 1 ; This allows us to handle the clipboard change event

		Clipboard :=
		scancode_c := Globals.Get("Scancodes").c
		Send ^{%scancode_c%}	; ^{c}
		Sleep 100

		CBContents := GetClipboardContents()
		CBContents := PreProcessContents(CBContents)
		Globals.Set("ItemText", CBContents)
		ParsedData := ParseItemData(CBContents)
		
		If (Item.Name) {			
			global AntiquaryData := []
			global AntiquaryType := AntiquaryGetType(Item)
			
			If (AntiquaryType) {
				If (AntiquaryType = "Map") {
					name := Item.BaseName
				} Else {
					name := Item.Name
				}

				url := "http://poe-antiquary.xyz/api/macro/" UriEncode(AntiquaryType) "/" UriEncode(Item.Name)			
				
				postData 	:= ""					
				options	:= "RequestType: GET"
				options	.= "`n" "TimeOut: 15"
				reqHeaders := []
				
				reqHeaders.push("Connection: keep-alive")
				reqHeaders.push("Cache-Control: max-age=0")
				reqHeaders.push("Upgrade-Insecure-Requests: 1")
				reqHeaders.push("Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8")
				
				data := PoEScripts_Download(url, postData, reqHeaders, "", true)

				Try {
					AntiquaryData := JSON.Load(data)
				} Catch error {
					errorMsg := error.Message
					Msgbox, %errorMsg%
				}

				name := AntiquaryData["name"]
				lastLeague := AntiquaryData["league"]
				itemType := AntiquaryData["itemType"]
				items := AntiquaryData.items
				length := items.Length()
				
				If (length == 0) {
					ShowToolTip("Item not available on http://poe-antiquary.xyz.")
				}
				Else If (length == 1) {
					id := items[1].id
					AntiquaryOpenInBrowser(itemType, name, id, lastLeague)
				}
				Else If (length > 1) {
					AntiquaryOpenInBrowser(itemType, name, id, lastLeague, length)
				}
			}
		}
		Else {			
			ShowToolTip("Item parsing failed, no name recognized.")
		}
		SuspendPOEItemScript = 0
	}
}

AntiquaryOpenInBrowser(type, name, id, lastLeague, multiItems = false) {
	league := TradeGlobals.Get("LeagueName")
	If (RegExMatch(league, "Hardcore.*")) {
		league := lastLeague " HC"
	} Else {
		league := lastLeague
	}
	
	league	:= UriEncode(league)
	type		:= UriEncode(type)
	name		:= UriEncode(name)
	id		:= UriEncode(id)
	utm		:= UriEncode("trade macro")
	
	If (multiItems) {
		url := "http://poe-antiquary.xyz/" league "/" type "?name=" name ;"?utm_source=" utm "&utm_medium=" utm "&utm_campaign=" utm		
	}
	Else {
		url := "http://poe-antiquary.xyz/" league "/" type "/" name "/" id ;"?utm_source=" utm "&utm_medium=" utm "&utm_campaign=" utm	
	}
	openWith := AssociatedProgram("html")
	OpenWebPageWith(openWith, url)
}

AntiquaryGetType(Item) {
	If (Item.IsUnique) {
		If (Item.IsWeapon) {
			return "Weapon"
		}
		If (Item.IsArmour) {
			return "Armour"
		}
		If (Item.IsFlask) {
			return "Flask"
		}
		If (Item.IsJewel) {
			return "Jewel"
		}
		If (Item.IsBelt or Item.IsRing or Item.IsAmulet) {
			return "Accessory"
		}
	}
	If (Item.IsEssence) {
		return "Essence"
	}
	If (Item.IsDivinationCard) {
		return "Divination"
	}
	If (Item.IsProphecy) {
		return "Prophecy"
	}
	If (Item.IsMapFragment) {
		return "Fragment"
	}
	If (Item.IsMap) {
		If (Item.IsUnique) {
			return "Unique Map"
		} Else {
			return "Map"	
		}		
	}
	If (RegExMatch(Item.Name, "(Sacrifice|Mortal|Fragment).*|Offering to the Goddess|Divine Vessel|Simulacrum|.*(Breachstone|s Key)")) {
		return "Fragment"
	}
	If (Item.IsCurrency) {
		return "Currency"
	}
}


StringToBase64UriEncoded(stringIn, noUriEncode = false, ByRef errorMessage = "") {
	FileDelete, %A_ScriptDir%\temp\itemText.txt
	FileDelete, %A_ScriptDir%\temp\base64Itemtext.txt
	FileDelete, %A_ScriptDir%\temp\encodeToBase64.txt
	
	encodeError1 := ""
	encodeError2 := ""
	stringBase64 := b64Encode(stringIn, encodeError1)
	
	If (not StrLen(stringBase64)) {
		FileAppend, %stringIn%, %A_ScriptDir%\temp\itemText.txt, utf-8
		command		:= "certutil -encode -f ""%cd%\temp\itemText.txt"" ""%cd%\temp\base64ItemText.txt"" & type ""%cd%\temp\base64ItemText.txt"""
		stringBase64	:= ReadConsoleOutputFromFile(command, "encodeToBase64.txt", encodeError2)
		stringBase64	:= Trim(RegExReplace(stringBase64, "i)-----BEGIN CERTIFICATE-----|-----END CERTIFICATE-----|77u/", ""))
	}

	If (not StrLen(stringBase64)) {
		errorMessage := ""
		If (StrLen(encodeError1)) {
			errorMessage .= encodeError1 " "
		}
		If (StrLen(encodeError2)) {
			errorMessage .= "Encoding via certutil returned: " encodeError2
		}
	}
	
	If (not noUriEncode) {
		stringBase64	:= UriEncode(stringBase64)
		stringBase64	:= RegExReplace(stringBase64, "i)^(%0D)?(%0A)?|((%0D)?(%0A)?)+$", "")
	} Else {
		stringBase64 := RegExReplace(stringBase64, "i)\r|\n", "")
	}
	
	Return stringBase64
}

/*
	Base64 Encode / Decode a string (binary-to-text encoding)
	https://github.com/jNizM/AHK_Scripts/blob/master/src/encoding_decoding/base64.ahk
	
	Alternative: https://github.com/cocobelgica/AutoHotkey-Util/blob/master/Base64.ahk
*/
b64Encode(string, ByRef error = "") {	
	VarSetCapacity(bin, StrPut(string, "UTF-8")) && len := StrPut(string, &bin, "UTF-8") - 1 
	If !(DllCall("crypt32\CryptBinaryToString", "ptr", &bin, "uint", len, "uint", 0x1, "ptr", 0, "uint*", size)) {
		;throw Exception("CryptBinaryToString failed", -1)
		error := "Exception (1) while encoding string to base64."
	}	
	VarSetCapacity(buf, size << 1, 0)
	If !(DllCall("crypt32\CryptBinaryToString", "ptr", &bin, "uint", len, "uint", 0x1, "ptr", &buf, "uint*", size)) {
		;throw Exception("CryptBinaryToString failed", -1)
		error := "Exception (2) while encoding string to base64."
	}
	
	If (not StrLen(Error)) {
		Return StrGet(&buf)
	} Else {
		Return ""
	}
}

b64Decode(string)
{
	If !(DllCall("crypt32\CryptStringToBinary", "ptr", &string, "uint", 0, "uint", 0x1, "ptr", 0, "uint*", size, "ptr", 0, "ptr", 0))
		throw Exception("CryptStringToBinary failed", -1)
	VarSetCapacity(buf, size, 0)
	If !(DllCall("crypt32\CryptStringToBinary", "ptr", &string, "uint", 0, "uint", 0x1, "ptr", &buf, "uint*", size, "ptr", 0, "ptr", 0))
		throw Exception("CryptStringToBinary failed", -1)
	return StrGet(&buf, size, "UTF-8")
}

OpenWebPageWith(application, url) {
	If (InStr(application, "iexplore")) {
		ie := ComObjCreate("InternetExplorer.Application")
		ie.Visible:=True
		ie.Navigate(url)
	} Else If (InStr(application, "launchwinapp")) {
		; Microsoft Edge
		Run, %comspec% /c "chcp 1251 & start microsoft-edge:%Url%", , Hide
	} Else {
		args := ""
		If (StrLen(application)) {
			args := "-new-tab"
			Try {
				Run, "%application%" %args% "%Url%"
			} Catch e {
				Run, "%application%" "%Url%"
			}
		} Else {
			Run %Url%
		}
	}
	Return
}

LookUpAffixes_old() {
	/*
		Opens item base on poeaffix.net
	*/
	IfWinActive, ahk_group PoEWindowGrp
	{
		Global Item, Opts, Globals, ItemData

		ClipBoardTemp := ClipboardAll
		SuspendPOEItemScript = 1 ; This allows us to handle the clipboard change event

		Clipboard :=
		scancode_c := Globals.Get("Scancodes").c
		Send ^{%scancode_c%}	; ^{c}
		Sleep 100

		CBContents := GetClipboardContents()
		CBContents := PreProcessContents(CBContents)
		Globals.Set("ItemText", CBContents)
		ParsedData := ParseItemData(CBContents)
		If (Item.Name) {
			dontRestoreClipboard := true
		}

		If (Item.Name) {
			url := "http://poeaffix.net/"
			If (RegExMatch(Item.BaseName, "i)Sacrificial Garb")) {
				url 		.= "ch-garb" ; ".html"
			} Else {
				ev		:= RegExMatch(ItemData.Stats, "i)Evasion Rating") ? "ev" : ""
				ar		:= RegExMatch(ItemData.Stats, "i)Armour") ? "ar" : ""
				es		:= RegExMatch(ItemData.Stats, "i)Energy Shield") ? "es" : ""
				RegExMatch(Item.SubType, "i)Axe|Sword|Mace|Sceptre|Bow|Staff|Wand|Fish|Dagger", weapon)
				RegExMatch(Item.Subtype, "i)Amulet|Ring|Belt|Quiver|Flask", accessory)
				RegExMatch(Item.Subtype, "i)Cobalt|Viridian|Crimson", jewel)

				suffix	:= ar . ev . es . weapon . accessory . jewel
				StringLower, suffix, suffix

				boots	:= RegExMatch(Item.Subtype, "i)Boots") ? "bt" : ""
				chest 	:= RegExMatch(Item.Subtype, "i)BodyArmour") ? "ch" : ""
				gloves 	:= RegExMatch(Item.Subtype, "i)Gloves") ? "gl" : ""
				helmet 	:= RegExMatch(Item.Subtype, "i)Helmet") ? "hm" : ""
				shield 	:= RegExMatch(Item.Subtype, "i)Shield") ? "sh" : ""
				ac		:= StrLen(accessory) ? "ac" : ""
				jw		:= StrLen(jewel) ? "jw" : ""
				gripType 	:= Item.GripType != "None" ? Item.GripType : ""

				prefix	:= boots . chest . gloves . helmet . shield . gripType . ac . jw
				StringLower, prefix, prefix

				url		.= prefix "-" suffix ".html"
			}
			openWith := AssociatedProgram("html")
			OpenWebPageWith(openWith, Url)
		}

		Sleep, 10
		If (!dontRestoreClipboard) {
			Clipboard := ClipBoardTemp
		}
		SuspendPOEItemScript = 0 ; Allow Item info to handle clipboard change event
	}
}

LookUpAffixes() {
	/*
		Opens item base on poeaffix.net
	*/
	IfWinActive, ahk_group PoEWindowGrp
	{
		Global Item, Opts, Globals, ItemData

		ClipBoardTemp := ClipboardAll
		SuspendPOEItemScript = 1 ; This allows us to handle the clipboard change event

		Clipboard :=
		scancode_c := Globals.Get("Scancodes").c
		Send ^{%scancode_c%}	; ^{c}
		Sleep 100

		CBContents := GetClipboardContents()
		CBContents := PreProcessContents(CBContents)
		Globals.Set("ItemText", CBContents)
		ParsedData := ParseItemData(CBContents)
		If (Item.Name) {
			dontRestoreClipboard := true
		}
		
		If (Item.Name) {
			url := "https://poedb.tw/us/mod.php"

			ev		:= RegExMatch(ItemData.Stats, "i)Evasion Rating") ? true : false
			ar		:= RegExMatch(ItemData.Stats, "i)Armour") ? true : false
			es		:= RegExMatch(ItemData.Stats, "i)Energy Shield") ? true : false
			RegExMatch(Item.SubType, "i)Axe|Sword|Mace|Sceptre|Bow|Wand|Claw|Wand|Rune Dagger|Dagger|Fishing Rod|Warstaff|Staff", weapon)
			RegExMatch(Item.Subtype, "i)Amulet|Ring|Belt|Quiver|Flask", accessory)
			RegExMatch(Item.Subtype, "i)Cobalt|Viridian|Crimson|Prismatic|Murderous Eye|Searching Eye|Ghastly Eye|Hypnotic Eye|Timeless", jewel)

			boots	:= RegExMatch(Item.Subtype, "i)Boots") ? "?cn=Boots" : ""
			chest 	:= RegExMatch(Item.Subtype, "i)BodyArmour") ? "?cn=Body+Armour" : ""
			gloves 	:= RegExMatch(Item.Subtype, "i)Gloves") ? "?cn=Gloves" : ""
			helmet 	:= RegExMatch(Item.Subtype, "i)Helmet") ? "?cn=Helmet" : ""
			shield 	:= RegExMatch(Item.Subtype, "i)Shield") ? "?cn=Shield" : ""

			If (StrLen(weapon)) {
				If (RegExMatch(weapon, "i)Axe|Sword|Mace")) {
					gripType 	:= Item.GripType == "1H" ? "One%20Hand%20" : "Two%20Hand%20"
				}					
				If (weapon = "Fishing Rod") {
					weapon := "FishingRod"
				}
				weapon := RegExReplace(weapon, "i)\s", "%20")

				url		.= "?cn=" gripType . weapon
			} 
			Else If (Item.BaseType == "Armour") {
				url		.= boots . chest . gloves . helmet . shield					
				If (ar and ev and es) {
					url	.= "&an=str_dex_int_armour"
				} Else If (ar and ev) {
					url	.= "&an=str_dex_armour"
					url	.= StrLen(shield) ? ",str_dex_shield" : ""
				} Else If (ar and es) {
					url	.= "&an=str_int_armour"
					url	.= StrLen(shield) ? ",str_int_shield" : "" 
				} Else If (ev and es) {
					url	.= "&an=dex_int_armour"
					url	.= StrLen(shield) ? ",dex_int_shield" : ""
				} Else If (ar) {
					url	.= "&an=str_armour"
					url	.= StrLen(shield) ? ",str_shield" : ""
				} Else If (ev) {
					url	.= "&an=dex_armour"
					url	.= StrLen(shield) ? ",dex_shield" : ""
				} Else If (es) {
					url	.= "&an=int_armour"
					url	.= StrLen(shield) ? ",focus" : ""
				}
			}
			Else If (StrLen(accessory)) {
				If (accessory = "ring") {
					url	.= "?cn=" accessory "&an=unset_ring"
				} Else If (RegExMatch(accessory, "i)Life Flask")) {
					url	.= "?cn=LifeFlask"
				} Else If (RegExMatch(accessory, "i)Mana Flask")) {
					url	.= "?cn=ManFlask"
				} Else If (RegExMatch(accessory, "i)Diamond Flask")) {
					url	.= "?cn=CriticalUtilityFlask"
				} Else If (RegExMatch(accessory, "i)Flask")) {
					url	.= "?cn=UtilityFlask"
				} Else {
					url	.= "?cn=" accessory
				}
			}
			Else If (StrLen(jewel)) {
				url	.= "?cn=BaseItemTypes"
				url	.= "&an=" RegExReplace(jewel, "i)\s", "+") "Jewel"
			}

			openWith := AssociatedProgram("html")
			OpenWebPageWith(openWith, Url)
		}

		Sleep, 10
		If (!dontRestoreClipboard) {
			Clipboard := ClipBoardTemp
		}
		SuspendPOEItemScript = 0 ; Allow Item info to handle clipboard change event
	}
}

; ########### TIMERS ############

; Tick every 100 ms
; Remove tooltip if mouse is moved or x seconds pass
ToolTipTimer:
	Global Opts, ToolTipTimeout, gdipTooltip
	ToolTipTimeout += 1
	MouseGetPos, CurrX, CurrY
	MouseMoved := (CurrX - X) ** 2 + (CurrY - Y) ** 2 > Opts.MouseMoveThreshold ** 2
	If (MouseMoved or ((UseTooltipTimeout == 1) and (ToolTipTimeout >= Opts.ToolTipTimeoutSeconds*10)))
	{
		SetTimer, ToolTipTimer, Off
		If (Opts.UseGDI or gdipTooltip.GetVisibility()) 
		{
			gdipTooltip.HideGdiTooltip(true)
		}
		Else
		{
			ToolTip
		}
		
		; close item filter nameplate
		fullScriptPath := A_ScriptDir "\lib\PoEScripts_ItemFilterNamePlate.ahk"
		DetectHiddenWindows, On
		WinClose, %fullScriptPath% ahk_class AutoHotkey
		WinKill, %fullScriptPath% ahk_class AutoHotkey
	}
	return

OnClipBoardChange:
	Global Opts
	IF SuspendPOEItemScript = 0
	{
		If (Opts.OnlyActiveIfPOEIsFront)
		{
			; do nothing if Path of Exile isn't the foremost window
			IfWinActive, ahk_group PoEWindowGrp
			{
				ParseClipBoardChanges()
			}
		}
		Else
		{
			; if running tests parse clipboard regardless if PoE is foremost
			; so we can check individual cases from test case text files
			ParseClipBoardChanges()
		}
	}
	return

ShowUpdateNotes:
	ShowUpdateNotes()
	return
	
ShowTranslationUI:
	ShowTranslationUI()
	return

TranslationUI_BtnTranslate:
	Gui, Translate:Submit, NoHide
	GuiControlGet, cbTransData, , TranslationEditInput
	CBContents := PreProcessContents(cbTransData)
	CBContents := PoEScripts_TranslateItemData(CBContents, translationData, currentLocale, retObj, retCode)
	GuiControl, Translate:, TranslationEditOutput, % CBContents
	GuiControl, Translate:, TranslationEditOutputDebug, % DebugPrintarray(retObj, 0)
	CBContents :=
	return

TranslationUI_BtnCancel:
	Gui, Translate:Destroy
	return
	
TranslationUI_BtnCopyToClipboard:
	Gui, Translate:Submit, NoHide
	SuspendPOEItemScript = 1
	GuiControlGet, cbTransData, , TranslationEditOutput
	Clipboard := cbTransData
	SuspendPOEItemScript = 0
	return

ShowTranslationUI() {
	Global 
	
	Gui, Translate:Destroy
	Gui, Translate:Color, ffffff, ffffff
	
	Gui, Translate:Margin, 10 , 10
	Gui, Translate:Add, Text, , Add your copied item information to translate it to english. The rightmost column shows some debug information. 
	
	TransGuiWidth	:= 1300
	TransGuiHeight	:= 750
	TransEditWidth	:= 375
	TransEditDebugWidth := 500
	TransEditHeight := (TransGuiHeight - 115)
	TransGuiSecondColumnPosX := TransEditWidth + 30
	TransGuiCopyButtonPosX := TransGuiWidth - 130 - 500
	TransGuiTransButtonPosX := TransEditWidth + 10 - 100
	TransGuiCloseButtonPosX := TransGuiWidth - 110

	Gui, Translate:Font, bold, Tahoma
	Gui, Translate:Add, Text, y+20, Add item text (copied ingame via ctrl + c)
	Gui, Translate:Font
	Gui, Translate:Add, Button, yp-5 w100 x%TransGuiTransButtonPosX% gTranslationUI_BtnTranslate, Translate
	Gui, Translate:Font, bold, Tahoma
	Gui, Translate:Add, Text, yp+5 x%TransGuiSecondColumnPosX%, Translated text
	Gui, Translate:Font
	Gui, Translate:Add, Button, yp-5 w100 x%TransGuiCopyButtonPosX% gTranslationUI_BtnCopyToClipboard, Copy (Clipboard)
	Gui, Translate:Font, , Consolas 
	Gui, Translate:Add, Edit, w%TransEditWidth% h%TransEditHeight% y+5 x10 HScroll vTranslationEditInput hwndTransateEditHwnd, 	
	Gui, Translate:Add, Edit, w%TransEditWidth% h%TransEditHeight% yp+0 x+20 HScroll vTranslationEditOutput ReadOnly, 
	Gui, Translate:Add, Edit, w%TransEditDebugWidth% h%TransEditHeight% yp+0 x+10 HScroll vTranslationEditOutputDebug ReadOnly, 
	Gui, Translate:Font
	
	Gui, Translate:Add, Button, x%TransGuiCloseButtonPosX% y+15 w100 gTranslationUI_BtnCancel, Close
	
	ControlFocus, , ahk_id %TransateEditHwnd%
	Gui, Translate:Show, w%TransGuiWidth% h%TransGuiHeight%, Translate Item Data
}

ChangedUserFilesWindow_Cancel:
	Gui, ChangedUserFiles:Cancel
	return

ChangedUserFilesWindow_OpenFolder:
	Gui, ChangedUserFiles:Cancel
	GoSub, EditOpenUserSettings
	return

LV_HotkeyEdit:
	If (not RegexMatch(A_GuiControlEvent, "Normal|DoubleClick")) {
		Return
	}
	If (RegExMatch(A_GuiControl, "i).*_Trigger$")) {
		_LVID := RegExReplace(A_GuiControl, "i)(.*)_Trigger$", "$1")
	} Else {
		_LVID := A_GuiControl
	}
	
	; check keyboard layout = eng_US and switch to if not, quick and dirty workaround
	; to support non-latin layouts (russian etc)
	; TODO: remove later
	_ENG_US := 0x4090409
	_Defaultlayout := GetCurrentLayout()
	If (GetKeySC("d") = 0 and _Defaultlayout != _ENG_US) {	 
	;If (_Defaultlayout != _ENG_US) {
		console.log("change layout")
		SwitchLayoutStart := A_TickCount
		SwitchLayoutElapsed := 0
		While (GetCurrentLayout() != _ENG_US and SwitchLayoutElapsed < 120) {
			SwitchLayout(_ENG_US)
			Sleep, 50
			SwitchLayoutElapsed := (A_TickCount - SwitchLayoutStart) / 1000
		}
		_switched := (GetCurrentLayout() != _Defaultlayout) ? true : false
	}
	
	Gui, ListView, %_LVID%
	LV_GetText(_oV, 1, 2)
	
	_prompt := "Please hold down the keys or mouse buttons you want to turn into a hotkey:"
	_note := "The majority of common keys from latin keyboard layouts should work."
	If (_switched) {
		_note := "`n`n" . "Forcibly switched to en_US layout because your layout seems to be unsupported."
	}
	_nV := Hotkey("+Tooltips", _prompt, _note, "Choose a Hotkey")
	
	; TODO: remove later
	If (_switched) {
		SwitchLayout(_Defaultlayout)
		console.log("changed layout back")
	}	
	
	LV_Delete(1)	
	If (not StrLen(_nV)) {
		_nV := _oV
	}
	LV_Add("","",_nV)
Return

ShowSettingsUI:
	ReadConfig()
	Sleep, 50
	UpdateSettingsUI()
	Sleep, 50
	ShowSettingsUI()
	return

SettingsUI_BtnOK:
	Global Opts
	Gui, SettingsUI:Submit
	Sleep, 50
	WriteConfig()
	AM_WriteConfig()
	UpdateSettingsUI()
	Fonts.SetFixedFont(GuiGet("FontSize", Opts.FontSize))
	return

SettingsUI_BtnCancel:
	Gui, SettingsUI:Cancel
	return

SettingsUI_BtnDefaults:
	Gui, SettingsUI:Cancel
	RemoveConfig()
	Sleep, 75
	CopyDefaultConfig()
	Sleep, 75
	ReadConfig()
	Sleep, 75
	UpdateSettingsUI()
	ShowSettingsUI()
	return
	
SettingsUI_AM_BtnDefaults:
	Gui, SettingsUI:Cancel
	RemoveConfig("AdditionalMacros.ini")
	Sleep, 75
	CopyDefaultConfig("AdditionalMacros.ini")
	Sleep, 75
	AM_ReadConfig(AM_Config)
	Sleep, 75
	UpdateSettingsUI()
	ShowSettingsUI()
	AM_SetHotkeys()
	Return

InitGDITooltip:
	Global Opts
	; some users experience FPS drops when gdi tooltip is initialized.
	If (Opts.UseGDI) {
		global gdipTooltip = new GdipTooltip(2, 8,,,[Opts.GDIWindowOpacity, Opts.GDIWindowColor, 10],[Opts.GDIBorderOpacity, Opts.GDIBorderColor, 10],[Opts.GDITextOpacity, Opts.GDITextColor, 10],true, Opts.RenderingFix, -0.3)
	}
	return


OpenGDIColorPicker(type, rgb, opacity, title, image) {
	; GDI+
	global
	_defaultColor		:= Opts["GDI" type "Color"]
	_defaultOpacity	:= Opts["GDI" type "Opacity"]
	_rgb				:= gdipTooltip.ValidateRGBColor(rgb, _defaultColor)
	_opacity			:= gdipTooltip.ValidateOpacity(opacity, _defaultOpacity, 10, 10)
	_ColorHandle		:= GDI%_type%ColorH
	_OpacityHandle		:= GDI%_type%OpacityH
	
	ColorPickerResults	:= new ColorPicker(_rgb, _opacity, title, image)
	If (StrLen(ColorPickerResults[2])) {		
		GuiControl, , % _ColorHandle, % ColorPickerResults[2]
		GuiControl, , % _OpacityHandle, % ColorPickerResults[3]	
	}
}

SettingsUI_BtnGDIWindowColor:
	_image	:= A_ScriptDir "\resources\images\colorPickerPreviewBg.png"	
	_type	:= "Window"
	GuiControlGet, _cGDIColor  , , % GDIWindowColorH
	GuiControlGet, _cGDIOpacity, , % GDIWindowOpacityH
	OpenGDIColorPicker(_type, _cGDIColor, _cGDIOpacity, "GDI+ Tooltip " _type " Color Picker", _image)
	return
	
SettingsUI_BtnGDIBorderColor:
	_image	:= A_ScriptDir "\resources\images\colorPickerPreviewBg.png"	
	_type	:= "Border"
	GuiControlGet, _cGDIColor  , , % GDIBorderColorH
	GuiControlGet, _cGDIOpacity, , % GDIBorderOpacityH	
	OpenGDIColorPicker(_type, _cGDIColor, _cGDIOpacity, "GDI+ Tooltip " _type " Color Picker", _image)
	return
	
SettingsUI_BtnGDITextColor:
	_image	:= A_ScriptDir "\resources\images\colorPickerPreviewBg.png"	
	_type	:= "Text"
	GuiControlGet, _cGDIColor  , , % GDITextColorH
	GuiControlGet, _cGDIOpacity, , % GDITextOpacityH
	OpenGDIColorPicker(_type, _cGDIColor, _cGDIOpacity, "GDI+ Tooltip " _type " Color Picker", _image)
	return

SettingsUI_BtnGDIPreviewTooltip:
	; temporarily save GDI state as true
	_tempGDIState := Opts.UseGDI
	_tempGDIRenderingFixState := Opts.GDIRenderingFix
	GuiControlGet, _tempUseGDI, , % UseGDIH
	Opts.UseGDI := _tempUseGDI
	
	GuiControlGet, _tempGDIWindowColor   , , % GDIWindowColorH
	GuiControlGet, _tempGDIWindowOpacity , , % GDIWindowOpacityH
	GuiControlGet, _tempGDIBorderColor   , , % GDIBorderColorH
	GuiControlGet, _tempGDIBorderOpacity , , % GDIBorderOpacityH
	GuiControlGet, _tempGDITextColor   , , % GDITextColorH
	GuiControlGet, _tempGDITextOpacity , , % GDITextOpacityH
	GuiControlGet, _tempGDIRenderingFix , , % GDIRenderingFixH
	gdipTooltip.SetRenderingFix(_tempGDIRenderingFix)
	gdipTooltip.UpdateColors(_tempGDIWindowColor, _tempGDIWindowOpacity, _tempGDIBorderColor, _tempGDIBorderOpacity, _tempGDITextColor, _tempGDITextOpacity, "10", "16")
	_testString =
	(
		TOOLIP Preview Window
		
		Voidbringer
		Conjurer Gloves
		Item Level:    70
		Base Level:    55
		Max Sockets:    4
		--------
		+1 to Level of Socketed Elem…          
		Increased Critical Strike Ch… 125-150  
		Increased Energy Shield       180-250  
		Increased Mana Cost of Skill…   80-40  
		Energy Shield gained on Kill    15-20
	)
	
	If (not IsObject(gdipTooltip.window)) {
		GoSub, InitGDITooltip
	}
	
	ShowToolTip(_testString)
	; reset options
	Opts.UseGDI := _tempGDIState
	Opts.GDIRenderingFix := _tempGDIRenderingFixState
	gdipTooltip.SetRenderingFix(Opts.GDIRenderingFix)
	gdipTooltip.UpdateColors(Opts.GDIWindowColor, Opts.GDIWindowOpacity, Opts.GDIBorderColor, Opts.GDIBorderOpacity, Opts.GDITextColor, Opts.GDITextOpacity, "10", "16")
	return

SettingsUI_BtnGDIDefaults:
	GuiControl, , % GDIWindowColorH  , % Opts.GDIWindowColorDefault 
	GuiControl, , % GDIWindowOpacityH, % Opts.GDIWindowOpacityDefault
	GuiControl, , % GDIBorderColorH  , % Opts.GDIBorderColorDefault
	GuiControl, , % GDIBorderOpacityH, % Opts.GDIBorderOpacityDefault 
	GuiControl, , % GDITextColorH    , % Opts.GDITextColorDefault
	GuiControl, , % GDITextOpacityH  , % Opts.GDITextOpacityDefault
	return

SettingsUI_ChkUseGDI:
	; GDI+
	GuiControlGet, IsChecked,, UseGDI
	If (Not IsChecked)
	{
		GuiControl, Disable, GDIWindowColor
		GuiControl, Disable, GDIWindowOpacity
		GuiControl, Disable, GDIBorderColor
		GuiControl, Disable, GDIBorderOpacity
		GuiControl, Disable, GDITextColor
		GuiControl, Disable, GDITextOpacity
		
		GuiControl, Disable, BtnGDIWindowColor
		GuiControl, Disable, BtnGDIBorderColor
		GuiControl, Disable, BtnGDITextColor		

		GuiControl, Disable, BtnGDIDefaults	
		GuiControl, Disable, BtnGDIPreviewTooltip
		GuiControl, Disable, GDIRenderingFix
		GuiControl, Disable, GDIConditionalColors
	}
	Else
	{	
		If (not IsObject(gdipTooltip.window)) {
			_tempUseGDI := Opts.UseGDI
			Opts.UseGDI := 1
			GoSub, InitGDITooltip
			Opts.UseGDI := _tempUseGDI		

			;update color and validate values and set rendering fix after initialising GDI
			gdipTooltip.SetRenderingFix(Opts.GDIRenderingFix)
			
			GuiControl,, GDIWindowColor	, % gdipTooltip.ValidateRGBColor(Opts.GDIWindowColor, Opts.GDIWindowColorDefault)
			GuiControl,, GDIWindowOpacity	, % gdipTooltip.ValidateOpacity(Opts.GDIWindowOpacity, Opts.GDIWindowOpacityDefault, "10", "10")
			GuiControl,, GDIBorderColor	, % gdipTooltip.ValidateRGBColor(Opts.GDIBorderColor, Opts.GDIBorderColorDefault)
			GuiControl,, GDIBorderOpacity	, % gdipTooltip.ValidateOpacity(Opts.GDIBorderOpacity, Opts.GDIBorderOpacityDefault, "10", "10")
			GuiControl,, GDITextColor	, % gdipTooltip.ValidateRGBColor(Opts.GDITextColor, Opts.GDITextColorDefault)
			GuiControl,, GDITextOpacity	, % gdipTooltip.ValidateOpacity(Opts.GDITextOpacity, Opts.GDITextOpacityDefault, "10", "10")
			gdipTooltip.UpdateColors(Opts.GDIWindowColor, Opts.GDIWindowOpacity, Opts.GDIBorderColor, Opts.GDIBorderOpacity, Opts.GDITextColor, Opts.GDITextOpacity, 10, 16)
		}	
		
		GuiControl, Enable, GDIWindowColor
		GuiControl, Enable, GDIWindowOpacity
		GuiControl, Enable, GDIBorderColor
		GuiControl, Enable, GDIBorderOpacity
		GuiControl, Enable, GDITextColor
		GuiControl, Enable, GDITextOpacity

		GuiControl, Enable, BtnGDIWindowColor
		GuiControl, Enable, BtnGDIBorderColor
		GuiControl, Enable, BtnGDITextColor

		GuiControl, Enable, BtnGDIDefaults	
		GuiControl, Enable, BtnGDIPreviewTooltip
		GuiControl, Enable, GDIRenderingFix
		GuiControl, Enable, GDIConditionalColors
	}
	return

SettingsUI_ChkUseTooltipTimeout:
	GuiControlGet, IsChecked,, UseTooltipTimeout
	If (Not IsChecked) {
		GuiControl, Disable, ToolTipTimeoutSeconds
	}
	Else {
		GuiControl, Enable, ToolTipTimeoutSeconds
	}
	return	

SettingsUI_ChkUseCompactDoubleRanges:
	GuiControlGet, IsChecked,, UseCompactDoubleRanges
	If (Not IsChecked) {
		GuiControl, Enable, OnlyCompactForTotalColumn
	}
	Else {
		GuiControl, Disable, OnlyCompactForTotalColumn
	}
	return

SettingsUI_ChkDisplayToolTipAtFixedCoords:
	GuiControlGet, IsChecked,, DisplayToolTipAtFixedCoords
	If (Not IsChecked)
	{
		GuiControl, Disable, LblScreenOffsetX
		GuiControl, Disable, ScreenOffsetX
		GuiControl, Disable, LblScreenOffsetY
		GuiControl, Disable, ScreenOffsetY
	}
	Else
	{
		GuiControl, Enable, LblScreenOffsetX
		GuiControl, Enable, ScreenOffsetX
		GuiControl, Enable, LblScreenOffsetY
		GuiControl, Enable, ScreenOffsetY
	}
	return

MenuTray_About:
	IfNotEqual, FirstTimeA, No
	{
		Authors := GetContributors(0)
		RelVer := Globals.get("ReleaseVersion")
		Gui, About:+owner1 -Caption +Border
		Gui, About:Color, ffffff, ffffff
		Gui, About:Font, S10 CA03410,verdana
		Gui, About:Add, Text, x260 y27 w170 h20 Center, Release %RelVer%
		Gui, About:Add, Button, 0x8000 x316 y300 w70 h21, Close
		Gui, About:Add, Picture, 0x1000 x17 y16 w230 h180, %A_ScriptDir%\resources\images\splash.png
		Gui, About:Font, Underline C3571AC,verdana
		Gui, About:Add, Text, x260 y57 w170 h20 gVisitForumsThread Center, PoE forums thread
		Gui, About:Add, Text, x260 y87 w170 h20 gAboutDlg_AhkHome Center, AutoHotkey homepage
		Gui, About:Add, Text, x260 y117 w170 h20 gAboutDlg_GitHub Center, PoE-ItemInfo GitHub
		Gui, About:Font, S7 CDefault normal, Verdana
		Gui, About:Add, Text, x16 y207 w410 h80,
		(LTrim
		Shows affix breakdowns and other useful infos for any item or item link.

		Usage: Set PoE to Windowed Fullscreen mode and hover over any item or item link. Press Ctrl+C to show a tooltip.

		(c) %A_YYYY% Hazydoc, Nipper4369 and contributors:
		)
		Gui, About:Add, Text, x16 y277 w270 h80, %Authors%

		FirstTimeA = No
	}

	height := Globals.Get("AboutWindowHeight", 340)
	width  := Globals.Get("AboutWindowWidth", 435)
	Gui, About:Show, h%height% w%width%, About..

	; Release counter animation
	tmpH = 0
	Loop, 20
	{
		tmpH += 1
		ControlMove, Static1,,,, %tmpH%, About..
		Sleep, 100
	}
	return

AboutDlg_AhkHome:
	Run, https://autohotkey.com/
	return

AboutDlg_GitHub:
	Run, https://github.com/aRTy42/POE-ItemInfo
	return

VisitForumsThread:
	Run, https://www.pathofexile.com/forum/view-thread/1678678
	return

AboutButtonClose:
AboutGuiClose:
	WinGet, AbtWndID, ID, About..
	DllCall("AnimateWindow", "Int", AbtWndID, "Int", 500, "Int", 0x00090010)
	WinActivate, ahk_id %MainWndID%
	return

EditOpenUserSettings:
    OpenUserSettingsFolder(Globals.Get("ProjectName"))
    return

EditAdditionalMacrosSettings:
	OpenUserDirFile("AdditionalMacros.ini")
	return

PreviewAdditionalMacros:
	OpenTextFileReadOnly(A_ScriptDir "\resources\ahk\AdditionalMacros.ahk")
	return

EditMapModWarningsConfig:
	OpenUserDirFile("MapModWarnings.ini")
	return

EditCustomMacrosExample:
	OpenUserDirFile("CustomMacros\customMacros_example.txt")
	return

EditCurrencyRates:
	OpenCreateDataTextFile("CurrencyRates.txt")
	return

ReloadScript:
	scriptName := RegExReplace(Globals.Get("ProjectName"), "i)poe-", "Run_") . ".ahk"
	Run, "%A_AhkPath%" "%A_ScriptDir%\%scriptName%"
	return

ShowAssignedHotkeys:
	ShowAssignedHotkeys()
	return

3GuiClose:
	Gui, 3:Cancel
	return

SettingsUIGuiEscape: 
	; settings 
	Gui, SettingsUI:Cancel
Return

AboutGuiEscape:
	Gui, About:Cancel
Return

ShowHotkeysGuiEscape:
	Gui, ShowHotkeys:Cancel
Return

TranslateGuiEscape:
	Gui, Translate:Cancel
Return

UpdateNotesGuiEscape:
	Gui, UpdateNotes:Cancel
Return

HotkeyConflictGuiEscape:
	Gui, HotkeyConflict:Cancel
Return

CloseHotkeyConflictGui:
	Gui, HotkeyConflict:Destroy
Return

CheckForUpdates:
	If (not globalUpdateInfo.repo) {
		global globalUpdateInfo := {}
	}
	If (not SkipItemInfoUpdateCall) {
		globalUpdateInfo.repo := Globals.Get("GithubRepo")
		globalUpdateInfo.user := Globals.Get("GithubUser")
		globalUpdateInfo.releaseVersion	:= Globals.Get("ReleaseVersion")
		globalUpdateInfo.skipSelection	:= Opts.UpdateSkipSelection
		globalUpdateInfo.skipBackup		:= Opts.UpdateSkipBackup
		globalUpdateInfo.skipUpdateCheck	:= Opts.ShowUpdateNotifications
		SplashScreenTitle := "PoE-ItemInfo"
	}

	hasUpdate := PoEScripts_Update(globalUpdateInfo.user, globalUpdateInfo.repo, globalUpdateInfo.releaseVersion, globalUpdateInfo.skipUpdateCheck, userDirectory, isDevVersion, globalUpdateInfo.skipSelection, globalUpdateInfo.skipBackup)
	If (hasUpdate = "no update" and not firstUpdateCheck) {
		_repo := globalUpdateInfo.repo
		_version := globalUpdateInfo.releaseVersion
		TrayTip, %_repo%, No updates available.`nVersion: %_version%
	}
	return

CurrencyDataDownloadURLtoJSON(url, sampleValue, critical = false, isFallbackRequest = false, league = "", project = "", tmpFileName = "", fallbackDir = "", ByRef usedFallback = false, ByRef loggedCurrencyRequestAtStartup = false, ByRef loggedTempLeagueCurrencyRequest = false, CurlTimeout = 35) {
	errorMsg := "Parsing the currency data (json) from poe.ninja failed.`n"
	errorMsg .= "This should only happen when the servers are down / unavailable."
	errorMsg .= "`n`n"
	errorMsg .= "This can fix itself when the servers are up again and the data gets updated automatically or if you restart the script at such a time."
	errorMsg .= "`n`n"
	errorMsg .= "You can find a log file with some debug information:"
	errorMsg .= "`n" """" A_ScriptDir "\temp\StartupLog.txt"""
	errorMsg .= "`n`nTry opening the settings menu and selecting a league/making sure that one is selected."
	errorMsg .= "`n`n"

	errors := 0
	parsingError := false	
	Try {
		options := ""
		options	.= "`n" "TimeOut: " CurlTimeout
		
		reqHeaders.push("Connection: keep-alive")
		reqHeaders.push("Cache-Control: max-age=0")
		reqHeaders.push("Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8")	
		reqHeaders.push("User-Agent: Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36")
		currencyData := PoEScripts_Download(url, postData, reqHeaders, options, true, true, false, "", reqHeadersCurl)
		
		deleteError := PoEScripts_SaveWriteTextFile(A_ScriptDir "\temp\currencyHistory_" league ".txt", currencyData, "utf-8", true, true)
		
		Try {
			parsedJSON := JSON.Load(currencyData)
		} Catch e {
			parsingError := true
		}	
		
		isTempLeague := RegExMatch(league, "^(Standard|Hardcore)")
		If (not loggedCurrencyRequestAtStartup or (not loggedTempLeagueCurrencyRequest and not isTempLeague)) {
			logMsg := "Requesting currency data from poe.ninja...`n`n" "cURL command:`n" reqHeadersCurl "`n`nAnswer: " reqHeaders
			WriteToLogFile(logMsg, "StartupLog.txt", project)
			
			loggedCurrencyRequestAtStartup := true
			If (not loggedTempLeagueCurrencyRequest and not isTempLeague) {
				loggedTempLeagueCurrencyRequest := true
			}
			If (deleteError) {
				WriteToLogFile("Failed to delete " A_ScriptDir "\temp\currencyHistory_" league ".txt before writing data to it. `n", "StartupLog.txt", project)	
			}
		}
		; first currency data parsing (script start)
		If ((critical and (not sampleValue or isFallbackRequest)) or not parsedJSON.lines.length()) {
			errors++
		}
	} Catch error {
		; first currency data parsing (script start)
		If (critical and (not sampleValue or isFallbackRequest)) {
			errors++
		}
	}

	If ((errors and critical and (not sampleValue or isFallbackRequest)) or parsingError) {
		FileRead, JSONFile, %fallbackDir%\currencyData_Fallback_%league%.json
		Try {
			parsedJSON := JSON.Load(JSONFile)
			If (isFallbackRequest) {
				errorMsg .= "This is a fallback request trying to get data for the """ league """ league since getting data for the currently selected league failed."
				errorMsg .= "`n`n"
			}
			errorMsg .= "The script is now using archived data from a fallback file instead. League: """ league """"
			errorMsg .= "`n`n"
		} Catch e {
			errorMsg .= "Using archived fallback data failed (JSON parse error)."
			errorMsg .= "`n`n"
		}
		
		MsgBox, 16, %project% - Error, %errorMsg%
		usedFallback := true
	}

	Return parsedJSON
}

PoENinjaPriceDataDownloadURLtoJSON(url, category, critical = false, isFallbackRequest = false, league = "", project = "", tmpFileName = "", fallbackDir = "", ByRef usedFallback = false, CurlTimeout = 35) {	
	errorMsg := "Parsing the " category " data (json) from poe.ninja failed.`n"
	errorMsg .= "This should only happen when the servers are down / unavailable."
	errorMsg .= "`n`n"
	errorMsg .= "This can fix itself when the servers are up again and the data gets updated automatically or if you restart the script at such a time."
	errorMsg .= "`n`n"
	errorMsg .= "You can find a log file with some debug information:"
	errorMsg .= "`n" """" A_ScriptDir "\temp\StartupLog.txt"""
	errorMsg .= "`n`nTry opening the settings menu and selecting a league/making sure that one is selected."
	errorMsg .= "`n`n"

	errors := 0
	parsingError := false	
	Try {
		options := ""
		options	.= "`n" "TimeOut: " CurlTimeout
		
		reqHeaders.push("Connection: keep-alive")
		reqHeaders.push("Cache-Control: max-age=0")
		reqHeaders.push("Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8")	
		reqHeaders.push("User-Agent: Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36")
		priceData := PoEScripts_Download(url, postData, reqHeaders, options, true, true, false, "", reqHeadersCurl)
		
		deleteError := PoEScripts_SaveWriteTextFile(A_ScriptDir "\temp\" category "History_" league ".txt", priceData, "utf-8", true, true)

		Try {
			parsedJSON := JSON.Load(priceData)
		} Catch e {
			parsingError := true
		}
	} Catch error {
		; first currency data parsing (script start)
		If (critical and (not sampleValue or isFallbackRequest)) {
			errors++
		}
	}

	Return parsedJSON
}

FetchCurrencyData:
	_CurrencyDataJSON	:= {}
	currencyLeagues	:= ["Standard", "Hardcore", "tmpstandard", "tmphardcore", "eventstandard", "eventhardcore"]
	sampleValue		:= "ff"
	loggedCurrencyRequestAtStartup := loggedCurrencyRequestAtStartup ? loggedCurrencyRequestAtStartup : false
	loggedTempLeagueCurrencyRequest := loggedTempLeagueCurrencyRequest ? loggedTempLeagueCurrencyRequest : false
	
	Loop, % currencyLeagues.Length() {
		currencyLeague := currencyLeagues[A_Index]	
		url	:= "https://poe.ninja/api/data/ItemOverview?league=" . currencyLeague . "&type=Currency"
		file := A_ScriptDir . "\temp\currencyData_" . currencyLeague . ".json"

		url	:= "https://poe.ninja/api/data/ItemOverview?league=" . currencyLeague . "&type=Currency"
		critical	:= StrLen(Globals.Get("LastCurrencyUpdate")) ? false : true
		parsedJSON := CurrencyDataDownloadURLtoJSON(url, sampleValue, critical, false, currencyLeague, "PoE-ItemInfo", file, A_ScriptDir "\data", usedFallback, loggedCurrencyRequestAtStartup, loggedTempLeagueCurrencyRequest)		

		Try {
			If (parsedJSON) {		
				_CurrencyDataJSON[currencyLeague] := parsedJSON.lines
				If (not usedFallback) {
					ParsedAtLeastOneLeague := True	
				}		
			}
			Else	{
				_CurrencyDataJSON[currencyLeague] := null
			}
		} Catch error {
			errorMsg := "Parsing the currency data (json) from poe.ninja failed for league:"
			errorMsg .= "`n" currencyLeague
			;MsgBox, 16, PoE-ItemInfo - Error, %errorMsg%
		}		
		parsedJSON :=
	}
	
	If (ParsedAtLeastOneLeague) {
		Globals.Set("LastCurrencyUpdate", A_NowUTC)
	}

	; parse JSON and write files to disk (like \data\CurrencyRates.txt)
	_CurrencyDataRates := {}
	For league, data in _CurrencyDataJSON {
		_CurrencyDataRates[league] := {}

		For currency, cData in data {
			cName       := cData.currencyTypeName
			cChaosEquiv := cData.chaosEquivalent

			If (cChaosEquiv >= 1) {
				cChaosQuantity := ZeroTrim(Round(cChaosEquiv, 2))
				cOwnQuantity   := 1
			}
			Else {
				cChaosQuantity := 1
				cOwnQuantity   := ZeroTrim(Round(1 / cChaosEquiv, 2))
			}	
			
			_CurrencyDataRates[league][cName] := {}
			_CurrencyDataRates[league][cName].ChaosEquiv := cChaosEquiv
			_CurrencyDataRates[league][cName].ChaosQuantity := cChaosQuantity
			_CurrencyDataRates[league][cName].OwnQuantity := cOwnQuantity
		}
	}
	
	Globals.Set("CurrencyDataRates", _CurrencyDataRates)
	_CurrencyDataJSON :=
	return

ZeroTrim(number) {
	; Trim trailing zeros from numbers

	RegExMatch(number, "(\d+)\.?(.+)?", match)
	If (StrLen(match2) < 1) {
		Return number
	} Else {
		trail := RegExReplace(match2, "0+$", "")
		number := (StrLen(trail) > 0) ? match1 "." trail : match1
		Return number
	}
}

IsInArray(el, array) {
	For i, element in array {
		If (el = "") {
			Return false
		}
		If (element = el) {
			Return true
		}
	}
	Return false
}

GetObjPropertyCount(obj) {
	Return NumGet(&obj + 4*A_PtrSize)
}

TogglePOEItemScript()
{
	IF SuspendPOEItemScript = 0
	{
		SuspendPOEItemScript = 1
		ShowToolTip("Item parsing PAUSED")
	}
	Else
	{
		SuspendPOEItemScript = 0
		ShowToolTip("Item parsing ENABLED")
	}
}

GetScanCodes() {
	f := A_FormatInteger
	SetFormat, Integer, H
	WinGet, WinID,, A
	ThreadID:=DllCall("GetWindowThreadProcessId", "UInt", WinID, "UInt", 0)
	InputLocaleID:=DllCall("GetKeyboardLayout", "UInt", ThreadID, "UInt")	
	SetFormat, Integer, %f%

	; example results: 0xF0020809/0xF01B0809/0xF01A0809
	; 0809 is for "English United Kingdom"
	; 0xF002 = "Dvorak"
	; 0xF01B = "Dvorak right handed"
	; 0xF01A = "Dvorak left handed"
	; 0xF01C0809 = some other Dvorak layout
	
	If (RegExMatch(InputLocaleID, "i)^(0xF002|0xF01B|0xF01A|0xF01C0809|0xF01C0409).*")) {
		; dvorak
		sc := {"c" : "sc017", "v" : "sc034", "f" : "sc015", "a" : "sc01E", "enter" : "sc01C"}
		project := Globals.Set("ProjectName")
		msg := "Using Dvorak keyboard layout mode!`n`nMsgBox closes after 15s."
		MsgBox, 0, %project%, %msg%, 15
		Return sc
	} Else If (RegExMatch(InputLocaleID, "i)^(0xF0C00407).*")) {
		; german dvorak (neo)
		sc := {"c" : "sc013", "v" : "sc011", "f" : "sc018", "a" : "sc020", "enter" : "sc01C"}
		project := Globals.Set("ProjectName")
		msg := "Using German Dvorak (neo) keyboard layout mode!`n`nMsgBox closes after 15s."
		MsgBox, 0, %project%, %msg%, 15
		Return sc
	} Else {
		; default
		sc := {"c" : "sc02E", "v" : "sc02f", "f" : "sc021", "a" : "sc01E", "enter" : "sc01C"}
		Return sc
	}	
}

GetCurrentItemFilterPath(ByRef parsingNeeded = true) {
	currentFilter	:= Globals.Get("CurrentItemFilter")
	iniPath		:= A_MyDocuments . "\My Games\Path of Exile\"
	configs 		:= []
	productionIni	:= iniPath . "production_Config.ini"
	betaIni		:= iniPath . "beta_Config.ini"	

	configs.push(productionIni)
	configs.push(betaIni)
	If (not FileExist(productionIni) and not FileExist(betaIni)) {
		Loop %iniPath%\*.ini
		{
			configs.push(iniPath . A_LoopFileName)		
		}	
	}

	readFile		:= ""
	For key, val in configs {
		IniRead, filter, %val%, UI, item_filter_loaded_successfully
		If (filter != "ERROR" and FileExist(iniPath . filter)) {
			Break
		}
	}
	
	filter := iniPath . filter

	If (currentFilter != filter) {
		parsingNeeded := true
		Globals.Set("CurrentItemFilter", filter)
		Return filter
	} Else {
		parsingNeeded := false
		Return currentFilter
	}
}

ShowAdvancedItemFilterFormatting() {
	Global Item

	SuspendPOEItemScript = 1 ; This allows us to handle the clipboard change event

	scancode_c := Globals.Get("Scancodes").c
	Send ^{%scancode_c%}
	Sleep 150
	CBContents := GetClipboardContents()
	CBContents := PreProcessContents(CBContents)
	Globals.Set("ItemText", CBContents)
	ParsedData := ParseItemData(CBContents)
	ShowItemFilterFormatting(Item, true)
	
	SuspendPOEItemScript = 0 ; Allow ItemInfo to handle clipboard change event	
}

ShowItemFilterFormatting(Item, advanced = false) {
	If (not Item.Name) {
		Return
	}
	
	parsingNeeded := true
	filterFile := GetCurrentItemFilterPath(parsingNeeded)
	If (RegExMatch(filterFile, "i).*\\(error)$")) {
		If (advanced) {
			ShowToolTip("No custom loot filter loaded successfully.`nMake sure you have one selected in your UI options.")
		}
		Return
	}
	
	ItemBaseList := Globals.Get("ItemBaseList")
	
	search := {}
	search.LinkedSockets := Item.Links
	search.ShaperItem := Item.IsShaperBase
	search.ElderItem := Item.IsElderBase
	
	search.CrusaderItem := Item.IsCrusaderBase
	search.HunterItem := Item.IsHunterBase
	search.WarlordItem := Item.IsWarlordBase
	search.RedeemerItem := Item.IsRedeemerBase
	
	search.FracturedItem := Item.IsFracturedBase
	search.SynthesisedItem := Item.IsSynthesisedBase
	search.ItemLevel := Item.Level
	search.BaseType := [Item.BaseName]
	search.HasExplicitMod :=					; HasExplicitMod "of Crafting" "of Spellcraft" "of Weaponcraft"
	search.Identified := Item.IsUnidentified ? 0 : 1
	search.Corrupted := Item.IsCorrupted
	search.Quality := Item.Quality
	search.Sockets := Item.Sockets	
	search.Width :=
	search.Height :=
	search.name := Item.Name

	; rarity
	If (Item.RarityLevel = 1) {
		search.Rarity := "Normal"
		search.RarityLevel := 1
	} Else If (Item.RarityLevel = 2) {
		search.Rarity := "Magic"
		search.RarityLevel := 2
	} Else If (Item.RarityLevel = 3) {
		search.Rarity := "Rare"
		search.RarityLevel := 3
	} Else If (Item.RarityLevel = 4) {
		search.Rarity := "Unique"
		search.RarityLevel := 4
	}
	
	; classes
	class := (StrLen(Item.SubType)) ? Item.SubType : Item.BaseType
	search.Class := []
	If (RegExMatch(class, "i)BodyArmour")) {
		search.Class.push("Body Armour")
		search.Class.push("Body Armours")
	}
	If (RegExMatch(class, "i)Sword|Mace|Axe")) {
		If (Item.GripType = "2H") {
			search.Class.push(class)
			search.Class.push("Two Hand " class)
			search.Class.push("Two Hand " class "s")
			search.Class.push("Two Hand")
		} Else {
			search.Class.push(class)
			search.Class.push("One Hand " class)
			search.Class.push("One Hand " class "s")
			search.Class.push("One Hand")
		}
	}
	If (RegExMatch(class, "i)Flask")) {
		If (RegExMatch(Item.BaseName, "i) (Life|Mana) ", match)) {
			search.Class.push(match1 " Flasks") 
			search.Class.push(match1 " Flask") 
			search.Class.push("Flask") 
		} Else {			
			search.Class.push("Utility Flasks") 
			search.Class.push("Utility Flask") 
			search.Class.push("Flask") 
		}
	}
	If (RegExMatch(class, "i)Jewel")) {
		class := "Jewel"
		search.Class.push(class)
		search.Class.push(class "s")
		
		If (RegExMatch(Item.SubType, "i)Murderous Eye|Hypnotic Eye|Searching Eye")) {
			class := "Abyss Jewel"
			search.Class.push(class)
			search.Class.push(class "s")
		}
	}
	If (RegExMatch(class, "i)Currency") and RegExMatch(Item.BaseName, "i)Resonator")) {
		search.Class.push("Delve Socketable Currency")		
		search.Class.push("Currency")		
	}	
	; Quest Items
	If (RegExMatch(Item.BaseName, "i)(Elder's Orb|Shaper's Orb)", match)) {
		search.Class.push("Quest")
		Item.IsQuestItem := true
	}

	If (not search.Class.MaxIndex() and StrLen(class)) {		
		search.Class.push(class)
		search.Class.push(class "s")
	}
	
	For key, val in ItemBaseList {
		For k, v in val {
			If (k = Item.BaseName) {
				search.DropLevel := v["Drop Level"]
				search.Width := v["Width"]
				search.Height := v["Height"]
				Break
			}
		}
	}
	If (Item.IsMap) {
		search.DropLevel := Item.MapTier + 67
	}

	; SocketGroups, RGB for example
	search.SocketGroup := []
	For key, val in Item.SocketGroups {
		sGroup := {}
		_r := RegExReplace(val, "i)r" , "", rCount)
		_g := RegExReplace(val, "i)g" , "", gCount)
		_b := RegExReplace(val, "i)b" , "", bCount)
		_w := RegExReplace(val, "i)w" , "", wCount)
		_w := RegExReplace(val, "i)d" , "", dCount)
		_w := RegExReplace(val, "i)a" , "", aCount)
		sGroup.r := rCount
		sGroup.g := gCount
		sGroup.b := bCount
		sGroup.w := wCount
		sGroup.d := dCount
		sGroup.a := aCount
		If (sGroup.r or sGroup.b or sGroup.g or sGroup.w or sGroup.d or sGroup.a) {
			search.SocketGroup.push(sGroup)	
		}		
	}	
	
	search.HasExplicitMod := []
	; works only for magic items
	If (Item.RarityLevel = 2) {
		RegExMatch(Item.Name, "i)(.*)?" Item.BaseName "(.*)?", nameParts)
		If (StrLen(nameParts1)) {
			search.HasExplicitMod.push(Trim(nameParts1))
		}
		If (StrLen(nameParts2)) {
			search.HasExplicitMod.push(Trim(nameParts2))
		}
	}
	
	search.SetBackGroundColor	:= GetItemDefaultColor(Item, "BackGround")
	search.SetBorderColor		:= GetItemDefaultColor(Item, "Border")
	search.SetTextColor			:= GetItemDefaultColor(Item, "Text")
	
	search.LabelLines := []
	_line := (Item.Quality > 0) ? "Superior " RegExReplace(Item.Name, "i)Superior (.*)", "$1") : Item.Name
	_line := (not Item.IsGem and not Item.IsUnidentified and not Item.RarityLevel = 1) ? RegExReplace(Item.Name, "i)Superior (.*)", "$1") : _line
	_line .= (Item.IsGem and Item.Level > 1) ? " (Level " Item.Level ")" : "" 
	search.LabelLines.push(_line)
	
	; Unidentified rare/unique items have the same baseName as their name
	If (Item.RarityLevel >= 3 and (RegExReplace(Item.Name, "i)Superior (.*)", "$1") != Item.BaseName)) {
		_line := Item.BaseName
		search.LabelLines.push(_line)
	}	

	ParseItemLootFilter(filterFile, search, parsingNeeded, advanced) 
}

GetItemDefaultColor(item, cType) {
	If (cType = "Border") {
		; labyrinth map item or map fragment
		If (item.IsMapFragment) {
			return "200 200 200 1" ; // white
		}

		; Quest Item / labyrinth item
		If (item.IsQuestItem or item.IsLabyrinthItem) { ; these variables don't exist yet
			return "74 230 58 1" ; // green
		}

		; map rarity
		Else If (item.IsMap) {
			If (item.RarityLevel = 1) {
				return "200 200 200 1"
			} Else If (item.RarityLevel = 2) {
				return "136 136 255 1"
			} Else If (item.RarityLevel = 3) {
				return "255 255 119 1"
			} Else If (item.RarityLevel = 4) {
				return " 175 96 37 1"
			} Else {
				return "255 255 255 0"
			}
		}
		
		; default border color: none
		Else  {
			return s:= "0 0 0 0"
		}
	}
	
	; background is always black
	Else If (cType = "BackGround") {		
		return  "0 0 0 255"
	}
	
	Else If (cType = "Text") {
		; create text color based gem class
		If (item.IsGem)
		{
			return "27 162 155 1"
		}

		; create text color based on currency class
		Else If (item.IsCurrency)
		{
			return "170 158 130 1"
		}

		; create text color based on map fragments classes
		Else If (RegExMatch(item.Name, "i)Offering of the Goddess") or item.IsMap)
		{
			return "200 200 200 1"
		}

		; quest / lab item
		Else If (item.IsQuestItem or item.IsLabyrinthItem) ; IsLabyrinthItem doesn't exist yet
		{
			return "74 230 58 1"
		}

		; div card
		Else If (item.IsDivinationCard)
		{
			return "14 186 255 1"
		}
		
		; create text color based on rarity
		Else If (item.RarityLevel)
		{
			If (item.RarityLevel = 1) {
				return "200 200 200 1"
			} Else If (item.RarityLevel = 2) {
				return "136 136 255 1"
			} Else If (item.RarityLevel = 3) {
				return "255 255 119 1"
			} Else If (item.RarityLevel = 4) {
				return " 175 96 37 1"
			} Else {
				return "255 255 255 0"
			}
		}

		; creating default text color (white)
		Else {
			return "255 255 255 1"
		}
	}
	
	Return
}

ParseItemLootFilter(filter, item, parsingNeeded, advanced = false) {
	; https://pathofexile.gamepedia.com/Item_filter
	rules := []
	matchedRule := {}
	
	; Use already parsed filter data if the item filter is still the same
	If (not parsingNeeded) {
		rules := Globals.Get("ItemFilterObj")
	}
	; Parse the item filter if it wasn't used the last time or fall back to parsing it if using the already parsed data fails
	If (parsingNeeded or rules.MaxIndex() > 1) {
		/*
			Parse filter rules to object
		*/
		Loop, Read, %filter%
		{
			If (RegExMatch(A_LoopReadLine, "i)^#") or not StrLen(A_LoopReadLine)) {
				continue
			}
			
			If (RegExMatch(Trim(A_LoopReadLine), "i)^(Show|Hide)(\s|#)?", match)) {
				rule := {}
				rule.Display := match1
				rule.Conditions := []
				rule.Comments := []
				If (RegExMatch(Trim(A_LoopReadLine), "i)#(.*)?", comment)) { ; only comments after filter code
					If (StrLen(comment1)) {
						rule.Comments.push(comment1)	
					}				
				}
				rules.push(rule)
			} Else  {
				RegExMatch(Trim(A_LoopReadLine), "i)#(.*)?", comment) ; only comments after filter code
				If (StrLen(comment1)) {
					rules[rules.MaxIndex()].Comments.push(comment1)
				}			
				
				line := RegExReplace(Trim(A_LoopReadLine), "i)#.*")
				
				/*
					Styles (last line is valid)
				*/
				If (RegExMatch(line, "i)^.*?Color\s")) {
					RegExMatch(line, "i)(.*?)\s(.*)", match)
					rules[rules.MaxIndex()][Trim(match1)] := Trim(match2)
				}
				
				Else If (RegExMatch(line, "i)^.*?(PlayAlertSound|MinimapIcon|PlayEffect)\s")) {
					RegExMatch(line, "i)(.*?)\s(.*)", match)
					params := StrSplit(Trim(match2), " ")
					rules[rules.MaxIndex()][Trim(match1)] := params
				}
				
				/*
					Conditions (every condition must match, lines don't overwrite each other)
				*/
				Else If (RegExMatch(line, "i)^.*?(Class|BaseType|HasExplicitMod|SocketGroup)\s")) {
					RegExMatch(line, "i)(.*?)\s(.*)", match)
					
					;temp := RegExReplace(match2, "i)(""\s+"")", """,""")
					temp := RegExReplace(match2, "i)(\s)\s+", "\s")
					temp := RegExReplace(temp, "i)(\s+)|""(.*?)""", "$1,$2")
					temp := RegExReplace(temp, "i)(,,+)", ",")
					temp := RegExReplace(temp, "i)(\s,)", ",")
					temp := RegExReplace(temp, "i)(^,)|(, $)")
					
					arr := StrSplit(temp, ",")
					
					condition := {}
					condition.name := match1
					condition.values := arr
					rules[rules.MaxIndex()].conditions.push(condition)
				}
				
				Else If (RegExMatch(line, "i)^.*?(DropLevel|ItemLevel|Rarity|LinkedSockets|Sockets|Quality|Height|Width|StackSize|GemLevel|MapTier)\s")) {
					RegExMatch(line, "i)(.*?)\s(.*)", match)
					paramsTemp := StrSplit(Trim(match2), " ")
					
					condition := {}
					condition.name := match1
					condition.operator := ParamsTemp.MaxIndex() = 2 ? paramsTemp[1] : "=" 
					condition.value := ParamsTemp.MaxIndex() = 2 ? paramsTemp[2] : paramsTemp[1]
					
					; rarity
					If (condition.value = "Normal") {
						condition.value := 1
					} Else If (condition.value = "Magic") {
						condition.value := 2
					} Else If (condition.value = "Rare") {
						condition.value := 3
					} Else If (condition.value = "Unique") {
						condition.value := 4
					}
					
					rules[rules.MaxIndex()].conditions.push(condition)
				}
				
				Else If (RegExMatch(line, "i)^.*?(Identified|Corrupted|ElderItem|SynthesisedItem|FracturedItem|ShaperItem|ShapedMap|ElderMap|BlightedMap|CrusaderItem|HunterItem|WarlordItem|RedeemerItem)\s")) {
					RegExMatch(line, "i)(.*?)\s(.*)", match)	
					
					condition := {}
					condition.name := Trim(match1)
					condition.value := Trim(match2) = "True" ? true : false			
					rules[rules.MaxIndex()].conditions.push(condition)
				}		
				
				/*
					the rest
				*/			
				Else {
					RegExMatch(line, "i)(.*?)\s(.*)", match)			
					rules[rules.MaxIndex()][Trim(match1)] := Trim(match2)
				}
			}
		}
		Globals.Set("ItemFilterObj", rules)
	}
	
	json := JSON.Dump(rules)
	FileDelete, %A_ScriptDir%\temp\itemFilterParsed.json
	FileAppend, %json%, %A_ScriptDir%\temp\itemFilterParsed.json
	
	/*
		Match item againt rules
	*/
	match := ""
	match1 := ""
	match2 := ""
	For k, rule in rules {
		totalConditions := rule.conditions.MaxIndex()
		matchingConditions := 0		
		matching_rules := []
		
		For i, condition in rule.conditions {
			
			If (RegExMatch(condition.name, "i)(LinkedSockets|DropLevel|ItemLevel|Rarity|Sockets|Quality|Height|Width|StackSize|GemLevel|MapTier)", match1)) {
				If (match1 = "Rarity") {
					If (CompareNumValues(item["RarityLevel"], condition.value, condition.operator)) {
						matchingConditions++
						matching_rules.push(condition.name)
					}
				} Else {
					If (CompareNumValues(item[match1], condition.value, condition.operator)) {
						matchingConditions++
						matching_rules.push(condition.name)
					}
				}
			}
			Else If (RegExMatch(condition.name, "i)(Identified|Corrupted|ElderItem|SynthesisedItem|FracturedItem|ShaperItem|ShapedMap|BlightedMap|ElderMap|CrusaderItem|HunterItem|WarlordItem|RedeemerItem)", match1)) {
				If (item[match1] == condition.value) {
					matchingConditions++
					matching_rules.push(condition.name)
				}
			}
			Else If (RegExMatch(condition.name, "i)(Class|BaseType|HasExplicitMod)", match1)) {
				For j, value in condition.values {
					foundMatch := 0
					
					For l, v in item[match1] {
						If (RegExMatch(v, "i)" value "")) {
							matchingConditions++
							matching_rules.push(condition.name)
							foundMatch := 1
							Break
						}
					}
					If (foundMatch) {
						Break
					}
				}
			}
			Else If (RegExMatch(condition.name, "i)(SocketGroup)", match1)) {
				For j, value in condition.values {
					foundMatch := 0
					
					For l, v in item[match1] {
						_r := RegExReplace(value, "i)r" , "", rCount)
						_g := RegExReplace(value, "i)g" , "", gCount)
						_b := RegExReplace(value, "i)b" , "", bCount)
						_w := RegExReplace(value, "i)w" , "", wCount)
						_w := RegExReplace(value, "i)d" , "", dCount)
						_w := RegExReplace(value, "i)a" , "", aCount)
						
						If (v.r = rCount and v.g = gCount and v.b = bCount and v.w = wCount and v.d = dCount and v.a = aCount) {
							matchingConditions++
							matching_rules.push(condition.name)
							foundMatch := 1
							Break
						}
					}
					If (foundMatch) {
						Break
					}
				}
			}
		}
		
		If (totalConditions = matchingConditions) {
			matchedRule := rule
			matchedRule["matching_rules"] := matching_rules
			Break
		}
	}
	;debugprintarray([matchedRule, item])
	
	If (not StrLen(matchedRule.SetBackgroundColor)) {
		matchedRule.SetBackgroundColor := item.SetBackgroundColor
	}
	If (not StrLen(matchedRule.SetBorderColor)) {
		matchedRule.SetBorderColor := item.SetBorderColor
	}
	If (not StrLen(matchedRule.SetTextColor)) {
		matchedRule.SetTextColor := item.SetTextColor
	}
	If (not StrLen(matchedRule.SetFontSize)) {
		matchedRule.SetFontSize := 32
	}

	itemName		:= item.LabelLines[1]
	itemBase		:= item.LabelLines[2]
	bgColor		:= matchedRule.SetBackgroundColor
	borderColor	:= matchedRule.SetBorderColor
	fontColor 	:= matchedRule.SetTextColor
	fontSize		:= matchedRule.SetFontSize
	
	If (advanced) {	
		filterName := RegExReplace(Globals.Get("CurrentItemFilter"), "i).*\\(.*)(\.filter)","$1")
		commentsJSON := DebugPrintArray(matchedRule, false)
		
		comments := ""
		For key, val in matchedRule.Comments {
			comments .= val "`n"
		}
		
		conditions := ""
		rarities := ["Normal", "Magic", "Rare", "Unique"]
		For key, val in matchedRule.Conditions {
			If (val.operator) {
				cLine := val.name
				If (val.name = "Rarity") {				
					cLine .= " " val.operator " " rarities[val.value]
				} Else {
					cLine .= " " val.operator " " val.value	
				}				
			}
			Else {
				cLine := val.name ": "
				indent := StrLen(cLine)
				count := 0
				For k, v in val.values {
					cLine .= """" v """"
					
					count++
					If (count = 5) {
						cLine .= "`n" StrPad("", indent)
						count := 0
					} Else {
						cLine .= ", "
					}
				}
			}
			
			conditions .= cLine "`n" 
		}
		conditions := RegExReplace(Trim(conditions), "i),(\n|\r|\s)+?$")

		line := "--------------------------------------------"
		tt := "Loaded Item Filter: """ filterName """`n`n"
		tt .= "Inline comments:" "`n" line "`n" 
		tt .= comments "`n"
		tt .= "Matching conditions:" "`n" line "`n" 
		tt .= conditions "`n`n"
		tt .= "  Disclaimer: Matching explicit mods is only possible for magic items. In rare" "`n"
		tt .= "              cases this can cause a wrong match, depending on the used filter."
		
		ShowToolTip(tt)	
	}
	
	MouseGetPos, CurrX, CurrY
	If (advanced) {
		Run "%A_AhkPath%" "%A_ScriptDir%\lib\PoEScripts_ItemFilterNamePlate.ahk" "%itemName%" "%itemBase%" "%bgColor%"  "%borderColor%"  "%fontColor%"  "%fontSize%" "%CurrX%" "%CurrY%" "1"	
	} Else {
		Run "%A_AhkPath%" "%A_ScriptDir%\lib\PoEScripts_ItemFilterNamePlate.ahk" "%itemName%" "%itemBase%" "%bgColor%"  "%borderColor%"  "%fontColor%"  "%fontSize%" "%CurrX%" "%CurrY%" 
	}
	
}

CompareNumValues(num1, num2, operator = "=") {
	res := 0
	If (operator = "=") {
		res := num1 = num2
	} Else If (operator = "==") {
		res := num1 == num2
	} Else If (operator = ">=") {
		res := num1 >= num2
	} Else If (operator = ">") {
		res := num1 > num2
	} Else If (operator = "<=") {
		res := num1 <= num2
	} Else If (operator = "<") {
		res := num1 < num2
	}
	Return res
}

StartLutbot:
	global LutBotSettings	:= class_EasyIni(A_MyDocuments "\AutoHotKey\LutTools\settings.ini")

	If (not FileExist(A_MyDocuments "\AutoHotKey\LutTools\lite.ahk")) {
		_project := Globals.Get("ProjectName")
		MsgBox, 0x14, %_project% - Lutbot lite.ahk missing, The Lutbot lite macro cannot be executed since its script file is missing,`nopen download website? ("http://lutbot.com/#/ahk")
		IfMsgBox Yes
		{
			OpenWebPageWith(AssociatedProgram("html"), "http://lutbot.com/#/ahk")
		}
	} Else {		
		Run "%A_AhkPath%" "%A_MyDocuments%\AutoHotKey\LutTools\lite.ahk"
	}

	If (Opts.Lutbot_WarnConflicts) {
		CheckForLutBotHotkeyConflicts(ShowAssignedHotkeys(true), LutBotSettings)
	}

	SetTimer, StartLutbot, Off
Return

OpenLutbotDocumentsFolder:
	;OpenUserSettingsFolder("Lutbot", A_MyDocuments "\AutoHotKey\LutTools")
	OpenUserSettingsFolder("Lutbot", LutBotSettings.variables.launcherPath)
Return

CheckForLutBotHotkeyConflicts(hotkeys, config) {
	conflicts := []
	
	For key, val in config.hotkeys {
		If (RegExMatch(key, "i)superLogout|logout|options")) {
			conflict := {}
			VKey := KeyNameToKeyCode(val, 0)
			assignedLabel := GetAssignedHotkeysLabel(key, val, vkey, "on")
			
			s1 := RegExReplace(val, "([-+^*$?\|&()])", "\$1")
			foundConflict := false
			For k, v in hotkeys {				
				s2 := RegExReplace(v[6], "([-+^*$?\|&()])", "\$1")
				If (RegExmatch(Trim(val), "i)^" Trim(s2) "$")) {
					foundConflict := true
					Break					
				}
			}
			
			If (StrLen(assignedLabel) or foundConflict) {
				conflict.name := key 
				conflict.hkey := val
				conflict.vkey := vkey
				conflict.assignedLabel := assignedLabel				
				conflicts.push(conflict)
			}
		}
	}
	
	If (conflicts.MaxIndex()) {
		project := Globals.Get("ProjectName")		
		msg := project " detected a hotkey conflict with the Lutbot lite macro, "
		msg .= "`n" "which should be resolved before playing the game."
		msg .= "`n`n" "Conflicting hotkey(s) from Lutbot:"
		For key, val in conflicts {
			msg .= "`n"   "- Lutbots """ val.name """ (" val.hkey ") conflicts with """ val.assignedLabel """"
		}
		
		MsgBox, 16, Lutbot lite - %project% conflict, %msg%
	}
}

ConvertGameIniAsciiKeysToVK(value) {
	values := StrSplit(value, " ")	; split string on spaces, which signals the combination of multiple keys
	vkey := ""
	
	Loop, % values.MaxIndex() {
		If (values[A_Index] < 32) {
			If (values.MaxIndex() <= 1) {				
				RegExMatch(values[A_Index], "i)(16|17|18)", match)	; 16 = shift (+), 17 = ctrl (^),  18 = alt (!)
				If (match1 = "16") {
					vkey := "+" vkey
				} Else If (match1 = "17") {
					vkey := "^" vkey
				} Else If (match1 = "18") {
					vkey := "!" vkey
				}
			}			
			Else {				
				RegExMatch(values[A_Index], "i)(1|2|3)", match)	; for some reason shift, ctrl and alt have different values when in combination with other keys
				If (match1 = "1") {
					vkey := "+" vkey
				} Else If (match1 = "2") {
					vkey := "^" vkey
				} Else If (match1 = "3") {
					vkey := "!" vkey
				}
			}
		}		
		Else {
			vkey .= StrReplace(FHex(values[A_Index]), "0x", "VK")
		}
	}
	
	Return vkey
}

FHex( int, pad=0 ) { 
	; Function by [VxE]. Formats an integer (decimals are truncated) as hex.
	; "Pad" may be the minimum number of digits that should appear on the right of the "0x".
	Static hx := "0123456789ABCDEF"

	If !( 0 < int |= 0 )
		Return !int ? "0x0" : "-" FHex( -int, pad )

	s := 1 + Floor( Ln( int ) / Ln( 16 ) )
	h := SubStr( "0x0000000000000000", 1, pad := pad < s ? s + 2 : pad < 16 ? pad + 2 : 18 )
	u := A_IsUnicode = 1

	Loop % s
		NumPut( *( &hx + ( ( int & 15 ) << u ) ), h, pad - A_Index << u, "UChar" ), int >>= 4

	Return h
}

CheckForGameHotkeyConflicts() {
	iniPath		:= A_MyDocuments . "\My Games\Path of Exile\"
	configs 		:= []
	productionIni	:= iniPath . "production_Config.ini"
	betaIni		:= iniPath . "beta_Config.ini"	
	
	configs.push(productionIni)
	configs.push(betaIni)
	If (not FileExist(productionIni) and not FileExist(betaIni)) {
		Loop %iniPath%\*.ini
		{
			configs.push(iniPath . A_LoopFileName) 
		}	
	}

	conflicts := []
	For config in configs {
		current_config := class_EasyIni(configs[config])
		convertedKeys := []
		
		For iniKey, iniValue in current_config["ACTION_KEYS"] {
			convertedKey := { "label" : iniKey, "value" : ConvertGameIniAsciiKeysToVK(iniValue)}
			convertedKeys.push(convertedKey)
		}

		assignedKeyList := ShowAssignedHotkeys(true)

		For aKey, assignedKey in assignedKeyList {
			For cKey, convertedKey in convertedKeys {
				If (assignedKey[5] = convertedKey.value) {
					obj := {"vk":assignedKey[5], "name": assignedKey[6], "game_label": convertedKey.label, "pretty_name": assignedKey[7]}
					conflicts.push(obj)
				}
			}
		} 
	}
	
	If (conflicts.MaxIndex()) {
		project := Globals.Get("ProjectName")
		
		Gui, ShowGameHotkeyConflicts:Color, ffffff, ffffff
		msg := project " detected a hotkey conflict with the Path of Exile keybindings, "
		msg .= "which should be resolved before playing the game. "
		msg .= "Otherwise " project " may block some of the games functions."
		Gui, ShowGameHotkeyConflicts:Add, Text, w600, % msg
		
		Gui, ShowGameHotkeyConflicts:Default
		Gui, ShowGameHotkeyConflicts:Font, , Courier New		
		Gui, ShowGameHotkeyConflicts:Font, , Consolas
		
		Gui, ShowGameHotkeyConflicts:Font, bold
		Gui, ShowGameHotkeyConflicts:Add, Text, x20  y55 h20 w200, Game function name
		Gui, ShowGameHotkeyConflicts:Add, Text, x+20 yp+0 h20 w150, Key combination (Code)
		Gui, ShowGameHotkeyConflicts:Add, Text, x+20 yp+0 h20 w200, Key combination (ENG name)
		Gui, ShowGameHotkeyConflicts:Add, Text, x+20 yp+0 h20 w250, Key combination (pretty name)
		Gui, ShowGameHotkeyConflicts:Font, norm
		
		_height := 35
		For key, val in conflicts {
			_height := _height + 25
			Gui, ShowGameHotkeyConflicts:Add, Text, x20  y+2 h20 w200, % val.game_label
			Gui, ShowGameHotkeyConflicts:Add, Text, x+20 yp+0 h20 w150, % val.vk
			Gui, ShowGameHotkeyConflicts:Add, Text, x+20 yp+0 h20 w200, % val.name
			Gui, ShowGameHotkeyConflicts:Add, Text, x+20 yp+0 h20 w250, % val.pretty_name
		}
		Gui, ShowGameHotkeyConflicts:Add, GroupBox, w850 h%_height% y40 x10, Conflicts
	
		text := " ^ : ctrl key modifier" . "`n"
		text .= " ! : alt key modifier" . "`n"
		text .= " + : shift key modifier" . "`n"
		text .= "`n" . "VK : Virtual Key Code"
		Gui, ShowGameHotkeyConflicts:Add, Text, x10 y+15, % text
		Gui, ShowGameHotkeyConflicts:Add, Button, x770 y+-25 h25 w90 gShowSettingsUI, Open Settings
		Gui, ShowGameHotkeyConflicts:Show, w870 xCenter yCenter, Path of Exile - %project% keybinding conflicts		
		Gui, SettingsUI:Default
		Gui, Font
	}
}

SaveAssignedHotkey(label, key, vkey, state) {
	hk := {}
	hk.key := key
	hk.vkey := vkey
	hk.state := state
	
	obj := Globals.Get("AssignedHotkeys")
	obj[label] := hk 
	Globals.Set("AssignedHotkeys", obj)
}

RemoveAssignedHotkey(label) {	
	haystack := Globals.Get("AssignedHotkeys")
	
	For k, v in haystack {
		If (k = label) {
			v.vkey := ""
			v.key := ""
			Globals.Set("AssignedHotkeys", haystack)
			Return
		}
	}
}

GetAssignedHotkeysLabel(label, key, vkey, ByRef state) {
	haystack := Globals.Get("AssignedHotkeys")
	
	For k, v in haystack {
		If (v.vkey = vkey) {
			state := v.state
			Return k
		}
	}
}

GetAssignedHotkeysEnglishKey(vkey) {
	haystack := ShowAssignedHotkeys(true)

	For k, v in haystack {
		If (v[5] = vkey) {
			Return haystack[k]
		}
	}
}

AssignHotKey(Label, key, vkey, enabledState = "on") {
	assignedState := ""
	assignedLabel := GetAssignedHotkeysLabel(Label, key, vkey, assignedState)

	If (assignedLabel = Label and enabledState = assignedState) {
		; new hotkey is already assigned to the target label

		Return
	} Else If (assignedLabel = Label and enabledState != assignedState) {
		; new hotkey is already assigned but has a different state (enabled/disabled)
		Hotkey, %VKey%, %Label%, UseErrorLevel %enabledState%
		SaveAssignedHotkey(Label, key, vkey, enabledState)
	} Else If (StrLen(assignedLabel)) {
		; new hotkey is already assigned to a different label
		; the old label will be unassigned unless prevented
		Hotkey, %VKey%, %Label%, UseErrorLevel %stateValue%
		If (not ErrorLevel) {
			SaveAssignedHotkey(Label, key, vkey, enabledState)
			RemoveAssignedHotkey(assignedLabel)
			ShowHotKeyConflictUI(GetAssignedHotkeysEnglishKey(VKey), VKey, Label, assignedLabel, false)
		}
	} Else {
		; new hotkey is not assigned to any label yet
		If (enabledState != "off") {
			; only assign it when it's enabled
			Hotkey, %VKey%, %Label%, UseErrorLevel %stateValue%
			SaveAssignedHotkey(Label, key, vkey, enabledState)
		}
	}

	If (ErrorLevel) {
		If (errorlevel = 1)
			str := str . "`nASCII " . VKey . " - 1) The Label parameter (" Label ") specifies a nonexistent label name."
		Else If (errorlevel = 2)
			str := str . "`nASCII " . VKey . " - 2) The KeyName parameter specifies one or more keys that are either not recognized or not supported by the current keyboard layout/language. Switching to the english layout should solve this for now."
		Else If (errorlevel = 3)
			str := str . "`nASCII " . VKey . " - 3) Unsupported prefix key. For example, using the mouse wheel as a prefix in a hotkey such as WheelDown & Enter is not supported."
		Else If (errorlevel = 4)
			str := str . "`nASCII " . VKey . " - 4) The KeyName parameter is not suitable for use with the AltTab or ShiftAltTab actions. A combination of two keys is required. For example: RControl & RShift::AltTab."
		Else If (errorlevel = 5)
			str := str . "`nASCII " . VKey . " - 5) The command attempted to modify a nonexistent hotkey."
		Else If (errorlevel = 6)
			str := str . "`nASCII " . VKey . " - 6) The command attempted to modify a nonexistent variant of an existing hotkey. To solve this, use Hotkey IfWin to set the criteria to match those of the hotkey to be modified."
		Else If (errorlevel = 50)
			str := str . "`nASCII " . VKey . " - 50) Windows 95/98/Me: The command completed successfully but the operating system refused to activate the hotkey. This is usually caused by the hotkey being "" ASCII " . int . " - in use"" by some other script or application (or the OS itself). This occurs only on Windows 95/98/Me because on other operating systems, the program will resort to the keyboard hook to override the refusal."
		Else If (errorlevel = 51)
			str := str . "`nASCII " . VKey . " - 51) Windows 95/98/Me: The command completed successfully but the hotkey is not supported on Windows 95/98/Me. For example, mouse hotkeys and prefix hotkeys such as a & b are not supported."
		Else If (errorlevel = 98)
			str := str . "`nASCII " . VKey . " - 98) Creating this hotkey would exceed the 1000-hotkey-per-script limit (however, each hotkey can have an unlimited number of variants, and there is no limit to the number of hotstrings)."
		Else If (errorlevel = 99)
			str := str . "`nASCII " . VKey . " - 99) Out of memory. This is very rare and usually happens only when the operating system has become unstable."

		MsgBox, %str%
	}
}

ShowHotKeyConflictUI(hkeyObj, hkey, hkeyLabel, oldLabel = "", preventedAssignment = false) {
	SplashUI.DestroyUI()
	
	Gui, HotkeyConflict:Destroy
	Gui, HotkeyConflict:Font,, Consolas

	Gui, HotkeyConflict:Add, Edit, w0 h0
	
	Gui, HotkeyConflict:Add, Text, x17 w150 h20, Label
	Gui, HotkeyConflict:Add, Text, x+10 yp+0 w150 h20, Pretty hotkey
	Gui, HotkeyConflict:Add, Text, x+10 yp+0 w150 h20, Hotkey
	Gui, HotkeyConflict:Add, Text, x+10 yp+0 w150 h20, Virtual Key
	line := ""
	Loop, 130 {
		line .= "-"
	}
	Gui, HotkeyConflict:Add, Text, x17 y+-5 w630 h20, % line
	
	Gui, HotkeyConflict:Add, Text, x17 y+0 w150 h20, % hkeyLabel
	Gui, HotkeyConflict:Add, Hotkey, x+10 yp-3 w150 h20, % hkeyObj[5]
	Gui, HotkeyConflict:Add, Text, x+10 yp+3 w150 h20, % hkeyObj[6]
	Gui, HotkeyConflict:Add, Text, x+10 yp+0 w150 h20, % hkey
	
	If (StrLen(oldLabel)) {
		Gui, HotkeyConflict:Font, bold
		Gui, HotkeyConflict:Add, Text, x17 y+15 w400 h20, % "Old Label: " oldLabel	
		Gui, HotkeyConflict:Font, norm
	}	
	
	Gui, HotkeyConflict:Font,, Verdana
	msg := "The hotkey for the label/function/feature """ hkeyLabel """ was previously used for "
	msg .= (StrLen(oldLabel)) ? "the label """ oldLabel """." : "a different one."
	If (not preventedAssignment) {
		msg .= "`nThe previously created one got overwritten and is now unassigned, please resolve this conflict`nin the settings menu."			
	} Else {
		msg .= "`nThis current hotkey was not assigned, keeping it's previous value. Please resolve this conflict`nin the settings menu if you want to set the hotkey to this function."
	}	
	msg .= "`n`nYou may have to restart the script afterwards."
	
	Gui, HotkeyConflict:Add, Text, x17 y+15 w630 h80, % msg
	
	Gui, HotkeyConflict:Add, Button, w60 x590 gCloseHotkeyConflictGui, Close
	Gui, HotkeyConflict:Show, xCenter yCenter w660, Hotkey conflict
	
	WinWaitClose, Hotkey conflict
	sleep 5000	
}


; ############ (user) macros #############
; macros are being appended here by merge script
