#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\..\_netcode_Core.au3"


; startup _netcode
_netcode_Startup()
$__net_bTraceEnable = False

; startup test server
Local $hMyParent = _netcode_TCPListen(1225)
If Not $hMyParent Then Exit MsgBox(16, "Error", "Could not startup Listener")

; preset events that lead to the void, so that these
; otherwise default events dont log information to the console.
_netcode_SetEvent($hMyParent, 'connection', "_Void")
_netcode_SetEvent($hMyParent, 'disconnected', "_Void")

; loop
While True
	_netcode_Loop($hMyParent)
WEnd


Func _Void(Const $hSocket, $p1 = Null, $p2 = Null, $p3 = Null)
EndFunc