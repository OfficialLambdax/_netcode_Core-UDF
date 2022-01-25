#NoTrayIcon
#include "..\..\..\..\_netcode_Core.au3"


; read the public key from the ini
Local $sPublicKey = IniRead(@ScriptDir & "\RSA Keys.ini", "RSA", "Pub", "")


; startup netcode
_netcode_Startup()

; connect without authing to netcode
Local $hMyClient = _netcode_TCPConnect("127.0.0.1", 1225, True)
if Not $hMyClient Then MsgBox(16, "Client Error", "Could not connect to server")

; enable the preshared RSA key method
_netcode_SetOption($hMyClient, "Handshake Enable Preshared RSA", True)

; and disable the Random RSA method, so that server cannot force it onto us
_netcode_SetOption($hMyClient, "Handshake Enable Random RSA", False)

; set the preshared RSA key
_netcode_SetOption($hMyClient, 'Handshake Preshared RSAKey', StringToBinary($sPublicKey))

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