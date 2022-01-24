#NoTrayIcon
#include "..\..\..\_netcode_Core.au3"


; startup _netcode
_netcode_Startup()


; connect non blocking
Local $hMyClient = _netcode_TCPConnect("127.0.0.1", 1225, False, "", "", True)

; add the connection event
_netcode_SetEvent($hMyClient, 'connection', "_Event_Connection")


; main
While _netcode_Loop("000")
	Sleep(10)
WEnd



Func _Event_Connection(Const $hSocket, $sStage)

	ConsoleWrite("Socket @ " & $hSocket & " completed stage: " & $sStage & @CRLF)

	; once the server reached stage "netcode", send a hello world to the message event.
	if $sStage == "netcode" Then _netcode_TCPSend($hSocket, "message", "Hello World")
EndFunc