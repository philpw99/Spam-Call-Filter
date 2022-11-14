#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Outfile_type=a3x
#AutoIt3Wrapper_Icon=modem.ico
#AutoIt3Wrapper_Outfile=release\Spam_Call_Filter.a3x
#AutoIt3Wrapper_UseX64=n
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

Global $gsVersion = "1.01"

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

#Region Declare Main gui and prepare for loop

; Create main gui
Global $guiMain = GUICreate( GuiTitle(),671,723,-1,-1,BitOr($WS_SIZEBOX,$WS_SYSMENU,$WS_MINIMIZEBOX),-1)
; GUISetIcon(@ScriptDir & "\modem.ico")
#include "Forms\Main.isf"


; Get last remember size ( Note: it doesn't work !)
;~ Local $iWinW = RegRead($gsRegBase, "WinW")	
;~ If Not @error Then
;~ 	Local $iWinH= RegRead($gsRegBase, "WinH")
;~ 	WinMove($guiMain, "", Default , Default , $iWinW, $iWinH )
;~ EndIf 

; Set the last column widths
Global $gsPhoneListWidth = RegRead($gsRegBase, "PhoneListWidth")
If Not @error Then 
	Local $aWidth = StringSplit($gsPhoneListWidth, "|", $STR_NOCOUNT )
	_GUICtrlListView_SetColumnWidth($lvPhoneCalls, 0, Int($aWidth[0]) )
	_GUICtrlListView_SetColumnWidth($lvPhoneCalls, 1, Int($aWidth[1]) )
	_GUICtrlListView_SetColumnWidth($lvPhoneCalls, 2, Int($aWidth[2]) )
	_GUICtrlListView_SetColumnWidth($lvPhoneCalls, 3, Int($aWidth[3]) )
	_GUICtrlListView_SetColumnWidth($lvPhoneCalls, 4, Int($aWidth[4]) )
EndIf
Global $gsRuleListWidth = RegRead($gsRegBase, "RuleListWidth")
If Not @error Then 
	Local $aWidth = StringSplit($gsRuleListWidth, "|", $STR_NOCOUNT )
	_GUICtrlListView_SetColumnWidth($lvRuleList, 0, Int($aWidth[0]) )
	_GUICtrlListView_SetColumnWidth($lvRuleList, 1, Int($aWidth[1]) )
EndIf


GUISetState( @SW_SHOW, $guiMain )

$gsComPort = RegRead($gsRegBase, "ComPort")
If @error Then
	While Not SetModemPort("NEW")
		If MsgBox(4, "Modem's Port not set", 'Do you want to quit the program?') = 6 Then
			AllDone()
		EndIf
	WEnd
Else
	If Not ( SetModemPort($gsComPort) And PortIsOK() ) Then
		While Not SetModemPort("NEW")
			If MsgBox(4, "Modem's Port not set", 'Do you want to quit the program?') = 6 Then
				AllDone()
			EndIf
		WEnd
	EndIf
EndIf

; Load Rule Data
LoadRules()

; Initialize modem settings, put it in voicemode
InitModem()

GetModemInfo()

If @error = 1 Then 
	MsgBox(0, "Error", "Error entering voice mode.")
	AllDone()
EndIf

; Start event mode
Events()

; Set Call Auto monitoring
Local $iAutoStart = RegRead($gsRegBase, "AutoMonitor")
If Not @error And $iAutoStart = 1 Then 
	GUICtrlSetState($chkAutoMonitor, $GUI_CHECKED)
	StartMonitor()
Else
	SetStatus("Not Monitoring...")
EndIf

#EndRegion Declare Main gui and prepare for loop



#Region Main Loop


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
				; c( "start processing line:" & $instr)
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

#EndRegion Main Loop

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
	;  GUISetOnEvent($GUI_EVENT_RESIZED, "RememberSize")  ; It doesn't work properly.
	
	; First Tab Buttons
	GUICtrlSetOnEvent($btnMonitor, "StartMonitor")
	GUICtrlSetOnEvent($btnWhiteList, "RuleAddWhiteList")
	GUICtrlSetOnEvent($btnWarning, "RuleAddWarning")
	GUICtrlSetOnEvent($btnDisconnect, "RuleAddDisconnect")
	GUICtrlSetOnEvent($btnFakeFax, "RuleAddFakeFax")
	GUICtrlSetOnEvent($btnPhoneListClear, "EventPhoneListClear")
	GUICtrlSetOnEvent($btnPhoneListExport, "EventPhoneListExport")

	; GUICtrlSetOnEvent($lvPhoneCalls, "Bingo")
	
	; Rule List Tab Buttons
	GUICtrlSetOnEvent($btnRuleAddAdv, "RuleAddAdv")
	GUICtrlSetOnEvent($btnRuleChange, "RuleChange")
	GUICtrlSetOnEvent($btnRuleDelete, "RuleDelete")
	
	; Setting Tab
    GUICtrlSetOnEvent($btnSetPort, "EventSetPort")
	GUICtrlSetOnEvent($chkAutoMonitor, "SetAutoMonitor")
	GUICtrlSetOnEvent($btnSave, "EventSaveSettings")
	GUICtrlSetOnEvent($comboSpeed, "EventSetSpeed")
	GUICtrlSetOnEvent($btnOpenLog, "EventOpenLog")
	
	; Log Tab
    GUICtrlSetOnEvent($btnSend, "EventSend")
	GUICtrlSetOnEvent($btnClear, "ClearReceived")
	GUICtrlSetOnEvent($btnAbout, "EventAbout")

	; Test functions.
	GUICtrlSetOnEvent($btnTest, "RuleWarning")

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

Func SetStatus($sLine)
	; Up to 4 lines in status
	Local $sText = GUICtrlRead($lbStatus)
	If $sText = "" Then 
		GUICtrlSetData($lbStatus, $sLine)
		Return 
	EndIf
	Local $aText = StringSplit($sText, @CRLF, $STR_ENTIRESPLIT )
	Local $iLines = $aText[0]
	Switch $iLines	; Switch by the count
		Case 1, 2, 3
			GUICtrlSetData($lbStatus, $sText & @CRLF & $sLine)
		Case Else ; 4 or more than 4
			GUICtrlSetData($lbStatus, $aText[$iLines-2] & @CRLF & $aText[$iLines-1] & @CRLF & $aText[$iLines] & @CRLF & $sLine)
	EndSwitch
EndFunc

Func TestLine()
	; Pickup the line then get code.
	AddLine("Doing Test Line...")
	AddLine( "Modem Pickup:" & SendCommand("AT+VLS=5") )	; Modem pick up, Internal speaker connected to the line.
	WaitReceiveLines(30000)
	AddLine( "Modem On Hook:" & SendCommand("AT+VLS=0") )	; Modem off hook
	; AddLine( "Modem Hang Up:" & SendCommand("ATH") )		; Hang up just in case.
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
			; Receive busy signal, the line is disconnected.
			If StringLeft($instr, 2) == $gsCodeBusy Then ExitLoop 
		EndIf
		Sleep(10)
	WEnd
EndFunc


Func ProcessLine($sLine)
	; When doing monitor. The info will come here in lines.
	$sLine = StringStripWS($sLine, 3)	; No leading or trailing white space.
	Const $iRingTimeLimit = 30000		; Ring time limit to 30 seconds.
	c("Line:" & $sLine)
	Static $hLastRingTime = 0		; Initial a static as 0
	Switch $sLine
		Case $gsCodeRing
			; Line is ringing
			If Not $gbRinging Then
				; The ringing just started. Reset the values.
				c("Ring started.")
				$gbRinging = True
				$hLastRingTime = TimerInit()	; Remember the start ringing time.
				; $gbLineProcessed = False
				; Global $gaCurrentCall = ["", "", "", "", ""]
			EndIf
				
		Case $gsCodeBusy
			; Line is busy or disconnected
			$gbRinging = False
			; $gbLineProcessed = False
			Global $gaCurrentCall = ["", "", "", "", ""]
			HangUp()
		
		Case $gsCodeExtPickup, $gsCodeExtHangup
			; Someone pickup the phone or hangup the phone.
			$gbRinging = False 
			$gbLineProcessed = False
			Global $gaCurrentCall = ["", "", "", "", ""]			; Clear the current call.
			InitReceiveFlags()
		
		Case Else
			If $gbRinging Then
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
						c("Current call name:" & $gaCurrentCall[$CALL_NAME] )
						; Now the name is entered. Time to process this phone.
						ProcessCall()
						$gbLineProcessed = True		; This call is processed. The following ring and call id will be ignored.
					Case Else
						c("Not process value on the left:" & GetValueBySep($sLine, $gsCodeCidSep ) )
				EndSwitch
			Else
				c("Not processed. Ringing:" & $gbRinging & " Processed:" & $gbLineProcessed)
			EndIf

	EndSwitch
	
	If $hLastRingTime <> 0 And $gbRinging And TimerDiff($hLastRingTime) > $iRingTimeLimit Then 
		; Ringing flag has been set for too long
		$gbRinging = False 
		$gbLineProcessed = True 
		InitReceiveFlags()
	EndIf

EndFunc

Func ClearReceived()
	GUICtrlSetData($edReceived, "")
EndFunc

Func HangUp()
	; AddLine( "Modem On Hook:" & SendCommand("AT+VLS=0") )	; Modem off hook
	AddLine( "Modem Hang Up:" & SendCommand("ATH") )		; Hang up.
	AddLine( "Back in voice mode:" & SendCommand("AT+FCLASS=8") )		; Set back to voice mode.
	$gbRinging = False
	$gbLineProcessed = False
	Global $gaCurrentCall = ["", "", "", "", ""]			; Clear the current call.
	InitReceiveFlags()
EndFunc

Func ProcessCall()
	; Here will look up the number then process it with rules.
	; The phone info is in $gaCurrentCall[5]
	Local $bRuleFound = False 
	Local $sNumber = $gaCurrentCall[$CALL_NUMBER]
	SetStatus("Incoming Call:" & $sNumber)
	For $i = 0 To UBound($gaRules)-1
		; Have to process the rules one by one
		If PatternFits( $sNumber, $gaRules[$i][$RULE_PATTERN] ) Then 
			SetStatus( "Apply rule:" & $gaRules[$i][$RULE_POLICY] ) 
			ApplyRule($gaRules[$i][$RULE_POLICY])
			$bRuleFound = True
			ExitLoop 
		EndIf
	Next
	If Not $bRuleFound Then
		SetStatus("Apply no rules.")
		ApplyRule("")
	EndIf
EndFunc

Func ApplyRule($sPolicy)
	; Apply rule with the current phone call
	$gaCurrentCall[$CALL_POLICYAPPLIED] = $sPolicy
	$aArray = CallArray2D($gaCurrentCall)
	_GUICtrlListView_AddArray($lvPhoneCalls, $aArray )
	Switch $sPolicy
		Case "Warning"
			RuleWarning()
		Case "Fake Fax"
			RuleFakeFax()
		Case "Disconnect"
			RuleDisconnect()
	EndSwitch
EndFunc

Func CallArray2D(ByRef $aCall)
	; Return a [1][5] 2D array from 1D $aCall
	Local  $aRet[1][5] = [ [ $aCall[0], $aCall[1], $aCall[2], $aCall[3], $aCall[4] ] ]
	Return $aRet
EndFunc

Func PatternFits($sNumber, $sPattern)
	If $sPattern = "" Then Return False 		; No patterns.
	If $sNumber == $sPattern Then Return True 	; Check Exactly first
	
	If StringRight($sPattern, 1) == "*" Then ; Starts with
		If StringLeft($sNumber, StringLen($sPattern)-1) & "*" == $sPattern Then Return True
	ElseIf StringLeft($sPattern, 1) == "*" Then ; Ends with
		If "*" & StringRight($sNumber, StringLen($sPattern) -1) == $sPattern Then Return True
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
		SetStatus("Not Monitoring...")
	Else
		; Not monitoring, start it.
		$gbCallMonitor = True
		GUICtrlSetData($btnMonitor, "Stop Call Monitor")
		SetStatus("Monitoring Calls...")
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

Func EventCallData()
	; Display the call data array for troubleshooting
	_ArrayDisplay($gaCalls)
EndFunc

Func EventRuleData()
	; Display the rule data array for troubleshooting
	_ArrayDisplay($gaRules)
EndFunc

Func EventSetSpeed()
	Local $sSpeed = _GUICtrlComboBox_GetEditText($comboSpeed)
	If $sSpeed = "" Then
		MsgBox(262144,"Please Choose a Speed","Please choose a speed. 9600 is safe while most modems support 119200.",0)
		Return 
	EndIf
	Local $iSpeed = Int($sSpeed)
	If Not StringIsDigit($sSpeed) Or $iSpeed < 9600 Or $iSpeed > 115200 Then 
		MsgBox(262160,"Invalid Speed","The speed you chose is not a valid value.",0)
		Return 
	EndIf
	
	$giComSpeed = $iSpeed
	RegWrite($gsRegBase, "ComSpeed", "REG_DWORD", $iSpeed)
	MsgBox(262160,"New Speed Set","The speed you chose will take effect next time you run this program.",0)

EndFunc

Func EventOpenLog()
	If FileExists($gsAppDir & "\ComLog.txt") Then
		ShellExecute($gsAppDir & "\ComLog.txt")
	Else
		MsgBox(262160,"No log yet","The log file doesn't exist yet.",0, $guiMain)
	EndIf
EndFunc

Func EventPhoneListClear()
	_GUICtrlListView_DeleteAllItems($lvPhoneCalls)
EndFunc

Func EventPhoneListExport()
	$sFile = FileSaveDialog("Save Phone List File", @DocumentsCommonDir, "Comma Seperated Values Files(*.csv)", 0, "Phone List.csv", $guiMain)
	If @error Then 
		MsgBox(262144,"File Not Saved","No file is saved.",0, $guiMain)
		Return 
	EndIf
	
	$hFile = FileOpen($sFile, $FO_OVERWRITE )
	If $hFile = -1 Then 
		MsgBox(262160,"Error Open File","Error trying to write the file:" _
			& @CRLF & $sFile ,0, $guiMain)
		Return 
	EndIf
	; Write headers
	FileWriteLine($hFile, '"Date","Time","Number","Name","Policy Applied"')
	$iCount = _GUICtrlListView_GetItemCount($lvPhoneCalls)
	For $i = 0 To $iCount-1
		; First column
		Local $sRow = Q( _GUICtrlListView_GetItemText($lvPhoneCalls, $i) )
		; The rest
		For $j = 1 To 4
			$sRow &= "," & Q( _GUICtrlListView_GetItemText($lvPhoneCalls, $i, $j) )
		Next
		FileWriteLine($hFile, $sRow)
	Next
	FileClose($hFile)
	
	$hMsgCSV = MsgBox(262164,"File Saved","The CSV file is saved. Do you want to open it?",0, $guiMain)
	If $hMsgCSV = 6 Then 
		; Yes, open the file
		ShellExecute($sFile)
	EndIf

EndFunc

Func Q($str)
	Return '"' & $str & '"'
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
	; Save the column widths to the registry
	$sWidth = _GUICtrlListView_GetColumnWidth($lvPhoneCalls, 0) _ 
		& "|" & _GUICtrlListView_GetColumnWidth($lvPhoneCalls, 1) _
		& "|" & _GUICtrlListView_GetColumnWidth($lvPhoneCalls, 2) _
		& "|" & _GUICtrlListView_GetColumnWidth($lvPhoneCalls, 3) _
		& "|" & _GUICtrlListView_GetColumnWidth($lvPhoneCalls, 4)
	If $sWidth <> $gsPhoneListWidth Then 
		RegWrite($gsRegBase, "PhoneListWidth", "REG_SZ", $sWidth)
	EndIf 
	$sWidth = _GUICtrlListView_GetColumnWidth($lvRuleList, 0) _
		& "|" & _GUICtrlListView_GetColumnWidth($lvRuleList, 1)
	If $sWidth <> $gsRuleListWidth Then 
		RegWrite($gsRegBase, "RuleListWidth", "REG_SZ", $sWidth)
	EndIf
    Exit
EndFunc   ;==>AllDone

Func c($str)
	ConsoleWrite($str & @CRLF)
EndFunc

#EndRegion Functions