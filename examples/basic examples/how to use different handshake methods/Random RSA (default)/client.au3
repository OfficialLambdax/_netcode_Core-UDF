#NoTrayIcon
#include "..\..\..\..\_netcode_Core.au3"

; startup netcode
_netcode_Startup()

; connect
Local $hMyClient = _netcode_TCPConnect("127.0.0.1", 1225)
if Not $hMyClient Then MsgBox(16, "Client Error", "Could not connect to server")

; quo packet
_netcode_TCPSend($hMyClient, 'message', "Hello World")

; send packet
_netcode_Loop($hMyClient)

; disconnect when ready
_netcode_TCPDisconnectWhenReady($hMyClient)

; shutdown
_netcode_Shutdown()