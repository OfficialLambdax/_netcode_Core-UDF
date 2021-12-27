;~ #AutoIt3Wrapper_AU3Check_Parameters=-w 1 -w 2 -w 3 -w 4 -w 5 -w 6 ; shows errors that arent errors - i used __netcode_Au3CheckFix() to fix
#include-once
#include <Array.au3> ; For development
;~ Opt("MustDeclareVars", 1)
#cs

	Github
		https://github.com/OfficialLambdax/_netcode_Core-UDF

	Terminology
		Parent
			parents are all listening sockets. So if you call TCPListen the returned socket is a parent. Every incoming connection accepted with TCPAccept will be a Client of that parent.
			To make things more compatible and use less code and complexity every socket returned from TCPConnect also is a client socket. Its parent socket then is 000.
			If required you can check what the socket is by using __netcode_CheckSocket() 1 = parent, 2 = client, 0 = unknown to _netcode.
			And if you want to know if a Client Socket is from TCPListen or TCPConnect then use __netcode_ClientGetParent(). A return
			of 000 will indicate its from TCPConnect() a different return but 0 will indicate its from TCPAccept. If 0 is returned then
			the given socket isnt a client socket or just not known to _netcode.

		Known and Unknown Sockets
			_netcode only handles sockets that are known to it. All sockets created by _netcode or that are bind to it with _netcode_BindSocket()
			are managed and info about can be retrieved. If a socket is created outside of _netcode then _netcode wont be able to give any
			information about it. That is also true if the socket is released from _netcode with _netcode_ReleaseSocket().
			You can use __netcode_CheckSocket() to check if a socket is known or not and of what type it is (1 = parent, 2 = client, 0 = unknown to _netcode).

		Socket Holding
			Sockets can be set OnHold with _netcode_SetSocketOnHold(). _netcode will pause executing packets from Sockets that are OnHold.
			To be clear: Just not be executed, _netcode will still receive, unpack and store incoming packets. However only until the Buffer
			limit is reached. Every packet exceeding the buffer will be voided.


		Add Handshake modes
			- Diffie–Hellman key exchange with a default and _netcode_SetInternalOption() Pi list
			- Diffie–Hellman key exchange with a Pi list provided from a internet source without encryption
			- Diffie–Hellman key exchange with a Pi list provided from a internet source with a preshared AES key encryption
			- PreShared key
			- Transport Layer Security 1.2 (external dll in a seperated _netcode addin?)
			- Transport Layer Security 1.3 (external dll in a seperated _netcode addin?)
			-

		Add two new stages for Server and Client Verification
			- The Server should be able to verify that the client is authorized to connect.
			- The Client should be able to verify that the server it connected to is actually the server it wanted
				to connect to.
			https://de.wikipedia.org/wiki/X.509
			https://docs.microsoft.com/en-us/azure/iot-hub/tutorial-x509-introduction

	Known Bugs
		Mayor - Having a high $__net_nMaxRecvBufferSize can result in a Hang. Why?
			Bug appears in the file send example - have the maxmimum buffer set to 1048576 * 25 to experience the bug
			(Bug happens not so often, but when, its very bad)

	Remarks

		Stripping
			use #AutoIt3Wrapper_Au3stripper_OnError=ForceUse in your Script and add all Event Functions to a Anti Stripping function.
			See __netcode_EventStrippingFix()


#ce

#cs
	Credits

		Big Thanks to TheXman@autoitscript.com !
		Without his CryptoNG UDF (https://www.autoitscript.com/forum/files/file/490-cryptong-udf-cryptography-api-next-generation)
		it wouldnt been possible for me to make use of the Next Gen cryptography api. The complete encryption part of this UDF lies on top of his UDF.
		His UDF however got stripped down as much as possible to be used easier and faster within _netcode. Big thanks again.

		Another big Thanks to j0kky@autoitscript.com !
		Two functions from his winsock.au3 UDF are currently in use within this UDF.
		Note: both functions will be removed at some point once i had the time to code my own.

#ce

#cs
	License (This license is temporary)

		Copyright (c) 2021 OfficialLambdax@github.com

		Permission is hereby temporary granted, free of charge, to any person obtaining a copy of this software
		and associated documentation files (the "Software"), to deal in the Software without restriction,
		including without further limitation the rights to use, copy, modify, merge, publish, distribute,
		and/or sell copies of the Software subject to the following conditions:

		The above copyright notice and this permission notice shall be included in all copies or substantial
		portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
		NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
		IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
		WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
		SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

		Temporary means that your permission, as defined and granted above, will be fully revoked once either a newer or
		different license for this software is put in place or either once the License of this Software is removed.
		The new License then might grant new or similiar permissions. In order to check if this license and your
		permissions are terminated, you have to frequently check the Offical Software repository.

		Sublicensing is not granted.

		This license does not affect potions of the Software that where not made by the Author of this
		Software and are maybe / or will be differently licensed. These potions where adequately encased
		with #Region and #EndRegion statements. The authors of these potions can be located at the "Credits"
		section in the Software source code header.

#ce

; In General you will never set any of these Globaly by hand, but right now the Option Functions are unfinished. So changes here can be made.
; Beaware that most of these globals will be removed soon and linked to the parents and clients, so that each have their own options.
; Just Default Options will remain here and you will be able to set these in a specific Function.
; ===================================================================================================================================================
; General Settings

; maximum buffer size
Global $__net_nMaxRecvBufferSize = 1048576 * 5

; the default recv len
Global $__net_nDefaultRecvLen = 1048576 * 0.25 ; has to be smaller then $__net_nMaxRecvBufferSize

; __netcode_RecvPackages() will never take longer then this timeout is set to
Global $__net_nTCPRecvBufferEmptyTimeout = 20 ; ms

; Set default Seed. Ignore for now, it is not fully implemented yet
Global $__net_nNetcodeStringDefaultSeed = Number("50853881441621333029") ; %NotSet% - numbers only - note change to Integer

; set to True if you want the _netcode_sParam() to binarize all data. Will slow down the function by alot.
Global $__net_bParamSplitBinary = False

; will be obsolete. The client will no longer send the plain password to the server in the future but its hash and the max len will be set to the
; default hash len.
Global $__net_nMaxPasswordLen = 30 ; max password len for the User Stage. If the StringLen is > this then it will deny the login

; disable to use the unstable socket select packet confirmation instead of the receivers confirmation packet.
; will not improve performance, but reduces receivers load and its network usage. If False this Option will render certain packet safety options useless.
; packet loss is a certain effect if _netcode_SetSocketOnHold() is used. Packet resend duo to packet loss or corruption will not work either until the packet
; safety is overhauled. Both the server and the clients need this option to be the same, it is not synced.
Global $__net_bPacketConfirmation = True

; ===================================================================================================================================================
; Tracer

; enables the Tracer. Will slow down the UDF by about 5 %, but needs to be True if you want to use any of the options below.
; never toggle THIS option in your script or it might hard crash. All others can be toggled anytime.
Global $__net_bTraceEnable = False

; will log every call of a UDF function to the console in a ladder format. Will massively decrease the UDF speed because it floods the console.
Global $__net_bTraceLogEnable = False

; will log errors and extendeds to the console and their describtions. very usefull while developing
Global $__net_bTraceLogErrorEnable = True

; will save all errors, its extendeds and further information to an array. Array can be looked at with _ArrayDisplay()
Global $__net_bTraceLogErrorSaveToArray = False

; each and every function becomes a Timer set to it. Once the function is done the Tracer outputs the time it took to finish the function.
; this is mostly a development function to see where things take long and to see what can be improved.
Global $__net_bTraceEnableTimers = False

; =======================================================================
; Tracer dont change
Global $__net_arTraceLadder[0][2] ; func name | timer
Global $__net_arTraceErrors[0][9] ; date | time | funcname | error code | extended code | error desc | extended desc | additional data | additional data

; ===================================================================================================================================================
; Internals dont change
Global $__net_arSockets[0] ; parent sockets
Global $__net_hWs2_32 = -1 ; Ws2_32.dll handle
Global $__net_sAuthNetcodeString = 'iT0325873JoWv5FVOY3' ; this string indicates to the server that a _netcode client is connecting
Global $__net_sAuthNetcodeConfirmationString = '09iCKqRh80D27' ; the server then responds with this, confirming to the client that it is a _netcode server.
Global $__net_sPacketBegin = '8NoguKX5UB' ; always 10 bytes long
Global $__net_sPacketInternalSplit = 'c3o8197sT6' ; 10 bytes
Global $__net_sPacketEnd = 'YWy44X03PF' ; 10 bytes
Global $__net_arDefaultEventsForEachNewClientSocket[0][2]
Global $__net_sParamSplitSeperator = 'eUwc99H4Vc' ; 10 bytes
Global $__net_sParamIndicatorString = 'NDs2GA59Wj' ; 10 bytes
Global $__net_sSerializationIndicator = '4i8lwnpc6w' ; 10 bytes - keep them always exactly 10 bytes long
Global $__net_sSerializeArrayIndicator = '6v934Y71fS' ; 10 bytes
Global $__net_sSerializeArrayYSeperator = '152b7l27E6' ; 10 bytes
Global $__net_sSerializeArrayXSeperator = '3615RW0117' ; 10 bytes
Global $__net_arPacketSendQue[0]
Global $__net_arPacketSendQueWait[0]
Global $__net_arPacketSendQueIDWait[0]
Global $__net_arGlobalIPList[0]
Global $__net_bGlobalIPListIsWhitelist = False
Global $__net_hInt_bcryptdll = -1 ; bcrypt.dll handle
Global $__net_hInt_ntdll = -1 ; nt.dll handle
Global $__net_hInt_cryptdll = -1 ; crypt.dll handle
Global $__net_hInt_hAESAlgorithmProvider = -1 ; AES provider handle
Global $__net_hInt_hRSAAlgorithmProvider = -1 ; RSA provider handle
Global $__net_hInt_hSHAAlgorithmProvider = -1 ; SHA provider handle
Global $__net_nInt_CryptionIterations = 1000 ; i have to research the topic of Iterations
__netcode_SRandomTemporaryFix()

; ===================================================================================================================================================
; Constants
Global Const $__net_sInt_AESCryptionAlgorithm = 'AES' ; todo ~ shouldnt change anyway, vars could be removed
Global Const $__net_sInt_RSACryptionAlgorithm = 'RSA'
Global Const $__net_sInt_SHACryptionAlgorithm = 'SHA256'
Global Const $__net_vInt_RSAEncPadding = 0x00000002
Global Const $__net_sInt_CryptionIV = Binary("0x000102030405060708090A0B0C0D0E0F") ; i have to research this topic
Global Const $__net_sInt_CryptionProvider = 'Microsoft Primitive Provider' ; and this
Global Const $__net_sNetcodeVersion = "0.1.5.11"
Global Const $__net_sNetcodeVersionBranch = "Concept Development" ; Concept Development | Early Alpha | Late Alpha | Early Beta | Late Beta

if $__net_nNetcodeStringDefaultSeed = "%NotSet%" Then __netcode_Installation()
__netcode_EventStrippingFix()

Func _netcode_Startup()
	__Trace_FuncIn("_netcode_Startup")
	__netcode_Init()
	__Trace_FuncOut("_netcode_Startup")
EndFunc   ;==>_netcode_Startup

Func _netcode_Shutdown()
	__Trace_FuncIn("_netcode_Shutdown")
	; todo
	__Trace_FuncOut("_netcode_Shutdown")
EndFunc   ;==>_netcode_Shutdown


; Give either the parent socket returned from _netcode_TCPListen() if you want all clients of it looped or a single client socket
; to loop just this one. If you give a parent, the loop will also check if there is a incomming connection to accept and automatically
; accepts it (but only one per loop call to prevent lag from tcpconnect spam).
; You can also give socket "000" if you have or expect multiple sockets from _netcode_TCPConnect() but only the clients from 000 will then be managed.
; There is no "000" socket if not a single socket got returned from _netcode_TCPConnect(), as its just created as a parent for all connect sockets.
; If all sockets from "000" disconnect, "000" is getting removed and therefore this func will then Return False.
; This Loop will always return False if the given socket does not exists, but returns True if it exists.
; The only @error is 1. It means that the Socket is unknown or removed from _netcode duo to a disconnect for example.
; You can use __netcode_CheckSocket() to check if _netcode knows the socket and what type it is.
; 0 = unknown, 1 = parent, 2 = client.
; "if __netcode_CheckSocket(socket) Then _netcode_Loop(socket)" - can help you to prevent a high amount of error logs.
; _netcode_Loop() is very fast. If not a single client is connected to the parent then the func takes ~0.15 ms.
; if you have 1000 sockets connected then this func takes around ~1.8 ms. If of course interactions with the sockets happen then the
; time is going up.
; Keep in mind that _netcode is designed to provide performance, so it tries to utilize the full thread it is running in.
; So If your main loop looks like this
; While _netcode_Loop(socket)
; WEnd
; then your cpu is going to be bashed. So if a loop takes 0.15 ms and you have no sleeps then _netcode DllCall's ten thousands of times per second.
; Please see the xxxxxx example if you only want to bash the cpu if its really needed to and have _netcode chill if nothing is
; going on or just nothing important.
Func _netcode_Loop(Const $hListenerSocket)
	__Trace_FuncIn("_netcode_Loop", $hListenerSocket)

	Local $nSocketIs = 0
	Local $hNewSocket = 0
	Local $bReturn = False
	Local $arClients[0]

	$nSocketIs = __netcode_CheckSocket($hListenerSocket)
	If $nSocketIs = 0 Then
		__Trace_Error(1, 0, "Socket is unknown", "", $hListenerSocket)
		Return SetError(1, 0, __Trace_FuncOut("_netcode_Loop", False)) ; socket is unknown
	EndIf

	; work through send quo
	if Not $__net_bPacketConfirmation Then __netcode_SendPacketQuoIDQuerry()
	__netcode_SendPacketQuo()

	Switch $nSocketIs

		Case 1 ; is Listener

			; "000" is valid parent socket for _netcode, but its not a real socket. Each client socket bind to "000" came
			; from _netcode_TCPConnect().
			if $hListenerSocket <> "000" Then

				; check for incomming connections
				; we accept one socket per loop on purpose to prevent lag comming from TCPConnect spam.
				$hNewSocket = __netcode_TCPAccept($hListenerSocket)
	;~ 			$hNewSocket = TCPAccept($hListenerSocket) ; for comparisons

				; if a new socket is created
				If $hNewSocket <> -1 Then

					; check that new socket if its ip is banned etc.
					If Not __netcode_CheckSocketIfAllowed($hNewSocket, $hListenerSocket) Then

						; if its invalid then disconnect it
						__netcode_TCPCloseSocket($hNewSocket)
					Else

						; if its not invalid then add socket, if we cant because the max clients are reached then disconnect
						$bReturn = __netcode_AddSocket($hNewSocket, $hListenerSocket)
						If Not $bReturn Then
							__netcode_TCPCloseSocket($hNewSocket)
						Else

							; if we successfully added the socket then call the connection event on stage 0
							__netcode_ExecuteEvent($hNewSocket, "connection", _netcode_sParams(0, _netcode_SocketToIP($hNewSocket)))
						EndIf
					EndIf

				EndIf
			EndIf

			; get all clients connected to the parent
			$arClients = __netcode_ParentGetClients($hListenerSocket)

			; if we have any clients
			if UBound($arClients) > 0 Then

				; then filter it with 'select' for all that windows tells us have something in the recv buffer
				$arClients = __netcode_SocketSelect($arClients, True)

				; query each client returned from 'select' for its data. So receive, manage and execute it
				For $i = 0 To UBound($arClients) - 1
					_netcode_RecvManageExecute($arClients[$i], $hListenerSocket)
				Next
			EndIf


		Case 2 ; is from TCPConnect

			_netcode_RecvManageExecute($hListenerSocket)


	EndSwitch


	Return __Trace_FuncOut("_netcode_Loop", True)

EndFunc   ;==>_netcode_Loop


; Recv, Manage and Execute Packets for the given Client Socket. Use this if you dont want to loop all sockets or accept any new connections.
; $hParentSocket doesnt need to be Set. The Func will read that byitself then.
; But giving it because you were already working with it anyway, results in that the func then doesnt do it -
; Performance increase is likely none.
Func _netcode_RecvManageExecute(Const $hSocket, $hParentSocket = False)
	__Trace_FuncIn("_netcode_RecvManageExecute", $hSocket, $hParentSocket)
	If _storageS_Read($hSocket, '_netcode_SocketIsListener') Then Return SetError(1, 0, False)
	If Not $hParentSocket Then $hParentSocket = __netcode_ClientGetParent($hSocket)

	; recv packages
	Local $sPackages = __netcode_RecvPackages($hSocket)
	Local $nError = @error
	If @extended = 1 Then
		__netcode_TCPCloseSocket($hSocket)
		__netcode_RemoveSocket($hSocket, False, False, $nError)
	EndIf
	If $sPackages = "" Then
;~ 		__Trace_Error(0, 1, "", "
		Return SetError(0, 1, __Trace_FuncOut("_netcode_RecvManageExecute", False)) ; we just didnt receive anything
	EndIf

	; manage packages
	__netcode_ManagePackages($hSocket, $sPackages)

	; execute packages
	If _netcode_GetSocketOnHold($hParentSocket) Then
		Return SetError(0, 2, __Trace_FuncOut("_netcode_RecvManageExecute", False)) ; the parent is set OnHold
	EndIf
	__netcode_ExecutePackets($hSocket)

	Return __Trace_FuncOut("_netcode_RecvManageExecute", True)
EndFunc   ;==>_netcode_RecvManageExecute

; set $bForce = True if you want to disconnect sockets that are not bind to _netcode. However the function will throw errors saying that it
; doesnt know the socket.
; ~ todo add disconnect quos. A socket wont be disconnect until everything thats in the buffer of it is processed and executed $bForce will overwrite that then.
; if the socket is set OnHold then _netcode will based on a option instantly disconnect or not (but will throw a error).
Func _netcode_TCPDisconnect(Const $hSocket, $bForce = False)
	__Trace_FuncIn("_netcode_TCPDisconnect", $hSocket)
	Local $nSocketIs = __netcode_CheckSocket($hSocket)
	If $nSocketIs = 0 Then
		__Trace_Error(1, 0, "This Socket is unknown to _netcode")
		if Not $bForce Then Return SetError(1, 0, __Trace_FuncOut("_netcode_TCPDisconnect", False)) ; this socket is unknown to _netcode
	EndIf
	__netcode_TCPCloseSocket($hSocket)

	Switch $nSocketIs
		Case 1 ; parent
			__netcode_RemoveSocket($hSocket, True, True)

		Case 2 ; client
			__netcode_RemoveSocket($hSocket, False, True)

	EndSwitch

	Return __Trace_FuncOut("_netcode_TCPDisconnect", True)
EndFunc   ;==>_netcode_TCPDisconnect

; $sPort = Local Port to open up
; $sIP = set a single IP that is allowed to connect from (0.0.0.0 allows for all). If you want to allow a set IP list then use xxxxxxxxx
; $nMaxPendingConnections = max not yet accepted incomming connections (handled by windows)
;							so if, lets say, _netcode can accept 5000 incomming connections per second but 6000 come in per second
;							then 1000 will be rejected by windows. Can also be used as a counter measure to protect from DDOS and Spam
; $nMaxConnections = How many Connections the listener should a maximum allow. So if 200 sockets are currently connected then the next will be rejected
;					until the socket amount got below $nMaxConnections.
; $bDoNotAddSocket = If True then this function will not Bind the new Socket to _netcode and will therefore not be managed until bind to it with
;					_netcode_BindSocket()
Func _netcode_TCPListen($sPort, $sIP = '0.0.0.0', $nMaxPendingConnections = Default, $nMaxConnections = 200, $bDoNotAddSocket = False)
	__Trace_FuncIn("_netcode_TCPListen", $sPort, $sIP, $nMaxPendingConnections, $nMaxConnections, $bDoNotAddSocket)

;~ 	hListenerSocket = TCPListen($sIP, $sPort, $nMaxPendingConnections)
	Local $hListenerSocket = __netcode_TCPListen($sIP, $sPort, $nMaxPendingConnections)
	Local $nError = @error
	If $nError Then
		__Trace_Error(1, $nError)
		Return SetError(1, $nError, __Trace_FuncOut("_netcode_TCPListen", False))
	EndIf

	If Not $bDoNotAddSocket Then __netcode_AddSocket($hListenerSocket, False, $nMaxConnections, $sIP, $sPort)

	Return __Trace_FuncOut("_netcode_TCPListen", $hListenerSocket)
EndFunc   ;==>_netcode_TCPListen

; $sIP = IP to connect to
; $sPort = Port to connect to
; $bDontAuthAsNetcode = set True if you want to skip the staging process in this func. Usefull for _netcode_Router UDF or certain differently managed services.
;						You can do that later with _netcode_AuthToNetcodeServer().
; $sUsername = if the Server requires a UserLogin duo to _netcode_SocketSetUserManagement() then a Username is required
; $sPassword = Password for the User. Dont hash the Password, the server hashes and checks it. If you do however give a hashed pw then THIS will be
;			the password that the server then hashes by itself.
; $arKeyPairs = (Unfinished, dont use) Pre Shared RSA keys. If the Server overall or the specific User requires a pre shared RSA key then these must go here.
;				Otherwise the Staging process will fail and the Client will be rejected.
Func _netcode_TCPConnect($sIP, $sPort, $bDontAuthAsNetcode = False, $sUsername = "", $sPassword = "", $arKeyPairs = False)
	__Trace_FuncIn("_netcode_TCPConnect", $sIP, $sPort, $bDontAuthAsNetcode, $sUsername, "$sPassword", "$arKeyPairs")

	; connect to ip and port
;~ 	Local $hSocket = TCPConnect($sIP, $sPort) ; for reference
	Local $hSocket = __netcode_TCPConnect($sIP, $sPort)
	If $hSocket = -1 Then
		Local $nError = @error
		__Trace_Error($nError, 0)
		Return SetError($nError, 0, __Trace_FuncOut("_netcode_TCPConnect", False))
	EndIf

	__netcode_ExecuteEvent($hSocket, "connection", _netcode_sParams(0, $sIP))

	__netcode_AddSocket($hSocket, '000', 0, $sIP, $sPort, $sUsername, $sPassword)
	If Not $bDontAuthAsNetcode Then
		If Not _netcode_AuthToNetcodeServer($hSocket, $sUsername, $sPassword, $arKeyPairs) Then
			Local $nError = @error
			Local $nExtended = @extended
			__netcode_TCPCloseSocket($hSocket)
			__netcode_RemoveSocket($hSocket)
			Return SetError($nError, $nExtended, __Trace_FuncOut("_netcode_TCPConnect", False))
		EndIf
	EndIf


	Return __Trace_FuncOut("_netcode_TCPConnect", $hSocket)
EndFunc   ;==>_netcode_TCPConnect

; dont hash the password.
; ~ todo add PacketENDStrings to verify the packet. The incomplete packet buffer should be limited to nothing more then like 4096 bytes.
; marked for recoding
Func _netcode_AuthToNetcodeServer(Const $hSocket, $sUsername = "", $sPassword = "", $arKeyPairs = False)
	__Trace_FuncIn("_netcode_AuthToNetcodeServer", $hSocket, $sUsername, "$sPassword", "$arKeyPairs")

	; authing to the server
	__netcode_TCPSend($hSocket, StringToBinary($__net_sAuthNetcodeString, 4))

	; wait for answer
	Local $sPackage = __netcode_PreRecvPackages($hSocket)
	If Not $sPackage Then
		__Trace_Error(1, 0, "Disconnected")
		Return SetError(1, 0, __Trace_FuncOut("_netcode_AuthToNetcodeServer", False))
	EndIf

	; check the answer
	If $sPackage <> $__net_sAuthNetcodeConfirmationString Then

		__Trace_Error(2, 0, "Server didnt auth as expected", "", $sPackage)
		Return SetError(2, 0, __Trace_FuncOut("_netcode_AuthToNetcodeServer", False)) ; server didnt auth as expected

	EndIf

	; first stage done
	__netcode_ExecuteEvent($hSocket, "connection", _netcode_sParams(1, ""))

	; create RSA key pair if none given through $arKeyPairs
	If Not IsBinary($arKeyPairs) Then $arKeyPairs = __netcode_CryptGenerateRSAKeyPair(2048)
	__netcode_SocketSetMyRSA($hSocket, $arKeyPairs[0], $arKeyPairs[1])

	; send public RSA key
	__netcode_TCPSend($hSocket, $arKeyPairs[1])

	; wait for answer
	$sPackage = __netcode_PreRecvPackages($hSocket)
	If Not $sPackage Then
		__Trace_Error(3, 0, "Disconnected")
		Return SetError(3, 0, __Trace_FuncOut("_netcode_AuthToNetcodeServer", False))
	EndIf

	; try decrypting data with private RSA key
	Local $sDecData = __netcode_RSADecrypt(Binary($sPackage), $arKeyPairs[0])

	; if we couldnt decrypt
	If $sDecData == 0 Then
;~ 		__netcode_PreDisconnect($hSocket, False, True)
		__Trace_Error(4, 0, "Could not decrypt data")
		Return SetError(4, 0, __Trace_FuncOut("_netcode_AuthToNetcodeServer", False)) ; couldnt decrypt data
	EndIf

	; save decrypted data as the AES key to the socket
	Local $hPassword = __netcode_AESDeriveKey(BinaryToString($sDecData), "packetencryption")
	__netcode_SocketSetPacketEncryptionPassword($hSocket, $hPassword)

	; second stage done
	__netcode_ExecuteEvent($hSocket, "connection", _netcode_sParams(2, BinaryToString($sDecData)))

	If $sUsername <> '' Then
		; try login in by sending our user and password
		__netcode_TCPSend($hSocket, StringToBinary(__netcode_AESEncrypt(StringToBinary("login:" & $sUsername & ':' & _netcode_SHA256($sPassword)), $hPassword), 4))

		; wait for answer
		$sPackage = __netcode_PreRecvPackages($hSocket)
		If Not $sPackage Then
			__Trace_Error(5, 0, "Disconnected")
			Return SetError(5, 0, __Trace_FuncOut("_netcode_AuthToNetcodeServer", False))
		EndIf

		; decrypt answer
		$sDecData = BinaryToString(__netcode_AESDecrypt(Binary(BinaryToString($sPackage)), $hPassword))

		; switch answer
		Switch $sDecData

			Case "Success"
				; ~ todo

			Case "Wrong"
				; ~ todo
				__Trace_Error(5, 1, "", "User is Unknown or Wrong Credentials")
				Return SetError(5, 1, __Trace_FuncOut("_netcode_AuthToNetcodeServer", False))

			Case "OnHold" ; the account is set to OnHold
				; ~ todo
				__Trace_Error(5, 2, "", "Account is OnHold")
				Return SetError(5, 2, __Trace_FuncOut("_netcode_AuthToNetcodeServer", False))

			Case "Banned"
				; ~ todo
				__Trace_Error(5, 3, "", "Account is Banned")
				Return SetError(5, 3, __Trace_FuncOut("_netcode_AuthToNetcodeServer", False))

			Case Else
				; ~ todo
				__Trace_Error(5, 4, "", "Unknown Error")
				Return SetError(5, 4, __Trace_FuncOut("_netcode_AuthToNetcodeServer", False))

		EndSwitch

		__netcode_SocketSetUser($hSocket, $sUsername)

		; third step done
		__netcode_ExecuteEvent($hSocket, "connection", _netcode_sParams(3, $sUsername))
	EndIf

	; Request PreSyn data
	__netcode_TCPSend($hSocket, __netcode_AESEncrypt("presyn", $hPassword))

	; wait for answer
	$sPackage = __netcode_PreRecvPackages($hSocket)
	If Not $sPackage Then
		__Trace_Error(6, 0, "Disconnected")
		Return SetError(6, 0, __Trace_FuncOut("_netcode_AuthToNetcodeServer", False))
	EndIf

	; decrypt answer
	$sDecData = BinaryToString(__netcode_AESDecrypt(Binary(BinaryToString($sPackage)), $hPassword))
	Local $arPreSyn = __netcode_CheckParamAndUnserialize($sDecData)
	If Not IsArray($arPreSyn) Then
		__Trace_Error(7, 0, "Could not decrypt Answer")
		Return SetError(7, 0, __Trace_FuncOut("_netcode_AuthToNetcodeServer", False))
	EndIf

	; set server rules
	For $i = 0 To UBound($arPreSyn) - 1
		__netcode_PreSyn($hSocket, $arPreSyn[$i][0], $arPreSyn[$i][1])
	Next

	; fourth step done
	__netcode_ExecuteEvent($hSocket, "connection", _netcode_sParams(4, $arPreSyn))

	; syn phase
	; ~ todo
;~ 	__netcode_SocketSetManageMode($hSocket, 'syn')

	; ready temp stage
;~ 	__netcode_TCPSend($hSocket, __netcode_AESEncrypt("ready", $hPassword))
	_netcode_TCPSend($hSocket, 'netcode_internal', 'null')
	__netcode_SendPacketQuo()

	__netcode_SocketSetManageMode($hSocket, 'netcode')
	__netcode_ExecuteEvent($hSocket, "connection", _netcode_sParams(10, ""))
	Return __Trace_FuncOut("_netcode_AuthToNetcodeServer", True)
EndFunc   ;==>_netcode_AuthToNetcodeServer

Func __netcode_PreSyn(Const $hSocket, $sPreSyn, $sData)
	__Trace_FuncIn("__netcode_PreSyn", $hSocket, $sPreSyn, $sData)
	Switch $sPreSyn

		Case "MaxRecvBufferSize"
			$__net_nMaxRecvBufferSize = Number($sData)


		Case "DefaultRecvLen"
			$__net_nDefaultRecvLen = Number($sData)


		Case "Encryption"
			__netcode_SocketSetPacketEncryption($hSocket, __netcode_SetVarType($sData, "Bool"))


		Case "Seed"
			__netcode_SeedingClientStrings($hSocket, Number($sData))

		Case Else
			; unknown rule
			; ~ todo


	EndSwitch
	__Trace_FuncOut("__netcode_PreSyn")
EndFunc   ;==>__netcode_PreSyn

#cs
 you need to be aware of one thing. This function only wrapps up the packet, checks if it would exceed the packet buffer of the other side
 and if not adds the packet to the send quo. The packets get send in the loop not here. So you can not do this
 For To
 	_netcode_TCPSend(socket, event, data)
 Next
 you should use it like so if you want to imidiatly send the packet
 For To
 	_netcode_TCPSend(socket, event, data)
 	_netcode_Loop(socket)
 Next

 you could force the imidiate sending by using __netcode_SendPacketQuo() in case you dont want to call _netcode_Loop(), but you really shouldnt because it isnt meant like that
 and there are a couple of reasons why it is made like that.
 For To
 	_netcode_TCPSend(socket, event, data)
	__netcode_SendPacketQuo()
 Next

 One Reason is that the sockets are set to non blocking and therefore the packet sending has to be done differently to make sure we dont mess up.
 Another Reason is that the UDF combines packets before sending. So you can add packets to the quo with $bWaitForFloodPrevention set to False
 (to know when its full) until the buffer is full and then _netcode_Loop() or >= _netcode_GetDefaultPacketContentSize() (or) _netcode_GetDynamicPacketContentSize()
 is reached to send with the right packet size.

 do %example% here

 @error = 10 means that the packet to be send would, even if the buffer of the other side is empty, would exceed it. Your data needs to be smaller!
		So if for example the Server or Client accepts a maximum packet size of 4mb but your packet is 4.5 mb in size then the packet would always be rejected by the server or client,
		no matter how full the buffer is. So instead of quoing the packet this function just returns @error.
		See _netcode_GetMaxPacketContentSize(), _netcode_GetDefaultPacketContentSize() and _netcode_GetDynamicPacketContentSize() for data sizes.
		Valid data Sizes are inherited by the Server in the PreSyn stage phase.

 if $bWaitForFloodPrevention is True then the function will loop until the other side reported back that it processed the last packets and that therefore the buffer is empty enough
 to recieve this data. If set to False the function will return @error = 1 if the buffer of the other side is to full to accept this packet.

 if you, however you do it, force the sending of packets while the buffer of the other side is full, then the other side will simply dismiss the packet. Thats
 because there are overflow protections in place. The Server or Client will simply never accept more data then they can process.
#ce
; marked for recoding
; store the specific $__net_nMaxRecvBufferSize to the socket, since having connections to multiple server with different
; settings would break the script.
; add a Timeout that can be set with _netcode_SetOption() and / or in the parameters $nWaitForFloodPreventionTimeout
; add the parameter to disable packet encryption for the given data.
Func _netcode_TCPSend(Const $hSocket, $sEvent, $sData = '', $bWaitForFloodPrevention = True)
	__Trace_FuncIn("_netcode_TCPSend", $hSocket, $sEvent, "$sData", $bWaitForFloodPrevention)

	; check if the socket is known to _netcode
	If Not __netcode_CheckSocket($hSocket) Then
		__Trace_Error(0, 1, "Socket is unknown")
		Return SetError(0, 1, __Trace_FuncOut("_netcode_TCPSend", False))
	EndIf

	; check if the given event is illegal
	if $sEvent = 'connection' Or $sEvent = 'disconnected' Then
		__Trace_Error(10, 0, "The " & $sEvent & " event is an invalid event to be send")
		Return SetError(10, 0, __Trace_FuncOut("_netcode_TCPSend", False))
	EndIf

	; create package
	Local $sPackage = __netcode_CreatePackage($hSocket, $sEvent, $sData)
	Local $nError = @error
	Local $sID = @extended
	Local $nLen = StringLen($sPackage)

	; check package size
	If $nLen > $__net_nMaxRecvBufferSize Then Return SetError(10, 0, __Trace_FuncOut("_netcode_TCPSend", False)) ; this packet is to big to ever get send

	; check for flood error in the packet creation phase
	if $nError Then

		; if the wait for flood prevention toggle is set
		if $bWaitForFloodPrevention Then

			; loop until the packet can be send or the socket is invalid
			While True

				; check if socket still exists
				if Not __netcode_CheckSocket($hSocket) Then
					__Trace_Error($nError, 1, "Socket is no longer known or disconnected")
					Return SetError($nError, 1, __Trace_FuncOut("_netcode_TCPSend", False))
				EndIf

				; loop socket
				if $__net_bPacketConfirmation Then
					_netcode_RecvManageExecute($hSocket)
				Else
					__netcode_SendPacketQuoIDQuerry()
				EndIf

				; check if the latest packet id changed
				if _storageS_Read($hSocket, '_netcode_SafetyBufferIndex') <> $sID Then

					; create new package with new packet id
					$sPackage = __netcode_CreatePackage($hSocket, $sEvent, $sData)
					$nError = @error
					$sID = @extended
					$nLen = StringLen($sPackage)

					; if createpackage() already sayed there is no error then exitloop already
					if $nError = 0 Then ExitLoop
				EndIf

				; check if enough buffer space is finally available and exitloop if thats the case
				if Number(_storageS_Read($hSocket, '_netcode_SafetyBufferSize')) + $nLen < $__net_nMaxRecvBufferSize Then
					$nError = 0
					ExitLoop
				EndIf

				; check for timeout
				; ~ todo

			WEnd

		EndIf

		; if still $nError
		if $nError Then
			__Trace_Error($nError, 0)
			Return SetError($nError, 0, __Trace_FuncOut("_netcode_TCPSend", False))
		EndIf

	EndIf

	; add packet to safety buffer if it not a internal packet
	If $sEvent <> 'netcode_internal' Then __netcode_AddToSafetyBuffer($hSocket, $sPackage, $nLen)

	; add packet to send quo
	__netcode_AddPacketToQue($hSocket, $sPackage, $sID)

	; add a p/s
	__netcode_SocketSetSendPacketPerSecond($hSocket, 1)

	Return __Trace_FuncOut("_netcode_TCPSend", True)

EndFunc   ;==>_netcode_TCPSend

Func _netcode_TCPSendRaw(Const $hSocket, $sData, $nLinkID = False)
	__Trace_FuncIn("_netcode_TCPSendRaw")

	If IsBinary($sData) Then $sData = BinaryToString($sData)

	if $nLinkID Then
;~ 		if IsBinary($sData) Then $sData = BinaryToString($sData)
		; currently not supported
		__Trace_Error(10, 0, "$nLinkID cannot be used right now")
		Return __Trace_FuncOut("_netcode_TCPSendRaw", False)
	EndIf

	__netcode_AddPacketToQue($hSocket, $sData)

	__Trace_FuncOut("_netcode_TCPSendRaw", True)
EndFunc

; give parent socket
; marked for recoding
; note - make it so that besides a single parent an array of parents and or clients can be given
Func _netcode_TCPBroadcast(Const $hSocket, $sEvent, $sData, $bWaitForFloodPrevention = True)
	__Trace_FuncIn("_netcode_TCPBroadcast", $hSocket, $sEvent, $bWaitForFloodPrevention)

	If __netcode_CheckSocket($hSocket) <> 1 Then
		__Trace_Error(1, 0, "This is not a parent socket", "", $hSocket)
		Return SetError(1, 0, __Trace_FuncOut("_netcode_TCPBroadcast", False)) ; this isnt a parent socket
	EndIf

	Local $arClients = __netcode_ParentGetClients($hSocket)
	For $i = 0 To UBound($arClients) - 1
		_netcode_TCPSend($arClients[$i], $sEvent, $sData, $bWaitForFloodPrevention)
	Next
	__Trace_FuncOut("_netcode_TCPBroadcast")
EndFunc   ;==>_netcode_TCPBroadcast

; get the bytes send per second in bytes ($nMode = 0), kilobytes (1) or megabytes (2).
; The given socket can be a client socket or a parent socket. If a parent is given then the bytes per second of all its clients is added together and returned.
Func _netcode_SocketGetSendBytesPerSecond(Const $hSocket, $nMode = 0)
	__Trace_FuncIn("_netcode_SocketGetSendBytesPerSecond")

	Local $nBytesPerSecond = 0
	Switch __netcode_CheckSocket($hSocket)
		Case 1 ; parent
			Local $arClients = __netcode_ParentGetClients($hSocket)
			For $i = 0 To UBound($arClients) - 1
				$nBytesPerSecond += __netcode_SocketGetSendBytesPerSecond($arClients[$i], $nMode)
			Next

		Case 2 ; client
			$nBytesPerSecond = __netcode_SocketGetSendBytesPerSecond($hSocket, $nMode)
	EndSwitch

	__Trace_FuncOut("_netcode_SocketGetSendBytesPerSecond")
	Return $nBytesPerSecond
EndFunc

; get the bytes received per second in bytes ($nMode = 0), kilobytes (1) or megabytes (2).
; The given socket can be a client socket or a parent socket. If a parent is given then the bytes per second of all its clients is added together and returned.
Func _netcode_SocketGetRecvBytesPerSecond(Const $hSocket, $nMode = 0)
	__Trace_FuncIn("_netcode_SocketGetRecvBytesPerSecond")

	Local $nBytesPerSecond = 0
	Switch __netcode_CheckSocket($hSocket)
		Case 1 ; parent
			Local $arClients = __netcode_ParentGetClients($hSocket)
			For $i = 0 To UBound($arClients) - 1
				$nBytesPerSecond += __netcode_SocketGetRecvBytesPerSecond($arClients[$i], $nMode)
			Next

		Case 2 ; client
			$nBytesPerSecond = __netcode_SocketGetRecvBytesPerSecond($hSocket, $nMode)
	EndSwitch

	__Trace_FuncOut("_netcode_SocketGetRecvBytesPerSecond")
	Return $nBytesPerSecond
EndFunc

Func _netcode_SocketGetSendPacketPerSecond(Const $hSocket)
	__Trace_FuncIn("_netcode_SocketGetSendPacketPerSecond")
	Local $nCount = 0

	Switch __netcode_CheckSocket($hSocket)
		Case 1 ; parent
			Local $arClients = __netcode_ParentGetClients($hSocket)
			For $i = 0 To UBound($arClients) - 1
				$nCount += __netcode_SocketGetSendPacketPerSecond($arClients[$i])
			Next

		Case 2 ; client
			$nCount = __netcode_SocketGetSendPacketPerSecond($hSocket)
	EndSwitch

	__Trace_FuncOut("_netcode_SocketGetSendPacketPerSecond")
	Return $nCount
EndFunc

Func _netcode_SocketGetRecvPacketPerSecond(Const $hSocket)
	__Trace_FuncIn("_netcode_SocketGetRecvPacketPerSecond")
	Local $nCount = 0

	Switch __netcode_CheckSocket($hSocket)
		Case 1 ; parent
			Local $arClients = __netcode_ParentGetClients($hSocket)
			For $i = 0 To UBound($arClients) - 1
				$nCount += __netcode_SocketGetRecvPacketPerSecond($arClients[$i])
			Next

		Case 2 ; client
			$nCount = __netcode_SocketGetRecvPacketPerSecond($hSocket)
	EndSwitch

	__Trace_FuncOut("_netcode_SocketGetRecvPacketPerSecond")
	Return $nCount
EndFunc

#cs
 Highly experimental !!
 Has to be triggered by the server, not the client, but with the client socket (yet).

 This Feature will send to the client a "connect a second socket" packet and a LinkID with it.
 if the client has it enabled it will connect a second time and it will send the same LinkID on the new socket.
 The Server then links both sockets together and also sends a confirmation packet to the client.
 Once setup both the server and the client will make the second socket a "Linked Socket" and change its manage mode
 to RawLinked. The Linked Socket can then be used for _netcode_TCPSendRaw(). This Socket is right now just one way
 so the client can send data to the server but not vise versa (yet). Each Data comming from the Client
 is routed to the $sCallback function. Your Callback function needs to have 4 params.
 1 = socket, 2 = LinkID, 3 = raw data, 4 = additional data.

 All data send with _netcode_TCPSendRaw() is not getting packed up, but rather send as is.
 This improves the performance by multiple hundred percent compared to the 'netcode' manage mode.
 (i could get up to 190 MB/s).
 Linked Sockets are basically usefull to stream data (See the file send example).

 Pls. note that:
 The data is send unencrypted no matter your settings (yet).
 And there are zero packet protections in place. If a packet is missing or is corrupted, _netcode wont notice.

 Server has to set _netcode_SetOption(parent, 'AllowSocketLinkingSetup', True),
 and Client has to set _netcode_SetOption(client, 'AllowSocketLinkingRequest', True).

 If you add $vAdditionalData then this var, no matter the type, will always be given to your callback.
 You can always edit the var on the fly with _netcode_SocketLinkSetAdditionalData(socket, LinkID, $vAdditionalData).

 be aware this feature is either being removed (unlikely), exported or rewritten, because as of yet i am not sure about the
 design and safety of this feature.
#ce
Func _netcode_SetupSocketLink(Const $hSocket, $sCallback, $nLinkID = Default, $vAdditionalData = False)
	__Trace_FuncIn("_netcode_SetupSocketLink")

	if _storageS_Read($hSocket, '_netcode_IsLinkClient') Then
		__Trace_Error(1, 0, "Link Clients cant be Link Provider")
		Return SetError(1, 0, __Trace_FuncOut("_netcode_SetupSocketLink", False))
	EndIf

	if $nLinkID = Default Then
		$nLinkID = __netcode_RandomPW(40, 1)
	Else
;~ 		if StringLen($nLinkID) <> 20 Then
;~ 			__Trace_Error(2, 0, "The LinkID is <> 20 len. It must be exactly of len 20")
;~ 			Return SetError(2, 0, __Trace_FuncOut("_netcode_SetupSocketLink", False))
;~ 		EndIf
	EndIf
	If Not __netcode_SocketAddLinkID($hSocket, $nLinkID, $sCallback, $vAdditionalData) Then
		Return SetError(3, 0, __Trace_FuncOut("_netcode_SetupSocketLink"))
	EndIf
	_netcode_TCPSend($hSocket, 'netcode_socketlinkrequest', $nLinkID)

	Return __Trace_FuncOut("_netcode_SetupSocketLink", $nLinkID)
EndFunc

#cs
Func _netcode_StopSocketLink(Const $hSocket, $nLinkID)
	; unlink, remove socketlink event and disconnect linked socket
EndFunc
#ce

Func _netcode_SocketLinkSetAdditionalData(Const $hSocket, $nLinkID, $vAdditionalData)
	__Trace_FuncIn("_netcode_SocketLinkSetAdditionalData")

	Local $hNewSocket = 0

	if _storageS_Read($hSocket, '_netcode_IsLinkClient') Then
		$hNewSocket = __netcode_SocketGetLinkedSocket($hSocket, $nLinkID)
		_storageS_Overwrite($hSocket, '_netcode_LinkAdditionalData', $vAdditionalData)
		_storageS_Overwrite($hNewSocket, '_netcode_LinkAdditionalData' & $nLinkID, $vAdditionalData)
	Else
		$hNewSocket = __netcode_SocketGetLinkedSocket($hSocket, $nLinkID)
		_storageS_Overwrite($hSocket, '_netcode_LinkAdditionalData' & $nLinkID, $vAdditionalData)
		_storageS_Overwrite($hNewSocket, '_netcode_LinkAdditionalData', $vAdditionalData)
	EndIf
	__Trace_FuncOut("_netcode_SocketLinkSetAdditionalData")
EndFunc

Func _netcode_SocketLinkGetAdditionalData(Const $hSocket, $nLinkID = False)
	__Trace_FuncIn("_netcode_SocketLinkGetAdditionalData")
	__Trace_FuncOut("_netcode_SocketLinkGetAdditionalData")
	if _storageS_Read($hSocket, '_netcode_IsLinkClient') Then
		Return _storageS_Read($hSocket, '_netcode_LinkAdditionalData')
	Else
		Return _storageS_Read($hSocket, '_netcode_LinkAdditionalData' & $nLinkID)
	EndIf
EndFunc

Func _netcode_CheckLink(Const $hSocket, $nLinkID = False)
	__Trace_FuncIn("_netcode_CheckLink")
	__Trace_FuncOut("_netcode_CheckLink")
	Return __netcode_SocketGetLinkedSocket($hSocket, $nLinkID)
EndFunc

Func _netcode_SocketSetManageMode(Const $hSocket, $sMode = Default)
	__Trace_FuncIn("_netcode_SocketSetManageMode")

	If $sMode = Default Then $sMode = "netcode"

	Switch $sMode

		Case "raw"
			__netcode_SocketSetManageMode($hSocket, "raw")

		Case "rawlinked"
			__netcode_SocketSetManageMode($hSocket, "rawlinked")

		Case "netcode"
			__netcode_SocketSetManageMode($hSocket, "netcode")

		Case Else
			__Trace_Error(1, 0, "Invalid Manage Mode")
			Return SetError(1, 0, __Trace_FuncOut("_netcode_SocketSetManageMode", False))


	EndSwitch

	Return __Trace_FuncOut("_netcode_SocketSetManageMode", True)
EndFunc

; $__net_sPacketBegin & $__net_sPacketInternalSplit * 3 & $__net_sPacketEnd & 32 for Hash & Event Len
Func _netcode_GetMaxPacketContentSize($sEvent = "", $nMarge = 0.9)
	__Trace_FuncIn("_netcode_GetMaxPacketContentSize", $sEvent, $nMarge)
	__Trace_FuncOut("_netcode_GetMaxPacketContentSize")
	Return Int(($__net_nMaxRecvBufferSize - (StringLen($__net_sPacketBegin) + StringLen($__net_sPacketEnd) + (StringLen($__net_sPacketInternalSplit) * 3) + 32 + StringLen($sEvent))) * $nMarge)
EndFunc   ;==>_netcode_GetMaxPacketContentSize

Func _netcode_GetDefaultPacketContentSize($sEvent = "")
	__Trace_FuncIn("_netcode_GetDefaultPacketContentSize", $sEvent)
	__Trace_FuncOut("_netcode_GetDefaultPacketContentSize")
	Return Int(($__net_nDefaultRecvLen - (StringLen($__net_sPacketBegin) + StringLen($__net_sPacketEnd) + (StringLen($__net_sPacketInternalSplit) * 3) + 32 + StringLen($sEvent))))
EndFunc   ;==>_netcode_GetDefaultPacketContentSize

#cs
; _netcode will try to figure out by itself which packet size is working best to send data as fast a possible.
; here we basically measure the bytes per second of the given client socket and rise / lower the size to check what increases performance.
; thats why on the first call this function wont return the best result. It will start from the $__net_nDefaultRecvLen.
; note for me - if compression is enabled this function maybe will calculate wrong sizes because compression is dynamic to what data flows into it.
Func _netcode_GetDynamicPacketContentSize(Const $hSocket)
	__Trace_FuncIn("_netcode_GetDynamicPacketContentSize", $hSocket)

	Local $nDynamicSize = _storageS_Read($hSocket, '_netcode_PacketDynamicSize')

	if $nDynamicSize = 0 Then
		Local $nSize = 0
		Local $nSec = 0
		Local $nBest = 0
		Local $nBestBytesPerSecond = 0
		Local $sData = ""
		Local $s256KB = ""
		Local $nBytesPerSecond = 0
		Local $nCount = 0

		For $i = 1 To 256 * 1024
			$s256KB &= "1"
		Next

		Do
			; create data
			$sData = ""
			$nSize += 256 * 1024 ; 256 kb
			For $i = 1 To $nSize Step 256 * 1024
				$sData &= $s256KB
			Next

			; make sure we start at the beginning of the second
			$nSec = @SEC
			Do
			Until $nSec <> @SEC
			$nSec = @SEC

			; checking speed
			$nCount = 0
			$nBytesPerSecond = 0
			While True
				if __netcode_CheckSocket($hSocket) = 0 Then Return __Trace_FuncOut("_netcode_GetDynamicPacketContentSize", False) ; disconnected
				_netcode_TCPSend($hSocket, 'netcode_internal', $sData)

				_netcode_Loop($hSocket)

				if $nSec <> @SEC Then
					$nCount += 1
					$nBytesPerSecond += __netcode_SocketGetSendBytesPerSecond($hSocket)
					if $nCount >= 2 Then ExitLoop
					$nSec = @SEC
				EndIf

			WEnd

			$nBytesPerSecond /= 2
			if $nBytesPerSecond > $nBestBytesPerSecond Then
				$nBestBytesPerSecond = $nBytesPerSecond
				$nBest = $nSize
			EndIf

			ConsoleWrite(StringLen($sData) & @TAB & @TAB & $nBytesPerSecond & @CRLF)

		Until $nSize > _netcode_GetMaxPacketContentSize()

		_storageS_Overwrite($hSocket, '_netcode_PacketDynamicSize', $nBest)
		$nDynamicSize = $nBest
	EndIf


	__Trace_FuncOut("_netcode_GetDynamicPacketContentSize")
	Return $nDynamicSize

EndFunc   ;==>_netcode_GetDynamicPacketContentSize
#ce


Func _netcode_UseNonCallbackEvent(Const $hSocket, $sMyEvent, $sSendEvent, $sData = "", $nTimeout = 10000) ; 10 sec default timeout

	; resetting eventdata in case there is something stored that got returned from a previous failed call
	_netcode_GetEventData($hSocket, $sMyEvent)

	; sending request
	_netcode_TCPSend($hSocket, $sSendEvent, $sData)


	Local $arEventData = ""
	Local $hTimer = TimerInit()

	; waiting for response
	Do
		if TimerDiff($hTimer) > $nTimeout Then Return SetError(2, 0, "") ; timeouted

		if __netcode_CheckSocket($hSocket) = 0 Then
			Return SetError(1, 0, "") ; disconnected
		Else
			_netcode_Loop($hSocket)
		EndIf

		$arEventData = _netcode_GetEventData($hSocket, $sMyEvent)
	Until IsArray($arEventData)

	Return $arEventData
EndFunc

Func _netcode_GetEventData(Const $hSocket, $sName)
	Local $sData = _storageS_Read($hSocket, '_netcode_Event' & StringToBinary($sName) & '_Data')
	_storageS_Overwrite($hSocket, '_netcode_Event' & StringToBinary($sName) & '_Data', "")

	Return $sData
EndFunc

; if you set a event for a parent then all NEW client sockets will get this event atttached.
; if you set a event for a client then only this client will have that event.
; if you use it with a parent then be aware that this func does not update the events on the existing client sockets. See _netcode_SetEventOnAllWithParent() for that
; note for me: the array used here has only the usage to be able to retrieve all existing events in case the user needs to know them, there is no other usage for the array.
Func _netcode_SetEvent(Const $hSocket, $sName, $sCallback, $bSet = True)
	__Trace_FuncIn("_netcode_SetEvent", $hSocket, $sName, $sCallback, $bSet)

	If $hSocket == '000' Then
		__Trace_Error(1, 0, "You cannot set a event to socket 000")
		Return SetError(1, 0, __Trace_FuncOut("_netcode_SetEvent", False)) ; you cannot set events for this socket
	EndIf

	; convert Eventname to Binary as every event is binarized. Therefore any name can be given.
	If Not IsBinary($sName) Then $sName = StringToBinary($sName)

	; Get all events from this socket
	Local $arEvents = __netcode_SocketGetEvents($hSocket)
	If Not IsArray($arEvents) Then
		__Trace_Error(2, 0, "Unknown Socket")
		Return SetError(2, 0, __Trace_FuncOut("_netcode_SetEvent", False)) ; all clients have this array. If this doesnt then the whole socket is unknown to _netcode
	EndIf
	Local $nArSize = UBound($arEvents)

	; Check if the event is already set
	Local $nIndex = -1
	For $i = 0 To $nArSize - 1
		If $arEvents[$i] = $sName Then
			$nIndex = $i
			ExitLoop
		EndIf
	Next

	If $bSet Then
		; if the event is already set then Return False. Why add what already is
		If $nIndex <> -1 Then
			__Trace_Error(3, 0, "This event is already set", "", $sName)
			Return SetError(3, 0, __Trace_FuncOut("_netcode_SetEvent", False)) ; this event is already set
		EndIf

		; increase the size by one and add the new event
		ReDim $arEvents[$nArSize + 1]
		$arEvents[$nArSize] = $sName

		; create storage var for faster event checking and store the set callback to it
		_storageS_Overwrite($hSocket, '_netcode_Event' & $sName, $sCallback)
		if $sCallback = "" Then _storageS_Overwrite($hSocket, '_netcode_Event' & $sName & '_Data', "")
		__netcode_SocketSetEvents($hSocket, $arEvents)

		Return __Trace_FuncOut("_netcode_SetEvent", True)

	Else

		; if the event is not set then Return False. Cant remove whats not here
		If $nIndex = -1 Then
			__Trace_Error(4, 0, "This event wasnt set", "", $sName)
			Return SetError(4, 0, __Trace_FuncOut("_netcode_SetEvent", False)) ; this event wasnt even set
		EndIf

		; overwrite the events index with the event name of the last index. Then ReDim the array with one less
		$arEvents[$nIndex] = $arEvents[$nArSize - 1]
		ReDim $arEvents[$nArSize - 1]

		; remove callback from storage
		_storageS_Overwrite($hSocket, '_netcode_Event' & $sName, False)
		__netcode_SocketSetEvents($hSocket, $arEvents)

		Return __Trace_FuncOut("_netcode_SetEvent", True)

	EndIf
EndFunc   ;==>_netcode_SetEvent

; ~ todo
; this function returns an 2D array from those sockets it has changed this event on.
; if the same array would be used in $hSocket this func would revert the changes to what was before.
; 2D
; [x][0] = Socket
; [0][x] = What was will be
Func _netcode_SetEventOnAll($sName, $sCallback, $bSet = True)
	__Trace_FuncIn("_netcode_SetEventOnAll", $sName, $sCallback, $bSet)

	If Not IsBinary($sName) Then $sName = StringToBinary($sName)
	Local $nArSize = UBound($__net_arSockets)

	For $i = 0 To $nArSize - 1
		_netcode_SetEventOnAllWithParent($__net_arSockets[$i], $sName, $sCallback, $bSet)
	Next
	__Trace_FuncOut("_netcode_SetEventOnAll")
EndFunc   ;==>_netcode_SetEventOnAll

Func _netcode_SetEventOnAllWithParent(Const $hSocket, $sName, $sCallback, $bSet = True)
	__Trace_FuncIn("_netcode_SetEventOnAllWithParent", $hSocket, $sName, $sCallback, $bSet)
	If Not _storageS_Read($hSocket, '_netcode_SocketIsListener') Then
		__Trace_Error(1, 0, "Client socket given, but Parent socket required")
		Return SetError(1, 0, __Trace_FuncOut("_netcode_SetEventOnAllWithParent", False)) ; this func is only for parent sockets
	EndIf
	If Not Binary($sName) Then $sName = StringToBinary($sName)

	Local $arClients = __netcode_ParentGetClients($hSocket)
	Local $nArSize = UBound($arClients)

	For $i = 0 To $nArSize - 1
		_netcode_SetEvent($arClients[$i], $sName, $sCallback, $bSet)
	Next
	__Trace_FuncOut("_netcode_SetEventOnAllWithParent")
EndFunc   ;==>_netcode_SetEventOnAllWithParent

#cs
; get all events set on this client
; [x][0] = client socket
; [0][x1] = first event | callback
; [0][x2] = second event | callback
; preset events are not listet
Func _netcode_GetEventsClient(Const $hSocket)
EndFunc   ;==>_netcode_GetEventsClient

; get all events set on this parent
Func _netcode_GetEventsParent(Const $hSocket)
EndFunc   ;==>_netcode_GetEventsParent

; get all client events no matter the parent
Func _netcode_GetEventsAll()
EndFunc   ;==>_netcode_GetEventsAll

; get all client events from this parent
Func _netcode_GetEventsAllByParent(Const $hSocket)
EndFunc   ;==>_netcode_GetEventsAllByParent
#ce

; Presetting events for all new incoming connections no matter the listener and if it already exist.
; All events set here are Default. Default events are 'connection', 'disconnected', 'flood', 'banned' etc.
; Defaults events are not linked to the other socket specific events.
; You could also set for example a 'connection' event with _netcode_SetEvent() on each or one client socket and it would be prioritized over the default event.
; if you want to overwrite a default event then just call this, you dont need to set it to false first.
Func _netcode_PresetEvent($sName, $sCallback, $bSet = True)
	__Trace_FuncIn("_netcode_PresetEvent", $sName, $sCallback, $bSet)

	If Not IsBinary($sName) Then $sName = StringToBinary($sName)
	Local $nArSize = UBound($__net_arDefaultEventsForEachNewClientSocket)

	Local $nIndex = -1
	For $i = 0 To $nArSize - 1
		If $__net_arDefaultEventsForEachNewClientSocket[$i][0] = $sName Then
			$nIndex = $i
			ExitLoop
		EndIf
	Next

	If $bSet Then

;~ 		if $nIndex <> -1 Then Return SetError(1, 0, False) ; this event is already set
		; ~ todo check if the array then has two events !

		ReDim $__net_arDefaultEventsForEachNewClientSocket[$nArSize + 1][2]
		$__net_arDefaultEventsForEachNewClientSocket[$nArSize][0] = $sName
		$__net_arDefaultEventsForEachNewClientSocket[$nArSize][1] = $sCallback

		_storageS_Overwrite('Internal', '_netcode_DefaultEvent' & $sName, $sCallback)

		Return __Trace_FuncOut("_netcode_PresetEvent", True)

	Else

		If $nIndex = -1 Then
			__Trace_Error(2, 0, "This event wasnt set", "", $sName)
			Return SetError(2, 0, __Trace_FuncOut("_netcode_PresetEvent", False)) ; this event wasnt even set
		EndIf

		$__net_arDefaultEventsForEachNewClientSocket[$nIndex][0] = $__net_arDefaultEventsForEachNewClientSocket[$nArSize - 1][0]
		$__net_arDefaultEventsForEachNewClientSocket[$nIndex][1] = $__net_arDefaultEventsForEachNewClientSocket[$nArSize - 1][1]
		ReDim $__net_arDefaultEventsForEachNewClientSocket[$nArSize - 1][2]

		_storageS_Overwrite('Internal', '_netcode_DefaultEvent' & $sName, False)

		Return __Trace_FuncOut("_netcode_PresetEvent", True)

	EndIf
EndFunc   ;==>_netcode_PresetEvent

; if the user wants to have specific events for all new clients of only one of his listeners
; setting an event here will not set them on each active connected client. The event will just be set on each NEW client.
; for setting Events on all active Sockets use _netcode_SetEventOnAllWithParent()
Func _netcode_PresetEventWithParent(Const $hSocket, $sName, $sCallback, $bSet = True)
	__Trace_FuncIn("_netcode_PresetEventWithParent", $hSocket, $sName, $sCallback, $bSet)

	If Not _storageS_Read($hSocket, '_netcode_SocketIsListener') Then
		__Trace_Error(1, 0, "This function can only be used for a parent socket", "", $hSocket)
		Return SetError(1, 0, __Trace_FuncOut("_netcode_PresetEventWithParent", False)) ; this func is only for parent sockets
	EndIf
	If Not IsBinary($sName) Then $sName = StringToBinary($sName)

	; read Events
	Local $arEvents = __netcode_SocketGetEvents($hSocket)
	Local $nArSize = UBound($arEvents)

	; Check if the event already exist
	Local $nIndex = -1
	For $i = 0 To $nArSize - 1
		If $arEvents[$i] = $sName Then
			$nIndex = $i
			ExitLoop
		EndIf
	Next

	If $bSet Then

		If $nIndex <> -1 Then
			__Trace_Error(2, 0, "This event is already set", "", $sName)
			Return SetError(2, 0, __Trace_FuncOut("_netcode_PresetEventWithParent", False)) ; this event is already set
		EndIf

		ReDim $arEvents[$nArSize + 1]
		$arEvents[$nArSize] = $sName

		; each new client is then set with these Events on Connect
		_storageS_Overwrite($hSocket, '_netcode_Event' & $sName, $sCallback)

		__netcode_SocketSetEvents($hSocket, $arEvents)
		Return __Trace_FuncOut("_netcode_PresetEventWithParent", True)

	Else

		If $nIndex = -1 Then
			__Trace_Error(3, 0, "This event wasnt set", "", $sName)
			Return SetError(3, 0, __Trace_FuncOut("_netcode_PresetEventWithParent", False)) ; this event wasnt even set
		EndIf

		$arEvents[$nIndex] = $arEvents[$nArSize - 1]
		ReDim $arEvents[$nArSize - 1]

		_storageS_Overwrite($hSocket, '_netcode_Event' & $sName, False)

		__netcode_SocketSetEvents($hSocket, $arEvents)
		Return __Trace_FuncOut("_netcode_PresetEventWithParent", True)

	EndIf

EndFunc   ;==>_netcode_PresetEventWithParent

; set a white or blacklist of IP's to a parent Socket.
; if you Whitelist just one IP, because you only want one IP to have access then consider using _netcode_TCPListen(port, ->ip<-) instead of this,
; because then windows will already deny unwated connections.
; if you have a million of ip's consider writing a IP Check application in a faster programming language. Otherwise you will notice lag.
Func _netcode_SetIPList(Const $hSocket, $arIPList, $bIsWhitelist)
	__Trace_FuncIn("_netcode_SetIPList", $hSocket, $arIPList, $bIsWhitelist)
	If __netcode_CheckSocket($hSocket) <> 1 Then
		__Trace_Error(1, 0, "This Func can only be used with a parent", "", $hSocket)
		Return SetError(1, 0, __Trace_FuncOut("_netcode_SetIPList", False)) ; the given socket must be a parent
	EndIf
	__netcode_SocketSetIPList($hSocket, $arIPList, $bIsWhitelist)
	__Trace_FuncOut("_netcode_SetIPList")
EndFunc   ;==>_netcode_SetIPList

; set a global white / blacklist. this will affect all new parent sockets, not the existing.
; however not whitelisted or blacklisted IP's will not be disconnected here. Use _netcode_DisconnectClientsByIP() for that.
; you basically set this before you setup a listener. The Global IPList then overwrites the parents IPlist. So you could remove IP's from one
; specific parent if you like.
; The array given needs to be 0 based ([0] = first ip)
Func _netcode_SetGlobalIPList($arIPList, $bIsWhitelist)
	__Trace_FuncIn("_netcode_SetGlobalIPList", $arIPList, $bIsWhitelist)
	$__net_arGlobalIPList = $arIPList
	$__net_bGlobalIPListIsWhitelist = $bIsWhitelist
	__Trace_FuncOut("_netcode_SetGlobalIPList")
EndFunc   ;==>_netcode_SetGlobalIPList

; a client socket set OnHold wont execute any packets anymore. It will still recieve and disassemble until the buffer is full.
; could be usefull to defeat ddos or just to pause a transmission.
; marked for recoding
Func _netcode_SetSocketOnHold(Const $hSocket, $bSet)
	__Trace_FuncIn("_netcode_SetSocketOnHold", $hSocket, $bSet)
	_storageS_Overwrite($hSocket, '_netcode_SocketExecutionOnHold', $bSet)
	__Trace_FuncOut("_netcode_SetSocketOnHold")
EndFunc   ;==>_netcode_SetSocketOnHold

Func _netcode_GetSocketOnHold(Const $hSocket)
	__Trace_FuncIn("_netcode_GetSocketOnHold", $hSocket)
	__Trace_FuncOut("_netcode_GetSocketOnHold")
	Return _storageS_Read($hSocket, '_netcode_SocketExecutionOnHold')
EndFunc   ;==>_netcode_GetSocketOnHold

; get the Clients of the given Parent in a array. If $bJustTheCount is True you get the number of clients currently connected to the parent
Func _netcode_ParentGetClients(Const $hSocket, $bJustTheCount = False)
	__Trace_FuncIn("_netcode_ParentGetClients", $hSocket, $bJustTheCount)
	If __netcode_CheckSocket($hSocket) <> 1 Then
		__Trace_Error(1, 0, "This Func can only be used with a parent", "", $hSocket)
		Return SetError(1, 0, __Trace_FuncOut("_netcode_ParentGetClients", False)) ; this isnt a parent socket
	EndIf

	If $bJustTheCount Then
		Return __Trace_FuncOut("_netcode_ParentGetClients", UBound(__netcode_ParentGetClients($hSocket)))
	Else
		Return __Trace_FuncOut("_netcode_ParentGetClients", __netcode_ParentGetClients($hSocket))
	EndIf
EndFunc   ;==>_netcode_ParentGetClients

; returns the parent socket of the given client socket
Func _netcode_ClientGetParent(Const $hSocket)
	Return __netcode_ClientGetParent($hSocket)
EndFunc

; returns all known parent sockets managed by _netcode
Func _netcode_GetParents($bJustTheCount = False)
	if $bJustTheCount Then
		Return UBound($__net_arSockets)
	Else
		Return $__net_arSockets
	EndIf
EndFunc

; use this function to combine params into one string for when you want to send multiple params to a event. Arrays (also 2D) are supported too.
; if you have a event Func _event_example($user, $password, $idk) then you can simply use this _netcode_TCPSend(socket, 'example', _netcode_sParams($user, $password, $idk)).
; if you set $p1, leave $p2 at Default and then set $p3, then this function will only process $p1 as it expects any Default param to be the last.
; so if you want to set p3 and not p2 then give just any input but Default.
; ~ todo process and save var types so it returns the correct var types when unpacked.
Func _netcode_sParams($p1, $p2 = Default, $p3 = Default, $p4 = Default, $p5 = Default, $p6 = Default, $p7 = Default, $p8 = Default, $p9 = Default, $p10 = Default, $p11 = Default, $p12 = Default, $p13 = Default, $p14 = Default, $p15 = Default, $p16 = Default)
	__Trace_FuncIn("_netcode_sParams")
;~ 	Local $arParamStrings = __netcode_SocketGetParamStrings($ socket?
	Local $sParams = $__net_sParamIndicatorString
	Local $sEvalParam ; cannot preset vartype as the given param can be of any type

	For $i = 1 To 16
		$sEvalParam = Eval("p" & $i)
		If $sEvalParam = Default Then ExitLoop

		If $__net_bParamSplitBinary Then $sEvalParam = StringToBinary($sEvalParam)
		$sParams &= __netcode_CheckParamAndSerialize($sEvalParam) & $__net_sParamSplitSeperator
	Next

	Return __Trace_FuncOut("_netcode_sParams", StringTrimRight($sParams, StringLen($__net_sParamSplitSeperator)))

	; anti au3check error, ignore it
	If False = True Then
		__netcode_Au3CheckFix($p1)
		__netcode_Au3CheckFix($p2)
		__netcode_Au3CheckFix($p3)
		__netcode_Au3CheckFix($p4)
		__netcode_Au3CheckFix($p5)
		__netcode_Au3CheckFix($p6)
		__netcode_Au3CheckFix($p7)
		__netcode_Au3CheckFix($p8)
		__netcode_Au3CheckFix($p9)
		__netcode_Au3CheckFix($p10)
		__netcode_Au3CheckFix($p11)
		__netcode_Au3CheckFix($p12)
		__netcode_Au3CheckFix($p13)
		__netcode_Au3CheckFix($p14)
		__netcode_Au3CheckFix($p15)
		__netcode_Au3CheckFix($p16)
	EndIf
EndFunc   ;==>_netcode_sParams

Func _netcode_SocketToIP(Const $socket)
	__Trace_FuncIn("_netcode_SocketToIP", $socket)
;~ 	If $__net_hWs2_32 = -1 Then $__net_hWs2_32 = DllOpen('Ws2_32.dll')
	Local $structName = DllStructCreate("short;ushort;uint;char[8]")
	Local $sRet = DllCall($__net_hWs2_32, "int", "getpeername", "int", $socket, "ptr", DllStructGetPtr($structName), "int*", DllStructGetSize($structName))
	If Not @error Then
		$sRet = DllCall($__net_hWs2_32, "str", "inet_ntoa", "int", DllStructGetData($structName, 3))
		If Not @error Then Return __Trace_FuncOut("_netcode_SocketToIP", $sRet[0])
	EndIf
	Return __Trace_FuncOut("_netcode_SocketToIP", False)
EndFunc   ;==>_netcode_SocketToIP

Func _netcode_DisconnectClientsByIP($sIP)
	__Trace_FuncIn("_netcode_DisconnectClientsByIP", $sIP)

	Local $arClients[0]

	For $i = 0 To UBound($__net_arSockets) - 1
		$arClients = __netcode_ParentGetClients($__net_arSockets[$i])

		For $iS = 0 To UBound($arClients) - 1
			If _netcode_SocketToIP($arClients[$iS]) = $sIP Then
				__netcode_TCPCloseSocket($arClients[$iS])
				__netcode_RemoveSocket($arClients[$iS])
			EndIf
		Next
	Next
	__Trace_FuncOut("_netcode_DisconnectClientsByIP")
EndFunc   ;==>_netcode_DisconnectClientsByIP

; if you created a socket yourself and you want to add it to _netcode then you can use this.
; if you created a listener socket aka parent then _netcode_BindSocket(parent socket, False, how much connections the socket should accept at maximum)
; if you created a socket with TCPAccept aka client yourself then _netcode_BindSocket(client socket, parent socket, False, ip from parent, port from parent, username if used, password if used)
; if you add a client socket with _netcode_BindSocket(client socket, parent socket) but the parent is yet unknown to _netcode then
; first add the parent, because you cant add both with a single call.
; if you created a socket with TCPConnect aka client yourself then _netcode_BindSocket(client socket, "000")
; if you encounter errors you can view __netcode_AddSocket() for the error describtions.
Func _netcode_BindSocket(Const $hSocket, $hParentSocket = False, $nIfListenerMaxConnections = 200, $sIP = False, $nPort = False, $sUsername = False, $sPassword = False)
	__Trace_FuncIn("_netcode_BindSocket", $hSocket, $hParentSocket, $nIfListenerMaxConnections)
	Local $bReturn = __netcode_AddSocket($hSocket, $hParentSocket, $nIfListenerMaxConnections, $sIP, $nPort, $sUsername, $sPassword)
	Local $nError = @error
	Local $nExtended = @extended

	If $nError Then __Trace_Error($nError, $nExtended)
	Return SetError($nError, $nExtended, __Trace_FuncOut("_netcode_BindSocket", $bReturn))
EndFunc   ;==>_netcode_BindSocket

; releasing a socket means that it is being unlinked from this UDF.
; the socket will no longer being handled by the UDF but not closed.
; Only if you give a parent socket all client sockets from it get closed.
; you can use __netcode_ParentGetClients() if you want to Release the clients first.
Func _netcode_ReleaseSocket(Const $hSocket)
	__Trace_FuncIn("_netcode_ReleaseSocket", $hSocket)
	Return __Trace_FuncOut("_netcode_ReleaseSocket", __netcode_RemoveSocket($hSocket))
EndFunc   ;==>_netcode_ReleaseSocket

#cs
; ban a certain IP from connecting. Active connections are ignored.
Func _netcode_BanByIP($sIP, $nMode)
EndFunc   ;==>_netcode_BanByIP
#ce

; Set the parent to require a user login. All new incoming connections then need to send user and password.
; The User Management requires a database.
; give parent socket
; marked for recoding
Func _netcode_SocketSetUserManagement(Const $hSocket, $bSet, $sfDbFilePath, $sfDbPath = "")
	__Trace_FuncIn("_netcode_SocketSetUserManagement", $hSocket, $bSet, $sfDbFilePath, $sfDbPath)
	If __netcode_CheckSocket($hSocket) <> 1 Then
		__Trace_Error(1, 0, "This Func can only be used with a parent")
		Return SetError(1, 0, __Trace_FuncOut("_netcode_SocketSetUserManagement", False)) ; this isnt a parent
	EndIf
	_storageS_Overwrite($hSocket, '_netcode_IsUserManaged', $bSet)
	_storageS_Overwrite($hSocket, '_netcode_UserDBFile', $sfDbFilePath)

	If $sfDbPath = "" Then $sfDbPath = StringLeft($sfDbFilePath, StringInStr($sfDbFilePath, '\', 0, -1))
	_storageS_Overwrite($hSocket, '_netcode_UserDBUserDataPath', $sfDbPath)
	__Trace_FuncOut("_netcode_SocketSetUserManagement")
EndFunc   ;==>_netcode_SocketSetUserManagement

; give parent socket.
; will either Return False if its not UserManaged
; or an Array
; [0] = Path to the DB
; [1] = Path to the User Folder
Func _netcode_SocketGetUserManagement(Const $hSocket)
	__Trace_FuncIn("_netcode_SocketGetUserManagement", $hSocket)
	If __netcode_CheckSocket($hSocket) <> 1 Then
		__Trace_Error(1, 0, "This Func can only be used with a parent")
		Return SetError(1, 0, __Trace_FuncOut("_netcode_SocketGetUserManagement", False)) ; this isnt a parent
	EndIf
	If Not _storageS_Read($hSocket, '_netcode_IsUserManaged') Then Return __Trace_FuncOut("_netcode_SocketGetUserManagement", False)

	Local $arUserDB[2]
	$arUserDB[0] = _storageS_Read($hSocket, '_netcode_UserDBFile')
	$arUserDB[1] = _storageS_Read($hSocket, '_netcode_UserDBUserDataPath')

	Return __Trace_FuncOut("_netcode_SocketGetUserManagement", $arUserDB)
EndFunc   ;==>_netcode_SocketGetUserManagement

#cs
 Entire Rewrite in progress!

 this is the ACTIVE Database. The INACTIVE and Group Database is not coded yet.

 statuses
	Active		- Active users can communicate with the server
	OnHold		- OnHold users get disconnected and told that they are set OnHold
	Banned		- ~ todo Banned users get disconnected and if set told a ban reason
	Blocked		- ~ todo Will just disconnect the client

 alerts
	2FAError	- If the Client couldnt login with 2FA
	LoginError	- If the User tried to login with the wrong credentials

 alert extended gives extra info about the alerts
	2FAError	- A array containing the amount a client tried to login with false 2FA and their IP's + Dates (Serialized)
	LoginError	- -"-


 the User DB is used with a 2D array
	[0][0] = Username
	[0][1] = SHA256 Password
	[0][2] = Status
	[0][3] = If 2FA is set (True/False|Mode|email/phone etc.)
	[0][4] = Alertmode
	[0][5] = Alert extended (Serialized)
	[0][6] = if banned - banned till date
	[0][7] = if banned - banned reason
	[0][8] = How much Clients can use this User at once
	[0][9] = How much Clients there are currently using this User
	[0][10] = Which Sockets currently are bind to this user
	[0][11] = User Specific Events (Whitelist or Blacklist) (Serialized)
	[0][12] = User Group names (Serialized)
	[0][13] = Last Login Date
	[0][14] = The last x (e.g. 10) Login IP's and dates in a array which is serialized
	[0][15] = #Tags (Serialized)
	[0][16] = Notes (Serialized)
	[0][17] = space for custom value
	[0][18] = space for custom value

	missing: time of registration

 the password needs to be SHA256
#ce
Func _netcode_AddUser($hSocketOrsfDB, $sUsername, $sPassword = "", $sStatus = "Active", $sPublicKey = "")
	__Trace_FuncIn("_netcode_AddUser", $hSocketOrsfDB, $sUsername, $sPassword, $sStatus, $sPublicKey)
	If IsString($sUsername) Then $sUsername = StringToBinary($sUsername)

	Local $arUserDB = __netcode_GetUserDB($hSocketOrsfDB)
	Local $nArSize = UBound($arUserDB)
	Local $nIndex = __netcode_FindUser($arUserDB, $sUsername)
	If $nIndex <> -1 Then
		__Trace_Error(1, 0, "This User already exists", "", $sUsername)
		Return SetError(1, 0, __Trace_FuncOut("_netcode_AddUser", False)) ; user already exists
	EndIf

	ReDim $arUserDB[$nArSize + 1][19]
	$arUserDB[$nArSize][0] = $sUsername
	$arUserDB[$nArSize][1] = $sPassword
	$arUserDB[$nArSize][2] = $sStatus
	$arUserDB[$nArSize][3] = $sPublicKey
	$arUserDB[$nArSize][8] = 1
	$arUserDB[$nArSize][9] = 0

	__netcode_SetUserDB($hSocketOrsfDB, $arUserDB)

	Return __Trace_FuncOut("_netcode_AddUser", False)
EndFunc   ;==>_netcode_AddUser

Func _netcode_RemoveUser($hSocketOrsfDB, $sUsername)
	__Trace_FuncIn("_netcode_RemoveUser", $sUsername)
	If IsString($sUsername) Then $sUsername = StringToBinary($sUsername)

	Local $arUserDB = __netcode_GetUserDB($hSocketOrsfDB)
	Local $nArSize = UBound($arUserDB)
	Local $nIndex = __netcode_FindUser($arUserDB, $sUsername)
	If $nIndex = -1 Then
		__Trace_Error(1, 0, "Could not find User", "", $sUsername)
		Return SetError(1, 0, __Trace_FuncOut("_netcode_RemoveUser", False))
	EndIf

	For $i = 0 To 18
		$arUserDB[$nIndex][$i] = $arUserDB[$nArSize - 1][$i]
	Next

	ReDim $arUserDB[$nArSize - 1][19]

	__netcode_SetUserDB($hSocketOrsfDB, $arUserDB)

	Return __Trace_FuncOut("_netcode_RemoveUser", True)
EndFunc   ;==>_netcode_RemoveUser

Func _netcode_SocketGetUser(Const $hSocket)
	__Trace_FuncIn("_netcode_SocketGetUser", $hSocket)
	Return __Trace_FuncOut("_netcode_SocketGetUser", __netcode_SocketGetUser($hSocket))
EndFunc   ;==>_netcode_SocketGetUser

; $nElement 0 or 1
Func _netcode_SetCustomValue($hSocketOrsfDB, $sUsername, $nElement, $sData)
	__Trace_FuncIn("_netcode_SetCustomValue", $hSocketOrsfDB, $sUsername, $nElement, $sData)
	If IsString($sUsername) Then $sUsername = StringToBinary($sUsername)

	__netcode_UserDBChangeValue($hSocketOrsfDB, $sUsername, 17 + $nElement, $sData)
	__Trace_FuncOut("_netcode_SetCustomValue")
EndFunc   ;==>_netcode_SetCustomValue

Func _netcode_ChangeUsername($hSocketOrsfDB, $sUsername, $sToUsername)
	__Trace_FuncIn("_netcode_ChangeUsername", $hSocketOrsfDB, $sUsername, $sToUsername)
	If IsString($sUsername) Then $sUsername = StringToBinary($sUsername)
	If IsString($sToUsername) Then $sToUsername = StringToBinary($sToUsername)

	__netcode_UserDBChangeValue($hSocketOrsfDB, $sUsername, 0, $sToUsername)
	__Trace_FuncOut("_netcode_ChangeUsername")
EndFunc   ;==>_netcode_ChangeUsername

; password needs to be in SHA256
Func _netcode_ChangeUserPassword($hSocketOrsfDB, $sUsername, $sPassword)
	__Trace_FuncIn("_netcode_ChangeUserPassword", $hSocketOrsfDB, $sUsername, $sPassword)
	If IsString($sUsername) Then $sUsername = StringToBinary($sUsername)

	__netcode_UserDBChangeValue($hSocketOrsfDB, $sUsername, 1, $sPassword)
	__Trace_FuncOut("_netcode_ChangeUserPassword")
EndFunc   ;==>_netcode_ChangeUserPassword

Func _netcode_ChangeUserStatus($hSocketOrsfDB, $sUsername, $sStatus)
	__Trace_FuncIn("_netcode_ChangeUserStatus", $sUsername, $sStatus)
	If IsString($sUsername) Then $sUsername = StringToBinary($sUsername)

	__netcode_UserDBChangeValue($hSocketOrsfDB, $sUsername, 2, $sStatus)
	__Trace_FuncOut("_netcode_ChangeUserStatus")
EndFunc   ;==>_netcode_ChangeUserStatus

#cs
Func _netcode_ChangeUserRSAPublicKey($hSocketOrsfDB, $sUsername, $sPublicKey)
	If IsString($sUsername) Then $sUsername = StringToBinary($sUsername)

	__netcode_UserDBChangeValue($hSocketOrsfDB, $sUsername, 3, $sPublicKey)
EndFunc
#ce

Func _netcode_CreateUserDB($sfDbPath = @ScriptDir & "\userdb")
	__Trace_FuncIn("_netcode_CreateUserDB", $sfDbPath)
	If FileExists($sfDbPath) Then
		__Trace_Error(1, 0, "A file exists at this place", "", $sfDbPath)
		Return SetError(1, 0, __Trace_FuncOut("_netcode_CreateUserDB", False)) ; a file exists at this place
	EndIf

	Local $arUserDB[0][6]
	__netcode_SetUserDB($sfDbPath, $arUserDB)
	If @error Then
		__Trace_Error(2, 0, "Couldnt open or create the DB")
		Return SetError(2, 0, __Trace_FuncOut("_netcode_CreateUserDB", False)) ; couldnt open or create the file
	EndIf

	Return __Trace_FuncOut("_netcode_CreateUserDB", True)
EndFunc   ;==>_netcode_CreateUserDB

; returns the db 2d array
Func _netcode_ReadUserDB($sfDbPath = @ScriptDir & "\userdb")
	__Trace_FuncIn("_netcode_ReadUserDB", $sfDbPath)
	Return __Trace_FuncOut("_netcode_ReadUserDB", __netcode_GetUserDB($sfDbPath))
EndFunc   ;==>_netcode_ReadUserDB

; hashes the given data and returns the hash
Func _netcode_SHA256($sData)
	__Trace_FuncIn("_netcode_SHA256", "$sData")
	Return __Trace_FuncOut("_netcode_SHA256", __netcode_CryptSHA256($sData))
EndFunc   ;==>_netcode_SHA256


;~ Func _netcode_SetGlobalEnablePassword($bSet)
;~ EndFunc

; unfinished
; marked for recoding
Func _netcode_SetOption(Const $hSocket, $sOption, $sData)
	__Trace_FuncIn("_netcode_SetOption", $hSocket, $sOption, $sData)
	Switch $sOption

		Case "Encryption"
			If Not IsBool($sData) Then
				__Trace_Error(2, 0, "Data needs to be of type Bool", "", $sOption, VarGetType($sData))
				Return SetError(2, 0, __Trace_FuncOut("_netcode_SetOption", False)) ; $sData need to be of type Bool (True or False)
			EndIf

			__netcode_SocketSetPacketEncryption($hSocket, $sData)
			Return __Trace_FuncOut("_netcode_SetOption", True)

		Case "AllowSocketLinkingSetup"
			If Not IsBool($sData) Then
				__Trace_Error(2, 0, "Data needs to be of type Bool", "", $sOption, VarGetType($sData))
				Return SetError(2, 0, __Trace_FuncOut("_netcode_SetOption", False))
			EndIf

			if $sData Then
				_netcode_SetEvent($hSocket, 'netcode_socketlinksetup', "__netcode_EventSocketLinkSetup")
			Else
				_netcode_SetEvent($hSocket, 'netcode_socketlinksetup', "__netcode_EventSocketLinkSetup", False)
			EndIf

		Case "AllowSocketLinkingRequest"
			If Not IsBool($sData) Then
				__Trace_Error(2, 0, "Data needs to be of type Bool", "", $sOption, VarGetType($sData))
				Return SetError(2, 0, __Trace_FuncOut("_netcode_SetOption", False))
			EndIf

			if $sData Then
				_netcode_SetEvent($hSocket, 'netcode_socketlinkrequest', "__netcode_EventSocketLinkRequest")
				_netcode_SetEvent($hSocket, 'netcode_socketlinkconfirmation', "__netcode_EventSocketLinkConfirmation")
			Else
				_netcode_SetEvent($hSocket, 'netcode_socketlinkrequest', "__netcode_EventSocketLinkRequest", False)
				_netcode_SetEvent($hSocket, 'netcode_socketlinkconfirmation', "__netcode_EventSocketLinkConfirmation", False)
			EndIf

		Case Else
			__Trace_Error(1, 0, "Unknown Option", "", $sOption, $sData)
			Return SetError(1, 0, __Trace_FuncOut("_netcode_SetOption", False)) ; unknown option


	EndSwitch

	Return __Trace_FuncOut("_netcode_SetOption")
EndFunc   ;==>_netcode_SetOption

; unfinished
; marked for recoding
Func _netcode_PresetOption($sOption, $sData)
	__Trace_FuncIn("_netcode_PresetOption", $sOption, $sData)
	Switch $sOption

		Case "Seed"
			__netcode_Seeding(__netcode_StringToSeed($sData))
			Return __Trace_FuncOut("_netcode_PresetOption", True)

		Case Else
			__Trace_Error(1, 0, "Unkwnon Option", "", $sOption, $sData)
			Return SetError(1, 0, __Trace_FuncOut("_netcode_PresetOption", False)) ; unknown option

	EndSwitch
EndFunc   ;==>_netcode_PresetOption

; unfinished
; marked for recoding
Func _netcode_SetInternalOption($sOption, $sData)

	Switch $sOption

		Case "---change----"
			__netcode_Au3CheckFix($sData)


		Case Else
			Return SetError(1, 0, False)

	EndSwitch

EndFunc


; Barrier. Internals Below. No Functions are ment to be used individually but some probably can.
; =============================================================================================================================================

; the client must be given
; checks the IPlist.
Func __netcode_CheckSocketIfAllowed(Const $hSocket, $hParentSocket = False)
	__Trace_FuncIn("__netcode_CheckSocketIfAllowed", $hSocket, $hParentSocket)

	If Not $hParentSocket Then $hParentSocket = __netcode_ClientGetParent($hSocket)
	Local $sSocketIP = _netcode_SocketToIP($hSocket)

	; check if ip is white or blacklistet
	Local $arIPList = __netcode_SocketGetIPList($hParentSocket)
	Local $bIsWhitelist = @error

	Local $nIndex = -1
	For $i = 0 To UBound($arIPList) - 1
		If $arIPList[$i] = $sSocketIP Then
			$nIndex = $i
			ExitLoop
		EndIf
	Next

	If $bIsWhitelist Then
		If $nIndex = -1 Then Return __Trace_FuncOut("__netcode_CheckSocketIfAllowed", False)
	Else
		If $nIndex <> -1 Then Return __Trace_FuncOut("__netcode_CheckSocketIfAllowed", False)
	EndIf

	; check if IP is banned
	; ~ todo


	Return __Trace_FuncOut("__netcode_CheckSocketIfAllowed", True)
EndFunc   ;==>__netcode_CheckSocketIfAllowed

; executes all packets in the buffer, will fail if socket is OnHold
Func __netcode_ExecutePackets(Const $hSocket)
	__Trace_FuncIn("__netcode_ExecutePackets", $hSocket)

	If _netcode_GetSocketOnHold($hSocket) Then Return __Trace_FuncOut("__netcode_ExecutePackets") ; this socket is on hold

	Local $arPackages = __netcode_SocketGetExecutionBufferValues($hSocket)
	Local $nCurrentBufferIndex = @error
	Local $nCurrentIndex = _storageS_Read($hSocket, '_netcode_ExecutionIndex')
	Local $sID = ""

	For $i = $nCurrentIndex To UBound($arPackages) - 1
		If $arPackages[$i][0] = '' Then ExitLoop

		__netcode_ExecuteEvent($hSocket, $arPackages[$i][0], $arPackages[$i][1])

		; if the event disconnected the socket or released it then return since there is no longer a purpose to execute more or todo anything else
		if __netcode_CheckSocket($hSocket) == 0 Then Return __Trace_FuncOut("__netcode_ExecutePackets")

;~ 		_netcode_TCPSend($hSocket, 'netcode_internal', 'packet_confirmation|' & $i, False)
		$sID &= $i & ','

		$arPackages[$i][0] = ''
		$arPackages[$i][1] = ''

		$nCurrentIndex += 1
		If $nCurrentIndex = 1000 Then $nCurrentIndex = 0

	Next

	if $__net_bPacketConfirmation Then
		if $sID <> "" Then
			$sID = StringTrimRight($sID, 1) ; cutting the last ','
			_netcode_TCPSend($hSocket, 'netcode_internal', 'packet_confirmation|' & $sID, False)
		EndIf
	EndIf

	__netcode_SocketSetExecutionBufferValues($hSocket, $nCurrentBufferIndex, $arPackages)
	_storageS_Overwrite($hSocket, '_netcode_ExecutionIndex', $nCurrentIndex)
	__Trace_FuncOut("__netcode_ExecutePackets")
EndFunc   ;==>__netcode_ExecutePackets

; staging system
; note for me: generally i need a fast packet router, have to see if i can come up with a faster variant
Func __netcode_ManagePackages(Const $hSocket, $sPackages)
	__Trace_FuncIn("__netcode_ManagePackages", $hSocket, "$sPackages")

	Switch __netcode_SocketGetManageMode($hSocket)

		Case 0 ; 'auth'
			__netcode_ManageAuth($hSocket, $sPackages)


		Case 1 ; 'handshake'
			__netcode_ManageHandshake($hSocket, $sPackages)


		Case 2 ; 'user'
			__netcode_ManageUser($hSocket, $sPackages)


		Case 3 ; '2FA'
			; ~ todo


		Case 4 ; 'presyn'
			__netcode_ManagePreSyn($hSocket, $sPackages)


		Case 5 ; 'syn'
			; ~ todo


		Case 9 ; temp stage
			__netcode_ManageReady($hSocket, $sPackages)


		Case 10 ; 'netcode'
			__netcode_ManageNetcode($hSocket, $sPackages)


		Case 11
;~ 			__netcode_ManageRaw($hSocket, $sPackages)


		Case 12
			__netcode_ManageRawLinked($hSocket, $sPackages)


;~ 		Case 'unmanaged'
			; ~ todo


		Case Else
			; something wrong


	EndSwitch

	__Trace_FuncOut("__netcode_ManagePackages")
EndFunc   ;==>__netcode_ManagePackages

Func __netcode_SocketSetManageMode(Const $hSocket, $sMode)
	__Trace_FuncIn("__netcode_SocketSetManageMode", $hSocket, $sMode)
	Local $nMode = -1

	Switch $sMode

		Case 'auth'
			$nMode = 0

		Case 'handshake'
			$nMode = 1

		Case 'user'
			$nMode = 2

		Case '2FA'
			$nMode = 3

		Case 'presyn'
			$nMode = 4

		Case 'syn'
			$nMode = 5

		Case 'ready' ; temp stage
			$nMode = 9

		Case 'netcode'
			$nMode = 10

		Case 'raw'
			$nMode = 11

		Case 'rawlinked'
			$nMode = 12

		Case 'unmanaged'
			; ~ todo

	EndSwitch

	If $nMode = -1 Then
		__Trace_Error(1, 0, "Unknown manage mode")
		Return SetError(1, 0, __Trace_FuncOut("__netcode_SocketSetManageMode", False)) ; unknown manage mode
	EndIf

	_storageS_Overwrite($hSocket, '_netcode_SocketManageMode', Int($nMode))

	Return __Trace_FuncOut("__netcode_SocketSetManageMode", True)
EndFunc   ;==>__netcode_SocketSetManageMode

Func __netcode_SocketGetManageMode(Const $hSocket)
	__Trace_FuncIn("__netcode_SocketGetManageMode", $hSocket)

	Return __Trace_FuncOut("__netcode_SocketGetManageMode", _storageS_Read($hSocket, '_netcode_SocketManageMode'))
EndFunc   ;==>__netcode_SocketGetManageMode

Func __netcode_ManageAuth($hSocket, $sPackages)
	__Trace_FuncIn("__netcode_ManageAuth", "$sPackages")

	If StringInStr($sPackages, $__net_sAuthNetcodeString) <> 0 Then
		__netcode_SocketSetManageMode($hSocket, 'handshake')

		; tcpsend a confirmation
		__netcode_TCPSend($hSocket, StringToBinary($__net_sAuthNetcodeConfirmationString))

		__netcode_ExecuteEvent($hSocket, "connection", _netcode_sParams(1, ""))

		Return __Trace_FuncOut("__netcode_ManageAuth")
	EndIf

	Return SetError(__netcode_TCPCloseSocket($hSocket), __netcode_RemoveSocket($hSocket), __Trace_FuncOut("__netcode_ManageAuth", False))

EndFunc   ;==>__netcode_ManageAuth

Func __netcode_ManageHandshake($hSocket, $sPackages)
	__Trace_FuncIn("__netcode_ManageHandshake", "$sPackages")
	$sPackages = StringToBinary($sPackages)

	; temporary fix
;~ 	$__net_nInt_TemporarySRandomFix += 1
;~ 	SRandom($__net_nInt_TemporarySRandomFix)
;~ 	__netcode_SRandomTemporaryFix()

	Local $sPW = __netcode_RandomPW(40, 3)
	Local $sEncryptionKey = __netcode_AESDeriveKey($sPW, "packetencryption")

	; encrypt AES Key with the the pub from the client
	Local $sEncData = __netcode_RSAEncrypt($sPW, $sPackages)

	If $sEncData == 0 Then
;~ 		__Trace_Error(
		Return SetError(__netcode_TCPCloseSocket($hSocket), __netcode_RemoveSocket($hSocket), __Trace_FuncOut("__netcode_ManageHandshake", False))
	EndIf
	__netcode_SocketSetOtherRSA($hSocket, $sPackages)
	__netcode_SocketSetPacketEncryptionPassword($hSocket, $sEncryptionKey)

	; send the encrypted key
	__netcode_TCPSend($hSocket, $sEncData)

	; set if set the USER stage if not enter presyn stage
	If IsArray(_netcode_SocketGetUserManagement(__netcode_ClientGetParent($hSocket))) Then
		__netcode_SocketSetManageMode($hSocket, 'user')
	Else
		__netcode_SocketSetManageMode($hSocket, 'presyn')
	EndIf

	__netcode_ExecuteEvent($hSocket, "connection", _netcode_sParams(2, $sPW))
	__Trace_FuncOut("__netcode_ManageHandshake")
EndFunc   ;==>__netcode_ManageHandshake

; unfinished
Func __netcode_ManageUser($hSocket, $sPackages)
	__Trace_FuncIn("__netcode_ManageUser", "$sPackages")
	Local $hPassword = __netcode_SocketGetPacketEncryptionPassword($hSocket)
	$sPackages = BinaryToString(__netcode_AESDecrypt(Binary(BinaryToString($sPackages)), $hPassword))

	Local $arPackages = StringSplit($sPackages, ':', 1)
	If $arPackages[0] < 3 Then
		; disconnect
		Return SetError(__netcode_TCPCloseSocket($hSocket), __netcode_RemoveSocket($hSocket), __Trace_FuncOut("__netcode_ManageUser", False))
	ElseIf $arPackages[1] <> 'login' Then
		; disconnect
		Return SetError(__netcode_TCPCloseSocket($hSocket), __netcode_RemoveSocket($hSocket), __Trace_FuncOut("__netcode_ManageUser", False))
	EndIf

	If Not __netcode_ManageUserLogin($hSocket, $arPackages, $hPassword) Then Return __Trace_FuncOut("__netcode_ManageUser")

	__netcode_ExecuteEvent($hSocket, "connection", _netcode_sParams(3, $arPackages[2]))
	__netcode_SocketSetManageMode($hSocket, 'presyn')
	__Trace_FuncOut("__netcode_ManageUser")
EndFunc   ;==>__netcode_ManageUser

#cs
 the array is 2D
	[0][0] = Username
	[0][1] = SHA256 Password
	[0][2] = Status
	[0][3] = 2FA Public RSA Key (if the Option is set)
	[0][4] = Alertmode
	[0][5] = Alert extended
	[0][6] = if banned - banned till date
	[0][7] = if banned - banned reason
	[0][8] = How much Clients can use this User at once
	[0][9] = How much Clients there are currently using this User
	[0][10] = Which Sockets currently are bind to this user - Array Serialized with |
	[0][11] = User Specific Events - Array Serialized with |
	[0][12] = User Group names (Serialized)
	[0][13] = Last Login Date
	[0][14] = The last 10 Login IP's and dates in a array which is serialized
	[0][15] = #Tags (Serialized)
	[0][16] = Notes (Serialized)
	[0][17] = space for custom value
	[0][18] = space for custom value
#ce
Func __netcode_ManageUserLogin($hSocket, $arPacket, $hPassword)
	__Trace_FuncIn("__netcode_ManageUserLogin", "$arPacket", "$hPassword")
	Local $hParentSocket = __netcode_ClientGetParent($hSocket)
	Local $arUserDB = __netcode_GetUserDB($hParentSocket)

	; locate user
	Local $nIndex = __netcode_FindUser($arUserDB, $arPacket[2])
	If $nIndex = -1 Then
		; disconnect
;~ 		__netcode_PreDisconnect($hSocket, True, True, True)
		__netcode_TCPSend($hSocket, __netcode_AESEncrypt("Wrong", $hPassword))
		Return SetError(__netcode_TCPCloseSocket($hSocket), __netcode_RemoveSocket($hSocket), __Trace_FuncOut("__netcode_ManageUserLogin", False))
	EndIf

	; check credentials
	If StringLen($arPacket[3]) <> 66 Then
		if StringLen($arPacket[3]) <= $__net_nMaxPasswordLen Then $arPacket[3] = _netcode_SHA256($arPacket[3])
		if StringLen($arPacket[3]) <> 66 Then Return SetError(__netcode_TCPCloseSocket($hSocket), __netcode_RemoveSocket($hSocket), __Trace_FuncOut("__netcode_ManageUserLogin", False))
	EndIf

	If $arUserDB[$nIndex][1] <> $arPacket[3] Then
		__netcode_TCPSend($hSocket, __netcode_AESEncrypt("Wrong", $hPassword))
;~ 		__netcode_PreDisconnect($hSocket, True, True, True)

		; if failed set Alert ~ todo

		Return SetError(__netcode_TCPCloseSocket($hSocket), __netcode_RemoveSocket($hSocket), __Trace_FuncOut("__netcode_ManageUserLogin", False))
	EndIf

	; check for [0][3] if set here


	; check user status
	If $arUserDB[$nIndex][2] <> "Active" Then
		If $arUserDB[$nIndex][2] = "Banned" Then

			; ~ todo
			; if banned check till and revert the ban if neccessary here.
			; also send the ban reason.

			__netcode_TCPSend($hSocket, __netcode_AESEncrypt("Banned", $hPassword))
		ElseIf $arUserDB[$nIndex][2] = "OnHold" Then
			__netcode_TCPSend($hSocket, __netcode_AESEncrypt("OnHold", $hPassword))
		EndIf

;~ 		__netcode_PreDisconnect($hSocket, True, True, True)
		Return SetError(__netcode_TCPCloseSocket($hSocket), __netcode_RemoveSocket($hSocket), __Trace_FuncOut("__netcode_ManageUserLogin", False))
	EndIf

	; check for [0][8] & [0][9] and if add to [0][9] and [0][10]


	; set [0][13] and [0][14]


	; read [0][11] and add the events


	; read alerts and extended


	; send sucess and additional data
;~ 	__netcode_TCPSend($hSocket, __netcode_AESEncrypt("Success", $hPassword))
	__netcode_TCPSend($hSocket, StringToBinary(__netcode_AESEncrypt("Success", $hPassword), 4))

	; has to save the UID not the username <<<=======================================<<<<<<<
	__netcode_SocketSetUser($hSocket, $arPacket[2])
	Return __Trace_FuncOut("__netcode_ManageUserLogin", True)
EndFunc   ;==>__netcode_ManageUserLogin

Func __netcode_ManagePreSyn($hSocket, $sPackages)
	__Trace_FuncIn("__netcode_ManagePreSyn", $hSocket, "$sPackages")
	Local $hPassword = __netcode_SocketGetPacketEncryptionPassword($hSocket)
;~ 	$sPackages = __netcode_AESDecrypt(StringToBinary($sPackages), $hPassword)
	$sPackages = BinaryToString(__netcode_AESDecrypt(Binary(BinaryToString($sPackages)), $hPassword))

;~ 	MsgBox(0, "PreSyn", BinaryToString($sPackages))

	; seed for this parent
	; max package size for this parent
	; default package size for this parent
	; encryption toggle for this parent
	; packet validation toggle for this parent
	; further rules

	Local $arPreSyn[4][2]
	$arPreSyn[0][0] = "MaxRecvBufferSize"
	$arPreSyn[0][1] = $__net_nMaxRecvBufferSize
	$arPreSyn[1][0] = "DefaultRecvLen"
	$arPreSyn[1][1] = $__net_nDefaultRecvLen
	$arPreSyn[2][0] = "Encryption"
	$arPreSyn[2][1] = __netcode_SocketGetPacketEncryption(__netcode_ClientGetParent($hSocket))
	$arPreSyn[3][0] = "Seed"
	$arPreSyn[3][1] = Number(__netcode_RandomPW(12, 1))

	Local $sPreSyn = StringToBinary(__netcode_CheckParamAndSerialize($arPreSyn))

;~ 	__netcode_TCPSend($hSocket, __netcode_AESEncrypt($sPreSyn, $hPassword))
	__netcode_TCPSend($hSocket, StringToBinary(__netcode_AESEncrypt($sPreSyn, $hPassword), 4))

	__netcode_SeedingClientStrings($hSocket, $arPreSyn[3][1])

	__netcode_ExecuteEvent($hSocket, "connection", _netcode_sParams(4, $arPreSyn))
;~ 	__netcode_SocketSetManageMode($hSocket, 'syn')

;~ 	__netcode_ExecuteEvent($hSocket, "connection", 10) ; temp - will move to the syn stage
	__netcode_ExecuteEvent($hSocket, "connection", _netcode_sParams(9, "")) ; temp - will move to the syn stage
;~ 	__netcode_SocketSetManageMode($hSocket, 'netcode')
	__netcode_SocketSetManageMode($hSocket, 'ready')
	__Trace_FuncOut("__netcode_ManagePreSyn")
EndFunc   ;==>__netcode_ManagePreSyn

Func __netcode_ManageSyn($hSocket, $sPackages)
	; ~ todo
	Return

	__netcode_Au3CheckFix($hSocket)
	__netcode_Au3CheckFix($sPackages)
EndFunc   ;==>__netcode_ManageSyn

Func __netcode_ManageReady($hSocket, $sPackages)
	__Trace_FuncIn("__netcode_ManageReady", "$sPackages")

;~ 	MsgBox(0, @ScriptName, $sPackages)

	__netcode_ExecuteEvent($hSocket, "connection", _netcode_sParams(10, ""))
	__netcode_SocketSetManageMode($hSocket, 'netcode')

;~ 	_storageS_Overwrite($hSocket, '_netcode_IncompletePacketBuffer', $sPackages)
	__netcode_ManageNetcode($hSocket, $sPackages)

	#cs
	Local $hPassword = __netcode_SocketGetPacketEncryptionPassword($hSocket)
	$sPackages = BinaryToString(__netcode_AESDecrypt(StringToBinary($sPackages), $hPassword))

	if $sPackages = "Ready" Then
		__netcode_ExecuteEvent($hSocket, "connection", 10)
		__netcode_SocketSetManageMode($hSocket, 'netcode')
	Else
		__Trace_Error(1, 0, "Couldnt Decrypt Ready Stage packet")
		Return SetError(__netcode_TCPCloseSocket($hSocket), __netcode_RemoveSocket($hSocket), __Trace_FuncOut("__netcode_ManageReady", False))
	EndIf
	#ce

	__Trace_FuncOut("__netcode_ManageReady")
EndFunc

; marked for recoding
Func __netcode_ManageNetcode($hSocket, $sPackages)
	__Trace_FuncIn("__netcode_ManageNetcode", "$sPackages")

	$sPackages = _storageS_Read($hSocket, '_netcode_IncompletePacketBuffer') & $sPackages
;~ 	if @ScriptName = "server.au3" Then MsgBox(0, "", _storageS_Read($hSocket, '_netcode_IncompletePacketBuffer'))
	_storageS_Overwrite($hSocket, '_netcode_IncompletePacketBuffer', "")
	; if the StringLeft() isnt $__net_sPacketBegin then we may have no netcode packet and have to check if its maybe something socks etc. related

	Local $arPacketStrings = __netcode_SocketGetPacketStrings($hSocket)
	Local $sPacketBegin = $arPacketStrings[0]
	Local $sPacketInternalSplit = $arPacketStrings[1]
	Local $sPacketEnd = $arPacketStrings[2]
;~ 	Local $sPacketBegin = $__net_sPacketBegin
;~ 	Local $sPacketInternalSplit = $__net_sPacketInternalSplit
;~ 	Local $sPacketEnd = $__net_sPacketEnd

	Local $arPackages = StringSplit($sPackages, $sPacketBegin, 1)
	Local $arPacketContent[0]
;~ 	Local $hPassword = Ptr("")
	Local $hPassword = __netcode_SocketGetPacketEncryptionPassword($hSocket)

;~ 	if @ScriptName = "server.au3" Then _ArrayDisplay($arPackages)
;~ 	if @ScriptName = "server.au3" Then MsgBox(0, "", $sPackages)

	For $i = 2 To $arPackages[0]
		If StringRight($arPackages[$i], 10) <> $sPacketEnd Then
			; packet is incomplete
			; if its not the last in the array then the whole recv most probably also is corrupted
			; ~ todo

			_storageS_Overwrite($hSocket, '_netcode_IncompletePacketBuffer', $sPacketBegin & $arPackages[$i])
;~ 			MsgBox(0, @ScriptName, $i & @CRLF & $arPackages[0] & @CRLF & @CRLF & StringRight($arPackages[$i], 10))
;~ 			_ArrayDisplay($arPackages)
			ContinueLoop
		EndIf

		$arPackages[$i] = StringTrimRight($arPackages[$i], 10)

		$arPacketContent = StringSplit($arPackages[$i], $sPacketInternalSplit, 1)
;~ 		_ArrayDisplay($arPacketContent)

		; if packet is not encrypted but it should then see if this is allowed, if not reject
		If __netcode_SocketGetPacketEncryption($hSocket) Then
			If $arPacketContent[0] < 2 Then
				; if allowed

;~ 				$hPassword = __netcode_SocketGetPacketEncryptionPassword($hSocket)
				$arPacketContent = StringSplit(BinaryToString(__netcode_AESDecrypt(StringToBinary($arPackages[$i]), $hPassword)), $sPacketInternalSplit, 1)


			EndIf
		Else
			; check if encrypted but shouldnt be and see if this is allowed, if not reject

		EndIf

		; if $arPacketContent[0] is <> 4 then reject packet

;~ 		if @ScriptName = "Server.au3" Then MsgBox(0, $arPacketContent[1], $arPacketContent[3])

		; maybe the Internal Split string reoccured in the data then merge all elements above [4] into [4]
		If $arPacketContent[0] > 4 Then
			For $i = 5 To $arPacketContent[0]
				$arPacketContent[4] &= $sPacketInternalSplit & $arPacketContent[$i]
			Next
		EndIf

		; [1] = id for packet safety
		; [2] = hash
		; [3] = event
		; [4] = data

;~ 		_ArrayDisplay($arPacketContent)

;~ 		$arPacketContent[4] = BinaryToString(__netcode_lzntdecompress(StringToBinary($arPacketContent[4])))

		__netcode_SocketSetRecvPacketPerSecond($hSocket, 1)

		If $arPacketContent[3] = 'netcode_internal' Then
			__netcode_ExecuteEvent($hSocket, 'netcode_internal', $arPacketContent[4])
			ContinueLoop
		EndIf

		; invalid events
		if $arPacketContent[3] = 'connection' Or $arPacketContent[3] = 'disconnected' Then
			__Trace_Error(1, 0, "Invalid Event: " & $arPacketContent[3] & " was send. Data and event gets rejected")
			$arPacketContent[3] = "208519967649002627"
			$arPacketContent[4] = '' ; data is rejected
		EndIf

		__netcode_AddToExecutionBuffer($hSocket, $arPacketContent[1], $arPacketContent[3], $arPacketContent[4])

	Next

	__Trace_FuncOut("__netcode_ManageNetcode")
EndFunc   ;==>__netcode_ManageNetcode

Func __netcode_ManageRawLinked(Const $hSocket, $sData)
	__Trace_FuncIn("__netcode_ManageRawLinked")

;~ 	MsgBox(0, @ScriptName, $sData)

	Local $sCallback = __netcode_SocketGetLinkedCallback($hSocket)
	if Not $sCallback Then
		__Trace_Error(1, 0, "Couldnt get a Callback")
		Return __Trace_FuncOut("__netcode_ManageRawLinked")
	EndIf

	Call($sCallback, $hSocket, "", $sData, _netcode_SocketLinkGetAdditionalData($hSocket))
	Switch @error

		Case "0xDEAD"
			__Trace_Error(2, 0, "Cannot Call")
			Return __Trace_FuncOut("__netcode_ManageRawLinked")

		Case "0xBEEF"
			__Trace_Error(3, 0, "Cannot Call")
			Return __Trace_FuncOut("__netcode_ManageRawLinked")

	EndSwitch

	__Trace_FuncOut("__netcode_ManageRawLinked")
EndFunc


; for _netcode_TCPConnect() only
; ~ todo remove this function
Func __netcode_PreRecvPackages(Const $hSocket)
	__Trace_FuncIn("__netcode_PreRecvPackages", $hSocket)

	Local $sPackage = ""

	Do
		$sPackage = __netcode_RecvPackages($hSocket)
		If @extended = 1 Then
;~ 			__netcode_TCPCloseSocket($hSocket)
;~ 			__netcode_RemoveSocket($hSocket)

			__Trace_Error(2, 0, "Disconnected")
			Return SetError(2, 0, __Trace_FuncOut("__netcode_PreRecvPackages", False)) ; lost connection
		EndIf

		; timeout here ~ todo

	Until $sPackage <> ''

	Return __Trace_FuncOut("__netcode_PreRecvPackages", $sPackage)
EndFunc   ;==>__netcode_PreRecvPackages


Func __netcode_AddPacketToQue(Const $hSocket, $sPackage, $nID = False)
	__Trace_FuncIn("__netcode_AddPacketToQue", $hSocket, "$sPackage", $nID)

	if $hSocket == False Then ; temp patch, requires investigation
;~ 		__Trace_Error(1, 0, "Socket is FALSE")
		Return __Trace_FuncOut("__netcode_AddPacketToQue")
	EndIf

	Local $nArSize = UBound($__net_arPacketSendQue)

	Local $nIndex = -1
	For $i = 0 To $nArSize - 1
		If $__net_arPacketSendQue[$i] = $hSocket Then
			$nIndex = $i
			ExitLoop
		EndIf
	Next

	If $nIndex = -1 Then
		ReDim $__net_arPacketSendQue[$nArSize + 1]
		$__net_arPacketSendQue[$nArSize] = $hSocket
	EndIf

	_storageS_Append($hSocket, '_netcode_PacketQuo', $sPackage)
	If $nID == False Then ; if Not $nID == False Then <- does not work If $nID <> False would also be True if $nID = 0. So it had to be done like here
	Else
		if Not $__net_bPacketConfirmation Then _storageS_Append($hSocket, '_netcode_PacketQuoIDQuo', $nID & ',')
	EndIf

	__Trace_FuncOut("__netcode_AddPacketToQue")
EndFunc   ;==>__netcode_AddPacketToQue

;~ _storageS_Overwrite($hSocket, '_netcode_PacketQuoIDQuo', "")
;~ _storageS_Overwrite($hSocket, '_netcode_PacketQuoIDWait', "")
; requires heavy testing to make sure that 'send' doesnt fail
Func __netcode_SendPacketQuo()
	__Trace_FuncIn("__netcode_SendPacketQuo")

	; there is no socket quoed
	if UBound($__net_arPacketSendQue) = 0 Then Return __Trace_FuncOut("__netcode_SendPacketQuo")

	; select clients of the send quo that are ready to send
	Local $arTempSendQuo = __netcode_SocketSelect($__net_arPacketSendQue, False)

	; if none are capable
	if UBound($arTempSendQuo) = 0 Then Return __Trace_FuncOut("__netcode_SendPacketQuo")

	; locals
	Local $nIndex = -1
	Local $nArSize = 0
	Local $nError = 0
	Local $bDisconnect = False
	Local $sData = ""

	; for every socket in the filtered send quo
	For $i = 0 To UBound($arTempSendQuo) - 1

		; send non-blocking
;~ 		$sData = StringToBinary(_storageS_Read($arTempSendQuo[$i], '_netcode_PacketQuo'), 4) ; Reverted - Fix from 1.5.10
		$sData = StringToBinary(_storageS_Read($arTempSendQuo[$i], '_netcode_PacketQuo'))
		__netcode_TCPSend($arTempSendQuo[$i], $sData, False)
		$nError = @error

		; empty the packet quo for the socket
		_storageS_Overwrite($arTempSendQuo[$i], '_netcode_PacketQuo', '')

		; see if the socket is disconnected
		Switch $nError
			Case 10050 To 10054
;~ 				_netcode_TCPDisconnect($arTempSendQuo[$i]) ; dont use internally
				__netcode_TCPCloseSocket($arTempSendQuo[$i])
				__netcode_RemoveSocket($arTempSendQuo[$i], False, False, $nError)

			Case 10035
				__netcode_SocketSetSendBytesPerSecond($arTempSendQuo[$i], BinaryLen($sData))

				if Not $__net_bPacketConfirmation Then
					Local $arIDs = StringSplit(_storageS_Read($arTempSendQuo[$i], '_netcode_PacketQuoIDQuo'), ',', 1)
					For $iS = 1 To $arIDs[0]
						__netcode_RemoveFromSafetyBuffer($arTempSendQuo[$i], $arIDs[$iS])
					Next
				EndIf

			Case Else
				__netcode_SocketSetSendBytesPerSecond($arTempSendQuo[$i], BinaryLen($sData))

				if Not $__net_bPacketConfirmation Then
					ReDim $__net_arPacketSendQueIDWait[UBound($__net_arPacketSendQueIDWait) + 1]
					$__net_arPacketSendQueIDWait[UBound($__net_arPacketSendQueIDWait) - 1] = $arTempSendQuo[$i]

					_storageS_Overwrite($arTempSendQuo[$i], '_netcode_PacketQuoIDWait', _storageS_Read($arTempSendQuo[$i], '_netcode_PacketQuoIDQuo'))
					_storageS_Overwrite($arTempSendQuo[$i], '_netcode_PacketQuoIDQuo', "")
				EndIf

		EndSwitch



		; remove socket from the global send quo array
		$nArSize = UBound($__net_arPacketSendQue)
		if $nArSize = 1 Then
			ReDim $__net_arPacketSendQue[0]
			ContinueLoop
		EndIf

		; find the socket in the array
		$nIndex = -1
		For $iS = 0 To $nArSize - 1
			if $__net_arPacketSendQue[$iS] = $arTempSendQuo[$i] Then
				$nIndex = $iS
				ExitLoop
			EndIf
		Next
		if $nIndex = -1 Then Exit MsgBox(16, "Development Error", "786340")

		; and remove it by replacing it with the last
		$__net_arPacketSendQue[$nIndex] = $__net_arPacketSendQue[$nArSize - 1]
		ReDim $__net_arPacketSendQue[$nArSize - 1]
	Next

	__Trace_FuncOut("__netcode_SendPacketQuo")
EndFunc

Func __netcode_SendPacketQuoIDQuerry()
	if UBound($__net_arPacketSendQueIDWait) = 0 Then Return

;~ 	ConsoleWrite(UBound($__net_arPacketSendQueIDWait) & @CRLF)

	Local $arTempSendQuo = __netcode_SocketSelect($__net_arPacketSendQueIDWait, False)
	if UBound($arTempSendQuo) = 0 Then Return

;~ 	_ArrayDisplay($__net_arPacketSendQueIDWait, @ScriptName)

	Local $arIDs = ""
	Local $nArSize = 0
	Local $bFound = False

	For $i = 0 To UBound($arTempSendQuo) - 1
		$arIDs = StringSplit(_storageS_Read($arTempSendQuo[$i], '_netcode_PacketQuoIDWait'), ',', 1)
;~ 		_ArrayDisplay($arIDs, @ScriptName)

		For $iS = 1 To $arIDs[0]
			if $arIDs[$iS] = "" Then ContinueLoop
			__netcode_RemoveFromSafetyBuffer($arTempSendQuo[$i], $arIDs[$iS])
		Next

		Do
			$bFound = False
			$nArSize = UBound($__net_arPacketSendQueIDWait)
			For $iS = 0 To $nArSize - 1
				if $__net_arPacketSendQueIDWait[$iS] = $arTempSendQuo[$i] Then

					$__net_arPacketSendQueIDWait[$iS] = $__net_arPacketSendQueIDWait[$nArSize - 1]
					ReDim $__net_arPacketSendQueIDWait[$nArSize - 1]
					$bFound = True

					ExitLoop
				EndIf
			Next
		Until Not $bFound

		_storageS_Overwrite($arTempSendQuo[$i], '_netcode_PacketQuoIDWait', '')
	Next
EndFunc

#cs
	Each packet quoed up in _netcode_TCPSend() is here given to the 'send' function.
	__netcode_TCPSend() is set to return even if the send is yet not done (duo to it being non blocking).
	If 'send' returns 10035 (would block) then this func will store the send data to the storage var "_netcode_PacketQuoSend"
	and the socket to the $__net_arPacketSendQueWait Global var.
	The next time this func is called it will check each socket in $__net_arPacketSendQueWait to see if
	'send' reports a different error then 10035 (would block). If so then it removes the socket from the $__net_arPacketSendQueWait
	array and reset the storage var "_netcode_PacketQuoSend".

	If a socket is in $__net_arPacketSendQueWait then no new data is given to 'send' until the previous data is successfully
	send.

	So this function makes sure the data is send in order but will not block until 'send' reports it as send.
	This is usefull in a situation where a client of multiple has a much slower internet connection.
	Usually this client would then slow down the whole UDF. But with this system that doesnt happen.
#ce
; note - inefficient
; marked for recoding
; "The select, WSAAsyncSelect or WSAEventSelect functions can be used to determine when it is possible to send more data."
; make use of that instead of using the current system, not just because its inefficient but also its most probably not intended like how its done here.
; check socket with "writefds:" __netcode_SocketSelect() should already be capable todo that.
Func __netcode_SendPacketQuo_Backup()
	__Trace_FuncIn("__netcode_SendPacketQuo")
	Local $nArSize = UBound($__net_arPacketSendQue)
	Local $nArSizeWait = UBound($__net_arPacketSendQueWait)
	If $nArSize = 0 And $nArSizeWait = 0 Then Return __Trace_FuncOut("__netcode_SendPacketQuo")

	; check if 'send' reported back that it has send the data
	if $nArSizeWait > 0 Then
		Local $arTempSendQuo = $__net_arPacketSendQueWait
		Local $nIndex = -1, $bDisconnect = False, $nError = 0

		; for each socket in $__net_arPacketSendQueWait
		For $i = 0 To $nArSizeWait - 1
			$bDisconnect = False

			; take the last send data and check if 'Send' reports that it is send
			__netcode_TCPSend($arTempSendQuo[$i], StringToBinary(_storageS_Read($arTempSendQuo[$i], '_netcode_PacketQuoSend')), False)
			$nError = @error
			; if it is send then remove the socket from the wait que
			Switch $nError
				Case 10035
					; nothing

				Case 0, 10050 To 10054
					_storageS_Overwrite($arTempSendQuo[$i], '_netcode_PacketQuoSend', "")

					; if its the only socket in the list then reset the array
					if UBound($__net_arPacketSendQueWait) = 1 Then
						ReDim $__net_arPacketSendQueWait[0]

					Else

						; find the socket in the array
						$nIndex = -1
						For $iS = 0 to UBound($__net_arPacketSendQueWait) - 1
							if $__net_arPacketSendQueWait[$iS] = $arTempSendQuo[$i] Then
								$nIndex = $iS
								ExitLoop
							EndIf
						Next
						if $nIndex = -1 Then Exit MsgBox(16, "Development error", "36923638942342698 CTRL+F me in _netcode_Core.au3") ; this error should never happen, but if does then because of a programming mistake in this UDF

						; remove the socket
						$__net_arPacketSendQueWait[$nIndex] = $__net_arPacketSendQueWait[UBound($__net_arPacketSendQueWait) - 1]
						ReDim $__net_arPacketSendQueWait[UBound($__net_arPacketSendQueWait) - 1]

					EndIf

					if $nError > 0 then $bDisconnect = True
			EndSwitch

			if $bDisconnect Then
				_netcode_TCPDisconnect($arTempSendQuo[$i])
			EndIf
		Next
		$nArSizeWait = UBound($__net_arPacketSendQueWait)
	EndIf

	Local $sData = "", $arTempSendQuo = $__net_arPacketSendQue, $nIndex = -1, $bDisconnect = False
	For $i = 0 To $nArSize - 1
		$bDisconnect = False
		if $nArSizeWait > 0 Then
			; if the current socket already has quoed to send data where the 'send' function hasnt yet reported back that it has send the data then
			; skip this socket
			For $iS = 0 To $nArSizeWait - 1
				if $__net_arPacketSendQueWait[$iS] = $arTempSendQuo[$i] Then ContinueLoop 2
			Next
		EndIf

		$sData = _storageS_Read($arTempSendQuo[$i], '_netcode_PacketQuo')
		__netcode_TCPSend($arTempSendQuo[$i], StringToBinary($sData), False)

		Switch @error
			Case 10035
				_storageS_Overwrite($arTempSendQuo[$i], '_netcode_PacketQuoSend', $sData)
				ReDim $__net_arPacketSendQueWait[UBound($__net_arPacketSendQueWait) + 1]
				$__net_arPacketSendQueWait[UBound($__net_arPacketSendQueWait) - 1] = $arTempSendQuo[$i]

			Case 10050 To 10054
				$bDisconnect = True

		EndSwitch

		_storageS_Overwrite($arTempSendQuo[$i], '_netcode_PacketQuo', '')

		; remove the socket from the send quo

		; if its the only socket in the list then reset the array
		if UBound($__net_arPacketSendQue) = 1 Then
			ReDim $__net_arPacketSendQue[0]
		Else

			; search and remove the last socket from the array
			$nIndex = -1
			For $iS = 0 To UBound($__net_arPacketSendQue) - 1
				if $__net_arPacketSendQue[$iS] = $arTempSendQuo[$i] Then
					$nIndex = $iS
					ExitLoop
				EndIf
			Next
			if $nIndex = -1 Then Exit MsgBox(16, "Development error", "2564387237898 CTRL+F me in _netcode_Core.au3") ; this error should never happen, but if does then because of a programming mistake in this UDF

			$__net_arPacketSendQue[$nIndex] = $__net_arPacketSendQue[UBound($__net_arPacketSendQue) - 1]
			ReDim $__net_arPacketSendQue[UBound($__net_arPacketSendQue) - 1]
		EndIf


		if $bDisconnect Then
			_netcode_TCPDisconnect($arTempSendQuo[$i])
		EndIf
	Next

	__Trace_FuncOut("__netcode_SendPacketQuo")
EndFunc   ;==>__netcode_SendPacketQuo

; execution buffer
; [x][0] = packet id
; [x][1] = event name
; [x][2] = data
Func __netcode_AddToExecutionBuffer(Const $hSocket, $sID, $sEvent, $sData)
	__Trace_FuncIn("__netcode_AddToExecutionBuffer", $hSocket, $sID, $sEvent, "$sData")
	; read current Execution buffer and its current index
	Local $arBuffer = __netcode_SocketGetExecutionBufferValues($hSocket)
	Local $nCurrentBufferIndex = @error
	Local $nPacketID = Number($sID)
	Local $nCurrentIndex = _storageS_Read($hSocket, '_netcode_ExecutionIndex')

;~ 	MsgBox(0, @ScriptName, $nPacketID & @CRLF & $nCurrentBufferIndex)

	; check if ID matches
	If $nPacketID <> $nCurrentBufferIndex Then
		If $nPacketID >= 1000 Then
			; this packet is very bad - order the last send packet from the socket and do not save this as it would break the order
			; also set the socket OnHold
			Return __Trace_FuncOut("__netcode_AddToExecutionBuffer")
		EndIf

		; missing packet/s - save this packet to its packet id and set the socket OnHold
		_netcode_SetSocketOnHold($hSocket, True)

;~ 		MsgBox(0, @ScriptName, "Expected : " & $nCurrentBufferIndex & " Got : " & $nPacketID) ; debug for the rare bug discovered in 0.1.5.10

		; request all missing packets.
		; ~ todo if we miss alot of packets then do something else.
		For $i = $nCurrentBufferIndex To $nPacketID
			_netcode_TCPSend($hSocket, 'netcode_internal', 'packet_getresend|' & $i)
		Next

		; all packets below the Execution Index can be ignored.
		If $nPacketID < $nCurrentIndex Then Return
	Else
		; if the current index > the size of the array then reset to the 0 index
		$nCurrentBufferIndex += 1
		If $nCurrentBufferIndex = 1000 Then $nCurrentBufferIndex = 0
	EndIf

	; write event and data to the buffer
	$arBuffer[$nPacketID][0] = $sEvent
	$arBuffer[$nPacketID][1] = $sData

	; storage the changed buffer
	__netcode_SocketSetExecutionBufferValues($hSocket, $nCurrentBufferIndex, $arBuffer)

	; check if the missing packets are now here. If then release the OnHold status
	; ~ needs heavy testing
	If _netcode_GetSocketOnHold($hSocket) Then

		For $i = $nCurrentIndex To $nCurrentBufferIndex - 1
			If $arBuffer[$i][0] = '' Then Return __Trace_FuncOut("__netcode_AddToExecutionBuffer")
		Next

		_netcode_SetSocketOnHold($hSocket, False)
	EndIf

	__Trace_FuncOut("__netcode_AddToExecutionBuffer")
EndFunc   ;==>__netcode_AddToExecutionBuffer

Func __netcode_EventStrippingFix()
	__Trace_FuncIn("__netcode_EventStrippingFix")
	__Trace_FuncOut("__netcode_EventStrippingFix")
	Return

	__netcode_EventConnect(0, 0, 0)
	__netcode_EventDisconnect(0, 0, 0)
	__netcode_EventFlood(0)
	__netcode_EventBanned(0)
	__netcode_EventMessage(0, 0)
	__netcode_EventSocketLinkRequest(0, 0)
	__netcode_EventSocketLinkSetup(0, 0)
	__netcode_EventSocketLinkConfirmation(0, 0)
	__netcode_EventInternal(0, 0)
EndFunc   ;==>__netcode_EventStrippingFix

;~ Func __netcode_EventConnect(Const $hSocket, $nStage)
Func __netcode_EventConnect(Const $hSocket, $nStage, $vData)
	__Trace_FuncIn("__netcode_EventConnect", $hSocket, $nStage)
	__Trace_FuncOut("__netcode_EventConnect")
	__netcode_Debug("New Socket @ " & $hSocket & " on Stage: " & $nStage)
EndFunc   ;==>__netcode_EventConnect

Func __netcode_EventDisconnect(Const $hSocket, $nDisconnectError = 0, $bDisconnectTriggered = False)
	__Trace_FuncIn("__netcode_EventDisconnect", $hSocket)
	__Trace_FuncOut("__netcode_EventDisconnect")
	__netcode_Debug("Socket @ " & $hSocket & " Disconnected Error: " & $nDisconnectError)
EndFunc   ;==>__netcode_EventDisconnect

Func __netcode_EventFlood(Const $hSocket)
	__Trace_FuncIn("__netcode_EventFlood", $hSocket)
	__Trace_FuncOut("__netcode_EventFlood")
	__netcode_Debug("Socket @ " & $hSocket & " Flooded the Recv Buffer")
EndFunc   ;==>__netcode_EventFlood

Func __netcode_EventBanned(Const $hSocket)
	__Trace_FuncIn("__netcode_EventBanned", $hSocket)
	__Trace_FuncOut("__netcode_EventBanned")
	__netcode_Debug("Socket @ " & $hSocket & " is Banned")
EndFunc   ;==>__netcode_EventBanned

Func __netcode_EventMessage(Const $hSocket, $sData)
	__Trace_FuncIn("__netcode_EventMessage", $hSocket)
	__Trace_FuncOut("__netcode_EventMessage")
	__netcode_Debug("Socket @ " & $hSocket & " send message len: " & StringLen($sData))
;~ 	__netcode_Debug("Socket @ " & $hSocket & " send message: " & $sData)
EndFunc   ;==>__netcode_EventMessage

; client receives id, connects and sends id back on the new socket
Func __netcode_EventSocketLinkRequest(Const $hSocket, $nLinkID)
	__Trace_FuncIn("__netcode_EventSocketLinkRequest")
	Local $arUserData = __netcode_SocketGetUsernameAndPassword($hSocket)
	Local $arData = __netcode_SocketGetIPAndPort($hSocket)

	Local $hNewSocket = _netcode_TCPConnect($arData[0], $arData[1], False, $arUserData[0], $arUserData[1])
	if Not $hNewSocket Then
		__Trace_Error(1, 0, "Could not Connect to Server for Link socket")
		Return __Trace_FuncOut("__netcode_EventSocketLinkRequest")
	EndIf

	; add to link list


	__netcode_SocketSetLink($hSocket, $hNewSocket, $nLinkID, False, False, False)
	_netcode_TCPSend($hNewSocket, 'netcode_socketlinksetup', $nLinkID)

	__netcode_SendPacketQuo()

	; temp
;~ 	_netcode_SocketSetManageMode($hNewSocket, "rawlinked")


	__Trace_FuncOut("__netcode_EventSocketLinkRequest")
EndFunc

; server receives id from the new socket and looks up which socket has it and then links them
; note - i have to improve that
Func __netcode_EventSocketLinkSetup(Const $hSocket, $nLinkID)
	__Trace_FuncIn("__netcode_EventSocketLinkSetup")
	Local $arClients = __netcode_ParentGetClients(__netcode_ClientGetParent($hSocket))

	Local $arData[0]
	Local $hNewSocket = -1
	Local $vAdditionalData
	Local $sCallback = ""
	For $i = 0 To UBound($arClients) -1
		$arData = __netcode_SocketGetLinkIDs($arClients[$i])
		if Not IsArray($arData) Then ContinueLoop

		For $iS = 0 To UBound($arData) - 1
			if $arData[$iS][0] = $nLinkID Then
				$hNewSocket = $arClients[$i]
				$sCallback = $arData[$iS][1]
				$vAdditionalData = $arData[$iS][2]
				ExitLoop 2
			EndIf
		Next
	Next

	if $hNewSocket = -1 Then
		__Trace_Error(1, 0, "Could not find LinkID")
;~ 		_netcode_TCPDisconnect($hSocket) ; dont use internally
		__netcode_TCPCloseSocket($hSocket)
		__netcode_RemoveSocket($hSocket)
		Return __Trace_FuncOut("__netcode_EventSocketLinkSetup")
	EndIf

	__netcode_SocketSetLink($hNewSocket, $hSocket, $nLinkID, $sCallback, $vAdditionalData)
	_netcode_TCPSend($hNewSocket, 'netcode_socketlinkconfirmation', $nLinkID)

	; temp
	_netcode_SocketSetManageMode($hSocket, "rawlinked")

	__Trace_FuncOut("__netcode_EventSocketLinkSetup")
EndFunc

Func __netcode_EventSocketLinkConfirmation(Const $hSocket, $nLinkID)
	__Trace_FuncIn("__netcode_EventSocketLinkConfirmation")
	Local $hNewSocket = __netcode_SocketGetLinkedSocket($hSocket, $nLinkID)
	_storageS_Overwrite($hNewSocket, '_netcode_IsLinkClient', $hSocket)

	; temp
	_netcode_SocketSetManageMode($hNewSocket, "rawlinked")
	__Trace_FuncOut("__netcode_EventSocketLinkConfirmation")
EndFunc

Func __netcode_EventInternal(Const $hSocket, $sData)
	__Trace_FuncIn("__netcode_EventInternal", $hSocket, "$sData")
	Local $arData = StringSplit($sData, '|', 1)
	Local $sPacket = ""

	Switch $arData[1]
		Case 'packet_confirmation'
			if $__net_bPacketConfirmation Then
				Local $arRet = StringSplit($arData[2], ',', 1)
				For $i = 1 To $arRet[0]
					__netcode_RemoveFromSafetyBuffer($hSocket, $arRet[$i])
				Next
			EndIf


		Case 'packet_getresend'

			; temporary patch to combat the discovered bug from v0.1.5.10
			if $__net_bTraceEnable And $__net_bTraceLogErrorEnable Then
				__Trace_Error(0, 0, "_netcode_Core Error : Forced Disconnect @ " & $hSocket & " duo to bug described in v0.1.5.10")
			Else
				ConsoleWrite("! _netcode_Core Error : Forced Disconnect @ " & $hSocket & " duo to bug described in v0.1.5.10" & @CRLF)
			EndIf

			__netcode_TCPCloseSocket($hSocket)
			__netcode_RemoveSocket($hSocket)

			Return



			$sPacket = __netcode_GetElementFromSafetyBuffer($hSocket, $arData[2])
			If $sPacket Then
				__netcode_AddPacketToQue($hSocket, BinaryToString($sPacket), $arData[2])
			EndIf


		Case 'restage'
			; todo


	EndSwitch

	__Trace_FuncOut("__netcode_EventInternal")
EndFunc   ;==>__netcode_EventInternal

Func __netcode_ExecuteEvent(Const $hSocket, $sEvent, $sData = '')
	__Trace_FuncIn("__netcode_ExecuteEvent", $hSocket, $sEvent, "$sData")

	; events are saved in Binary to support every possible symbol
	If Not IsBinary($sEvent) Then $sEvent = StringToBinary($sEvent)

	if $sEvent = "208519967649002627" Then
		__Trace_Error(5, 0, "Invalid Event got rejected")
		Return __Trace_FuncOut("__netcode_ExecuteEvent", False)
	EndIf

	; check if event is set. if not check if the event is a default event.
	Local $sCallback = _storageS_Read($hSocket, '_netcode_Event' & $sEvent)
;~ 	ConsoleWrite(@TAB & BinaryToString($sEvent) & @TAB & $sCallback & @CRLF)
	If $sCallback == False Then
		$sCallback = _storageS_Read('Internal', '_netcode_DefaultEvent' & $sEvent)
		If $sCallback == False Then
			__Trace_Error(1, 0, 'This Event is unknown: "' & BinaryToString($sEvent) & '"', "", $hSocket, $sEvent)
			Return SetError(1, 0, __Trace_FuncOut("__netcode_ExecuteEvent", False)) ; this event is neither set / preset nor a default event. the event is completly unknown
		EndIf

	EndIf

	; if its a non callback event then store the data to the Event
	if $sCallback = "" Then
		if _storageS_Read($hSocket, '_netcode_Event' & $sEvent & '_Data') <> "" Then
			__Trace_Error(6, 0, "Non Callback Event misused. Event data gets overwritten.")
		EndIf
		_storageS_Overwrite($hSocket, '_netcode_Event' & $sEvent & '_Data', __netcode_sParams_2_arParams($hSocket, $sData))
		Return __Trace_FuncOut("__netcode_ExecuteEvent")
	EndIf


	; currently not working duo to the $sCallback vartype is required to be a Expression not a String
;~ 	if Not IsFunc($sCallback) Then
;~ 		__Trace_Error(2, 0, 'Event Callback: "' & $sCallback & '" func for event "' & BinaryToString($sEvent) & '" doesnt exists')
;~ 	EndIf

;~ 	ConsoleWrite(@TAB & @TAB & BinaryToString($sEvent) & @CRLF)

	; convert params to array, and also unmerge them if _netcode_sParams() is used, for Call()
	Local $arParams = __netcode_sParams_2_arParams($hSocket, $sData)

	__Trace_FuncIn($sCallback)
	Call($sCallback, $arParams)
	If @error Then ; needs further testing
		__Trace_Error(3, 0, 'Event Callback func got called with the wrong amount of params: ' & UBound($arParams) - 1)

		; temporary
		Switch $sEvent

			Case "connection"
				__Trace_Error(4, 0, "Calling Callback Func with 2 params instead")
				ReDim $arParams[3]
				Call($sCallback, $arParams)
				if @error Then __Trace_Error(5, 0, 'Event Callback func got called with the wrong amount of params: ' & UBound($arParams) - 1)

			Case "disconnected"
				__Trace_Error(4, 0, "Calling Callback Func with 1 param instead")
				Call($sCallback, $arParams[1])
				if @error Then __Trace_Error(5, 0, 'Event Callback func got called with the wrong amount of params: 1')

		EndSwitch
	EndIf

	__Trace_FuncOut($sCallback)

	__Trace_FuncOut("__netcode_ExecuteEvent")
EndFunc   ;==>__netcode_ExecuteEvent

; creates an array for Call() with the params and also unserializes data serialized with _netcode_sParams()
Func __netcode_sParams_2_arParams($hSocket, $r_params)
	__Trace_FuncIn("__netcode_sParams_2_arParams", $hSocket, "$r_params")
	Local $nIndicatorLen = StringLen($__net_sParamIndicatorString)
	Local $aTmp[2]
	Local $arParams[0]

	; these elements are everywhere the same
	$aTmp[0] = 'CallArgArray'
	$aTmp[1] = $hSocket

	If $r_params == '' Then ; if no params where set
		Return __Trace_FuncOut("__netcode_sParams_2_arParams", $aTmp)

	ElseIf StringLeft($r_params, $nIndicatorLen) <> $__net_sParamIndicatorString Then ; if params set but not merged with _netcode_sParams
		ReDim $aTmp[3]

		$aTmp[2] = __netcode_CheckParamAndUnserialize($r_params)
		Return __Trace_FuncOut("__netcode_sParams_2_arParams", $aTmp)

	Else ; if merged with _netcode_sParams
		$arParams = StringSplit(StringTrimLeft($r_params, $nIndicatorLen), $__net_sParamSplitSeperator, 1)
		ReDim $aTmp[2 + $arParams[0]]

		For $i = 1 To $arParams[0]
;~ 			If $__net_bParamSplitBinary Then $arParams[$i] = $arParams[$i] ; param binarization will be done by _netcode internally once packet reassembling in a packet corruption case is implemented.
			$aTmp[1 + $i] = __netcode_CheckParamAndUnserialize($arParams[$i])
		Next

		Return __Trace_FuncOut("__netcode_sParams_2_arParams", $aTmp)
	EndIf

	__Trace_FuncOut("__netcode_sParams_2_arParams")
EndFunc   ;==>__netcode_r_Params2ar_Params

; we only serialize arrays. Do not parse 2D array with the size [n][1] it will think its a 1D array (try redimming with Execute()).
; todo - if the array count is to big, show a warning. Also do more error checking to protect the code from DDOS.
; easiest would be to limit the array size to a reasonable size.
; add vargettype function to make sure each element has the right var type once unserialized
Func __netcode_CheckParamAndSerialize($sParam, $bNoIndication = False)
	__Trace_FuncIn("__netcode_CheckParamAndSerialize", "$sParam", $bNoIndication)
	Switch VarGetType($sParam)
		Case 'Array'
			Return __Trace_FuncOut("__netcode_CheckParamAndSerialize", __netcode_SerializeArray($sParam))

		Case Else
			Return __Trace_FuncOut("__netcode_CheckParamAndSerialize", $sParam)

	EndSwitch

	__Trace_FuncOut("__netcode_CheckParamAndSerialize")
EndFunc   ;==>__netcode_CheckParamAndSerialize

; marked for recoding
; add support for 3D arrays and add data var type storing to recreate the arrays with the exact same data var types in the unserializer.
Func __netcode_SerializeArray($sParam)
	__Trace_FuncIn("__netcode_SerializeArray", "$sParam")
	Local $nY = UBound($sParam)
	Local $nX = UBound($sParam, 2)
	Local $sReturnString = $__net_sSerializationIndicator & $__net_sSerializeArrayIndicator

	If $nX = 0 Then

		For $iY = 0 To $nY - 1
			$sReturnString &= $sParam[$iY] & $__net_sSerializeArrayYSeperator
		Next

	Else

		For $iY = 0 To $nY - 1
			For $iX = 0 To $nX - 1
				$sReturnString &= $sParam[$iY][$iX] & $__net_sSerializeArrayXSeperator
			Next

			$sReturnString &= $__net_sSerializeArrayYSeperator
		Next

	EndIf

	Return __Trace_FuncOut("__netcode_SerializeArray", $sReturnString)
EndFunc   ;==>__netcode_SerializeArray

Func __netcode_CheckParamAndUnserialize($sParam)
	__Trace_FuncIn("__netcode_CheckParamAndUnserialize", "$sParam")
	If StringLeft($sParam, 10) <> $__net_sSerializationIndicator Then Return __Trace_FuncOut("__netcode_CheckParamAndUnserialize", $sParam)
	$sParam = StringTrimLeft($sParam, 10)

	Switch StringLeft($sParam, 10)
		Case $__net_sSerializeArrayIndicator
			Return __Trace_FuncOut("__netcode_CheckParamAndUnserialize", __netcode_UnserializeArray(StringTrimLeft($sParam, 10)))

		Case Else
			Return __Trace_FuncOut("__netcode_CheckParamAndUnserialize", $sParam)

	EndSwitch

	__Trace_FuncOut("__netcode_CheckParamAndUnserialize")
EndFunc   ;==>__netcode_CheckParamAndUnserialize

Func __netcode_UnserializeArray($sParam)
	__Trace_FuncIn("__netcode_UnserializeArray", "$sParam")

	Local $arYParam = StringSplit($sParam, $__net_sSerializeArrayYSeperator, 1)
	Local $arXParam = StringSplit($arYParam[1], $__net_sSerializeArrayXSeperator, 1)
	Local $nY = $arYParam[0]
	Local $nX = $arXParam[0]

	If $nX < 2 Then

		Local $arParam[$nY - 1]
		For $i = 0 To $nY - 2
			$arParam[$i] = $arYParam[$i + 1]
		Next

	Else

		Local $arParam[$nY - 1][$nX - 1]
		For $iY = 0 To $nY - 2
			$arXParam = StringSplit($arYParam[$iY + 1], $__net_sSerializeArrayXSeperator, 1)

			For $iX = 0 To $nX - 2
				$arParam[$iY][$iX] = $arXParam[$iX + 1]
			Next
		Next

	EndIf

	Return __Trace_FuncOut("__netcode_UnserializeArray", $arParam)
EndFunc   ;==>__netcode_UnserializeArray

; note - do not Return a binarized packet, since autoit seems to be much faster working with Strings.
; i actually got 3 mb/s more by changing from Binary to String processing.
; this func takes about 15ms on a 1.25mb packet. I think it is the content assembly or the
; binary/string conversion of the content when encryption is toggled on, because otherwise this function is done in 2 ms with the same data size.
; data encryption just takes a small amount of ms, so it has to be something else. As of now i can only think of the BinaryToString() conversion once the Binary exits the
; aes encryption func.
Func __netcode_CreatePackage(Const $hSocket, $sEvent, $sData)
	__Trace_FuncIn("__netcode_CreatePackage", $hSocket, $sEvent, "$sData")

	; Read the Seeded Packet strings
	Local $arPacketStrings = __netcode_SocketGetPacketStrings($hSocket)
	Local $sPacketBegin = $arPacketStrings[0]
	Local $sPacketInternalSplit = $arPacketStrings[1]
	Local $sPacketEnd = $arPacketStrings[2]

	; New packet ID
	Local $sPacketID = _storageS_Read($hSocket, '_netcode_SafetyBufferIndex')

	; we no longer want to convert data back to string if the user chooses to give it as binary
;~ 	If IsBinary($sData) Then $sData = BinaryToString($sData)

	; hash data
	; ~ todo - not implemented yet - have to find a very quick but safe hashing algo
	Local $sValidationHash = ''

	; create packet content
	Local $sPackage = $sPacketID & $sPacketInternalSplit & $sValidationHash & $sPacketInternalSplit & $sEvent & $sPacketInternalSplit & $sData

	; compress packet content
	; ~ todo

	; encrypt packet content
	If __netcode_SocketGetPacketEncryption($hSocket) Then
		Local $hPassword = __netcode_SocketGetPacketEncryptionPassword($hSocket)
;~ 		$sPackage = BinaryToString(__netcode_AESEncrypt(StringToBinary($sPackage), $hPassword))
		$sPackage = BinaryToString(__netcode_AESEncrypt($sPackage, $hPassword))
	EndIf

	; wrap the packet content
	$sPackage = $sPacketBegin & $sPackage & $sPacketEnd
	$nLen = StringLen($sPackage)

	; check if the packet size would exceed the left buffer space
	If Number(_storageS_Read($hSocket, '_netcode_SafetyBufferSize')) + $nLen > $__net_nMaxRecvBufferSize Then

;~ 		__Trace_Error(1, 0, "Packet is currently to large to be send") ; usuall warning, doesnt need to be shown

		__Trace_FuncOut("__netcode_CreatePackage")
		Return SetError(1, $sPacketID, $sPackage)

	EndIf

	__Trace_FuncOut("__netcode_CreatePackage")
	Return SetError(0, $sPacketID, $sPackage)

EndFunc

; [0] = packet
; [1] = len
Func __netcode_AddToSafetyBuffer(Const $hSocket, $sPacket, $nLen)
	__Trace_FuncIn("__netcode_AddToSafetyBuffer", $hSocket, "$sPacket", $nLen)
	; read buffer values
	Local $arBuffer = __netcode_SocketGetSafetyBufferValues($hSocket)
	Local $nCurrentIndex = @error
	Local $nBufferSize = @extended
	If Not IsArray($arBuffer) Then Return __Trace_FuncOut("__netcode_AddToSafetyBuffer")

	; add packet to buffer
	$arBuffer[$nCurrentIndex][0] = $sPacket
	$arBuffer[$nCurrentIndex][1] = $nLen

	; calculate new size and index
	$nBufferSize += $nLen
	$nCurrentIndex += 1
	If $nCurrentIndex = 1000 Then $nCurrentIndex = 0

	; save new buffer values
	__netcode_SocketSetSafetyBufferValues($hSocket, $nCurrentIndex, $nBufferSize, $arBuffer)
	__Trace_FuncOut("__netcode_AddToSafetyBuffer")
EndFunc   ;==>__netcode_AddToSafetyBuffer

Func __netcode_RemoveFromSafetyBuffer(Const $hSocket, $sID)
	__Trace_FuncIn("__netcode_RemoveFromSafetyBuffer", $hSocket, $sID)
	$sID = Number($sID)
	If $sID >= 1000 Then Return __Trace_FuncOut("__netcode_RemoveFromSafetyBuffer") ; what?

	; read buffer values
	Local $arBuffer = __netcode_SocketGetSafetyBufferValues($hSocket)
	Local $nCurrentIndex = @error
	Local $nBufferSize = @extended

	; recal new size and empty the index
	$nBufferSize -= $arBuffer[$sID][1]
	$arBuffer[$sID][0] = ''
	$arBuffer[$sID][1] = ''

	; save new buffer values
	__netcode_SocketSetSafetyBufferValues($hSocket, $nCurrentIndex, $nBufferSize, $arBuffer)
	__Trace_FuncOut("__netcode_RemoveFromSafetyBuffer")
EndFunc   ;==>__netcode_RemoveFromSafetyBuffer

Func __netcode_GetElementFromSafetyBuffer(Const $hSocket, $sID)
	__Trace_FuncIn("__netcode_GetElementFromSafetyBuffer", $hSocket, $sID)
	$sID = Number($sID)
	If $sID >= 1000 Then Return __Trace_FuncOut("__netcode_GetElementFromSafetyBuffer", False) ; id can never be >= 1000

	Local $arBuffer = __netcode_SocketGetSafetyBufferValues($hSocket)
	Local $sPacket = $arBuffer[$sID][0]
	If $sPacket = '' Then Return __Trace_FuncOut("__netcode_GetElementFromSafetyBuffer", False) ; packet not stored

	Return __Trace_FuncOut("__netcode_GetElementFromSafetyBuffer", $sPacket)
EndFunc   ;==>__netcode_GetElementFromSafetyBuffer

Func __netcode_RecvPackages(Const $hSocket)
	__Trace_FuncIn("__netcode_RecvPackages", $hSocket)
	Local $sPackages = ''
	Local $sTCPRecv = ''
	Local $hTimer = TimerInit()
	Local $bDisconnect = False
	Local $nError = 0
	Local $nBytes = 0

	Do
;~ 		TCPRecv ; reference
;~ 		$sTCPRecv = __netcode_TCPRecv_Backup($hSocket, 65536, 1)
		$sTCPRecv = __netcode_TCPRecv($hSocket)
		$nError = @error
		$nBytes += @extended
		Switch $nError
			Case 10050 To 10054
				$bDisconnect = True


			Case 1
				$bDisconnect = True
				$nError = 0

		EndSwitch

		If $bDisconnect Then
;~ 			If $sPackages <> '' Then ExitLoop ; in the case the client send something and then closed his socket instantly. We still want to process the packet first. So we call disconnect next loop.
;~ 			If $sPackages <> '' Then Return $sPackages ; in the case the client send something and then closed his socket instantly. We still want to process the packet first. So we call disconnect next loop.

			__Trace_Error($nError, 1, "Disconnected")
			Return SetError($nError, 1, __Trace_FuncOut("__netcode_RecvPackages", False))
		EndIf

;~ 		__netcode_SocketSetRecvBytesPerSecond($hSocket, $nBytes)

		$sPackages &= BinaryToString($sTCPRecv) ; old way
;~ 		$sPackages &= BinaryToString($sTCPRecv, 4) ; Reverted - Fix from 1.5.10
;~ 		$sPackages &= StringMid($sTCPRecv, 3) ; inefficient

		; todo ~ check size and if it exceeds the max Recv Buffer Size

		If TimerDiff($hTimer) > $__net_nTCPRecvBufferEmptyTimeout Then ExitLoop

	Until $sTCPRecv = ''

;~ 	$sPackages = BinaryToString('0x' & $sPackages, 4) ; part of StringMid

	__netcode_SocketSetRecvBytesPerSecond($hSocket, $nBytes)

	Return __Trace_FuncOut("__netcode_RecvPackages", $sPackages)
EndFunc   ;==>__netcode_RecvPackages

; Seterror(x , y , z)
; x = @error = Index
; y = @extended = Size
; z = Return = Array
Func __netcode_SocketGetSafetyBufferValues(Const $hSocket)
	__Trace_FuncIn("__netcode_SocketGetSafetyBufferValues", $hSocket)
	Local $nCurrentIndex = _storageS_Read($hSocket, '_netcode_SafetyBufferIndex')
	Local $nCurrentSize = _storageS_Read($hSocket, '_netcode_SafetyBufferSize')

	__Trace_FuncOut("__netcode_SocketGetSafetyBufferValues")
	Return SetError($nCurrentIndex, $nCurrentSize, _storageS_Read($hSocket, '_netcode_SafetyBuffer'))
EndFunc   ;==>__netcode_SocketGetSafetyBufferValues

Func __netcode_SocketSetSafetyBufferValues(Const $hSocket, $nIndex, $nSize, $arBuffer)
	__Trace_FuncIn("__netcode_SocketSetSafetyBufferValues", $hSocket, $nIndex, $nSize, "$arBuffer")
	_storageS_Overwrite($hSocket, '_netcode_SafetyBufferIndex', $nIndex)
	_storageS_Overwrite($hSocket, '_netcode_SafetyBufferSize', $nSize)
	_storageS_Overwrite($hSocket, '_netcode_SafetyBuffer', $arBuffer)
	__Trace_FuncOut("__netcode_SocketSetSafetyBufferValues")
EndFunc   ;==>__netcode_SocketSetSafetyBufferValues

; Seterror (x, 0, y)
; x = @error = Index
; y = Return = Array
Func __netcode_SocketGetExecutionBufferValues(Const $hSocket)
	__Trace_FuncIn("__netcode_SocketGetExecutionBufferValues", $hSocket)
	Local $nCurrentIndex = _storageS_Read($hSocket, '_netcode_ExecutionBufferIndex')

	__Trace_FuncOut("__netcode_SocketGetExecutionBufferValues")
	Return SetError($nCurrentIndex, 0, _storageS_Read($hSocket, '_netcode_ExecutionBuffer'))
EndFunc   ;==>__netcode_SocketGetExecutionBufferValues

Func __netcode_SocketSetExecutionBufferValues(Const $hSocket, $nIndex, $arBuffer)
	__Trace_FuncIn("__netcode_SocketSetExecutionBufferValues", $hSocket, $nIndex, "$arBuffer")
	_storageS_Overwrite($hSocket, '_netcode_ExecutionBufferIndex', $nIndex)
	_storageS_Overwrite($hSocket, '_netcode_ExecutionBuffer', $arBuffer)
	__Trace_FuncOut("__netcode_SocketSetExecutionBufferValues")
EndFunc   ;==>__netcode_SocketSetExecutionBufferValues

Func __netcode_SocketGetEvents(Const $hSocket)
	__Trace_FuncIn("__netcode_SocketGetEvents", $hSocket)
	__Trace_FuncOut("__netcode_SocketGetEvents")
	Return _storageS_Read($hSocket, '_netcode_EventStorage')
EndFunc   ;==>__netcode_SocketGetEvents

Func __netcode_SocketSetEvents(Const $hSocket, $arEvents)
	__Trace_FuncIn("__netcode_SocketSetEvents", $hSocket, "$arEvents")
	_storageS_Overwrite($hSocket, '_netcode_EventStorage', $arEvents)
	__Trace_FuncOut("__netcode_SocketSetEvents")
EndFunc   ;==>__netcode_SocketSetEvents

; Seterror (x, 0, y)
; x = @error = True / False - if is whitelist or not
; y = Return = Array
Func __netcode_SocketGetIPList(Const $hSocket)
	__Trace_FuncIn("__netcode_SocketGetIPList", $hSocket)
;~ 	if __netcode_CheckSocket($hSocket) <> 1 Then Return SetError(1, 0, False) ; this isnt a parent
	Local $bIsWhitelist = _storageS_Read($hSocket, '_netcode_IPListIsWhitelist')

	__Trace_FuncOut("__netcode_SocketGetIPList")
	Return SetError($bIsWhitelist, 0, _storageS_Read($hSocket, '_netcode_IPList'))
EndFunc   ;==>__netcode_SocketGetIPList

Func __netcode_SocketSetIPList(Const $hSocket, $arIPList, $bIsWhitelist)
	__Trace_FuncIn("__netcode_SocketSetIPList", $hSocket, "$arIPList", $bIsWhitelist)
	_storageS_Overwrite($hSocket, '_netcode_IPList', $arIPList)
	_storageS_Overwrite($hSocket, '_netcode_IPListIsWhitelist', $bIsWhitelist)
	__Trace_FuncOut("__netcode_SocketSetIPList")
EndFunc   ;==>__netcode_SocketSetIPList

Func __netcode_SocketSetMyRSA(Const $hSocket, $sPrivate, $sPublic)
	__Trace_FuncIn("__netcode_SocketSetMyRSA", $hSocket, "$sPrivate", "$sPublic")
	_storageS_Overwrite($hSocket, '_netcode_MYRSAPrivateKey', $sPrivate)
	_storageS_Overwrite($hSocket, '_netcode_MYRSAPubliceKey', $sPublic)
	__Trace_FuncOut("__netcode_SocketSetMyRSA")
EndFunc   ;==>__netcode_SocketSetMyRSA

Func __netcode_SocketGetMyRSA(Const $hSocket, $bPrivate = True)
	__Trace_FuncIn("__netcode_SocketGetMyRSA", $hSocket, $bPrivate)
	__Trace_FuncOut("__netcode_SocketGetMyRSA")
	If $bPrivate Then
		Return _storageS_Read($hSocket, '_netcode_MYRSAPrivateKey')
	Else
		Return _storageS_Read($hSocket, '_netcode_MYRSAPubliceKey')
	EndIf
EndFunc   ;==>__netcode_SocketGetMyRSA

Func __netcode_SocketSetOtherRSA(Const $hSocket, $sPublic)
	__Trace_FuncIn("__netcode_SocketSetOtherRSA", $hSocket, "$sPublic")
	_storageS_Overwrite($hSocket, '_netcode_OtherRSAPublicKey', $sPublic)
	__Trace_FuncOut("__netcode_SocketSetOtherRSA")
EndFunc   ;==>__netcode_SocketSetOtherRSA

Func __netcode_SocketGetOtherRSA(Const $hSocket)
	__Trace_FuncIn("__netcode_SocketGetOtherRSA", $hSocket)
	__Trace_FuncOut("__netcode_SocketGetOtherRSA")
	Return _storageS_Read($hSocket, '_netcode_OtherRSAPublicKey')
EndFunc   ;==>__netcode_SocketGetOtherRSA

; give client socket
Func __netcode_SocketSetPacketEncryption(Const $hSocket, $bSet)
	__Trace_FuncIn("__netcode_SocketSetPacketEncryption", $hSocket, $bSet)
	_storageS_Overwrite($hSocket, '_netcode_SocketUsesEncryption', $bSet)
	__Trace_FuncOut("__netcode_SocketSetPacketEncryption")
EndFunc   ;==>__netcode_SocketSetPacketEncryption

Func __netcode_SocketGetPacketEncryption(Const $hSocket)
	__Trace_FuncIn("__netcode_SocketGetPacketEncryption", $hSocket)
	__Trace_FuncOut("__netcode_SocketGetPacketEncryption")
	Return _storageS_Read($hSocket, '_netcode_SocketUsesEncryption')
EndFunc   ;==>__netcode_SocketGetPacketEncryption

; give client socket
Func __netcode_SocketSetPacketEncryptionPassword(Const $hSocket, $sPW)
	__Trace_FuncIn("__netcode_SocketSetPacketEncryptionPassword", $hSocket, "$sPW")
	_storageS_Overwrite($hSocket, '_netcode_SocketEncryptionPassword', $sPW)
	__Trace_FuncOut("__netcode_SocketSetPacketEncryptionPassword")
EndFunc   ;==>__netcode_SocketSetPacketEncryptionPassword

Func __netcode_SocketGetPacketEncryptionPassword(Const $hSocket)
	__Trace_FuncIn("__netcode_SocketGetPacketEncryptionPassword", $hSocket)
	__Trace_FuncOut("__netcode_SocketGetPacketEncryptionPassword")
	Return _storageS_Read($hSocket, '_netcode_SocketEncryptionPassword')
EndFunc   ;==>__netcode_SocketGetPacketEncryptionPassword

Func __netcode_SocketSetIPAndPort(Const $hSocket, $sIP, $nPort)
	__Trace_FuncIn("__netcode_SocketSetIPAndPort")
	Local $arData[2] = [$sIP,$nPort]
	_storageS_Overwrite($hSocket, '_netcode_IPAndPort', $arData)
	__Trace_FuncOut("__netcode_SocketSetIPAndPort")
EndFunc

Func __netcode_SocketGetIPAndPort(Const $hSocket)
	__Trace_FuncIn("__netcode_SocketGetIPAndPort")
	__Trace_FuncOut("__netcode_SocketGetIPAndPort")
	Return _storageS_Read($hSocket, '_netcode_IPAndPort')
EndFunc

Func __netcode_SocketSetUsernameAndPassword(Const $hSocket, $sUsername, $sPassword)
	__Trace_FuncIn("__netcode_SocketSetUsernameAndPassword")
	Local $arData[2] = [$sUsername,$sPassword]
	_storageS_Overwrite($hSocket, '_netcode_UsernameAndPassword', $arData)
	__Trace_FuncOut("__netcode_SocketSetUsernameAndPassword")
EndFunc

Func __netcode_SocketGetUsernameAndPassword(Const $hSocket)
	__Trace_FuncIn("__netcode_SocketGetUsernameAndPassword")
	__Trace_FuncOut("__netcode_SocketGetUsernameAndPassword")
	Return _storageS_Read($hSocket, '_netcode_UsernameAndPassword')
EndFunc

Func __netcode_SocketAddLinkID(Const $hSocket, $nLinkID, $sCallback, $vAdditionalData)
	__Trace_FuncIn("__netcode_SocketAddLinkID")
	Local $arData = __netcode_SocketGetLinkIDs($hSocket)
	if Not IsArray($arData) Then Local $arData[0][0]

;~ 	if UBound($arData) > 0 Then
;~ 		__Trace_Error(10, 0, "Currently only 1 Link socket is supported")
;~ 		Return __Trace_FuncOut("__netcode_SocketAddLinkID", False)
;~ 	EndIf

	Local $nArSize = UBound($arData)

	For $i = 0 To $nArSize - 1
		if $arData[$i][0] = $nLinkID Then
			; error link id already exists
			__Trace_Error(1, 0, "LinkID already exists", False)
			Return __Trace_FuncOut("__netcode_SocketAddLinkID")
		EndIf
	Next

	ReDim $arData[$nArSize + 1][3]
	$arData[$nArSize][0] = $nLinkID
	$arData[$nArSize][1] = $sCallback
	$arData[$nArSize][2] = $vAdditionalData
	_storageS_Overwrite($hSocket, '_netcode_LinkID', $arData)

	Return __Trace_FuncOut("__netcode_SocketAddLinkID", True)
EndFunc

Func __netcode_SocketGetLinkIDs(Const $hSocket)
	__Trace_FuncIn("__netcode_SocketGetLinkIDs")
	__Trace_FuncOut("__netcode_SocketGetLinkIDs")
	Return _storageS_Read($hSocket, '_netcode_LinkID')
EndFunc

Func __netcode_SocketRemoveLinkID(Const $hSocket, $nLinkID)
	__Trace_FuncIn("__netcode_SocketRemoveLinkID")
	Local $arData = __netcode_SocketGetLinkIDs($hSocket)
	if Not IsArray($arData) Then
		__Trace_Error(1, 0, "This LinkID does not exists")
		Return __Trace_FuncOut("__netcode_SocketRemoveLinkID")
	EndIf

	Local $nArSize = UBound($arData)
	if $nArSize = 0 Then
		__Trace_Error(2, 0, "This LinkID does not exists")
		Return __Trace_FuncOut("__netcode_SocketRemoveLinkID")
	EndIf

	Local $nIndex = -1
	For $i = 0 To $nArSize - 1
		if $arData[$i][0] = $nLinkID Then
			$nIndex = $i
			ExitLoop
		EndIf
	Next

	if $nIndex = -1 Then
		__Trace_Error(3, 0, "This LinkID does not exists")
		Return __Trace_FuncOut("__netcode_SocketRemoveLinkID")
	EndIf

	$arData[$nIndex][0] = $arData[$nArSize - 1][0]
	$arData[$nIndex][1] = $arData[$nArSize - 1][1]
	$arData[$nIndex][2] = $arData[$nArSize - 1][2]
	ReDim $arData[$nArSize - 1][3]

	__Trace_FuncOut("__netcode_SocketRemoveLinkID")
EndFunc

Func __netcode_SocketSetLink(Const $hSocket, $hNewSocket, $nLinkID, $sCallback, $vAdditionalData, $bSetIsLinkClient = True)
	__Trace_FuncIn("__netcode_SocketSetLink")
	_storageS_Overwrite($hSocket, '_netcode_Link' & $nLinkID, $hNewSocket)
	_storageS_Overwrite($hSocket, '_netcode_LinkAdditionalData' & $nLinkID, $vAdditionalData)
;~ 	_storageS_Overwrite($hSocket, '_netcode_LinkCallback' & $nLinkID, $sCallback)
;~ 	_storageS_Overwrite($hNewSocket, '_netcode_Link' & $nLinkID, $hSocket)
	_storageS_Overwrite($hNewSocket, '_netcode_LinkAdditionalData', $vAdditionalData)
	_storageS_Overwrite($hNewSocket, '_netcode_LinkCallback', $sCallback)
	if $bSetIsLinkClient Then _storageS_Overwrite($hNewSocket, '_netcode_IsLinkClient', $hSocket)
	__Trace_FuncOut("__netcode_SocketSetLink")
EndFunc

Func __netcode_SocketGetLinkedSocket(Const $hSocket, $nLinkID = False)
	__Trace_FuncIn("__netcode_SocketGetLinkedSocket")
	__Trace_FuncOut("__netcode_SocketGetLinkedSocket")
	if _storageS_Read($hSocket, '_netcode_IsLinkClient') Then
		Return _storageS_Read($hSocket, '_netcode_IsLinkClient')
	Else
		Return _storageS_Read($hSocket, '_netcode_Link' & $nLinkID)
	EndIf
EndFunc

Func __netcode_SocketGetLinkedCallback(Const $hSocket, $nLinkID = False)
	__Trace_FuncIn("__netcode_SocketGetLinkedCallback")
	__Trace_FuncOut("__netcode_SocketGetLinkedCallback")
	if _storageS_Read($hSocket, '_netcode_IsLinkClient') Then
		Return _storageS_Read($hSocket, '_netcode_LinkCallback')
	Else
		Return _storageS_Read($hSocket, '_netcode_LinkCallback' & $nLinkID)
	EndIf
EndFunc

; currently only saves the username instead of the UID
Func __netcode_SocketSetUser(Const $hSocket, $nUID)
	__Trace_FuncIn("__netcode_SocketSetUser", $hSocket, $nUID)
	_storageS_Overwrite($hSocket, '_netcode_SocketUserID', $nUID)
	__Trace_FuncOut("__netcode_SocketSetUser")
EndFunc   ;==>__netcode_SocketSetUser

Func __netcode_SocketGetUser(Const $hSocket)
	__Trace_FuncIn("__netcode_SocketGetUser", $hSocket)
	__Trace_FuncOut("__netcode_SocketGetUser")
	Return _storageS_Read($hSocket, '_netcode_SocketUserID')
EndFunc   ;==>__netcode_SocketGetUser

Func __netcode_SetUserDB($hSocketOrsfDB, $arUserDB)
	__Trace_FuncIn("__netcode_SetUserDB", $hSocketOrsfDB, "$arUserDB")
	Local $hOpen

	If StringInStr($hSocketOrsfDB, '\') Then ; if filepath

		If UBound($arUserDB) = 0 Then
			$hOpen = FileOpen($hSocketOrsfDB, 18)
			FileClose($hOpen)

			Return __Trace_FuncOut("__netcode_SetUserDB")
		EndIf

		$hOpen = FileOpen($hSocketOrsfDB, 18)
		If $hOpen = -1 Then
			__Trace_Error(1, 0, "Couldnt open DB")
			Return SetError(1, 0, __Trace_FuncOut("__netcode_SetUserDB", False))
		EndIf

		Local $sData = ""
		For $i = 0 To UBound($arUserDB) - 1
			For $iS = 0 To 18
				$sData &= $arUserDB[$i][$iS] & '|'
			Next

			$sData = StringTrimRight($sData, 1) & @CRLF
		Next

		FileWrite($hOpen, $sData)
		FileClose($hOpen)

	Else ; if socket

		Local $sfDbPath = _storageS_Read($hSocketOrsfDB, '_netcode_UserDBPath')

		__netcode_SetUserDB($sfDbPath, $arUserDB)
		_storageS_Overwrite($hSocketOrsfDB, '_netcode_UserDB', $arUserDB)

	EndIf

	__Trace_FuncOut("__netcode_SetUserDB")
EndFunc   ;==>__netcode_SetUserDB

Func __netcode_GetUserDB($hSocketOrsfDB)
	__Trace_FuncIn("__netcode_GetUserDB", $hSocketOrsfDB)

	Local $arUserDB[0][0]

	If StringInStr($hSocketOrsfDB, '\') Then ; if filepath

		Local $arUserData[0]
		Local $hOpen = FileOpen($hSocketOrsfDB)
		Local $arUserDB1D = StringSplit(FileRead($hOpen), @CRLF, 1)
		FileClose($hOpen)

		If $arUserDB1D[1] = "" Then
			ReDim $arUserDB[0][19]
			Return __Trace_FuncOut("__netcode_GetUserDB", $arUserDB)
		EndIf

		Local $arUserDB[$arUserDB1D[0] - 1][19]

		For $i = 1 To $arUserDB1D[0]
			If $arUserDB1D[$i] = "" Then ContinueLoop
			$arUserData = StringSplit($arUserDB1D[$i], '|', 1)

			For $iS = 0 To 18
				$arUserDB[$i - 1][$iS] = $arUserData[$iS + 1]
			Next
		Next

		Return __Trace_FuncOut("__netcode_GetUserDB", $arUserDB)

	Else ; if socket

		$arUserDB = _netcode_SocketGetUserManagement($hSocketOrsfDB)
		Return __Trace_FuncOut("__netcode_GetUserDB", __netcode_GetUserDB($arUserDB[0]))

	EndIf
EndFunc   ;==>__netcode_GetUserDB

Func __netcode_FindUser(ByRef $arUserDB, $sUsername)
	__Trace_FuncIn("__netcode_FindUser", $arUserDB, $sUsername)

	; check binarized users
	For $i = 0 To UBound($arUserDB) - 1
		If $arUserDB[$i][0] = $sUsername Then Return __Trace_FuncOut("__netcode_FindUser", $i)
	Next

	; check unbinarized users
	For $i = 0 To UBound($arUserDB) - 1
		If BinaryToString($arUserDB[$i][0]) = $sUsername Then Return __Trace_FuncOut("__netcode_FindUser", $i)
	Next

	Return __Trace_FuncOut("__netcode_FindUser", -1)
EndFunc   ;==>__netcode_FindUser

Func __netcode_UserDBChangeValue($hSocketOrsfDB, $sUsername, $nIndexOfData, $sData)
	__Trace_FuncIn("__netcode_UserDBChangeValue", $hSocketOrsfDB, $sUsername, $nIndexOfData, "$sData")
	Local $arUserDB = __netcode_GetUserDB($hSocketOrsfDB)
;~ 	Local $nArSize = UBound($arUserDB)
	Local $nIndex = __netcode_FindUser($arUserDB, $sUsername)

	$arUserDB[$nIndex][$nIndexOfData] = $sData

	__netcode_SetUserDB($hSocketOrsfDB, $arUserDB)
	__Trace_FuncOut("__netcode_UserDBChangeValue")
EndFunc   ;==>__netcode_UserDBChangeValue

Func __netcode_AddSocket(Const $hSocket, $hListenerSocket = False, $nIfListenerMaxConnections = 0, $sIP = False, $nPort = False, $sUsername = False, $sPassword = False)
	__Trace_FuncIn("__netcode_AddSocket", $hSocket, $hListenerSocket, $nIfListenerMaxConnections)

	Local $nArSize = 0

	If $hListenerSocket Then ; if we want to add a client socket to this listener socket

		; check if parent socket exists or if its '000'. A 000 parent socket indicates that $hSocket is from TCPConnect
		If Not _storageS_Read($hListenerSocket, '_netcode_SocketIsListener') Then
			If $hListenerSocket = '000' Then
				__netcode_AddSocket('000')
			Else
				__Trace_Error(1, 0, "Unknown parent socket", "", $hListenerSocket)
				Return SetError(1, 0, __Trace_FuncOut("__netcode_AddSocket", False))
			EndIf
		EndIf

		; check if the parent accepts more Connections, if then add one, if not return error
		Local $nCurrentConnections = _storageS_Read($hListenerSocket, '_netcode_ListenerCurrentConnections') + 1
		If $nCurrentConnections > _storageS_Read($hListenerSocket, '_netcode_ListenerMaxConnections') And $hListenerSocket <> '000' Then
			__Trace_Error(2, 0, "Rejecting socket. Parent has maximum Connections reached")
			Return SetError(2, 0, __Trace_FuncOut("__netcode_AddSocket", False))
		EndIf
		_storageS_Overwrite($hListenerSocket, '_netcode_ListenerCurrentConnections', $nCurrentConnections)

		; get the current client array
		Local $arClients = _storageS_Read($hListenerSocket, '_netcode_ListenerClients')
		$nArSize = UBound($arClients)

		; check if new socket is already part of this array
		For $i = 0 To $nArSize - 1
			If $arClients[$i] = $hSocket Then
				__Trace_Error(3, 0, "This socket already exists", "", $hSocket)
				Return SetError(3, 0, __Trace_FuncOut("__netcode_AddSocket", False)) ; socket already exists in this array
			EndIf
		Next

		; add new client socket to array
		ReDim $arClients[$nArSize + 1]
		$arClients[$nArSize] = $hSocket

		; write new array to storage
		_storageS_Overwrite($hListenerSocket, '_netcode_ListenerClients', $arClients)

		; set default storage vars for this new client socket
		_storageS_Overwrite($hSocket, '_netcode_MyParent', $hListenerSocket) ; this is my parent
		__netcode_SocketSetManageMode($hSocket, 'auth') ; beginning in the auth stage - note make it optionally settable in the options

		Local $arBuffer[1000][2]
		_storageS_Overwrite($hSocket, '_netcode_SafetyBuffer', $arBuffer) ; safety buffer with 1000 elements
		_storageS_Overwrite($hSocket, '_netcode_SafetyBufferIndex', 0) ; starting at index 0
		_storageS_Overwrite($hSocket, '_netcode_SafetyBufferSize', 0) ; current buffer size is 0
		_storageS_Overwrite($hSocket, '_netcode_ExecutionBuffer', $arBuffer) ; execution buffer with 1000 elements
		_storageS_Overwrite($hSocket, '_netcode_ExecutionBufferIndex', 0) ; starting at index 0
		_storageS_Overwrite($hSocket, '_netcode_ExecutionIndex', 0) ; execution index starts at 0
		_storageS_Overwrite($hSocket, '_netcode_IncompletePacketBuffer', "") ; create empty incomplete packet buffer
		_storageS_Overwrite($hSocket, '_netcode_PacketQuo', "") ; create empty packetquo buffer
		_storageS_Overwrite($hSocket, '_netcode_PacketQuoSend', "") ; create empty packetquo buffer
		_storageS_Overwrite($hSocket, '_netcode_PacketQuoIDQuo', "")
		_storageS_Overwrite($hSocket, '_netcode_PacketQuoIDWait', "")
		_storageS_Overwrite($hSocket, '_netcode_SocketExecutionOnHold', False) ; OnHold on False
		_storageS_Overwrite($hSocket, '_netcode_PacketDynamicSize', 0) ; needs to be inherited from the parent or the server if client is from TCPConnect()
		Local $arBuffer[0]
		_storageS_Overwrite($hSocket, '_netcode_EventStorage', $arBuffer) ; create event buffer with 0 elements
;~ 		Local $arBuffer[1000] ; for BytesPerSecondArray
;~ 		For $i = 0 To 999
;~ 			$arBuffer[$i] = 0
;~ 		Next
		_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecond', 0)
;~ 		_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecondArray', $arBuffer)
		_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecondSecond', @SEC)
		_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecondCount', 0)
		_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecond', 0)
;~ 		_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecondArray', $arBuffer)
		_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecondSecond', @SEC)
		_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecondCount', 0)
		_storageS_Overwrite($hSocket, '_netcode_SendPacketPerSecond', 0)
		_storageS_Overwrite($hSocket, '_netcode_SendPacketPerSecondBuffer', 0)
		_storageS_Overwrite($hSocket, '_netcode_SendPacketPerSecondSecond', @SEC)
		_storageS_Overwrite($hSocket, '_netcode_RecvPacketPerSecond', 0)
		_storageS_Overwrite($hSocket, '_netcode_RecvPacketPerSecondBuffer', 0)
		_storageS_Overwrite($hSocket, '_netcode_RecvPacketPerSecondSecond', @SEC)
		__netcode_SocketSetPacketEncryption($hSocket, __netcode_SocketGetPacketEncryption($hListenerSocket))
		__netcode_SocketSetIPAndPort($hSocket, $sIP, $nPort) ; set ip and port given in _netcode_TCPConnect()
		__netcode_SocketSetUsernameAndPassword($hSocket, $sUsername, $sPassword)

		; write parent socket events to client socket
		Local $arEvents = __netcode_SocketGetEvents($hListenerSocket)
		$nArSize = UBound($arEvents)
		For $i = 0 To $nArSize - 1
			_netcode_SetEvent($hSocket, BinaryToString($arEvents[$i]), _storageS_Read($hListenerSocket, '_netcode_Event' & $arEvents[$i]))
		Next

		Return __Trace_FuncOut("__netcode_AddSocket", True)


	Else ; if we want to add a new listener socket

		; check if parent socket already exists
		If _storageS_Read($hSocket, '_netcode_SocketIsListener') Then
			__Trace_Error(4, 0, "This Socket already exists", "", $hSocket)
			Return SetError(4, 0, __Trace_FuncOut("__netcode_AddSocket", False)) ; it already exists
		EndIf

		; add parent socket to parent socket array
		$nArSize = UBound($__net_arSockets)
		ReDim $__net_arSockets[$nArSize + 1]
		$__net_arSockets[$nArSize] = $hSocket

		; set default storage vars for this parent socket
		_storageS_Overwrite($hSocket, '_netcode_SocketIsListener', True) ; this socket is a parent
		_storageS_Overwrite($hSocket, '_netcode_ListenerMaxConnections', $nIfListenerMaxConnections) ; set how much connections we allow
		_storageS_Overwrite($hSocket, '_netcode_ListenerCurrentConnections', 0) ; how much connections we currently have
		Local $arClients[0]
		_storageS_Overwrite($hSocket, '_netcode_ListenerClients', $arClients) ; create client array with 0 elements
		_storageS_Overwrite($hSocket, '_netcode_EventStorage', $arClients) ; create event array with 0 elements
		_storageS_Overwrite($hSocket, '_netcode_IPList', $__net_arGlobalIPList) ; set global ip list as parent ip list
		_storageS_Overwrite($hSocket, '_netcode_IPListIsWhitelist', $__net_bGlobalIPListIsWhitelist) ; set if ip list is white or blacklist
		_storageS_Overwrite($hSocket, '_netcode_SocketExecutionOnHold', False) ; OnHold on False
		__netcode_SocketSetIPAndPort($hSocket, $sIP, $nPort) ; set ip and port given in _netcode_TCPListen()

		Return __Trace_FuncOut("__netcode_AddSocket", $nArSize)

	EndIf
EndFunc   ;==>__netcode_AddSocket

Func __netcode_RemoveSocket(Const $hSocket, $bIsParent = False, $bDisconnectTriggered = False, $nDisconnectError = 0)
	__Trace_FuncIn("__netcode_RemoveSocket", $hSocket, $bIsParent)

	Local $arClients[0]
	Local $nArSize = 0
	Local $nIndex = 0

	If Not $bIsParent Then ; if we remove a client from a parent

		; get my parent socket and the client array from it
		Local $hParentSocket = _storageS_Read($hSocket, '_netcode_MyParent')
		$arClients = _storageS_Read($hParentSocket, '_netcode_ListenerClients')
		$nArSize = UBound($arClients)

		; check if the array even holds clients
		If $nArSize = 0 Then
			__Trace_Error(1, 0, "The parent has Zero connections")
			Return SetError(1, 0, __Trace_FuncOut("__netcode_RemoveSocket", False)) ; this array is empty
		EndIf

		; find position of my client in the client array
		$nIndex = -1
		For $i = 0 To $nArSize - 1
			If $arClients[$i] = $hSocket Then
				$nIndex = $i
				ExitLoop
			EndIf
		Next
		If $nIndex = -1 Then
			__Trace_Error(2, 0, "This socket doesnt exist")
			Return SetError(2, 0, __Trace_FuncOut("__netcode_RemoveSocket", False)) ; this socket doesnt exist in the array
		EndIf

		; call disconnect event
;~ 		__netcode_ExecuteEvent($hSocket, "disconnected")
		__netcode_ExecuteEvent($hSocket, "disconnected", _netcode_sParams($nDisconnectError, $bDisconnectTriggered))

		; remove one connection from the active connection counter of the parent
		Local $nCurrentConnections = _storageS_Read($hParentSocket, '_netcode_ListenerCurrentConnections') - 1
		_storageS_Overwrite($hParentSocket, '_netcode_ListenerCurrentConnections', $nCurrentConnections)

		; overwrite the found index with the last and ReDim the array aka remove the client socket
		$arClients[$nIndex] = $arClients[$nArSize - 1]
		ReDim $arClients[$nArSize - 1]

		; store the new array
		_storageS_Overwrite($hParentSocket, '_netcode_ListenerClients', $arClients)

		; tidy storage vars of the client socket. All vars get overwritten here with Bool False
		_storageS_TidyGroupVars($hSocket)

		; if parent socket is "000" and it has no more clients then remove the parent.
		if $hParentSocket = "000" Then
			if $nArSize - 1 = 0 Then __netcode_RemoveSocket("000", True)
		EndIf

		Return __Trace_FuncOut("__netcode_RemoveSocket", True)

	Else ; if we remove a parent

		; check if this is actually a parent socket
		If Not _storageS_Read($hSocket, '_netcode_SocketIsListener') Then
			__Trace_Error(3, 0, "Wrong Socket Type. This is a Client but has to be a parent")
			Return SetError(3, 0, __Trace_FuncOut("__netcode_RemoveSocket", False))
		EndIf

		; disconnect and remove every client of this parent
		$arClients = _storageS_Read($hSocket, '_netcode_ListenerClients')
		$nArSize = UBound($arClients)
		For $i = 0 To $nArSize - 1
			__netcode_TCPCloseSocket($arClients[$i])
			__netcode_RemoveSocket($arClients[$i], False)
		Next

		; find position of the parent in the parent array
		$nArSize = UBound($__net_arSockets)
		$nIndex = -1
		For $i = 0 To $nArSize - 1
			If $__net_arSockets[$i] = $hSocket Then
				$nIndex = $i
				ExitLoop
			EndIf
		Next
		If $nIndex = -1 Then
			__Trace_Error(4, 0, "Parent is unknown")
			Return SetError(4, 0, __Trace_FuncOut("__netcode_RemoveSocket", False)) ; parent socket isnt in the parent array
		EndIf

		; overwrite the found index with the last and ReDim the array
		$__net_arSockets[$nIndex] = $__net_arSockets[$nArSize - 1]
		ReDim $__net_arSockets[$nArSize - 1]

		; tidy storage vars of the parent socket. All vars get overwritten here with Bool False
		_storageS_TidyGroupVars($hSocket)

		Return __Trace_FuncOut("__netcode_RemoveSocket", True)

	EndIf

EndFunc   ;==>__netcode_RemoveSocket

Func __netcode_ParentGetClients(Const $hSocket)
	__Trace_FuncIn("__netcode_ParentGetClients", $hSocket)
	__Trace_FuncOut("__netcode_ParentGetClients")
	Return _storageS_Read($hSocket, '_netcode_ListenerClients')
EndFunc   ;==>__netcode_ParentGetClients

Func __netcode_ClientGetParent(Const $hSocket)
	__Trace_FuncIn("__netcode_ClientGetParent", $hSocket)
	__Trace_FuncOut("__netcode_ClientGetParent")
	Return _storageS_Read($hSocket, '_netcode_MyParent')
EndFunc   ;==>__netcode_ClientGetParent

; returns if its a parent or client
; 1 = is parent
; 2 = is client
; 0 = socket is unknown
Func __netcode_CheckSocket(Const $hSocket)
	__Trace_FuncIn("__netcode_CheckSocket", $hSocket)
	__Trace_FuncOut("__netcode_CheckSocket")
	If _storageS_Read($hSocket, '_netcode_SocketIsListener') Then Return 1
	If _storageS_Read($hSocket, '_netcode_MyParent') Then Return 2
	Return 0
EndFunc   ;==>__netcode_CheckSocket

Func __netcode_Installation()
	Local $rMSGBOX = MsgBox(64 + 4, "Installation", "Thanks for downloading the _netcode UDF. There is one Step left to setup _netcode." & @CRLF & @CRLF _
										& "That is to set the Default Seed within the Global var $__net_nNetcodeStringDefaultSeed"  & @CRLF & @CRLF _
										& "I can do that for you if i can write to myself. Click Yes if you allow me to. If the Path below is wrong " _
										& "press No and double click this UDF. I will ask you again:" & @CRLF & @CRLF _
										& @ScriptFullPath & @CRLF & @CRLF _
										& "You can also set the Seed yourself. Just open the UDF and change the mentioned Global var to a number of any length." _
										& "The var needs to look like this:" & @CRLF & @CRLF _
										& 'Global $__net_nNetcodeStringDefaultSeed = Number("random number")' & @CRLF & @CRLF _
										& "See the Documentation\seeding.txt for more info.")
	if $rMSGBOX <> 6 Then Exit

	if @ScriptName <> "_netcode_Core.au3" Then
		$rMSGBOX = MsgBox(48 + 4, "Warning", "My file name is not _netcode_Core.au3. It is: " & @CRLF & @CRLF _
										& @ScriptName & @CRLF & @CRLF _
										& "Am i really this file? (Keep in mind im going to edit me)")
		if $rMSGBOX <> 6 Then Exit
	EndIf

	Local $hOpen = FileOpen(@ScriptFullPath, 0)
	if $hOpen = -1 Then Exit MsgBox(16, "Error", "I cannot open myself in Read mode. Exiting")
	Local $sRead = FileRead($hOpen)
	FileClose($hOpen)

	$hOpen = FileOpen(@ScriptFullPath, 2)
	if $hOpen = -1 Then Exit MsgBox(16, "Error", "I cannot open myself in Write mode. Exiting")
	FileWrite($hOpen, StringReplace($sRead, '"%NotSet%"', 'Number("' & __netcode_RandomPW(20, 1) & '")', 1))
	FileClose($hOpen)

	MsgBox(64, "Done", "It should have worked. If you dont see this message again then everything is right")

	Exit
EndFunc

Func __netcode_Init()
	__Trace_FuncIn("__netcode_Init")
	Local Static $bInit = False
	If $bInit Then Return __Trace_FuncOut("__netcode_Init")

	TCPStartup()
	; _WinAPI_Wow64EnableWow64FsRedirection - "C:\Windows\Sysnative\ws2_32.dll"
;~ 	if @AutoItX64 Then
;~ 		$__net_hWs2_32 = DllOpen("C:\Windows\SysWOW64\ws2_32.dll")
;~ 	Else
		$__net_hWs2_32 = DllOpen("Ws2_32.dll")
;~ 	EndIf
	__netcode_CryptStartup()
	__netcode_Seeding()

	_netcode_PresetEvent("connection", "__netcode_EventConnect")
	_netcode_PresetEvent("disconnected", "__netcode_EventDisconnect")
	_netcode_PresetEvent("flood", "__netcode_EventFlood")
	_netcode_PresetEvent("banned", "__netcode_EventBanned")
	_netcode_PresetEvent("message", "__netcode_EventMessage")
	_netcode_PresetEvent("netcode_internal", "__netcode_EventInternal")

	$bInit = True
	__Trace_FuncOut("__netcode_Init")
EndFunc   ;==>__netcode_Init

; default string seeding
Func __netcode_Seeding($nSeed = $__net_nNetcodeStringDefaultSeed)
	__Trace_FuncIn("__netcode_Seeding", $nSeed)
	$__net_sAuthNetcodeString = __netcode_SeedToString($nSeed, 19, "AuthNetcodeString")
	$__net_sAuthNetcodeConfirmationString = __netcode_SeedToString($nSeed, 13, "AuthNetcodeConfirmationString")
	$__net_sPacketBegin = __netcode_SeedToString($nSeed, 10, "PacketBegin")
	$__net_sPacketInternalSplit = __netcode_SeedToString($nSeed, 10, "PacketInternalSplit")
	$__net_sPacketEnd = __netcode_SeedToString($nSeed, 10, "PacketEnd")
	$__net_sParamIndicatorString = __netcode_SeedToString($nSeed, 10, "ParamIndicatorString")
	$__net_sParamSplitSeperator = __netcode_SeedToString($nSeed, 10, "ParamSplitSeperator")
	$__net_sSerializationIndicator = __netcode_SeedToString($nSeed, 10, "SerializationIndicator")
	$__net_sSerializeArrayIndicator = __netcode_SeedToString($nSeed, 10, "SerializeArrayIndicator")
	$__net_sSerializeArrayYSeperator = __netcode_SeedToString($nSeed, 10, "SerializeArrayYSeperator")
	$__net_sSerializeArrayXSeperator = __netcode_SeedToString($nSeed, 10, "SerializeArrayXSeperator")
	__Trace_FuncOut("__netcode_Seeding")
EndFunc   ;==>__netcode_Seeding

Func __netcode_SeedingClientStrings(Const $hSocket, $nSeed)
	__Trace_FuncIn("__netcode_SeedingClientStrings", $hSocket, $nSeed)
	__netcode_SocketSetPacketStrings($hSocket, __netcode_SeedToString($nSeed, 10, "PacketBegin"), __netcode_SeedToString($nSeed, 10, "PacketInternalSplit"), __netcode_SeedToString($nSeed, 10, "PacketEnd"))
;~ 	__netcode_SocketSetParamStrings($hSocket, __netcode_SeedToString($nSeed, 10, "ParamIndicatorString"), __netcode_SeedToString($nSeed, 10, "ParamSplitSeperator"))
;~ 	__netcode_SocketSetSerializerStrings($hSocket, __netcode_SeedToString($nSeed, 10, "SerializationIndicator"), __netcode_SeedToString($nSeed, 10, "SerializeArrayIndicator"), __netcode_SeedToString($nSeed, 10, "SerializeArrayYSeperator"), __netcode_SeedToString($nSeed, 10, "SerializeArrayXSeperator"))
	__Trace_FuncOut("__netcode_SeedingClientStrings")
EndFunc   ;==>__netcode_SeedingClientStrings

; marked for recoding
; needs to generate strings that cant be reverted to the seed. Use hash algorhytms.
Func __netcode_SeedToString($nSeed, $nStringLen, $sSalt = "")
	__Trace_FuncIn("__netcode_SeedToString", $nSeed, $nStringLen, $sSalt)
	Local Static $arChars ; 61 chars
	If Not IsArray($arChars) Then $arChars = StringSplit(BinaryToString("0x6162636465666768696A6B6C6D6E6F707172737475767778797A4142434445464748494A4B4C4D4E4F505152535455565758595A30313233343536373839"), '', 2)

	If $sSalt <> "" Then
		Local $nSalt = 0
		Local $arSaltChars = StringSplit($sSalt, '', 2)

		For $i = 0 To UBound($arSaltChars) - 1
			$nSalt += Int(Asc($arSaltChars[$i]))
		Next

		$nSeed += $nSalt
	EndIf

	Local $sChars = ''
	For $i = 1 To $nStringLen
		SRandom($nSeed + $i)
		$sChars &= $arChars[Random(0, 61, 1)]
	Next

	Return __Trace_FuncOut("__netcode_SeedToString", $sChars)
EndFunc   ;==>__netcode_SeedToString

; no this isnt a reverse function
Func __netcode_StringToSeed($sString)
	__Trace_FuncIn("__netcode_StringToSeed", $sString)
	Local $arChars = StringSplit($sString, '', 2)

	Local $nSeed = ''
	For $i = 0 To UBound($arChars) - 1
		$nSeed &= Int(Asc($arChars[$i]))
	Next

	Return __Trace_FuncOut("__netcode_StringToSeed", Number($nSeed))
EndFunc   ;==>__netcode_StringToSeed

; use with client socket
Func __netcode_SocketSetPacketStrings(Const $hSocket, $sPacketBegin, $sPacketInternalSplit, $sPacketEnd)
	__Trace_FuncIn("__netcode_SocketSetPacketStrings", $hSocket, $sPacketBegin, $sPacketInternalSplit, $sPacketEnd)
	Local $arPacketStrings[3]
	$arPacketStrings[0] = $sPacketBegin
	$arPacketStrings[1] = $sPacketInternalSplit
	$arPacketStrings[2] = $sPacketEnd
	_storageS_Overwrite($hSocket, '_netcode_PacketStrings', $arPacketStrings)
	__Trace_FuncOut("__netcode_SocketSetPacketStrings")
EndFunc   ;==>__netcode_SocketSetPacketStrings

; use with client socket
Func __netcode_SocketGetPacketStrings(Const $hSocket)
	__Trace_FuncIn("__netcode_SocketGetPacketStrings", $hSocket)
	Local $arPacketStrings = _storageS_Read($hSocket, '_netcode_PacketStrings')
	If Not IsArray($arPacketStrings) Then Local $arPacketStrings[3] = [$__net_sPacketBegin, $__net_sPacketInternalSplit, $__net_sPacketEnd]

	Return __Trace_FuncOut("__netcode_SocketGetPacketStrings", $arPacketStrings)
EndFunc   ;==>__netcode_SocketGetPacketStrings

#cs have to see if i add this. the sParam and serializer functions need access to the socket id. currently they dont have that
Func __netcode_SocketSetParamStrings(Const $hSocket, $sParamIndicatorString, $sParamSplitSeperator)
	Local $arParamStrings[2]
	$arParamStrings[0] = $sParamIndicatorString
	$arParamStrings[1] = $sParamSplitSeperator
	_storageS_Overwrite($hSocket, '_netcode_ParamStrings', $arParamStrings)
EndFunc

Func __netcode_SocketGetParamStrings(Const $hSocket)
	Local $arParamStrings = _storageS_Read($hSocket, '_netcode_ParamStrings')
	if Not IsArray($arParamStrings) Then Local $arParamStrings[2] = [$__net_sParamIndicatorString, $__net_sParamSplitSeperator]

	Return $arParamStrings
EndFunc

Func __netcode_SocketSetSerializerStrings(Const $hSocket, $sSerializationIndicator, $sSerializeArrayIndicator, $sSerializeArrayYSeperator, $sSerializeArrayXSeperator)
	Local $arSerializerStrings[4]
	$arSerializerStrings[0] = $sSerializationIndicator
	$arSerializerStrings[1] = $sSerializeArrayIndicator
	$arSerializerStrings[2] = $sSerializeArrayYSeperator
	$arSerializerStrings[3] = $sSerializeArrayXSeperator
	_storageS_Overwrite($hSocket, '_netcode_SerializerStrings', $arSerializerStrings)
EndFunc

Func __netcode_SocketGetSerializerStrings(Const $hSocket)
	Local $arSerializerStrings = _storageS_Read($hSocket, '_netcode_SerializerStrings')
	if Not IsArray($arSerializerStrings) Then Local $arSerializerStrings[4] = [$__net_sSerializationIndicator, $__net_sSerializeArrayIndicator, $__net_sSerializeArrayYSeperator, $__net_sSerializeArrayXSeperator]

	Return $arSerializerStrings
EndFunc
#ce have to see if i add this. the sParam and serializer functions need access to the socket id. currently they dont have that

Func __netcode_SocketSetSendBytesPerSecond(Const $hSocket, $nBytes)
	__Trace_FuncIn("__netcode_SocketSetSendBytesPerSecond")

	; return if zero bytes because nothing needs to be added
	if $nBytes = 0 Then Return __Trace_FuncOut("__netcode_SocketSetSendBytesPerSecond")

	; get buffer and the second it belongs too
	Local $nBufferSize = _storageS_Read($hSocket, '_netcode_SendBytesPerSecondCount')
;~ 	if Not IsArray($arBuffer) Then Return __Trace_FuncOut("__netcode_SocketSetSendBytesPerSecond") ; socket gone
	Local $nCalculatedSecond = _storageS_Read($hSocket, '_netcode_SendBytesPerSecondSecond')

	; if its the next second then
	if $nCalculatedSecond <> @SEC Then

		; calculate how much bytes per second where send
		Local $nBytesPerSecond = $nBufferSize
		$nBufferSize = 0
		_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecondCount', 0)

		; and write said information to the storage
		_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecond', $nBytesPerSecond)
		_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecondSecond', @SEC)
	EndIf

	; add the current send bytes to the array index of the ms it was send
	$nBufferSize += $nBytes

	; update buffer
	_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecondCount', $nBufferSize)
	__Trace_FuncOut("__netcode_SocketSetSendBytesPerSecond")
EndFunc

#cs
Func __netcode_SocketSetSendBytesPerSecond_Backup(Const $hSocket, $nBytes)
	__Trace_FuncIn("__netcode_SocketSetSendBytesPerSecond")

	; return if zero bytes because nothing needs to be added
	if $nBytes = 0 Then Return __Trace_FuncOut("__netcode_SocketSetSendBytesPerSecond")

	; get buffer and the second it belongs too
	Local $arBuffer = _storageS_Read($hSocket, '_netcode_SendBytesPerSecondArray')
	if Not IsArray($arBuffer) Then Return __Trace_FuncOut("__netcode_SocketSetSendBytesPerSecond") ; socket gone
	Local $nCalculatedSecond = _storageS_Read($hSocket, '_netcode_SendBytesPerSecondSecond')

	; if its the next second then
	if $nCalculatedSecond <> @SEC Then

		; calculate how much bytes per second where send and also clean the buffer
		Local $nBytesPerSecond = 0
		For $i = 0 To 999
			$nBytesPerSecond += $arBuffer[$i]
			$arBuffer[$i] = 0
		Next

		; and write said information to the storage
		_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecond', $nBytesPerSecond)
		_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecondSecond', @SEC)
	EndIf

	; add the current send bytes to the array index of the ms it was send
	$arBuffer[@MSEC] += $nBytes

	; update buffer
	_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecondArray', $arBuffer)
	__Trace_FuncOut("__netcode_SocketSetSendBytesPerSecond")
EndFunc
#ce

; currently only works for client sockets
Func __netcode_SocketGetSendBytesPerSecond(Const $hSocket, $nMode = 0)
	Local $nBytesPerSecond = _storageS_Read($hSocket, '_netcode_SendBytesPerSecond')

	if $nBytesPerSecond = 0 Then
		Return 0
	Else
		; if the info is old as- or older then 2 seconds then return 0
;~ 		Local $nCalculatedSecond = _storageS_Read($hSocket, '_netcode_SendBytesPerSecondSecond')

		if @SEC - _storageS_Read($hSocket, '_netcode_SendBytesPerSecondSecond') >= 2 Then Return 0
	EndIf

	Switch $nMode
		Case 0 ; bytes
			Return $nBytesPerSecond

		Case 1 ; kbytes
			Return Round($nBytesPerSecond / 1024, 2)

		Case 2 ; mbytes
			Return Round($nBytesPerSecond / 1048576, 2)

;~ 		Case 3 ; gbytes
			; do we need that?

	EndSwitch
EndFunc

Func __netcode_SocketSetRecvBytesPerSecond(Const $hSocket, $nBytes)
	__Trace_FuncIn("__netcode_SocketSetRecvBytesPerSecond")

	; return if zero bytes because nothing needs to be added
	if $nBytes = 0 Then Return __Trace_FuncOut("__netcode_SocketSetRecvBytesPerSecond")

	; get buffer and the second it belongs too
	Local $nBufferSize = _storageS_Read($hSocket, '_netcode_RecvBytesPerSecondCount')
;~ 	if Not IsArray($arBuffer) Then Return __Trace_FuncOut("__netcode_SocketSetRecvBytesPerSecond") ; socket gone
	Local $nCalculatedSecond = _storageS_Read($hSocket, '_netcode_RecvBytesPerSecondSecond')

	; if its the next second then
	if $nCalculatedSecond <> @SEC Then

		; calculate how much bytes per second where received and also clean the buffer
		Local $nBytesPerSecond = $nBufferSize
		$nBufferSize = 0
		_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecondCount', 0)

		; and write said information to the storage
		_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecond', $nBytesPerSecond)
		_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecondSecond', @SEC)
	EndIf

	; add the current received bytes to the array index of the ms it was received
	$nBufferSize += $nBytes

	; update buffer
	_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecondCount', $nBufferSize)
	__Trace_FuncOut("__netcode_SocketSetRecvBytesPerSecond")
EndFunc

#cs
Func __netcode_SocketSetRecvBytesPerSecond_Backup(Const $hSocket, $nBytes)
	__Trace_FuncIn("__netcode_SocketSetRecvBytesPerSecond")

	; return if zero bytes because nothing needs to be added
	if $nBytes = 0 Then Return __Trace_FuncOut("__netcode_SocketSetRecvBytesPerSecond")

	; get buffer and the second it belongs too
	Local $arBuffer = _storageS_Read($hSocket, '_netcode_RecvBytesPerSecondArray')
	if Not IsArray($arBuffer) Then Return __Trace_FuncOut("__netcode_SocketSetRecvBytesPerSecond") ; socket gone
	Local $nCalculatedSecond = _storageS_Read($hSocket, '_netcode_RecvBytesPerSecondSecond')

	; if its the next second then
	if $nCalculatedSecond <> @SEC Then

		; calculate how much bytes per second where received and also clean the buffer
		Local $nBytesPerSecond = 0
		For $i = 0 To 999
			$nBytesPerSecond += $arBuffer[$i]
			$arBuffer[$i] = 0
		Next

		; and write said information to the storage
		_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecond', $nBytesPerSecond)
		_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecondSecond', @SEC)
	EndIf

	; add the current received bytes to the array index of the ms it was received
	$arBuffer[@MSEC] += $nBytes

	; update buffer
	_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecondArray', $arBuffer)
	__Trace_FuncOut("__netcode_SocketSetRecvBytesPerSecond")
EndFunc
#ce

Func __netcode_SocketGetRecvBytesPerSecond(Const $hSocket, $nMode = 0)
	Local $nBytesPerSecond = _storageS_Read($hSocket, '_netcode_RecvBytesPerSecond')

	if $nBytesPerSecond = 0 Then
		Return 0
	Else
		; if the info is old as- or older then 2 seconds then return 0
		if @SEC - _storageS_Read($hSocket, '_netcode_RecvBytesPerSecondSecond') >= 2 Then Return 0
	EndIf

	Switch $nMode
		Case 0 ; bytes
			Return $nBytesPerSecond

		Case 1 ; kbytes
			Return Round($nBytesPerSecond / 1024, 2)

		Case 2 ; mbytes
			Return Round($nBytesPerSecond / 1048576, 2)

;~ 		Case 3 ; gbytes
			; do we need that?

	EndSwitch
EndFunc

Func __netcode_SocketSetSendPacketPerSecond(Const $hSocket, $nCount)
	__Trace_FuncIn("__netcode_SocketSetSendPacketPerSecond", $hSocket, $nCount)
	Local $nBufferSize = _storageS_Read($hSocket, '_netcode_SendPacketPerSecondBuffer')
	Local $nCalculatedSecond = _storageS_Read($hSocket, '_netcode_SendPacketPerSecondSecond')

	if $nCalculatedSecond <> @SEC Then
		_storageS_Overwrite($hSocket, '_netcode_SendPacketPerSecond', $nBufferSize)
		_storageS_Overwrite($hSocket, '_netcode_SendPacketPerSecondSecond', @SEC)
		$nBufferSize = 0
	EndIf

	$nBufferSize += $nCount
	_storageS_Overwrite($hSocket, '_netcode_SendPacketPerSecondBuffer', $nBufferSize)
	__Trace_FuncOut("__netcode_SocketSetSendPacketPerSecond")
EndFunc

Func __netcode_SocketGetSendPacketPerSecond(Const $hSocket)
	; this is dump and will fail if the current sec is < the one the bps got saved for.
	if @SEC - _storageS_Read($hSocket, '_netcode_SendPacketPerSecondSecond') >=2 Then Return 0

	Return _storageS_Read($hSocket, '_netcode_SendPacketPerSecond')
EndFunc

Func __netcode_SocketSetRecvPacketPerSecond(Const $hSocket, $nCount)
	__Trace_FuncIn("__netcode_SocketSetRecvPacketPerSecond", $hSocket, $nCount)
	Local $nBufferSize = _storageS_Read($hSocket, '_netcode_RecvPacketPerSecondBuffer')
	Local $nCalculatedSecond = _storageS_Read($hSocket, '_netcode_RecvPacketPerSecondSecond')

	if $nCalculatedSecond <> @SEC Then
		_storageS_Overwrite($hSocket, '_netcode_RecvPacketPerSecond', $nBufferSize)
		_storageS_Overwrite($hSocket, '_netcode_RecvPacketPerSecondSecond', @SEC)
		$nBufferSize = 0
	EndIf

	$nBufferSize += $nCount
	_storageS_Overwrite($hSocket, '_netcode_RecvPacketPerSecondBuffer', $nBufferSize)
	__Trace_FuncOut("__netcode_SocketSetRecvPacketPerSecond")
EndFunc

Func __netcode_SocketGetRecvPacketPerSecond(Const $hSocket)
	if @SEC - _storageS_Read($hSocket, '_netcode_RecvPacketPerSecondSecond') >=2 Then Return 0

	Return _storageS_Read($hSocket, '_netcode_RecvPacketPerSecond')
EndFunc

; this functions only sets the var type, it doesnt convert the data
; so a String var, ment to be set to Binary, wont be set with StringToBinary() it will just be set with Binary()
Func __netcode_SetVarType($vData, $sVarType)
	__Trace_FuncIn("__netcode_SetVarType", "$vData", $sVarType)

	Switch $sVarType

		Case "Bool"
			If $vData == "False" Then Return __Trace_FuncOut("__netcode_SetVarType", False)
			If $vData == "True" Then Return __Trace_FuncOut("__netcode_SetVarType", True)

			__Trace_Error(2, 0, "Neither True not False was given", "", $vData)
			Return SetError(2, 0, __Trace_FuncOut("__netcode_SetVarType", False)) ; neither True nor False was given

		Case "Int32"
			__Trace_FuncOut("__netcode_SetVarType")
			Return Int($vData, 1)

		Case "Int64"
			__Trace_FuncOut("__netcode_SetVarType")
			Return Int($vData, 2)

		Case "Double"
			__Trace_FuncOut("__netcode_SetVarType")
			Return $vData + 0.00

		Case "Binary"
			__Trace_FuncOut("__netcode_SetVarType")
			Return Binary($vData)

		Case "String"
			__Trace_FuncOut("__netcode_SetVarType")
			Return String($vData)

		Case "HWnd" ; Help file - "No literal string should be converted to an HWND because there is no guarantee that a given window will have the same HWND ever again. This is not strictly forbidden, but it is a programming mistake and should be avoided."
			$vData = HWnd($vData)
			Local $nError = @error
			If $nError Then __Trace_Error($nError, 0, "HWnd Error")
			Return SetError($nError, 0, __Trace_FuncOut("__netcode_SetVarType", $vData)) ; if @error see HWnd() helpfile

		Case "Number"
			__Trace_FuncOut("__netcode_SetVarType")
			Return Number($vData)

		Case "Ptr"
			__Trace_FuncOut("__netcode_SetVarType")
			Return Ptr($vData)

		Case Else
			__Trace_Error(1, 0, "Unknown var type", "", $sVarType)
			Return SetError(1, 0, __Trace_FuncOut("__netcode_SetVarType", False)) ; cannot convert to that $sVarType

	EndSwitch
EndFunc   ;==>__netcode_SetVarType

; x32 and x64 compatible
Func __netcode_SocketSelect($arClients, $bRead = True)
	__Trace_FuncIn("__netcode_SocketSelect")
	Local $nArSize = UBound($arClients)
	Local $tFD_SET, $tTIMEVAL
	Local $arRet[0]

	; creating fd_set and timeval structs
	if @AutoItX64 Then ; structs need to be created with different var types for x32 and x64.
		$tFD_SET = DllStructCreate("int64 fd_count;int64 fd_array[" & $nArSize & "]")
		$tTIMEVAL = DllStructCreate("int64;int64")
	Else
		$tFD_SET = DllStructCreate("int fd_count;int fd_array[" & $nArSize & "]")
		$tTIMEVAL = DllStructCreate("int;int")
	EndIf

	; setting fd_count to the amount of socket to be checked and timevals to 0 sec and ms
	DllStructSetData($tFD_SET, "fd_count", $nArSize)
    DllStructSetData($tTIMEVAL, 1, 0) ; tv_sec
    DllStructSetData($tTIMEVAL, 2, 0) ; tv_usec

	; filling the fd_set dtruct with the client sockets
	For $i = 0 To $nArSize - 1
		DllStructSetData($tFD_SET, "fd_array", $arClients[$i], $i + 1)
	Next

	; if we want to filter for the sockets that have something in the receive buffer or if we want to filter for the sockets that can send something
	if $bRead Then
		$arRet = DllCall($__net_hWs2_32, 'int', 'select', 'int', 0, 'ptr', DllStructGetPtr($tFD_SET), 'ptr', 0, 'ptr', 0, 'ptr', DllStructGetPtr($tTIMEVAL))
	Else
		$arRet = DllCall($__net_hWs2_32, 'int', 'select', 'int', 0, 'ptr', 0, 'ptr', DllStructGetPtr($tFD_SET), 'ptr', 0, 'ptr', DllStructGetPtr($tTIMEVAL))
	EndIf

	; if the call failed. A fail can be -1 and 0. If its -1 then there also is an error retrievable with WSAGetLastError.
	if $arRet[0] = -1 Then
		__Trace_Error(__netcode_WSAGetLastError(), 0, "Select error")
		Return __Trace_FuncOut("__netcode_SocketSelect")
	ElseIf $arRet[0] = 0 Then
		Return __Trace_FuncOut("__netcode_SocketSelect")
	EndIf

	; redim the array with the amount of filtered sockets
	ReDim $arRet[DllStructGetData($tFD_SET, "fd_count")]

	; get the filtered sockets out of the struct
	For $i = 1 To UBound($arRet)
		$arRet[$i - 1] = DllStructGetData($tFD_SET, "fd_array", $i)
	Next

	; return the filtered sockets
	Return __Trace_FuncOut("__netcode_SocketSelect", $arRet)
EndFunc

; this func has some weird issue with WSAGetLastError returning error 1400, yes 1400 not 10040. The Error table doesnt reveal anything, google dont too.
; i dont know what the heck it means.
; marked for recoding. i have to find the best way to use send() or wsasend()
Func __netcode_TCPSend($hSocket, $sData, $bReturnWhenDone = True) ; TCPSend
	__Trace_FuncIn("__netcode_TCPSend", $hSocket, "$sData")
;~ 	$sData = BinaryToString($sData)
	Local $nLen = BinaryLen($sData)
;~ 	Local $nLen = StringLen($sData)

	If $__net_hWs2_32 = -1 Then $__net_hWs2_32 = DllOpen("Ws2_32.dll")

	Local $stAddress_Data = DllStructCreate('byte[' & $nLen & ']')
;~ 	Local $stAddress_Data = DllStructCreate('char[' & $nLen & ']')
	DllStructSetData($stAddress_Data, 1, $sData)

;~ 	Local $hTimer = TimerInit()
;~ 	Local $nTookTimer = 0
	Local $arRet[0]
	Local $nError = 0

	Do
		; ~ performance tests
;~ 		$arRet = DllCall($__net_hWs2_32, "int", "send", "ptr", $hSocket, "ptr", DllStructGetPtr($stAddress_Data), "int", DllStructGetSize($stAddress_Data), "int", 0)
;~ 		$arRet = DllCall($__net_hWs2_32, "int", "send", "int", $hSocket, "ptr", DllStructGetPtr($stAddress_Data), "int", DllStructGetSize($stAddress_Data), "int", 0)
		$arRet = DllCall($__net_hWs2_32, "int", "send", "int", $hSocket, "struct*", $stAddress_Data, "int", DllStructGetSize($stAddress_Data), "int", 0)
;~ 		$nTookTimer = TimerDiff($hTimer)

		If $arRet[0] <> -1 Then ExitLoop

		$nError = __netcode_WSAGetLastError()

		if $bReturnWhenDone And $nError = 10035 Then ContinueLoop
	Until $nError <> 1400

;~ 	if $nError Then MsgBox(0, @ScriptName, $nError)
;~ 	if $nError Then _ArrayDisplay($arRet)

	If $nError And $arRet[0] = -1 Then
;~ 	If $nError Or $arRet[0] = -1 Then
		if $nError <> 10035 Then __Trace_Error($nError, 0)
		Return SetError($nError, 0, __Trace_FuncOut("__netcode_TCPSend", 0))
	EndIf

;~ 	__netcode_SocketSetSendBytesPerSecond($hSocket, $arRet[0], $nTookTimer)

	Return __Trace_FuncOut("__netcode_TCPSend", $arRet[0])

EndFunc   ;==>__netcode_TCPSend

Func __netcode_WSAGetLastError()
;~ 	__Trace_FuncIn("__netcode_WSAGetLastError")
	If $__net_hWs2_32 = -1 Then $__net_hWs2_32 = DllOpen("Ws2_32.dll")
	Local $iRet = DllCall($__net_hWs2_32, "int", "WSAGetLastError")
	If @error Then
		SetExtended(1)
;~ 		Return __Trace_FuncOut("__netcode_WSAGetLastError", 0)
		Return 0
	EndIf
;~ 	Return __Trace_FuncOut("__netcode_WSAGetLastError", $iRet[0])
	Return $iRet[0]
EndFunc   ;==>__netcode_WSAGetLastError

; TCPRecv
; WSAGetLastError() sometimes returns error 5
; https://www.gamedev.net/forums/topic/399027-wsagetlasterror-returns-5-what-does-this-mean-solved/
Func __netcode_TCPRecv(Const $hSocket)
	__Trace_FuncIn("__netcode_TCPRecv", $hSocket)

	Local $nError = 0
	Local $tRecvBuffer = DllStructCreate("byte[" & 65536 & "]")

	; every socket is already non blocking, but recv still blocks occassionally which is very bad. So i reset to non blockig mode
	; until i figured why recv blocks while it shouldnt.
	Local $arRet = DllCall($__net_hWs2_32, "int", "ioctlsocket", "int", $hSocket, "long", 0x8004667e, "ulong*", 1) ;FIONBIO

	$arRet = DllCall($__net_hWs2_32, "int", "recv", "int", $hSocket, "ptr", DllStructGetPtr($tRecvBuffer), "int", 65536, "int", 0)

	; "If the connection has been gracefully closed, the return value is zero."
	if $arRet[0] = 0 Then
		__Trace_Error(1, 0, "Socket Error")
		Return SetError(1, 0, __Trace_FuncOut("__netcode_TCPRecv", False))
	EndIf

	if $arRet[0] = -1 Then
		$nError = __netcode_WSAGetLastError()
		if $nError > 10000 Then ; "Error codes below 10000 are standard Win32 error codes"
			if $nError <> 10035 Then
				__Trace_Error($nError, 2, "Socket Error")
				Return SetError($nError, 2, __Trace_FuncOut("__netcode_TCPRecv", False))
			EndIf
		EndIf

		Return __Trace_FuncOut("__netcode_TCPRecv", "")
	EndIf

;~ 	if @ScriptName = "Server.au3" then ConsoleWrite($hSocket & @TAB & @TAB & BinaryToString(BinaryMid(DllStructGetData($tRecvBuffer, 1), 1, $arRet[0])) & @CRLF)

	__Trace_FuncOut("__netcode_TCPRecv")
	Return SetError(0, $arRet[0], BinaryMid(DllStructGetData($tRecvBuffer, 1), 1, $arRet[0]))
EndFunc

#Region ===========================================================================================================================
; Code taken from j0kky

;~ #cs
; #FUNCTION# ====================================================================================================================
; Name...........: _TCPRecv
; Description ...: Receives data from a connected socket.
; Syntax.........: _TCPRecv($iMainsocket, $iMaxLen, $iFlag = 0)
; Parameters ....: $iMainsocket - The array as returned by _TCPAccept
;				   				  or the connected socket identifier (SocketID) as returned by _TCPConnect.
;                  $iMaxLen - max # of characters to receive (usually 2048).
;                  $iFlag - values can be added together
;                  |$TCP_DATA_DEFAULT (0) - Text data. [Default]
;                  |$TCP_DATA_BINARY (1) - Binary data.
;                  |$TCP_DATA_EOT (2) - Returns data received and
;				   				  		set @error to -6 when it reaches the End of Text ASCII character (Chr(3))
; Return values .: On success it returns the binary/string sent by the connected socket.
;                  On failure it returns "" and sets the @error or @extended flag to non-zero:
;                  @error values:
;                  |-1 - internal error
;                  |-2 - missing DLL (Ws2_32.dll)
;                  |-3 - undefined error
;                  |-4 - invalid parameter
;                  |Any Windows Socket Error Code retrieved by WSAGetLastError
;                  @extended values:
;                  |1 - connection closed
;                  |2 - End of Text reached
; Author ........: j0kky
; Modified ......: 1.0.0
; Remarks .......: If Unicode strings need to be transmitted they must be encoded/decoded with StringToBinary()/BinaryToString().
; 				   $iFlag = 2 must be set in couple with _TCPSend
; 				   You must check for both @error and @extended, @extended could be set with @error set to zero
; Links .........: recv:		https://msdn.microsoft.com/en-us/library/windows/desktop/ms740121(v=vs.85).aspx
;				   error codes:	https://msdn.microsoft.com/en-us/library/windows/desktop/ms740668(v=vs.85).aspx
; ===============================================================================================================================
Func __netcode_TCPRecv_Backup($iMainsocket, $iMaxLen, $iFlag = 0)
	__Trace_FuncIn("__netcode_TCPRecv_Backup", $iMainsocket, $iMaxLen, $iFlag)

;~ 	If IsArray($iMainsocket) And (UBound($iMainsocket, 0) = 1) And (UBound($iMainsocket) > 0) Then $iMainsocket = $iMainsocket[0]
;~ 	If $iFlag = Default Then $iFlag = 0
;~ 	$iMainsocket = Number($iMainsocket)
;~ 	$iMaxLen = Number($iMaxLen)
;~ 	$iFlag = Number($iFlag)
;~ 	If $iMainsocket < 0 Or _
;~ 			$iMaxLen < 1 Or _
;~ 			Not ($iFlag = 0 Or $iFlag = 1 Or $iFlag = 2) Then Return SetError(-4, 0, -1) ; invalid parameter

;~ 	If $__net_hWs2_32 = -1 Then $__net_hWs2_32 = DllOpen('Ws2_32.dll')
	Local $hWs2 = $__net_hWs2_32
;~ 	If @error Then Return SetError(-2, 0, -1) ;missing DLL
	Local $bError = 0, $nCode = 0, $nExtended = 0

	If Not $bError Then
		$aRet = DllCall($hWs2, "int", "ioctlsocket", "uint", $iMainsocket, "long", 0x8004667e, "ulong*", 1) ;FIONBIO
		If @error Then
			$bError = -1
		ElseIf $aRet[0] <> 0 Then ;SOCKET_ERROR
			$bError = 1
		EndIf
	EndIf

	Local $tBuf
	If $iFlag Then
		$tBuf = DllStructCreate("byte[" & $iMaxLen & "]")
	Else
		$tBuf = DllStructCreate("char[" & $iMaxLen & "]")
	EndIf
	Local $aRet = DllCall($hWs2, "int", "recv", "uint", $iMainsocket, "ptr", DllStructGetPtr($tBuf), "int", $iMaxLen, "int", 0)
	If @error Then
		$bError = -1
	ElseIf ($aRet[0] = -1) Or ($aRet[0] = 4294967295) Then ;SOCKET_ERROR
		$bError = 1
		$aRet = DllCall($hWs2, "int", "WSAGetLastError")
		If @error Then
			$bError = -1
		ElseIf $aRet[0] = 0 Or $aRet[0] = 10035 Then ;WSAEWOULDBLOCK
			$nCode = -10 ;internal function value, it means no error
		EndIf
	ElseIf $aRet[0] = 0 Then
		$bError = 1
		$nCode = -10
		$nExtended = 1 ;connection closed
	Else
;~ 		Local $sResult = DllStructGetData($tBuf, 1) ;data
		Local $sResult = BinaryMid(DllStructGetData($tBuf, 1), 1, $aRet[0]) ; "If no error occurs, recv returns the number of bytes received and the buffer pointed to by the buf parameter will contain this data received"
;~ 		If BitAND($iFlag, 2) = 2 Then ;EOT
;~ 			If StringRight($sResult, 1) = Chr(3) Then
;~ 				$sResult = StringTrimRight($sResult, 1)
;~ 				$nExtended = 2 ;End of Text reached
;~ 			EndIf
;~ 		EndIf
	EndIf

	Local $nReturn = ""

	If $bError < 0 Then
		$nCode = -1 ;internal error
		$nReturn = "" ;failure
	ElseIf $bError > 0 Then
		If Not $nCode Then
			$aRet = DllCall($hWs2, "int", "WSAGetLastError")
			If @error Then
				$nCode = -1
			Else
				$nCode = $aRet[0]
			EndIf
			If $nCode = 0 Then $nCode = -3 ;undefined error
		EndIf
		If $nCode = -10 Then $nCode = 0
		$nReturn = ""
	Else
		$nReturn = $sResult
	EndIf
;~ 	DllClose($hWs2)

	If $nCode <> 0 Then __Trace_Error($nCode, $nExtended)
	Return SetError($nCode, $nExtended, __Trace_FuncOut("__netcode_TCPRecv_Backup", $nReturn))
EndFunc   ;==>__netcode_TCPRecv
;~ #ce

; #FUNCTION# ====================================================================================================================
; Name...........: _TCPAccept
; Description ...: Permits an incoming connection attempt on a socket.
; Syntax.........: _TCPAccept($iMainsocket)
; Parameters ....: $iMainsocket - The main socket identifier (SocketID) as returned by _TCPListen function.
; Return values .: On success it returns an array:
;                  |[0] - The connected socket identifier.
;                  |[1] - The external address of the client
;                  |[2] - The external port which the client are communicating on
;                  On failure it returns -1 and sets @error to non zero:
;                  |-1 - internal error
;                  |-2 - missing DLL (Ws2_32.dll)
;                  |-3 - undefined error
;                  |-4 - invalid parameter (not used in this function)
;                  |Any Windows Socket Error Code retrieved by WSAGetLastError
; Author ........: j0kky
; Modified ......: 1.0.0
; Links .........: accept:		https://msdn.microsoft.com/en-us/library/windows/desktop/ms737526(v=vs.85).aspx
;				   error codes:	https://msdn.microsoft.com/en-us/library/windows/desktop/ms740668(v=vs.85).aspx
; ===============================================================================================================================
Func __netcode_TCPAccept($iMainsocket)
	__Trace_FuncIn("__netcode_TCPAccept", $iMainsocket)
	$iMainsocket = Number($iMainsocket)
	If $iMainsocket < 0 Then
		__Trace_Error(-4, 0, "Invalid parameter")
		Return SetError(-4, 0, __Trace_FuncOut("__netcode_TCPAccept", -1)) ; invalid parameter
	EndIf

	If $__net_hWs2_32 = -1 Then $__net_hWs2_32 = DllOpen('Ws2_32.dll')
	Local $hWs2 = $__net_hWs2_32
;~ 	If @error Then Return SetError(-2, 0, -1) ;missing DLL

	Local $bError = 0, $nCode = 0, $hSock = 0
	Local $tagSockAddr = "short sin_family; ushort sin_port; " & _
			"STRUCT; ulong S_addr; ENDSTRUCT; " & _ ;sin_addr
			"char sin_zero[8]"

	If Not $bError Then
		Local $aRet = DllCall($hWs2, "int", "ioctlsocket", "int", $iMainsocket, "dword", 0x8004667e, "uint*", 1) ;WSA_NBTCP
		If @error Then
			$bError = -1
		ElseIf $aRet[0] <> 0 Then ;SOCKET_ERROR
			$bError = 1
		EndIf
	EndIf

	If Not $bError Then
		Local $tSockAddr = DllStructCreate($tagSockAddr)

		$aRet = DllCall($hWs2, "uint", "accept", "uint", $iMainsocket, "ptr", DllStructGetPtr($tSockAddr), "int*", DllStructGetSize($tSockAddr))
		If @error Then
			$bError = -1
		ElseIf ($aRet[0] = 4294967295) Or ($aRet[0] = -1) Then ;INVALID_SOCKET
			$bError = 1
			$aRet = DllCall($hWs2, "int", "WSAGetLastError")
			If @error Then
				$bError = -1
			ElseIf ($aRet[0] = 0) Or ($aRet[0] = 10035) Then ;WSAEWOULDBLOCK
				$nCode = -10 ;internal function value, it means no error
			EndIf
		Else
			$hSock = $aRet[0]
;~ 			$aRet = DllCall($hWs2, "ptr", "inet_ntoa", "ulong", DllStructGetData($tSockAddr, "S_addr"))
;~ 			If @error Then
;~ 				$bError = -1
;~ 			ElseIf $aRet[0] = Null Then
;~ 				$bError = 1
;~ 			Else
;~ 				$sIPAddr = DllStructGetData(DllStructCreate("char[15]", $aRet[0]), 1)
;~ 				$aRet = DllCall($hWs2, "ushort", "ntohs", "ushort", DllStructGetData($tSockAddr, "sin_port"))
;~ 				If @error Then
;~ 					$bError = -1
;~ 				Else
;~ 					$nPort = $aRet[0]
;~ 					Local $aResult[3] = [$hSock, $sIPAddr, $nPort]
;~ 				EndIf
;~ 			EndIf
		EndIf
	EndIf

	Local $nReturn = 0

	If $bError < 0 Then
		$nCode = -1 ;internal error
		$nReturn = -1 ;failure
		If $hSock Then __netcode_TCPCloseSocket($hSock)
	ElseIf $bError > 0 Then
		If Not $nCode Then
			$aRet = DllCall($hWs2, "int", "WSAGetLastError")
			If @error Then
				$nCode = -1
			Else
				$nCode = $aRet[0]
			EndIf
			If $nCode = 0 Then $nCode = -3 ;undefined error
		EndIf
		If $nCode = -10 Then $nCode = 0
		$nReturn = -1
		If $hSock Then __netcode_TCPCloseSocket($hSock)
	Else
		$nReturn = $hSock

		; disable Nagle algorithm for testing https://docs.microsoft.com/en-us/windows/win32/api/winsock/nf-winsock-setsockopt
		Local $tworkspace = DllStructCreate("BOOLEAN")
		DllStructSetData($tworkspace, 1, False)
		$arGen = DllCall($__net_hWs2_32, "int", "setsockopt", "uint", $hSock, "int", 6, "int", 1, "struct*", $tworkspace, "int", DllStructGetSize($tworkspace))

	EndIf
;~ 	DllClose($hWs2)

	If $nCode <> 0 And $nCode <> 1400 Then __Trace_Error($nCode, 0)
	Return SetError($nCode, 0, __Trace_FuncOut("__netcode_TCPAccept", $nReturn))
EndFunc   ;==>__netcode_TCPAccept

#EndRegion ===========================================================================================================================

; ipv6
; https://docs.microsoft.com/en-us/windows/win32/winsock/sockaddr-2
; https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-socket
; https://docs.microsoft.com/en-us/windows/win32/winsock/function-calls-2
; http://osr600doc.xinuos.com/en/SDK_netapi/sockC.TheIPv6sockaddrstructure.html
Func __netcode_TCPListen($sIP, $sPort, $nMaxPendingConnections, $nAdressFamily = 2)
	__Trace_FuncIn("__netcode_TCPListen", $sIP, $sPort, $nMaxPendingConnections, $nAdressFamily)
	If $__net_hWs2_32 = -1 Then $__net_hWs2_32 = DllOpen('Ws2_32.dll')

	Local $nError = 0
	Local $arGen[0]
	Local $tDataBuffer
	Local $hSocket = 0

	; create socket
	if $nAdressFamily = 2 Then
		$arGen = DllCall($__net_hWs2_32, "uint", "socket", "int", $nAdressFamily, "int", 1, "int", 6)
		$hSocket = $arGen[0]

		; create ip and port struct
		$tDataBuffer = DllStructCreate("short; ushort; uint; char[8]")
		DllStructSetData($tDataBuffer, 1, 2)

		$arGen = DllCall($__net_hWs2_32, "ushort", "htons", "ushort", $sPort)
		DllStructSetData($tDataBuffer, 2, $arGen[0])

		$arGen = DllCall($__net_hWs2_32, "uint", "inet_addr", "str", $sIP)
		DllStructSetData($tDataBuffer, 3, $arGen[0])
	ElseIf $nAdressFamily = 23 Then

	 	$arGen = DllCall($__net_hWs2_32, "uint", "socket", "int", $nAdressFamily, "int", 1, "int", 6)
		$hSocket = $arGen[0]

;~ 		Local $tbuffer = DllStructCreate("uint s6_addr[16]")
;~ 		DllStructSetData($tBuffer, 1, $sIP)

		$tDataBuffer = DllStructCreate("short;ushort;ulong;struct;ulong")
		DllStructSetData($tDataBuffer, 1, 23)

		$arGen = DllCall($__net_hWs2_32, "ushort", "htons", "ushort", $sPort)
		DllStructSetData($tDataBuffer, 2, $arGen[0])

		$arGen = DllCall($__net_hWs2_32, "uint", "inet_addr", "str", $sIP)
;~ 		DllStructSetData($tDataBuffer, 4, $arGen[0])

	EndIf

	; bind socket
	$arGen = DllCall($__net_hWs2_32, "int", "bind", "uint", $hSocket, "ptr", DllStructGetPtr($tDataBuffer), "int", DllStructGetSize($tDataBuffer))
	If $arGen[0] <> 0 Then
		$nError = __netcode_WSAGetLastError()
		__Trace_Error($nError, 0)
		Return SetError($nError, 0, __Trace_FuncOut("__netcode_TCPListen"))
	EndIf

	; set listener
	$arGen = DllCall($__net_hWs2_32, "int", "listen", "uint", $hSocket, "int", $nMaxPendingConnections)
	If $arGen[0] <> 0 Then
		$nError = __netcode_WSAGetLastError()
		__Trace_Error($nError, 0)
		Return SetError($nError, 0, __Trace_FuncOut("__netcode_TCPListen"))
	EndIf

;~ 	Local $tworkspace = DllStructCreate("BOOLEAN")
;~ 	DllStructSetData($tworkspace, 1, False)
;~ 	$arGen = DllCall($__net_hWs2_32, "int", "setsockopt", "uint", $hSocket, "int", 6, "int", 1, "struct*", $tworkspace, "int", DllStructGetSize($tworkspace))

	$arGen = DllCall($__net_hWs2_32, "int", "ioctlsocket", "int", $hSocket, "dword", 0x8004667e, "uint*", 1) ;WSA_NBTCP

	Return __Trace_FuncOut("__netcode_TCPListen", $hSocket)
EndFunc   ;==>__netcode_TCPListen

Func __netcode_TCPConnect($sIP, $sPort, $nAdressFamily = 2)
	__Trace_FuncIn("__netcode_TCPConnect", $sIP, $sPort, $nAdressFamily)
	If $__net_hWs2_32 = -1 Then $__net_hWs2_32 = DllOpen('Ws2_32.dll')

	Local $nError = 0

	; create socket
	Local $arGen = DllCall($__net_hWs2_32, "uint", "socket", "int", $nAdressFamily, "int", 1, "int", 6)
	Local $hSocket = $arGen[0]

	; create ip and port struct
	; ~ todo IPv6 support here
	Local $tDataBuffer = DllStructCreate("short; ushort; uint; char[8]")
	DllStructSetData($tDataBuffer, 1, 2)

	$arGen = DllCall($__net_hWs2_32, "ushort", "htons", "ushort", $sPort)
	DllStructSetData($tDataBuffer, 2, $arGen[0])

	$arGen = DllCall($__net_hWs2_32, "uint", "inet_addr", "str", $sIP)
	DllStructSetData($tDataBuffer, 3, $arGen[0])

	; connect
	$arGen = DllCall($__net_hWs2_32, "int", "connect", "uint", $hSocket, "ptr", DllStructGetPtr($tDataBuffer), "int", DllStructGetSize($tDataBuffer))
	If $arGen[0] <> 0 Then
		$nError = __netcode_WSAGetLastError()
		__Trace_Error($nError, 0)
		Return SetError($nError, 0, __Trace_FuncOut("__netcode_TCPConnect", -1))
	EndIf

	; disable Nagle algorithm for testing https://docs.microsoft.com/en-us/windows/win32/api/winsock/nf-winsock-setsockopt
	Local $tworkspace = DllStructCreate("BOOLEAN")
	DllStructSetData($tworkspace, 1, False)
	$arGen = DllCall($__net_hWs2_32, "int", "setsockopt", "uint", $hSocket, "int", 6, "int", 1, "struct*", $tworkspace, "int", DllStructGetSize($tworkspace))

	; make socket non blocking
	$arGen = DllCall($__net_hWs2_32, "int", "ioctlsocket", "int", $hSocket, "dword", 0x8004667E, "uint*", 1)

	Return __Trace_FuncOut("__netcode_TCPConnect", $hSocket)
EndFunc   ;==>__netcode_TCPConnect

Func __netcode_CheckEncryption()
	__netcode_CryptStartup()

	Local Const $sTestString = "Lorem ipsum 0123456789"
;~ 	Local Const $sTestString = ClipGet()
	Local $arError[3] = [False, False, False]

	; test RSA
	Local $arKeyPairs = __netcode_CryptGenerateRSAKeyPair(2048)

	Local $sEncData = __netcode_RSAEncrypt($sTestString, $arKeyPairs[1])
	Local $sDecData = __netcode_RSADecrypt($sEncData, $arKeyPairs[0])

	If $sTestString <> BinaryToString($sDecData) Then $arError[0] = True

	; test AES
	Local $hKeyHandlle = __netcode_AESDeriveKey("lets just use this password", "need some pommes to your salt?")

	$sEncData = __netcode_AESEncrypt($sTestString, $hKeyHandlle)
	$sDecData = __netcode_AESDecrypt($sEncData, $hKeyHandlle)

	If $sTestString <> BinaryToString($sDecData) Then $arError[1] = True

	; test SHA256
	; ~ todo
;~ 	Local $sEncData = __netcode_CryptSHA256($sTestString)

	; ~ todo recode
	If $arError[0] And $arError[1] And $arError[2] Then Return SetError(4, 0, False) ; if all failed
	If $arError[0] Then Return SetError(1, 0, False) ; if RSA failed
	If $arError[1] Then Return SetError(2, 0, False) ; if AES failed
	If $arError[2] Then Return SetError(3, 0, False) ; if SHA failed

	Return True
EndFunc   ;==>__netcode_CheckEncryption

#Region ===========================================================================================================================
; Stripped down CryptoNG UDF by TheXman@autoitscript.com

Func __netcode_AESEncrypt($sData, $sPW)
	__Trace_FuncIn("__netcode_AESEncrypt", "$sData", "$sPW")

	If IsString($sData) Then
		$sData = StringToBinary($sData, 4)
	Else
		$sData = Binary($sData)
	EndIf

	Local $tDataBuffer = DllStructCreate(StringFormat('byte data[%i]', BinaryLen($sData)))
	DllStructSetData($tDataBuffer, 1, $sData)

	Local $tIVBuffer = DllStructCreate(StringFormat('byte data[%i]', BinaryLen($__net_sInt_CryptionIV)))
	DllStructSetData($tIVBuffer, 1, $__net_sInt_CryptionIV)

	; get size of encrypted output
	Local $arEncrypt = DllCall($__net_hInt_bcryptdll, "int", "BCryptEncrypt", _
			"handle", $sPW, _
			"struct*", $tDataBuffer, _
			"ulong", DllStructGetSize($tDataBuffer), _
			"ptr", Null, _
			"struct*", $tIVBuffer, _
			"ulong", DllStructGetSize($tIVBuffer), _
			"ptr", Null, _
			"ulong*", 0, _
			"ulong*", Null, _
			"ulong", 0x00000001 _
			)

	Local $tOutputBuffer = DllStructCreate(StringFormat('byte data[%i]', $arEncrypt[9]))

	$arEncrypt = DllCall($__net_hInt_bcryptdll, "int", "BCryptEncrypt", _
			"handle", $sPW, _
			"struct*", $tDataBuffer, _
			"ulong", DllStructGetSize($tDataBuffer), _
			"ptr", Null, _
			"struct*", $tIVBuffer, _
			"ulong", DllStructGetSize($tIVBuffer), _
			"struct*", $tOutputBuffer, _
			"ulong", DllStructGetSize($tOutputBuffer), _
			"ulong*", Null, _
			"ulong", 0x00000001 _
			)


	Return __Trace_FuncOut("__netcode_AESEncrypt", DllStructGetData($tOutputBuffer, 1))

EndFunc   ;==>__netcode_AESEncrypt

Func __netcode_AESDecrypt($sData, $sPW)
	__Trace_FuncIn("__netcode_AESDecrypt", "$sData", "$sPW")
	If IsString($sData) Then
		$sData = StringToBinary($sData, 4)
	Else
		$sData = Binary($sData)
	EndIf

	Local $tDataBuffer = DllStructCreate(StringFormat('byte data[%i]', BinaryLen($sData)))
	DllStructSetData($tDataBuffer, 1, $sData)

	Local $tIVBuffer = DllStructCreate(StringFormat('byte data[%i]', BinaryLen($__net_sInt_CryptionIV)))
	DllStructSetData($tIVBuffer, 1, $__net_sInt_CryptionIV)

	; get size of encrypted output
	Local $arDecrypt = DllCall($__net_hInt_bcryptdll, "int", "BCryptDecrypt", _
			"handle", $sPW, _
			"struct*", $tDataBuffer, _
			"ulong", DllStructGetSize($tDataBuffer), _
			"ptr", Null, _
			"struct*", $tIVBuffer, _
			"ulong", DllStructGetSize($tIVBuffer), _
			"ptr", Null, _
			"ulong*", 0, _
			"ulong*", Null, _
			"ulong", 0x00000001 _
			)

	Local $tOutputBuffer = DllStructCreate(StringFormat('byte data[%i]', $arDecrypt[9]))

	$arDecrypt = DllCall($__net_hInt_bcryptdll, "int", "BCryptDecrypt", _
			"handle", $sPW, _
			"struct*", $tDataBuffer, _
			"ulong", DllStructGetSize($tDataBuffer), _
			"ptr", Null, _
			"struct*", $tIVBuffer, _
			"ulong", DllStructGetSize($tIVBuffer), _
			"struct*", $tOutputBuffer, _
			"ulong", DllStructGetSize($tOutputBuffer), _
			"ulong*", Null, _
			"ulong", 0x00000001 _
			)

	If $arDecrypt[0] <> 0 Then
		__Trace_Error(1, 0, "Couldnt decrypt data")
		Return SetError(1, 0, __Trace_FuncOut("__netcode_AESDecrypt", -1)) ; couldnt decrypt
	EndIf

	$sData = BinaryMid(DllStructGetData($tOutputBuffer, 1), 1, $arDecrypt[9])

	Return __Trace_FuncOut("__netcode_AESDecrypt", $sData)

EndFunc   ;==>__netcode_AESDecrypt

; only accepts AES "256"
Func __netcode_AESDeriveKey($vKey, $sSalt)
	__Trace_FuncIn("__netcode_AESDeriveKey", "$vKey", "$sSalt")

	; create PBKDF2
	Local $arOpenProvider = DllCall($__net_hInt_bcryptdll, 'int', 'BCryptOpenAlgorithmProvider', 'handle*', 0, 'wstr', 'SHA1', 'wstr', $__net_sInt_CryptionProvider, 'ulong', 0x00000008)
	Local $hHashProvider = $arOpenProvider[1]

	Local $sPassword = StringToBinary($vKey, 4)
	Local $tPasswordBuffer = DllStructCreate(StringFormat('byte data[%i]', BinaryLen($sPassword)))
	DllStructSetData($tPasswordBuffer, 1, $sPassword)

	Local $vSalt

	If IsString($sSalt) Then
		$vSalt = StringToBinary($sSalt, 4)
	Else
		$vSalt = Binary($sSalt)
	EndIf
	Local $tSaltBuffer = DllStructCreate(StringFormat('byte data[%i]', BinaryLen($vSalt)))
	DllStructSetData($tSaltBuffer, 1, $sSalt)

	Local $tKeyBuffer = DllStructCreate(StringFormat('byte data[%i]', 256 / 8))

	Local $arDeriveKey = DllCall($__net_hInt_bcryptdll, "int", "BCryptDeriveKeyPBKDF2", _
			"handle", $hHashProvider, _
			"struct*", $tPasswordBuffer, _
			"ulong", DllStructGetSize($tPasswordBuffer), _
			"struct*", $tSaltBuffer, _
			"ulong", DllStructGetSize($tSaltBuffer), _
			"uint64", $__net_nInt_CryptionIterations, _
			"struct*", $tKeyBuffer, _
			"ulong", DllStructGetSize($tKeyBuffer), _
			"ulong", 0 _
			)

	Local $vPBKDF2 = DllStructGetData($tKeyBuffer, 1)

	__netcode_CryptCloseProvider($hHashProvider)

	; generate symmetric key
	If IsString($vPBKDF2) Then
		$vPBKDF2 = StringToBinary($vPBKDF2, 4)
	Else
		$vPBKDF2 = Binary($vPBKDF2)
	EndIf

	$tKeyBuffer = DllStructCreate(StringFormat('byte data[%i]', BinaryLen($vPBKDF2)))
	DllStructSetData($tKeyBuffer, 1, $vPBKDF2)

	Local $arSymmetricKey = DllCall($__net_hInt_bcryptdll, "int", "BCryptGenerateSymmetricKey", _
			"handle", $__net_hInt_hAESAlgorithmProvider, _
			"handle*", Null, _
			"ptr", Null, _
			"ulong", 0, _
			"struct*", $tKeyBuffer, _
			"ulong", DllStructGetSize($tKeyBuffer), _
			"ulong", 0 _
			)

	Local $hEncryptionKey = $arSymmetricKey[2]

	Return __Trace_FuncOut("__netcode_AESDeriveKey", $hEncryptionKey)


	; anti au3check error
	if False = True Then __netcode_Au3CheckFix($arDeriveKey)

EndFunc   ;==>__netcode_AESDeriveKey

; i had to fiddle around with RSA alot to make it compatible to all data inputs. Thats why it looks so wonky.
Func __netcode_RSAEncrypt($sData, $sPublicKey)
	__Trace_FuncIn("__netcode_RSAEncrypt", "$sData", "$sPublicKey")
	If IsBinary($sPublicKey) Then $sPublicKey = BinaryToString($sPublicKey)
	$sPublicKey = __netcode_CryptStringToBinary($sPublicKey)

	If IsString($sData) Then $sData = StringToBinary($sData)
	$sData = __netcode_CryptBinaryToString($sData)

	Local $sEncData = __netcode_CryptRSAEncrypt($sData, $sPublicKey)

	$sEncData = __netcode_CryptBinaryToString($sEncData)
	$sEncData = StringToBinary($sEncData)

	Return __Trace_FuncOut("__netcode_RSAEncrypt", $sEncData)
EndFunc   ;==>__netcode_RSAEncrypt

Func __netcode_RSADecrypt($sData, $sPrivateKey)
	__Trace_FuncIn("__netcode_RSADecrypt", "$sData", "$sPrivateKey")
	If IsBinary($sPrivateKey) Then $sPrivateKey = BinaryToString($sPrivateKey)
	$sPrivateKey = __netcode_CryptStringToBinary($sPrivateKey)

	If IsBinary($sData) Then $sData = BinaryToString($sData)
	$sData = __netcode_CryptStringToBinary($sData)

	Local $sDecData = __netcode_CryptRSADecrypt($sData, $sPrivateKey)

	$sDecData = BinaryToString($sDecData)
	$sDecData = __netcode_CryptStringToBinary($sDecData)

	Return __Trace_FuncOut("__netcode_RSADecrypt", $sDecData)
EndFunc   ;==>__netcode_RSADecrypt

Func __netcode_CryptRSAEncrypt($sData, $sPublicKey)
	__Trace_FuncIn("__netcode_CryptRSAEncrypt", "$sData", "$sPublicKey")
	Local $hKeyHandlle = __netcode_RSAImportKey($sPublicKey, "RSAPUBLICBLOB")

	If IsString($sData) Then
		$sData = StringToBinary($sData)
	Else
		$sData = Binary($sData)
	EndIf

	Local $vPadding = $__net_vInt_RSAEncPadding

	Local $tDataBuffer = DllStructCreate(StringFormat("byte data[%i]", BinaryLen($sData)))
	DllStructSetData($tDataBuffer, 1, $sData)

	Local $arGen = DllCall($__net_hInt_bcryptdll, "int", "BCryptEncrypt", _
			"handle", $hKeyHandlle, _
			"struct*", $tDataBuffer, _
			"ulong", DllStructGetSize($tDataBuffer), _
			"ptr", Null, _
			"struct*", Null, _
			"ulong", 0, _
			"ptr", Null, _
			"ulong*", Null, _
			"ulong*", Null, _
			"ulong", $vPadding _
			)

	Local $tOutputBuffer = DllStructCreate(StringFormat("byte data[%i]", $arGen[9]))

	$arGen = DllCall($__net_hInt_bcryptdll, "int", "BCryptEncrypt", _
			"handle", $hKeyHandlle, _
			"struct*", $tDataBuffer, _
			"ulong", DllStructGetSize($tDataBuffer), _
			"ptr", Null, _
			"struct*", Null, _
			"ulong", 0, _
			"struct*", $tOutputBuffer, _
			"ulong", DllStructGetSize($tOutputBuffer), _
			"ulong*", Null, _
			"ulong", $vPadding _
			)

	Return __Trace_FuncOut("__netcode_CryptRSAEncrypt", DllStructGetData($tOutputBuffer, 1))
EndFunc   ;==>__netcode_CryptRSAEncrypt

Func __netcode_CryptRSADecrypt($sData, $sPrivateKey)
	__Trace_FuncIn("__netcode_CryptRSADecrypt", "$sData", "$sPrivateKey")
	Local $hKeyHandlle = __netcode_RSAImportKey($sPrivateKey, "RSAPRIVATEBLOB")

	Local $vPadding = $__net_vInt_RSAEncPadding

	Local $tDataBuffer = DllStructCreate(StringFormat("byte data[%i]", BinaryLen($sData)))
	DllStructSetData($tDataBuffer, 1, $sData)

	Local $arGen = DllCall($__net_hInt_bcryptdll, "int", "BCryptDecrypt", _
			"handle", $hKeyHandlle, _
			"struct*", $tDataBuffer, _
			"ulong", DllStructGetSize($tDataBuffer), _
			"ptr", Null, _
			"struct*", Null, _
			"ulong", 0, _
			"ptr", Null, _
			"ulong*", Null, _
			"ulong*", Null, _
			"ulong", $vPadding _
			)

	Local $tOutputBuffer = DllStructCreate(StringFormat("byte data[%i]", $arGen[9]))

	$arGen = DllCall($__net_hInt_bcryptdll, "int", "BCryptDecrypt", _
			"handle", $hKeyHandlle, _
			"struct*", $tDataBuffer, _
			"ulong", DllStructGetSize($tDataBuffer), _
			"ptr", Null, _
			"struct*", Null, _
			"ulong", 0, _
			"struct*", $tOutputBuffer, _
			"ulong", DllStructGetSize($tOutputBuffer), _
			"ulong*", Null, _
			"ulong", $vPadding _
			)

	Return __Trace_FuncOut("__netcode_CryptRSADecrypt", BinaryMid(DllStructGetData($tOutputBuffer, 1), 1, $arGen[9]))
EndFunc   ;==>__netcode_CryptRSADecrypt

Func __netcode_RSAImportKey($sKey, $sBlob)
	__Trace_FuncIn("__netcode_RSAImportKey", "$sKey", "$sBlob")

	Local $tKeyBuffer = DllStructCreate(StringFormat("byte data [%i]", BinaryLen($sKey)))
	DllStructSetData($tKeyBuffer, 1, $sKey)

	Local $arGen = DllCall($__net_hInt_bcryptdll, "int", "BCryptImportKeyPair", _
			"handle", $__net_hInt_hRSAAlgorithmProvider, _
			"handle", Null, _
			"wstr", $sBlob, _
			"handle*", Null, _
			"struct*", $tKeyBuffer, _
			"ulong", DllStructGetSize($tKeyBuffer), _
			"ulong", 0x00000008 _
			)

	Return __Trace_FuncOut("__netcode_RSAImportKey", $arGen[4])

EndFunc   ;==>__netcode_RSAImportKey

; [0] = private
; [1] = public
Func __netcode_CryptGenerateRSAKeyPair($nKeyLen)
	__Trace_FuncIn("__netcode_CryptGenerateRSAKeyPair", $nKeyLen)
	Local $arGen = DllCall($__net_hInt_bcryptdll, "int", "BCryptGenerateKeyPair", _
			"handle", $__net_hInt_hRSAAlgorithmProvider, _
			"handle*", Null, _
			"ulong", $nKeyLen, _
			"ulong", 0 _
			)

	Local $hKeyHandlle = $arGen[2]

	$arGen = DllCall($__net_hInt_bcryptdll, "int", "BCryptFinalizeKeyPair", _
			"handle", $hKeyHandlle, _
			"ulong", 0 _
			)


	Local $arReturn[2]
	$arReturn[0] = __netcode_CryptReadRSA($hKeyHandlle, "RSAPRIVATEBLOB")
	$arReturn[1] = __netcode_CryptReadRSA($hKeyHandlle, "RSAPUBLICBLOB")

	$arReturn[0] = __netcode_CryptBinaryToString($arReturn[0])
	$arReturn[1] = __netcode_CryptBinaryToString($arReturn[1])

	$arReturn[0] = StringToBinary($arReturn[0])
	$arReturn[1] = StringToBinary($arReturn[1])

	Return __Trace_FuncOut("__netcode_CryptGenerateRSAKeyPair", $arReturn)

EndFunc   ;==>__netcode_CryptGenerateRSAKeyPair

Func __netcode_CryptReadRSA($hKeyHandlle, $sBlob)
	__Trace_FuncIn("__netcode_CryptReadRSA", "$hKeyHandle", "$sBlob")
	Local $arGen = DllCall($__net_hInt_bcryptdll, "int", "BCryptExportKey", _
			"handle", $hKeyHandlle, _
			"handle", Null, _
			"wstr", $sBlob, _
			"ptr", Null, _
			"ulong", 0, _
			"ulong*", Null, _
			"ulong", 0 _
			)

	Local $tKeyBuffer = DllStructCreate(StringFormat("byte data[%i]", $arGen[6]))

	$arGen = DllCall($__net_hInt_bcryptdll, "int", "BCryptExportKey", _
			"handle", $hKeyHandlle, _
			"handle", Null, _
			"wstr", $sBlob, _
			"struct*", $tKeyBuffer, _
			"ulong", DllStructGetSize($tKeyBuffer), _
			"ulong*", Null, _
			"ulong", 0 _
			)

	Return __Trace_FuncOut("__netcode_CryptReadRSA", DllStructGetData($tKeyBuffer, 1))

EndFunc   ;==>__netcode_CryptReadRSA

Func __netcode_CryptSHA256($sData)
	__Trace_FuncIn("__netcode_CryptSHA256", "$sData")

	If IsString($sData) Then
		$sData = BinaryToString($sData, 4)
	Else
		$sData = Binary($sData)
	EndIf


	Local $arGen = DllCall($__net_hInt_bcryptdll, "int", "BCryptCreateHash", _
			"handle", $__net_hInt_hSHAAlgorithmProvider, _
			"handle*", 0, _
			"ptr", Null, _
			"ulong", 0, _
			"struct*", Null, _
			"ulong", 0, _
			"ulong", 0 _
			)

	Local $hHashObject = $arGen[2]

	Local $tDataBuffer = DllStructCreate(StringFormat("byte data[%i]", BinaryLen($sData)))
	DllStructSetData($tDataBuffer, 1, $sData)

	$arGen = DllCall($__net_hInt_bcryptdll, "int", "BCryptHashData", _
			"handle", $hHashObject, _
			"struct*", $tDataBuffer, _
			"ulong", DllStructGetSize($tDataBuffer), _
			"ulong", 0 _
			)

	$arGen = DllCall($__net_hInt_bcryptdll, "int", "BCryptGetProperty", _
			"handle", $hHashObject, _
			"wstr", "HashDigestLength", _
			"ptr", Null, _
			"ulong", 0, _
			"ulong*", 0, _
			"ulong", 0 _
			)

	$tDataBuffer = DllStructCreate(StringFormat("byte data[%i]", $arGen[5]))
	$arGen = DllCall($__net_hInt_bcryptdll, "int", "BCryptGetProperty", _
			"handle", $hHashObject, _
			"wstr", "HashDigestLength", _
			"struct*", $tDataBuffer, _
			"ulong", DllStructGetSize($tDataBuffer), _
			"ulong*", 0, _
			"ulong", 0 _
			)

	$tDataBuffer = DllStructCreate(StringFormat("byte data[%i]", DllStructGetData($tDataBuffer, 1, 1)))
	$arGen = DllCall($__net_hInt_bcryptdll, "int", "BCryptFinishHash", _
			"handle", $hHashObject, _
			"struct*", $tDataBuffer, _
			"ulong", DllStructGetSize($tDataBuffer), _
			"ulong", 0 _
			)

	Return __Trace_FuncOut("__netcode_CryptSHA256", DllStructGetData($tDataBuffer, 1))

EndFunc   ;==>__netcode_CryptSHA256

Func __netcode_CryptBinaryToString($sData, $iStringFormat = 0x00000001 + 0x40000000)
	__Trace_FuncIn("__netcode_CryptBinaryToString", "$sData", $iStringFormat)

	Local $tDataBuffer = DllStructCreate(StringFormat("byte data[%i];", BinaryLen($sData)))
	DllStructSetData($tDataBuffer, 1, $sData)

	Local $arGen = DllCall($__net_hInt_cryptdll, "int", "CryptBinaryToStringW", _
			"struct*", $tDataBuffer, _
			"dword", DllStructGetSize($tDataBuffer), _
			"dword", $iStringFormat, _
			"wstr", Null, _
			"dword*", Null _
			)


	Local $tValueBuffer = DllStructCreate("dword value;")
	DllStructSetData($tDataBuffer, 1, $arGen[5], 0)

	$arGen = DllCall($__net_hInt_cryptdll, "int", "CryptBinaryToStringW", _
			"struct*", $tDataBuffer, _
			"dword", DllStructGetSize($tDataBuffer), _
			"dword", $iStringFormat, _
			"wstr", "", _
			"dword*", DllStructGetPtr($tValueBuffer) _
			)


	Return __Trace_FuncOut("__netcode_CryptBinaryToString", $arGen[4])

EndFunc   ;==>__netcode_CryptBinaryToString

Func __netcode_CryptStringToBinary($sData, $iStringFormat = 0x00000006)
	__Trace_FuncIn("__netcode_CryptStringToBinary", "$sData", $iStringFormat)

	Local $arGen = DllCall($__net_hInt_cryptdll, "int", "CryptStringToBinaryW", _
			"wstr", $sData, _
			"dword", StringLen($sData), _
			"dword", $iStringFormat, _
			"struct*", Null, _
			"dword*", Null, _
			"dword*", Null, _
			"dword*", Null _
			)


	Local $tValueBuffer = DllStructCreate("dword value;")
	DllStructSetData($tValueBuffer, 1, $arGen[5], 0)

	Local $tDataBuffer = DllStructCreate(StringFormat("byte data[%i];", $arGen[5]))

	$arGen = DllCall($__net_hInt_cryptdll, "int", "CryptStringToBinaryW", _
			"wstr", $sData, _
			"dword", StringLen($sData), _
			"dword", $iStringFormat, _
			"struct*", $tDataBuffer, _
			"dword*", DllStructGetPtr($tValueBuffer), _
			"dword*", Null, _
			"dword*", Null _
			)

	Return __Trace_FuncOut("__netcode_CryptStringToBinary", DllStructGetData($tDataBuffer, 1))

EndFunc   ;==>__netcode_CryptStringToBinary

Func __netcode_CryptCloseProvider($hHandle)
	__Trace_FuncIn("__netcode_CryptCloseProvider", $hHandle)
	DllCall($__net_hInt_bcryptdll, "int", "BCryptCloseAlgorithmProvider", "handle", $hHandle, "ulong", 0)
	__Trace_FuncOut("__netcode_CryptCloseProvider")
EndFunc   ;==>__netcode_CryptCloseProvider

Func __netcode_CryptStartup()
	__Trace_FuncIn("__netcode_CryptStartup")
	If $__net_hInt_bcryptdll = -1 Then
		$__net_hInt_bcryptdll = DllOpen('bcrypt.dll')
		If $__net_hInt_bcryptdll = -1 Then
			__Trace_Error(1, 0, "Couldnt Open bcrypt.dll")
			Return SetError(1, 0, __Trace_FuncOut("__netcode_CryptStartup", False))
		EndIf
	EndIf

	If $__net_hInt_hAESAlgorithmProvider = -1 Then
		Local $arCall = DllCall($__net_hInt_bcryptdll, "int", "BCryptOpenAlgorithmProvider", _
				"handle*", 0, _
				"wstr", $__net_sInt_AESCryptionAlgorithm, _
				"wstr", $__net_sInt_CryptionProvider, _
				"ulong", 0 _
				)
		$__net_hInt_hAESAlgorithmProvider = $arCall[1]

		; Set block chaining mode
		Local $arCheck = DllCall($__net_hInt_bcryptdll, "int", "BCryptSetProperty", _
				"handle", $__net_hInt_hAESAlgorithmProvider, _
				"wstr", 'ChainingMode', _
				"wstr", 'ChainingModeCBC', _
				"ulong", BinaryLen('ChainingModeCBC'), _
				"ulong", 0 _
				)
	EndIf

	If $__net_hInt_hRSAAlgorithmProvider = -1 Then
		$arCall = DllCall($__net_hInt_bcryptdll, "int", "BCryptOpenAlgorithmProvider", _
				"handle*", 0, _
				"wstr", $__net_sInt_RSACryptionAlgorithm, _
				"wstr", $__net_sInt_CryptionProvider, _
				"ulong", 0 _
				)
		$__net_hInt_hRSAAlgorithmProvider = $arCall[1]
	EndIf

	If $__net_hInt_hSHAAlgorithmProvider = -1 Then
		$arCall = DllCall($__net_hInt_bcryptdll, "int", "BCryptOpenAlgorithmProvider", _
				"handle*", 0, _
				"wstr", $__net_sInt_SHACryptionAlgorithm, _
				"wstr", $__net_sInt_CryptionProvider, _
				"ulong", 0 _
				)
		$__net_hInt_hSHAAlgorithmProvider = $arCall[1]
	EndIf

	If $__net_hInt_ntdll = -1 Then
		$__net_hInt_ntdll = DllOpen('ntdll.dll')
	EndIf

	If $__net_hInt_cryptdll = -1 Then
		$__net_hInt_cryptdll = DllOpen('Crypt32.dll')
	EndIf

	Return __Trace_FuncOut("__netcode_CryptStartup", True)


	; anti au3check error
	If False = True Then __netcode_Au3CheckFix($arCheck)
EndFunc   ;==>__netcode_CryptStartup

Func __netcode_CryptShutdown()
	__Trace_FuncIn("__netcode_CryptShutdown")
	If $__net_hInt_hAESAlgorithmProvider <> -1 Then
		__netcode_CryptCloseProvider($__net_hInt_hAESAlgorithmProvider)
		$__net_hInt_hAESAlgorithmProvider = -1
	EndIf

	If $__net_hInt_hRSAAlgorithmProvider <> -1 Then
		__netcode_CryptCloseProvider($__net_hInt_hRSAAlgorithmProvider)
		$__net_hInt_hRSAAlgorithmProvider = -1
	EndIf

	If $__net_hInt_hSHAAlgorithmProvider <> -1 Then
		__netcode_CryptCloseProvider($__net_hInt_hSHAAlgorithmProvider)
		$__net_hInt_hSHAAlgorithmProvider = -1
	EndIf

	If $__net_hInt_bcryptdll <> -1 Then
		DllClose($__net_hInt_bcryptdll)
		$__net_hInt_bcryptdll = -1
	EndIf

	If $__net_hInt_ntdll <> -1 Then
		DllClose($__net_hInt_ntdll)
		$__net_hInt_ntdll = -1
	EndIf

	If $__net_hInt_cryptdll <> -1 Then
		DllClose($__net_hInt_cryptdll)
		$__net_hInt_cryptdll = -1
	EndIf
	__Trace_FuncOut("__netcode_CryptShutdown")
EndFunc   ;==>__netcode_CryptShutdown

; Stripped down CryptoNG UDF by TheXman@autoitscript.com
#EndRegion ===========================================================================================================================

#cs
; lznt functions from xxxxxxxxxxxxxxxxxxxxxxxxxx idk know actually
; marked for recoding
Func __netcode_lzntdecompress($bbinary)
	Local $tinput = DllStructCreate("byte[" & BinaryLen($bbinary) & "]")
	DllStructSetData($tinput, 1, $bbinary)

;~ 	Local $tbuffer = DllStructCreate("byte[" & 0x40000 & "]") ; 0x40000 taken from UEZ - File to Base64 String Code Generator
	Local $tbuffer = DllStructCreate("byte[" & $__net_nMaxRecvBufferSize & "]") ; since our packets will never exceed this anyway.. could change when i add the big packet feature

	Local $a_call = DllCall($__net_hInt_ntdll, "int", "RtlDecompressBuffer", "ushort", 2, "ptr", DllStructGetPtr($tbuffer), "dword", DllStructGetSize($tbuffer), "ptr", DllStructGetPtr($tinput), "dword", DllStructGetSize($tinput), "dword*", 0)
	If @error OR $a_call[0] Then
		Return SetError(1, 0, "")
	EndIf

	Return Binary(BinaryToString(BinaryMid(DllStructGetData($tbuffer, 1), 1, $a_call[6])))

;~ 	Local $toutput = DllStructCreate("byte[" & $a_call[6] & "]", DllStructGetPtr($tbuffer))
;~ 	Return SetError(0, 0, Binary(BinaryToString(DllStructGetData($toutput, 1))))
EndFunc

Func __netcode_lzntcompress($vinput, $icompressionformatandengine = 2)
	If NOT ($icompressionformatandengine = 258) Then
		$icompressionformatandengine = 2
	EndIf

	Local $tinput = DllStructCreate("byte[" & BinaryLen($vinput) & "]")
	DllStructSetData($tinput, 1, $vinput)

	Local $a_call = DllCall($__net_hInt_ntdll, "int", "RtlGetCompressionWorkSpaceSize", "ushort", $icompressionformatandengine, "dword*", 0, "dword*", 0)
	If @error OR $a_call[0] Then
		Return SetError(1, 0, "")
	EndIf

	Local $tworkspace = DllStructCreate("byte[" & $a_call[2] & "]")
	Local $tbuffer = DllStructCreate("byte[" & 16 * DllStructGetSize($tinput) & "]")
	Local $a_call = DllCall($__net_hInt_ntdll, "int", "RtlCompressBuffer", "ushort", $icompressionformatandengine, "ptr", DllStructGetPtr($tinput), "dword", DllStructGetSize($tinput), "ptr", DllStructGetPtr($tbuffer), "dword", DllStructGetSize($tbuffer), "dword", 4096, "dword*", 0, "ptr", DllStructGetPtr($tworkspace))

	If @error OR $a_call[0] Then
		Return SetError(2, 0, "")
	EndIf

	Return BinaryMid(DllStructGetData($tbuffer, 1), 1, $a_call[7])

;~ 	Local $toutput = DllStructCreate("byte[" & $a_call[7] & "]", DllStructGetPtr($tbuffer))
;~ 	Return SetError(0, 0, DllStructGetData($toutput, 1))
EndFunc
#ce

Func __netcode_TCPCloseSocket($hSocket)
	__Trace_FuncIn("__netcode_TCPCloseSocket", $hSocket)

	If $__net_hWs2_32 = -1 Then $__net_hWs2_32 = DllOpen('Ws2_32.dll')
	Local $iRet = DllCall($__net_hWs2_32, "int", "shutdown", "uint", $hSocket, "int", 2)
	If @error Then
		SetError(1, @error)
		Return __Trace_FuncOut("__netcode_TCPCloseSocket", False)
	EndIf
	If $iRet[0] <> 0 Then
		SetError(2, __netcode_WSAGetLastError())
		Return __Trace_FuncOut("__netcode_TCPCloseSocket", False)
	EndIf
	Return __Trace_FuncOut("__netcode_TCPCloseSocket", True)
EndFunc   ;==>__netcode_TCPCloseSocket

Func __netcode_MakeLong($LoWord, $HiWord)
	Return BitOR($HiWord * 0x10000, BitAND($LoWord, 0xFFFF))
EndFunc   ;==>__netcode_MakeLong

Func __netcode_HiWord($Long)
	Return BitShift($Long, 16)
EndFunc   ;==>__netcode_HiWord

Func __netcode_LoWord($Long)
	Return BitAND($Long, 0xFFFF)
EndFunc   ;==>__netcode_LoWord

Func __netcode_Debug($sText)
	ConsoleWrite($sText & @CRLF)
EndFunc   ;==>__netcode_Debug

Func __netcode_RandomPW($nLenght = 12, $sChoice = '5', $sPass = '')
	__Trace_FuncIn("__netcode_RandomPW", "$nLenght", "$sChoice", "$sPass")
	Local Static $key[5]
	Local $i
	If $key[0] = "" Then
		$key[0] = '1234567890'
		$key[1] = __netcode_StringRepeat($key[0], 4) & 'abcdefghijklmnopqrstuvwxyz'
		$key[2] = $key[1] & 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
		$key[3] = $key[2] & 'öäüÖÄÜß'
		$key[4] = $key[3] & '@€µ²³°!§$%&/()=<>|,.-;:_#+*~?\' & Chr(34) & Chr(39)
	EndIf

	For $i = 1 To $nLenght
		__netcode_SRandomTemporaryFix()
		$sPass &= StringMid($key[$sChoice - 1], Random(1, StringLen($key[$sChoice - 1]), 1), 1)
	Next
	Return __Trace_FuncOut("__netcode_RandomPW", $sPass)
EndFunc   ;==>__netcode_RandomPW

Func __netcode_StringRepeat($sString, $nCount)
	__Trace_FuncIn("__netcode_StringRepeat", $sString, $nCount)
	Local $sRet = ''
	For $i = 1 To $nCount
		$sRet &= $sString
	Next

	Return __Trace_FuncOut("__netcode_StringRepeat", $sRet)
EndFunc   ;==>__netcode_StringRepeat

; ignore this func, its never called, but used to fix au3check failing with "warning: $var: declared, but not used in func."
; while the $var is in reality used with Eval() and therefore the warning is wrong.
Func __netcode_Au3CheckFix(ByRef $vVar)
	Return $vVar + 1
EndFunc

; this func patches a security issue mentioned in 0.1.5. SRandom affects Random in a way that it is possible to calculate the used
; password for the packet encryption. This is possible through back calculating the used Seed through the information send in the 'auth' stage.
; Sadly it isnt possible to reset SRandom() to a non Seed, so to combat said issue we create an array with 1000 elements with random numbers
; before SRandom ever is called here. SRandom can be set to these random number right before the UDF creates a password for a session key.
; The issue is faced further once the Diffie Hellman Key exchange is implemented.
; This function is used before each Random call in __netcode_RandomPW(). So to guess the password by using the SRandom seed is going to take
; as long as cracking the password itself, if not longer.
Func __netcode_SRandomTemporaryFix()
	Local Static $arBuffer[0], $nIndex = 0
	If UBound($arBuffer) = 0 Then
		ReDim $arBuffer[1000]
		For $i = 0 To 999
			For $iS = 1 To 18
				$arBuffer[$i] &= Random(0, 9, 1)
			Next
			$arBuffer[$i] = Number($arBuffer[$i])

			if Random(0, 1, 1) = 1 Then $arBuffer[$i] *= -1
		Next
	EndIf
	SRandom($arBuffer[$nIndex])
	$arBuffer[$nIndex] += 1

	$nIndex += 1
	if $nIndex > 999 Then $nIndex = 0

	;123456789012345678
;~ 	_ArrayDisplay($arBuffer)
EndFunc

; This is a part of the _storageS.au3 UDF - not public

Func _storageS_Overwrite($ElementGroup, $Element0, $Element1)
;~ 	Local $sVarName = "__storageS_" & StringToBinary($ElementGroup & $Element0)
	Local $sVarName = "__storageS_" & $ElementGroup & $Element0
	; Not binarizing it added about 0.5 mb/s. However it makes the functions breakable when illegal characters are used.
	; Illegal characters are all chars which wouldnt work to create a var, like a space or symbols like <, >, =, etc..

	; we wont declare vars if $Element1 is False because _storageS_Read() always returns False and @error 1 on undeclared vars
	If $Element1 == False And Not IsDeclared($sVarName) Then Return 1
	If Not IsDeclared($sVarName) Then __storageS_AddGroupVar($ElementGroup, $Element0)

	Return Assign($sVarName, $Element1, 2)
EndFunc   ;==>_storageS_Overwrite

Func _storageS_Append($ElementGroup, $Element0, $Element1)
;~ 	Local $sVarName = "__storageS_" & StringToBinary($ElementGroup & $Element0)
	Local $sVarName = "__storageS_" & $ElementGroup & $Element0

	If Not IsDeclared($sVarName) Then Return _storageS_Overwrite($ElementGroup, $Element0, $Element1)

	Return Assign($sVarName, Eval($sVarName) & $Element1, 2)
EndFunc   ;==>_storageS_Append

Func _storageS_Read($ElementGroup, $Element0)
;~ 	Local $sVarName = "__storageS_" & StringToBinary($ElementGroup & $Element0)
	Local $sVarName = "__storageS_" & $ElementGroup & $Element0

	If Not IsDeclared($sVarName) Then Return SetError(1, 0, False)
	Return Eval($sVarName)
EndFunc   ;==>_storageS_Read

Func __storageS_AddGroupVar($ElementGroup, $Element0)
	If $ElementGroup = "StorageS" Then Return

	Local $arGroupVars = _storageS_Read("StorageS", $ElementGroup)
	If Not IsArray($arGroupVars) Then
		Local $arGroupVars[0]
	EndIf

	Local $nArSize = UBound($arGroupVars)

	ReDim $arGroupVars[$nArSize + 1]
	$arGroupVars[$nArSize] = $Element0
	_storageS_Overwrite("StorageS", $ElementGroup, $arGroupVars)
EndFunc   ;==>__storageS_AddGroupVar

Func _storageS_TidyGroupVars($ElementGroup)
	Local $arGroupVars = _storageS_Read("StorageS", $ElementGroup)
	If Not IsArray($arGroupVars) Then Return

	For $i = 0 To UBound($arGroupVars) - 1
		_storageS_Overwrite($ElementGroup, $arGroupVars[$i], Null)
	Next

	_storageS_Overwrite("StorageS", $ElementGroup, Null)
EndFunc   ;==>_storageS_TidyGroupVars

Func _storageS_DisplayGroupVars($ElementGroup)
	Local $arGroupVars = _storageS_Read("StorageS", $ElementGroup)
	If Not IsArray($arGroupVars) Then Return

	Local $nArSize = UBound($arGroupVars)
	Local $arGroupVars2D[$nArSize][3]
	Local $vData

	For $i = 0 To $nArSize - 1
		$arGroupVars2D[$i][0] = $arGroupVars[$i]

		$vData = _storageS_Read($ElementGroup, $arGroupVars[$i])
		$arGroupVars2D[$i][1] = VarGetType($vData)
		$arGroupVars2D[$i][2] = $vData
	Next

	Return $arGroupVars2D
EndFunc   ;==>_storageS_DisplayGroupVars

; Tracer Functions for debug and error managements

Func __Trace_FuncIn($sFuncName, $p1 = Default, $p2 = Default, $p3 = Default, $p4 = Default, $p5 = Default, $p6 = Default)
	If Not $__net_bTraceEnable Then Return

	Local $nArSize = UBound($__net_arTraceLadder)
	ReDim $__net_arTraceLadder[$nArSize + 1][2]

	$__net_arTraceLadder[$nArSize][0] = $sFuncName
	If $__net_bTraceEnableTimers Then $__net_arTraceLadder[$nArSize][1] = TimerInit()

	__Trace_LogFunc($p1, $p2, $p3, $p4, $p5, $p6)
EndFunc   ;==>__Trace_FuncIn

Func __Trace_FuncOut($sFuncName, $vReturn = False)
	If Not $__net_bTraceEnable Then Return $vReturn

	Local $nArSize = UBound($__net_arTraceLadder)

;~ 	ConsoleWrite($__net_arTraceLadder[$nArSize - 1][0] & @CRLF)
	If $__net_arTraceLadder[$nArSize - 1][0] <> $sFuncName Then Exit MsgBox(16, "Error", "Trace Error - Exiting" & @CRLF & $__net_arTraceLadder[$nArSize - 1][0] & " <> " & $sFuncName)

	If $__net_bTraceEnableTimers Then __Trace_LogFunc(Default, Default, Default, Default, Default, Default, TimerDiff($__net_arTraceLadder[$nArSize - 1][1]))

	ReDim $__net_arTraceLadder[$nArSize - 1][2]

	Return $vReturn
EndFunc   ;==>__Trace_FuncOut

Func __Trace_Error($nError, $nExtended, $sErrorDescription = "", $sExtendedDescription = "", $vAdditionalData = Null, $vAdditionalData2 = Null)
	If Not $__net_bTraceEnable Then Return

	Local $nArSize = UBound($__net_arTraceErrors)

	If $__net_bTraceLogErrorSaveToArray Then
		; date | time | funcname | error code | extended code | error desc | extended desc | additional data | additional data
		ReDim $__net_arTraceErrors[$nArSize + 1][UBound($__net_arTraceErrors, 2)]
		$__net_arTraceErrors[$nArSize][0] = @YEAR & "/" & @MON & "/" & @MDAY
		$__net_arTraceErrors[$nArSize][1] = @HOUR & ":" & @MIN & ":" & @SEC & "." & @MSEC
		$__net_arTraceErrors[$nArSize][2] = $__net_arTraceLadder[UBound($__net_arTraceLadder) - 1][0]
		$__net_arTraceErrors[$nArSize][3] = $nError
		$__net_arTraceErrors[$nArSize][4] = $nExtended
		$__net_arTraceErrors[$nArSize][5] = $sErrorDescription
		$__net_arTraceErrors[$nArSize][6] = $sExtendedDescription
		$__net_arTraceErrors[$nArSize][7] = $vAdditionalData
		$__net_arTraceErrors[$nArSize][8] = $vAdditionalData2
	EndIf

	__Trace_LogError($nError, $nExtended, $sErrorDescription, $sExtendedDescription)
EndFunc   ;==>__Trace_Error

Func __Trace_LogFunc($p1, $p2, $p3, $p4, $p5, $p6, $nTimerDiff = False)
	If Not $__net_bTraceLogEnable Then Return

	Local $sLog = ""
	Local $nArSize = UBound($__net_arTraceLadder)
	Local $sEvalParam

	For $i = 1 To $nArSize - 1
		$sLog &= @TAB
	Next

;~ 	$sLog &= $__net_arTraceLadder[$nArSize - 1] & "()"
	$sLog &= $__net_arTraceLadder[$nArSize - 1][0] & "("

	For $i = 1 To 6
		$sEvalParam = Eval("p" & $i)
		If $sEvalParam = Default Then
			If $i <> 1 Then $sLog = StringTrimRight($sLog, 2)
			ExitLoop
		EndIf

		$sLog &= $sEvalParam
		If $i <> 6 Then $sLog &= ', '
	Next

	$sLog &= ")"

	If $nTimerDiff Then $sLog &= " Took: " & Round($nTimerDiff, 4) & " ms"
	ConsoleWrite($sLog & @CRLF)

	Return

	; anti au3check error
	If False = True Then
		__netcode_Au3CheckFix($p1)
		__netcode_Au3CheckFix($p2)
		__netcode_Au3CheckFix($p3)
		__netcode_Au3CheckFix($p4)
		__netcode_Au3CheckFix($p5)
		__netcode_Au3CheckFix($p6)
	EndIf
EndFunc   ;==>__Trace_LogFunc

Func __Trace_LogError($nError, $nExtended, $sErrorDescription, $sExtendedDescription)
	If Not $__net_bTraceLogErrorEnable Then Return

	Local $sError = ""
	Local $nArSize = UBound($__net_arTraceLadder)

	if Not @Compiled Then $sError &= '! '

	If $__net_bTraceLogEnable Then
		For $i = 1 To $nArSize - 1
			$sError &= @TAB
		Next
	EndIf

;~ 	$sError &= $__net_arTraceLadder[$nArSize - 1][0] & "() Err: " & $nError & " - Ext: " & $nExtended & " - '" & $sErrorDescription & "' - '" & $sExtendedDescription & "'"
	$sError &= $__net_arTraceLadder[$nArSize - 1][0] & "() Err: " & $nError & " - Ext: " & $nExtended
	if $sErrorDescription <> "" Or $sExtendedDescription <> "" Then $sError &= " -"
	if $sErrorDescription <> "" Then $sError &= " Err: '" & $sErrorDescription & "'"
	if $sExtendedDescription <> "" Then $sError &= " Ext: '" & $sExtendedDescription & "'"
	ConsoleWrite($sError & @CRLF)
EndFunc   ;==>__Trace_LogError
