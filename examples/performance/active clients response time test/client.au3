#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\_netcode_Core.au3"
#cs
	Whenever the Server Responds with data we request the next and meassure how long it takes
	until we get the next data.
#ce

; connect to this ip
Global $__sServerIP = "127.0.0.1"

; and to this port
Global $__nServerPort = 1225

; set how many clients to connect
Global $__nSocketAmount = 1000

; internal
Global $__arClients[$__nSocketAmount][2] ; socket | timer handle



; startup _netcode
_netcode_Startup()
$__net_bTraceEnable = False


; preset event
_netcode_PresetEvent("connection", "_Event_Connection")

; connect all clients
ConsoleWrite("Connecting Sockets.." & @CRLF)
For $i = 0 To $__nSocketAmount - 1
	$__arClients[$i][0] = _netcode_TCPConnect($__sServerIP, $__nServerPort)

	; add events
	_netcode_SetEvent($__arClients[$i][0], 'postdata', "_Event_GotData")

	; add index to storage
	_storageG_Overwrite($__arClients[$i][0], '_ArrayIndex', $i)
Next

; request data for each and every socket and start a timer
ConsoleWrite("Trigger Data Send" & @CRLF)
For $i = 0 To $__nSocketAmount - 1
	_netcode_TCPSend($__arClients[$i][0], 'getdata')
	$__arClients[$i][1] = TimerInit()
Next

; main
While _netcode_Loop("000")
WEnd



; events

; the server responded, now check how long it took with all sockets beging active
Func _Event_GotData(Const $hSocket, $sData)
	Local $nIndex = _storageG_Read($hSocket, '_ArrayIndex')

	ConsoleWrite($hSocket & " Data Request took " & Round(TimerDiff($__arClients[$nIndex][1]), 2) & " ms" & @CRLF)

	; trigger another send right here
	_netcode_TCPSend($hSocket, 'getdata')
	$__arClients[$nIndex][1] = TimerInit()
EndFunc

Func _Event_Connection(Const $hSocket, $sStage)
	if $sStage <> 'netcode' Then Return
	ConsoleWrite("New Socket @ " & $hSocket & @CRLF)
EndFunc