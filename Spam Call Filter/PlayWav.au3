Func PlayWav8bitUnsigned($sFile)
	Local $NULL
	If Not FileExists($sFile) Then Return SetError(1)
	Local $WAVE_HEADER = GetWaveHeader($sFile)

	If Not VerifyWaveFormat( $WAVE_HEADER, 8, 8000, 1 )	Then ; 8bit 8000hz, mono
		MsgBox(48,"Wrong Wav Format","This audio file should be a 8bit 8000hz mono unsigned PCM wav file.",0, $guiMain)
		Return SetError(1)
	EndIf
	
	Local $iSize = DllStructGetData($WAVE_HEADER, "Subchunk2Size")	; Get the bytes of raw data.
	c("Wave data size:" & $iSize)

	; Create the buffer for the raw audio data
	; Since this implemenetion is made for 8 bit wav files each sample is 8 bit (1 bytes) thus each element is a byte(8 bit).
	; Subchunk2Size shows the total bytes for the raw data.
	; Amount of samples is calculated with the total size of the raw audio data divided by the size of each sample
	$Data = DllStructCreate("byte [" & ( DllStructGetData($WAVE_HEADER, "Subchunk2Size") ) & "]")
	$lpData = DllStructGetPtr($Data)
	; c("lpData:" & Hex($lpData))

	; Open the file again to read all data.
	$fhandle = _WinAPI_CreateFile($sFile, 2, 2, 2)

	_WinAPI_ReadFile($fhandle, $lpData, DllStructGetData($WAVE_HEADER, "Subchunk2Size"), $NULL)

	; No more reading, the entire file is in memory!
	_WinAPI_CloseHandle($fhandle)

	; Now prepare the modem and send the raw data over
	; Should be off hook before this.
	AddLine( "Set Voice Compression to 1: " & SendCommand("AT+VSM=1") )	; 8bit Unsigned PCM, 8000hz, mono
	AddLine( "In Voice Transmit Mode: " & SendCommand("AT+VTX") )
	
	_CommClearOutputBuffer()
	
	AddLine("Start playing file:" & $sFile)
	
	; Clear transmit buffer
	_CommSendByte(16)
	_CommSendByte(24)
	
	Local $iTransferSize = 1024
	; Transmit 1024 bytes at a time. The buffer is 2048 only.
	If $iSize <= $iTransferSize Then 
		SendData8Bit( $lpData, $iSize )
		; _CommSendByteArray($lpData, $iSize, 0)
		If @error Then c("Error sending data.")
	Else
		For $i = 0 To Floor($iSize / $iTransferSize )
			SendData8Bit( $lpData )	; Send 1024 data at a time
			; _CommSendByteArray($lpData, 1024, 0)
			If @error Then
				c("Error sending data when i=" & $i)
				ExitLoop
			EndIf
			$lpData += $iTransferSize
			WaitForUnderBuffer()
			If $gfBusy Or $gfDialTone Or $gfHangUp Then
				; Send end signal
				_CommSendByte(16)
				_CommSendByte(3)
				AddLine("Voice transmission interrupted by busy, dialtone or hangup.")
				Return 
			EndIf
		Next
		; _CommSendByteArray($lpData, Mod ($iSize, 1024) , 0)
		SendData8Bit( $lpData, Mod ($iSize, $iTransferSize) )	; Send the rest of data.
		If @error Then c("Error sending data at the last batch." )
	EndIf
	
	; Send end signal
	_CommSendByte(16)
	_CommSendByte(3)
	
	AddLine( "Voice transmission done.")
EndFunc

Func VerifyWaveFormat($WaveHeader, $BitsPerSample, $SampleRate, $Channels, $iAudioFormat = 1 )
	; Before we read the heavy stuff, lets check if the data is what we expect
	; AudioFormat = 1 means PCM uncompressed.
	If Not (DllStructGetData($WaveHeader, "Format") == "WAVE") Then; All wav files should have the Format set to WAVE
		c("Error, This is not a valid wav file!")
		Return SetError(1, 0, False )
	EndIf

	If DllStructGetData($WaveHeader, "AudioFormat") <> $iAudioFormat Then; 1 means PCM (raw audio data) which is the only thing supported
		c("Error. This is wav file format is not " & $iAudioFormat)
		Return SetError(2, 0, False )
	EndIf 


	If DllStructGetData($WaveHeader, "BitsPerSample") <> $BitsPerSample Then
		c("Error. This is wav file has a sample size error:" & DllStructGetData($WaveHeader, "BitsPerSample"))
		Return SetError(3, 0, False)
	EndIf

	If (DllStructGetData($WaveHeader, "SampleRate") <> $SampleRate ) Then; All wav files should have the Format set to WAVE
		c("Error, This wav file has wrong sample rate: " & DllStructGetData($WaveHeader, "SampleRate"))
		Return SetError(4, 0,  False )
	EndIf

	If (DllStructGetData($WaveHeader, "NumChannels") <> $Channels ) Then; All wav files should have the Format set to WAVE
		c("Error, This wav file has wrong channel number!")
		Return SetError(5, 0,  False )
	EndIf

	Return True
EndFunc

Func PlayWav16to8Signed($sFile)
	
	; This func will play a 16bit, 8000hz mono file to 8bit 8000hz mono Signed channel
	; This way the sound quality should be better.
	; Too bad this function doesn't work.
	Local $NULL
	If Not FileExists($sFile) Then Return SetError(1)
	Local $WAVE_HEADER = GetWaveHeader($sFile)

	If Not VerifyWaveFormat( $WAVE_HEADER, 16, 8000, 1 )	Then ; 16bit 8000hz, mono
		MsgBox(48,"Wrong Wav Format","This audio file should be a 16bit 8000hz mono signed PCM wav file.",0, $guiMain)
		Return SetError(1)
	EndIf

	Local $iSize = DllStructGetData($WAVE_HEADER, "Subchunk2Size")	; Get the bytes of raw data.
	c("Wave data size:" & $iSize)

	; Create the buffer for the raw audio data
	; Since this implemenetion is made for 8 bit wav files each sample is 16 bit (2 bytes) thus each element is a ushort(16 bit).
	; Subchunk2Size shows the total bytes for the raw data.
	; Amount of samples is calculated with the total size of the raw audio data divided by the size of each sample
	$Data = DllStructCreate("ushort[" & ( DllStructGetData($WAVE_HEADER, "Subchunk2Size")/2 ) & "]")
	$lpData = DllStructGetPtr($Data)
	; c("lpData:" & Hex($lpData))
	
	; Open the file again to read all data.
	$fhandle = _WinAPI_CreateFile($sFile, 2, 2, 2)
	_WinAPI_ReadFile($fhandle, $lpData, DllStructGetData($WAVE_HEADER, "Subchunk2Size"), $NULL)

	; No more reading, the entire file is in memory!
	_WinAPI_CloseHandle($fhandle)

	; Now prepare the modem and send the raw data over
	; Should be off hook before this.
	AddLine( "Set Voice Compression to 0: " & SendCommand("AT+VSM=0") )	; 8bit Signed PCM, 8000hz, mono
	AddLine( "In Voice Transmit Mode: " & SendCommand("AT+VTX") )
	
	_CommClearOutputBuffer()
	
	AddLine("Start playing file:" & @CRLF & $sFile)
	
	; Clear transmit buffer
	_CommSendByte(16)
	_CommSendByte(24)
	
	Local $iTransferSize = 1024
	; Transmit 1024 bytes at a time. The buffer is 2048 only.
	If $iSize <= $iTransferSize Then 
		SendData16BitTo8Bit( $lpData, $iSize )
		; _CommSendByteArray($lpData, $iSize, 0)
		If @error Then c("Error sending data.")
	Else
		For $i = 0 To Floor($iSize / $iTransferSize )
			SendData16BitTo8Bit( $lpData )	; Send 1024 data at a time
			; _CommSendByteArray($lpData, 1024, 0)
			If @error Then
				c("Error sending data when i=" & $i)
				ExitLoop
			EndIf
			$lpData += $iTransferSize
			WaitForUnderBuffer()
		Next
		; _CommSendByteArray($lpData, Mod ($iSize, 1024) , 0)
		SendData16BitTo8Bit( $lpData, Mod ($iSize, $iTransferSize) )	; Send the rest of data.
		If @error Then c("Error sending data at the last batch." )
	EndIf
	
	; Send end signal
	_CommSendByte(16)
	_CommSendByte(3)
	
	AddLine( "Voice transmission done.")

EndFunc

Func GetWaveHeader($sFile)
	; Return a WAVRHEADER format DDLStruct.
	
	; Just a dummy variable I need for WINAPI_ReadFile
	Local $NULL

	; Just the three constants I'm using
	Const $WAVE_MAPPER = 4294967295
	Const $WAVE_FORMAT_PCM = 0x01
	Const $WHDR_BEGINLOOP = 0x04

	Local $winmm = DllOpen("winmm.dll")
	Local $Data

	; WAVE_HEADER
	; The header data that is read from the wav file
	; Info found here: http://ccrma.stanford.edu/courses/422/projects/WaveFormat/
	Local $WAVE_HEADER = DllStructCreate("char ChunkID[4];int ChunkSize;char Format[4];char Subchunk1ID[4];" & _
			"int Subchunk1Size;short AudioFormat;short NumChannels;int SampleRate;" & _
			"int ByteRate;short BlockAlign;short BitsPerSample;char Subchunk2ID[4];" & _
			"int Subchunk2Size")

	; Open the file in read mode
	$fhandle = _WinAPI_CreateFile($sFile, 2, 2, 2)
	_WinAPI_ReadFile($fhandle, DllStructGetPtr($WAVE_HEADER, "ChunkID"), 4, $NULL)
	_WinAPI_ReadFile($fhandle, DllStructGetPtr($WAVE_HEADER, "ChunkSize"), 4, $NULL)
	_WinAPI_ReadFile($fhandle, DllStructGetPtr($WAVE_HEADER, "Format"), 4, $NULL)
	_WinAPI_ReadFile($fhandle, DllStructGetPtr($WAVE_HEADER, "Subchunk1ID"), 4, $NULL)
	_WinAPI_ReadFile($fhandle, DllStructGetPtr($WAVE_HEADER, "Subchunk1Size"), 4, $NULL)
	_WinAPI_ReadFile($fhandle, DllStructGetPtr($WAVE_HEADER, "AudioFormat"), 2, $NULL)
	_WinAPI_ReadFile($fhandle, DllStructGetPtr($WAVE_HEADER, "NumChannels"), 2, $NULL)
	_WinAPI_ReadFile($fhandle, DllStructGetPtr($WAVE_HEADER, "SampleRate"), 4, $NULL)
	_WinAPI_ReadFile($fhandle, DllStructGetPtr($WAVE_HEADER, "ByteRate"), 4, $NULL)
	_WinAPI_ReadFile($fhandle, DllStructGetPtr($WAVE_HEADER, "BlockAlign"), 2, $NULL)
	_WinAPI_ReadFile($fhandle, DllStructGetPtr($WAVE_HEADER, "BitsPerSample"), 2, $NULL)
	_WinAPI_ReadFile($fhandle, DllStructGetPtr($WAVE_HEADER, "Subchunk2ID"), 4, $NULL)
	_WinAPI_ReadFile($fhandle, DllStructGetPtr($WAVE_HEADER, "Subchunk2Size"), 4, $NULL)
	
	_WinAPI_CloseHandle($fhandle)
	Return $WAVE_HEADER
EndFunc


Func SendData8Bit( $lpVoice, $iLength = 1024)
	; Send binary data with Send String Method.
	; Do not send <DLE> codes here. In fact, all <DLE> in the data will be changed.
	$sData = DllStructGetData( DllStructCreate("CHAR[" & $iLength & "]", $lpVoice), 1)	; Get the string from data
	$sData = StringReplace($sData, Chr(16), Chr(17))	; no chr(16) should be in the voice data.
	_CommSendString($sData)
EndFunc

Func SendData16BitTo8Bit( $lpVoice, $iLength = 1024)
	; Send binary data with Send String Method.
	; Do not send <DLE> codes here. In fact, all <DLE> in the data will be changed.
	; This one convert 16 bit signed to 8 bit signed.
	$sData = DllStructGetData( DllStructCreate("CHAR[" & $iLength & "]", $lpVoice), 1)	; Get the string from data
	$aData = StringToASCIIArray($sData, 0, Default , 1)	; ANSI only
	
	$sOut = ""
	For $i = 0 To UBound($aData)-1 Step 2	; Keep only higher byte and discard all lower bytes
		$iChar = $aData[$i]
		$sOut &= Chr($iChar)
		If $iChar = 16 Then $sOut &= Chr(16)	; if it's Chr(16), then one more Chr(16) to escape it.
	Next
	c("send one batch " & $lpVoice)
	_CommSendString($sOut)
EndFunc


Func WaitForUnderBufferBG($iTimeOut = 5000)
	; This is for duplex voice mode. Need BGReceive() running in the background.
	Local $hTimer = TimerInit()
	While TimerDiff($hTimer) < $iTimeOut
		If $gfBufferUnderrun Then Return
		; Sleep(1)	; Cannot do sleep here, or the sound will be broken
	Wend
EndFunc


Func WaitForUnderBuffer($iTimeOut = 5000)
	; Read input for underbuffer
	; This is for normal wav playback, not for background transmission.
	Local $hTimer = TimerInit()
	While TimerDiff($hTimer) < $iTimeOut
		$instr = _Commgetstring()
		If $instr <> "" Then
			Switch StringLeft($instr, 2)
				Case $gsCodeUnderBuffer
					return
				Case $gsCodeBusy
					$gfBusy = True 
				Case $gsCodeDialTone
					$gfDialTone = True
				Case Chr(16) & "s", Chr(16) & "q", Chr(16) & "I"	; Hang up.
					$gfHangUp = True
				Case Chr(16) & "/"		; DTMF tone
					$gfKeyPressed = True
					$gsKeyPressed &= StringMid($instr, 3, 1)
			EndSwitch 
		EndIf
		; Sleep(1)	; Cannot do sleep here, or the sound will be broken
	Wend
EndFunc
