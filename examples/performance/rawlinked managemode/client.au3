#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\_netcode_Core.au3"

Local $hClientSocket = False

_netcode_Startup()
_netcode_PresetEvent("connection", "_NewConnection")


While $hClientSocket = False
	$hClientSocket = _netcode_TCPConnect('127.0.0.1', 1225)
	Sleep(100)
WEnd

_netcode_SetOption($hClientSocket, 'AllowSocketLinkingRequest', True)
Do
	_netcode_Loop("000")
Until _netcode_CheckLink($hClientSocket, "hiwh")

Local $hLinkSocket = _netcode_CheckLink($hClientSocket, "hiwh")

Local $sSend = ''
For $i = 1 To 1048576 * 0.1
	$sSend &= '1'
Next
ConsoleWrite("Start sending" & @CRLF)

Local $hTimerSecond = TimerInit()
While _netcode_Loop("000")
	_netcode_TCPSendRaw($hLinkSocket, $sSend)
	if TimerDiff($hTimerSecond) > 1000 Then
		ConsoleWrite("RECV: " & _netcode_SocketGetRecvBytesPerSecond($hLinkSocket, 2) & " MB/s" & @TAB & @TAB & "SEND: " & _netcode_SocketGetSendBytesPerSecond($hLinkSocket, 2) & " MB/s" & @CRLF)
		$hTimerSecond = TimerInit()
	EndIf
WEnd

Func _NewConnection(Const $hSocket, $nStage, $vData)
	ConsoleWrite("New Socket @ " & $hSocket & " @ Stage " & $nStage & @CRLF)
EndFunc