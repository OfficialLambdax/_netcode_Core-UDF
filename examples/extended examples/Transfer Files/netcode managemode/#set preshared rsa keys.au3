#NoTrayIcon
#include "..\..\..\..\_netcode_Core.au3"


Local $sfServer = @ScriptDir & "\server.au3"
Local $sfClient = @ScriptDir & "\client.au3"

if Not FileExists($sfServer) Or Not FileExists($sfClient) Then
	Exit MsgBox(48, "Error", "Server.au3 or Client.au3 does not exist")
EndIf


; startup _netcode
_netcode_Startup()


; create a rsa key pair
Local $arKey = __netcode_CryptGenerateRSAKeyPair(2048)
$arKey[0] = BinaryToString($arKey[0])
$arKey[1] = BinaryToString($arKey[1])

; set the priv key in the server.au3
Local $hOpen = FileOpen($sfServer, 0)
Local $sRead = FileRead($hOpen)
FileClose($hOpen)

; check how often it occurs in the script
StringReplace($sRead, "%privatekey%", "")
if @extended <= 1 Then Exit MsgBox(48, "Error", "The private key is already set in the server.au3")

; only replace the first encounter
$sRead = StringReplace($sRead, "%privatekey%", $arKey[0], 1)

$hOpen = FileOpen($sfServer, 2)
FileWrite($hOpen, $sRead)
FileClose($hOpen)


; set the pub key in the client.au3
$hOpen = FileOpen($sfClient, 0)
$sRead = FileRead($hOpen)
FileClose($hOpen)

; check how often it occurs in the script
StringReplace($sRead, "%publickey%", "")
if @extended <= 1 Then Exit MsgBox(48, "Error", "The public key is already set in the client.au3")

; only replace the first encounter
$sRead = StringReplace($sRead, "%publickey%", $arKey[1], 1)

$hOpen = FileOpen($sfClient, 2)
FileWrite($hOpen, $sRead)
FileClose($hOpen)

MsgBox(64, "Done", "Successfully written rsa keys into the server.au3 and client.au3")