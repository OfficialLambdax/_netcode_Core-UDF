#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\_netcode_Core.au3"

; set how large the data will be that the server sends to each client on request
Global $__nPacketSize = 1048576 * 0.3 ; bytes - 1048576 is 1 MB

; set server port
Global $__nServerPort = 1225

; set if you want to use encryption
Local $bEnableEncryption = False


; internals
Global $__hTimer = TimerInit()
Global $__hTimerSecond = TimerInit()
Global $__sData = ""


; create data set
For $i = 1 To $__nPacketSize
	$__sData &= "1"
Next

; startup _netcode
_netcode_Startup()
$__net_bTraceEnable = False

; startup listener
Global $__hServerSocket = _netcode_TCPListen($__nServerPort, "0.0.0.0", Default, 5000)
if Not $__hServerSocket Then Exit MsgBox(16, "Error", "Could not open Port. Exiting")

; set options
_netcode_SetOption($__hServerSocket, "Encryption", $bEnableEncryption)

; add events
_netcode_SetEvent($__hServerSocket, 'getdata', "_Event_GetData")
_netcode_SetEvent($__hServerSocket, 'connection', "_Event_Connection")

; local for consolewrite
Local $sText = ""


; main
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




; events
Func _Event_GetData(Const $hSocket)
	_netcode_TCPSend($hSocket, "postdata", $__sData)
EndFunc

Func _Event_Connection(Const $hSocket, $sStage)
	; nothing
EndFunc

