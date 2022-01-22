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

; create a global for the buttons
Global $__arSocketGuiButtons[0][3] ; socket | toggle button | disconnect button


; startup netcode
_netcode_Startup()

; startup listener
Local $hMyParent = _netcode_TCPListen(1225, '0.0.0.0', Default, 10)
if Not $hMyParent Then Exit MsgBox(16, "Server Error", "Could not startup listener")

; add events
_netcode_SetEvent($hMyParent, 'connection', "_Event_Connection")
_netcode_SetEvent($hMyParent, 'disconnected', "_Event_Disconnected")
_netcode_SetEvent($hMyParent, 'SetPicture', "_Event_SetPicture")



; loop parent
While True
	_netcode_Loop($hMyParent)

	; eco mode if no client is connected
	if _netcode_ParentGetClients($hMyParent, True) = 0 Then
		Sleep(50)
	Else
		_Internal_CatchButtonPress()
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

	; register buttons to guigetmsg sub function
	_Internal_AddButtons($hSocket, $fbToggle, $fbDisconnect)

	; store gui variables
	_netcode_SocketSetVar($hSocket, 'Main', $fMain)
	_netcode_SocketSetVar($hSocket, 'Toggle', $fbToggle)
	_netcode_SocketSetVar($hSocket, 'Disconnect', $fbDisconnect)
	_netcode_SocketSetVar($hSocket, 'Picture', $fPicture)

	; show gui
	GUISetState(@SW_SHOW, $fMain)
	GUISetState(@SW_SHOW, $fPicture)

EndFunc

; deletes the gui
Func _Event_Disconnected(Const $hSocket, $nError, $bIntended)

	ConsoleWrite("Socket @ " & $hSocket & " disconnected" & @CRLF)

	Local $fMain = _netcode_SocketGetVar($hSocket, 'Main')

	GUIDelete($fMain)

	_Internal_DeleteButtons($hSocket)

EndFunc

; switches the buttons
Func _Internal_CatchButtonPress()

	Local $hGuiMsg = GUIGetMsg()
	If Not $hGuiMsg Then Return

	if $hGuiMsg = $GUI_EVENT_CLOSE Then Exit ; exit the program

	For $i = 0 To UBound($__arSocketGuiButtons) - 1

		if $__arSocketGuiButtons[$i][1] = $hGuiMsg Then ; if toggle button
			_netcode_TCPSend($__arSocketGuiButtons[$i][0], 'Toggle')

			if GUICtrlRead($__arSocketGuiButtons[$i][1]) = "Start" Then
				GUICtrlSetData($__arSocketGuiButtons[$i][1], "Stop")
			Else
				GUICtrlSetData($__arSocketGuiButtons[$i][1], "Start")
			EndIf

		ElseIf $__arSocketGuiButtons[$i][2] = $hGuiMsg Then ; if disconnect button
			_netcode_TCPSend($__arSocketGuiButtons[$i][0], 'Close')

		EndIf

	Next

EndFunc

Func _Internal_AddButtons($hSocket, $fbToggle, $fbDisconnect)
	Local $nArSize = UBound($__arSocketGuiButtons)

	ReDim $__arSocketGuiButtons[$nArSize + 1][3]
	$__arSocketGuiButtons[$nArSize][0] = $hSocket
	$__arSocketGuiButtons[$nArSize][1] = $fbToggle
	$__arSocketGuiButtons[$nArSize][2] = $fbDisconnect
EndFunc

Func _Internal_DeleteButtons($hSocket)
	Local $nArSize = UBound($__arSocketGuiButtons)

	Local $nIndex = -1
	For $i = 0 To $nArSize - 1
		if $__arSocketGuiButtons[$i][0] = $hSocket Then
			$nIndex = $i
			ExitLoop
		EndIf
	Next

	if $nIndex = -1 Then Return

	$__arSocketGuiButtons[$nIndex][0] = $__arSocketGuiButtons[$nArSize - 1][0]
	$__arSocketGuiButtons[$nIndex][1] = $__arSocketGuiButtons[$nArSize - 1][1]
	$__arSocketGuiButtons[$nIndex][2] = $__arSocketGuiButtons[$nArSize - 1][2]

	ReDim $__arSocketGuiButtons[$nArSize - 1][3]
EndFunc