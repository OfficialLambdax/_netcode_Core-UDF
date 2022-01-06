#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\_netcode_Core.au3"
#include <Array.au3>

#cs


#ce



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

_netcode_Startup()

If Not @Compiled Then $__net_bTraceEnable = True

Global $__hMyConnectClient = _netcode_TCPConnect($__sConnectToIP, $__sConnectToPort)
if Not $__hMyConnectClient Then Exit MsgBox(16, "Client Error", "Cannot Connect to Server")

; set callback events
_netcode_SetEvent($__hMyConnectClient, 'disconnected', "_Event_Disconnect")

; set non callback events
_netcode_SetEvent($__hMyConnectClient, 'RegisterResponse')

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

	; show failed uploads
	if UBound($arErrors) > 0 Then
		_ArrayDisplay($arErrors, "Failed Uploads")
	EndIf

	ReDim $arErrors[0][2]

WEnd

; stop _netcode
_netcode_Shutdown()

; =========================================================================
; Events

Func _Event_Disconnect(Const $hSocket, $nDisconnectError, $bDisconnectTriggered)

EndFunc


; =========================================================================
; Internals

Func _Internal_UploadFile($sFilePath, $nIndex)

	if StringRight($sFilePath, 1) = '\' Then ; if folder

		; cut file name according to the file upload mode
		if $__bFolderUpload Then
			$sFilePath = StringTrimLeft($sFilePath, StringLen($__sfFolderPath) + 1)

;~ 			MsgBox(0, "", $sFilePath)
		Else
			$sFilePath = StringTrimLeft($sFilePath, StringInStr($sFilePath, '\', 0, -1))
		EndIf

		; register upload of folder
		Local $arResponse = _netcode_UseNonCallbackEvent($__hMyConnectClient, 'RegisterResponse', 'RegisterDownload', _netcode_sParams(StringToBinary($sFilePath, 4), 0))
		if @error Then

			; error while requesting folder creation
			Return SetError(99, 0, False)
		EndIf

		; manually convert respond to Bool, since _netcode_sParams() cant do that
		$arResponse[2] = __netcode_SetVarType($arResponse[2], "Number")

		; check response
		if $arResponse[2] == 0 Then
			; folder created successfully
		Else
			; folder couldnt be created

			Return SetError($arResponse[2], 0, False)
		EndIf

		$sFilePath = StringTrimLeft($sFilePath, StringInStr($sFilePath, '\', 0, -2))

		ConsoleWrite($nIndex - 1 & '/' & UBound($__arFiles) - 1 & @TAB & $sFilePath & @CRLF)

		Return True

	Else ; if file

		; open file in read mode
		Local $hFileHandle = FileOpen($sFilePath, 16)
		if $hFileHandle = -1 Then
			; couldnt open the file in read mode
			Return False
		EndIf

		; save how large the file is
		Local $nFileSize = FileGetSize($sFilePath)

		; cut file name according to the file upload mode
		if $__bFolderUpload Then
			$sFilePath = StringTrimLeft($sFilePath, StringLen($__sfFolderPath) + 1)
		Else
			$sFilePath = StringTrimLeft($sFilePath, StringInStr($sFilePath, '\', 0, -1))
		EndIf

		; register upload of file
		Local $arResponse = _netcode_UseNonCallbackEvent($__hMyConnectClient, 'RegisterResponse', 'RegisterDownload', _netcode_sParams(StringToBinary($sFilePath, 4), $nFileSize))
		if @error Then

			; error while requesting a file upload
			FileClose($hFileHandle)
			Return SetError(99, 0, False)
		EndIf

		; manually convert respond to Bool, since _netcode_sParams() cant do that
		$arResponse[2] = __netcode_SetVarType($arResponse[2], "Number")

		; check if server denies upload
		if $arResponse[2] <> 0 Then

			; server denied upload
			FileClose($hFileHandle)
			Return SetError($arResponse[2], 0, False)
		EndIf

		; ready variables for upload
		Local $sData = ""
		Local $sReadSize = _netcode_GetDefaultPacketContentSize("Download")
		Local $nProgress = 0
		Local $nBytesLastRead = 0

		$sFilePath = StringTrimLeft($sFilePath, StringInStr($sFilePath, '\', 0, -1))

		; upload loop
		While True

			; read file content
			$sData = FileRead($hFileHandle, $sReadSize)
			if @error = -1 Then ; end of file reached

				ExitLoop
			EndIf
			$nBytesLastRead = @extended

			; quo packet with flood prevention on
			_netcode_TCPSend($__hMyConnectClient, "Download", BinaryToString($sData), True)

			; send packet
			If Not _netcode_Loop($__hMyConnectClient) Then

				; if we lost connection to the server
				FileClose($hFileHandle)
				Return SetError(100, 0, False)

			EndIf

			$nProgress += $nBytesLastRead

			ConsoleWrite($nIndex - 1 & '/' & UBound($__arFiles) - 1 & " Uploading Progress " & Round(($nProgress / $nFileSize) * 100, 0) & "%" & @TAB & @TAB & "of " & Round($nFileSize / 1048576, 2) & " MB" & @TAB & @TAB & "@ " & _netcode_SocketGetSendBytesPerSecond($__hMyConnectClient, 2) & " MB/s - " & $sFilePath & @CRLF)

		WEnd

		FileClose($hFileHandle)

		; tell server that we are done uploading
		$arResponse = _netcode_UseNonCallbackEvent($__hMyConnectClient, 'RegisterResponse', 'DownloadFinished')
		if @error Then
			; server didnt answer in time
			Return SetError(101, 0, False)
		EndIf

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