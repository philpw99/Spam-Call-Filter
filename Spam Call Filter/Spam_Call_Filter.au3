#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=modem.ico
#AutoIt3Wrapper_UseX64=n
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <windowsconstants.au3>
#include <buttonconstants.au3>
#include <FileConstants.au3>
#include <ScrollBarsConstants.au3>
#include <StaticConstants.au3>
#include <GUIConstantsEx.au3>
#Include <GuiButton.au3>
#include <GuiEdit.au3>
#include <EditConstants.au3>
#include <GuiComboBox.au3>
#include <GuiListView.au3>
#include <GuiTab.au3>
#include <WINAPI.au3>	; For wav playback
#include <Array.au3>

; Communication main functions
#include "CommMG.au3"
; Initialize globals
#include "Globals.au3"

#include "Disclaimer.au3"
If Not Disclaimer() Then Exit	; Not Accpeting the terms.

; Create main gui
Global $guiMain = GUICreate("Main",671,723,-1,-1,BitOr($WS_SIZEBOX,$WS_SYSMENU,$WS_MINIMIZEBOX),-1)
#include "Forms\Main.isf"

; Get last remember size
Local $iWinW = RegRead($gsRegBase, "WinW")	
If Not @error Then
	Local $iWinH= RegRead($gsRegBase, "WinH")
	WinMove($guiMain, "", Default , Default , $iWinW, $iWinH )
EndIf 

GUISetState( @SW_SHOW, $guiMain )

$gsComPort = RegRead($gsRegBase, "ComPort")
If @error Then
	While SetModemPort("NEW") = False
		If MsgBox(4, "Modem's Port not set", 'Do you want to quit the program?') = 6 Then
			AllDone()
		EndIf
	WEnd
Else
	If Not ( SetModemPort($gsComPort) And PortIsOK() ) Then
		While SetModemPort("NEW") = False
			If MsgBox(4, "Modem's Port not set", 'Do you want to quit the program?') = 6 Then
				AllDone()
			EndIf
		WEnd
	EndIf
EndIf

; Load Rule Data
LoadRules()

GetModemInfo()
; Initialize modem settings, put it in voicemode
InitModem()
If @error = 1 Then 
	MsgBox(0, "Error", "Error entering voice mode.")
	AllDone()
EndIf

; Set the COM port text
GUICtrlSetData($lblComPort, $oModem.Item("Port") )

; Set Xon Xoff values
_CommSetXonXoffProperties(11, 13, 100, 100)

; Start event mode
Events()

; Auto monitor
Local $iAutoStart = RegRead($gsRegBase, "AutoMonitor")
If Not @error And $iAutoStart = 1 Then 
	StartMonitor()
EndIf


Global $ghTimer = TimerInit()	; For doing things every second.
Global $iCheckTime = 250		; Check every 250ms instead of 1000 ms
While True
    ;sleep(40)
    ;gets characters received returning when one of these conditions is met:
    ;receive @CR, received 20 characters or 200ms has elapsed
    $instr = _commGetLine(@CR, 20, 200);_CommGetString()

    If $instr <> '' Then ;if we got something
		If StringStripWS($instr,3) <> "" Then
			If $gbCallMonitor Then
				c( "start processing line:" & $instr)
				ProcessLine($instr)
			EndIf
			AddLine($instr)
			; SaveLine($instr)
		EndIf
    Else
        Sleep(20)
    EndIf
	If TimerDiff($ghTimer) > $iCheckTime Then 
		DoEverySecond()
		$ghTimer = TimerInit()
	EndIf
WEnd

Alldone()	; Disconnect all ports and exit

#Region Functions
#include "Modem.au3"		; Modem functions
#include "Settings.au3"
#include "Rules.au3"		; Rules functions
#include "PlayWav.au3"		; Functions to play wav files.

Func Events()
    Opt("GUIOnEventMode", 1)

	; General GUI stuff
    GUISetOnEvent($GUI_EVENT_CLOSE, "AllDone")
	GUISetOnEvent($GUI_EVENT_RESIZED, "RememberSize")
	
	; First Tab Buttons
	GUICtrlSetOnEvent($btnMonitor, "StartMonitor")
	GUICtrlSetOnEvent($btnWhiteList, "RuleAddWhiteList")
	GUICtrlSetOnEvent($btnWarning, "RuleAddWarning")
	GUICtrlSetOnEvent($btnDisconnect, "RuleAddDisconnect")
	GUICtrlSetOnEvent($btnFakeFax, "RuleAddFakeFax")
	GUICtrlSetOnEvent($btnPhilip, "RuleIsPhilip")
	
	; Rule List Tab Buttons
	GUICtrlSetOnEvent($btnRuleAddAdv, "RuleAddAdv")
	GUICtrlSetOnEvent($btnRuleChange, "RuleChange")
	GUICtrlSetOnEvent($btnRuleDelete, "RuleDelete")
	
	
	; Setting Tab
    GUICtrlSetOnEvent($btnSetPort, "EventSetPort")
	GUICtrlSetOnEvent($chkAutoMonitor, "SetAutoMonitor")
	GUICtrlSetOnEvent($btnSave, "SaveSettings")
	
	; Log Tab
    GUICtrlSetOnEvent($btnSend, "EventSend")
	GUICtrlSetOnEvent($btnTest, "TestLine")

EndFunc   ;==>Events

Func DoEverySecond()
	Local $iRow
	; Check on something every second
	Switch _GUICtrlTab_GetCurFocus($tab)
		Case 0	; Phone calls
			$iRow = _GUICtrlListView_GetSelectedIndices($lvPhoneCalls)
			If $iRow <> $giCurrentPhoneCallIndice Then 
				; Some row is selected or unselected
				SetCurrentNumber($iRow)
				$giCurrentPhoneCallIndice = $iRow
			EndIf
			
		Case 1	; Rule list
			$iRow = _GUICtrlListView_GetSelectedIndices($lvRuleList)
			If $iRow <> $giCurrentRuleIndice Then 
				; Some row is selected or unselected
				SetCurrentRule($iRow)
				$giCurrentRuleIndice = $iRow
			EndIf
	EndSwitch 
EndFunc

Func TestLine()
	; Pickup the line then get code.
	AddLine("Doing Test Line...")
	AddLine( "Modem Pickup:" & SendCommand("AT+VLS=5") )	; Modem pick up, Internal speaker connected to the line.
	WaitReceiveLines(30000)
	AddLine( "Modem On Hook:" & SendCommand("AT+VLS=0") )	; Modem off hook
	AddLine( "Modem Hang Up:" & SendCommand("ATH") )		; Hang up just in case.
EndFunc

Func Bingo()
	MsgBox(0, "Bingo", "Bingo")
EndFunc

Func WaitReceiveLines($iTimeLimit = 5000 )
	; This is for writing received lines only
	; The lines will be written to log, but not returned.
	Local $hTimer = TimerInit()
	While TimerDiff( $hTimer ) < $iTimeLimit
		$instr = _commGetLine(@CR, 20, 200)
		If $instr <> "" Then
			AddLine($instr)
		EndIf
		Sleep(100)
		; Receive busy signal, the line is disconnected.
		If $instr = Chr(16) & "b" Then Return 
	WEnd
	
EndFunc


Func ProcessLine($sLine)
	; When doing monitor. The info will come here in lines.
	$sLine = StringStripWS($sLine, 1)	; No leading white space.
	c("Line:" & $sLine)
	Switch $sLine
	
		Case $gsCodeRing
			; Line is ringing
			If $gbRinging = False Then
				; The ringing just started. Reset the values.
				$gbRinging = True
				$gbLineProcessed = False
				Global $gaCurrentCall = ["", "", "", "", ""]
			EndIf
				
		Case $gsCodeBusy
			; Line is busy or disconnected
			$gbRinging = False
			$gbLineProcessed = False
			Global $gaCurrentCall = ["", "", "", "", ""]
		
		Case Else
			If $gbRinging And Not $gbLineProcessed Then
				c("Process line:" & $sLine)
				Switch GetValueBySep($sLine, $gsCodeCidSep )	; Get the value on the left side of " = ", or other seperator.
					Case $gsCodeCidDate
						$gaCurrentCall[$CALL_DATE] = GetValueBySep($sLine, $gsCodeCidSep, 2) ; Get the value on the right side of =
					Case $gsCodeCidTime
						$gaCurrentCall[$CALL_TIME] = GetValueBySep($sLine, $gsCodeCidSep, 2)
					Case $gsCodeCidNumber
						$gaCurrentCall[$CALL_NUMBER] = GetValueBySep($sLine, $gsCodeCidSep, 2)
					Case $gsCodeCidName
						$gaCurrentCall[$CALL_NAME] = GetValueBySep($sLine, $gsCodeCidSep, 2)
						; Now the name is entered. Time to process this phone.
						ProcessCall()
						$gbLineProcessed = True		; This call is processed. The following ring and call id will be ignored.
					Case Else
						c("Not process value on the left:" & GetValueBySep($sLine, $gsCodeCidSep ) )
				EndSwitch
			EndIf
	EndSwitch
EndFunc

Func HangUp()
	AddLine( "Modem On Hook:" & SendCommand("AT+VLS=0") )	; Modem off hook
	AddLine( "Modem Hang Up:" & SendCommand("ATH") )		; Hang up just in case.
	$gbRinging = False
	$gbLineProcessed = False
	Global $gaCurrentCall = ["", "", "", "", ""]			; Clear the current call.
EndFunc

Func ProcessCall()
	; Here will look up the number then process it with rules.
	; The phone info is in $gaCurrentCall[5]
	Local $bRuleFound = False 
	Local $sNumber = $gaCurrentCall[$CALL_NUMBER]
	For $i = 0 To UBound($gaRules)-1
		; Have to process the rules one by one
		If PatternFits( $sNumber, $gaRules[$i][$RULE_PATTERN] ) Then 
			ApplyRule($gaRules[$i][$RULE_POLICY])
			$bRuleFound = True 
			ExitLoop 
		EndIf
	Next
	If Not $bRuleFound Then ApplyNone()
EndFunc

Func ApplyRule($sPolicy)
	; Apply rule with the current phone call
	$gaCurrentCall[$CALL_POLICYAPPLIED] = $sPolicy
	_GUICtrlListView_AddArray($lvPhoneCalls, $gaCurrentCall)
EndFunc

Func ApplyNone()
	$gaCurrentCall[$CALL_POLICYAPPLIED] = "None"
	_GUICtrlListView_AddArray($lvPhoneCalls, $gaCurrentCall)
EndFunc


Func PatternFits($sNumber, $sPattern)
	If $sNumber = $sPattern Then Return True 	; Check Exactly first
	
	If StringRight($sPattern, 1) = "*" Then ; Starts with
		If StringLeft($sNumber, StringLen($sPattern)-1) & "*" = $sPattern Then Return True
	ElseIf StringLeft($sPattern, 1) = "*" Then ; Ends with
		If "*" & StringRight($sNumber, StringLen($sPattern) -1) = $sPattern Then Return True
	EndIf
	
	Return False
EndFunc



Func GetValueBySep($str, $sep, $occur = 1)
	; return the value seperated by $sep
	; Like str ="v1 v2 v3 v4", $sep=" ", $occur = 3 then return "v3"
	Local $pos1 = ( $occur = 1 ? 1 : StringInStr($str, $sep, 1, $occur - 1) + StringLen($sep) )
	Local $pos2 = StringInStr($str, $sep, 1, $occur )
	If $pos2 = 0 Then $pos2 = Stringlen($str) + 1
	Return StringMid($str, $pos1, $pos2 - $pos1)
EndFunc


Func StartMonitor()
	If $gbCallMonitor Then 
		; Monitoring. Stop it
		$gbCallMonitor = False
		GUICtrlSetData($btnMonitor, "Start Call Monitor")
		GUICtrlSetData($lbStatus, "Not Monitoring.")
	Else
		; Not monitoring, start it.
		$gbCallMonitor = True
		GUICtrlSetData($btnMonitor, "Stop Call Monitor")
		GUICtrlSetData($lbStatus, "Monitoring.")
	EndIf
	; Reset the ring status.
	$gbRinging = False
	$gbLineProcessed = False
	Global $gaCurrentCall = ["", "", "", "", ""]
EndFunc

Func RememberSize()
	; Save the main GUI size in registry
	$aPos = WinGetPos($guiMain)
	; RegWrite($gsRegBase, "WinX", "REG_DWORD", $aPos[0])
	; RegWrite($gsRegBase, "WinY", "REG_DWORD", $aPos[1])
	RegWrite($gsRegBase, "WinW", "REG_DWORD", $aPos[2])
	RegWrite($gsRegBase, "WinH", "REG_DWORD", $aPos[3])
EndFunc

Func PortIsOK()
	; Return true if OK, false if not.
	$sResult = SendCommand("AT")
	Return EndWithOK($sResult)
EndFunc

Func SendCommand($sCommand, $iReplyTimeLimit = 1000)
	; When port is open, send a command and get the reply from the port
	; Input: text command to send to serial port
	; Output: returned result within time limit,default 1 second
	_CommSendstring( $sCommand & @CR)
	$hTimer = TimerInit()
	$sReply = ""
	While TimerDiff($hTimer) < $iReplyTimeLimit
		$sReturn = _CommGetLine(@CR, 80, 200)
		If $sReturn <> "" Then
			; reset the timer, wait another second
			$hTimer = TimerInit()
			$sReply &= $sReturn
			If EndWithOK($sReturn) Then 
				; The communication is done
				Return StringStripWS($sReply, 3)
			EndIf
		Else
			Sleep(20)
		EndIf
	Wend
	Return StringStripWS($sReply, 3)
EndFunc


Func SaveLine($line)
	; Don't record empty lines
	$line = StringStripWS($line, 3)
	; C("LINE:" & StringToBinary($line))
	If $line = "" Then return
	; Save file
	Local $sFile = $gsAppDir & "\ComLog.txt"
	Local $hFile = FileOpen($sFile, $FO_APPEND )
	If $hFile = -1 Then Return SetError(1)
	FileWrite($hFile, @MON & "/" & @MDAY & " " & @HOUR & ":" & @MIN & " " & $line & @CR)
	FileClose($hFile)
EndFunc


Func AddLine($Line)
	; Add one line to the received text
	Local $sReceived = GUICtrlRead($edReceived)
	; Trim it if too long
	If StringLen($sReceived) > 3000 Then 
		$sReceived = StringRight( $sReceived, 1500)
		_GUICtrlEdit_SetText($edReceived, $sReceived )
	EndIf 
	Local $iLen = StringLen($sReceived)
	If $iLen = 0 Then
		_GUICtrlEdit_AppendText($edReceived, $Line)
	Else
		_GUICtrlEdit_AppendText($edReceived, "<|" & @CRLF & $Line)	; Append new line
	EndIf

;~ 	_GUICtrlEdit_SetSel($edReceived, $iLen+1, -1)	; Select the last line

;~ 	_GUICtrlEdit_Scroll($edReceived, $SB_SCROLLCARET )	; Scroll to the end.
;~ 	_GUICtrlEdit_SetSel($edReceived, -1, -1)	; Deselect last line.

	; Save it to a file if set in settings.
	If $gbSaveLog Then SaveLine($Line)
		
EndFunc

Func EventSetPort()
	; Close all port first
	_Commcloseport(true)
	
	While SetModemPort("NEW") = False
		If MsgBox(4, "Modem's Port not set", 'Do you want to quit the program?') = 6 Then
			AllDone()
		EndIf
	Wend
	
	; Set the COM port text
	GUICtrlSetData($lblComPort,  _CommPortConnection() )
    GUICtrlSetState($inpCommand, $GUI_FOCUS)
EndFunc   ;==>SetPortEvent

Func EventSend();send the text in the inputand append CR
	Local $line = GUICtrlRead( $inpCommand )
	$sResult = SendCommand($line)
    GUICtrlSetData($inpCommand, '');clear the input
	AddLine( "Send: " & $line )
	AddLine( $sResult)
	; SaveLine("Send: " & $line & @CRLF & $sResult)
    ;GUICtrlSetState($edit1,$GUI_FOCUS);sets the caret back in the terminal screen
EndFunc   ;==>SendEvent

Func AllDone()
	SendCommand("ATZ")	; Reset modem.
    _Commcloseport(true)
    Exit
EndFunc   ;==>AllDone

Func c($str)
	ConsoleWrite($str & @CRLF)
EndFunc

#EndRegion Functions