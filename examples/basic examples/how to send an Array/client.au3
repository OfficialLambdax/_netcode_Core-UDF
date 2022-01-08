#NoTrayIcon
#include "..\..\..\_netcode_Core.au3"
#include <Array.au3>


; startup the udf first
_netcode_Startup()

; connect to ip 127.0.0.1 and port 1225
Local $hMyClient = _netcode_TCPConnect('127.0.0.1', 1225)

; check if we could connect and if not exit
if Not $hMyClient Then Exit MsgBox(16, "Error", "Could not connect to 127.0.0.1 @ 1225")



; create array
Local $arExampleArray[20][20]

; fill array with random numbers
For $iY = 0 To 19 ; for Y row

	For $iX = 0 To 19 ; for X row

		$arExampleArray[$iY][$iX] = Random(0, 9, 1)

	Next

Next

; show array
_ArrayDisplay($arExampleArray, "I am going to send this array to the server")


; send the array and use the simple params serializer
_netcode_TCPSend($hMyClient, 'MyServerEvent', _netcode_sParams($arExampleArray))


; loop
While Sleep(10)

	; loop the client socket and exitloop if we disconnected
	If Not _netcode_Loop($hMyClient) Then ExitLoop


WEnd

; show again for comparison
_ArrayDisplay($arExampleArray, "Client side. For comparison.")
