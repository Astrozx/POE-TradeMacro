﻿; ignore include errors to support two different paths
#Include, *i CalcChecksum.ahk
#Include, *i %A_ScriptDir%\..\..\lib\CalcChecksum.ahk

#Include, *i JSON.ahk
#Include, *i %A_ScriptDir%\..\..\lib\JSON.ahk

#Include, *i EasyIni.ahk
#Include, *i %A_ScriptDir%\..\..\lib\EasyIni.ahk


PoEScripts_HandleUserSettings(ProjectName, BaseDir, External, sourceDir, scriptDir = "") {
	Dir := BaseDir . "\" . ProjectName

	; check for git files to determine if it's a development version, return a path using the branch name
	devBranch := PoEScripts_isDevelopmentVersion(scriptDir)
	If (StrLen(devBranch)) {
		Dir .= devBranch
	}
	PoEScripts_CreateDirIfNotExist(Dir)

	; copy/replace/update files after checking if it's neccessary (files do not exist, files were changed in latest update)
	PoEScripts_CopyFiles(sourceDir, Dir, fileList)
	Return fileList
}

PoEScripts_CopyFiles(sourceDir, destDir, ByRef fileList) {
	overwrittenFiles := []
	PoEScripts_CopyFolderContentsRecursive(sourceDir, destDir, overwrittenFiles)

	; provide data for user notification on what files were updated/replaced and backed up if such
	If (overwrittenFiles.Length()) {
		fileList := ""
		Loop, % overwrittenFiles.Length() {
			If (!InStr(fileList, overwrittenFiles[A_Index])) {
				fileList .= "- " . overwrittenFiles[A_Index] . "`n"
			}
		}
	}
	Return
}

; TODO: add docstring and comments
PoEScripts_ConvertOldFiles(sourceDir, destDir, ByRef overwrittenFiles) {
	; TODO: trim whitespaces in key names in current configs?
	If (FileExist(destDir "\MapModWarnings.txt")) {
		PoEScripts_CreateDirIfNotExist(destDir "\backup")
		FileCopy, %destDir%\MapModWarnings.txt, %destDir%\backup\MapModWarnings.txt, 1
		PoEScripts_ConvertMapModsWarnings(destDir)
		FileDelete, %destDir%\MapModWarnings.txt
		overwrittenFiles.Push("MapModWarnings.txt")
	}
	If (!FileExist(destDir "\AdditionalMacros.ini") and FileExist(destDir "\AdditionalMacros.txt")) {
		PoEScripts_CreateDirIfNotExist(destDir "\backup")
		FileCopy, %destDir%\AdditionalMacros.txt, %destDir%\backup\AdditionalMacros.txt, 1
		PoEScripts_ConvertAdditionalMacrosSettings(destDir)
		FileDelete, %destDir%\MapModWarnings.txt
		overwrittenFiles.Push("AdditionalMacros.txt")
	}
	If (FileExist(destDir "\config.ini")) {
		PoEScripts_CreateDirIfNotExist(destDir "\backup")
		FileCopy, %destDir%\config.ini, %destDir%\backup\config.ini, 1
		PoEScripts_ConvertItemInfoConfig(sourceDir, destDir)
		overwrittenFiles.Push("config.ini")
	}
	Return
}

PoEScripts_ConvertItemInfoConfig(sourceDir, destDir) {
	; due to massive changes of comments it's better to convert old file first, and perform update after
	NewConfigObj := class_EasyIni(sourceDir "\config.ini")
	OldConfigObj := class_EasyIni(destDir "\config.ini")
	for sectionName, sectionKeys in OldConfigObj {
		if (NewConfigObj.HasKey(sectionName)) {
			for sectionKeyName, sectionKeyVal in sectionKeys {
				if NewConfigObj[sectionName].HasKey(sectionKeyName) {
					NewConfigObj.SetKeyVal(sectionName, sectionKeyName, sectionKeyVal)
				}
			}
		}
	}
	NewConfigObj.Save(destDir "\config.ini")
	Return
}

PoEScripts_ConvertAdditionalMacrosSettings(destDir) {
	FileRead, File_AdditionalMacros, %destDir%\AdditionalMacros.txt
	labelList := []
	_Pos := 1
	While (_Pos := RegExMatch(File_AdditionalMacros, "i)(global\sAM_.*)", labelStr, _Pos + StrLen(labelStr))) {
		labelList.Push(labelStr)
	}
	AdditionalMacros_INI := class_EasyIni()
	for labelIndex, labelContent in labelList {
		labelHotkeys := ""
		RegExMatch(labelContent, "(AM_.*?)\s", labelName)
		AdditionalMacros_INI.AddSection(labelName1)
		RegExMatch(labelContent, "\[(.*)\]", paramStr)
		for paramIndex, paramContent in StrSplit(paramStr1, ", ") {
			StringReplace, paramContent, paramContent, ",,All
			StringReplace, paramContent, paramContent, [,,All
			StringReplace, paramContent, paramContent, ],,All
			if (paramIndex == 1) {
				AdditionalMacros_INI.AddKey(labelName1, "State", paramContent)
			}
			else if (InStr(labelName1, "KickYourself") and paramIndex == 3){
				AdditionalMacros_INI.AddKey(labelName1, "CharacterName", paramContent)
			}
			else {
				if (labelHotkeys == "") {
					labelHotkeys := paramContent
				}
				else {
					labelHotkeys .= ", " paramContent
				}
			}
		}
		AdditionalMacros_INI.AddKey(labelName1, "Hotkeys", labelHotkeys)
	}
	AdditionalMacros_INI.Save(destDir "\AdditionalMacros.ini")
	Return
}

PoEScripts_ConvertMapModsWarnings(destDir) {
	FileRead, MapModWarnings_TXT, %destDir%\MapModWarnings.txt
	MapModWarnings_JSON := JSON.Load(MapModWarnings_TXT)
	MapModWarnings_INI := class_EasyIni()
	secGeneral := "General"
	secAffixes := "Affixes"
	MapModWarnings_INI.AddSection(secGeneral)
	MapModWarnings_INI.AddSection(secAffixes)
	If (MapModWarnings_JSON.HasKey("enable_Warnings")) {
		MapModWarnings_INI.AddKey(secGeneral, "enable_Warnings", MapModWarnings_JSON.enable_Warnings)
		MapModWarnings_JSON.Delete("enable_Warnings")
	}
	For keyName, keyVal in MapModWarnings_JSON {
		MapModWarnings_INI.AddKey(secAffixes, keyName, keyVal)
	}
	MapModWarnings_INI.Save(destDir "\MapModWarnings.ini")
	Return
}

PoEScripts_CopyFolderContentsRecursive(SourcePath, DestDir, ByRef overwrittenFiles, DoOverwrite = false) {
	If (!InStr(FileExist(DestDir), "D")) {
		count := 0
		Loop, %SourcePath%\*.*, 1, 1
		{
			count++
		}
		If (count > 0) {
			FileCreateDir, %DestDir%
		}
		Else {
			Return
		}
	}
	Else {
		PoEScripts_ConvertOldFiles(SourcePath, DestDir, overwrittenFiles)
	}
	Loop %SourcePath%\*.*, 1
	{
		If (InStr(FileExist(A_LoopFileFullPath), "D")) {
			PoEScripts_CopyFolderContentsRecursive(A_LoopFileFullPath, DestDir "\" A_LoopFileName, overwrittenFiles, DoOverwrite)
		}
		Else {
			fileAction := PoEScripts_GetActionForFile(A_LoopFileFullPath, DestDir)
			PoEScripts_DoActionForFile(fileAction, A_LoopFileFullPath, DestDir, overwrittenFiles)
		}
	}
	Return
}

PoEScripts_CleanFileName(fileName, removeStr="") {
	RegExMatch(fileName, "i)(" removeStr ")", removeThis)
	fileName_cleaned := RegExReplace(FileName, removeThis, "")
	Return fileName_cleaned
}

; TODO: add docstring and comments
PoEScripts_GetActionForFile(filePath, destDir) {
	; List of possible actions:
	; - skip (=0)
	; - copy (=1)
	; - update (=2)
	; - replace (=3)
	SplitPath, filePath, fileFullName, fileDir, fileExt, fileName, fileDrive
	If (!RegExMatch(fileExt, "i)bak$")) {
		fileFullName_cleaned := PoEScripts_CleanFileName(fileFullName, "_dontOverwrite")
		If (!FileExist(DestDir "\" fileFullName_cleaned)) {
			Return 1
		}
		Else {
			If (fileFullName == fileFullName_cleaned) {
				If (RegExMatch(fileExt, "i)ini$")) {
					If (!class_EasyIni(destDir "\" fileFullName).Compare(fileDir "\" fileFullName)) {
						Return 2
					}
				}
				Else {
					Return 3
				}
			}
		}
	}
	Return 0
}

; TODO: add docstring and comments
PoEScripts_DoActionForFile(fileAction, filePath, destDir, ByRef overwrittenFiles) {
	If (fileAction == 0) {
		Return
	}
	SplitPath, filePath, fileFullName, fileDir, fileExt, fileName, fileDrive
	fileFullName_cleaned := PoEScripts_CleanFileName(fileFullName, "_dontOverwrite")
	If (fileAction == 1) {
		FileCopy, %filePath%, %destDir%\%fileFullName_cleaned%, 1
		Return
	}
	Else {
		PoEScripts_CreateDirIfNotExist(destDir "\backup")
		If (fileAction == 2) {
			; make backup
			FileCopy, %destDir%\%fileFullName%, %destDir%\backup\%fileFullName%, 1
			; load file into object
			destIniObj := class_EasyIni(destDir "\" fileFullName)
			; update object with source file
			destIniObj.Update(filePath)
			; save changes to file
			destIniObj.Save(destDir "\" fileFullName)
			overwrittenFiles.Push(fileFullName)
		}
		Else If (fileAction == 3) {
			; make backup
			FileCopy, %destDir%\%fileFullName_cleaned%, %destDir%\backup\%fileFullName_cleaned%, 1
			; replace file
			FileCopy %filePath%, %destDir%\%fileFullName_cleaned%, 1
			overwrittenFiles.Push(fileFullName_cleaned)
		}
		Else {
			MsgBox, Unknown file action
			Return
		}
	}
	Return
}

PoEScripts_CreateDirIfNotExist(directory) {
	If (!InStr(FileExist(directory), "D")) {
		FileCreateDir, %directory%
	}
	Return
}

PoEScripts_isDevelopmentVersion(directory = "") {
	directory := StrLen(directory) ? directory : A_ScriptDir
	branch := ""
	If (FileExist(directory "\.git")) {
		If (FileExist(directory "\.git\HEAD")) {
			FileRead, head, %directory%\.git\HEAD
			Loop, Parse, head, `n, `r
			{
				RegExMatch(A_LoopField, "ref:.*\/(.*)", refs)
				If (StrLen(refs1)) {
					branch := "\dev_" . refs1
				}
			}
		}
	}
	Return branch
}
