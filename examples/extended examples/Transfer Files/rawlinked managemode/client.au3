#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\..\_netcode_Core.au3"

#cs
	~ todo description
#ce

Global $__hClientSocket = False
Global $__hClientLinkedSocket = False
Global $__sIP = InputBox("", "IP", "127.0.0.1")
if @error Then Exit
Global $__nPort = 1225
Global $__sFileToUpload = ""
Global $__hFileHandle

; =========================================================================
; Init

_netcode_Startup()
_netcode_PresetEvent("disconnected", "_Event_Disconnect")

While $__hClientSocket = False
	$__hClientSocket = _netcode_TCPConnect($__sIP, $__nPort)
	if Not $__hClientSocket Then Sleep(500)
WEnd

_netcode_SetOption($__hClientSocket, "AllowSocketLinkingRequest", True)

; =========================================================================
; Select File and Send its name and size to server


$__sFileToUpload = FileOpenDialog("Choose File to Upload", @ScriptDir, "(*.*)", 1)
if @error Then Exit

$__hFileHandle = FileOpen($__sFileToUpload, 16)
if $__hFileHandle = -1 Then Exit MsgBox(16, "Error", "Cannot open File")


Local $sFileName = StringTrimLeft($__sFileToUpload, StringInStr($__sFileToUpload, '\', 0, -1))
_netcode_TCPSend($__hClientSocket, 'RegisterUpload', _netcode_sParams($sFileName, FileGetSize($__sFileToUpload)))


; =========================================================================
; Main loop

While _netcode_Loop("000")
	; if both sockets closed then exit loop and therefore quit
	if Not $__hClientSocket And Not $__hClientLinkedSocket Then Exit

	; if the linked socket doesnt exists yet
	if Not $__hClientLinkedSocket Then
		; check if the Link is up
		if _netcode_CheckLink($__hClientSocket, "upload") Then
			; if yes then add the linked socket to the Global var
			$__hClientLinkedSocket = _netcode_CheckLink($__hClientSocket, "upload")
		EndIf

	Else
		; if the linked socket is up then upload
		_Upload()

	EndIf
WEnd

; =========================================================================
; Upload function - not a Event

Func _Upload()
	; read data in the maximum size of the Default packet size
	$sRead = FileRead($__hFileHandle, _netcode_GetDefaultPacketContentSize())

	; if end of file is reached, therefore the upload is done, tell the server
	if @error = -1 Then
		; if done
		FileClose($__hFileHandle)
		_netcode_TCPSend($__hClientSocket, 'UploadDone')

		_netcode_Loop($__hClientSocket)
		Sleep(1000)

		; and exit
		Exit

	Else
		; send the read data
		_netcode_TCPSendRaw($__hClientLinkedSocket, $sRead)

	EndIf
EndFunc


; =========================================================================
; netcode Events

Func _Event_Disconnect(Const $hSocket, $nDisconnectError, $bDisconnectTriggered)
	ConsoleWrite($hSocket & " Disconnected" & @CRLF)
	if $__hClientLinkedSocket = $hSocket Then
		$__hClientLinkedSocket = False
	ElseIf $__hClientSocket = $hSocket Then
		$__hClientSocket = False
	EndIf
EndFunc