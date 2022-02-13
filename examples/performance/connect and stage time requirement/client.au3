#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\_netcode_Core.au3"

; define the amount of times to connect and stage through
Local $nTestAmount = 100

; startup _netcode
_netcode_Startup()
$__net_bTraceEnable = False

; preset events that lead to the void, so that these
; otherwise default events dont log information to the console.
_netcode_PresetEvent('connection', "_Void")
_netcode_PresetEvent('disconnected', "_Void")

Local $hTimer = 0, $nTime = 0, $hSocket = 0

For $i = 1 To $nTestAmount

	; init timer
	$hTimer = TimerInit()

	; connect and stage
	$hSocket = _netcode_TCPConnect("127.0.0.1", 1225)

	; save the time it took
	$nTime += TimerDiff($hTimer)

	; disconnect.
	; it doesnt matter how many clients the server has. What matters
	; is how many of them are Active. See the UDF header for a describtion of
	; inactive and active clients.
	_netcode_TCPDisconnect($hSocket)

Next

; display results
ConsoleWrite($nTestAmount & " Connect and Stage throughs took " & $nTime & " ms " & Round($nTime / $nTestAmount, 2) & " ms/avg" & @CRLF)

; shutdown
_netcode_Shutdown()


Func _Void(Const $hSocket, $p1 = Null, $p2 = Null, $p3 = Null)
EndFunc