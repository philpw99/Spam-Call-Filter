;Globals.au3
; All registry settings stored here.

Global $gsRegBase = "HKEY_CURRENT_USER\Software\SpamCallFilter"
Global $oModem = ObjCreate("Scripting.Dictionary")
; Set auto monitor. The monitoring setting will be determined in the main file.
Global $gbCallMonitor = False

; This is the phone recorder buffer.
Global $gsPhoneInBuffer = ""
Global $gsPhoneOutBuffer

; Set Save log
Global $gbSaveLog = False 
If RegRead($gsRegBase, "SaveLog") = 1 Then
	$gbSaveLog = True
EndIf

Global $gbLineProcessed = False, $gbRinging = False, $gbOnHook = True

; Modem receive data and set the following flags. If no function handles it, it will remain true or not empty.

; AppData folder
Global $gsAppDir = @AppDataDir & "\SpamCallFilter"
If Not FileExists($gsAppDir) Then 
	DirCreate($gsAppDir)
EndIf

Global $giComSpeed = RegRead($gsRegBase, "ComSpeed")
If @error Then 
	$giComSpeed = 9600	; Universal speed
	RegWrite($gsRegBase, "ComSpeed", "REG_DWORD", $giComSpeed)
EndIf

; Initial Modem codes
InitCodes()

; Initialize receive state flags
InitReceiveFlags()

Global $gaRules[0][2]		; Data for $lvRuleList]]
Enum $RULE_PATTERN, $RULE_POLICY

Global $giCurrentRuleIndice, $giCurrentPhoneCallIndice

Global $gaCalls[0][5]
Enum $CALL_DATE, $CALL_TIME, $CALL_NUMBER, $CALL_NAME, $CALL_POLICYAPPLIED
Global $gaCurrentCall[5]

Func GuiTitle()
	Return "Spam Call Filter v" & $gsVersion
EndFunc

Func InitReceiveFlags()
	; Initialize all the global receive flags
	Global $gfKeyPressed = False, $gsKeyPressed = "", $gfRing = False, $gfDataEnd = False
	Global $gfBufferOverrun = False, $gfBufferUnderrun = False
	Global $gfHangUp = False, $gfBusy = False, $gfDialTone = False 
	Global $gsReceiveBuffer = ""
EndFunc


Func InitCodes()
	; It will read the registry and set the global codes
	; Ring
	Global $gsCodeRing = RegRead($gsRegBase, "CodeRing")
	If @error Then 
		$gsCodeRing = Chr(16) & "R"
		RegWrite($gsRegBase, "CodeRing", "REG_SZ", $gsCodeRing)
		If @error Then c("error writing code ring:" & @error)
	EndIf
	; Dial tone
	Global $gsCodeDialTone = RegRead($gsRegBase, "CodeDialTone")
	If @error Then 
		$gsCodeDialTone = Chr(16) & "d"
		RegWrite($gsRegBase, "CodeDialTone", "REG_SZ", $gsCodeDialTone)
	EndIf
	; Busy
	Global $gsCodeBusy = RegRead($gsRegBase, "CodeBusy")
	If @error Then 
		$gsCodeBusy = Chr(16) & "b"
		RegWrite($gsRegBase, "CodeBusy", "REG_SZ", $gsCodeBusy)
	EndIf
	; Underbuffer
	Global $gsCodeUnderBuffer = RegRead($gsRegBase, "CodeUnderBuffer")
	If @error Then 
		$gsCodeUnderBuffer = Chr(16) & "u"
		RegWrite($gsRegBase, "CodeUnderBuffer", "REG_SZ", $gsCodeUnderBuffer)
	EndIf
	; Extension Pickup
	Global $gsCodeExtPickup = RegRead($gsRegBase, "CodeExtPickup")
	If @error Then 
		$gsCodeExtPickup = Chr(16) & "P"
		RegWrite($gsRegBase, "CodeExtPickup", "REG_SZ", $gsCodeExtPickup)
	EndIf
	; Extension Hangup
	Global $gsCodeExtHangup = RegRead($gsRegBase, "CodeExtHangup")
	If @error Then 
		$gsCodeExtHangup = Chr(16) & "p"
		RegWrite($gsRegBase, "CodeExtHangup", "REG_SZ", $gsCodeExtHangup)
	EndIf

	; Caller id codes
	Global $gsCodeCidDate = RegRead($gsRegBase, "CodeCidDate")
	If @error Then 
		$gsCodeCidDate = "DATE"
		RegWrite($gsRegBase, "CodeCidDate", "REG_SZ", $gsCodeCidDate)
	EndIf

	Global $gsCodeCidTime = RegRead($gsRegBase, "CodeCidTime")
	If @error Then 
		$gsCodeCidTime = "TIME"
		RegWrite($gsRegBase, "CodeCidTime", "REG_SZ", $gsCodeCidTime)
	EndIf

	Global $gsCodeCidNumber = RegRead($gsRegBase, "CodeCidNumber")
	If @error Then 
		$gsCodeCidNumber = "NMBR"
		RegWrite($gsRegBase, "CodeCidNumber", "REG_SZ", $gsCodeCidNumber)
	EndIf

	Global $gsCodeCidName = RegRead($gsRegBase, "CodeCidName")
	If @error Then 
		$gsCodeCidName = "NAME"
		RegWrite($gsRegBase, "CodeCidName", "REG_SZ", $gsCodeCidName )
	EndIf
	
	Global $gsCodeCidSep = RegRead($gsRegBase, "CodeCidSep")
	If @error Then 
		$gsCodeCidSep = " = "
		RegWrite($gsRegBase, "CodeCidSep", "REG_SZ", $gsCodeCidSep )
	EndIf
EndFunc
