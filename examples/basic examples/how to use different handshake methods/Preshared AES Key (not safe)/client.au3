#NoTrayIcon
#include "..\..\..\..\_netcode_Core.au3"

; startup netcode
_netcode_Startup()

; connect without authing to netcode
Local $hMyClient = _netcode_TCPConnect("127.0.0.1", 1225, True)
if Not $hMyClient Then MsgBox(16, "Client Error", "Could not connect to server")

; enable the preshared AES key method
_netcode_SetOption($hMyClient, "Handshake Enable Preshared AES", True)

; set the preshared AES key
_netcode_SetOption($hMyClient, 'Handshake Preshared AESKey', "TestPassword")

; auth to netcode server
If Not _netcode_AuthToNetcodeServer($hMyClient) Then Exit MsgBox(16, "Client Error", "Could not stage through")

; quo packet
_netcode_TCPSend($hMyClient, 'message', "Hello World")

; send packet
_netcode_Loop($hMyClient)

; disconnect when ready
_netcode_TCPDisconnectWhenReady($hMyClient)

; shutdown
_netcode_Shutdown()