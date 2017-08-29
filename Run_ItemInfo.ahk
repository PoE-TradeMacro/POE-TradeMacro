﻿; #####################################################################################################################
; # This script checks if the right AHK version is installed and runs the ItemInfo merge script.
; #####################################################################################################################
#Include, %A_ScriptDir%\resources\Version.txt

MsgWrongAHKVersion := "AutoHotkey v" . AHKVersionRequired . " or later is needed to run this script. `n`nYou are using AutoHotkey v" . A_AhkVersion . " (installed at: " . A_AhkPath . ")`n`nPlease go to http://ahkscript.org to download the most recent version."
If (A_AhkVersion < AHKVersionRequired)
{
    MsgBox, 16, Wrong AutoHotkey Version, % AHKVersionRequired
    ExitApp
}

Run "%A_AhkPath%" "%A_ScriptDir%\resources\ahk\Merge_ItemInfo.ahk" "%A_ScriptDir%"