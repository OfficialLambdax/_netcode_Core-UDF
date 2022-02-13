#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\..\_netcode_Core.au3"

; Setting it to 0.0.0.0 will allow anyone to connect to it. Setting it to, lets say, 127.0.0.1 means that only a client from 127.0.0.1 can connect to it
Global $__sAccessIP = '0.0.0.0'

; port to listen for incomming connections. Variable can be of type String, Int, Number or Double.
Global $__sAccessPort = '1225'

; no more clients that this can be connected at once
Global $__nHowManyClientsAreAllowedAtOnce = 10

; where to store the files and folders
Global $__sfDownloadPath = @ScriptDir & "\Downloads"

; witch each client a session key is handshaked. The current method is not safe against man in the middle attacks
Global $__bUseEncryption = True

; set to true if you want to deny the upload of a file that is already present in the storage
Global $__bDenyOverwritingOfExistingFiles = False


; =========================================================================
; Init

Local $sPrivateKey = "%privatekey%"

if $sPrivateKey == "%privatekey%" Then
	Exit MsgBox(48, "Server Error", "Private key is not set yet")
EndIf

Local $arKeys[2]
$arKeys[0] = StringToBinary($sPrivateKey)
;~ $arKeys[1] = ; not used yet

; startup netcode
_netcode_Startup()

; if the script is compiled then deactivate the tracer
If @Compiled Then $__net_bTraceEnable = False

; create storage directory if it doesnt exist yet
if Not FileExists($__sfDownloadPath) Then DirCreate($__sfDownloadPath)

; create listener
Global $__hMyParent = _netcode_TCPListen($__sAccessPort, $__sAccessIP,  Default, $__nHowManyClientsAreAllowedAtOnce)
if @error Then Exit MsgBox(16, "Server Error", "Could not startup listener at port: " & $__sAccessPort)

; toggle encryption
_netcode_SetOption($__hMyParent, "Encryption", $__bUseEncryption)

; enable the preshared rsa key handshake method
_netcode_SetOption($__hMyParent, "Handshake Method", "PresharedRSAKey")

; set the private key
_netcode_SetOption($__hMyParent, "Handshake Preshared RSAKey", $arKeys)

; set callback events
_netcode_SetEvent($__hMyParent, 'RegisterDownload', "_Event_RegisterDownload")
_netcode_SetEvent($__hMyParent, 'Download', "_Event_Download")
_netcode_SetEvent($__hMyParent, 'DownloadFinished', "_Event_DownloadFinished")
_netcode_SetEvent($__hMyParent, 'FilesAmount', "_Event_FilesAmount")

; priotize these events over the default events
_netcode_SetEvent($__hMyParent, 'disconnected', "_Event_Disconnect")
_netcode_SetEvent($__hMyParent, 'connection', "_Event_Connect")
_netcode_SetEvent($__hMyParent, "message", "_Event_Message")


; =========================================================================
; Main

ConsoleWrite("Server online at port " & $__sAccessPort & @CRLF)

While True
	if Not _netcode_Loop($__hMyParent) Then Exit MsgBox(16, "Server Error", "Server Shutdown unintentionally")

	; log the server status
	_Internal_ServerStatus()

	; spare the hradware resources if no client is connected
	if _netcode_ParentGetClients($__hMyParent, True) = 0 Then Sleep(50)
WEnd




; =========================================================================
; Parent Events

; updates the file amount progress of the client
Func _Event_FilesAmount(Const $hSocket, $sText)
	if StringLen($sText) > 10 Then Return

	if $sText == "Null" Then $sText = Null

	_netcode_SocketSetVar($hSocket, "FilesProgress", $sText)
EndFunc

; registers a download from the client and opens a file handle
Func _Event_RegisterDownload(Const $hSocket, $sFileName, $nFileSize)

	; convert filename back
	$sFileName = BinaryToString($sFileName, 4)

	if StringLen($sFileName) > 100 Then
		; file name to long
		_netcode_TCPSend($hSocket, 'RegisterResponse', "1")
		Return
	EndIf

	if StringInStr($sFileName, '\..\') Then
		; file name contains illegal characters
		_netcode_TCPSend($hSocket, 'RegisterResponse', "2")
		Return
	EndIf

	Local $hFileHandle = _netcode_SocketGetVar($hSocket, "FileDownloadHandle")
	if $hFileHandle <> Null Then
		; download already registered
		_netcode_TCPSend($hSocket, 'RegisterResponse', "3")
		Return
	EndIf

	Local $sFilePath = $__sfDownloadPath & '\' & $sFileName

	if FileExists($sFilePath) And $__bDenyOverwritingOfExistingFiles Then
		; file already exists
		_netcode_TCPSend($hSocket, 'RegisterResponse', "4")
		Return
	EndIf

	; if file was actually a folder
	if StringRight($sFilePath, 1) = '\' Then
		DirCreate($sFilePath)
		_netcode_TCPSend($hSocket, 'RegisterResponse', "0")
		Return
	EndIf

	$hFileHandle = FileOpen($sFilePath, 18)
	if $hFileHandle = -1 Then
		; could not open file in write mode
		_netcode_TCPSend($hSocket, 'RegisterResponse', "5")
		Return
	EndIf

	; success
	_netcode_SocketSetVar($hSocket, "FileDownloadHandle", $hFileHandle)
	_netcode_SocketSetVar($hSocket, "FileDownloadPath", $sFilePath)
	_netcode_SocketSetVar($hSocket, "FileDownloadSize", Number($nFileSize))
	_netcode_SocketSetVar($hSocket, "FileDownloadProgressSize", 0) ; bytes received
	_netcode_SocketSetVar($hSocket, "FileDownloadProgress", 0) ; percentage


	_netcode_TCPSend($hSocket, 'RegisterResponse', "0")
EndFunc

; writes the file content to the pre opened file handle
Func _Event_Download(Const $hSocket, $sData)
	Local $hFileHandle = _netcode_SocketGetVar($hSocket, "FileDownloadHandle")
	if $hFileHandle = Null Then Return

	FileWrite($hFileHandle, StringToBinary($sData))

	; update progress
	Local $nFileSize = _netcode_SocketGetVar($hSocket, "FileDownloadSize")
	Local $nFileProgressSize = _netcode_SocketGetVar($hSocket, "FileDownloadProgressSize")
	$nFileProgressSize += BinaryLen($sData)

	_netcode_SocketSetVar($hSocket, "FileDownloadProgressSize", $nFileProgressSize)
	_netcode_SocketSetVar($hSocket, "FileDownloadProgress", Round(($nFileProgressSize / $nFileSize) * 100, 0))
EndFunc

; closes the file handle once the client has finished uploading the file
Func _Event_DownloadFinished(Const $hSocket)
	Local $hFileHandle = _netcode_SocketGetVar($hSocket, "FileDownloadHandle")
	if $hFileHandle = Null Then Return

	FileClose($hFileHandle)
	_netcode_SocketSetVar($hSocket, "FileDownloadHandle", Null)

	_netcode_TCPSend($hSocket, 'RegisterResponse', "True")
EndFunc

; closes and deletes files from an abrupted disconnect
Func _Event_Disconnect(Const $hSocket, $nDisconnectError, $bDisconnectTriggered)
	Local $hFileHandle = _netcode_SocketGetVar($hSocket, "FileDownloadHandle")
	if $hFileHandle <> Null Then

		; close the file handle if the download abrupted and also delete the file because its likely incomplete
		FileClose($hFileHandle)
		FileDelete(_netcode_SocketGetVar($hSocket, "FileDownloadPath"))
	EndIf

	Local $sText = ""

	Switch $nDisconnectError

		Case 0
			$sText = "gracefully"

		Case 10050 To 10054
			$sText = "abruptly"

	EndSwitch

	ConsoleWrite("Client @ " & $hSocket & " " & $sText & " disconnected" & @CRLF)
EndFunc

; just a display notice
Func _Event_Connect(Const $hSocket, $sStage)
	Switch $sStage

		Case 'auth'
			ConsoleWrite("New Client @ " & $hSocket & @CRLF)

		Case 'handshake'
			ConsoleWrite("Client @ " & $hSocket & " uses session key: " & _netcode_StageGetExtraInformation($hSocket) & @CRLF)

		Case 'netcode'
			ConsoleWrite("Client @ " & $hSocket & " Ready" & @CRLF)

	EndSwitch
EndFunc

; venting message data for performance tests
Func _Event_Message(Const $hSocket, $sData)
EndFunc



; =========================================================================
; Internals

; logs the server status
Func _Internal_ServerStatus()

	Local Static $hTimer = TimerInit()
	Local $nStatusIntervall = 5000 ; every 5 seconds

	if TimerDiff($hTimer) < $nStatusIntervall Then Return

	ConsoleWrite("/////////////////// Creating Status Report \\\\\\\\\\\\\\\\\\\" & @CRLF)

	; get all clients of the parent
	Local $arClients = _netcode_ParentGetClients($__hMyParent)

	; if there is no client
	If UBound($arClients) = 0 Then
		ConsoleWrite("Server has no Clients" & @CRLF)
		ConsoleWrite("\\\\\\\\\\\\\\\\\\\  End of Status Report  ///////////////////" & @CRLF)
		$hTimer = TimerInit()
		Return
	EndIf

	ConsoleWrite("Server has " & UBound($arClients) & " Clients" & @CRLF)

	Local $nFileSize = 0
	Local $nFileProgress = 0
	Local $sText = ""

	; and list their download progresses
	For $i = 0 To UBound($arClients) - 1
		If _netcode_SocketGetVar($arClients[$i], "FilesProgress") = Null Then

			Local $nBytesPerSecond = _netcode_SocketGetRecvBytesPerSecond($arClients[$i], 2)

			; if the client is active but not uploading files
			if $nBytesPerSecond > 0 Then
				ConsoleWrite(@TAB & "Socket @ " & $arClients[$i] & " is active with " & $nBytesPerSecond & " MB/s" & @CRLF)
			Else
				ConsoleWrite(@TAB & "Socket @ " & $arClients[$i] & " is inactive" & @CRLF)
			EndIf
		Else

			; get file upload variables
			$nFileSize = _netcode_SocketGetVar($arClients[$i], "FileDownloadSize")
			$nFileProgress = _netcode_SocketGetVar($arClients[$i], "FileDownloadProgress")
			$sText = _netcode_SocketGetVar($arClients[$i], "FilesProgress")

			; and log them to the console
			ConsoleWrite(@TAB & "Socket @ " & $arClients[$i] & " - Files " & $sText & @TAB & "Current (" & $nFileProgress & "%) of " & Round($nFileSize / 1048576, 2) & " MB" & @TAB & @TAB & _netcode_SocketGetRecvBytesPerSecond($arClients[$i], 2) & " MB/s" & @CRLF)
		EndIf
	Next

	ConsoleWrite("\\\\\\\\\\\\\\\\\\\  End of Status Report  ///////////////////" & @CRLF)

	; reset timer
	$hTimer = TimerInit()
EndFunc