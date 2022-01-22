#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\_netcode_Core.au3"

; toggle this to enable encryption
Local $bEncryption = False


_netcode_Startup()
$__net_bTraceEnable = False
_netcode_PresetEvent("connection", "_NewConnection")
_netcode_PresetEvent("message", "_Message")

Global $hServerSocket = _netcode_TCPListen(1225, '0.0.0.0', Default, 1000)
_netcode_SetOption($hServerSocket, "Encryption", $bEncryption)


Global $hTimerSecond = TimerInit()
Global $hTimer = TimerInit()
While _netcode_Loop($hServerSocket)
	if TimerDiff($hTimerSecond) > 1000 Then
		ConsoleWrite(@TAB & @TAB & @TAB & "Loop Time: " & Round(TimerDiff($hTimer), 2) & " ms" & @TAB & @TAB & _netcode_ParentGetClients($hServerSocket, True) & " Clients" & @TAB)
		ConsoleWrite("RECV: " & _netcode_SocketGetRecvBytesPerSecond($hServerSocket, 2) & " MB/s    SEND: " & _netcode_SocketGetSendBytesPerSecond($hServerSocket, 2) & " MB/s" & @TAB & @TAB)
		ConsoleWrite("RECV: " & _netcode_SocketGetRecvPacketPerSecond($hServerSocket) & " p/s    SEND: " & _netcode_SocketGetSendPacketPerSecond($hServerSocket) & " p/s" & @CRLF)
		$hTimerSecond = TimerInit()
	EndIf
	$hTimer = TimerInit()
WEnd

Func _NewConnection(Const $hSocket, $sStage)
	ConsoleWrite("New Socket @ " & $hSocket & " @ Stage " & $sStage & @CRLF)
EndFunc

Func _Message(Const $hSocket, $sData)
	; nothing
EndFunc