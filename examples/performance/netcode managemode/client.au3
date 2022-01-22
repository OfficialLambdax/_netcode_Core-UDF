#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\_netcode_Core.au3"

Local $hClientSocket = False

_netcode_Startup()
$__net_bTraceEnable = False
_netcode_PresetEvent("connection", "_NewConnection")


While $hClientSocket = False
	$hClientSocket = _netcode_TCPConnect('127.0.0.1', 1225)
	Sleep(100)
WEnd


Local $sSend = ''
For $i = 1 To 1048576 * 0.3
	$sSend &= '1'
Next
ConsoleWrite("Start sending: " & StringLen($sSend) & @CRLF)

Local $hTimerSecond = TimerInit()
While _netcode_Loop($hClientSocket)
	_netcode_TCPSend($hClientSocket, "message", $sSend)
	if TimerDiff($hTimerSecond) > 1000 Then
		ConsoleWrite("RECV: " & _netcode_SocketGetRecvBytesPerSecond($hClientSocket, 2) & " MB/s" & @TAB & @TAB & "SEND: " & _netcode_SocketGetSendBytesPerSecond($hClientSocket, 2) & " MB/s" & @TAB & @TAB & _netcode_SocketGetSendPacketPerSecond($hClientSocket) & " p/s" & @CRLF)
		$hTimerSecond = TimerInit()
	EndIf
WEnd

Func _NewConnection(Const $hSocket, $sStage)
	ConsoleWrite("New Socket @ " & $hSocket & " @ Stage " & $sStage & @CRLF)
EndFunc