#NoTrayIcon
#include "..\..\..\_netcode_Core.au3"
#include <Array.au3>


; startup the udf first
_netcode_Startup()

; start server at port 1225 and make it possible for everyone to connect to it
Local $hMyParent = _netcode_TCPListen(1225, '0.0.0.0')

; check if starting the server worked and if not exit
if Not $hMyParent Then Exit MsgBox(16, "Error", "Could not start listener @ port 1225")

; define a callback event for the server, to which clients can send data
_netcode_SetEvent($hMyParent, 'MyServerEvent', "_Event_MyServerEvent")



; loop
While Sleep(10)
	_netcode_Loop($hMyParent)
WEnd


; my event callback function
Func _Event_MyServerEvent($hSocket, $arExampleArray)

	; disconnect the client first so that it can also show the array for comparison
	_netcode_TCPDisconnect($hSocket)

	; check if an array got send
	if Not IsArray($arExampleArray) Then Return ConsoleWrite("Warning: No array got send" & @CRLF)

	; then show the array
	_ArrayDisplay($arExampleArray, "Server Side. For comparison.")
EndFunc