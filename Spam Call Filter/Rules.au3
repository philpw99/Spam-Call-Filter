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
;~ 		GUICtrlSetState($radPatternStart, $GUI_UNCHECKED )
;~ 		GUICtrlSetState($radPatternEnd, $GUI_UNCHECKED )
;~ 		GUICtrlSetState($radPatternExactly, $GUI_UNCHECKED )
;~ 		GUICtrlSetData($inpPattern, "")
;~ 		GUICtrlSetState($radPolicyWhiteList, $GUI_UNCHECKED )
;~ 		GUICtrlSetState($radPolicyWarning, $GUI_UNCHECKED )
;~ 		GUICtrlSetState($radPolicyDisconnect, $GUI_UNCHECKED )
;~ 		GUICtrlSetState($radPolicyFakeFax, $GUI_UNCHECKED )
;~ 		GUICtrlSetState($radPolicyPhilip, $GUI_UNCHECKED )
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
	_GUICtrlListView_SetItemText($lvRuleList, $iItem, $sRule, 1)
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
	_GUICtrlListView_SetItemText($lvRuleList, 0, "White List", 1)
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

Func GetCurrentRule()
	; Return as string "pattern|policy"
	; This is the rule add button in the second tab
	Local $sNumber = guictrlread($inpPattern)
	If $sNumber = "" Then 
		MsgBox(262192,"Pattern number cannot be empty","The pattern number cannot be empty.",0, $guiMain)
		Return SetError(1)
	EndIf
	; Select pattern
	Select 
		Case Check($radPatternStart)
			$sNumber &= "*"
		Case Check($radPatternEnd)
			$sNumber = "*" & $sNumber
		Case Check($radPatternExactly)
			; Do nothing here
		Case Else
			; Not select one at all.
			MsgBox(262192,"Choose one way for the pattern.","You have to choose either 'start with', 'end with' or 'exactly'",0, $guiMain)
			Return SetError(1)
	EndSelect
	; Select policy
	Local $sPolicy = ""
	Select
		Case Check($radPolicyWhiteList)
			$sPolicy = "White List"
		Case Check($radPolicyNone)
			$sPolicy = ""
		Case Check($radPolicyWarning)
			$sPolicy = "Warning"
		Case Check($radPolicyDisconnect)
			$sPolicy = "Disconnect"
		Case Check($radPolicyFakeFax)
			$sPolicy = "Fake Fax"
		Case Else
			; Not select the policy yet
			MsgBox(262192,"Choose one policy","You have to choose one of the policy.",0, $guiMain)
			Return SetError(1)
	EndSelect
	Return $sNumber & "|" & $sPolicy
EndFunc 
	
Func RuleAddAdv()
	Local $sRule = GetCurrentRule()
	If @error Then Return 
	
	$sNumber = GetValueBySep($sRule, "|")
	$sPolicy = GetValueBySep($sRule, "|", 2)
	
	If $sPolicy = "White List" Then
		; Add it to the top
		_ArrayInsert($gaRules, 1, $sNumber & "|" & $sPolicy)		; Insert new values above the first row
		; Insert row in the rules list view as well.
		_GUICtrlListView_InsertItem($lvRuleList, $sNumber, 0 )
		_GUICtrlListView_SetItemText($lvRuleList, 0, $sPolicy, 1)
	Else
		; Add it to the end.
		_ArrayAdd($gaRules, $sNumber& "|" & $sPolicy)	; Add new rule to the end
		; Add new rule to the end of the rule list
		Local $iItem = _GUICtrlListView_AddItem($lvRuleList, $sNumber)
		; _GUICtrlListView_AddSubItem($lvRuleList, $iItem, $sPolicy, 1)
		_GUICtrlListView_SetItemText($lvRuleList, $iItem, $sPolicy, 1)
	EndIf 
	SaveRuleList()
EndFunc

Func RuleChange()
	; This is for second tab rule change button
	Local $iRow = _GUICtrlListView_GetSelectedIndices($lvRuleList)
	; c("Row selected to bechanged:" & $iRow)
	If $iRow = "" Then 
		MsgBox(262192,"Choose a Rule","You need to choose a rule from the list on the left first.",0, $guiMain)
		Return 
	EndIf
	Local $sRule = GetCurrentRule()
	If @error Then Return 
	
	$sPattern = GetValueBySep($sRule, "|")
	$sPolicy = GetValueBySep($sRule, "|", 2)
	$gaRules[$iRow][$RULE_PATTERN] = $sPattern
	$gaRules[$iRow][$RULE_POLICY] = $sPolicy
	_GUICtrlListView_SetItemText($lvRuleList, $iRow, $sPattern)
	_GUICtrlListView_SetItemText($lvRuleList, $iRow, $sPolicy, 1)
	SaveRuleList()
EndFunc

Func RuleDelete()
	; This is for second tab rule delete button
	Local $iRow = _GUICtrlListView_GetSelectedIndices($lvRuleList)
	; MsgBox(0, "row", "Row selected:" & $iRow)
	If $iRow = "" Then 
		MsgBox(262192,"Choose a Rule","You need to choose a rule from the list on the left first.",0, $guiMain)
		Return 
	EndIf
	_ArrayDelete($gaRules, $iRow)
	_GUICtrlListView_DeleteItem($lvRuleList, $iRow)
	SaveRuleList()
EndFunc

Func Check($hControl)
	Return GuiCtrlRead($hControl) = $GUI_CHECKED
EndFunc

Func NotCheck($hControl)
	Return GuiCtrlRead($hControl) = $GUI_UNCHECKED
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
	AddLine("Doing Policy Fake Fax...")
	SendCommand("AT+FCLASS=1") 	; Get in fax mode
	AddLine( "Modem Answer:" & SendCommand("ATA"))			; Answer
	WaitReceiveLines($iTimeLimit)	; Wait 30 seconds to receive any thing.
	HangUp()
	SendCommand("AT+FCLASS=8") 	; Get back to voice mode
EndFunc

Func RuleDisconnect( )
	$iTimeLimit = 20000		; 20 Seconds
	; This one will pickup, wait for time limit, then just disconnect
	AddLine("Doing Policy Disconnect...")
	AddLine( "Modem Pickup:" & SendCommand("AT+VLS=1") )	; Modem pick up.
	; Just silence
	WaitReceiveLines($iTimeLimit)
	HangUp()
EndFunc

Func RuleWarning()
	; Play voice.
	AddLine("Doing Policy Warning ...")
	AddLine( "Modem Pickup: " & SendCommand("AT+VLS=1") )	; Modem pick up.
	InitReceiveFlags()
	PlayWav8bitUnsigned( @ScriptDir & "\Warning.wav")
	AddLine("Back to the rule.")
	WaitReceiveLines(5000) ; Wait 5 seconds for other side to start talking.
	HangUp()
EndFunc

Func WaitForSilence()
	$iTimeOut = 10000
	; Enter pick up mode
	AddLine("Enter modem pickup mode:" & SendCommand("AT+VLS=1") )
	AddLine("Set compression:" & SendCommand("AT+VSM=1") )
	; Enter voice recording mode
	; AddLine("Switch to Voice Recording mode:" & SendCommand("AT+VRX") )
	; AddLine("Wait for silence.")
	_CommSendString("AT+VRX" & @CR)

	InitReceiveFlags()				; Reset all receive global flags

	$iBufferSize = 80001				; Voice data in 10 second.
	Local $aData[$iBufferSize]	
	Local $iThreshold = 50 * 8000	; average data is below 50
	Local $iTotalCount = 0			; iTotalCount is count of all the data received
	Local $iPos = 0					; iPos is the current position in the data array.
	Local $iTotal = 0				; iTotal is the voice data numeric total.
	Local $hTimer = TimerInit()
	Local $iMax = 0
	While TimerDiff($hTimer) < $iTimeOut
		Local $sPiece = _Commgetstring()
		If $sPiece <> "" Then
			; Convert to numbers in batch
			Local $aPiece = StringToASCIIArray($sPiece, Default , Default , 1 )
			Local $iLen = UBound($aPiece)
			Local $i = -1		; $i is the position in $aPiece
			While True 
				; Loop through all numbers
				$i += 1		
				If $i >= $iLen Then ExitLoop 
				If $aPiece[$i] = Chr(16) Then 
					Switch $aPiece[$i + 1]
						Case 16		; double Chr(16) count as a single Chr(16)
							$i += 1
						Case 26		; 26 means 2 chr(16), so annoying, just count as one chr(16) to simplify things
							$i += 1
							$aPiece[$i] = Chr(16)
						Case 35, 42, 48 to 57 	; DTMF tones
							$gfKeyPressed = True 
							$gsKeyPressed &= Chr($aPiece[$i+1])
							$i += 2		; skip those 2 char
							c(Chr(16) & $aPiece[$i + 1])
						Case 111		; Buffer overrun
							$gfBufferOverrun = True 
							$i += 2
							c(Chr(16) & $aPiece[$i + 1])
						Case 108, 113, 115	; Time out or hung up
							$gfHangUp = True 
							$i += 2
							c(Chr(16) & $aPiece[$i + 1])
						Case 114			; Ringing ? ?
							$gfRing = True 
							$i += 2
							c(Chr(16) & $aPiece[$i + 1])
						Case 98				; Busy tone, maybe hung up
							$gfBusy = True
							$i += 2
							c(Chr(16) & $aPiece[$i + 1])
						Case 100			; Dial tone
							$gfDialTone = True
							$i += 2
							c(Chr(16) & $aPiece[$i + 1])
						Case 117			; Buffer underrun
							$gfBufferUnderrun = True
							$i += 2
							c(Chr(16) & $aPiece[$i + 1])
						Case Else 			; Don't care
							$i += 2
					EndSwitch
				EndIf
				
				; Finish filtered out special commands
				Local $iChar = $aPiece[$i] 
				$iChar = Abs($iChar - 128)	; For signed PCM signal
				If $iChar > $iMax Then $iMax = $iChar
				$iTotalCount += 1
				If $iTotalCount >= $iBufferSize Then 
					$iPos = Mod( $iTotalCount, $iBufferSize)
					$iTotal = $iTotal - $aData[$iPos] + $iChar		; Remove the last queue and add the new one
					$aData[$iPos] = $iChar			; Set the new data
				Else 
					; buffer not filled yet
					$iPos = $iTotalCount
					$iTotal += $iChar
					$aData[$iPos] = $iChar
				EndIf
				
			Wend
			
		EndIf
	Wend
	_CommSendByte(16)
	_CommSendByte(33) ; receive abort.
	AddLine("modem on hook:" & SendCommand("AT+VLS=0") )
	HangUp()
	c("total byte:" & $iTotalCount)
	Local $dAverage
	If $iTotalCount > $iBufferSize Then 
		$dAverage = $iTotal / $iBufferSize
	Else 
		$dAverage = $iTotal / $iTotalCount
	EndIf
	c("Average value in buffer:" & $dAverage)
	c("Max char value:" & $iMax)
EndFunc


