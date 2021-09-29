#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include-once
#include "..\..\..\_netcode_Core.au3"

Global $___nServerIP = InputBox('', "What IP", "127.0.0.1")
Global $___nServerPort = 1225
Global $___hServerSocket
Global $___bConnectedToServer = False
Global $___bFileToTransferSet = False
Global $___hFileHandle
Global $___sfFileToUpload = ""
Global $___nFileSize = 0

_netcode_Startup()

_netcode_PresetEvent("FileTransfer", "_On_FileTransfer")
_netcode_PresetEvent("connection", "_ConnectedToServer")
_netcode_PresetEvent("disconnected", "_DisconnectedFromServer")

ConsoleWrite("Client trying to Connect to " & $___nServerIP & ':' & $___nServerPort & @CRLF)

While True
	if Not $___bConnectedToServer Then _netcode_TCPConnect($___nServerIP, $___nServerPort)
	if $___bConnectedToServer Then _netcode_Loop($___hServerSocket)
	if $___bConnectedToServer Then _FileTransfer()
WEnd

Func _FileTransfer()
	if $___sfFileToUpload = "" Then
		$___sfFileToUpload = FileOpenDialog("Choose File to Upload", @ScriptDir, "(*.*)", 1)
		if @error Then Exit

		$sFileName = StringTrimLeft($___sfFileToUpload, StringInStr($___sfFileToUpload, '\', 0, -1))
		$___nFileSize = FileGetSize($___sfFileToUpload)
		_netcode_TCPSend($___hServerSocket, 'FileTransfer', 'Register|' & $sFileName & '|' & $___nFileSize)
	EndIf

	if $___bFileToTransferSet Then
;~ 		$sRead = FileRead($___hFileHandle, 32000)
		$sRead = FileRead($___hFileHandle, _netcode_GetDefaultPacketContentSize('FileTransfer'))
		if @error = -1 Then
			FileClose($___hFileHandle)
			$___bFileToTransferSet = False
			_netcode_TCPSend($___hServerSocket, 'FileTransfer', "Done")
			ConsoleWrite("Upload Done" & @CRLF)
		Else
;~ 			While Not _netcode_TCPSend($___hServerSocket, 'FileTransfer', _netcode_sParams('Stream', BinaryToString($sRead)))
			_netcode_TCPSend($___hServerSocket, 'FileTransfer', _netcode_sParams('Stream', BinaryToString($sRead)))
;~ 				_netcode_Loop($___hServerSocket)
;~ 			WEnd
			ConsoleWrite("Send " & Round($sRead / 1024, 2) & ' KB' & @TAB & FileGetPos($___hFileHandle) & ' / ' & $___nFileSize & @CRLF)
		EndIf
	EndIf
EndFunc



Func _On_FileTransfer(Const $hSocket, $sData)
	Local $arData = StringSplit($sData, '|', 1 + 2)

	Switch $arData[0]
		Case "OK"
			$___bFileToTransferSet = True
			$___hFileHandle = FileOpen($___sfFileToUpload, 16)
			ConsoleWrite("Server Send OK" & @CRLF)

		Case "Done"
;~ 			ConsoleWrite("Exiting" & @TAB & @TAB & _Crypt_HashFile($___sfFileToUpload, $CALG_MD5) & @CRLF)
			ConsoleWrite("Exiting" & @CRLF)
			$___sfFileToUpload = ""
	EndSwitch
EndFunc

Func _ConnectedToServer(Const $hSocket, $nStage)
	if $nStage <> 10 Then Return
	ConsoleWrite("Connected to Server on Socket: " & $hSocket & @CRLF)
	$___hServerSocket = $hSocket
	$___bConnectedToServer = True
EndFunc

Func _DisconnectedFromServer(Const $hSocket)
	ConsoleWrite("Disconnected From Server on Socket: " & $hSocket & @CRLF)
	$___bConnectedToServer = False
	$___bFileToTransferSet = False
	$___sfFileToUpload = ""
EndFunc
