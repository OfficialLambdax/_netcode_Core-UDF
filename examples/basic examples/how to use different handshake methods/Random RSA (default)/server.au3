#NoTrayIcon
#include "..\..\..\..\_netcode_Core.au3"

; startup netcode
_netcode_Startup()


; start listener
Local $hMyParent = _netcode_TCPListen(1225)
if Not $hMyParent Then Exit MsgBox(16, "Server Error", "Cannot startup listener")

; enable encryption
_netcode_SetOption($hMyParent, 'Encryption', True)

; add events
_netcode_SetEvent($hMyParent, "connection", "_MyEvent_Connection")
_netcode_SetEvent($hMyParent, "message", "_MyEvent_Message")


While Sleep(10)
	_netcode_Loop($hMyParent)
WEnd





Func _MyEvent_Connection(Const $hSocket, $sStage)

	Switch $sStage

		Case "connect"
			ConsoleWrite("New Client @ Socket " & $hSocket & @CRLF)

		Case "handshake"
			ConsoleWrite("Client @ Socket " & $hSocket & " uses session key: " & _netcode_StageGetExtraInformation($hSocket) & @CRLF)

	EndSwitch

EndFunc

Func _MyEvent_Message(Const $hSocket, $sMessage)
	ConsoleWrite("Client @ Socket " & $hSocket & " send message: " & $sMessage & @CRLF)
EndFunc