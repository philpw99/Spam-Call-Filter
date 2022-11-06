;Disclaimer.au3
; Function Disclaimer()
; Check to see if a disclaimer is needed
; Return true if accepted, false if disagree or close.
; Global: $gsRegBase

Func Disclaimer()
	Local $bAccepted = RegRead($gsRegBase, "DisclaimerAccepted")
	If Not @error and $bAccepted Then Return True 
	
	; Show the disclaimer
	Local $guiDisclaimer = GUICreate("Disclaimer",798,363,-1,-1,-1,-1)
	#include "Forms\Disclaimer.isf"
	
	GUISetState(@SW_SHOW, $guiDisclaimer)
	While True 
		Local $nMsg = GUIGetMsg()
		Switch $nMsg
			Case $btnAgree
				RegWrite($gsRegBase, "DisclaimerAccepted", "REG_DWORD", 1 )
				GUIDelete($guiDisclaimer)
				Return True 
			Case $btnDisagree, $GUI_EVENT_CLOSE
				GUIDelete($guiDisclaimer)
				Return False 
		EndSwitch
		Sleep(20)
	Wend
EndFunc


