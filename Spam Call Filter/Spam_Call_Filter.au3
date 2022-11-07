#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=modem.ico
#AutoIt3Wrapper_UseX64=n
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "CommMG.au3"
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

#Region Initial Globals
; All registry settings stored here.
Global $gsRegBase = "HKEY_CURRENT_USER\Software\SpamCallFilter"
Global $oModem = ObjCreate("Scripting.Dictionary")
; Not monitor yet.
Global $gbCallMonitor = False, $gbLineProcessing = False, $gbRinging = False, $gbOnHook = True

; AppData folder
Global $gsAppDir = @AppDataDir & "\SpamCallFilter"
If Not FileExists($gsAppDir) Then 
	DirCreate($gsAppDir)
EndIf

; Ringing code
Global $gsCodeRing = RegRead($gsRegBase, "CodeRing")
If @error Then 
	$gsCodeRing = Chr(16) & "R"
	RegWrite($gsRegBase, "CodeRing", "REG_SZ", $gsCodeRing)
EndIf

; Caller id number code
Global $gsCodeCIDNumber = RegRead($gsRegBase, "CodeCIDNumber")
If @error Then 
	$gsCodeCIDNumber = "NMBR"
	RegWrite($gsRegBase, "CodeCIDNumber", "REG_SZ", $gsCodeCIDNumber)
EndIf

Global $gaRules[0][2]		; Data for $lvRuleList]]
Enum $RULE_PATTERN, $RULE_POLICY

Global $giCurrentRuleIndice, $giCurrentPhoneCallIndice
#EndRegion Globals

#include "Disclaimer.au3"
If Not Disclaimer() Then Exit	; Not Accpeting the terms.

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

Global $ghTimer = TimerInit()
While True
    ;sleep(40)
    ;gets characters received returning when one of these conditions is met:
    ;receive @CR, received 20 characters or 200ms has elapsed
    $instr = _commGetLine(@CR, 20, 200);_CommGetString()

    If $instr <> '' Then ;if we got something
		If StringStripWS($instr,3) <> "" Then
			If $gbCallMonitor And Not $gbLineProcessing Then 
				ProcessLine($instr)
			EndIf
			AddLine($instr)
			; SaveLine($instr)
		EndIf
    Else
        Sleep(20) ;MichaelXMike
    EndIf
	If TimerDiff($ghTimer) > 1000 Then 
		DoEverySecond()
		$ghTimer = TimerInit()
	EndIf
WEnd

Alldone()

#Region Functions
#include "SetModemPort.au3"
#include "Rules.au3"
#include "PlayWav.au3"

Func Events()
    Opt("GUIOnEventMode", 1)
    GUISetOnEvent($GUI_EVENT_CLOSE, "AllDone")
    GUICtrlSetOnEvent($btnSend, "EventSend")
    GUICtrlSetOnEvent($btnSetPort, "EventSetPort")
	GUISetOnEvent($GUI_EVENT_RESIZED, "RememberSize")
	GUICtrlSetOnEvent($btnMonitor, "StartMonitor")
	GUICtrlSetOnEvent($btnTest, "RuleIsPhilip")
	GUICtrlSetOnEvent($btnWhiteList, "RuleAddWhiteList")
	GUICtrlSetOnEvent($btnWarning, "RuleAddWarning")
	GUICtrlSetOnEvent($btnDisconnect, "RuleAddDisconnect")
	GUICtrlSetOnEvent($btnFakeFax, "RuleAddFakeFax")
	GUICtrlSetOnEvent($btnPhilip, "RuleAddPhilip")
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
	$gbLineProcessing = True
	c("Line:" & $sLine)
	Switch $sLine
		
		Case $gsCodeRing
			; Line is ringing
			$gbRinging = True
			
		Case Else
			If $gbRinging Then 
				If StringLeft($sLine, 4) = $gsCodeCIDNumber Then 
					$sNumber = GetValueBySep( $sLine, " = ")
					ProcessNumber($sNumber)
				EndIf
			EndIf

	EndSwitch
	
	$gbLineProcessing = False
EndFunc

Func ProcessNumber($sNumber)
	; Here will look up the number then process it with rules.
	
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
	
EndFunc

Func RememberSize()
	; Save the main GUI size in registry
	$aPos = WinGetPos($guiMain)
	; RegWrite($gsRegBase, "WinX", "REG_DWORD", $aPos[0])
	; RegWrite($gsRegBase, "WinY", "REG_DWORD", $aPos[1])
	RegWrite($gsRegBase, "WinW", "REG_DWORD", $aPos[2])
	RegWrite($gsRegBase, "WinH", "REG_DWORD", $aPos[3])
EndFunc


Func InitModem()
	; Initialize modem settings.
	SendCommand("ATZ")	; Soft reset the modem to default profile
	SendCommand("ATE0")	; Disable command echo
	Local $sResult = SendCommand("AT+FCLASS=8")	; Enter voice mode
	If Not EndWithOK($sResult) Then 
		Return SetError(1)
	EndIf
	AddLine ("Modem now initialized and in voice mode.")
	AddLine("Set DTMF duration to 0.2" & SendCommand("AT+VTD=20") )	; Set DTMF dial tone duration. Reg is 85, too long.

	; SendCommand("ATV1")	; Set verbose response
	; SendCommand("ATX3")	; Set get basic result codes with dial tone detection

	
	$sResult = SendCommand("AT&V") ; Get all the parameters
	; Get the codes.
	With $oModem
		.Item("Escape") = Int( GetPara($sResult, "S02:") )
		.Item("CR") = Int( GetPara($sResult, "S03:") )
		.Item("LF") = Int( GetPara($sResult, "S04:") )
	EndWith
	SendCommand("ATS0=0")	; Disable auto answering (just in case)
	SendCommand("AT+FCLASS=8")	; Entering Voice mode
	SendCommand("AT+VCID=1")	; Enable caller ID
	
EndFunc

Func GetPara($sResult, $sPara)
	; Get the S0, S1... value from the AT&V command result
	Local $iPos1 = StringInStr($sResult, $sPara ) 
	If $iPos1 = 0 Then Return ""
	$iPos2 = StringInStr($sResult, " ", 2, 1, $iPos1 + 1)
	Return StringStripWS(StringMid($sResult, $iPos1, $iPos2-$iPos1), 2)
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
		_GUICtrlEdit_AppendText($edReceived, @CRLF & $Line)	; Append new line
	EndIf

;~ 	_GUICtrlEdit_SetSel($edReceived, $iLen+1, -1)	; Select the last line

;~ 	_GUICtrlEdit_Scroll($edReceived, $SB_SCROLLCARET )	; Scroll to the end.
;~ 	_GUICtrlEdit_SetSel($edReceived, -1, -1)	; Deselect last line.

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
    ;MsgBox(0,'will close ports','')
    _Commcloseport(true)
    ;MsgBox(0,'port closed','')
    Exit
EndFunc   ;==>AllDone

Func c($str)
	ConsoleWrite($str & @CRLF)
EndFunc

#EndRegion Functions