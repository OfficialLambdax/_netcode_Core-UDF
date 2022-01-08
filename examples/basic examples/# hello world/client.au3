#NoTrayIcon
#include "..\..\..\_netcode_Core.au3"


; startup netcode
_netcode_Startup()

; connect to server
Local $hMyClient = _netcode_TCPConnect('127.0.0.1', 1225)
if Not $hMyClient Then Exit MsgBox(16, "Client Error", "Cannot connect to Server")


; quo a message to be send to the server
_netcode_TCPSend($hMyClient, 'MyEvent', 'Hello World')

; send message
_netcode_Loop($hMyClient)

; disconnect from the server once data is received
_netcode_TCPDisconnectWhenReady($hMyClient)