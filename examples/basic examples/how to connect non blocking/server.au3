#NoTrayIcon
#include "..\..\..\_netcode_Core.au3"


; startup _netcode
_netcode_Startup()


; startup listener
Local $hMyParent = _netcode_TCPListen(1225)
if Not $hMyParent Then Exit MsgBox(16, "Server Error", "Cannot start listener at port 1225")

; add message event
_netcode_SetEvent($hMyParent, 'message', "_Event_Message")


; main
While Sleep(10)
	_netcode_Loop($hMyParent)
WEnd


Func _Event_Message(Const $hSocket, $sText)
	ConsoleWrite("Client @ " & $hSocket & " send message: " & $sText & @CRLF)
EndFunc