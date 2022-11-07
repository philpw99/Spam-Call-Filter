Func SaveSettings()
	; Save all settings in "Settings" tab
	; Com port is saved immediately.
	; RegWrite($gsRegBase, "ComPort", "REG_SZ", GUICtrlRead($lblComPort))
	; For now, it should save only the modem codes
	RegWrite($gsRegBase, "CodeRing", "REG_SZ", Guictrlread($inpCodeRing))
	RegWrite($gsRegBase, "CodeDialTone", "REG_SZ", Guictrlread($inpCodeDialTone))
	RegWrite($gsRegBase, "CodeBusy", "REG_SZ", Guictrlread($inpCodeBusy))
	RegWrite($gsRegBase, "CodeUnderBuffer", "REG_SZ", Guictrlread($inpCodeUnderBuffer))
	RegWrite($gsRegBase, "CodeCidDate", "REG_SZ", Guictrlread($inpCodeCidDate))
	RegWrite($gsRegBase, "CodeCidTime", "REG_SZ", Guictrlread($inpCodeCidTime))	
	RegWrite($gsRegBase, "CodeCidNumber", "REG_SZ", Guictrlread($inpCodeCidNumber))
	RegWrite($gsRegBase, "CodeCidName", "REG_SZ", Guictrlread($inpCodeCidName))
	RegWrite($gsRegBase, "CodeCidSep", "REG_SZ", Guictrlread($inpCodeCidSep))
	; Now load the codes
	InitCodes()
	
	MsgBox(262208,"Settings Saved","All the settings are saved. They are taking effects immediately.",0, $guiMain)
EndFunc

Func SetSaveLog()
	If GUICtrlRead($chkSaveLog) = $GUI_CHECKED Then 
		RegWrite($gsRegBase, "SaveLog", "REG_DWORD", 1)
		$gbSaveLog = True
	Else
		RegWrite($gsRegBase, "SaveLog", "REG_DWORD", 0)
		$gbSaveLog = False
	EndIf
EndFunc


Func SetAutoMonitor()
	If GUICtrlRead($chkAutoMonitor) = $GUI_CHECKED Then 
		RegWrite($gsRegBase, "AutoMonitor", "REG_DWORD", 1)
	Else
		RegWrite($gsRegBase, "AutoMonitor", "REG_DWORD", 0)
	EndIf
EndFunc
