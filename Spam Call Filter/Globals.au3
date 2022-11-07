;Globals.au3
; All registry settings stored here.
Global $gsRegBase = "HKEY_CURRENT_USER\Software\SpamCallFilter"
Global $oModem = ObjCreate("Scripting.Dictionary")
; Not monitor yet.
Global $gbCallMonitor = False, $gbLineProcessed = False, $gbRinging = False, $gbOnHook = True

; AppData folder
Global $gsAppDir = @AppDataDir & "\SpamCallFilter"
If Not FileExists($gsAppDir) Then 
	DirCreate($gsAppDir)
EndIf

; Modem codes
; Ring
Global $gsCodeRing = RegRead($gsRegBase, "CodeRing")
If @error Then 
	$gsCodeRing = Chr(16) & "R"
	RegWrite($gsRegBase, "CodeRing", "REG_SZ", $gsCodeRing)
EndIf
; Dial tone
Global $gsCodeDialTone = RegRead($gsRegBase, "CodeDialTone")
If @error Then 
	$gsCodeDialTone = Chr(16) & "d"
	RegWrite($gsRegBase, "CodeRing", "REG_SZ", $gsCodeDialTone)
EndIf
; Busy
Global $gsCodeBusy = RegRead($gsRegBase, "CodeBusy")
If @error Then 
	$gsCodeRing = Chr(16) & "b"
	RegWrite($gsRegBase, "CodeBusy", "REG_SZ", $gsCodeBusy)
EndIf
; Underbuffer
Global $gsCodeUnderBuffer = RegRead($gsRegBase, "CodeUnderBuffer")
If @error Then 
	$gsCodeUnderBuffer = Chr(16) & "u"
	RegWrite($gsRegBase, "CodeUnderBuffer", "REG_SZ", $gsCodeUnderBuffer)
EndIf

; Caller id codes
Global $gsCodeDate = RegRead($gsRegBase, "CodeDate")
If @error Then 
	$gsCodeNumber = "DATE"
	RegWrite($gsRegBase, "CodeDate", "REG_SZ", $gsCodeDate)
EndIf

Global $gsCodeTime = RegRead($gsRegBase, "CodeTime")
If @error Then 
	$gsCodeNumber = "TIME"
	RegWrite($gsRegBase, "CodeTime", "REG_SZ", $gsCodeTime)
EndIf

Global $gsCodeNumber = RegRead($gsRegBase, "CodeNumber")
If @error Then 
	$gsCodeNumber = "NMBR"
	RegWrite($gsRegBase, "CodeNumber", "REG_SZ", $gsCodeNumber)
EndIf

Global $gsCodeName = RegRead($gsRegBase, "CodeName")
If @error Then 
	$gsCodeNumber = "NAME"
	RegWrite($gsRegBase, "CodeNumber", "REG_SZ", $gsCodeName )
EndIf

Global $gaRules[0][2]		; Data for $lvRuleList]]
Enum $RULE_PATTERN, $RULE_POLICY

Global $giCurrentRuleIndice, $giCurrentPhoneCallIndice

Global $gaCalls[0][5]
Enum $CALL_DATE, $CALL_TIME, $CALL_NUMBER, $CALL_NAME, $CALL_POLICYAPPLIED
Global $gaCurrentCall[5]
