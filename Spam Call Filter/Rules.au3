;Rules.au3
; Should be all functions

Func LoadRules()
	; Global $gaRules
	Local $hFile = FileOpen($gsAppDir & "\rules.txt", $FO_READ )
	If @error then
		c("error loading rules.txt")
		Return SetError(1)
	EndIf
	ReDim $gaRules[0][2]	; clear the array
	Local $i = 0
	While True 
		Local $sLine = FileReadLine($hFile)
		If @error Then ExitLoop ; End of file
		$i += 1
		Redim $gaRules[$i][2]
		$gaRules[$i-1][$RULE_PATTERN] = GetValueBySep($sLine, "|", 1)
		$gaRules[$i-1][$RULE_POLICY] = GetValueBySep($sLine, "|", 2)
	Wend
	FileClose($hFile)
	; delete all items then add them back.
	If _GUICtrlListView_GetItemCount($lvRuleList) > 0 Then 
		_GUICtrlListView_DeleteAllItems($lvRuleList)
	EndIf 
	_GUICtrlListView_AddArray($lvRuleList, $gaRules)
	$giCurrentRuleIndice = ""
EndFunc

Func SetCurrentRule($iRow)
	; get the rule from the list and set the control
	If $iRow = "" Then 
		GUICtrlSetState($radPatternStart, $GUI_UNCHECKED )
		GUICtrlSetState($radPatternEnd, $GUI_UNCHECKED )
		GUICtrlSetState($radPatternExactly, $GUI_UNCHECKED )
		GUICtrlSetData($inpPattern, "")
		GUICtrlSetState($radPolicyWhiteList, $GUI_UNCHECKED )
		GUICtrlSetState($radPolicyWarning, $GUI_UNCHECKED )
		GUICtrlSetState($radPolicyDisconnect, $GUI_UNCHECKED )
		GUICtrlSetState($radPolicyFakeFax, $GUI_UNCHECKED )
		GUICtrlSetState($radPolicyPhilip, $GUI_UNCHECKED )
	Else
		Local $sPattern = _GUICtrlListView_GetItemText($lvRuleList, Int($iRow))
		Local $sPolicy = _GUICtrlListView_GetItemText($lvRuleList, Int($iRow), 1)
		; Set pattern
		Select 
			Case StringRight($sPattern, 1) = "*"	; Starts with...
				GUICtrlSetState($radPatternStart, $GUI_CHECKED )
				GUICtrlSetData($inpPattern, StringMid($sPattern, 2))
			Case StringLeft($sPattern, 1) = "*"		; Ends with ...
				GUICtrlSetState($radPatternEnd, $GUI_CHECKED )
				GUICtrlSetData($inpPattern, StringLeft($sPattern, StringLen($sPattern) -1))
			Case Else								; Exactly
				GUICtrlSetState($radPatternExactly, $GUI_CHECKED )
				GUICtrlSetData($inpPattern, $sPattern)
		EndSelect
		
		; Set Policy
		Switch $sPolicy
			Case "White List"
				GUICtrlSetState($radPolicyWhiteList, $GUI_CHECKED )
			Case "Warning"
				GUICtrlSetState($radPolicyWarning, $GUI_CHECKED )
			Case "Fake Fax"
				GUICtrlSetState($radPolicyFakeFax, $GUI_CHECKED )
			Case "It's Philip"
				GUICtrlSetState($radPolicyPhilip, $GUI_CHECKED )
			Case Else 
				GUICtrlSetState($radPolicyNone, $GUI_CHECKED )
		EndSwitch
	EndIf
	
EndFunc

Func SetCurrentNumber($iRow)
	If $iRow = "" Then
		GUICtrlSetData($inpNumber, "")
	Else
		GUICtrlSetData($inpNumber, _GUICtrlListView_GetItemText($lvPhoneCalls, Int($iRow), 1) )
	EndIf
EndFunc

Func RuleAdd($sRule)
	; Add a new rule to the end
	Local $sNumber = GUICtrlRead($inpNumber)
	If $sNumber = "" Then
		MsgBox(262208,"Number is empty","Please enter the telephone number like '18881234567' into the blanket above.",0, $guiMain)
		Return
	EndIf
	If Not NumberIsValid($sNumber) Then 
		$hMsgPhone = MsgBox(262193,"Invalid Telephone Number","The telephone number should be 11 digits like '18881234567'." _ 
			& @CRLF & "If you are not in the US and use your own format of number, you can click on 'OK' to continue." _ 
			& @CRLF & "Otherwise, pleae click on 'Cancel' to try it again.",0, $guiMain)
		If $hMsgPhone = 2 Then Return 	; Cancel
	EndIf
	
	_ArrayAdd($gaRules, $sNumber& "|" & $sRule)	; Add new rule to the end
	; Add new rule to the end of the rule list
	Local $iItem = _GUICtrlListView_AddItem($lvRuleList, $sNumber)
	_GUICtrlListView_SetItemText($lvRuleList, $sRule, $iItem, 1)
	SaveRuleList()
	
	MsgBox(262208,"Rule Saved","The new rule is successfully saved.",0, $guiMain)

EndFunc

Func RuleAddWhiteList()
	; Insert the white list from the top
	Local $sNumber = GUICtrlRead($inpNumber)
	If $sNumber = "" Then
		MsgBox(262208,"Number is empty","Please enter the telephone number like '18881234567' into the blanket above.",0, $guiMain)
		Return
	EndIf
	If Not NumberIsValid($sNumber) Then 
		$hMsgPhone = MsgBox(262193,"Invalid Telephone Number","The telephone number should be 11 digits like '18881234567'." _ 
			& @CRLF & "If you are not in the US and use your own format of number, you can click on 'OK' to continue." _ 
			& @CRLF & "Otherwise, pleae click on 'Cancel' to try it again.",0, $guiMain)
		If $hMsgPhone = 2 Then Return 	; Cancel
	EndIf
	_ArrayInsert($gaRules, 1, $sNumber & "|White List")		; Insert new values above the first row
	; Insert row in the rules list view as well.
	_GUICtrlListView_InsertItem($lvRuleList, $sNumber, 0 )
	_GUICtrlListView_SetItemText($lvRuleList, "White List", 0, 1)
	SaveRuleList()
	MsgBox(262208,"Rule Saved","The new rule is successfully saved.",0, $guiMain)
EndFunc

Func RuleAddWarning()
	RuleAdd("Warning")
EndFunc

Func RuleAddDisconnect()
	RuleAdd("Disconnect")
EndFunc

Func RuleAddFakeFax()
	RuleAdd("Fake Fax")
EndFunc

Func RuleAddPhilip()
	RuleAdd("It's Philip")
EndFunc

Func SaveRuleList()
	Local $hFile = FileOpen($gsAppDir & "\rules.txt", $FO_OVERWRITE )
	If @error then
		c("Error opening to write rules.txt.")
		Return SetError(1)
	EndIf
	For $i = 0 To UBound($gaRules)-1
		FileWriteLine($hFile, $gaRules[$i][$RULE_PATTERN] & "|" & $gaRules[$i][$RULE_POLICY])
	Next
	FileClose($hFile)
EndFunc

Func NumberIsValid($sNumber)
	If stringleft($sNumber, 1) <> "1" Then Return False
	If StringLen($sNumber) <> 11 Then return False 
	Return StringIsDigit($sNumber)
EndFunc

Func RuleFakeFax( )
	$iTimeLimit = 30000		; 30 seconds
	; This one will pickup the phone and pretend to be a fax machine.
	; Assume it's already in voice mode
	AddLine("Doing Fake Fax...")
	SendCommand("AT+FCLASS=1") 	; Get in fax mode
	AddLine( "Modem Answer:" & SendCommand("ATA"))			; Answer
	WaitReceiveLines($iTimeLimit)	; Wait 30 seconds to receive any thing.
	HangUp()
	SendCommand("AT+FCLASS=8") 	; Get back to voice mode
EndFunc

Func RuleDisconnect( )
	$iTimeLimit = 20000		; 20 Seconds
	; This one will pickup, wait for time limit, then just disconnect
	AddLine("Doing Disconnect...")
	AddLine( "Modem Pickup:" & SendCommand("AT+VLS=5") )	; Modem pick up, Internal speaker connected to the line.
	WaitReceiveLines($iTimeLimit)
	HangUp()
EndFunc

Func RuleIsPhilip()
	; Play voice.
	$iTimeLimit = 30000		; 30 seconds
	AddLine("Doing It's Philip ...")
	AddLine( "Modem Pickup: " & SendCommand("AT+VLS=5") )	; Modem pick up, Internal speaker connected to the line.
	
	PlayWav( @ScriptDir & "\out.wav")
	WaitReceiveLines(5000) ; Wait 5 seconds for other side to start talking.
	; WaitForSilence()	; Now let the other side talk.  It's bad. Wait too long.
	
	HangUp()
EndFunc

Func WaitForSilence($iTimeOut = 30000)
	; Enter voice recording mode
	AddLine("Switch to Voice Recording mode:" & SendCommand("AT+VRX") )
	AddLine("Wait for silence.")
	; Read input for underbuffer
	Local $hTimer = TimerInit()
	While TimerDiff($hTimer) < $iTimeOut
		$instr = _Commgetstring()
		If $instr <> "" Then
			$str = StringLeft($instr, 2)
			If $str = $gsCodeBusy Then return
		EndIf
		Sleep(20)
	Wend	
EndFunc
