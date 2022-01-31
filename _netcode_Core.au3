;~ #AutoIt3Wrapper_AU3Check_Parameters=-w 1 -w 2 -w 3 -w 4 -w 5 -w 6 ; shows errors that arent errors - i used __netcode_Au3CheckFix() to fix
#include-once
#include <Array.au3> ; For development of this UDF
;~ Opt("MustDeclareVars", 1) ; nice fature to find missing variable declarations
#cs

	Official Repository
		https://github.com/OfficialLambdax/_netcode_Core-UDF

	Terminology

		Parent Sockets and Client Sockets
			A parent is a socket that originates from _netcode_TCPListen(). Clients are seperated into Accept Clients and Connect Clients.
			Accept clients originate from TCPAccept (which is called within _netcode_Loop()) and Connect clients which come from _netcode_TCPConnect.
			_netcode treats accept and connect clients similiar but slightly different in some cases.
			Each Client requires to have a parent. A Accept client is bound to the TCPListen parent that it is accepted from.
			A connect client is bound to a fictive socket named "000".

			You can get the type of the socket with _netcode_CheckSocket().

			The fictive socket "000" is created whenever a new connect client socket is created and deleted once there are none left.

			With _netcode_Loop() you can either loop a parent, in which case every accept client of it is looped. Or you can loop
			an individual Accept or Connect client. Additionally you can also Loop the "000" socket, in which case all Connect clients
			are looped.

		Known and Unknown Sockets
			_netcode only handles sockets that are known to it. All sockets created by _netcode or that are bind to it with _netcode_BindSocket()
			are managed and info about them can be retrieved. If a socket is created outside of _netcode then _netcode wont be able to give any
			information about it. That is also true if the socket is released from _netcode with _netcode_ReleaseSocket().
			You can use _netcode_CheckSocket() to check if a socket is known or not and of what type it is (1 = parent, 2 = client, 0 = unknown to _netcode).

		Socket Holding
			Sockets can be set OnHold with _netcode_SetSocketOnHold(). _netcode will pause executing packets from Sockets that are OnHold.
			To be clear: Just not be executed, _netcode will still receive, unpack and store incoming packets. However only until the Buffer
			limit is reached. Every packet exceeding the buffer will be voided. But the sender wont overflow the buffer since it calculates the status
			of the receivers buffer.

		Active and Inactive Sockets
			Inactive sockets are Sockets which do not transfer data at the moment. Active sockets are those where data is received from or data is send to currently.
			So once data is in the recv or send buffer the Inactive becomes a active and once not it becomes inactive again. Inactive sockets are very fast to handle.

			Generally _netcode_Loop() checks with the __netcode_SocketSelect() function if any of the Sockets, to be looped, have anything in the recv Buffer.
			Said function will simply ask windows if data got received. Only those sockets where that check is true are then be run with _netcode_RecvManageExecute().
			This function will then, like the name says, empty the windows own buffer, unpack the received data and lastly execute it.

			The 'select' dll call is the key which rised the performance within _netcode. Because of it only sockets that have anything received are managed.
			Every else is ignored, which dramatically improved loop time. Also because of it _netcode is capable to support thousands of inactive sockets.
			Nearly only active sockets actually take performance.

		Staging
			_netcode uses so called Stages. Each and every incomming connection needs to stage through several layers before it is possible to interact with it or
			before the clients are able to communicate with the events.
			Within these stages a session key is handshaked, options are synced, the optional user login is done and more. A connect client for example always inherits
			the options from the server and obviously that needs to be done at some point. _netcode does all of that automatically. If you set or overwrote the
			default 'connection' event then you get the last, successfully executed stage, told with the second param $sStage.

			Stages as of version v0.1.5.21 (to be overhauled)

				$sStage = 'connect' (connection stage)
					Will be thrown once a new socket is connected.

				$sStage = 'auth' (auth stage)

				$sStage = 'presyn' (presyn stage)

				$sStage = 'handshake' (handshake stage)

				$sStage = 'syn' (syn stage)

				$sStage = 'user' (user stage)

				$sStage = 'ready' (ready stage)

				$sStage = 'netcode' (netcode stage)
					Once this stage is reached both the server and client can use _netcode_TCPSend() and execute events on each other.



		Events
			_netcode Supports 2 different types of Events. Callback Events and Non Callback Events. The difference of them is described below.
			Besides this _netcode has so called Default Events and Socket specfic events.

			Default Events are useable by each and every Socket. _netcode_PresetEvent() is the function for that.

			Socket specific events are limited to the Socket they are bind to.
			If you set events to a parent with _netcode_SetEvent() then every Accept Client, once created, get all parent events bind to themself.
			If you set one or more events with _netcode_SetEvent() to a Accept or Connect Client, then only this Client will have these Events.

			Socket specific Events are priotised over Default events.
			_netcode simply checks for a socket specifc event first and then for a default event. If the event is not set
			when the packets are processed and executed then the data is simply vented and a Tracer error thrown.

			Events are case-sensitive.
			So if you set a event like _netcode_SetEvent(hSocket, "MyEvent", "_Event_MyEvent") then you can only call it by using
			_netcode_TCPSend($hSocket, "MyEvent") and not with "myevent" or "Myevent" etc.

			IMPORTANT NOTICE
			Do not, and i repeat do not, call _netcode_Loop(), _netcode_RecvManageExecute() or _netcode_UseNonCallbackEvent() within a Event. This can and will trigger recursion crash's.
			_netcode_Loop()
				_Event_MyEvent()
					_netcode_Loop()
						_Event_MyEvent()
							_netcode_Loop()
								.... n

			This also applies to large data sends that would trigger a Flood Prevention within _netcode_TCPSend().
			So if you are going to write a complex script then do large data sends outside of the event, to prevent recursion issues.

			; ~ todo write appropriate examples

		Callback Event
			Set with _netcode_SetEvent($hSocket, "MyCallbackEvent", "_Event_MyCallbackEvent")

			Callback events are tied to Functions of your own. So if you have set the "MyCallbackEvent" on lets say the server like above and then send data to it
			from the client with _netcode_TCPSend($hSocket, "MyCallbackEvent", "example data") then your Function "_Event_MyCallbackEvent" will be called with 2 parameters,
			once the server received and processed the packet.

			Your Callback function ALWAYS has to have atleast one parameter
				Func _Event_MyCallbackEvent(Const $hSocket)

			This Event then can easiely be called with _netcode_TCPSend($hSocket, "MyCallbackEvent")

			If you use the $sData param in _netcode_TCPSend() without _netcode_sParams() or .._exParams() then your Callback function needs to look like this
				Func _Event_MyCallbackEvent(Const $hSocket, $sData)

			_netcode_TCPSend($hSocket, "MyCallbackEvent", "your data")


			Your Callback Function can have up to 16 parameters
				Func _Event_MyCallbackEvent(Const $hSocket, $param1, $param2, $param3..... $param16)

			In order to send up to 16 parameters you have to use _netcodes own Serializer that comes with 2 Feature sets.
				_netcode_sParams()
				_netcode_exParams()
				More information available in the Serialization point.


			Your Callback Function parameter amount always need to match the amount of params that you send. Otherwise the Function Call() will fail and the data is rejected.

		Non Callback Event
			Set with _netcode_SetEvent($hSocket, "MyNonCallbackEvent")

			Non Callback events are not tied to Functions of your own. The data send to it can be read with _netcode_GetEventData().
			The general idea behind Non Callback events is to make it possible to get data like how you would with a simple Function call.

			So if you have set a non callback event with _netcode_SetEvent($hSocket, "MyNonCallbackEvent")
			then you can either use _netcode_GetEventData() to check for data for the Event or you can use _netcode_UseNonCallbackEvent().

			_netcode_UseNonCallbackEvent() will send data to the given event of the receiver and will wait for a response on your non callback event
			and return it then.

			Local $arEventResponse = _netcode_UseNonCallbackEvent($hSocket, "MyNonCallbackEvent", "SendMyRequestToThisEventOnTheReceiversEnd", "OptionalData")

			Both _netcode_GetEventData() and _netcode_UseNonCallbackEvent() will return a CallArgArray, which would usually be used for Calling the Event Function.

			[0] = "CallArgArray"
			[1] = $hSocket
			[2] = response data
			[.]
			[.]
			[18] = up to 16 params

			So Non callback Events are also compatible with _netcode_sParams() and .._exParams().

		Serialization
			_netcode features two Serializers _netcode_sParams() aka Simple parameters and _netcode_exParams() aka extended parameters.

			The Simple params serializer is faster then the Extended params. But exParams provides Variable Type reconstruction.

			AS OF NOW exParams is not implemented !

			Both serializers convert the given params into a String which can be send with _netcode_TCPSend().
			Like _netcode_TCPSend($hSocket, "MyEvent", _netcode_sParams($param1, $param2, $param3))
			Within the Packet Execution the serialized data is then deserialized.

			So you will get exactly, in your Event function, what you have send.

			Both serializers support Arrays of any size. Also 2 Dimensional.

			Objects are not supported.

			If you want to add your own Serialization then you can do that.
			_netcode_TCPSend($hSocket, "MyEvent", _Serialize($data))
			and in your event function simply
			$data = _Deserialize($data)


		Tracer
			The Tracer is a debug feature. It Traces the whole _netcode code execution and will consolewrite and log errors that might happend.
			So if your script doesnt work as it should then try setting $__net_bTraceEnable = True and $__net_bTraceLogErrorEnable = True
			The Tracer also has the ability to log every function call to the console. $__net_bTraceLogEnable = True

			Overall the Tracer, if enabled, will take some performance but is great to find issues and bugs. A misspelled eventname for example
			is easiely detectable with it.

			Errors and Warning are printed in Red if you run your script within SciTE.



	Known Bugs
		Mayor
			- Unlikely to happen. _netcodes own packet safety is currently not working. The light weight feature is made to fix packet corruption,
			packet loss or misorders. Currently in such an event _netcode will simply disconnect the client. The disconnect is on purpose, because otherwise a
			memory leak will happen. The bug is further described in the changelog at v0.1.5.10. The bug is unlikely to happen because packet corruptions or loss
			is very rare.

		Minor
			- Sending special characters that cannot be converted with StringToBinary() get corrupted. To prevent this from happening, either
			enable encryption or convert the string yourself with StringToBinary(data, 4) when you send the data and revert the conversion in your event.
			The bug is further described in the changelog at v0.1.5.10


	Remarks

		Stripping
			use #AutoIt3Wrapper_Au3stripper_OnError=ForceUse in your Script and add all Event Functions to a Anti Stripping function.
			See __netcode_EventStrippingFix() for an example.

			~ todo Create a seperate document for this


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

; The UDF checks once a day if its up to date, toggle to False if you dont want that
; this toggle also affects addons, its global for all _netcode elements.
Global $__net_bCheckForUDFUpdate = True

; maximum buffer size
Global $__net_nMaxRecvBufferSize = 1048576 * 5

; the default recv len
Global $__net_nDefaultRecvLen = 1048576 * 0.25 ; has to be smaller then $__net_nMaxRecvBufferSize

; __netcode_RecvPackages() will never take longer then this timeout is set to
Global $__net_nTCPRecvBufferEmptyTimeout = 20 ; ms

; Set default Seed. Ignore for now, it is not fully implemented yet
Global $__net_nNetcodeStringDefaultSeed = Number("50853881441621333029") ; %NotSet% - numbers only - note change to Double

; set to True if you want the _netcode_sParam() to binarize all data. Will slow down the function by alot.
Global $__net_bParamSplitBinary = False

; will be obsolete. The client will no longer send the plain password to the server in the future but its hash and the max len will be set to the
; default hash len.
Global $__net_nMaxPasswordLen = 30 ; max password len for the User Stage. If the StringLen is > this then it will deny the login

; disable to use the unstable socket select packet confirmation instead of the receivers confirmation packet.
; will not improve performance, but reduces receivers load and its network usage. If False this Option will render certain packet safety options useless.
; packet loss is a certain effect if _netcode_SetSocketOnHold() is used. Packet resend duo to packet loss or corruption will not work either until the packet
; safety is overhauled. Both the server and the clients need this option to be the same, it is not synced because its a global setting.
Global $__net_bPacketConfirmation = True

; ===================================================================================================================================================
; Tracer

; enables the Tracer. Will slow down the UDF by about 5 %, but needs to be True if you want to use any of the options below.
; never toggle THIS option on the fly in your script or it might hard crash. All other Tracer sub options can be toggled anytime.
Global $__net_bTraceEnable = False

; will log every call of a UDF function to the console in a ladder format. Will massively decrease the UDF speed because it floods the console.
Global $__net_bTraceLogEnable = False

; will log errors and extendeds to the console and their describtions. very usefull while developing
Global $__net_bTraceLogErrorEnable = True

; will save all errors, its extendeds and further information to an array. Array can be looked at with _ArrayDisplay($__net_arTraceErrors)
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
Global $__net_arSockets[0] ; all known parent sockets
Global $__net_hWs2_32 = -1 ; Ws2_32.dll handle
Global $__net_sAuthNetcodeString = 'iT0325873JoWv5FVOY3' ; this string indicates to the server that a _netcode client is connecting
Global $__net_sAuthNetcodeConfirmationString = '09iCKqRh80D27' ; the server then responds with this, confirming to the client that it is a _netcode server.
Global $__net_sPacketBegin = '8NoguKX5UB' ; always 10 bytes long
Global $__net_sPacketInternalSplit = 'c3o8197sT6' ; 10 bytes
Global $__net_sPacketEnd = 'YWy44X03PF' ; 10 bytes
Global $__net_arDefaultEventsForEachNewClientSocket[0][2] ; contains all default events. Eventname | Callback
Global $__net_sParamSplitSeperator = 'eUwc99H4Vc' ; 10 bytes
Global $__net_sParamIndicatorString = 'NDs2GA59Wj' ; 10 bytes
Global $__net_sSerializationIndicator = '4i8lwnpc6w' ; 10 bytes - keep them always exactly 10 bytes long
Global $__net_sSerializeArrayIndicator = '6v934Y71fS' ; 10 bytes
Global $__net_sSerializeArrayYSeperator = '152b7l27E6' ; 10 bytes
Global $__net_sSerializeArrayXSeperator = '3615RW0117' ; 10 bytes
Global $__net_arPacketSendQue[0] ; contains all sockets that have something in the send buffer
Global $__net_arPacketSendQueWait[0] ; old variable used for a earlier send quo method
Global $__net_arPacketSendQueIDWait[0] ; contains all sockets where the send buffer was just send. Used to check when to clear the safetybuffer if $__net_bPacketConfirmation = False
Global $__net_arGlobalIPList[0] ; unused - will contain a ip list that is either white or blacklist. Incoming connection
Global $__net_bGlobalIPListIsWhitelist = False
Global $__net_hInt_bcryptdll = -1 ; bcrypt.dll handle
Global $__net_hInt_ntdll = -1 ; nt.dll handle
Global $__net_hInt_cryptdll = -1 ; crypt.dll handle
Global $__net_hInt_hAESAlgorithmProvider = -1 ; AES provider handle
Global $__net_hInt_hRSAAlgorithmProvider = -1 ; RSA provider handle
Global $__net_hInt_hSHAAlgorithmProvider = -1 ; SHA provider handle
Global $__net_nInt_CryptionIterations = 1000 ; i have to research the topic of Iterations
Global $__net_nInt_RecursionCounter = -1 ; starting at -1
Global $__net_bNetcodeStarted = False
__netcode_SRandomTemporaryFix()

; ===================================================================================================================================================
; Constants
Global Const $__net_sInt_AESCryptionAlgorithm = 'AES' ; todo ~ shouldnt change anyway, vars could be removed
Global Const $__net_sInt_RSACryptionAlgorithm = 'RSA'
Global Const $__net_sInt_SHACryptionAlgorithm = 'SHA256'
Global Const $__net_vInt_RSAEncPadding = 0x00000002
Global Const $__net_sInt_CryptionIV = Binary("0x000102030405060708090A0B0C0D0E0F") ; i have to research this topic
Global Const $__net_sInt_CryptionProvider = 'Microsoft Primitive Provider' ; and this
Global Const $__net_sNetcodeVersion = "0.1.5.25"
Global Const $__net_sNetcodeVersionBranch = "Concept Development" ; Concept Development | Early Alpha | Late Alpha | Early Beta | Late Beta
Global Const $__net_sNetcodeOfficialRepositoryURL = "https://github.com/OfficialLambdax/_netcode_Core-UDF"
Global Const $__net_sNetcodeOfficialRepositoryChangelogURL = "https://github.com/OfficialLambdax/_netcode_Core-UDF/blob/main/%23changelog%20concept%20stage.txt"
Global Const $__net_sNetcodeVersionURL = "https://raw.githubusercontent.com/OfficialLambdax/_netcode-UDF/main/versions/_netcode_Core.version"
Global Const $__net_sNetcodeHKCUPath = "HKCU\SOFTWARE\_netcode_UDF\"

if $__net_nNetcodeStringDefaultSeed = "%NotSet%" Then __netcode_Installation()
__netcode_EventStrippingFix()
if Not @Compiled Then $__net_bTraceEnable = True

; ===================================================================================================================================================
; User Defined Functions below


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Startup
; Description ...: Starts up _netcode. Needs to be called before you use any of the Functions in this UDF
; Syntax ........: _netcode_Startup()
; Parameters ....: None
; Return values .: None
; Modified ......:
; Remarks .......:
; ===============================================================================================================================
Func _netcode_Startup()
	__Trace_FuncIn("_netcode_Startup")
	__netcode_Init()
	__Trace_FuncOut("_netcode_Startup")
EndFunc   ;==>_netcode_Startup


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Shutdown
; Description ...: Shutsdown _netcode and closes every known socket.
; Syntax ........: _netcode_Shutdown()
; Parameters ....: None
; Return values .: None
; Modified ......:
; Remarks .......: With every socket disconnect also the disconnected event will be called.
; ===============================================================================================================================
Func _netcode_Shutdown()
	__Trace_FuncIn("_netcode_Shutdown")
	__netcode_Shutdown()
	__Trace_FuncOut("_netcode_Shutdown")
EndFunc   ;==>_netcode_Shutdown


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Loop
; Description ...: Give either the parent or the client socket. Will loop it. That means that data is send, received, processed and executed
;				   for the specific socket. For parent sockets the function will also Accept a single new incoming connection per loop. If you have multiple
;				   Client sockets coming from TPCConnect then you can use the socket "000". In that case all TCPConnect sockets get looped
;				   after another. "000" is invalid if not a single TCPConnect socket is known.
; Syntax ........: _netcode_Loop(Const $hParent or $hClient)
; Return values .: True 	= If the Socket is valid. False = If the socket is invalid (also if the socket is disconnected).
; Errors ........: 1 		= Socket is unknown right from the beginning
; Modified ......:
; Remarks .......: _netcode is designed to provide performance. You might want to add Sleep() in your code to lower the CPU usage.
;				  The amount of time this function takes is depended on how much active sockets _netcode manages. a thousand inactive take a split of a millisecond.
; ===============================================================================================================================
Func _netcode_Loop(Const $hListenerSocket)
	__Trace_FuncIn("_netcode_Loop", $hListenerSocket)

	$__net_nInt_RecursionCounter += 1

	Local $nSocketIs = 0
	Local $hNewSocket = 0
	Local $bReturn = False
	Local $arClients[0]

	$nSocketIs = __netcode_CheckSocket($hListenerSocket)
	If $nSocketIs = 0 Then
		__Trace_Error(1, 0, "Socket is unknown", "", $hListenerSocket)
		$__net_nInt_RecursionCounter -= 1
		Return SetError(1, 0, __Trace_FuncOut("_netcode_Loop", False)) ; socket is unknown
	EndIf

	if $__net_nInt_RecursionCounter > 1 Then __Trace_Error(0, 0, "FATAL WARNING: Recursion level @ " & $__net_nInt_RecursionCounter & ". Script might crash. See _netcode_SetEvent() Remarks.")

	; work through send quo
	if Not $__net_bPacketConfirmation Then __netcode_SendPacketQuoIDQuerry()
	__netcode_SendPacketQuo()

	; check for pending connections
	__netcode_ParentCheckNonBlockingConnectClients("000")

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
							__netcode_ExecuteEvent($hNewSocket, "connection", 'connect')
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

	$__net_nInt_RecursionCounter -= 1
	Return __Trace_FuncOut("_netcode_Loop", True)

EndFunc   ;==>_netcode_Loop


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_RecvManageExecute
; Description ...: Similiar to _netcode_Loop() but will only receive, process and execute the packets. Is used in various ways within this UDF.
;				   You cannot give a parent socket as $hSocket.
; Syntax ........: _netcode_RecvManageExecute(Const $hSocket[, $hParentSocket = False])
; Parameters ....: $hSocket             - [const] The Socket.
;                  $hParentSocket       - [optional] The parentsocket of $hSocket
; Return values .: False 				= if nothing was done by the function
;				   True 				= if the function received, processed and executed packets (all three)
; Errors ........: 1 					= The socket given with $hSocket is a parent
; Extended ......: 1 					= No data was received
; 				   2 					= The parent socket is set OnHold
; Modified ......:
; Remarks .......: $hParentSocket does not need to be set. But giving it because you were already working with it anyway, results in that the func then doesnt read it.
;					Performance increase is likely none.
; Example .......: No
; ===============================================================================================================================
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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_TCPDisconnect
; Description ...: Will close the given socket and will remove it from _netcode. The "disconnected" Event will be called with it.
; Syntax ........: _netcode_TCPDisconnect(Const $hSocket[, $bForce = False])
; Parameters ....: $hSocket             - [const] The socket.
;                  $bForce              - [optional] Set to True if the given Socket is unknown to _netcode.
; Return values .: True 				= Success - False = Failed
; Modified ......:
; Remarks .......: Unfinished function. _netcode is supposed to become a disconnect quo. This feature is supposed to become usefull to make sure
;				   that the other side actually got the last send data.
; Example .......: No
; ===============================================================================================================================
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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_TCPDisconnectWhenReady
; Description ...: Disconnects the given socket once the safety buffer is empty.
; Syntax ........: _netcode_TCPDisconnectWhenReady(Const $hSocket)
; Parameters ....: $hSocket             - [const] The socket
;				   $nTimeout			- Time in ms. If this time is exceeded then the socket is disconnected.
; Return values .: True					= Success
;				   False				= Socket is unknown
; Modified ......:
; Remarks .......: This is a temporary function and will be replaced with a non blocking technic that is automatically going to be used
;				   with _netcode_TCPDisconnect(). For the time being this function here is just usefull to make sure that the last send
;				   packets are actually executed by the receiver. So that no data loss is happening duo to a too early disconnect.
; Example .......: No
; ===============================================================================================================================
Func _netcode_TCPDisconnectWhenReady(Const $hSocket, $nTimeout = 10000)

	Switch __netcode_CheckSocket($hSocket)

		Case 0
			Return False

		Case 1 ; parent

			; get the clients of this parent
			Local $arClients = __netcode_ParentGetClients($hSocket)

			; for each client
			For $i = 0 To UBound($arClients) - 1

				; disconnect when ready
				_netcode_TCPDisconnectWhenReady($arClients[$i], $nTimeout)

			Next

			; disconnect parent
			_netcode_TCPDisconnect($hSocket)

			Return True

		Case 2 ; client
			Local $hTimer = TimerInit()

			While True

				; if time is above $nTimeout then exitloop
				if TimerDiff($hTimer) > $nTimeout Then ExitLoop

				; check safetbuffersize
				if Number(_storageS_Read($hSocket, '_netcode_SafetyBufferSize')) = 0 Then ExitLoop

				; try to catch 'netcode_internal' packets
				_netcode_RecvManageExecute($hSocket)

				; check if socket is still present
				if Not __netcode_CheckSocket($hSocket) Then Return True
			WEnd

			; finnaly disconnect the client
			_netcode_TCPDisconnect($hSocket)

			Return True


	EndSwitch
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_TCPListen
; Description ...: Creates a parent socket with a set amount of maximum clients
; Syntax ........: _netcode_TCPListen($sPort[, $sIP = '0.0.0.0'[, $nMaxPendingConnections = Default[, $nMaxConnections = 200[,
;                  $bDoNotAddSocket = False]]]])
; Parameters ....: $sPort               - The port to listen too. Can be Int, Number, Double, String.
;                  $sIP                 - [optional] If you want to limit where incomming connections originate from then set this to anything but '0.0.0.0'.
;				   						IPv4 only at the moment.
;                  $nMaxPendingConnections- [optional] Ignore this parameter for now.
;                  $nMaxConnections     - [optional] The maximum amount of Clients this parent is allowed to manage per time.
;				  						  All further incoming connections are disconnected until a spot is free again.
;                  $bDoNotAddSocket     - [optional] Set to True if you do not want _netcode to manage the created listener. _netcode will not know of it
;				   						until you bind it with _netcode_BindSocket().
; Return values .: True					= A socket handle - False = Creating the Parent failed
; Errors ........: 1 					= Could not startup a listener. Port taken? _netcode_Startup() called before?
; Modified ......:
; Remarks .......: The socket created with this Function will be set to be non blocking and the naggle algorhytm will be disabled.
; Example .......: No
; ===============================================================================================================================
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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_TCPConnect
; Description ...: Connects to the given IP and Port either Blocking or non Blocking
; Syntax ........: _netcode_TCPConnect($sIP, $vPort[, $bDontAuthAsNetcode = False[, $sUsername = ""[, $sPassword = ""[,
;                  $bNonBlocking = False[, $nTimeout = 2000]]]]])
; Parameters ....: $sIP                 - The IP to connect to
;                  $vPort               - The port to connect to
;                  $bDontAuthAsNetcode  - [optional] Set to True if you want to call _netcode_AuthToNetcodeServer() yourself
;                  $sUsername           - [optional] If the Server is Usermanaged then enter the Username here
;                  $sPassword           - [optional] If the Server is Usermanaged then enter the Password here
;                  $bNonBlocking        - [optional] Set to True if you want the Connect call to be Non Blocking. See Remarks.
;                  $nTimeout            - [optional] Time in ms
; Return values .: A Socket				= When the connect call was a success
;				   False				= if it wasnt
; Errors ........: https://docs.microsoft.com/de-de/windows/win32/winsock/windows-sockets-error-codes-2
; Modified ......:
; Remarks .......: A non blocking connect call, will always return a socket even so that the socket isnt connected yet.
;				   Those sockets are added to _netcode but with ID 3. So _netcode_CheckSocket() will return 3.
;				   Within _netcode_Loop() the pending connection will be checked. And when the connect was a success then
;				   Automatically added to _netcode. The connection event will also be called.
;				   If the connection failed or timeouted then the disconnected event will be called.
;				   You can already store data to the pending sockets or add events with _netcode_SetEvent().
; Example .......: No
; ===============================================================================================================================
Func _netcode_TCPConnect($sIP, $vPort, $bDontAuthAsNetcode = False, $sUsername = "", $sPassword = "", $bNonBlocking = False, $nTimeout = 2000)
	__Trace_FuncIn("_netcode_TCPConnect", $sIP, $vPort, $bDontAuthAsNetcode, $sUsername, "$sPassword", $bNonBlocking)

	Local $hSocket = 0
	Local $nError = 0
	Local $nExtended = 0
	Local $bAuth = False

	If $bNonBlocking Then

		; ipv4 and non blocking
		$hSocket = __netcode_TCPConnect($sIP, $vPort, 2, True, $nTimeout)
		if $hSocket = -1 Then
			$nError = @error
			__Trace_Error($nError, 0)
			Return SetError($nError, 0, __Trace_FuncOut("_netcode_TCPConnect", False))
		EndIf

		; save ip, port, username and password
		__netcode_SocketSetIPAndPort($hSocket, $sIP, $vPort)
		__netcode_SocketSetUsernameAndPassword($hSocket, $sUsername, $sPassword)

		; add the non blocking connect call to the list
		__netcode_ParentAddNonBlockingConnectClient("000", $hSocket, $bDontAuthAsNetcode, $nTimeout)

		Return __Trace_FuncOut("_netcode_TCPConnect", $hSocket)

	Else

		; ipv4 and blocking
		$hSocket = __netcode_TCPConnect($sIP, $vPort, 2, False, $nTimeout)

		; if we couldnt connect
		if $hSocket = -1 Then
			$nError = @error
			__Trace_Error($nError, 0)
			Return SetError($nError, 0, __Trace_FuncOut("_netcode_TCPConnect", False))
		EndIf

		; add socket to _netcode
		__netcode_AddSocket($hSocket, '000', 0, $sIP, $vPort, $sUsername, $sPassword)

		; execute connection event
		__netcode_ExecuteEvent($hSocket, "connection", 'connect')

		; auth to netcode server if toggled on
		if Not $bDontAuthAsNetcode Then

			$bAuth = _netcode_AuthToNetcodeServer($hSocket, $sUsername, $sPassword, $bNonBlocking)
			If Not $bAuth Then
				$nError = @error
				$nExtended = @extended

				__netcode_TCPCloseSocket($hSocket)
				__netcode_RemoveSocket($hSocket)
				Return SetError($nError, $nExtended, __Trace_FuncOut("_netcode_TCPConnect", False))
			EndIf

		EndIf

		Return __Trace_FuncOut("_netcode_TCPConnect", $hSocket)

	EndIf

EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_AuthToNetcodeServer
; Description ...: Triggers the Staging process for the connect client.
; Syntax ........: _netcode_AuthToNetcodeServer(Const $hSocket[, $sUsername = ""[, $sPassword = ""[, $bNonBlocking = False[,
;                  $nTimeout = 2000]]]])
; Parameters ....: $hSocket             - [const] The socket
;                  $sUsername           - [optional] If the Server is Usermanaged then enter the Username here
;                  $sPassword           - [optional] If the Server is Usermanaged then enter the Password here
;                  $bNonBlocking        - [optional] Set to True if you want the Staging to be non Blocking
; Return values .: True					= If the staging was a success (blocking only)
;				 : False				= If the staging failes (blocking only)
;				 : Null					= Always on a non blocking call
; Errors ........: 1					= Socket is unknown to _netcode
; Modified ......:
; Remarks .......: You use this function for when you call _netcode_TCPConnect() with the $bDontAuthTAsNetcode set to True.
;				 : If you do this then you can set socket specific options or events to the connect socket, so that they are
;				 : applied to them before the staging is started. This is helpfull because you need the socket first
;				 : to apply changes to it.
;				 : This function call also be Non Blocking. That the socket might still be pending doesnt matter.
; Example .......: No
; ===============================================================================================================================
Func _netcode_AuthToNetcodeServer(Const $hSocket, $sUsername = "", $sPassword = "", $bNonBlocking = False)

	; if the socket is unknown then return false
	If __netcode_CheckSocket($hSocket) = 0 Then Return SetError(1, 0, False) ; socket is unknown to netcode

	if $sUsername <> "" Or $sPassword <> "" Then
		__netcode_SocketSetUsernameAndPassword($hSocket, $sUsername, $sPassword)
	EndIf

	; if the socket is pending then set the dont auth to netcode toggle to False
	If __netcode_CheckSocket($hSocket) = 3 Then
		_storageS_Overwrite($hSocket, '_netcode_DontAuthAsNetcode', False)
	Else
		; otherwie trigger the first stage now
		__netcode_ManageAuth($hSocket, Null)
	EndIf

	; if the call is set to be non blocking then return Null
	if $bNonBlocking Then Return Null

	; otherwsie wait until we reached stage 10 (netcode)
	While __netcode_CheckSocket($hSocket) <> 0

		; loop just this socket
		_netcode_Loop($hSocket)

		; exitloop once stage = 10
		if __netcode_SocketGetManageMode($hSocket) = 10 Then ExitLoop
	WEnd

	; in case we exited loop because the socket disconnected then return false
	if __netcode_CheckSocket($hSocket) = 0 Then Return False

	; other call it a success
	Return True

EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_GetCurrentStageName
; Description ...: Returns the Stagename the given socket is currently running in
; Syntax ........: _netcode_GetCurrentStageName($hSocket)
; Parameters ....: $hSocket             - The socket
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_GetCurrentStageName($hSocket)
	Local $nCode = __netcode_SocketGetManageMode($hSocket)

	Switch $nCode

		Case 0
			Return 'auth'

		Case 1
			Return 'presyn'

		Case 2
			Return 'handshake'

		Case 3
			Return 'syn'

		Case 4
			Return 'user'

;~ 		Case 5
;~ 			Return 'mfa'

		Case 9
			Return 'ready'

		Case 10
			Return 'netcode'

	EndSwitch
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_StageGetError
; Description ...: Returns the Error code that the given stage has set
; Syntax ........: _netcode_StageGetError($hSocket[, $sStageName = ""])
; Parameters ....: $hSocket             - The socket
;                  $sStageName          - [optional] Stagename
; Return values .: A Error code			= If there was an error
;				 : 0					= If there was no error
;				 : -1					= If the stage hasnt been executed
; Modified ......:
; Remarks .......: If you call this function in your disonnect function to catch the error but you get -1 returned then
;				 : that means that the given stage hasnt been executed.
;				 : If you dont give a stagename then _netcode will read the current.
;				 : You only need to call this function if you are looking to treat a specific error differently in your script
;				 : or if you are debugging.
;				 : Otherwise _netcode_StageGetErrorDescription() should work fine for you.
;				 :
; Error codes ...: accept means the error appeared on the accept client. connect = on the connect client.
; auth ..........: (accept)		1		= The pre shared key could not be verified
; presyn ........: (connect)	1		= The presyn data could not be decrypted
;				 : (connect)	2		= %reserved%
; handshake .....: (accept)		1		= The session key could not be decrypted
;				 : (connect)	2		= The public key could not be decrypted
;				 : (connect)	3		= The session key could not be encrypted
; Syn ...........: (connect)	1		= The Syn data could not be decrypted
;				 : (connect)	2		= %reserved%
; User ..........: (accept)		1		= User Stage error. See _netcode_StageGetExtended()
; User ..........: (connect)	2		= User Stage error. See _netcode_StageGetExtended()
; ===============================================================================================================================
Func _netcode_StageGetError($hSocket, $sStageName = "")
	if $sStageName = "" Then $sStageName = _netcode_GetCurrentStageName($hSocket)

	Local $arData = _storageS_Read($hSocket, '_netcode_StageErrAndExt_' & $sStageName)
	if Not IsArray($arData) Then Return -1 ; stage hasnt run, could indicate that a disconnect happened before

	Return $arData[0]
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_StageGetExtended
; Description ...: Returns the Extended code that the given stage has set
; Syntax ........: _netcode_StageGetExtended($hSocket[, $sStageName = ""])
; Parameters ....: $hSocket             - a handle value.
;                  $sStageName          - [optional] a string value. Default is "".
; Return values .: A Extended code		= If there was one set
;				 : 0					= If there was none
;				 : -1					= If the stage hasnt been executed
; Modified ......:
; Remarks .......: If you call this function in your disonnect function to catch the extended but you get -1 returned then
;				 : that means that the given stage hasnt been executed.
;				 : If you dont give a stagename then _netcode will read the current.
;				 : You only need to call this function if you are looking to treat a specific extended differently in your script
;				 : or if you are debugging.
;				 : Otherwise _netcode_StageGetExtendedDescription() should work fine for you.
;				 :
; Extended Codes : accept means the error appeared on the accept client. connect = on the connect client.
; presyn ........: (connect)	1		= %reserved%
; syn ...........: (connect)	1		= %reserved%
; user ..........: (accept)		1		= Could not decrypt user login details
; 				 : (accept)		2		= Username is not present in the user db
; 				 : (accept)		3		= Wrong Password
; 				 : (accept)		4		= Account is set OnHold
; 				 : (accept)		5		= Account is Banned
; 				 : (accept)		6		= Account is Blocked
;				 : (connect)	1		= Server requires User login, but client has none set to it _netcode_TCPConnect(ip, port, False, xxx, xxx)
;				 : (connect)	2		= Could not decrypt server answer
;				 : (connect)	3		= Unknown user or wrong password
;				 : (connect)	4		= Account is set OnHold
;				 : (connect)	5		= Account is Banned
;				 : (connect)	6		= Unknown Error
; ===============================================================================================================================
Func _netcode_StageGetExtended($hSocket, $sStageName = "")
	if $sStageName = "" Then $sStageName = _netcode_GetCurrentStageName($hSocket)

	Local $arData = _storageS_Read($hSocket, '_netcode_StageErrAndExt_' & $sStageName)
	if Not IsArray($arData) Then Return -1 ; stage hasnt run, could indicate that a disconnect happened before

	Return $arData[1]
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_StageGetErrorDescription
; Description ...: Returns information as String for the given socket, stage and error.
; Syntax ........: _netcode_StageGetErrorDescription($hSocket[, $sStageName = ""[, $nError = 0]])
; Parameters ....: $hSocket             - The socket
;                  $sStageName          - [optional] Stagename
;                  $nError              - [optional] Error
; Return values .: A String
;				 : ""					= Empty if there was no error
; Modified ......:
; Remarks .......: Neither the Stagename nor the Error need to be given. _netcode will read the last error from the last stage
;				 : itself.
; Example .......: No
; ===============================================================================================================================
Func _netcode_StageGetErrorDescription($hSocket, $sStageName = "", $nError = 0)
	if $sStageName = "" Then $sStageName = _netcode_GetCurrentStageName($hSocket)
	if $nError = 0 Then $nError = _netcode_StageGetError($hSocket, $sStageName)

	; if no error
	if $nError <= 0 Then Return ""

	Local $nSocketIs = _netcode_CheckSocket($hSocket)
	if $nSocketIs == 1 Then Return SetError(1, 0, False)
	$nSocketIs = @error ; 1 = accept, 2 = connect

	Local $sText = ""

	Switch $nSocketIs

		Case 1 ; accept client
			$sText = "Error(" & $nError & ") for Accept client @ Stage: " & $sStageName & @TAB

		Case 2 ; connect client
			$sText = "Error(" & $nError & ") for Connect client @ Stage: " & $sStageName & @TAB

	EndSwitch

	Switch $sStageName ; switch for the stage

		Case 'auth' ; auth stage

			Switch $nSocketIs ; switch for the socket type

				Case 1 ; its a accept client

					Switch $nError ; switch the error

						Case 1 ; its error 1
							$sText &= "Pre shared key could not be verified"

					EndSwitch


				Case 2 ; its a connect client

					; none

			EndSwitch


		Case 'presyn'

			Switch $nSocketIs

				Case 1

					; none

				Case 2

					Switch $nError

						Case 1
							$sText &= "Could not decrypt Presyn data"

;~ 						Case 2
;~ 							$sText &= "reserved"

					EndSwitch

			EndSwitch


		Case 'handshake'

			Switch $nSocketIs

				Case 1

					Switch $nError

						Case 1
							$sText &= "The session key could not be decrypted"

					EndSwitch


				Case 2

					Switch $nError

						Case 1
							$sText &= "The public key could not be decrypted"

						Case 2
							$sText &= "The session key could not be encrypted"

					EndSwitch

			EndSwitch

		Case 'syn'

			Switch $nSocketIs

				Case 1

					; none

				Case 2

					Switch $nError

						Case 1
							$sText &= "The syn data could not be decrypted"

;~ 						Case 2
;~ 							$sText &= "reserved"

					EndSwitch

			EndSwitch

		Case 'user'

			Switch $nSocketIs

				Case 1

					Switch $nError

						Case 1
							$sText &= "User stage error"

					EndSwitch


				Case 2

					Switch $nError

						Case 1
							$sText &= "User stage error"

					EndSwitch

			EndSwitch
	EndSwitch

	Return $sText
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_StageGetExtendedDescription
; Description ...:
; Syntax ........: _netcode_StageGetExtendedDescription($hSocket[, $sStageName = ""[, $nExtended = 0]])
; Parameters ....: $hSocket             - The socket
;                  $sStageName          - [optional] Stagename
;                  $nError              - [optional] Extended
; Return values .: A String
;				 : ""					= Empty if there was no Extended
; Modified ......:
; Remarks .......: Neither the Stagename nor the Extended need to be given. _netcode will read the last extended from the last stage
;				 : itself.
; Example .......: No
; ===============================================================================================================================
Func _netcode_StageGetExtendedDescription($hSocket, $sStageName = "", $nExtended = 0)
	if $sStageName = "" Then $sStageName = _netcode_GetCurrentStageName($hSocket)
	if $nExtended = 0 Then $nExtended = _netcode_StageGetExtended($hSocket, $sStageName)

	; if no extended
	if $nExtended <= 0 Then Return ""

	Local $nSocketIs = _netcode_CheckSocket($hSocket)
	if $nSocketIs == 1 Then Return SetError(1, 0, False)
	$nSocketIs = @error ; 1 = accept, 2 = connect

	Local $sText = ""

	Switch $nSocketIs

		Case 1 ; accept client
			$sText = "Extended(" & $nExtended & ") for Accept client @ Stage: " & $sStageName & @TAB

		Case 2 ; connect client
			$sText = "Extended(" & $nExtended & ") for Connect client @ Stage: " & $sStageName & @TAB

	EndSwitch


	Switch $sStageName

;~ 		Case 'presyn'
			; reserved


;~ 		Case 'syn'
			; reserved

		Case 'user'

			Switch $nSocketIs

				Case 1

					Switch $nExtended

						Case 1
							$sText &= "Could not decrypt user login details"

						Case 2
							$sText &= "Username is not present in the user db"

						Case 3
							$sText &= "Wrong password"

						Case 4
							$sText &= "Account is set OnHold"

						Case 5
							$sText &= "Account is Banned"

						Case 6
							$sText &= "Account Blocked"

					EndSwitch

				Case 2

					Switch $nExtended

						Case 1
							$sText &= "Server requires login, but client knows no login details"

						Case 2
							$sText &= "Could not decrypt server answer"

						Case 3
							$sText &= "Unknown User or Wrong password"

						Case 4
							$sText &= "Account is set OnHold"

						Case 5
							$sText &= "Account is Banned"

						Case 6
							$sText &= "Unknown Error"

					EndSwitch


			EndSwitch
	EndSwitch

	Return $sText
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_StageGetExtraInformation
; Description ...: Returns additional Data.
; Syntax ........: _netcode_StageGetExtraInformation($hSocket[, $sStageName = ""])
; Parameters ....: $hSocket             - The socket
;                  $sStageName          - [optional] Stagename
; Return values .: None
; Modified ......:
; Remarks .......: If you a Stagename then this function will return the extra information set in the given stage.
;				 : Otherwise it will give the latest set extra information.
; Example .......: No
; ===============================================================================================================================
Func _netcode_StageGetExtraInformation($hSocket, $sStageName = "")
	if $sStageName = "" Then $sStageName = _netcode_GetCurrentStageName($hSocket)

	Local $sData = _storageS_Read($hSocket, '_netcode_StageExtraInfo_' & $sStageName)
	if $sData == False Then Return ""

	Return $sData
EndFunc


; marked for recoding
; store the specific $__net_nMaxRecvBufferSize to the socket, since having connections to multiple server with different
; settings would break the script.
; add a Timeout that can be set with _netcode_SetOption() and / or in the parameters $nWaitForFloodPreventionTimeout
; add the parameter to disable packet encryption for the given data.
; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_TCPSend
; Description ...: Quos up a packet to be send within _netcode_Loop(). The packet is created within this function and a buffer size check is also done.
; Syntax ........: _netcode_TCPSend(Const $hSocket, $sEvent[, $sData = ''[, $bWaitForFloodPrevention = True]])
; Parameters ....: $hSocket             - [const] The socket
;                  $sEvent              - Eventname (case-sensitive)
;                  $sData               - [optional] The data you optionally want to send to the event. See _netcode_sParams() for more options.
;										  It is best to give String data [BinaryToString()] ! If you do want to give binary then have it converted
;										  with $SB_UFT8 otherwise data corruption will happen.
;                  $bWaitForFloodPrevention- [optional] See Remarks
; Return values .: False				= If the packet couldnt be quod
;				   True					= If the packet was successfully quod or buffered
; Errors ........: 10					= Illegal event used
;				   11					= The given Data is to large to be ever send
;				   12					= Tracer Warning only: The given Data is not of Type String.
;				   13					= The socket is not in the required 'netcode' stage. Data is buffered and send once the socket is the 'netcode' stage.
;                  1					= Flood prevention error. Will be returned if the data couldnt be quod because the buffer is too full
; Extended ......: 1					= Socket is unknown or the Socket got disconnected
; Modified ......:
; Remarks .......: _netcode uses a Buffering system to make sure that neither the server nor the client is sending more data
;				   then the other side can process. Todo that _netcode does some calculations and will reject data if its to much for the other side to handle.
;				   This feature is called Flood Prevention. If $bWaitForFloodPrevention is set to True then this function will wait
;                  for the buffer to be empty enough again to quo up the current packet. If its set to False then this function will
;                  return, without quoing the packet, and will give @error = 1. On servers you should set $bWaitForFloodPrevention to False.
;				   Otherwise slow clients will lower the performance for all other Clients.
;                  See _netcode_GetMaxPacketContentSize(), _netcode_GetDefaultPacketContentSize() and _netcode_GetDynamicPacketContentSize() for the right data sizes.
;
;				   Again. This function does not Send data. It quos it up. The packets are send once you call _netcode_Loop() the next time.
;				   There are two reasons why this is done. First of all _netcode combines packets, sending a single is just faster then sending multiple.
;				   Second, all sockets are set to be non blocking. So managing alot of Sockets is much more efficient and a single slow socket cant anymore
;				   slow down all other or the whole script.
;
;				   If you opened a File in read mode with the Binary flag (16) then what you read with FileRead does not have the right binary format and
;				   and the Data will be corrupted. Use BinaryToString() when you send the data and StringToBinary() in your Event function.
; Example .......: .\examples\TCPSend ~ todo note: I should exactly show how to use _netcode_TCPSend on a server for maximum performance
; ===============================================================================================================================
Func _netcode_TCPSend(Const $hSocket, $sEvent, $sData = '', $bWaitForFloodPrevention = True)
	__Trace_FuncIn("_netcode_TCPSend", $hSocket, $sEvent, "$sData", $bWaitForFloodPrevention)

	; check if the socket is known to _netcode
	If Not __netcode_CheckSocket($hSocket) Then
		__Trace_Error(0, 1, "Socket is unknown")
		Return SetError(0, 1, __Trace_FuncOut("_netcode_TCPSend", False))
	EndIf

	; check the managemode the socket is in
	If __netcode_SocketGetManageMode($hSocket) <> 10 Then

		Local $arBuffer = _storageS_Read($hSocket, '_netcode_PreNetcodeSendBuffer')
		if Not IsArray($arBuffer) Then
			Local $arBuffer[0][3]
		EndIf

		Local $nArSize = UBound($arBuffer)
		ReDim $arBuffer[$nArSize + 1][3]
		$arBuffer[$nArSize][0] = $sEvent
		$arBuffer[$nArSize][1] = $sData
		$arBuffer[$nArSize][2] = $bWaitForFloodPrevention

		_storageS_Overwrite($hSocket, '_netcode_PreNetcodeSendBuffer', $arBuffer)

		; trigger a warn info
		; ~ todo

;~ 		__Trace_Error(13, 0, "Socket is not in the netcode stage")
		Return SetError(13, 0, __Trace_FuncOut("_netcode_TCPSend", True))
	EndIf

	; check if the given event is illegal
	if $sEvent = 'connection' Or $sEvent = 'disconnected' Then
		__Trace_Error(10, 0, "The " & $sEvent & " event is an invalid event to be send")
		Return SetError(10, 0, __Trace_FuncOut("_netcode_TCPSend", False))
	EndIf

	; temporary check data variable type
	if Not IsString($sData) Then
		__Trace_Error(12, 0, "WARNING: Data is of Type: " & VarGetType($sData) & " but should be of Type String. Data Corruption might happen.")
	EndIf

	; create package
	Local $sPackage = __netcode_CreatePackage($hSocket, $sEvent, $sData)
	Local $nError = @error
	Local $sID = @extended
	Local $nLen = StringLen($sPackage)

	; check package size
	If $nLen > $__net_nMaxRecvBufferSize Then Return SetError(11, 0, __Trace_FuncOut("_netcode_TCPSend", False)) ; this packet is to big to ever get send

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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_TCPSendRaw
; Description ...: DO NOT USE. Socket linking is unsafe and experimental.
; Syntax ........: _netcode_TCPSendRaw(Const $hSocket, $sData[, $nLinkID = False])
; Parameters ....: $hSocket             - [const] a handle value.
;                  $sData               - a string value.
;                  $nLinkID             - [optional] a general number value. Default is False.
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
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


; both functions should be made in a way that they help in the efficient use of _netcode_TCPSend() ..Raw() for servers.
Func _netcode_SendHelper(Const $hSocket)
	; ~ todo
EndFunc

Func _netcode_SetSendHelper(Const $hSocket, $sData)
	; ~ todo
EndFunc


; give parent socket
; marked for recoding
; note - make it so that besides a single parent an array of parents and or clients can be given
; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_TCPBroadcast
; Description ...: Broadcasts data for the event to all clients of the given parent
; Syntax ........: _netcode_TCPBroadcast(Const $hSocket, $sEvent, $sData[, $bWaitForFloodPrevention = True])
; Parameters ....: $hSocket             - [const] The parent socket
;                  $sEvent              - Eventname (case-sensitive)
;                  $sData               - [optional] data given to the event
;                  $bWaitForFloodPrevention- [optional] See _netcode_TCPSend()
; Return values .: None
; Errors ........: 1					= The given socket is not a parent
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_TCPBroadcast(Const $hSocket, $sEvent, $sData = "", $bWaitForFloodPrevention = True)
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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SocketGetSendBytesPerSecond
; Description ...: Will return the send bytes per second for the given parent or client socket in b, kb or mb round to 2 decimals.
; Syntax ........: _netcode_SocketGetSendBytesPerSecond(Const $hSocket[, $nMode = 0])
; Parameters ....: $hSocket             - [const] The parent or client socket
;                  $nMode               - [optional] 0 = bytes - 1 = kilobytes - 2 = megabytes
; Return values .: Bytes per second
; Modified ......:
; Remarks .......: If a parent socket is given then the function will read the bps for each client and adds them together.
; Example .......: No
; ===============================================================================================================================
Func _netcode_SocketGetSendBytesPerSecond(Const $hSocket, $nMode = 0)
	__Trace_FuncIn("_netcode_SocketGetSendBytesPerSecond")

	Local $nBytesPerSecond = 0
	Switch __netcode_CheckSocket($hSocket)
		Case 1 ; parent
			Local $arClients = __netcode_ParentGetClients($hSocket)
			For $i = 0 To UBound($arClients) - 1
				$nBytesPerSecond += __netcode_SocketGetSendBytesPerSecond($arClients[$i])
			Next

		Case 2 ; client
			$nBytesPerSecond = __netcode_SocketGetSendBytesPerSecond($hSocket)
	EndSwitch

	__Trace_FuncOut("_netcode_SocketGetSendBytesPerSecond")

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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SocketGetRecvBytesPerSecond
; Description ...: Will return the received bytes per second for the given parent or client socket in b, kb or mb round to 2 decimals.
; Syntax ........: _netcode_SocketGetRecvBytesPerSecond(Const $hSocket[, $nMode = 0])
; Parameters ....: $hSocket             - [const] The parent or client socket
;                  $nMode               - [optional] 0 = bytes - 1 = kilobytes - 2 = megabytes
; Return values .: Bytes per second
; Modified ......:
; Remarks .......: If a parent socket is given then the function will read the bps for each client and adds them together.
; Example .......: No
; ===============================================================================================================================
Func _netcode_SocketGetRecvBytesPerSecond(Const $hSocket, $nMode = 0)
	__Trace_FuncIn("_netcode_SocketGetRecvBytesPerSecond")

	Local $nBytesPerSecond = 0
	Switch __netcode_CheckSocket($hSocket)
		Case 1 ; parent
			Local $arClients = __netcode_ParentGetClients($hSocket)
			For $i = 0 To UBound($arClients) - 1
				$nBytesPerSecond += __netcode_SocketGetRecvBytesPerSecond($arClients[$i])
			Next

		Case 2 ; client
			$nBytesPerSecond = __netcode_SocketGetRecvBytesPerSecond($hSocket)
	EndSwitch

	__Trace_FuncOut("_netcode_SocketGetRecvBytesPerSecond")

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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SocketGetSendPacketPerSecond
; Description ...: Will return the send packets per second for the given parent or client socket
; Syntax ........: _netcode_SocketGetSendPacketPerSecond(Const $hSocket)
; Parameters ....: $hSocket             - [const] The parent or client socket
; Return values .: Packets per second
; Modified ......:
; Remarks .......: If a parent socket is given then the function will read the pps for each client and adds them together.
; Example .......: No
; ===============================================================================================================================
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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SocketGetRecvPacketPerSecond
; Description ...: Will return the received packets per second for the given parent or client socket
; Syntax ........: _netcode_SocketGetRecvPacketPerSecond(Const $hSocket)
; Parameters ....: $hSocket             - [const] The parent or client socket
; Return values .: Packets per second
; Modified ......:
; Remarks .......: If a parent socket is given then the function will read the pps for each client and adds them together.
; Example .......: No
; ===============================================================================================================================
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

 Edit:
 This function and its subparts is going to be removed and replaced with the Sub Stream feature.
 Additional informations about it can be read in .\Concept Plan.txt
#ce
; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SetupSocketLink
; Description ...: DO NOT USE. Unsafe and highly experimental.
; Syntax ........: _netcode_SetupSocketLink(Const $hSocket, $sCallback[, $nLinkID = Default[, $vAdditionalData = False]])
; Parameters ....: $hSocket             - [const] a handle value.
;                  $sCallback           - a string value.
;                  $nLinkID             - [optional] a general number value. Default is Default.
;                  $vAdditionalData     - [optional] a variant value. Default is False.
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SocketLinkSetAdditionalData
; Description ...: DO NOT USE. Unsafe and highly experimental.
; Syntax ........: _netcode_SocketLinkSetAdditionalData(Const $hSocket, $nLinkID, $vAdditionalData)
; Parameters ....: $hSocket             - [const] a handle value.
;                  $nLinkID             - a general number value.
;                  $vAdditionalData     - a variant value.
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SocketLinkGetAdditionalData
; Description ...: DO NOT USE. Unsafe and highly experimental.
; Syntax ........: _netcode_SocketLinkGetAdditionalData(Const $hSocket[, $nLinkID = False])
; Parameters ....: $hSocket             - [const] a handle value.
;                  $nLinkID             - [optional] a general number value. Default is False.
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_SocketLinkGetAdditionalData(Const $hSocket, $nLinkID = False)
	__Trace_FuncIn("_netcode_SocketLinkGetAdditionalData")
	__Trace_FuncOut("_netcode_SocketLinkGetAdditionalData")
	if _storageS_Read($hSocket, '_netcode_IsLinkClient') Then
		Return _storageS_Read($hSocket, '_netcode_LinkAdditionalData')
	Else
		Return _storageS_Read($hSocket, '_netcode_LinkAdditionalData' & $nLinkID)
	EndIf
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_CheckLink
; Description ...: DO NOT USE. Unsafe and highly experimental.
; Syntax ........: _netcode_CheckLink(Const $hSocket[, $nLinkID = False])
; Parameters ....: $hSocket             - [const] a handle value.
;                  $nLinkID             - [optional] a general number value. Default is False.
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_CheckLink(Const $hSocket, $nLinkID = False)
	__Trace_FuncIn("_netcode_CheckLink")
	__Trace_FuncOut("_netcode_CheckLink")
	Return __netcode_SocketGetLinkedSocket($hSocket, $nLinkID)
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SocketSetManageMode
; Description ...: Sets the manage mode for the given socket. Both a server and the client need the same manage mode or they
;				   wont be able to understand each other. You most likely will not use this function in the current state of the UDF.
; Syntax ........: _netcode_SocketSetManageMode(Const $hSocket[, $sMode = Default])
; Parameters ....: $hSocket             - [const] The Socket
;                  $sMode               - [optional]
; Return values .: True					= Success
;				   False				= Failed
; Errors ........: 1					= Invalid Manage Mode
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
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


; marked for recoding.
; Requires the socket to know the maximum packet size ! The packet string lens however are always exactly the same, no matter the seed.
; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_GetMaxPacketContentSize
; Description ...: Will return the maximum data size the socket buffer accepts for the given socket.
; Syntax ........: _netcode_GetMaxPacketContentSize([$sEvent = ""[, $nMarge = 0.9]])
; Parameters ....: $sEvent              - [optional] Eventname
;                  $nMarge              - [optional] Safety marge
; Return values .: None
; Modified ......:
; Remarks .......: If your data is bigger then this then _netcode_TCPSend() most likely will reject the quoing.
;                  If you, however you do it, force the sending of to large data then the receiver will simply reject it in the end.
;                  So keep the data that you send within these limits. Keep in mind that each client inherits the settings from the server.
; Example .......: FileRead($handle), _netcode_GetMaxPacketContentSize("event"))
; ===============================================================================================================================
Func _netcode_GetMaxPacketContentSize($sEvent = "", $nMarge = 0.9)
	__Trace_FuncIn("_netcode_GetMaxPacketContentSize", $sEvent, $nMarge)
	__Trace_FuncOut("_netcode_GetMaxPacketContentSize")
	Return Int(($__net_nMaxRecvBufferSize - (StringLen($__net_sPacketBegin) + StringLen($__net_sPacketEnd) + (StringLen($__net_sPacketInternalSplit) * 3) + 32 + StringLen($sEvent))) * $nMarge)
EndFunc   ;==>_netcode_GetMaxPacketContentSize


; marked for recoding.
; Requires the socket to know the maximum packet size ! The packet string lens however are always exactly the same, no matter the seed.
; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_GetDefaultPacketContentSize
; Description ...: Will return the default data size, inherited by the server, for the given socket.
; Syntax ........: _netcode_GetDefaultPacketContentSize([$sEvent = ""])
; Parameters ....: $sEvent              - [optional] Eventname
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: FileRead($handle), _netcode_GetDefaultPacketContentSize("event"))
; ===============================================================================================================================
Func _netcode_GetDefaultPacketContentSize($sEvent = "")
	__Trace_FuncIn("_netcode_GetDefaultPacketContentSize", $sEvent)
	__Trace_FuncOut("_netcode_GetDefaultPacketContentSize")
	Return Int(($__net_nDefaultRecvLen - (StringLen($__net_sPacketBegin) + StringLen($__net_sPacketEnd) + (StringLen($__net_sPacketInternalSplit) * 3) + 32 + StringLen($sEvent))))
EndFunc   ;==>_netcode_GetDefaultPacketContentSize


#cs DO NOT USE. SIMPLY INEFFICIENT AT THE MOMENT.
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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SocketSetVar
; Description ...: Sets Custom data for your own usage to a Socket
; Syntax ........: _netcode_SocketSetVar(Const $hSocket, $sName, $vData)
; Parameters ....: $hSocket             - [const] The Socket
;                  $sName               - Variable name (case-sensitive)
;                  $vData               - data of any kind
; Return values .: True					= Success
;				   False				= Failure
; Errors ........: 1					= If the socket is not known to _netcode
; Modified ......:
; Remarks .......: Data is kept within _netcode until the socket is removed or released from _netcode.
;				   In the case of a disconnect, you will still be able to access the data in your disconnect event.
;				   Right after, it will be removed.
;				   You can name the Variable however you want.
; Example .......: No
; ===============================================================================================================================
Func _netcode_SocketSetVar(Const $hSocket, $sName, $vData)
	if __netcode_CheckSocket($hSocket) = 0 Then Return SetError(1, 0, False)

	$sName = StringToBinary('_netcode_custom_' & $sName, 4)
	_storageS_Overwrite($hSocket, $sName, $vData)

	Return True
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SocketGetVar
; Description ...: Returns the Data, previously set with _netcode_SocketSetVar()
; Syntax ........: _netcode_SocketGetVar(Const $hSocket, $sName)
; Parameters ....: $hSocket             - [const] The socket
;                  $sName               - Variable name (case-sensitive)
; Return values .: Your data
; 				 : Null					= No Data available
; Errors ........: 1					= If the socket is not known to _netcode
; Modified ......:
; Remarks .......: If the variable wasnt set yet or got already removed then the return is always Null.
; Example .......: No
; ===============================================================================================================================
Func _netcode_SocketGetVar(Const $hSocket, $sName)
	if __netcode_CheckSocket($hSocket) = 0 Then Return SetError(1, 0, Null)

	$sName = StringToBinary('_netcode_custom_' & $sName, 4)
	Local $sData = _storageS_Read($hSocket, $sName)

	if @error Then Return SetError(1, 0, Null)
	Return $sData

EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_UseNonCallbackEvent
; Description ...: Will TCPSend data to the given remote event of the given socket and then await an answer on the given local non Callback event.
; Syntax ........: _netcode_UseNonCallbackEvent(Const $hSocket, $sMyEvent, $sSendEvent[, $sData = ""[, $nTimeout = 10000]])
; Parameters ....: $hSocket             - [const] The socket
;                  $sMyEvent            - Local non Callback event
;                  $sSendEvent          - Remote event
;                  $sData               - [optional] Extra Data to be send
;                  $nTimeout            - [optional] Maximum Time to wait for an answer
; Return values .: 1D Array with n elements
;                  [0] = "CallArgArray" <-- Always
;                  [1] = Socket handle  <-- Always
;                  [2] = param 1        <-- if the other side returned data
;                  [n] = param n        <-- each and every param element can be of any VarType
;				   False				= When the Socket disconnected or the request Timeouted.
;
; Errors ........: 1					= The socket disconnected
;				   2					= Timeout
; Modified ......:
; Remarks .......: For the usage of local non callback events only. Imagine the usage of a Function where you expect an return.
;                  Thats what non callback events are for. To get a fast and easy return from the other side. Simple as that.
;				   Non Callback events are compatible with _netcode_sParams() and _netcode_exParams().
;                  Thats why an Array is returned instead of the raw data.
; Example .......: No
; ===============================================================================================================================
Func _netcode_UseNonCallbackEvent(Const $hSocket, $sMyEvent, $sSendEvent, $sData = "", $nTimeout = 10000) ; 10 sec default timeout

	; resetting eventdata in case there is something stored that got returned from a previous failed call
	_netcode_GetEventData($hSocket, $sMyEvent)

	; sending request
	_netcode_TCPSend($hSocket, $sSendEvent, $sData)

	; check for TCPSend error
	; ~ todo

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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_GetEventData
; Description ...: Returns and Resets the current saved Non Callback event data.
; Syntax ........: _netcode_GetEventData(Const $hSocket, $sName)
; Parameters ....: $hSocket             - [const] The socket
;                  $sName               - Eventname
; Return values .: 1D Array with n elements
;                  [0] = "CallArgArray" <-- Always
;                  [1] = Socket handle  <-- Always
;                  [2] = param 1        <-- if the other side returned data
;                  [n] = param n        <-- each and every param element can be of any VarType
;                  ""					= Empty String if no data is stored.
; Modified ......:
; Remarks .......: Similiar to _netcode_UseNonCallbackEvent(). But usefull if you do not want to hang up the execution of the script
;                  while waiting for the Answer. This function however does no TCPSend.
; Example .......: No
; ===============================================================================================================================
Func _netcode_GetEventData(Const $hSocket, $sName)
	Local $sData = _storageS_Read($hSocket, '_netcode_Event' & StringToBinary($sName) & '_Data')
	_storageS_Overwrite($hSocket, '_netcode_Event' & StringToBinary($sName) & '_Data', "")

	Return $sData
EndFunc


; note for me: the array used here has only the usage to be able to retrieve all existing events in case the user needs to know them, there is no other usage for the array.
; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SetEvent
; Description ...: Sets or Unsets Non- and Callback Events for the given sockets.
; Syntax ........: _netcode_SetEvent(Const $hSocket, $sName, $sCallback[, $bSet = True])
; Parameters ....: $hSocket             - [const] Parent or Client socket
;                  $sName               - Eventname (case-sensitive)
;                  $sCallback           - [optional] String Callback function name. If "" is given then the Event is a Non Callback Event.
;                  $bSet                - [optional] True = Set - False = Unset
; Return values .: True					= Success
;				   False				= Failed
; Errors ........: 1					= 000 Socket is invalid
;				   2					= Unknown Socket
;				   3					= Event is already set
;				   4					= Event does not exist
; Modified ......:
; Remarks .......: If you set an Event to a parent, then each NEW TCPAccept client of it will inherit this event then.
;                  If you set an Event to a TCP- Accept or Connect client, then only this specific client will have it.
;                  _netcode supports up to 16 params for Callback functions.
;				   Events are case-sensitive. And keep in mind that Non Callback Events need to be used differently.
;
;				   IMPORTANT NOTICE
;				   Do not use _netcode_Loop(), _netcode_RecvManageExecute() or _netcode_UseNonCallbackEvent() within your
;				   event functions, because that might lead to a recursion crash. A Fatal Tracer Warning will be shown if the Tracer is enabled.
; Example .......: _netcode_SetEvent($hSocket, "MyCallbackEvent", "_Event_MyCallbackEvent")
;				   _netcode_SetEvent($hSocket, "MyNonCallbackEvent")
; ===============================================================================================================================
Func _netcode_SetEvent(Const $hSocket, $sName, $sCallback = "", $bSet = True)
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


; marked for recoding
; ~ todo
; this function returns an 2D array from those sockets it has changed this event on.
; if the same array would be used in $hSocket this func would revert the changes to what was before.
; 2D
; [x][0] = Socket
; [0][x] = What was will be
; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SetEventOnAll
; Description ...: DO NOT USE
; Syntax ........: _netcode_SetEventOnAll($sName, $sCallback[, $bSet = True])
; Parameters ....: $sName               - a string value.
;                  $sCallback           - a string value.
;                  $bSet                - [optional] a boolean value. Default is True.
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_SetEventOnAll($sName, $sCallback, $bSet = True)
	__Trace_FuncIn("_netcode_SetEventOnAll", $sName, $sCallback, $bSet)

	If Not IsBinary($sName) Then $sName = StringToBinary($sName)
	Local $nArSize = UBound($__net_arSockets)

	For $i = 0 To $nArSize - 1
		_netcode_SetEventOnAllWithParent($__net_arSockets[$i], $sName, $sCallback, $bSet)
	Next
	__Trace_FuncOut("_netcode_SetEventOnAll")
EndFunc   ;==>_netcode_SetEventOnAll



; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SetEventOnAllWithParent
; Description ...: DO NOT USE
; Syntax ........: _netcode_SetEventOnAllWithParent(Const $hSocket, $sName, $sCallback[, $bSet = True])
; Parameters ....: $hSocket             - [const] a handle value.
;                  $sName               - a string value.
;                  $sCallback           - a string value.
;                  $bSet                - [optional] a boolean value. Default is True.
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_PresetEvent
; Description ...: Sets Default Events.
; Syntax ........: _netcode_PresetEvent($sName, $sCallback[, $bSet = True])
; Parameters ....: $sName               - Eventname
;                  $sCallback           - Callback function name
;                  $bSet                - [optional] True = Set - False = Unset
; Return values .: True					= Success
;				   False				= Failed
; Errors ........: 2					= Event does not exist
; Modified ......:
; Remarks .......: Standard default events are 'connection', 'disconnected', 'flood' and 'netcode_internal'.
;                  You can overwrite these in favor for your own.
;                  Default events cannot be Non Callback events !
;				   If a Default Event is present then each parent after this call can use them.
;                  If a Socket specfic Event is set for a socket then the socket specific event is preffered over the default.
;                  _netcode just checks for socket specific events first and then for default events.
; Example .......: No
; ===============================================================================================================================
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

		; check if the event is already set
		if $nIndex <> -1 Then

			; if so then remove it first
			_netcode_PresetEvent($sName, "", False)
			$nArSize = UBound($__net_arDefaultEventsForEachNewClientSocket)
		EndIf

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


#cs
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
#ce


; marked for recoding
; set a white or blacklist of IP's to a parent Socket.
; if you Whitelist just one IP, because you only want one IP to have access then consider using _netcode_TCPListen(port, ->ip<-) instead of this,
; because then windows will already deny unwated connections.
; if you have a million of ip's consider writing a IP Check application in a faster programming language. Otherwise you will notice lag.
; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SetIPList
; Description ...: DO NOT USE. Not fully implemented
; Syntax ........: _netcode_SetIPList(Const $hSocket, $arIPList, $bIsWhitelist)
; Parameters ....: $hSocket             - [const] a handle value.
;                  $arIPList            - an array of unknowns.
;                  $bIsWhitelist        - a boolean value.
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
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
; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SetGlobalIPList
; Description ...: DO NOT USE. Not fully implemented
; Syntax ........: _netcode_SetGlobalIPList($arIPList, $bIsWhitelist)
; Parameters ....: $arIPList            - an array of unknowns.
;                  $bIsWhitelist        - a boolean value.
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_SetGlobalIPList($arIPList, $bIsWhitelist)
	__Trace_FuncIn("_netcode_SetGlobalIPList", $arIPList, $bIsWhitelist)
	$__net_arGlobalIPList = $arIPList
	$__net_bGlobalIPListIsWhitelist = $bIsWhitelist
	__Trace_FuncOut("_netcode_SetGlobalIPList")
EndFunc   ;==>_netcode_SetGlobalIPList


; marked for recoding
; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SetSocketOnHold
; Description ...: Sets the given client or parent socket OnHold
; Syntax ........: _netcode_SetSocketOnHold(Const $hSocket, $bSet)
; Parameters ....: $hSocket             - [const] The socket
;                  $bSet                - True = Set - False = Unset
; Return values .: None
; Modified ......:
; Remarks .......: A client socket set OnHold wont execute any packets anymore. It will still recieve and disassemble until the buffer is full.
; Example .......: No
; ===============================================================================================================================
Func _netcode_SetSocketOnHold(Const $hSocket, $bSet)
	__Trace_FuncIn("_netcode_SetSocketOnHold", $hSocket, $bSet)
	_storageS_Overwrite($hSocket, '_netcode_SocketExecutionOnHold', $bSet)
	__Trace_FuncOut("_netcode_SetSocketOnHold")
EndFunc   ;==>_netcode_SetSocketOnHold


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_GetSocketOnHold
; Description ...: Returns the OnHold status for the given parent or client socket
; Syntax ........: _netcode_GetSocketOnHold(Const $hSocket)
; Parameters ....: $hSocket             - [const] The socket
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_GetSocketOnHold(Const $hSocket)
	__Trace_FuncIn("_netcode_GetSocketOnHold", $hSocket)
	__Trace_FuncOut("_netcode_GetSocketOnHold")
	Return _storageS_Read($hSocket, '_netcode_SocketExecutionOnHold')
EndFunc   ;==>_netcode_GetSocketOnHold


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_ParentGetClients
; Description ...: Returns the Client sockets for the given parent in a 1D array or the Amount of Clients the parent has.
; Syntax ........: _netcode_ParentGetClients(Const $hSocket[, $bJustTheCount = False])
; Parameters ....: $hSocket             - [const] The parent socket.
;                  $bJustTheCount       - [optional] False = 1D array containing the Client sockets - True = Integer
; Return values .: 1D Array
;				   [0] = Client Socket
;				   [n] = Client Socket
;				   Integer				= The amount of clients.
; Errors ........: 1					= The given Socket is not a parent socket or unknown
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_ClientGetParent
; Description ...: Returns the Parent socket of the given Client socket
; Syntax ........: _netcode_ClientGetParent(Const $hSocket)
; Parameters ....: $hSocket             - [const] The Client socket
; Return values .: Parent Socket
;				   False				= Not a parent socket or unknown
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_ClientGetParent(Const $hSocket)
	Return __netcode_ClientGetParent($hSocket)
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_GetParents
; Description ...: Returns every Parent socket in a 1D Array managed by _netcode
; Syntax ........: _netcode_GetParents([$bJustTheCount = False])
; Parameters ....: $bJustTheCount       - [optional] False = 1D Array - True = Integer
; Return values .: 1D Array
;				   [0] Parent socket
;				   [n] Parent socket
;                  Integer				= Amount of parent sockets
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_GetParents($bJustTheCount = False)
	if $bJustTheCount Then
		Return UBound($__net_arSockets)
	Else
		Return $__net_arSockets
	EndIf
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_sParams (aka simple params)
; Description ...: Serializer function usefull for _netcode_TCPSend() for when you want to send multiple params to an event.
; Syntax ........: _netcode_sParams($p1[, $p2 = Default[, $p3 = Default[, $p4 = Default[, $p5 = Default[, $p6 = Default[,
;                  $p7 = Default[, $p8 = Default[, $p9 = Default[, $p10 = Default[, $p11 = Default[, $p12 = Default[,
;                  $p13 = Default[, $p14 = Default[, $p15 = Default[, $p16 = Default]]]]]]]]]]]]]]])
; Parameters ....: $p1                  - param 1
;                  $p2                  - [optional] param 2
;                  $p3                  - [optional] param 3
;                  $p4                  - [optional] param 4
;                  $p5                  - [optional] param 5
;                  $p6                  - [optional] param 6
;                  $p7                  - [optional] param 7
;                  $p8                  - [optional] param 8
;                  $p9                  - [optional] param 9
;                  $p10                 - [optional] param 10
;                  $p11                 - [optional] param 11
;                  $p12                 - [optional] param 12
;                  $p13                 - [optional] param 13
;                  $p14                 - [optional] param 14
;                  $p15                 - [optional] param 15
;                  $p16                 - [optional] param 16
; Return values .: String
; Modified ......:
; Remarks .......: A "Default" param indicates that the previous param was the last.
;				   If the Event callback function looks like this:
;                  Func _Event_MyEvent(Const $hSocket, $param1, $param2)
;                  Then you can use this function like:
;                  _netcode_TCPSend($hSocket, "MyEvent", _netcode_sParams($param1, $param2))
;
;                  The simple params function also supports arrays (up to 2D of any size).
;                  However every variable is converted into String. And this String vartype is kept on the receiving end.
;                  Use _netcode_exParams() if you want to save and restore variable types.
;                  Simple params is just faster then Extended params.
; Example .......: No
; ===============================================================================================================================
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


Func _netcode_exParams($p1, $p2 = Default, $p3 = Default, $p4 = Default, $p5 = Default, $p6 = Default, $p7 = Default, $p8 = Default, $p9 = Default, $p10 = Default, $p11 = Default, $p12 = Default, $p13 = Default, $p14 = Default, $p15 = Default, $p16 = Default)
	;  ~ todo
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SocketToIP
; Description ...: Returns the IP for the given Socket
; Syntax ........: _netcode_SocketToIP(Const $socket)
; Parameters ....: $socket              - [const] The socket
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_SocketToIP(Const $socket)
	__Trace_FuncIn("_netcode_SocketToIP", $socket)
	Local $structName = DllStructCreate("short;ushort;uint;char[8]")
	Local $sRet = DllCall($__net_hWs2_32, "int", "getpeername", "int", $socket, "ptr", DllStructGetPtr($structName), "int*", DllStructGetSize($structName))
	If Not @error Then
		$sRet = DllCall($__net_hWs2_32, "str", "inet_ntoa", "int", DllStructGetData($structName, 3))
		If Not @error Then Return __Trace_FuncOut("_netcode_SocketToIP", $sRet[0])
	EndIf
	Return __Trace_FuncOut("_netcode_SocketToIP", False)
EndFunc   ;==>_netcode_SocketToIP


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_DisconnectClientsByIP
; Description ...: Disconnects every Client socket, of every parent, that has the given IP.
; Syntax ........: _netcode_DisconnectClientsByIP($sIP)
; Parameters ....: $sIP                 - IP
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_CheckSocket
; Description ...: Returns the socket type
; Syntax ........: _netcode_CheckSocket(Const $hSocket)
; Parameters ....: $hSocket             - [const] The socket
; Return values .: 0					= Unknown socket (the socket is unknown to _netcode)
; 				 : 1					= This socket is a parent
; 				 : 2					= This socket is a client
;				 : 3					= This socket is a pending connect client
; Extended ......: 1					= The client socket is a Accept client
; 				 : 2					= The client socket is a Connect client
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_CheckSocket(Const $hSocket)

	Switch __netcode_CheckSocket($hSocket)

		Case 0
			Return 0

		Case 1
			Return 1

		Case 2
			If __netcode_ClientGetParent($hSocket) = "000" Then
				Return SetError(0, 2, 2)
			Else
				Return SetError(0, 1, 2)
			EndIf

		Case 3
			Return SetError(0, 2, 3)

	EndSwitch

EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_BindSocket
; Description ...: Binds the given Socket to _netcode. Either as parent or as tcp- accept / connect client of the given parent.
; Syntax ........: _netcode_BindSocket(Const $hSocket[, $hParentSocket = False[, $nIfListenerMaxConnections = 200[, $sIP = False[,
;                  $nPort = False[, $sUsername = False[, $sPassword = False]]]]]])
; Parameters ....: $hSocket             - [const] The parent or client socket
;                  $hParentSocket       - [optional] The parent socket if $hSocket is a tcp- accept or connect client socket
;                  $nIfListenerMaxConnections- [optional] if $hSocket is a parent socket then how many clients it at maximum is allowed to have
;                  $sIP                 - [optional] If $hSocket is a tcp connect client socket then to which ip it is connected
;                  $nPort               - [optional] If $hSocket is a tcp connect client socket then to which port it is connected
;                  $sUsername           - [optional] If $hSocket is a tcp connect client socket and if a username is / was required
;                  $sPassword           - [optional] If $hSocket is a tcp connect client socket and if a password is / was required (plaintext)
; Return values .: None
; Modified ......:
; Remarks .......: In order to Bind a tcp accept socket, the parent needs to be present first. So if the parent is not know to _netcode yet then
;				   add the parent first. You can also figure the type of a socket by using _netcode_CheckSocket().
; Example .......: _netcode_BindSocket($hSocket, False)				; how to add a parent socket
;				   _netcode_BindSocket($hSocket, $hParentSocket)	; how to add a tcp accept client socket (accept sockets originate from TCPAccept)
;				   _netcode_BindSocket($hSocket, "000")				; how to add a tcp connect client socket (connect sockets originate from TCPConnect)
; ===============================================================================================================================
Func _netcode_BindSocket(Const $hSocket, $hParentSocket = False, $nIfListenerMaxConnections = 200, $sIP = False, $nPort = False, $sUsername = False, $sPassword = False)
	__Trace_FuncIn("_netcode_BindSocket", $hSocket, $hParentSocket, $nIfListenerMaxConnections)
	Local $bReturn = __netcode_AddSocket($hSocket, $hParentSocket, $nIfListenerMaxConnections, $sIP, $nPort, $sUsername, $sPassword)
	Local $nError = @error
	Local $nExtended = @extended

	If $nError Then __Trace_Error($nError, $nExtended)
	Return SetError($nError, $nExtended, __Trace_FuncOut("_netcode_BindSocket", $bReturn))
EndFunc   ;==>_netcode_BindSocket


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_ReleaseSocket
; Description ...: If you want to release a socket from _netcode's management, but not disconnect it.
; Syntax ........: _netcode_ReleaseSocket(Const $hSocket)
; Parameters ....: $hSocket             - [const] The parent or client socket
; Return values .: None
; Modified ......:
; Remarks .......: _netcode will entirely wipe the socket and its data, just like if it disconnected, but without disconnecting it.
;				   If you want to release a parent socket then release its clients first, otherwise the clients get disconnected.
;				   _netcode_ParentGetClients() might be of use.
; Example .......: No
; ===============================================================================================================================
Func _netcode_ReleaseSocket(Const $hSocket)
	__Trace_FuncIn("_netcode_ReleaseSocket", $hSocket)
	Return __Trace_FuncOut("_netcode_ReleaseSocket", __netcode_RemoveSocket($hSocket))
EndFunc   ;==>_netcode_ReleaseSocket

#cs
; ban a certain IP from connecting. Active connections are ignored.
Func _netcode_BanByIP($sIP, $nMode)
EndFunc   ;==>_netcode_BanByIP
#ce

#Region DO NOT USE. To be overhauled.
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
#EndRegion DO NOT USE. To be overhauled.


; hashes the given data and returns the hash
; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SHA256
; Description ...: Returns the SHA256 Hash of the given data
; Syntax ........: _netcode_SHA256($sData)
; Parameters ....: $sData               - data
; Return values .: Binary
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_SHA256($sData)
	__Trace_FuncIn("_netcode_SHA256", "$sData")
	Return __Trace_FuncOut("_netcode_SHA256", __netcode_CryptSHA256($sData))
EndFunc   ;==>_netcode_SHA256


; unfinished
; marked for recoding
; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SetOption
; Description ...: Sets Options to the given parent or client socket. To be Overhauled.
; Syntax ........: _netcode_SetOption(Const $hSocket, $sOption, $sData)
; Parameters ....: $hSocket             - [const] The socket
;                  $sOption             - String option name
;                  $sData               - Variable option parameter
; Return values .: True					= If Success
;				 : False				= If not
;				 : -2					= Unknown Socket
;				 : -1					= Option does not exist
; Errors ........: 1					= Wrong Socket type
;				 : 2					= The variable Option parameter was of the Wrong type
;				 :
; Options .......: Socket Type			Option name						Input type						Description
;				 : Parent/Accept Client	Encryption						True / False (Bool)				Enables or Disables the Data encryption of the given socket. (Default False)
;				 : Parent				AllowSocketLinkingSetup			True / False (Bool)				Ignore this Option
;				 : Connect Client		AllowSocketLinkingRequest		True / False (Bool)				Ignore this Option
;				 : All					Seed							Number (Int32 / Int64 / Double)	~ todo
;				 : Parent/Accept Client	Handshake Method				String							Sets the handshake method to use (RandomRSA, PresharedAESKey, PresharedRSAKey) (Default RandomRSA)
;				 : All					Handshake Preshared AESKey		String							Sets the preshared AES key
;				 : All					Handshake Preshared RSAKey		Array/Binary					Parent or Accept client require an Array [0] = private [1] = public. The connect client requires the public key in binary.
;				 : Connect Client		Handshake Enable Preshared AES	True / False (Bool)				Enables or Disables the handshake mode. (Default False)
;				 : Connect Client		Handshake Enable Preshared RSA	True / False (Bool)				Enables or Disables the handshake mode. (Default False)
;				 : Connect Client		Handshake Enable Random RSA		True / False (Bool)				Enables or Disables the handshake mode. (Default True)
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_SetOption(Const $hSocket, $sOption, $sData)
	__Trace_FuncIn("_netcode_SetOption", $hSocket, $sOption, $sData)

	if __netcode_CheckSocket($hSocket) == 0 Then
		__Trace_Error(-2, 0, "Unknown Socket")
		Return SetError(-2, 0, __Trace_FuncOut("_netcode_SetOption", False))
	EndIf

	Switch $sOption

		Case "Encryption"
			If Not IsBool($sData) Then
				__Trace_Error(2, 0, "Data needs to be of type Bool", "", $sOption, VarGetType($sData))
				Return SetError(2, 0, __Trace_FuncOut("_netcode_SetOption", False)) ; $sData need to be of type Bool (True or False)
			EndIf

			__netcode_SocketSetPacketEncryption($hSocket, $sData)
			Return __Trace_FuncOut("_netcode_SetOption", True)

		Case "Handshake Method" ; parent or accept client
			_netcode_CheckSocket($hSocket)
			If @extended == 2 Then ; socket is connect client
				__Trace_Error(1, 0, "Wrong Socket type", "", $sOption)
				Return SetError(1, 0, __Trace_FuncOut("_netcode_SetOption", False))
			EndIf

			Switch $sData

				Case "RandomRSA" ; default
					__netcode_SocketSetHandshakeMode($hSocket, "RandomRSA")

				Case "PresharedAESKey" ; the AES key is preshared and just needs to be verified similiar to the auth stage
					__netcode_SocketSetHandshakeMode($hSocket, "PresharedAESKey")

				Case "PresharedRSAKey" ; the RSA public key is preshared with the Client
					__netcode_SocketSetHandshakeMode($hSocket, "PresharedRSAKey")

				Case Else
					; ~ todo

			EndSwitch

		Case "Handshake Custom"
			; $sData needs to contain the callback
			; ~ todo


		Case "Handshake Preshared AESKey" ; parent, accept or connect client
			; needs to be of type string
			if Not IsString($sData) Then
				__Trace_Error(2, 0, "Data needs to be of type String", "", $sOption, VarGetType($sData))
				Return SetError(2, 0, __Trace_FuncOut("_netcode_SetOption", False))
			EndIf

			__netcode_SocketSetHandshakeExtra($hSocket, $sData)

		Case "Handshake Preshared RSAKey" ; parent, accept or connect client
			; parent and accept clients need to give an array containing the priv at [0] and the pub at [1].
			; connect client needs to give a binary containing the pub key.

			_netcode_CheckSocket($hSocket)
			Switch @extended

				Case 0, 1 ; if parent or accept client
					If Not IsArray($sData) Then
						__Trace_Error(2, 0, "Data needs to be of type Array", "", $sOption, VarGetType($sData))
						Return SetError(2, 0, __Trace_FuncOut("_netcode_SetOption", False))
					EndIf

					__netcode_SocketSetHandshakeExtra($hSocket, $sData)

				Case 2 ; if connect client

					If Not IsBinary($sData) Then
						__Trace_Error(2, 0, "Data needs to be of type Binary", "", $sOption, VarGetType($sData))
						Return SetError(2, 0, __Trace_FuncOut("_netcode_SetOption", False))
					EndIf

					__netcode_SocketSetHandshakeExtra($hSocket, $sData)

			EndSwitch


		Case "Handshake Enable Preshared AES" ; connect client only - disabled by default
			_netcode_CheckSocket($hSocket)
			Switch @extended

				Case 0, 1
					__Trace_Error(1, 0, "Wrong Socket type", "", $sOption)
					Return SetError(1, 0, __Trace_FuncOut("_netcode_SetOption", False))

				Case 2

					If Not IsBool($sData) Then
						__Trace_Error(2, 0, "Data needs to be of type Bool", "", $sOption, VarGetType($sData))
						Return SetError(2, 0, __Trace_FuncOut("_netcode_SetOption", False))
					EndIf

					__netcode_SocketSetHandshakeModeEnable($hSocket, "PresharedAESKey", $sData)

			EndSwitch


		Case "Handshake Enable Preshared RSA" ; connect client only - disabled by default
			_netcode_CheckSocket($hSocket)
			Switch @extended

				Case 0, 1
					__Trace_Error(1, 0, "Wrong Socket type", "", $sOption)
					Return SetError(1, 0, __Trace_FuncOut("_netcode_SetOption", False))

				Case 2

					If Not IsBool($sData) Then
						__Trace_Error(2, 0, "Data needs to be of type Bool", "", $sOption, VarGetType($sData))
						Return SetError(2, 0, __Trace_FuncOut("_netcode_SetOption", False))
					EndIf

					__netcode_SocketSetHandshakeModeEnable($hSocket, "PresharedRSAKey", $sData)

			EndSwitch

		Case "Handshake Enable Random RSA" ; connect client only - enabled by default
			_netcode_CheckSocket($hSocket)
			Switch @extended

				Case 0, 1
					__Trace_Error(1, 0, "Wrong Socket type", "", $sOption)
					Return SetError(1, 0, __Trace_FuncOut("_netcode_SetOption", False))

				Case 2

					If Not IsBool($sData) Then
						__Trace_Error(2, 0, "Data needs to be of type Bool", "", $sOption, VarGetType($sData))
						Return SetError(2, 0, __Trace_FuncOut("_netcode_SetOption", False))
					EndIf

					__netcode_SocketSetHandshakeModeEnable($hSocket, "RandomRSA", $sData)

			EndSwitch

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

		Case "Seed"
			If __netcode_CheckSocket($hSocket) <> 1 Then
				If _netcode_StageGetError($hSocket, "Syn") <> -1 Then
					__Trace_Error(3, 0, "Socket already has a Shared Seed", "", $sOption)
					Return SetError(3, 0, __Trace_FuncOut("_netcode_SetOption", False))
				EndIf
			EndIf

			if Not IsNumber($sData) Then
				__Trace_Error(2, 0, "Data needs to be of type Int32, Int64 or Double", "", $sOption, VarGetType($sData))
				Return SetError(2, 0, __Trace_FuncOut("_netcode_SetOption", False))
			EndIf

			_storageS_Overwrite($hSocket, '_netcode_SocketSeed', $sData)


		Case Else
			__Trace_Error(-1, 0, "Unknown Option", "", $sOption, $sData)
			Return SetError(-1, 0, __Trace_FuncOut("_netcode_SetOption", False)) ; unknown option


	EndSwitch

	Return __Trace_FuncOut("_netcode_SetOption")
EndFunc   ;==>_netcode_SetOption


; unfinished
; marked for recoding
; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_PresetOption
; Description ...: Sets Default Options. To be Overhauled
; Syntax ........: _netcode_PresetOption($sOption, $sData)
; Parameters ....: $sOption             - String option name
;                  $sData               - Variable option parameter
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
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
; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_SetInternalOption
; Description ...: Ignore
; Syntax ........: _netcode_SetInternalOption($sOption, $sData)
; Parameters ....: $sOption             - a string value.
;                  $sData               - a string value.
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
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
; =============================================================================================================================================
; =============================================================================================================================================
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
; reminder. the data TO BE executed needs to be deleted from the execution buffer before the data is executed.
; otherwise, in the case that _netcode_Loop() is called within the event, the data is simply going to be reexecuted.
; That would be a bug that could cause recursion issues.
Func __netcode_ExecutePackets(Const $hSocket)
	__Trace_FuncIn("__netcode_ExecutePackets", $hSocket)

	If _netcode_GetSocketOnHold($hSocket) Then Return __Trace_FuncOut("__netcode_ExecutePackets") ; this socket is on hold

	Local $arPackages = __netcode_SocketGetExecutionBufferValues($hSocket)
	Local $nCurrentBufferIndex = @error
	Local $nCurrentIndex = _storageS_Read($hSocket, '_netcode_ExecutionIndex')
	Local $sID = ""
	Local $nExecutingIndex = 0

	; if the socket is already gone at this point then as such also is the execution buffer
	If Not IsArray($arPackages) Then Return __Trace_FuncOut("__netcode_ExecutePackets")

	While True

		if $arPackages[$nCurrentIndex][0] = '' Then ExitLoop

		; remove data from buffer
		__netcode_SocketRemExecutionBufferValue($hSocket, $nCurrentIndex)

		; temporary store index that is going to be executed
		$nExecutingIndex = $nCurrentIndex

		; highten index to save it before we execute the event
		$nCurrentIndex += 1
		if $nCurrentIndex = 1000 Then $nCurrentIndex = 0

		; update the execution index
		_storageS_Overwrite($hSocket, '_netcode_ExecutionIndex', $nCurrentIndex)

		; execute event
		__netcode_ExecuteEvent($hSocket, $arPackages[$nExecutingIndex][0], $arPackages[$nExecutingIndex][1])

		; if the event disconnected the socket or released it then return since there is no longer a purpose to execute more or todo anything else
		if __netcode_CheckSocket($hSocket) == 0 Then Return __Trace_FuncOut("__netcode_ExecutePackets")

		; add executed index
		$sID &= $nExecutingIndex & ','

	WEnd

	if $__net_bPacketConfirmation Then
		if $sID <> "" Then
			$sID = StringTrimRight($sID, 1) ; cutting the last ','
			_netcode_TCPSend($hSocket, 'netcode_internal', 'packet_confirmation|' & $sID, False)
		EndIf
	EndIf

	__Trace_FuncOut("__netcode_ExecutePackets")
EndFunc   ;==>__netcode_ExecutePackets

Func __netcode_SocketSetStageErrorAndExtended(Const $hSocket, $sStageName, $nError = 0 , $nExtended = 0)
	Local $arData[2] = [$nError,$nExtended]
	_storageS_Overwrite($hSocket, '_netcode_StageErrAndExt_' & $sStageName, $arData)
EndFunc

Func __netcode_SocketSetStageExtraInformation(Const $hSocket, $sStageName, $vData)
	_storageS_Overwrite($hSocket, '_netcode_StageExtraInfo_' & $sStageName, $vData)
EndFunc

; staging system
; note for me: generally i need a fast packet router, have to see if i can come up with a faster variant
Func __netcode_ManagePackages(Const $hSocket, $sPackages)
	__Trace_FuncIn("__netcode_ManagePackages", $hSocket, "$sPackages")

	Switch __netcode_SocketGetManageMode($hSocket)

		Case 0 ; 'auth'
			__netcode_ManageAuth($hSocket, $sPackages)

		Case 1 ; 'presyn'
			__netcode_ManagePreSyn($hSocket, $sPackages)

		Case 2 ; 'handshake'
			__netcode_ManageHandshake($hSocket, $sPackages)

		Case 3 ; 'syn'
			__netcode_ManageSyn($hSocket, $sPackages)

		Case 4 ; 'user'
			__netcode_ManageUser($hSocket, $sPackages)

		Case 5 ; 'MFA'
			; ~ todo

		Case 9 ; ready stage
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
			__Trace_Error(1, 0, "CRITICAL: Socket has invalid Manage mode")
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

		Case 'presyn'
			$nMode = 1

		Case 'handshake'
			$nMode = 2

		Case 'syn'
			$nMode = 3

		Case 'user'
			$nMode = 4

		Case 'mfa'
			$nMode = 5 ; not included yet

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

	if $nMode = 10 Then
		Local $arBuffer = _storageS_Read($hSocket, '_netcode_PreNetcodeSendBuffer')
		If IsArray($arBuffer) Then

			Local $nArSize = UBound($arBuffer)

			For $i = 0 To $nArSize - 1
				If Not _netcode_TCPSend($hSocket, $arBuffer[$i][0], $arBuffer[$i][1], $arBuffer[$i][2]) Then
					__Trace_LogError(0, 0, "Prenetcode Stage Buffer could not be successfully send for Event: " & $arBuffer[0])
				EndIf
			Next

			_storageS_Overwrite($hSocket, '_netcode_PreNetcodeSendBuffer', Null)
		EndIf
	EndIf

	Return __Trace_FuncOut("__netcode_SocketSetManageMode", True)
EndFunc   ;==>__netcode_SocketSetManageMode

Func __netcode_SocketGetManageMode(Const $hSocket)
	__Trace_FuncIn("__netcode_SocketGetManageMode", $hSocket)

	Return __Trace_FuncOut("__netcode_SocketGetManageMode", _storageS_Read($hSocket, '_netcode_SocketManageMode'))
EndFunc   ;==>__netcode_SocketGetManageMode

; the connect client uses the socket seed as a preshared key and encrypts the string 'netcode' with it.
; the accept client tries to decrypt the text with its socket seed. if both password matched then the text can be decrypted.
; and the stage is done.
; the generall purpose of this stage is it, to make sure that both parties actually use netcode and that both parties use the same
; pre handshake encryption key. So that all data that is transmitted before the handshake is encrypted.
Func __netcode_ManageAuth(Const $hSocket, $sPackages)
	__Trace_FuncIn("__netcode_ManageAuth", "$sPackages")

	Local $nSocketIs = 1
	Local $hParent = __netcode_ClientGetParent($hSocket)
	if $hParent == "000" Then $nSocketIs = 2

	Switch $nSocketIs

		Case 1 ; if accept client

			; create pre handshake key from the seed
			Local $hPassword = __netcode_AESDeriveKey(_storageS_Read($hSocket, '_netcode_SocketSeed'), 'prehandshake')

			; set extra info
			__netcode_SocketSetStageExtraInformation($hSocket, 'auth', _storageS_Read($hSocket, '_netcode_SocketSeed'))

			; check if we can decrypt the package
			$sPackages = __netcode_AESDecrypt(StringToBinary($sPackages), $hPassword)

			; check the string
			if $sPackages <> "netcode" Then

				__netcode_SocketSetStageErrorAndExtended($hSocket, 'auth', 1, 0)

				__netcode_TCPCloseSocket($hSocket)
				__netcode_RemoveSocket($hSocket)

				__Trace_Error(1, 0, "Pre shared key could not be verified")
				Return __Trace_FuncOut("__netcode_ManageAuth")
			EndIf

			; store pre handshake key
			__netcode_SocketSetPacketEncryptionPassword($hSocket, $hPassword)

			; call stage to be done
			__netcode_SocketSetStageErrorAndExtended($hSocket, 'auth', 0, 0)
			__netcode_ExecuteEvent($hSocket, "connection", 'auth')

			; set next stage
			__netcode_SocketSetManageMode($hSocket, 'presyn')

			; trigger next stage
			__netcode_ManagePreSyn($hSocket, Null)

			Return __Trace_FuncOut("__netcode_ManageAuth")


		Case 2 ; if connect client

			; create pre handshake key from the seed
			Local $hPassword = __netcode_AESDeriveKey(_storageS_Read($hSocket, '_netcode_SocketSeed'), 'prehandshake')

			; set extra info
			__netcode_SocketSetStageExtraInformation($hSocket, 'auth', _storageS_Read($hSocket, '_netcode_SocketSeed'))

			; store pre handshake key
			__netcode_SocketSetPacketEncryptionPassword($hSocket, $hPassword)

			; encrypt auth string
			Local $sData = __netcode_AESEncrypt("netcode", $hPassword)

			; send encrypted auth string
			__netcode_TCPSend($hSocket, $sData)

			; call stage to be done
			__netcode_SocketSetStageErrorAndExtended($hSocket, 'auth', 0, 0)
			__netcode_ExecuteEvent($hSocket, "connection", 'auth')

			; set next stage
			__netcode_SocketSetManageMode($hSocket, 'presyn')

			Return __Trace_FuncOut("__netcode_ManageAuth")


	EndSwitch

EndFunc

; the accept client creates presyn data. Like which stages have to follow up and which handshake mode to use.
; the connect client then applies the server settings to itself but also checks them. If it allows the settings and
; if the stages are available.
; as of now this stage is useless, since there are no different handshake modes and the stages arent dynamic yet.
; this stage was just implemented for the upcoming stages overhaul.
Func __netcode_ManagePreSyn(Const $hSocket, $sPackages)
	__Trace_FuncIn("__netcode_ManagePreSyn", $hSocket, "$sPackages")

	; get the pre handshake key
	Local $hPassword = __netcode_SocketGetPacketEncryptionPassword($hSocket)

	Local $nSocketIs = 1
	Local $hParent = __netcode_ClientGetParent($hSocket)
	if $hParent == "000" Then $nSocketIs = 2


	Switch $nSocketIs

		Case 1 ; if accept client

			; create presyn option set for the connect client to inherit
			Local $arPreSyn[1][2]

			$arPreSyn[0][0] = "HandshakeMode"
			$arPreSyn[0][1] = __netcode_SocketGetHandshakeMode($hSocket)

			; ~ todo
			; like the handshake mode and the following stage order

			; set extra info
			__netcode_SocketSetStageExtraInformation($hSocket, 'presyn', $arPreSyn)

			; serialize the array
			Local $sData = __netcode_CheckParamAndSerialize($arPreSyn)

			; encrypt the serialized array
			$sData = __netcode_AESEncrypt($sData, $hPassword)

			; send the encrypted data
			__netcode_TCPSend($hSocket, $sData)

			; call the stage
			__netcode_SocketSetStageErrorAndExtended($hSocket, 'presyn', 0, 0)
			__netcode_ExecuteEvent($hSocket, "connection", 'presyn')

			; set next stage
			__netcode_SocketSetManageMode($hSocket, 'handshake')


			Return __Trace_FuncOut("__netcode_ManagePreSyn")


		Case 2 ; if connect client

			; decrypt presyn data
			$sPackages = __netcode_AESDecrypt(StringToBinary($sPackages), $hPassword)

			; if we couldnt decrypt it
			if $sPackages == -1 Then

				__netcode_SocketSetStageErrorAndExtended($hSocket, 'presyn', 1, 0)

				__netcode_TCPCloseSocket($hSocket)
				__netcode_RemoveSocket($hSocket)

				__Trace_Error(1, 0, "Could not decrypt presyn data")
				Return __Trace_FuncOut("__netcode_ManagePreSyn")
			EndIf

			; deserialize presyn data
			Local $arPreSyn = __netcode_CheckParamAndUnserialize(BinaryToString($sPackages))

			; set extra info
			__netcode_SocketSetStageExtraInformation($hSocket, 'presyn', $arPreSyn)

			; if there is presyn data
			Local $nArSize = UBound($arPreSyn)
			If $nArSize > 0 Then

				; then apply it to ourself
				For $i = 0 To $nArSize - 1
					; ~ todo
					; also check here if the presyn data is allowed and if the required stages are present

					If Not __netcode_ManagePreSyn_Inherit($hSocket, $arPreSyn[$i][0], $arPreSyn[$i][1]) Then
						__netcode_SocketSetStageErrorAndExtended($hSocket, 'presyn', 1, 0)

						__netcode_TCPCloseSocket($hSocket)
						__netcode_RemoveSocket($hSocket)

						__Trace_Error(2, 0, "Cannot inherit Option " & $arPreSyn[$i][0] & " " & $arPreSyn[$i][1])
						Return __Trace_FuncOut("__netcode_ManagePreSyn")
					EndIf
				Next

			EndIf

			; if we could then tell the server about it
			Local $sData = __netcode_AESEncrypt("1", $hPassword)
			__netcode_TCPSend($hSocket, $sData)

			; call the stage
			__netcode_SocketSetStageErrorAndExtended($hSocket, 'presyn', 0, 0)
			__netcode_ExecuteEvent($hSocket, "connection", 'presyn')
			; set the next stage

			__netcode_SocketSetManageMode($hSocket, 'handshake')

			Return __Trace_FuncOut("__netcode_ManagePreSyn")

	EndSwitch

EndFunc

Func __netcode_ManagePreSyn_Inherit(Const $hSocket, $sOption, $vData)

	Switch $sOption

		Case "HandshakeMode"
			; check if the mode is present
			; ~ todo

			; check if the mode is enabled
			If Not __netcode_SocketGetHandshakeModeEnable($hSocket, $vData) Then Return False

			__netcode_SocketSetHandshakeMode($hSocket, $vData)

			Return True

		Case Else
			; ~ todo

	EndSwitch

EndFunc

; the accept clients here starts the preset handshake mode.
; as of know only a single mode is present.
Func __netcode_ManageHandshake(Const $hSocket, $sPackages)
	__Trace_FuncIn("__netcode_ManageHandshake", "$sPackages")

	; get the pre handshake key
	Local $hPassword = __netcode_SocketGetPacketEncryptionPassword($hSocket)
	Local $bReturn = False

	Local $nSocketIs = 1
	Local $hParent = __netcode_ClientGetParent($hSocket)
	if $hParent == "000" Then $nSocketIs = 2


	Switch $nSocketIs

		Case 1 ; if accept client

			; perform the preset handshake mode here
			; ~ todo
			; like preshared key
			; or send the preset public key + cert for TLS
			; or create a random rsa set

			Switch __netcode_SocketGetHandshakeMode($hSocket)

				Case "RandomRSA"
					$bReturn = __netcode_ManageHandshake_SubRandomRSA($hSocket, $nSocketIs, $hPassword, $sPackages)

				Case "PresharedAESKey"
					$bReturn = __netcode_ManageHandshake_SubPreSharedAESKey($hSocket, $nSocketIs, $hPassword, $sPackages)

				Case "PresharedRSAKey"
					$bReturn = __netcode_ManageHandshake_SubPreSharedRSASKey($hSocket, $nSocketIs, $hPassword, $sPackages)

;~ 				Case "Custom"
;~ 					; ~ todo

;~ 				Case Else
					; ~ todo


			EndSwitch


			if $bReturn == False Then

				__netcode_TCPCloseSocket($hSocket)
				__netcode_RemoveSocket($hSocket)

				__Trace_Error(1, 0, "Handshake failed")

			ElseIf $bReturn == True Then
				; call the stage
				__netcode_SocketSetStageErrorAndExtended($hSocket, 'handshake', 0, 0)
				__netcode_ExecuteEvent($hSocket, "connection", 'handshake')

				; set next stage
				__netcode_SocketSetManageMode($hSocket, 'syn')

				; trigger the next stage
				__netcode_ManageSyn($hSocket, Null)
			EndIf


		Case 2 ; if connect client

			; perform the preset handshake mode here
			; ~ todo

			Switch __netcode_SocketGetHandshakeMode($hSocket)

				Case "RandomRSA"
					$bReturn = __netcode_ManageHandshake_SubRandomRSA($hSocket, $nSocketIs, $hPassword, $sPackages)

				Case "PresharedAESKey"
					$bReturn = __netcode_ManageHandshake_SubPreSharedAESKey($hSocket, $nSocketIs, $hPassword, $sPackages)

				Case "PresharedRSAKey"
					$bReturn = __netcode_ManageHandshake_SubPreSharedRSASKey($hSocket, $nSocketIs, $hPassword, $sPackages)

;~ 				Case "Custom"
;~ 					; ~ todo

;~ 				Case Else
					; ~ todo


			EndSwitch


			if $bReturn == False Then

				__netcode_TCPCloseSocket($hSocket)
				__netcode_RemoveSocket($hSocket)

				__Trace_Error(1, 0, "Handshake failed")

			ElseIf $bReturn == True Then

				; call the stage
				__netcode_SocketSetStageErrorAndExtended($hSocket, 'handshake', 0, 0)
				__netcode_ExecuteEvent($hSocket, "connection", 'handshake')

				; set next stage
				__netcode_SocketSetManageMode($hSocket, 'syn')
			EndIf




	EndSwitch

	__Trace_FuncOut("__netcode_ManageHandshake")
EndFunc

; the accept client creates a priv and pub RSA key and sends the pub to the connect client.
; the connect client creates a random session key, makes it the new packet encryption key, encrypts it with the pub rsa key and sends it back.
; the accept client then decrypts it and makes the session key the new packet encryption key.
; not man in the middle proof.
Func __netcode_ManageHandshake_SubRandomRSA(Const $hSocket, $nSocketIs, $hPassword, $vData = "")
	__Trace_FuncIn("__netcode_ManageHandshake_SubRandomRSA", $hSocket, $nSocketIs, "$hPassword", "$vData")

	Local $nSubStage = _storageS_Read($hSocket, '_netcode_handshake_SubRandomRSAStage')
	if $nSubStage == False Then $nSubStage = 0

	Switch $nSocketIs

		Case 1 ; if accept client

			Switch $nSubStage

				Case 0 ; create rsa keys

					; create rsa keys
					Local $arKeyPairs = __netcode_CryptGenerateRSAKeyPair(2048) ; 0 private | 1 public

					; store my rsa keys
					__netcode_SocketSetMyRSA($hSocket, $arKeyPairs[0], $arKeyPairs[1])

					; encrypt the public key with the prehandshake key
					Local $sData = __netcode_AESEncrypt($arKeyPairs[1], $hPassword)

					; send it to the connect client
					__netcode_TCPSend($hSocket, $sData)

					; set next sub stage
					_storageS_Overwrite($hSocket, '_netcode_handshake_SubRandomRSAStage', 1)

					; return Null
					Return __Trace_FuncOut("__netcode_ManageHandshake_SubRandomRSA", Null)

				Case 1 ; decrypt rsa response from connect client to get the new packet encryption pw

					; decrypt AES encrypted RSA encrypted key
					$vData = __netcode_AESDecrypt(StringToBinary($vData), $hPassword)

					; get our priv key
					Local $sPrivateKey = __netcode_SocketGetMyRSA($hSocket)

					; decrypt the session key with our priv key
					$vData = __netcode_RSADecrypt($vData, $sPrivateKey)

					; if we cant decrypt it then return False
					if $vData == "" Then
						__netcode_SocketSetStageErrorAndExtended($hSocket, 'handshake', 1, 0)
						Return __Trace_FuncOut("__netcode_ManageHandshake_SubRandomRSA", False)
					EndIf

					; set extra info
					__netcode_SocketSetStageExtraInformation($hSocket, 'handshake', BinaryToString($vData))

					; destroy pre handshake key
					__netcode_CryptDestroyKey($hPassword)

					; derive the new key
					$hPassword = __netcode_AESDeriveKey(BinaryToString($vData), 'packetencryption')

					; store it
					__netcode_SocketSetPacketEncryptionPassword($hSocket, $hPassword)

					; return true
					Return __Trace_FuncOut("__netcode_ManageHandshake_SubRandomRSA", True)

			EndSwitch


		Case 2 ; if connect client

			; decrypt public rsa key from the server
			Local $sPublicKey = __netcode_AESDecrypt(StringToBinary($vData), $hPassword)

			; if we could not decrypt it then return false
			if $sPublicKey == -1 Then
				__netcode_SocketSetStageErrorAndExtended($hSocket, 'handshake', 2, 0)
				Return __Trace_FuncOut("__netcode_ManageHandshake_SubRandomRSA", False)
			EndIf

			; store the servers public key
			__netcode_SocketSetOtherRSA($hSocket, $sPublicKey)

			; create a random session pw
			Local $sPassword = __netcode_RandomPW(40, 4)

			; set extra info
			__netcode_SocketSetStageExtraInformation($hSocket, 'handshake', $sPassword)

			; encrypt the password with the public key
			Local $sData = __netcode_RSAEncrypt($sPassword, $sPublicKey)

			; if we could not encrypt the session key then return False
			if $sData == "" Then
				__netcode_SocketSetStageErrorAndExtended($hSocket, 'handshake', 3, 0)
				Return __Trace_FuncOut("__netcode_ManageHandshake_SubRandomRSA", False)
			EndIf

			; encrypt the rsa encrypted key with the preshared key
			$sData = __netcode_AESEncrypt($sData, $hPassword)

			; destroy the pre handshake key
			__netcode_CryptDestroyKey($hPassword)

			; make it our new packet encryption key
			$hPassword = __netcode_AESDeriveKey($sPassword, 'packetencryption')
			__netcode_SocketSetPacketEncryptionPassword($hSocket, $hPassword)

			; send the encrypted session key to the server
			__netcode_TCPSend($hSocket, $sData)

			; return True
			Return __Trace_FuncOut("__netcode_ManageHandshake_SubRandomRSA", True)


	EndSwitch

EndFunc

Func __netcode_ManageHandshake_SubPreSharedAESKey(Const $hSocket, $nSocketIs, $hPassword, $vData = "")

	Local $nSubStage = _storageS_Read($hSocket, '_netcode_handshake_SubPreSharedAESKeyStage')
	if $nSubStage == False Then $nSubStage = 0

	Switch $nSocketIs

		Case 1 ; if accept client

			Switch $nSubStage

				Case 0 ; request the connect client to send a encrypted sample text
					__netcode_TCPSend($hSocket, __netcode_AESEncrypt("PreSharedAESKey", $hPassword))

					; set next sub stage
					_storageS_Overwrite($hSocket, '_netcode_handshake_SubPreSharedAESKeyStage', 1)
					Return Null


				Case 1 ; try to decrypt the sample text with the preshared key
					; destroy the old key
					__netcode_CryptDestroyKey($hPassword)

					; take new key from storage
					Local $sPassword = __netcode_SocketGetHandshakeExtra($hSocket)

					if $sPassword == False Then
						__Trace_Error(0, 0, "Missing Password for the PreSharedAESKey handshake mode")
						Return False
					EndIf

					; derive the new key
					$hPassword = __netcode_AESDeriveKey($sPassword, 'packetencryption')

					; make it the new packet encryption key
					__netcode_SocketSetPacketEncryptionPassword($hSocket, $hPassword)

					; try to decrypt the sample text
					$vData = __netcode_AESDecrypt(StringToBinary($vData), $hPassword)

					; check sample test
					if $vData <> "PreSharedAESKey" Then

						Return False
					EndIf

					__netcode_SocketSetStageExtraInformation($hSocket, 'handshake', $sPassword)

					Return True


			EndSwitch


		Case 2 ; if connect client

			$vData = __netcode_AESDecrypt(StringToBinary($vData), $hPassword)

			; check if the accept client send the right string
			if BinaryToString($vData) <> "PreSharedAESKey" Then

				Return False
			EndIf

			; destroy the old key
			__netcode_CryptDestroyKey($hPassword)

			; take the new key from the storage
			Local $sPassword = __netcode_SocketGetHandshakeExtra($hSocket)

			; check if the preshared aes key was set
			if $sPassword == False Then
				__Trace_Error(0, 0, "Missing Password for the PreSharedAESKey handshake mode")
				Return False
			Endif

			; derive the new key
			$hPassword = __netcode_AESDeriveKey($sPassword, 'packetencryption')

			; make it our packet encryption key
			__netcode_SocketSetPacketEncryptionPassword($hSocket, $hPassword)

			; encrypt the sample text with it
			Local $sData = __netcode_AESEncrypt("PreSharedAESKey", $hPassword)

			; send it
			__netcode_TCPSend($hSocket, $sData)

			__netcode_SocketSetStageExtraInformation($hSocket, 'handshake', $sPassword)

			Return True


	EndSwitch

EndFunc

Func __netcode_ManageHandshake_SubPreSharedRSASKey(Const $hSocket, $nSocketIs, $hPassword, $vData = "")

	Local $nSubStage = _storageS_Read($hSocket, '_netcode_handshake_SubPreSharedRSAKeyStage')
	if $nSubStage == False Then $nSubStage = 0

	Switch $nSocketIs

		Case 1 ; accept client

			Switch $nSubStage

				Case 0 ; request the connect client to create a session key and encrypt it with preshared public key

					__netcode_TCPSend($hSocket, __netcode_AESEncrypt("PreSharedRSAKey", $hPassword))

					; set next sub stage
					_storageS_Overwrite($hSocket, '_netcode_handshake_SubPreSharedRSAKeyStage', 1)
					Return Null

				Case 1 ; decrypt the session key

					; decrypt to the rsa text
					$vData = __netcode_AESDecrypt(StringToBinary($vData), $hPassword)

					; get the priv key
					Local $sPrivateKey = __netcode_SocketGetHandshakeExtra($hSocket)

					if $sPrivateKey == False Then
						__Trace_Error(0, 0, "Missing Private key for the PreSharedAESKey handshake mode")
						Return False
					EndIf

					$sPrivateKey = $sPrivateKey[0]

					; decrypt the rsa text
					$vData = BinaryToString(__netcode_RSADecrypt($vData, $sPrivateKey))

					if $vData == "" Then

						Return False
					EndIf

					; destroy the old key
					__netcode_CryptDestroyKey($hPassword)

					; derive the new
					$hPassword = __netcode_AESDeriveKey($vData, 'packetencryption')

					; make it the session key
					__netcode_SocketSetPacketEncryptionPassword($hSocket, $hPassword)

					__netcode_SocketSetStageExtraInformation($hSocket, 'handshake', $vData)

					Return True



			EndSwitch


		Case 2 ; connect client

			; decrypt the request
			$vData = __netcode_AESDecrypt(StringToBinary($vData), $hPassword)

			; check the request string
			if BinaryToString($vData) <> "PreSharedRSAKey" Then

				Return False
			EndIf


			; read the public from the storage
			Local $sPublicKey = __netcode_SocketGetHandshakeExtra($hSocket)

			; check the public key
			if $sPublicKey == False Then
				__Trace_Error(0, 0, "Missing Public key for the PreSharedRSAKey handshake mode")
				Return False
			EndIf

			; create session key
			Local $sPassword = __netcode_RandomPW(40, 4)


			; RSA encrypt the session key
			Local $sData = __netcode_RSAEncrypt($sPassword, $sPublicKey)


			; encrypt the rsa text with the preshared
			$sData = __netcode_AESEncrypt($sData, $hPassword)

			; send it
			__netcode_TCPSend($hSocket, $sData)

			; destroy the old key
			__netcode_CryptDestroyKey($hPassword)

			; derive the new key
			$hPassword = __netcode_AESDeriveKey($sPassword, 'packetencryption')

			; make it the session key
			__netcode_SocketSetPacketEncryptionPassword($hSocket, $hPassword)

			__netcode_SocketSetStageExtraInformation($hSocket, 'handshake', $sPassword)

			Return True



	EndSwitch

EndFunc


; the accept client reads its settings, like the maximum recv buffer size, the session seed etc. and sends it to the connect client.
; the connect client inherits these server options but also verifies them.
; as of now there isnt much to syn. _netcode just doesnt feature much toggleable options yet.
Func __netcode_ManageSyn(Const $hSocket, $sPackages)
	__Trace_FuncIn("__netcode_ManageSyn")

	; get the pre handshake key
	Local $hPassword = __netcode_SocketGetPacketEncryptionPassword($hSocket)

	Local $nSocketIs = 1
	Local $hParent = __netcode_ClientGetParent($hSocket)
	if $hParent == "000" Then $nSocketIs = 2

	Switch $nSocketIs

		Case 1 ; accept client

			; create syn data
			Local $bUserStage = "False"
			If IsArray(_netcode_SocketGetUserManagement(__netcode_ClientGetParent($hSocket))) Then $bUserStage = "True"
			Local $nSessionSeed = Number(__netcode_RandomPW(12, 1))

			Local $arSynData[5][2]
			$arSynData[0][0] = "MaxRecvBufferSize"
			$arSynData[0][1] = _storageS_Read($hSocket, '_netcode_MaxRecvBufferSize')
			$arSynData[1][0] = "DefaultRecvLen"
			$arSynData[1][1] = _storageS_Read($hSocket, '_netcode_DefaultRecvLen')
			$arSynData[2][0] = "Encryption"
			$arSynData[2][1] = __netcode_SocketGetPacketEncryption(__netcode_ClientGetParent($hSocket))
			$arSynData[3][0] = "Seed"
			$arSynData[3][1] = $nSessionSeed
			$arSynData[4][0] = "UserStage"
			$arSynData[4][1] = $bUserStage

			; set extra info
			__netcode_SocketSetStageExtraInformation($hSocket, 'syn', $arSynData)

			; make the session seed also our own
			__netcode_SeedingClientStrings($hSocket, $nSessionSeed)

			; serialize the syn data
			Local $sData = __netcode_CheckParamAndSerialize($arSynData)

			; encrypt syn data
			$sData = __netcode_AESEncrypt($sData, $hPassword)

			; send the encrypted syn data
			__netcode_TCPSend($hSocket, $sData)

			; call the stage
			__netcode_SocketSetStageErrorAndExtended($hSocket, 'syn', 0, 0)
			__netcode_ExecuteEvent($hSocket, "connection", 'syn')

			; set next stage
			If $bUserStage == "True" Then
				__netcode_SocketSetManageMode($hSocket, 'user')
			Else
				__netcode_SocketSetManageMode($hSocket, 'ready')
			EndIf

			Return __Trace_FuncOut("__netcode_ManageSyn")

		Case 2 ; connect client

			; decrypt the syn data
			$sPackages = __netcode_AESDecrypt(StringToBinary($sPackages), $hPassword)

			; if we couldnt decrypt it
			if $sPackages == -1 Then
				__netcode_SocketSetStageErrorAndExtended($hSocket, 'syn', 1, 0)

				__netcode_TCPCloseSocket($hSocket)
				__netcode_RemoveSocket($hSocket)

				__Trace_Error(1, 0, "Could not decrypt data for the Syn stage")
				Return __Trace_FuncOut("__netcode_ManageSyn")
			EndIf

			; deserialize syn data
			Local $arSynData = __netcode_CheckParamAndUnserialize(BinaryToString($sPackages))

			; set extra info
			__netcode_SocketSetStageExtraInformation($hSocket, 'syn', $arSynData)

			; check and inherit settings
			$bUserStage = False

			Local $nArSize = UBound($arSynData)
			if $nArSize > 0 Then

				For $i = 0 To $nArSize - 1

					if $arSynData[$i][0] = "UserStage" Then
						$bUserStage = __netcode_SetVarType($arSynData[$i][1], "Bool")
						ContinueLoop
					EndIf

					__netcode_ManageSyn_Inherit($hSocket, $arSynData[$i][0], $arSynData[$i][1])

				Next

			EndIf

			; call the stage
			__netcode_SocketSetStageErrorAndExtended($hSocket, 'syn', 0, 0)
			__netcode_ExecuteEvent($hSocket, "connection", 'syn')

			; set next stage
			if $bUserStage Then
				__netcode_SocketSetManageMode($hSocket, 'user')

				; trigger user stage
				__netcode_ManageUser($hSocket, Null)
			Else
				__netcode_SocketSetManageMode($hSocket, 'netcode')

				; send a void packet, so that the server gets out of the ready stage
				_netcode_TCPSend($hSocket, 'netcode_internal', "0")

				; call the finish netcode stage
				__netcode_ExecuteEvent($hSocket, "connection", 'netcode')
			EndIf

			Return __Trace_FuncOut("__netcode_ManageSyn")
	EndSwitch

EndFunc

Func __netcode_ManageSyn_Inherit(Const $hSocket, $sPreSyn, $sData)
	__Trace_FuncIn("__netcode_ManageSyn_Inherit", $hSocket, $sPreSyn, $sData)
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
			__Trace_Error(1, 0, 'Rule: "' & $sPreSyn & '" with setting: "' & $sData & '" is unknown')


	EndSwitch
	__Trace_FuncOut("__netcode_ManageSyn_Inherit")
EndFunc   ;==>__netcode_ManageSyn_Inherit


Func __netcode_ManageUser(Const $hSocket, $sPackages)
	__Trace_FuncIn("__netcode_ManageUser")

	; get the pre handshake key
	Local $hPassword = __netcode_SocketGetPacketEncryptionPassword($hSocket)

	Local $nSocketIs = 1
	Local $hParent = __netcode_ClientGetParent($hSocket)
	if $hParent == "000" Then $nSocketIs = 2

	Local $nStage = _storageS_Read($hSocket, '_netcode_user_ConnectClientStage')
	if $nStage == False Then $nStage = 0


	Switch $nSocketIs

		Case 1 ; if accept client

			; decrypt username and password
			$sPackages = __netcode_AESDecrypt(StringToBinary($sPackages), $hPassword)

			; if we couldnt decrypt it then disconnect
			if $sPackages == -1 Then
				__netcode_SocketSetStageErrorAndExtended($hSocket, 'user', 1, 1)

				__netcode_TCPCloseSocket($hSocket)
				__netcode_RemoveSocket($hSocket)

				__Trace_Error(1, 1, "Could not decrypt username and password")
				Return __Trace_FuncOut("__netcode_ManageUser")
			EndIf

			; create userarray
			Local $arUserData = StringSplit(BinaryToString($sPackages), ':', 3)

			; set extra info
			__netcode_SocketSetStageExtraInformation($hSocket, 'user', $arUserData[0])

			; get user db
			Local $arUserDB = __netcode_GetUserDB($hParent)

			; find user index
			Local $nIndex = __netcode_FindUser($arUserDB, BinaryToString($arUserData[0]))

			; if the user doesnt exists then disconnect
			if $nIndex == -1 Then
				__netcode_SocketSetStageErrorAndExtended($hSocket, 'user', 1, 2)

				; send info
				__netcode_TCPSend($hSocket, __netcode_AESEncrypt("Wrong", $hPassword))

				; do not disconnect so that the user can get a info why his login failed
;~ 				__netcode_TCPCloseSocket($hSocket)
;~ 				__netcode_RemoveSocket($hSocket)

				__Trace_Error(1, 2, "Wrong login details")
				Return __Trace_FuncOut("__netcode_ManageUser")
			EndIf

			; if wrong password
			if $arUserDB[$nIndex][1] <> $arUserData[1] Then
				__netcode_SocketSetStageErrorAndExtended($hSocket, 'user', 1, 3)

				; send info
				__netcode_TCPSend($hSocket, __netcode_AESEncrypt("Wrong", $hPassword))

				; do not disconnect so that the user can get a info why his login failed
;~ 				__netcode_TCPCloseSocket($hSocket)
;~ 				__netcode_RemoveSocket($hSocket)

				__Trace_Error(1, 3, "Wrong login details")
				Return __Trace_FuncOut("__netcode_ManageUser")
			EndIf

			; check user state
			Switch $arUserDB[$nIndex][2]

				Case 'OnHold'
					__netcode_TCPSend($hSocket, __netcode_AESEncrypt("OnHold", $hPassword))
					__netcode_SocketSetStageErrorAndExtended($hSocket, 'user', 1, 4)
					__Trace_Error(1, 4, "Account OnHold")
					Return __Trace_FuncOut("__netcode_ManageUser")

				Case 'Banned'
					__netcode_TCPSend($hSocket, __netcode_AESEncrypt("Banned", $hPassword))
					__netcode_SocketSetStageErrorAndExtended($hSocket, 'user', 1, 5)
					__Trace_Error(1, 5, "Account Banned")
					Return __Trace_FuncOut("__netcode_ManageUser")

				Case 'Blocked'
					__Trace_Error(1, 6, "Account Blocked")
					__netcode_SocketSetStageErrorAndExtended($hSocket, 'user', 1, 6)
					__netcode_TCPCloseSocket($hSocket)
					__netcode_RemoveSocket($hSocket)
					Return __Trace_FuncOut("__netcode_ManageUser")

			EndSwitch

			; set username to socket
			__netcode_SocketSetUser($hSocket, BinaryToString($arUserData[0]))

			; send success
			__netcode_TCPSend($hSocket, __netcode_AESEncrypt("Success", $hPassword))

			; call the stage
			__netcode_SocketSetStageErrorAndExtended($hSocket, 'user', 0, 0)
			__netcode_ExecuteEvent($hSocket, "connection", 'user')

			; set next stage
			__netcode_SocketSetManageMode($hSocket, 'ready')

			Return __Trace_FuncOut("__netcode_ManageUser")


		Case 2 ; if connect client


			Switch $nStage

				Case 0 ; send username and password

					; get username and password
					Local $arUserData = __netcode_SocketGetUsernameAndPassword($hSocket)

					; if none where given then disconnect
					if $arUserData[0] == False And $arUserData[1] == False Then
						__netcode_SocketSetStageErrorAndExtended($hSocket, 'user', 2, 1)

						__netcode_TCPCloseSocket($hSocket)
						__netcode_RemoveSocket($hSocket)

						__Trace_Error(1, 0, "Server requires server login. But no username or Password given.")
						Return __Trace_FuncOut("__netcode_ManageUser")
					EndIf

					; set extra info
					__netcode_SocketSetStageExtraInformation($hSocket, 'user', $arUserData[0])

					; build packet
					Local $sData = StringToBinary($arUserData[0]) & ':' & _netcode_SHA256($arUserData[1])

					; encrypt packet
					$sData = __netcode_AESEncrypt(StringToBinary($sData), $hPassword)

					; send packet
					__netcode_TCPSend($hSocket, $sData)

					; set next user stage
					_storageS_Overwrite($hSocket, '_netcode_user_ConnectClientStage', 1)

					Return __Trace_FuncOut("__netcode_ManageUser")


				Case 1 ; process answer

					; decrypt answer
					$sPackages = __netcode_AESDecrypt(StringToBinary($sPackages), $hPassword)

					; if we couldnt decrypt it then disconnect
					if $sPackages == -1 Then
						__netcode_SocketSetStageErrorAndExtended($hSocket, 'user', 2, 2)

						__netcode_TCPCloseSocket($hSocket)
						__netcode_RemoveSocket($hSocket)

						__Trace_Error(1, 0, "Could not decrypt Server answer in the User stage 1")
						Return __Trace_FuncOut("__netcode_ManageUser")
					EndIf


					; switch answer
					Local $bSuccess = False
					Switch BinaryToString($sPackages)

						Case "Success"
							$bSuccess = True


						Case "Wrong"
							__netcode_SocketSetStageErrorAndExtended($hSocket, 'user', 2, 3)
							__netcode_TCPCloseSocket($hSocket)
							__netcode_RemoveSocket($hSocket)

							__Trace_Error(2, 3, "User doesnt exist or Login details wrong")
							Return __Trace_FuncOut("__netcode_ManageUser")

						Case "OnHold"
							__netcode_SocketSetStageErrorAndExtended($hSocket, 'user', 2, 4)
							__netcode_TCPCloseSocket($hSocket)
							__netcode_RemoveSocket($hSocket)

							__Trace_Error(2, 4, "Account is OnHold")
							Return __Trace_FuncOut("__netcode_ManageUser")

						Case "Banned"
							__netcode_SocketSetStageErrorAndExtended($hSocket, 'user', 2, 5)
							__netcode_TCPCloseSocket($hSocket)
							__netcode_RemoveSocket($hSocket)

							__Trace_Error(2, 5, "Account is Banned")
							Return __Trace_FuncOut("__netcode_ManageUser")

					EndSwitch

					if Not $bSuccess Then
						__netcode_SocketSetStageErrorAndExtended($hSocket, 'user', 2, 6) ; temp
						__netcode_TCPCloseSocket($hSocket)
						__netcode_RemoveSocket($hSocket)

						__Trace_Error(2, 6, "Unknown Error")
						Return __Trace_FuncOut("__netcode_ManageUser")
					EndIf

					; set user to socket
					Local $arUserData = __netcode_SocketGetUsernameAndPassword($hSocket)
					__netcode_SocketSetUser($hSocket, $arUserData[0])

					; call stage
					__netcode_SocketSetStageErrorAndExtended($hSocket, 'user', 0, 0)
					__netcode_ExecuteEvent($hSocket, "connection", 'user')

					; set next stage
					__netcode_SocketSetManageMode($hSocket, 'netcode')

					; call the finish netcode stage
					__netcode_ExecuteEvent($hSocket, "connection", 'netcode')

					; send void packet so that the server gets out of the ready stage
					_netcode_TCPSend($hSocket, 'netcode_internal', "0")

					Return __Trace_FuncOut("__netcode_ManageUser")

			EndSwitch



	EndSwitch

EndFunc

Func __netcode_ManageReady($hSocket, $sPackages)
	__Trace_FuncIn("__netcode_ManageReady", "$sPackages")

	__netcode_ExecuteEvent($hSocket, "connection", 'netcode')
	__netcode_SocketSetManageMode($hSocket, 'netcode')

	__netcode_ManageNetcode($hSocket, $sPackages)

	__Trace_FuncOut("__netcode_ManageReady")
EndFunc

; marked for recoding
Func __netcode_ManageNetcode($hSocket, $sPackages)
	__Trace_FuncIn("__netcode_ManageNetcode", "$sPackages")

	$sPackages = _storageS_Read($hSocket, '_netcode_IncompletePacketBuffer') & $sPackages
	_storageS_Overwrite($hSocket, '_netcode_IncompletePacketBuffer', "")
	; if the StringLeft() isnt $__net_sPacketBegin then we may have no netcode packet and have to check if its maybe something socks etc. related

	Local $arPacketStrings = __netcode_SocketGetPacketStrings($hSocket)
	Local $sPacketBegin = $arPacketStrings[0]
	Local $sPacketInternalSplit = $arPacketStrings[1]
	Local $sPacketEnd = $arPacketStrings[2]

	Local $sPacketEndLen = StringLen($sPacketEnd)

	Local $arPackages = StringSplit($sPackages, $sPacketBegin, 1)
	Local $arPacketContent[0]
	Local $hPassword = __netcode_SocketGetPacketEncryptionPassword($hSocket)

;~ 	if @ScriptName = "server.au3" Then _ArrayDisplay($arPackages)
;~ 	if @ScriptName = "server.au3" Then MsgBox(0, "", $sPackages)

	For $i = 2 To $arPackages[0]
;~ 		If StringRight($arPackages[$i], 10) <> $sPacketEnd Then
		If StringRight($arPackages[$i], $sPacketEndLen) <> $sPacketEnd Then
			; packet is incomplete
			; if its not the last in the array then the whole recv most probably also is corrupted
			; ~ todo

			_storageS_Overwrite($hSocket, '_netcode_IncompletePacketBuffer', $sPacketBegin & $arPackages[$i])
;~ 			MsgBox(0, @ScriptName, $i & @CRLF & $arPackages[0] & @CRLF & @CRLF & StringRight($arPackages[$i], 10))
;~ 			_ArrayDisplay($arPackages)
			ContinueLoop
		EndIf


		$arPackages[$i] = StringTrimRight($arPackages[$i], $sPacketEndLen)


		; check if socket has encryption toggled
		if __netcode_SocketGetPacketEncryption($hSocket) Then
			$arPackages[$i] = __netcode_AESDecrypt(StringToBinary($arPackages[$i]), $hPassword)
		EndIf

		; check if socket has compression toggled
;~ 		if Not IsBinary($arPackages[$i]) Then $arPackages[$i] = StringToBinary($arPackages[$i])
;~ 		$arPackages[$i] = __netcode_LzntDecompress($arPackages[$i])

		; Split packet into its contents
		If IsBinary($arPackages[$i]) Then $arPackages[$i] = BinaryToString($arPackages[$i], 4)
		$arPacketContent = StringSplit($arPackages[$i], $sPacketInternalSplit, 1)


		; if $arPacketContent[0] is <> 4 then reject packet


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

;~ 		_ArrayDisplay($arPacketContent, @ScriptName)

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
;~ 	Local $arTempSendQuo = $__net_arPacketSendQue

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

				; empty the packet quo for the socket
;~ 				_storageS_Overwrite($arTempSendQuo[$i], '_netcode_PacketQuo', '')

			Case 10058
				; socket got closed but data was still in the send buffer.
				; we do nothing

			Case Else
				; empty the packet quo for the socket
;~ 				_storageS_Overwrite($arTempSendQuo[$i], '_netcode_PacketQuo', '')

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

		; do not update the buffer index since we still expect it

	Else
		; if the current index > the size of the array then reset to the 0 index
		$nCurrentBufferIndex += 1
		If $nCurrentBufferIndex = 1000 Then $nCurrentBufferIndex = 0
	EndIf

	; storage the changed buffer
;~ 	__netcode_SocketSetExecutionBufferValues($hSocket, $nCurrentBufferIndex, $arBuffer)
	__netcode_SocketAddExecutionBufferValue($hSocket, $nPacketID, $sEvent, $sData, $nCurrentBufferIndex)

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

	__netcode_EventConnect(0, 0)
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
Func __netcode_EventConnect(Const $hSocket, $nStage)
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

;~ 	if BinaryToString($sEvent) = 'netcode_internal' Then
;~ 		MsgBox(0, @ScriptName, $sCallback)
;~ 	EndIf

	; convert params to array, and also unmerge them if _netcode_sParams() is used, for Call()
	Local $arParams = __netcode_sParams_2_arParams($hSocket, $sData)

	__Trace_FuncIn($sCallback)
	Call($sCallback, $arParams)
	If @error Then ; needs further testing
		__Trace_Error(3, 0, 'Event Callback func got called with the wrong amount of params: ' & UBound($arParams) - 1)

		#cs
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
		#ce
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
	; ~ todo check for compression flag
;~ 	$sPackage = __netcode_LzntCompress($sPackage)

	; encrypt packet content
	If __netcode_SocketGetPacketEncryption($hSocket) Then
		Local $hPassword = __netcode_SocketGetPacketEncryptionPassword($hSocket)

		$sPackage = __netcode_AESEncrypt($sPackage, $hPassword)
	EndIf

	; convert back to string if compression or encryption got used
	if IsBinary($sPackage) Then $sPackage = BinaryToString($sPackage)

	; wrap the packet content
	$sPackage = $sPacketBegin & $sPackage & $sPacketEnd
	Local $nLen = StringLen($sPackage)

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

		$sPackages &= BinaryToString($sTCPRecv) ; old way
;~ 		$sPackages &= BinaryToString($sTCPRecv, 4) ; Reverted - Fix from 1.5.10

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
	_storageS_Overwrite($hSocket, '_netcode_ExecutionBufferIndex', $nIndex) ; hold the next expected packet ID
	_storageS_Overwrite($hSocket, '_netcode_ExecutionBuffer', $arBuffer)
	__Trace_FuncOut("__netcode_SocketSetExecutionBufferValues")
EndFunc   ;==>__netcode_SocketSetExecutionBufferValues

; adds data to the execution buffer
Func __netcode_SocketAddExecutionBufferValue(Const $hSocket, $nIndex, $sEvent, $sData, $nCurrentBufferIndex)

	Local $arBuffer = __netcode_SocketGetExecutionBufferValues($hSocket)

	$arBuffer[$nIndex][0] = $sEvent
	$arBuffer[$nIndex][1] = $sData

	__netcode_SocketSetExecutionBufferValues($hSocket, $nCurrentBufferIndex, $arBuffer)

EndFunc

; removes the data from the given index
Func __netcode_SocketRemExecutionBufferValue(Const $hSocket, $nIndex)

	Local $arBuffer = __netcode_SocketGetExecutionBufferValues($hSocket)
	Local $nCurrentBufferIndex = @error

	$arBuffer[$nIndex][0] = ""
	$arBuffer[$nIndex][1] = ""

	__netcode_SocketSetExecutionBufferValues($hSocket, $nCurrentBufferIndex, $arBuffer)

EndFunc

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
; x = @error = True / False - if whitelist or not
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

Func __netcode_SocketSetHandshakeMode(Const $hSocket, $sMode)
	_storageS_Overwrite($hSocket, '_netcode_HandhakeMode', $sMode)
EndFunc

Func __netcode_SocketGetHandshakeMode(Const $hSocket)
	Return _storageS_Read($hSocket, '_netcode_HandhakeMode')
EndFunc

; keys or some other info
Func __netcode_SocketSetHandshakeExtra(Const $hSocket, $vData)
	_storageS_Overwrite($hSocket, '_netcode_HandhakeExtra', $vData)
EndFunc

Func __netcode_SocketGetHandshakeExtra(Const $hSocket)
	Return _storageS_Read($hSocket, '_netcode_HandhakeExtra')
EndFunc

; "PresharedRSAKey", "PresharedAESKey", "RandomRSA"
Func __netcode_SocketSetHandshakeModeEnable(Const $hSocket, $sMode, $bSet)
	_storageS_Overwrite($hSocket, '_netcode_IsHandshakeModeEnabled_' & $sMode, $bSet)
EndFunc

Func __netcode_SocketGetHandshakeModeEnable(Const $hSocket, $sMode)
	Return _storageS_Read($hSocket, '_netcode_IsHandshakeModeEnabled_' & $sMode)
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
		If Not IsArray(_storageS_Read($hSocket, '_netcode_EventStorage')) Then _storageS_Overwrite($hSocket, '_netcode_EventStorage', $arBuffer) ; create event buffer with 0 elements
;~ 		Local $arBuffer[1000] ; for BytesPerSecondArray
;~ 		For $i = 0 To 999
;~ 			$arBuffer[$i] = 0
;~ 		Next
		_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecond', 0)
		_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecondTimer', TimerInit())
		_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecondCount', 0)
		_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecond', 0)
		_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecondTimer', TimerInit())
		_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecondCount', 0)
		_storageS_Overwrite($hSocket, '_netcode_SendPacketPerSecond', 0)
		_storageS_Overwrite($hSocket, '_netcode_SendPacketPerSecondBuffer', 0)
		_storageS_Overwrite($hSocket, '_netcode_SendPacketPerSecondTimer', TimerInit())
		_storageS_Overwrite($hSocket, '_netcode_RecvPacketPerSecond', 0)
		_storageS_Overwrite($hSocket, '_netcode_RecvPacketPerSecondBuffer', 0)
		_storageS_Overwrite($hSocket, '_netcode_RecvPacketPerSecondTimer', TimerInit())

		; inherit the parent settings
		_storageS_Overwrite($hSocket, '_netcode_SocketSeed', _storageS_Read($hListenerSocket, '_netcode_SocketSeed')) ; inherit seed from the parent
		_storageS_Overwrite($hSocket, '_netcode_MaxRecvBufferSize', _storageS_Read($hListenerSocket, '_netcode_MaxRecvBufferSize')) ; inherit max buffer size
		_storageS_Overwrite($hSocket, '_netcode_DefaultRecvLen', _storageS_Read($hListenerSocket, '_netcode_DefaultRecvLen')) ; inherit default recv len
		__netcode_SocketSetHandshakeMode($hSocket, __netcode_SocketGetHandshakeMode($hListenerSocket)) ; take handshake mode from parent
		__netcode_SocketSetHandshakeExtra($hSocket, __netcode_SocketGetHandshakeExtra($hListenerSocket)) ; take handshake extra from parent
		__netcode_SocketSetHandshakeModeEnable($hSocket, "PresharedRSAKey", __netcode_SocketGetHandshakeModeEnable($hListenerSocket, "PresharedRSAKey"))
		__netcode_SocketSetHandshakeModeEnable($hSocket, "PresharedAESKey", __netcode_SocketGetHandshakeModeEnable($hListenerSocket, "PresharedAESKey"))
		__netcode_SocketSetHandshakeModeEnable($hSocket, "RandomRSA", __netcode_SocketGetHandshakeModeEnable($hListenerSocket, "RandomRSA"))

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
		_storageS_Overwrite($hSocket, '_netcode_NonBlockingConnectClients', $arClients)

		; inherit default options
		_storageS_Overwrite($hSocket, '_netcode_SocketSeed', $__net_nNetcodeStringDefaultSeed) ; inherit the default seed
		_storageS_Overwrite($hSocket, '_netcode_MaxRecvBufferSize', $__net_nMaxRecvBufferSize)
		_storageS_Overwrite($hSocket, '_netcode_DefaultRecvLen', $__net_nDefaultRecvLen)
		__netcode_SocketSetHandshakeMode($hSocket, "RandomRSA") ; needs to be inherited by the default options !
;~ 		__netcode_SocketSetHandshakeExtra($hSocket, "") ; ~ todo
		; "PresharedRSAKey", "PresharedAESKey", "RandomRSA"
		__netcode_SocketSetHandshakeModeEnable($hSocket, "PresharedRSAKey", False) ; needs to be inherited by the default options !
		__netcode_SocketSetHandshakeModeEnable($hSocket, "PresharedAESKey", False)
		__netcode_SocketSetHandshakeModeEnable($hSocket, "RandomRSA", True)

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

		; if the remove socket is already called, but again because the disconnected event might did it again, then return to
		; prevent recursion issues.
		if _storageS_Read($hSocket, '_netcode_RemovalOngoing') == True Then Return __Trace_FuncOut("__netcode_RemoveSocket", False)
		_storageS_Overwrite($hSocket, '_netcode_RemovalOngoing', True)

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

		; remove one connection from the active connection counter of the parent
		Local $nCurrentConnections = _storageS_Read($hParentSocket, '_netcode_ListenerCurrentConnections') - 1
		_storageS_Overwrite($hParentSocket, '_netcode_ListenerCurrentConnections', $nCurrentConnections)

		; overwrite the found index with the last and ReDim the array aka remove the client socket
		$arClients[$nIndex] = $arClients[$nArSize - 1]
		ReDim $arClients[$nArSize - 1]

		; store the new array
		_storageS_Overwrite($hParentSocket, '_netcode_ListenerClients', $arClients)

		; call disconnect event
;~ 		__netcode_ExecuteEvent($hSocket, "disconnected")
		__netcode_ExecuteEvent($hSocket, "disconnected", _netcode_sParams($nDisconnectError, $bDisconnectTriggered))

		; destroy aes key
		__netcode_CryptDestroyKey(__netcode_SocketGetPacketEncryptionPassword($hSocket))

		; tidy storage vars of the client socket. All vars get overwritten here with Bool False
		_storageS_TidyGroupVars($hSocket)

		; if parent socket is "000" and it has no more clients then remove the parent.
		if $hParentSocket = "000" Then
			if UBound(__netcode_ParentGetNonBlockingConnectClients("000")) = 0 Then
				if $nArSize - 1 = 0 Then __netcode_RemoveSocket("000", True)
			EndIf
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

Func __netcode_ParentAddNonBlockingConnectClient(Const $hParent, $hClient, $bDontAuthAsNetcode, $nTimeout)

	; check if socket 000 exists
	if __netcode_CheckSocket("000") == 0 Then __netcode_AddSocket("000")

	; get current list
	Local $arClients = __netcode_ParentGetNonBlockingConnectClients($hParent)
	Local $nArSize = UBound($arClients)

	; add client
	ReDim $arClients[$nArSize + 1]
	$arClients[$nArSize] = $hClient

	; store vars
	_storageS_Overwrite($hClient, '_netcode_Pending', True)
	_storageS_Overwrite($hClient, '_netcode_DontAuthAsNetcode', $bDontAuthAsNetcode)
	_storageS_Overwrite($hClient, '_netcode_TimerHandle', TimerInit())
	_storageS_Overwrite($hClient, '_netcode_Timeout', $nTimeout)

	; already create event storage, so that the dev can already add events
	Local $arEvents[0]
	_storageS_Overwrite($hClient, '_netcode_EventStorage', $arEvents)

	; store new list
	_storageS_Overwrite($hParent, '_netcode_NonBlockingConnectClients', $arClients)
EndFunc

Func __netcode_ParentDelNonBlockingConnectClient(Const $hParent, $hClient)
	; get current list
	Local $arClients = __netcode_ParentGetNonBlockingConnectClients($hParent)
	Local $nArSize = UBound($arClients)

	; find position
	Local $nIndex = -1

	For $i = 0 To $nArSize - 1

		if $arClients[$i] = $hClient Then
			$nIndex = $i
			ExitLoop
		EndIf

	Next

	if $nIndex = -1 Then Return

	$arClients[$nIndex] = $arClients[$nArSize - 1]
	ReDim $arClients[$nArSize - 1]

	; wipe vars
	_storageS_Overwrite($hClient, '_netcode_Pending', Null)
	_storageS_Overwrite($hClient, '_netcode_DontAuthAsNetcode', Null)
	_storageS_Overwrite($hClient, '_netcode_TimerHandle', Null)
	_storageS_Overwrite($hClient, '_netcode_Timeout', Null)

	; store new list
	_storageS_Overwrite($hParent, '_netcode_NonBlockingConnectClients', $arClients)
EndFunc

Func __netcode_ParentCheckNonBlockingConnectClients(Const $hParent)
	; get current list
	Local $arClients = __netcode_ParentGetNonBlockingConnectClients($hParent)
	Local $nArSize = UBound($arClients)

	if $nArSize = 0 Then Return

	; select clients that are writeable
	$arClients = __netcode_SocketSelect($arClients, False)
	$nArSize = UBound($arClients)

	Local $arUserData[2]
	Local $arIPAndPort[2]
	Local $hTimer = 0
	Local $nTimeout = 0
	Local $bDontAuthAsNetcode = False

	; see which are ready
	if $nArSize > 0 Then

		; for each connected client, remove it from the list, add it to netcode and if toggled start the authtonetcode
		For $i = 0 To $nArSize - 1

			; get vars
			$arUserData = __netcode_SocketGetUsernameAndPassword($arClients[$i])
			$arIPAndPort = __netcode_SocketGetIPAndPort($arClients[$i])
			$bDontAuthAsNetcode = _storageS_Read($arClients[$i], '_netcode_DontAuthAsNetcode')
			$nTimeout = _storageS_Read($arClients[$i], '_netcode_Timeout')

			; delete socket from pending list
			__netcode_ParentDelNonBlockingConnectClient($hParent, $arClients[$i])

			; add socket to netcode
			__netcode_AddSocket($arClients[$i], $hParent, 0, $arIPAndPort[0], $arIPAndPort[1], $arUserData[0], $arUserData[1])

			; call first stage
			__netcode_ExecuteEvent($arClients[$i], 'connection', "connect")

			; trigger authtonetcode
			if Not $bDontAuthAsNetcode Then _netcode_AuthToNetcodeServer($arClients[$i], $arUserData[0], $arUserData[1], True)

		Next

	EndIf

	; reread current list, so that we wont accidently disconnect just connected clients
	$arClients = __netcode_ParentGetNonBlockingConnectClients($hParent)
	$nArSize = UBound($arClients)

	; check timeouts
	If $nArSize > 0 Then

		For $i = 0 To $nArSize - 1

			; get timeout vars
			$hTimer = _storageS_Read($arClients[$i], '_netcode_TimerHandle')
			$nTimeout = _storageS_Read($arClients[$i], '_netcode_Timeout')

			; if timeouted then remove the socket and call the disconnected event
			if TimerDiff($hTimer) > $nTimeout Then

				__netcode_TCPCloseSocket($arClients[$i])

				__netcode_ExecuteEvent($arClients[$i], 'disconnected', _netcode_sParams(-1, False))

				__netcode_ParentDelNonBlockingConnectClient($hParent, $arClients[$i])

				; timeout storage wipe only ! Otherwise the event storage would be gone at that point.
				_storageS_TidyGroupVars($arClients[$i])

			EndIf

		Next

	EndIf

	; reread again
	$arClients = __netcode_ParentGetNonBlockingConnectClients($hParent)
	$nArSize = UBound($arClients)

	; if the list is empty and socket 000 holds no sockets then remove it
	$arClients = __netcode_ParentGetClients("000")
	if UBound($arClients) = 0 And $nArSize = 0 Then __netcode_RemoveSocket("000", True)

EndFunc

Func __netcode_ParentGetNonBlockingConnectClients(Const $hParent)
	Return _storageS_Read($hParent, '_netcode_NonBlockingConnectClients')
EndFunc

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
	if _storageS_Read($hSocket, '_netcode_Pending') Then Return 3
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
	If $__net_bNetcodeStarted Then Return __Trace_FuncOut("__netcode_Init")

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

	; only check if script is compiled, it is enabled and only once a day.
	__netcode_UDFVersionCheck($__net_sNetcodeVersionURL, $__net_sNetcodeOfficialRepositoryURL, $__net_sNetcodeOfficialRepositoryChangelogURL, '_netcode_Core', $__net_sNetcodeVersion)

	$__net_bNetcodeStarted = True
	__Trace_FuncOut("__netcode_Init")
EndFunc   ;==>__netcode_Init

Func __netcode_Shutdown()
	__Trace_FuncIn("__netcode_Shutdown")
	if Not $__net_bNetcodeStarted Then Return __Trace_FuncOut("__netcode_Shutdown")

	; check for known parent sockets
	Local $nArSize = UBound($__net_arSockets)
	if $nArSize > 0 Then

		Local $arClients[0]
		Local $arParents = $__net_arSockets

		; for every parent socket
		For $i = 0 To $nArSize - 1

			; check for client sockets
			$arClients = __netcode_ParentGetClients($arParents[$i])
			if UBound($arClients) > 0 Then

				; for every client socket
				For $iS = 0 To UBound($arClients) - 1

					; disconnect the client socket
					_netcode_TCPDisconnect($arClients[$iS])

				Next

			EndIf

			; close the parent socket if its not the '000' socket
			if $arParents[$i] <> '000' Then _netcode_TCPDisconnect($arParents[$i])

		Next

	EndIf

	; remove all default events
	Local $arEvents = $__net_arDefaultEventsForEachNewClientSocket
	For $i = 0 To UBound($arEvents) - 1
		_netcode_PresetEvent($arEvents[$i][0], "", False)
	Next

	; close cryptography provider
	__netcode_CryptShutdown()

	; close dlls
	DllClose($__net_hWs2_32)
	$__net_hWs2_32 = False

	; close autoits tcpstartup
	TCPShutdown()

	; set startup flag to false
	$__net_bNetcodeStarted = False

	__Trace_FuncOut("__netcode_Shutdown")
EndFunc

Func __netcode_UDFVersionCheck(Const $sVersionFileURL, Const $sOfficialRepoURL, Const $sOfficialRepoChangelogURL, Const $sUDFName, Const $sCurrentVersion)

	; no version check if the script is compiled
	If @Compiled Then Return

	; if disabled then return
	if Not $__net_bCheckForUDFUpdate Then Return

	; only a single check per day
	Local $sHKCUPath = $__net_sNetcodeHKCUPath
	Local $sCurrentDate = @MDAY & '/' & @MON & '/' & @YEAR

	; read latest check date
	Local $sDate = RegRead($sHKCUPath, $sUDFName & '_lastcheck')

	; if never checked before
	if @error Then
		; then write the current date
		RegWrite($sHKCUPath, $sUDFName & '_lastcheck', "REG_SZ", $sCurrentDate)
	EndIf

	; if we already checked the version at this day then
	if $sDate = $sCurrentDate Then

		; read if there was a new version
		Local $sVersion = RegRead($sHKCUPath, $sUDFName & '_latestversion')

		; if not then return
		if @error Then Return

		; if its the same as the latest then return
		If $sCurrentVersion = $sVersion Then Return

		; if not then log a info
		ConsoleWrite(@CRLF)
		ConsoleWrite('+ New "' & $sUDFName & '" Version available v' & $sVersion & @CRLF)
		ConsoleWrite("  You are running version v" & $sCurrentVersion & @CRLF)
		ConsoleWrite("  Latest Version can be found here: " & $sOfficialRepoURL & @CRLF)
		ConsoleWrite("  Changelog is here: " & $sOfficialRepoChangelogURL & @CRLF)
		ConsoleWrite("  You can disable the Version check by setting $__net_bCheckForUDFUpdate to False" & @CRLF)
		ConsoleWrite("  Have a nice day! (:" & @CRLF)
		ConsoleWrite(@CRLF)

		Return
	EndIf

	; write to reg that we are running a check
	RegWrite($sHKCUPath, $sUDFName & '_lastcheck', "REG_SZ", $sCurrentDate)

	; read latest version from version url using https
	Local $sVersion = InetRead($sVersionFileURL, 1)

	; if it failed then just return
	If @error Then Return

	; convert to string
	$sVersion = BinaryToString($sVersion)

	; cut LF and CRLF if present
	$sVersion = StringReplace($sVersion, @LF, "")
	$sVersion = StringReplace($sVersion, @CRLF, "")

	; if the current version is the latest then return
	if $sCurrentVersion = $sVersion Then Return

	; if not then write that to the reg
	RegWrite($sHKCUPath, $sUDFName & '_latestversion', "REG_SZ", $sVersion)

	; lastly rerun the func to display a notice
	Return __netcode_UDFVersionCheck($sVersionFileURL, $sOfficialRepoURL, $sOfficialRepoChangelogURL, $sUDFName, $sCurrentVersion)

EndFunc

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

	; create key just for the client strings
	Local $hPassword = __netcode_AESDeriveKey($nSeed, "ClientStrings")

	; encrypt the packet wrapper begin string
	Local $sPacketBegin = BinaryToString(__netcode_AESEncrypt(__netcode_SeedToString($nSeed, 10, "PacketBegin"), $hPassword))
;~ 	Local $sPacketBegin = __netcode_SeedToString($nSeed, 10, "PacketBegin")

	; keep the internal packet content split string unencrypted
	Local $sPacketInternalSplit = __netcode_SeedToString($nSeed, 10, "PacketInternalSplit")

	; and encrypt the packet wrapper end string
	Local $sPacketEnd = BinaryToString(__netcode_AESEncrypt(__netcode_SeedToString($nSeed, 10, "PacketEnd"), $hPassword))
;~ 	Local $sPacketEnd = __netcode_SeedToString($nSeed, 10, "PacketEnd")

	__netcode_CryptDestroyKey($hPassword)


	__netcode_SocketSetPacketStrings($hSocket, $sPacketBegin, $sPacketInternalSplit, $sPacketEnd)


	; maybe at some point
;~ 	__netcode_SocketSetParamStrings($hSocket, __netcode_SeedToString($nSeed, 10, "ParamIndicatorString"), __netcode_SeedToString($nSeed, 10, "ParamSplitSeperator"))
;~ 	__netcode_SocketSetSerializerStrings($hSocket, __netcode_SeedToString($nSeed, 10, "SerializationIndicator"), __netcode_SeedToString($nSeed, 10, "SerializeArrayIndicator"), __netcode_SeedToString($nSeed, 10, "SerializeArrayYSeperator"), __netcode_SeedToString($nSeed, 10, "SerializeArrayXSeperator"))


	__Trace_FuncOut("__netcode_SeedingClientStrings")
EndFunc   ;==>__netcode_SeedingClientStrings

; marked for recoding
; needs to generate strings that cant be reverted to the seed. Use hash algorhytms or something.
; ANY CHANGES HERE WILL MAKE THE NEW _netcode VERSIONS UNABLE TO TALK TO PREVIOUS VERSIONS ! <<<<==================<<<<
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
	Local $hTimer = _storageS_Read($hSocket, '_netcode_SendBytesPerSecondTimer')

	; if its the next second then
	if TimerDiff($hTimer) > 1000 Then

		; calculate how much bytes per second where send
		Local $nBytesPerSecond = $nBufferSize
		$nBufferSize = 0
		_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecondCount', 0)

		; and write said information to the storage
		_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecond', $nBytesPerSecond)
		_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecondTimer', TimerInit())
	EndIf

	; add the current send bytes to the array index of the ms it was send
	$nBufferSize += $nBytes

	; update buffer
	_storageS_Overwrite($hSocket, '_netcode_SendBytesPerSecondCount', $nBufferSize)
	__Trace_FuncOut("__netcode_SocketSetSendBytesPerSecond")
EndFunc

; currently only works for client sockets
Func __netcode_SocketGetSendBytesPerSecond(Const $hSocket)
	Local $nBytesPerSecond = _storageS_Read($hSocket, '_netcode_SendBytesPerSecond')

	if $nBytesPerSecond = 0 Then
		Return 0
	Else
		; if the info is old as- or older then 2 seconds then return 0
		if TimerDiff(_storageS_Read($hSocket, '_netcode_SendBytesPerSecondTimer')) > 2000 Then Return 0
	EndIf

	Return $nBytesPerSecond

EndFunc

Func __netcode_SocketSetRecvBytesPerSecond(Const $hSocket, $nBytes)
	__Trace_FuncIn("__netcode_SocketSetRecvBytesPerSecond")

	; return if zero bytes because nothing needs to be added
	if $nBytes = 0 Then Return __Trace_FuncOut("__netcode_SocketSetRecvBytesPerSecond")

	; get buffer and the second it belongs too
	Local $nBufferSize = _storageS_Read($hSocket, '_netcode_RecvBytesPerSecondCount')
	Local $hTimer = _storageS_Read($hSocket, '_netcode_RecvBytesPerSecondTimer')

	; if its the next second then
	if TimerDiff($hTimer) > 1000 Then

		; calculate how much bytes per second where received and also clean the buffer
		Local $nBytesPerSecond = $nBufferSize
		$nBufferSize = 0
		_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecondCount', 0)

		; and write said information to the storage
		_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecond', $nBytesPerSecond)
		_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecondTimer', TimerInit())
	EndIf

	; add the current received bytes to the array index of the ms it was received
	$nBufferSize += $nBytes

	; update buffer
	_storageS_Overwrite($hSocket, '_netcode_RecvBytesPerSecondCount', $nBufferSize)
	__Trace_FuncOut("__netcode_SocketSetRecvBytesPerSecond")
EndFunc

Func __netcode_SocketGetRecvBytesPerSecond(Const $hSocket)
	Local $nBytesPerSecond = _storageS_Read($hSocket, '_netcode_RecvBytesPerSecond')

	if $nBytesPerSecond = 0 Then
		Return 0
	Else
		; if the info is old as- or older then 2 seconds then return 0
		if TimerDiff(_storageS_Read($hSocket, '_netcode_RecvBytesPerSecondTimer')) > 2000 Then Return 0
	EndIf

	Return $nBytesPerSecond

EndFunc

Func __netcode_SocketSetSendPacketPerSecond(Const $hSocket, $nCount)
	__Trace_FuncIn("__netcode_SocketSetSendPacketPerSecond", $hSocket, $nCount)
	Local $nBufferSize = _storageS_Read($hSocket, '_netcode_SendPacketPerSecondBuffer')
	Local $hTimer = _storageS_Read($hSocket, '_netcode_SendPacketPerSecondTimer')

	if TimerDiff($hTimer) > 1000 Then
		_storageS_Overwrite($hSocket, '_netcode_SendPacketPerSecond', $nBufferSize)
		_storageS_Overwrite($hSocket, '_netcode_SendPacketPerSecondTimer', TimerInit())
		$nBufferSize = 0
	EndIf

	$nBufferSize += $nCount
	_storageS_Overwrite($hSocket, '_netcode_SendPacketPerSecondBuffer', $nBufferSize)
	__Trace_FuncOut("__netcode_SocketSetSendPacketPerSecond")
EndFunc

Func __netcode_SocketGetSendPacketPerSecond(Const $hSocket)
	if TimerDiff(_storageS_Read($hSocket, '_netcode_SendPacketPerSecondTimer')) > 2000 Then Return 0

	Return _storageS_Read($hSocket, '_netcode_SendPacketPerSecond')
EndFunc

Func __netcode_SocketSetRecvPacketPerSecond(Const $hSocket, $nCount)
	__Trace_FuncIn("__netcode_SocketSetRecvPacketPerSecond", $hSocket, $nCount)
	Local $nBufferSize = _storageS_Read($hSocket, '_netcode_RecvPacketPerSecondBuffer')
	Local $hTimer = _storageS_Read($hSocket, '_netcode_RecvPacketPerSecondTimer')

	if TimerDiff($hTimer) > 1000 Then
		_storageS_Overwrite($hSocket, '_netcode_RecvPacketPerSecond', $nBufferSize)
		_storageS_Overwrite($hSocket, '_netcode_RecvPacketPerSecondTimer', TimerInit())
		$nBufferSize = 0
	EndIf

	$nBufferSize += $nCount
	_storageS_Overwrite($hSocket, '_netcode_RecvPacketPerSecondBuffer', $nBufferSize)
	__Trace_FuncOut("__netcode_SocketSetRecvPacketPerSecond")
EndFunc

Func __netcode_SocketGetRecvPacketPerSecond(Const $hSocket)
	if TimerDiff(_storageS_Read($hSocket, '_netcode_RecvPacketPerSecondTimer')) > 2000 Then Return 0

	Return _storageS_Read($hSocket, '_netcode_RecvPacketPerSecond')
EndFunc

; this functions only sets the var type, it doesnt convert the data
; so a String var, ment to be set to Binary, wont be set with StringToBinary() it will just be set with Binary()
Func __netcode_SetVarType($vData, $sVarType)
	__Trace_FuncIn("__netcode_SetVarType", "$vData", $sVarType)

	Switch $sVarType

		Case "Bool"
			$vData = StringUpper($vData)
			If $vData == "FALSE" Then Return __Trace_FuncOut("__netcode_SetVarType", False)
			If $vData == "TRUE" Then Return __Trace_FuncOut("__netcode_SetVarType", True)

			__Trace_Error(2, 0, "Neither True nor False was given", "", $vData)
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

	; filling the fd_set struct with the client sockets
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

#cs
; x32 and x64 compatible
; 0 = Read
; 1 = Write
; 2 = exceptfds
Func __netcode_SocketSelect_2($arClients, $nMode = 0)
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

	; filling the fd_set struct with the client sockets
	For $i = 0 To $nArSize - 1
		DllStructSetData($tFD_SET, "fd_array", $arClients[$i], $i + 1)
	Next

	; if we want to filter for the sockets that have something in the receive buffer or if we want to filter for the sockets that can send something
	Switch $nMode

		Case 0
			$arRet = DllCall($__net_hWs2_32, 'int', 'select', 'int', 0, 'ptr', DllStructGetPtr($tFD_SET), 'ptr', 0, 'ptr', 0, 'ptr', DllStructGetPtr($tTIMEVAL))

		Case 1
			$arRet = DllCall($__net_hWs2_32, 'int', 'select', 'int', 0, 'ptr', 0, 'ptr', DllStructGetPtr($tFD_SET), 'ptr', 0, 'ptr', DllStructGetPtr($tTIMEVAL))

		Case 2
			$arRet = DllCall($__net_hWs2_32, 'int', 'select', 'int', 0, 'ptr', 0, 'ptr', 0, 'ptr', DllStructGetPtr($tFD_SET), 'ptr', DllStructGetPtr($tTIMEVAL))

	EndSwitch

	_ArrayDisplay($arRet, $nMode)


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
#ce

; this func has some weird issue with WSAGetLastError returning error 1400, yes 1400 not 10040. The Error table doesnt reveal anything, google dont too.
; i dont know what the heck it means.
; marked for recoding. i have to find the best way to use send() or wsasend()
Func __netcode_TCPSend($hSocket, $sData, $bReturnWhenDone = True) ; TCPSend
	__Trace_FuncIn("__netcode_TCPSend", $hSocket, "$sData")

	Local $nLen = BinaryLen($sData)

	; fill struct with data that is to be send
	Local $stAddress_Data = DllStructCreate('byte[' & $nLen & ']')
	DllStructSetData($stAddress_Data, 1, $sData)

	Local $arRet[0]
	Local $nError = 0

	; send loop
	Do

		; call ws2 to send the data
		$arRet = DllCall($__net_hWs2_32, "int", "send", "int", $hSocket, "struct*", $stAddress_Data, "int", DllStructGetSize($stAddress_Data), "int", 0)

		; if instantly send then exitloop
		If $arRet[0] <> -1 Then ExitLoop

		; get error code
		$nError = __netcode_WSAGetLastError()

		; if code is "Would Block" and the func is set to continue until data is successfully send then Continueloop
		if $bReturnWhenDone And $nError = 10035 Then ContinueLoop

		; otherwise exitloop the loop if the error is <> 1400
	Until $nError <> 1400

	; check the error
	If $nError And $arRet[0] = -1 Then

		; if it wasnt the "Would Block" error then log it
		if $nError <> 10035 Then __Trace_Error($nError, 0)

		; then return with the error
		Return SetError($nError, 0, __Trace_FuncOut("__netcode_TCPSend", 0))
	EndIf

	; return no error and the amount of bytes that where send
	Return __Trace_FuncOut("__netcode_TCPSend", $arRet[0])

EndFunc   ;==>__netcode_TCPSend

Func __netcode_WSAGetLastError()
	If $__net_hWs2_32 = -1 Then $__net_hWs2_32 = DllOpen("Ws2_32.dll")
	Local $iRet = DllCall($__net_hWs2_32, "int", "WSAGetLastError")
	If @error Then
		Return SetError(0, 1, 0)
	EndIf
	Return $iRet[0]
EndFunc   ;==>__netcode_WSAGetLastError

; TCPRecv
; WSAGetLastError() sometimes returns error 5
; https://www.gamedev.net/forums/topic/399027-wsagetlasterror-returns-5-what-does-this-mean-solved/
; marked for recoding
; the func should become a second param saying how much data, per call, to extract.
; generally _netcode should empty the windows buffer with a single call. The size of the windows buffer should be set to the sockets max buffer.
Func __netcode_TCPRecv(Const $hSocket)
	__Trace_FuncIn("__netcode_TCPRecv", $hSocket)

	Local $nError = 0
;~ 	Local $tRecvBuffer = DllStructCreate("char[" & 65536 & "]")
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
;~ 	Return SetError(0, $arRet[0], StringMid(DllStructGetData($tRecvBuffer, 1), 1, $arRet[0]))
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
		Local $aRet = DllCall($hWs2, "int", "ioctlsocket", "uint", $iMainsocket, "long", 0x8004667e, "ulong*", 1) ;FIONBIO
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
		Local $arGen = DllCall($__net_hWs2_32, "int", "setsockopt", "uint", $hSock, "int", 6, "int", 1, "struct*", $tworkspace, "int", DllStructGetSize($tworkspace))

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

; note: add a settable timeval
Func __netcode_TCPConnect($sIP, $sPort, $nAdressFamily = 2, $bNonBlocking = False, $nTimeout = 2000)
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

	; make socket non blocking before the connect call if $bNonBlocking
	If $bNonBlocking Then $arGen = DllCall($__net_hWs2_32, "int", "ioctlsocket", "int", $hSocket, "dword", 0x8004667E, "uint*", 1)

	; connect. Will return error 10035 always if non blocking
	$arGen = DllCall($__net_hWs2_32, "int", "connect", "uint", $hSocket, "ptr", DllStructGetPtr($tDataBuffer), "int", DllStructGetSize($tDataBuffer))
	If $arGen[0] <> 0 Then
		$nError = __netcode_WSAGetLastError()
		if $bNonBlocking Then
			Return SetError($nError, 0, __Trace_FuncOut("__netcode_TCPConnect", $hSocket))
		EndIf
		__Trace_Error($nError, 0)
		Return SetError($nError, 0, __Trace_FuncOut("__netcode_TCPConnect", -1))
	EndIf

	; make socket non blocking after the connect call if Not $bNonBlocking
	If Not $bNonBlocking Then $arGen = DllCall($__net_hWs2_32, "int", "ioctlsocket", "int", $hSocket, "dword", 0x8004667E, "uint*", 1)

	; disable Nagle algorithm for testing https://docs.microsoft.com/en-us/windows/win32/api/winsock/nf-winsock-setsockopt
	Local $tworkspace = DllStructCreate("BOOLEAN")
	DllStructSetData($tworkspace, 1, False)
	$arGen = DllCall($__net_hWs2_32, "int", "setsockopt", "uint", $hSocket, "int", 6, "int", 1, "struct*", $tworkspace, "int", DllStructGetSize($tworkspace))


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

Func __netcode_CryptDestroyKey($hPassword)
	DllCall($__net_hInt_bcryptdll, "int", "BCryptDestroyKey", "handle",  $hPassword)
EndFunc

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

; lznt functions from xxxxxxxxxxxxxxxxxxxxxxxxxx idk know yet
; marked for recoding
Func __netcode_LzntDecompress($bbinary)

	If Not IsBinary($bbinary) Then $bbinary = Binary($bbinary)

	Local $tinput = DllStructCreate("byte[" & BinaryLen($bbinary) & "]")
	DllStructSetData($tinput, 1, $bbinary)

;~ 	Local $tbuffer = DllStructCreate("byte[" & 0x40000 & "]") ; 0x40000 taken from UEZ - File to Base64 String Code Generator
	Local $tbuffer = DllStructCreate("byte[" & $__net_nMaxRecvBufferSize & "]") ; since our packets will never exceed this anyway.. could change when i add the big packet feature

	Local $a_call = DllCall($__net_hInt_ntdll, "int", "RtlDecompressBuffer", "ushort", 2, "ptr", DllStructGetPtr($tbuffer), "dword", DllStructGetSize($tbuffer), "ptr", DllStructGetPtr($tinput), "dword", DllStructGetSize($tinput), "dword*", 0)
	If @error OR $a_call[0] Then
		Return SetError(1, 0, "")
	EndIf

	Return BinaryMid(DllStructGetData($tbuffer, 1), 1, $a_call[6])

EndFunc

Func __netcode_LzntCompress($vinput, $icompressionformatandengine = 2)

	If Not IsBinary($vinput) Then
		$vinput = StringToBinary($vinput, 4)
	Else
		$vinput = Binary($vinput)
	EndIf

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

EndFunc

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

; there is no way to remove variables (as far as i know). But we can "clean" all of them by overwriting them with Null
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

Func __Trace_LogError($nError, $nExtended, $sErrorDescription, $sExtendedDescription = "")
	If Not $__net_bTraceLogErrorEnable Then Return

	Local $sError = ""
	Local $nArSize = UBound($__net_arTraceLadder)

	if Not @Compiled Then $sError &= '! '

	If $__net_bTraceLogEnable Then
		For $i = 1 To $nArSize - 1
			$sError &= @TAB
		Next
	EndIf

	$sError &= $__net_arTraceLadder[$nArSize - 1][0] & "() Err: " & $nError & " - Ext: " & $nExtended
	if $sErrorDescription <> "" Or $sExtendedDescription <> "" Then $sError &= " -"
	if $sErrorDescription <> "" Then $sError &= " Err: '" & $sErrorDescription & "'"
	if $sExtendedDescription <> "" Then $sError &= " Ext: '" & $sExtendedDescription & "'"
	ConsoleWrite($sError & @CRLF)
EndFunc   ;==>__Trace_LogError
