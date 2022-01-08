#include "..\..\..\_netcode_Core.au3"



; startup netcode
_netcode_Startup()

; startup listener
Local $hMyParent = _netcode_TCPListen(1225, '0.0.0.0')
if Not $hMyParent Then Exit MsgBox(16, "Server Error", "Could not startup listener")

; add the "MyEvent" event and bind it to the function "_Event_MyEvent"
_netcode_SetEvent($hMyParent, 'MyEvent', "_Event_MyEvent")

; show message that we started the server successfully
MsgBox(64, "Server Hello", "Server is online. You can close it either with the Tray icon or via SciTE")


; loop the parent socket
While Sleep(10)
	_netcode_Loop($hMyParent)
WEnd


; my event callback
Func _Event_MyEvent($hSocket, $sData)

	; show the client message
	MsgBox(64, "Server message", "Client send me a message: " & $sData)

EndFunc