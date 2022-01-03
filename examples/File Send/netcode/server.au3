#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\_netcode_Core.au3"




Global $__sAccessIP = '0.0.0.0'
Global $__sAccessPort = '1225'
Global $__nHowManyClientsAreAllowedAtOnce = 10
Global $__sfDownloadPath = @ScriptDir & "\Downloads"
Global $__bUseEncryption = False
Global $__bDenyOverwritingOfExistingFiles = False


; =========================================================================
; Init

_netcode_Startup()

;~ If Not @Compiled Then $__net_bTraceEnable = True
$__net_bTraceEnable = True

if Not FileExists($__sfDownloadPath) Then DirCreate($__sfDownloadPath)

Global $__hMyParent = _netcode_TCPListen($__sAccessPort, $__sAccessIP,  Default, $__nHowManyClientsAreAllowedAtOnce)
if @error Then Exit MsgBox(16, "Server Error", "Could not startup listener at port: " & $__sAccessPort)

; toggle encryption
_netcode_SetOption($__hMyParent, "Encryption", $__bUseEncryption)

; set callback events
_netcode_SetEvent($__hMyParent, 'RegisterDownload', "_Event_RegisterDownload")
_netcode_SetEvent($__hMyParent, 'Download', "_Event_Download")
_netcode_SetEvent($__hMyParent, 'DownloadFinished', "_Event_DownloadFinished")

; priotize these events over the default events
_netcode_SetEvent($__hMyParent, 'disconnected', "_Event_Disconnect")
_netcode_SetEvent($__hMyParent, 'connection', "_Event_Connect")
_netcode_SetEvent($__hMyParent, "message", "_Event_Message")


; =========================================================================
; Main

ConsoleWrite("Server online at port " & $__sAccessPort & @CRLF)

While True
	if Not _netcode_Loop($__hMyParent) Then Exit MsgBox(16, "Server Error", "Server Shutdown")

	; server status
	_Internal_ServerStatus()

	; eco mode when no client is online
	if _netcode_ParentGetClients($__hMyParent, 1) = 0 Then Sleep(50)
WEnd




; =========================================================================
; Parent Events

; registers a download from the client and opens a file handle
Func _Event_RegisterDownload(Const $hSocket, $sFileName, $nFileSize)
	if StringLen($sFileName) > 100 Then
		; file name to long
		_netcode_TCPSend($hSocket, 'RegisterResponse', "False")
		Return
	EndIf

	if StringInStr($sFileName, '..') Then
		; file name contains illegal characters
		_netcode_TCPSend($hSocket, 'RegisterResponse', "False")
		Return
	EndIf

	Local $hFileHandle = _netcode_SocketGetVar($hSocket, "FileDownloadHandle")
	if $hFileHandle <> Null Then
		; download already registered
		_netcode_TCPSend($hSocket, 'RegisterResponse', "False")
		Return
	EndIf

	Local $sFilePath = $__sfDownloadPath & '\' & $sFileName

	if FileExists($sFilePath) And $__bDenyOverwritingOfExistingFiles Then
		; file already exists
		_netcode_TCPSend($hSocket, 'RegisterResponse', "False")
		Return
	EndIf

	; if file was actually a folder
	if StringRight($sFilePath, 1) = '\' Then
		DirCreate($sFilePath)
		_netcode_TCPSend($hSocket, 'RegisterResponse', "True")
		Return
	EndIf

	$hFileHandle = FileOpen($sFilePath, 18)
	if $hFileHandle = -1 Then
		; could not open file in write mode
		_netcode_TCPSend($hSocket, 'RegisterResponse', "False")
		Return
	EndIf

	; success
	_netcode_SocketSetVar($hSocket, "FileDownloadHandle", $hFileHandle)
	_netcode_SocketSetVar($hSocket, "FileDownloadPath", $sFilePath)
	_netcode_SocketSetVar($hSocket, "FileDownloadSize", Number($nFileSize))
	_netcode_SocketSetVar($hSocket, "FileDownloadProgressSize", 0) ; bytes received
	_netcode_SocketSetVar($hSocket, "FileDownloadProgress", 0) ; percentage

	_netcode_TCPSend($hSocket, 'RegisterResponse', "True")
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

; closes the file handle
Func _Event_DownloadFinished(Const $hSocket)
	Local $hFileHandle = _netcode_SocketGetVar($hSocket, "FileDownloadHandle")
	if $hFileHandle = Null Then Return

	FileClose($hFileHandle)
	_netcode_SocketSetVar($hSocket, "FileDownloadHandle", Null)
EndFunc

; closes and deletes files from an abrupted disconnect
Func _Event_Disconnect(Const $hSocket, $nDisconnectError, $bDisconnectTriggered)
	Local $hFileHandle = _netcode_SocketGetVar($hSocket, "FileDownloadHandle")
	if $hFileHandle <> Null Then
		; close the file handle if the download abrupted and also delete the file because its incomplete
		FileClose($hFileHandle)
		FileDelete(_netcode_SocketGetVar($hSocket, "FileDownloadPath"))
	EndIf

	ConsoleWrite("Client @ " & $hSocket & " disconnected" & @CRLF)
EndFunc

; just a display notice
Func _Event_Connect(Const $hSocket, $nStage, $vData)
	Switch $nStage

		Case 0
			ConsoleWrite("New Client @ " & $hSocket & @CRLF)

		Case 10
			ConsoleWrite("Client @ " & $hSocket & " Ready" & @CRLF)

	EndSwitch
EndFunc

; venting message data for performance tests
Func _Event_Message(Const $hSocket, $sData)

EndFunc



; =========================================================================
; Internals

Func _Internal_ServerStatus()

	Local Static $hTimer = TimerInit()
	Local $nStatusIntervall = 5000 ; 10 seconds

	if TimerDiff($hTimer) < $nStatusIntervall Then Return

	ConsoleWrite("/////////////////// Creating Status Report \\\\\\\\\\\\\\\\\\\" & @CRLF)

	; get all clients of the parent and list their download progresses
	Local $arClients = _netcode_ParentGetClients($__hMyParent)
	If UBound($arClients) = 0 Then
		ConsoleWrite("Server has no Clients" & @CRLF)
		ConsoleWrite("\\\\\\\\\\\\\\\\\\\  End of Status Report  ///////////////////" & @CRLF)
		$hTimer = TimerInit()
		Return
	EndIf

	ConsoleWrite("Server has " & UBound($arClients) & " Clients" & @CRLF)

	Local $nFileSize = 0
	Local $nFileProgress = 0

	For $i = 0 To UBound($arClients) - 1
		If _netcode_SocketGetVar($arClients[$i], "FileDownloadHandle") = Null Then
			Local $nBytesPerSecond = _netcode_SocketGetRecvBytesPerSecond($arClients[$i], 2)
			if $nBytesPerSecond > 0 Then
				ConsoleWrite(@TAB & "Socket @ " & $arClients[$i] & " is active with " & $nBytesPerSecond & " MB/s" & @CRLF)
			Else
				ConsoleWrite(@TAB & "Socket @ " & $arClients[$i] & " is inactive" & @CRLF)
			EndIf
		Else
			$nFileSize = _netcode_SocketGetVar($arClients[$i], "FileDownloadSize")
			$nFileProgress = _netcode_SocketGetVar($arClients[$i], "FileDownloadProgress")

			ConsoleWrite(@TAB & "Socket @ " & $arClients[$i] & " - Progress " & $nFileProgress & "%" & @TAB & "of " & Round($nFileSize / 1048576, 2) & " MB" & @TAB & @TAB & _netcode_SocketGetRecvBytesPerSecond($arClients[$i], 2) & " MB/s" & @CRLF)
		EndIf
	Next

	ConsoleWrite("\\\\\\\\\\\\\\\\\\\  End of Status Report  ///////////////////" & @CRLF)

	$hTimer = TimerInit()
EndFunc