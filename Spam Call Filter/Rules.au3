;Rules.au3
; Should be all functions

Func RuleFakeFax( )
	$iTimeLimit = 30000		; 30 seconds
	; This one will pickup the phone and pretend to be a fax machine.
	; Assume it's already in voice mode
	AddLine("Doing Fake Fax...")
	SendCommand("AT+FCLASS=1") 	; Get in fax mode
	AddLine( "Modem Answer:" & SendCommand("ATA"))			; Answer
	WaitReceiveLines($iTimeLimit)	; Wait 30 seconds to receive any thing.
	AddLine("Hangup:" & SendCommand("ATH") ) ; Hang up
	SendCommand("AT+FCLASS=8") 	; Get back to voice mode
EndFunc

Func RuleDisconnect( )
	$iTimeLimit = 20000		; 20 Seconds
	; This one will pickup, wait for time limit, then just disconnect
	AddLine("Doing Disconnect...")
	AddLine( "Modem Pickup:" & SendCommand("AT+VLS=5") )	; Modem pick up, Internal speaker connected to the line.
	WaitReceiveLines($iTimeLimit)
	AddLine( "Modem On Hook:" & SendCommand("AT+VLS=0") )	; Modem off hook
	AddLine( "Modem Hang Up:" & SendCommand("ATH") )		; Hang up just in case.
EndFunc

Func RuleIsPhilip()
	; Play voice.
	$iTimeLimit = 30000		; 30 seconds
	AddLine("Doing It's Philip ...")
	AddLine( "Modem Pickup: " & SendCommand("AT+VLS=5") )	; Modem pick up, Internal speaker connected to the line.
	
	PlayWav( @ScriptDir & "\out.wav")
	WaitReceiveLines(5000) ; Wait 5 seconds for other side to start talking.
	WaitForSilence()	; Now let the other side talk.
	
	AddLine( "Modem On Hook:" & SendCommand("AT+VLS=0") )	; Modem off hook
	AddLine( "Modem Hang Up:" & SendCommand("ATH") )		; Hang up just in case.

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
			If $str = Chr(16) & Chr(3) Or $str = Chr(16) & "b" Then return
		EndIf
		Sleep(20)
	Wend	
EndFunc
