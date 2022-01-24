#NoTrayIcon
#include "..\..\..\_netcode_Core.au3"

; startup _netcode
_netcode_Startup()

; connect to server
Local $hMyClient = _netcode_TCPConnect("127.0.0.1", 1225)
if Not $hMyClient Then Exit MsgBox(16, "Client Error", "Cannot connect to server")

; add non callback event
_netcode_SetEvent($hMyClient, 'NonCallback')

ConsoleWrite("Connected to Server" & @CRLF & @CRLF)



; get random number
Local $nNum1 = _netcode_UseNonCallbackEvent($hMyClient, 'NonCallback', 'Random')
$nNum1 = $nNum1[2]
ConsoleWrite("$nNum1 = " & $nNum1 & @CRLF)


; get random number betwen 0 and 99
Local $nNum2 = _netcode_UseNonCallbackEvent($hMyClient, 'NonCallback', 'RandomMinMax', _netcode_sParams(0, 99))
$nNum2 = $nNum2[2]
ConsoleWrite("$nNum2 = " & $nNum2 & @CRLF)


; calculate $nNum1 ^ 2
$nNum1 = _netcode_UseNonCallbackEvent($hMyClient, 'NonCallback', 'NumX2', $nNum1)
$nNum1 = $nNum1[2]
ConsoleWrite("$nNum1 ^ 2 = " & $nNum1 & @CRLF)


; add Num 1 to Num 2
Local $nResult = _netcode_UseNonCallbackEvent($hMyClient, 'NonCallback', 'AddNum', _netcode_sParams($nNum1, $nNum2))
$nResult = $nResult[2]
ConsoleWrite("$nNum1 + $nNum2 = " & $nResult & @CRLF)


; shutdown netcode
_netcode_Shutdown()
