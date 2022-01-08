#NoTrayIcon
#include <ScreenCapture.au3>
#include <GDIPlus.au3>
#include <WinAPIHObj.au3>
#include <Memory.au3>

_GDIPlus_Startup()

#cs
_Screenshot_LittleExample()
Func _Screenshot_LittleExample()
	$ws_popup = -2147483648
	$ws_ex_mdichild = 64
	$ws_maximizebox = 65536
	$ws_minimizebox = 131072
	$ws_sizebox = 262144
	$ws_thickframe = $ws_sizebox
	$ws_tabstop = 65536
	$ws_caption = 12582912
	$ws_sysmenu = 524288
	$gui_ss_default_gui = BitOR($ws_minimizebox, $ws_caption, $ws_popup, $ws_sysmenu)
	$gui_dockleft = 2
	$gui_docktop = 32
	$gui_dockwidth = 256
	$gui_dockheight = 512
	$wm_size = 5
	$gui_rundefmsg = "GUI_RUNDEFMSG"
	$gui_event_close = -3

	GUIRegisterMsg($wm_size, "_Screenshot_wm_size")

	Local $nCountLast = 0
	Local $nCountAct = 0
	Local $hCountTimer = TimerInit()

	Global $___hGuiParent = GUICreate("Test", 500, 500, -1, -1, BitOR($gui_ss_default_gui, $ws_maximizebox, $ws_sizebox, $ws_thickframe, $ws_tabstop))
	$aparentpos = WinGetPos($___hGuiParent)
	Global $___hGuiChild = GUICreate("RDWINDOW", $aparentpos[2] - 25, $aparentpos[3] - 120, 0, 55, $ws_popup, $ws_ex_mdichild, $___hGuiParent)
	GUISetState(@SW_SHOW, $___hGuiParent)
	GUISetState(@SW_SHOW, $___hGuiChild)


	While True
		if GUIGetMsg() = $GUI_EVENT_CLOSE Then Exit

		if TimerDiff($hCountTimer) > 1000 Then
			$nCountLast = $nCountAct
			$nCountAct = 0
			$hCountTimer = TimerInit()
		EndIf

		$nCountAct += 1
		ConsoleWrite("This much Images per Second " & $nCountLast & @CRLF)

		$sImage = _Screenshot_ReturnData(20)
		_Screenshot_DrawOnGUi($___hGuiChild, $sImage)
	WEnd
EndFunc

Func _Screenshot_wm_size($hwnd, $imsg, $wparam, $lparam)
	$hgui = $___hGuiParent
	$hchildgui = $___hGuiChild
	If $hchildgui = "" Then Return "GUI_RUNDEFMSG"
	If WinActive($hgui) Then
		$aparentpos = WinGetPos($hgui)
		If IsArray($aparentpos) Then
			WinMove($hchildgui, "", $aparentpos[0] + 10, $aparentpos[1] + 110, $aparentpos[2] - 25, $aparentpos[3] - 120)
			$tempchildpos = WinGetPos($hchildgui)
		EndIf
	EndIf
	Return "GUI_RUNDEFMSG"
EndFunc
#ce

Func _Screenshot_DrawOnGUi($hGUi, $sImage)
	$hgraphic = _gdiplus_graphicscreatefromhwnd($hGUi)
	$hbitmap = _gdiplus_bitmapcreatefrommemory($sImage)

	$aGuiPos = WinGetPos($hGUi)
;~ 	WinMove($hgraphic, "", $aGuiPos[0], $aGuiPos[1], $aGuiPos[2], $aGuiPos[3])

	$hbitmap_scaled = _gdiplus_imageresize($hbitmap, $aGuiPos[2], $aGuiPos[3])
	_gdiplus_graphicsdrawimage($hgraphic, $hbitmap_scaled, 0, 0)

	_gdiplus_graphicsdispose($hgraphic)
	_gdiplus_bitmapdispose($hbitmap)
	_gdiplus_bitmapdispose($hbitmap_scaled)
EndFunc


Func _Screenshot_ReturnData($nQuality, $ileft = 0, $itop = 0, $iright = -1, $ibottom = -1)
;~ 	_GDIPlus_Startup()

	Local $hbitmap = _screencapture_capture("", $ileft, $itop, $ileft + $iright, $itop + $ibottom)
	Local $himage = _gdiplus_bitmapcreatefromhbitmap($hbitmap)
	Local $bimage = _Screenshot_streamimage2binarystring($himage, "JPG", $nQuality)
	_winapi_deleteobject($hbitmap)
	_gdiplus_imagedispose($himage)

	Return $bimage
EndFunc

Func _Screenshot_streamimage2binarystring($hbitmap, $sformat, $iquality)
	Local $simgclsid, $tguid, $tparams
	Switch $sformat
		Case "JPG"
			$simgclsid = _gdiplus_encodersgetclsid($sformat)
			$tguid = _winapi_guidfromstring($simgclsid)
			Local $tdata = DllStructCreate("int Quality")
			DllStructSetData($tdata, "Quality", $iquality)
			Local $pdata = DllStructGetPtr($tdata)
			$tparams = _gdiplus_paraminit(1)
			_gdiplus_paramadd($tparams, $gdip_epgquality, 1, $gdip_eptlong, $pdata)
		Case "PNG", "BMP", "GIF", "TIF"
			$simgclsid = _gdiplus_encodersgetclsid($sformat)
			$tguid = _winapi_guidfromstring($simgclsid)
		Case Else
			Return SetError(1, 0, 0)
	EndSwitch
	Local $hstream = _winapi_createstreamonhglobal()
	If @error Then Return SetError(2, 0, 0)
	_gdiplus_imagesavetostream($hbitmap, $hstream, DllStructGetPtr($tguid), DllStructGetPtr($tparams))
	If @error Then Return SetError(3, 0, 0)
	_gdiplus_bitmapdispose($hbitmap)
	Local $hmemory = _winapi_gethglobalfromstream($hstream)
	If @error Then Return SetError(4, 0, 0)
	Local $imemsize = _memglobalsize($hmemory)
	If NOT $imemsize Then Return SetError(5, 0, 0)
	Local $pmem = _memgloballock($hmemory)
	$tdata = DllStructCreate("byte[" & $imemsize & "]", $pmem)
	Local $bdata = DllStructGetData($tdata, 1)
	_winapi_releasestream($hstream)
	_memglobalfree($hmemory)
	Return $bdata
EndFunc