#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\_netcode_Core.au3"


Global $__nPacketSize = 1048576 * 0.3 ; bytes - 1048576 is 1 MB
Global $__nServerPort = 1225
Global $__hServerSocket = False
Global $__hTimer = TimerInit()
Global $__hTimerSecond = TimerInit()
Global $__sData = ""

For $i = 1 To $__nPacketSize
	$__sData &= "1"
Next

_netcode_Startup()
$__net_bTraceEnable = False
_netcode_PresetEvent("getdata", "_Event_GetData")
_netcode_PresetEvent("connection", "_Event_Connection")

$__hServerSocket = _netcode_TCPListen($__nServerPort, "0.0.0.0", Default, 5000)
if Not $__hServerSocket Then Exit MsgBox(16, "Error", "Could not open Port. Exiting")
;~ _netcode_SetOption($__hServerSocket, "Encryption", True)

Local $sText = ""

While _netcode_Loop($__hServerSocket)
	if TimerDiff($__hTimerSecond) > 1000 Then

		$sText = @TAB & @TAB & "Loop time: " & Round(TimerDiff($__hTimer), 2) & " ms"
		$sText &= @TAB & @TAB & "Client amount: " & _netcode_ParentGetClients($__hServerSocket, True)
		$sText &= @TAB & "D: " & _netcode_SocketGetRecvBytesPerSecond($__hServerSocket, 2) & " MB/s"
		$sText &= @TAB & "U: " & _netcode_SocketGetSendBytesPerSecond($__hServerSocket, 2) & " MB/s"

		ConsoleWrite($sText & @CRLF)
		$__hTimerSecond = TimerInit()
	EndIf
	$__hTimer = TimerInit()
WEnd

Func _Event_GetData(Const $hSocket)
	_netcode_TCPSend($hSocket, "postdata", $__sData)
EndFunc

Func _Event_Connection(Const $hSocket, $sStage)
;~ 	if $sStage <> 'netcode' Then Return
;~ 	ConsoleWrite("New Socket @ " & $hSocket & @CRLF)
EndFunc

