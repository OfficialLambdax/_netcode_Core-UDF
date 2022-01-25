#NoTrayIcon
#include "..\..\..\..\_netcode_Core.au3"

; startup netcode
_netcode_Startup()


Local $arKeys = __netcode_CryptGenerateRSAKeyPair(2048)

IniWrite(@ScriptDir & "\RSA Keys.ini", "RSA", "Priv", BinaryToString($arKeys[0]))
IniWrite(@ScriptDir & "\RSA Keys.ini", "RSA", "Pub", BinaryToString($arKeys[1]))