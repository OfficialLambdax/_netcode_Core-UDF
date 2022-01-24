#NoTrayIcon
#include "..\..\..\_netcode_Core.au3"

; startup _netcode
_netcode_Startup()


; setup listener
Local $hMyParent = _netcode_TCPListen(1225)
if Not $hMyParent Then Exit MsgBox(16, "Server Error", "Cannot start listener at port 1225")

; add events
_netcode_SetEvent($hMyParent, 'Random', "_MyEvent_Random")
_netcode_SetEvent($hMyParent, 'NumX2', "_MyEvent_NumX2")
_netcode_SetEvent($hMyParent, 'RandomMinMax', "_MyEvent_RandomMinMax")
_netcode_SetEvent($hMyParent, 'AddNum', "_MyEvent_AddNum")




; main
While Sleep(10)
	_netcode_Loop($hMyParent)
WEnd



; some random number
Func _MyEvent_Random(Const $hSocket)
	_netcode_TCPSend($hSocket, 'NonCallback', String(Random(0, 1000, True)))
EndFunc

; Returns $nNum ^ 2
Func _MyEvent_NumX2(Const $hSocket, $nNum)
	$nNum = Number($nNum)

	_netcode_TCPSend($hSocket, 'NonCallback', String($nNum ^ 2))
EndFunc

; creates a random number between the given min and max and returns it
Func _MyEvent_RandomMinMax(Const $hSocket, $nMin, $nMax)
	$nMin = Number($nMin)
	$nMax = Number($nMax)

	_netcode_TCPSend($hSocket, 'NonCallback', String(Random($nMin, $nMax, True)))
EndFunc

; adds x + y and returns the result
Func _MyEvent_AddNum(Const $hSocket, $nX, $nY)
	$nX = Number($nX)
	$nY = Number($nY)

	_netcode_TCPSend($hSocket, 'NonCallback', String($nX + $nY))
EndFunc