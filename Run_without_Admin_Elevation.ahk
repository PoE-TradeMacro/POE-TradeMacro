; This script merges TradeMacroInit, PoE-ItemInfo and TradeMacro into one script and executes it.
FileRemoveDir, %A_ScriptDir%/temp, 1
#Include, %A_ScriptDir%/resources/VersionTrade.txt
TradeMsgWrongAHKVersion := "AutoHotkey v" . TradeAHKVersionRequired . " or later is needed to run this script. `n`nYou are using AutoHotkey v" . A_AhkVersion . " (installed at: " . A_AhkPath . ")`n`nPlease go to http://ahkscript.org to download the most recent version."
If (A_AhkVersion < TradeAHKVersionRequired)
{
    MsgBox, 16, Wrong AutoHotkey Version, % TradeMsgWrongAHKVersion
    ExitApp
}



StartSplashScreen()

FileRead, info, POE-ItemInfo.ahk
FileRead, tradeInit, %A_ScriptDir%\data_trade\TradeMacroInit.ahk
FileRead, trade, %A_ScriptDir%\data_trade\TradeMacro.ahk

info := "`n`r`n`r" . info . "`n`r`n`r"
CloseScript("main.ahk")
FileDelete, %A_ScriptDir%\main.ahk
FileCopy, %A_ScriptDir%\data_trade\TradeMacroInit.ahk, %A_ScriptDir%\main.ahk
FileAppend, %info%, %A_ScriptDir%\main.ahk
FileAppend, %trade%, %A_ScriptDir%\main.ahk

Run %A_ScriptDir%\main.ahk
ExitApp 

CloseScript(Name)
{
	DetectHiddenWindows On
	SetTitleMatchMode RegEx
	IfWinExist, i)%Name%.* ahk_class AutoHotkey
		{
		WinClose
		WinWaitClose, i)%Name%.* ahk_class AutoHotkey, , 2
		If ErrorLevel
			return "Unable to close " . Name
		else
			return "Closed " . Name
		}
	else
		return Name . " not found"
}


StartSplashScreen() {
    SplashTextOn, , 20, PoE-TradeMacro, Merging and starting Scripts...
}