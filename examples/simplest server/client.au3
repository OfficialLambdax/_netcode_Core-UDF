#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\_netcode_Core.au3"

_netcode_Startup()

Global $__hClientSocket = _netcode_TCPConnect("127.0.0.1", 1225)
If Not $__hClientSocket Then Exit MsgBox(16, "Error", "Could not Connect to Server on Port 1225")
_netcode_SetEvent($__hClientSocket, "message", "_Event_Message")

_Message()

While _netcode_Loop($__hClientSocket)
	Sleep(50)
WEnd



Func _Event_Message(Const $hSocket, $sData)
	_Message($sData)
EndFunc

Func _Message($sMessage = False)

	if $sMessage Then
		Local $sResponse = InputBox("Client", "Server @ " & $__hClientSocket & " send message: " & @CRLF & $sMessage, "Put answer here")
		if @error Or $sResponse = "" Then Exit

	Else
		Local $sResponse = InputBox("Client", "Type your Message", "")
		if @error Or $sResponse = "" Then Exit

	EndIf

	_netcode_TCPSend($__hClientSocket, "message", $sResponse)
EndFunc