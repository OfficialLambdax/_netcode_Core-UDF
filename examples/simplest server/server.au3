#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\_netcode_Core.au3"

_netcode_Startup()

Local $hServerSocket = _netcode_TCPListen(1225)
if Not $hServerSocket Then Exit MsgBox(16, "Error", "Could not setup Listener on Port 1225")
_netcode_SetEvent($hServerSocket, "message", "_Event_Message")
_netcode_SetOption($hServerSocket, "Encryption", True) ; dont need to be enabled


ConsoleWrite("Server is running" & @CRLF)
While _netcode_Loop($hServerSocket)
	; _netcode is designed to be performant, so if no sleep is placed it will bash the cpu.
	Sleep(50)
WEnd


Func _Event_Message(Const $hSocket, $sData)
	Local $sResponse = InputBox("Server", "Client @ " & $hSocket & " send message: " & @CRLF & $sData, "Put answer here")
	if @error or $sResponse = "" Then Return

	_netcode_TCPSend($hSocket, "message", $sResponse)
EndFunc
