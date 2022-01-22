#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
;~ #NoTrayIcon
#AutoIt3Wrapper_Au3stripper_OnError=ForceUse
#Au3Stripper_Ignore_Funcs=_net_*
#Au3Stripper_Ignore_Funcs=_Sync_*
#include-once
#include "..\..\..\_netcode_Core.au3"
#include "_screenshot.au3"
#include <ScreenCapture.au3>

; create global vars
Global $__bToggle = False

; startup netcode
_netcode_Startup()

; connect to server
Local $hMyClient = _netcode_TCPConnect('127.0.0.1', 1225)
if Not $hMyClient Then Exit MsgBox(16, "Client Error", "Could not connect to server")


; add events
_netcode_SetEvent($hMyClient, 'Toggle', "_Event_Toggle")
_netcode_SetEvent($hMyClient, 'Close', "_Event_Close")


; loop client
While True
	If Not _netcode_Loop($hMyClient) Then Exit

	if $__bToggle Then _netcode_TCPSend($hMyClient, 'SetPicture', BinaryToString(_Screenshot_ReturnData(20)))
WEnd


Func _Event_Toggle(Const $hSocket)
	if $__bToggle Then
		$__bToggle = False
	Else
		$__bToggle = True
	EndIf
EndFunc

Func _Event_Close(Const $hSocket)

	_netcode_Shutdown()
	Exit

EndFunc