#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\_netcode_Core.au3"

#cs
	Absolute simple Server design.
	This Server allows multiple Clients to Upload multiple files at once.
	It uses the RawLinked ManageMode to improve Performance.
	[NOTE = The RawLinked ManageMode is highly experimental and unsafe - dont use it yet.
	The Mode will be recoded, so this script will break.]

	Each Client that connects and has send a "RegisterUpload"
	Event packet, will in Return get a Request to Connect a Second
	Socket for SocketLinking. Once the Client did, the Server
	accepts the uploaded data.

	Right within the "RegisterUpload" Event the Server also opens
	a file handle and stores it into an array.
	[0] = file handle
	[1] = size of what was uploaded already
	[2] = size of the file

	This array is set to the $vAdditionalData param in _netcode_SetupSocketLink().

	Once the _RawEvent_Upload() Event then gets called because the Client send
	data to it then the array is given with it. The func then uses the FileHandle in [0]
	to write the send data to and adds the len of the send data to [1]. Lastly it will
	update the array to _netcode.

	Once the Client is done with uploading it triggers the "UploadDone" Event.
	The Server then calculates how long it took to upload and how fast in MB/s it was.
	Lastly the File Handle gets closed.

	If a Client disconnects in the process the file handle to it will also be closed.

#ce


Global $__hServerSocket = False
Global $__sfDownloadDir = @ScriptDir & "\Downloads"

; =========================================================================
; Init

; check if .\downloads exists, if not create it
If Not FileExists($__sfDownloadDir) Then DirCreate($__sfDownloadDir)

; startup _netcode and setup listener aka parent
_netcode_Startup()
$__hServerSocket = _netcode_TCPListen(1225, "0.0.0.0")
If Not $__hServerSocket Then Exit MsgBox(16, "Error", "Couldnt Setup Listener. Exiting")

; set option to allow for Linking Setups on the parent socket
_netcode_SetOption($__hServerSocket, "AllowSocketLinkingSetup", True)

; set events that we want to use, excluding the RawLinked Event, as its defined differently
_netcode_SetEvent($__hServerSocket, "connection", "_Event_Connect")
_netcode_SetEvent($__hServerSocket, "disconnected", "_Event_Disconnect")
_netcode_SetEvent($__hServerSocket, "RegisterUpload", "_Event_RegisterUpload")
_netcode_SetEvent($__hServerSocket, "UploadDone", "_Event_UploadDone")


; =========================================================================
; Main Loop

While _netcode_Loop($__hServerSocket)

	; if no clients are connected then sleep 50 ms, else stress the cpu
	If _netcode_ParentGetClients($__hServerSocket, True) = 0 Then Sleep(50)

WEnd


; =========================================================================
; RawLinked Events

; will write the send data to the FileHandle in $vAdditionalData[0] and will add the len of the send data
; to the $vAdditionalData[1] to properly show the upload progress.
Func _RawEvent_Upload(Const $hSocket, $nLinkID, $sData, $vAdditionalData)

	FileWrite($vAdditionalData[0], $sData)
	$vAdditionalData[1] += StringLen($sData)

	ConsoleWrite($hSocket & @TAB & $vAdditionalData[1] & ' / ' & $vAdditionalData[2] & @CRLF)
	_netcode_SocketLinkSetAdditionalData($hSocket, $nLinkID, $vAdditionalData)

EndFunc


; =========================================================================
; netcode Events

; Opens a FileHandle for the given filename and creates an array for $vAdditionalData.
; Then it requests a second connect from the client.
Func _Event_RegisterUpload(Const $hSocket, $sFileName, $nFileSize)

	ConsoleWrite("Setting Up File Upload" & @CRLF)

	Local $arData[4] = [FileOpen($__sfDownloadDir & '\' & $sFileName, 18),0,$nFileSize,TimerInit()]

	_netcode_SetupSocketLink($hSocket, "_RawEvent_Upload", "upload", $arData)

EndFunc

; when the client has reached the fileend then it will send a trigger for this event.
; this event closes the filehandle and then calculated the time the upload took and the mb/s.
Func _Event_UploadDone(Const $hSocket)

	ConsoleWrite("Upload Finished by " & $hSocket & @CRLF)

	Local $arData = _netcode_SocketLinkGetAdditionalData($hSocket, "upload")
	if Not IsArray($arData) Then Return

	ConsoleWrite("Upload Took: " & Round(TimerDiff($arData[3]) / 1000, 2) & ' Seconds' & @TAB & Round(($arData[2] / Round(TimerDiff($arData[3]) / 1000, 2)) / 1048576, 2) & ' MB/s' & @CRLF)

EndFunc

; useless event in this script. We only want a notice once, that is when the client has
; staged to 10.
Func _Event_Connect(Const $hSocket, $nStage)
	if $nStage <> 10 Then Return
	ConsoleWrite("New Socket @ " & $hSocket & @CRLF)
EndFunc

; in case the client disconnects early, it might be that a filehandle is still linked to it.
; in that case we close it.
Func _Event_Disconnect(Const $hSocket)
	ConsoleWrite($hSocket & " Disconnected" & @CRLF)
	Local $arData = _netcode_SocketLinkGetAdditionalData($hSocket)
	If IsArray($arData) Then
		FileClose($arData[0])
	EndIf
EndFunc