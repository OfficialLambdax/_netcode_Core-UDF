#NoTrayIcon
#include "..\..\..\_netcode_Core.au3"


; declare a global variable for this example
Global $__bAwaitingMessageConfirmationFromServer = False

; and a local variable
Local $sSendThisText = ""


; startup the udf first
_netcode_Startup()

; connect to ip 127.0.0.1 and port 1225
Local $hMyClient = _netcode_TCPConnect('127.0.0.1', 1225)

; check if we could connect and if not exit
if Not $hMyClient Then Exit MsgBox(16, "Error", "Could not connect to 127.0.0.1 @ 1225")

; define a callback event for this client, to which the server can send data
_netcode_SetEvent($hMyClient, 'MyClientEvent', "_Event_MyClientEvent")



; loop
While Sleep(10)

	; loop the client socket and exit the script if we disconnected
	If Not _netcode_Loop($hMyClient) Then Exit MsgBox(16, "Error", "Disconnected from Server")

	; if we arent awaiting a message approval from the server then
	if Not $__bAwaitingMessageConfirmationFromServer Then

		; ask for the message to be send
		$sSendThisText = InputBox("Send Message", "Enter what you want to send to the server. Press Cancel to Exit", "Text")

		; check if cancel is clicked or if the text is empty
		if $sSendThisText = "" Or @error Then

			; shutdown _netcode
			_netcode_Shutdown()

			; exit
			Exit MsgBox(64, "Exit", "Exiting script")

		EndIf


		; send the message
		_netcode_TCPSend($hMyClient, 'MyServerEvent', $sSendThisText)


		; and wait for confirmation
		$__bAwaitingMessageConfirmationFromServer = True
	EndIf

WEnd




Func _Event_MyClientEvent($hSocket)
	ConsoleWrite("Server confirmed that he received your message" & @CRLF)

	; reset the global variable
	$__bAwaitingMessageConfirmationFromServer = False
EndFunc