This examples shows how Non callback Events can be used.

In this case the client asks the server to create two random numbers, then to calculate one number^2 and then to add both numbers together.
The example was coded in this way to also show how the simple parameter serializer can be used with non callback events.

Do not forget that _netcode_UseNonCallbackEvent() always returns a CallArgArray.
[0] = "CallArgArray"
[1] = SocketID
[2] = param1
[.
[n]

