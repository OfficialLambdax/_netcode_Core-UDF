#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\..\_netcode_Core.au3"
#include <Array.au3>



Global $__sConnectToIP = InputBox("Server IP", "Set Server IP", '127.0.0.1')
if @error Then Exit
Global $__sConnectToPort = '1225'

; =========================================================================
; Init

Global $__arFiles[1]
Global $__bFolderUpload = False
Global $__sfFolderPath = ""
Local $arErrors[0][2]
Local $nArSize = 0
Local $rMsgBox = 0
Local $nError = 0
Local $sPublicKey = "UlNBMQAIAAADAAAAAAEAAAAAAAAAAAAAAQAB0FdtG5glD2+Hy559w1GRiToFTqkP0arWvG/zMvOqa+fFQiFxHSqXZqlUQEB5/oranE/RTSCGiCLTur159Afv+xQC9ET64dB5Rq7y6Ppw0z0qzjCD80eXPVkmxPGtkBTpYGW5LAt7NN9r7a6A/V/nBDf6aYiR2m6BEUnGHmlnyfAjG46bGF+AEC+/Q9BvD2CjfRsExWSj07Scbpmm7UZ1ooV5fp9VTQdwmCypdRzH+gTHqz5bGjP7x6GC/h4s2SGyRG658V/UoBbxN+SotyBenJRqAj6AtbWjlyFkeS6diDsPYLoOm77TwTRjvPOx6XQ2jKUmxsWX2xZRGGDPskD1dQ=="

If $sPublicKey == "%publickey%" Then
	Exit MsgBox(48, "Client Error", "Public key not set yet")
EndIf

_netcode_Startup()

If @Compiled Then $__net_bTraceEnable = False

Global $__hMyConnectClient = _netcode_TCPConnect($__sConnectToIP, $__sConnectToPort, True)
if Not $__hMyConnectClient Then Exit MsgBox(16, "Client Error", "Cannot Connect to Server")

; enable the preshared rsa key handshake method
_netcode_SetOption($__hMyConnectClient, "Handshake Enable Preshared RSA", True)

; disable the Random RSA method
_netcode_SetOption($__hMyConnectClient, "Handshake Enable Random RSA", False)

; set the public key
_netcode_SetOption($__hMyConnectClient, "Handshake Preshared RSAKey", StringToBinary($sPublicKey))

; set non callback events
_netcode_SetEvent($__hMyConnectClient, 'RegisterResponse')

If Not _netcode_AuthToNetcodeServer($__hMyConnectClient) Then
	Exit MsgBox(16, "Client Error", "Could not Stage through")
EndIf

; =========================================================================
; Main

While True

	$rMsgBox = MsgBox(32 + 3, "Question", "Do you want to upload multiple files or a single? Yes for Folder select. No for single file select.")

	if $rMsgBox = 6 Then ; if folder select

		$__bFolderUpload = True

		$__sfFolderPath = FileSelectFolder("Select Folder", @ScriptDir)
		if @error Then Exit
		$__arFiles = _RecursiveFileListToArray($__sfFolderPath, '', 0)

	ElseIf $rMsgBox = 7 Then ; if single file select

		$__bFolderUpload = False

		ReDim $__arFiles[2]
		$__arFiles[0] = 1
		$__arFiles[1] = FileOpenDialog("Select File", @ScriptDir, "All (*.*)")
		if @error Then Exit

	Else
		ExitLoop

	EndIf

	For $i = 1 To UBound($__arFiles) - 1

		; tell the server our progress
		_netcode_TCPSend($__hMyConnectClient, 'FilesAmount', $i - 1 & '/' & UBound($__arFiles) - 1)

		; upload file
		if Not _Internal_UploadFile($__arFiles[$i], $i) Then

			; catch error
			$nError = @error

			; add failed file upload to array
			$nArSize = UBound($arErrors)
			ReDim $arErrors[$nArSize + 1][2]
			$arErrors[$nArSize][0] = $__arFiles[$i]

			; add reason for the fail
			Switch $nError

				Case 1
					$arErrors[$nArSize][1] = "File name too long"

				Case 2
					$arErrors[$nArSize][1] = "File name contains illegal chars"

				Case 3
					$arErrors[$nArSize][1] = "A file upload is already registered"

				Case 4
					$arErrors[$nArSize][1] = "File is already present"

				Case 5
					$arErrors[$nArSize][1] = "Server couldnt create file"

				Case 98
					$arErrors[$nArSize][1] = "Could not open the File in Read mode"

				Case 99
					$arErrors[$nArSize][1] = "Server didnt respond to Upload Register"

				Case 100
					$arErrors[$nArSize][1] = "Lost connection to the server"

				Case 101
					$arErrors[$nArSize][1] = "Server didnt respond to Upload Finish"

			EndSwitch

		EndIf

		; check our connection to the server
		if __netcode_CheckSocket($__hMyConnectClient) = 0 Then Exit MsgBox(16, "Disconnected", "Disconnected from Server. Aborting Upload")
	Next

	; tell the server that we are done
	_netcode_TCPSend($__hMyConnectClient, 'FilesAmount', "Null")

	; send the last packet
	_netcode_Loop($__hMyConnectClient)

	; show failed uploads
	if UBound($arErrors) > 0 Then
		_ArrayDisplay($arErrors, "Failed Uploads")
	EndIf

	ReDim $arErrors[0][2]

WEnd

; stop _netcode
_netcode_Shutdown()

; =========================================================================
; Callback Events

; none


; =========================================================================
; Internals

Func _Internal_UploadFile($sFilePath, $nIndex)

	if StringRight($sFilePath, 1) = '\' Then ; if folder

		; cut file name according to the file upload mode
		if $__bFolderUpload Then
			$sFilePath = StringTrimLeft($sFilePath, StringLen($__sfFolderPath) + 1)
		Else
			$sFilePath = StringTrimLeft($sFilePath, StringInStr($sFilePath, '\', 0, -1))
		EndIf

		; register upload of the current folder and read response from the non callback event
		Local $arResponse = _netcode_UseNonCallbackEvent($__hMyConnectClient, 'RegisterResponse', 'RegisterDownload', _netcode_sParams(StringToBinary($sFilePath, 4), 0))
		if @error Then

			; server didnt answer in time or disconnected
			Return SetError(99, 0, False)
		EndIf

		; manually convert respond to Number, because it is of Type String
		$arResponse[2] = __netcode_SetVarType($arResponse[2], "Number")

		; check response
		if $arResponse[2] <> 0 Then
			; return the responded reason for denying the upload
			Return SetError($arResponse[2], 0, False)
		EndIf

		; cut filepath to the name for consolewrite
		$sFilePath = StringTrimLeft($sFilePath, StringInStr($sFilePath, '\', 0, -2))

		; log the progress to the console
		ConsoleWrite($nIndex - 1 & '/' & UBound($__arFiles) - 1 & @TAB & $sFilePath & @CRLF)

		; success
		Return True

	Else ; if file

		; open file in read mode
		Local $hFileHandle = FileOpen($sFilePath, 16)
		if $hFileHandle = -1 Then
			; couldnt open the file in read mode
			Return SetError(98, 0, False)
		EndIf

		; get how large the file is
		Local $nFileSize = FileGetSize($sFilePath)

		; cut file name according to the file upload mode
		if $__bFolderUpload Then
			$sFilePath = StringTrimLeft($sFilePath, StringLen($__sfFolderPath) + 1)
		Else
			$sFilePath = StringTrimLeft($sFilePath, StringInStr($sFilePath, '\', 0, -1))
		EndIf

		; register upload of file and read response from the non callback event
		Local $arResponse = _netcode_UseNonCallbackEvent($__hMyConnectClient, 'RegisterResponse', 'RegisterDownload', _netcode_sParams(StringToBinary($sFilePath, 4), $nFileSize))
		if @error Then

			; server didnt answer in time or disconnected
			FileClose($hFileHandle)
			Return SetError(99, 0, False)
		EndIf

		; manually convert respond to Number, because it is of Type String
		$arResponse[2] = __netcode_SetVarType($arResponse[2], "Number")

		; check if server denies upload
		if $arResponse[2] <> 0 Then
			FileClose($hFileHandle)

			; return the responded reason for denying the upload
			Return SetError($arResponse[2], 0, False)
		EndIf

		; create variables for upload
		Local $sData = ""
		Local $sReadSize = _netcode_GetDefaultPacketContentSize("Download")
		Local $nProgress = 0
		Local $nBytesLastRead = 0

		; cut the filepath for its name for ConsoleWrite()
		$sFilePath = StringTrimLeft($sFilePath, StringInStr($sFilePath, '\', 0, -1))

		; upload loop
		While True

			; read file content
			$sData = FileRead($hFileHandle, $sReadSize)

			; end of file reached
			if @error = -1 Then

				ExitLoop
			EndIf

			; catch the amount of read bytes instead of using BinaryLen()
			$nBytesLastRead = @extended

			; quo the data for sending with flood prevention on
			_netcode_TCPSend($__hMyConnectClient, "Download", BinaryToString($sData), True)

			; send the data with _netcode_Loop()
			If Not _netcode_Loop($__hMyConnectClient) Then

				; if we lost connection to the server while uploading
				FileClose($hFileHandle)
				Return SetError(100, 0, False)

			EndIf

			; add the last read bytes to the progress for ConsoleWrite()
			$nProgress += $nBytesLastRead

			; log our progress to the Console
			ConsoleWrite($nIndex - 1 & '/' & UBound($__arFiles) - 1 & " Uploading Progress " & Round(($nProgress / $nFileSize) * 100, 0) & "%" & @TAB & @TAB & "of " & Round($nFileSize / 1048576, 2) & " MB" & @TAB & @TAB & "@ " & _netcode_SocketGetSendBytesPerSecond($__hMyConnectClient, 2) & " MB/s - " & $sFilePath & @CRLF)

		WEnd

		; close the handle since the upload has finished
		FileClose($hFileHandle)

		; let the server know that we are done uploading so that it can close the handle on its side
		$arResponse = _netcode_UseNonCallbackEvent($__hMyConnectClient, 'RegisterResponse', 'DownloadFinished')
		if @error Then

			; server didnt answer in time
			Return SetError(101, 0, False)
		EndIf

		; success
		Return True

	EndIf
EndFunc

;Author: Oscar (Autoit.de)
Func _RecursiveFileListToArray($sPath, $sPattern, $iFlag = 0, $iFormat = 1, $sDelim = @CRLF)
	Local $hSearch, $sFile, $sReturn = ''
	If StringRight($sPath, 1) <> '\' Then $sPath &= '\'
	$hSearch = FileFindFirstFile($sPath & '*.*')
	If @error Or $hSearch = -1 Then Return SetError(1, 0, $sReturn)
	While True
		$sFile = FileFindNextFile($hSearch)
		If @error Then ExitLoop
		If StringInStr(FileGetAttrib($sPath & $sFile), 'D') Then
			If StringRegExp($sPath & $sFile, $sPattern) And ($iFlag = 0 Or $iFlag = 2) Then $sReturn &= $sPath & $sFile & '\' & $sDelim
			$sReturn &= _RecursiveFileListToArray($sPath & $sFile & '\', $sPattern, $iFlag, 0)
			ContinueLoop
		EndIf
		If StringRegExp($sFile, $sPattern) And ($iFlag = 0 Or $iFlag = 1) Then $sReturn &= $sPath & $sFile & $sDelim
	WEnd
	FileClose($hSearch)
	If $iFormat Then Return StringSplit(StringTrimRight($sReturn, StringLen($sDelim)), $sDelim, $iFormat)
	Return $sReturn
EndFunc   ;==>_RecursiveFileListToArray