#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\_netcode_Core.au3"

; declare the ip of the computer that you want to scan
Local $sIP = "127.0.0.1"

; define the port range to start from
Local $nPortRangeStart = 1

; define the port range to stop at
Local $nPortRangeStop = 1000

; opens a file handle for the log
Global $__hLog = FileOpen(@ScriptDir & "\log.txt", 1)

; the script makes a 50ms pause after each connect call, so that neither your computer, nor the target computer gets spammed.
; that sleep can be disabled by setting this to True.
Local $bGoInsane = False

; startup _netcode
_netcode_Startup()

; preset two events for each new socket
_netcode_PresetEvent("connection", "_Event_Connection")
_netcode_PresetEvent("disconnected", "_Event_Disconnect")

; some locals
Local $hSocket = 0, $arClients[0]




For $i = $nPortRangeStart To $nPortRangeStop

	; connect non blocking
	$hSocket = _netcode_TCPConnect($sIP, $i, True, "", "", True)

	; store the port to the socket
	_netcode_SocketSetVar($hSocket, 'port', $i)

	; read how much pending sockets we currently have
	$arClients = __netcode_ParentGetNonBlockingConnectClients("000")

	; log that to the console
	ConsoleWrite(@TAB & @TAB & "Pending Sockets: " & UBound($arClients) & @TAB & " Progress: " & $i & " / " & $nPortRangeStop & @CRLF)

	; call the loop to check the pending sockets
	_netcode_Loop("000")

	; sleep a little, so that we dont spam our OS or the other computer. Comment it if you want to go insane
	If Not $bGoInsane Then Sleep(50)
Next


; wait until all connections got closed
While _netcode_Loop("000")
	Sleep(10)
WEnd

; then close the file handle
FileClose($__hLog)

; shutdown _netcode
_netcode_Shutdown()

; done




Func _Event_Connection(Const $hSocket, $sStage)

	; get the port
	Local $nPort = _netcode_SocketGetVar($hSocket, 'port')

	; write it to the console
	ConsoleWrite("+ Successfully Connected @ Port: " & $nPort & @CRLF)

	; and to the file
	FileWrite($__hLog, $nPort & @CRLF)

	; disconnect the socket
	_netcode_TCPDisconnect($hSocket)
EndFunc

Func _Event_Disconnect(Const $hSocket, $x, $y)

	; get the port
	Local $nPort = _netcode_SocketGetVar($hSocket, 'port')

	; write it to the console
	ConsoleWrite("!Could not Connect @ Port: " & $nPort & @CRLF)

EndFunc