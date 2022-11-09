Func PlayWav($sFile)

	If Not FileExists($sFile) Then Return SetError(1)

	; Just a dummy variable I need for WINAPI_ReadFile
	Local $NULL

	; Just the three constants I'm using
	Const $WAVE_MAPPER = 4294967295
	Const $WAVE_FORMAT_PCM = 0x01
	Const $WHDR_BEGINLOOP = 0x04

	Local $winmm = DllOpen("winmm.dll")
	Local $Data

	; WAVEFORMATEX
	; Used to open a wavedevice
	; http://msdn.microsoft.com/en-us/library/ms713497(VS.85).aspx
	Global $WAVEFORMATEX = DllStructCreate("ushort wFormatTag;ushort nChannels;dword nSamplesPerSec;" & _
			"dword nAvgBytesPerSec;ushort nBlockAlign;ushort wBitsPerSample;" & _
			"ushort cbSize")

	; WAVE_HEADER
	; The header data that is read from the wav file
	; Info found here: http://ccrma.stanford.edu/courses/422/projects/WaveFormat/
	Global $WAVE_HEADER = DllStructCreate("char ChunkID[4];int ChunkSize;char Format[4];char Subchunk1ID[4];" & _
			"int Subchunk1Size;short AudioFormat;short NumChannels;int SampleRate;" & _
			"int ByteRate;short BlockAlign;short BitsPerSample;char Subchunk2ID[4];" & _
			"int Subchunk2Size")

	; WAVE_HDR
	; Struct that contains the pointer to the raw audio data, which is sent to waveOutWrite
	; http://msdn.microsoft.com/en-us/library/ms713724(VS.85).aspx
	Global $WAVE_HDR = DllStructCreate("ptr lpData;dword dwBufferLength;dword dwBytesRecorded;uint dwUser;" & _
			"dword dwFlags;dword dwLoops;ptr lpNext;uint reserved")


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

	; Before we read the heavy stuff, lets check if the data is what we expect


	If Not (DllStructGetData($WAVE_HEADER, "Format") == "WAVE") Then; All wav files should have the Format set to WAVE
		c("Error, This is not a valid wav file!")
		Return SetError(2)
	ElseIf DllStructGetData($WAVE_HEADER, "AudioFormat") <> 1 Then; 1 means PCM (raw audio data) which is the only thing supported
		c("Error. This is wav file is compressed, only uncompressed files are supported.")
		Return SetError(3)
	ElseIf DllStructGetData($WAVE_HEADER, "BitsPerSample") <> 8 Then; THis script only deals with 8 bits, not difficult to fix though
		c("Error. This is wav file is has not a sample size of 8 bits, only 8 bits files are supported.")
		Return SetError(4)
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
	_WinAPI_ReadFile($fhandle, $lpData, DllStructGetData($WAVE_HEADER, "Subchunk2Size"), $NULL)

	; No more reading, the entire file is in memory!
	_WinAPI_CloseHandle($fhandle)

	; Now prepare the modem and send the raw data over
	; Should be off hook before this.
	AddLine( "Set Voice Compression to 1: " & SendCommand("AT+VSM=1") )
	AddLine( "In Voice Transmit Mode: " & SendCommand("AT+VTX") )
	
	_CommClearOutputBuffer()
	
	AddLine("Start playing file:" & $sFile)
	
	; Clear transmit buffer
	_CommSendByte(16)
	_CommSendByte(24)
	
	Local $iTransferSize = 1024
	; Transmit 1024 bytes at a time. The buffer is 2048 only.
	If $iSize <= $iTransferSize Then 
		SendData( $lpData, $iSize )
		; _CommSendByteArray($lpData, $iSize, 0)
		If @error Then c("Error sending data.")
	Else
		For $i = 0 To Floor($iSize / $iTransferSize )
			SendData( $lpData )	; Send 1024 data at a time
			; _CommSendByteArray($lpData, 1024, 0)
			If @error Then
				c("Error sending data when i=" & $i)
				ExitLoop
			EndIf
			$lpData += $iTransferSize
			WaitForUnderBuffer()
		Next
		; _CommSendByteArray($lpData, Mod ($iSize, 1024) , 0)
		SendData( $lpData, Mod ($iSize, $iTransferSize) )	; Send the rest of data.
		If @error Then c("Error sending data at the last batch." )
	EndIf
	
	; Send end signal
	_CommSendByte(16)
	_CommSendByte(3)
	
	AddLine( "Voice transmission done.")
EndFunc 
	


Func SendData( $lpVoice, $iLength = 1024)
	; Send binary data with Send String Method.
	; Do not send <DLE> codes here. In fact, all <DLE> in the data will be changed.
	$sData = DllStructGetData( DllStructCreate("CHAR[" & $iLength & "]", $lpVoice), 1)	; Get the string from data
	$sData = StringReplace($sData, Chr(16), Chr(17))	; no chr(16) should be in the voice data.
	_CommSendString($sData)
EndFunc

Func WaitForUnderBufferBG($iTimeOut = 5000)
	; This is for duplex voice mode. Need BGReceive() running in the background.
	Local $hTimer = TimerInit()
	While TimerDiff($hTimer) < $iTimeOut
		If $gfBufferUnderrun Then Return
		Sleep(1)
	Wend
EndFunc


Func WaitForUnderBuffer($iTimeOut = 5000)
	; Read input for underbuffer
	; This is for normal wav playback, not for background transmission.
	Local $hTimer = TimerInit()
	While TimerDiff($hTimer) < $iTimeOut
		$instr = _Commgetstring()
		If $instr <> "" Then
			If StringLeft($instr, 2) = Chr(16) & "u" Then return
		EndIf
		Sleep(1)
	Wend
EndFunc
