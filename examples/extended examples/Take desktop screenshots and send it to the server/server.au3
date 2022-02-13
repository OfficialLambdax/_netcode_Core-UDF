#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Au3stripper_OnError=ForceUse
#Au3Stripper_Ignore_Funcs=_net_*
#include-once
#include "..\..\..\_netcode_Core.au3"
#include "_screenshot.au3"
#include <ButtonConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
Opt("GUIOnEventMode", 1)


; startup netcode
_netcode_Startup()

; startup listener
Local $hMyParent = _netcode_TCPListen(1225, '0.0.0.0', Default, 10)
if Not $hMyParent Then Exit MsgBox(16, "Server Error", "Could not startup listener")

; add events
_netcode_SetEvent($hMyParent, 'connection', "_Event_Connection")
_netcode_SetEvent($hMyParent, 'disconnected', "_Event_Disconnected")
_netcode_SetEvent($hMyParent, 'SetPicture', "_Event_SetPicture")

; timer
Local $hTimer = TimerInit()


; loop parent
While True
	_netcode_Loop($hMyParent)

	; eco mode if no client is connected
	if _netcode_ParentGetClients($hMyParent, True) = 0 Then
		Sleep(50)
	Else
		if TimerDiff($hTimer) > 5000 Then
			ConsoleWrite("Receiving: " & _netcode_SocketGetRecvBytesPerSecond($hMyParent, 2) & " MB/s" & @CRLF)

			$hTimer = TimerInit()
		EndIf
	EndIf
WEnd



; sets the send pictures to the gui of the socket
Func _Event_SetPicture(Const $hSocket, $sPicture)
	Local $fPicture = _netcode_SocketGetVar($hSocket, 'Picture')

	_Screenshot_DrawOnGUi($fPicture, Binary($sPicture))
EndFunc

; creates the gui
Func _Event_Connection(Const $hSocket, $sStage)

	if $sStage = 'auth' Then ConsoleWrite("New Connection @ Socket " & $hSocket & @CRLF)

	if $sStage <> 'netcode' Then Return

	; create gui
	Local $fMain = GUICreate("Desktop Picture for @ " & $hSocket, 615, 454, -1, -1, BitOR($gui_ss_default_gui, $ws_maximizebox, $ws_thickframe, $ws_tabstop)) ; , $ws_sizebox
	Local $fbToggle = GUICtrlCreateButton("Start", 8, 8, 75, 25)
	Local $fbDisconnect = GUICtrlCreateButton("Disconnect", 96, 8, 75, 25)
	Local $arParentPos = WinGetPos($fMain)
	Local $fPicture = GUICreate("TEST", $arParentPos[2] - 30, $arParentPos[3] - 105, -1, 50, $ws_popup, $ws_ex_mdichild, $fMain) ;$ws_popup

	; store gui variables
	_netcode_SocketSetVar($hSocket, 'Main', $fMain)
	_netcode_SocketSetVar($hSocket, 'Picture', $fPicture)

	; store socket to buttons
	_storageG_Overwrite($fbToggle, '_GUI_Socket', $hSocket)
	_storageG_Overwrite($fbDisconnect, '_GUI_Socket', $hSocket)

	; store button types
	_storageG_Overwrite($fbToggle, '_GUICTRL_Type', "Toggle")
	_storageG_Overwrite($fbDisconnect, '_GUICTRL_Type', "Disconnect")

	; register gui events
	GUICtrlSetOnEvent($fbToggle, "_GuiEvent_ButtonPress")
	GUICtrlSetOnEvent($fbDisconnect, "_GuiEvent_ButtonPress")

	; show gui
	GUISetState(@SW_SHOW, $fMain)
	GUISetState(@SW_SHOW, $fPicture)

EndFunc

; deletes the gui
Func _Event_Disconnected(Const $hSocket, $nError, $bIntended)

	ConsoleWrite("Socket @ " & $hSocket & " disconnected" & @CRLF)

	Local $fMain = _netcode_SocketGetVar($hSocket, 'Main')

	GUIDelete($fMain)

EndFunc



Func _GuiEvent_ButtonPress()

	Local $hPressedControl = @GUI_CtrlId
	Local $hSocket = _storageG_Read($hPressedControl, '_GUI_Socket')

	Switch _storageG_Read($hPressedControl, '_GUICTRL_Type')

		Case "Toggle"
			_netcode_TCPSend($hSocket, 'Toggle')

			if GUICtrlRead($hPressedControl) == "Start" Then
				GUICtrlSetData($hPressedControl, "Stop")
			Else
				GUICtrlSetData($hPressedControl, "Start")
			EndIf


		Case "Disconnect"
			_netcode_TCPSend($hSocket, 'Close')


	EndSwitch

EndFunc


