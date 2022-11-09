; SetModemPort
; Input: "New" as new selction "COM1" as the port to set.
; Return true when the port is set
; Return false if fails.
Func SetModemPort($sPortName)
	If $sPortName <> "NEW" Then 
		; Set the port then return
		$sErr = SetPort($sPortName)
		If @error Then Return False
		Return True
	EndIf
	
	; Get the list of ports like "COM1|COM2"
	Local $sPortList = _CommListPorts(1)
	If @error = 1 Or $sPortList = "" Then 
		MsgBox(262160,"Error","Cannot find any serial ports. The Modem driver might not installed correctly." _ 
			& @CRLF & "You need to open the 'Device Manager' and find out why.",0, $guiMain)
		Return False 
	ElseIf @error = 2 Then 
		MsgBox(262160,"Error","Cannot find the commg.dll or cannot load commg.dll with the program.",0, $guiMain)
		Return False
	EndIf

	; $guiMain is the parent gui
	$guiSetModemPort = GUICreate("Select Modem's Port",478,341,-1,-1,-1,-1, $guiMain)
	#include "Forms\SetModemPort.isf"

	; Set the port list
	GUICtrlSetData($comboPort, $sPortList, "")
	
	GUISetState(@SW_SHOW, $guiSetModemPort)
	While True
		Local $nMsg = GUIGetMsg()
		Switch $nMsg
			Case $btnOK
				With $oModem
					If .Count = 0 Then 
						MsgBox(262160,"No Valid Modem Yet","Seems you haven't choose a valid serial port for the modem yet.",0, $guiSetModemPort)
						ContinueLoop 
					EndIf
					If .Item("VoiceMode") <> "Supported" Then 
						MsgBox(262192,"Voice mode not supported","This modem doesn't support voice mode, which is necessary to get caller IDs." & @CRLF & "The program will not work without caller id working.",0, $guiSetModemPort)
						ContinueLoop 
					EndIf
					; OK, finally all is good. Remember it in registry.
					RegWrite($gsRegBase, "ComPort", "REG_SZ", .Item("Port") )
				EndWith
				GUIDelete($guiSetModemPort)
				Return True
			Case $comboPort
				Local $sPort = GUICtrlRead($comboPort)
				$sResult = SetPort($sPort)
				If $sResult <> "OK" Then 
					MsgBox(262160,"Error With Serial Port " & $sPort,"Error Number: " & @error _ 
						& @CRLF & "Message: " & $sResult,0, $guiSetModemPort)
					; clear the combo box
					_GUICtrlComboBox_SetEditText($comboPort, "")
					$oModem.RemoveAll()
					GUICtrlSetData($edPortStatus, "Choose a port above.")
					ContinueLoop 
				EndIf
				; Port is set, time to do the test.
				$sResult = SendCommand("AT")
				If Not EndWithOK($sResult) Then
					MsgBox(262160,"Not A Modem","Seems this is not a valid serial port for a modem." _ 
						& @CRLF & "Reply: " & $sResult,0, $guiSetModemPort)
					; clear the combo box
					_GUICtrlComboBox_SetEditText($comboPort, "")
					$oModem.RemoveAll()
					GUICtrlSetData($edPortStatus, "Choose a port above.")
					ContinueLoop 
				EndIf
				GetModemInfo()
				With $oModem
					GUICtrlSetData($edPortStatus, "Port: " & $sPort & @CRLF & "Manufacturer: " & .Item("Manufacturer") & @CRLF _
						& "Product: " & .Item("ProductID") & @CRLF & "Version: " & .Item("Version") & @CRLF & "Voice Mode: " & .Item("VoiceMode") )
				EndWith
				
				; Replied with AT. Now find out the model, id... etc
			Case $btnCancel, $GUI_EVENT_CLOSE
				GUIDelete($guiSetModemPort)
				Return False 
		EndSwitch
		Sleep(20)
	Wend
	
EndFunc

Func GetModemInfo()
	; Make sure the port is opened before calling this
	; This will either fill the $oModem with info,
	; Or it will delete all existing info if port is not opened.
	$sPort = _CommPortConnection()
	If $sPort = "" Then
		$oModem.RemoveAll()
		Return SetError(1)
	Else 
		; Set the COM port text
		GUICtrlSetData($lblComPort, $sPort )
	EndIf
	
	AddLine("Port: " & $sPort & " is connected.")
	Local $sResult = ""

	With $oModem
		.Item("Port") = $sPort
		.Item("Manufacturer") = GetLine( SendCommand("AT+FMI?"), 1 )
		.Item("ProductID") = GetLine( SendCommand("AT+FMM?"), 1 )
		.Item("Version") = GetLine( SendCommand("AT+FMR?"), 1 )
		Local $sVoiceClass = GetLine( SendCommand("AT+FCLASS=?"), 1)
		.Item("VoiceMode") = ( StringInStr($sVoiceClass, ",8", 1) = 0 ? "Not Supported" : "Supported") 
		
		AddLine("Modem Port: " & .Item("Port") )
		AddLine("Modem Manufacturer: " & .Item("Manufacturer") )
		AddLine("Modem Product ID: " & .Item("ProductID") )
		AddLine("Modem Version: " & .Item("Version") )
		AddLine("Voice Mode: " & .Item("VoiceMode") )
	EndWith 
	
EndFunc

Func GetLine($str, $iLineNumber)
	; return the line you want from text
	If $iLineNumber < 1 Then Return ""
	
	Local $iPosStart, $iPosEnd
	If $iLineNumber = 1 Then 
		$iPosStart = 1
		$iPosEnd = StringInStr($str, @CR, 0, 1)
		If $iPosEnd = 1 Then Return ""	; The first line is empty
		If $iPosEnd = 0 Then $iPosEnd = StringLen($str) + 1	; No @CR in the end
	Else
		$iPosStart = StringInStr($str, @CR, 1, $iLineNumber-1)
		If $iPosStart = 0 Then Return ""	; $iLineNumber too big
		$iPosEnd = StringInStr($str, @CR, 1, 1, $iPosStart + 1)
		if $iPosEnd = 0 Then $iPosEnd = StringLen($str) + 1	; Last line and no @CR in the end
	EndIf
	
	Return StringStripCR( StringMid($str, $iPosStart, $iPosEnd-$iPosStart) )

EndFunc

Func EndWithOK($str)
	If StringRight($str, 2) = "OK" Or StringRight($str, 3) = "OK" & @CR Then
		Return True
	Else
		Return False 
	EndIf
EndFunc

Func SetPort($sPort)
	; Input: string like "COM1" or just "1"
	; Output: "OK" if success
	; 	Fail then return error number and return the error message
	Local $iPort = 0
	If StringLeft($sPort, 3) = "COM" Then 
		; "COM1"
		$iPort = Int(StringMid($sPort, 4))
	Else
		; "1"
		$iPort = Int($sPort)
	EndIf
	Local $sErr = ""
	Local $iErr = _CommSetport($iPort, $sErr, $giComSpeed) 
	; The rest is all default: $iBaud=9600,$iBits=8,$ipar=0,$iStop=1,$iFlow=0,$RTSMode = 0,$DTRMode = 0
	If $iErr = 1 Then Return "OK"
	Return SetError($iErr, 0, $sErr)
EndFunc

Func InitModem()
	; Initialize modem settings.
	SendCommand("ATZ")	; Soft reset the modem to default profile
	SendCommand("ATE0")	; Disable command echo
	SendCommand("ATX7")	; Set get basic result codes with dial tone AND busy detection
	; Set Xon Xoff values
	; _CommSetXonXoffProperties(11, 13, 100, 100)
	; SendCommand("ATV1")	; Set verbose response
	SendCommand("ATS0=0")	; Disable auto answering (just in case)
	SendCommand("AT+VCID=1")	; Enable caller ID
	AddLine( "Entering Voice Mode:" & SendCommand("AT+FCLASS=8") )	; Enter voice mode
	SendCommand("AT+VTD=20")	; Set DTMF dial tone duration. Reg is 85, too long.
	SetStatus("Modem is ready.")
EndFunc

Func GetPara($sResult, $sPara)
	; Get the S0, S1... value from the AT&V command result
	Local $iPos1 = StringInStr($sResult, $sPara ) 
	If $iPos1 = 0 Then Return ""
	$iPos2 = StringInStr($sResult, " ", 2, 1, $iPos1 + 1)
	Return StringStripWS(StringMid($sResult, $iPos1, $iPos2-$iPos1), 2)
EndFunc

