﻿If (!FileExist(A_ScriptDir "\main.ahk")) {
	RunWait, Run_Only_This.ahk
	While (!FileExist(A_ScriptDir "\main.ahk")) {
		Sleep, 500
	}
}

SplitPath, A_AhkPath,, AhkDir
RunWait %comspec% /c ""%AhkDir%"\Compiler\Ahk2Exe.exe /in "main.ahk" /out "PoE-TradeMacro_(Fallback).exe" /icon "resources\poe-trade-bl.ico""
ExitApp