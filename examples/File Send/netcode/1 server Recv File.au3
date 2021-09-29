#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include-once
#include "..\..\..\_netcode_Core.au3"

Global $___nServerIP = "0.0.0.0"
Global $___nServerPort = 1225
Global $___hServerSocket
Global $___sfDownloadDir = @ScriptDir & "\Downloads"
Global $___hMeassurementTimer

_netcode_Startup()

_netcode_PresetEvent("FileTransfer", "_On_FileTransfer")
_netcode_PresetEvent("connection", "_NewClientConnection")
_netcode_PresetEvent("disconnected", "_ClientDisconnect")

$___hServerSocket = _netcode_TCPListen($___nServerPort, $___nServerIP, Default, 1)
if @error Then Exit
;~ _netcode_SetOption($___hServerSocket, "Encryption", True)

ConsoleWrite("File Download Server Up" & @CRLF)

While True
	_netcode_Loop($___hServerSocket)
WEnd


Func _On_FileTransfer(Const $hSocket, $sData, $sOptional = "")
	Local Static $sfFilePath = "", $hFileHandle, $bRegistered = False, $nFileSize = 0, $nAlreadyTransmitted = 0
	Local $arData = StringSplit($sData, '|', 1 + 2)

	Switch $arData[0]
		Case "Register" ; 1 = FileName | 2 = FileSize
			$___hMeassurementTimer = TimerInit()
			; check for \..\
			$sfFilePath = $___sfDownloadDir & "\" & $arData[1]
			$nFileSize = $arData[2]
			$hFileHandle = FileOpen($sfFilePath, 18)
			$bRegistered = True
			_netcode_TCPSend($hSocket, 'FileTransfer', 'OK')
			ConsoleWrite("Download Registered " & $arData[1] & " with size " & Round($arData[2] / 1024, 2) & ' KB' & @CRLF)

		Case "Stream"
			$sOptional = StringToBinary($sOptional)
			FileWrite($hFileHandle, $sOptional)
			$nLen = StringLen($sOptional) / 2
			$nAlreadyTransmitted += $nLen ; because binary
			ConsoleWrite("Received " & Round($nLen / 1024, 2) & " KB" & @TAB & '~ ' & $nAlreadyTransmitted & ' / ' & $nFileSize & @CRLF)
;~ 			$arTmp = _Io_GetLastMeassurements()
;~ 			ConsoleWrite($hSocket & " from Recv to FireEvent Call() took: " & Round($arTmp[1][1], 2) & ' ms' & @CRLF)

		Case "Done"
			FileClose($hFileHandle)
			$bRegistered = False
			$nAlreadyTransmitted = 0
			_netcode_TCPSend($hSocket, 'FileTransfer', "Done")
			ConsoleWrite("Download Finished" & @CRLF)
;~ 			ConsoleWrite("Took " & Round(TimerDiff($___hMeassurementTimer) / 1000, 2) & ' Seconds' & @TAB & _Crypt_HashFile($sfFilePath, $CALG_MD5) & @CRLF)
			ConsoleWrite("Took " & Round(TimerDiff($___hMeassurementTimer) / 1000, 2) & ' Seconds' & @TAB & Round(($nFileSize / Round(TimerDiff($___hMeassurementTimer) / 1000, 2)) / 1048576, 2) & ' MB/s' & @CRLF)
;~ 			Exit

	EndSwitch
EndFunc




Func _NewClientConnection(Const $hSocket, $nStage)
	if $nStage <> 10 Then Return
	ConsoleWrite("New Client at: " & $hSocket & @CRLF)
EndFunc

Func _ClientDisconnect(Const $hSocket)
	ConsoleWrite("Client Disconnected: " & $hSocket & @CRLF)
EndFunc
