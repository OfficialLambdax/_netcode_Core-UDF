Non blocking connect calls, are as the name says, non blocking. Usually blocking means that the function _netcode_TCPConnect() would either return once the connect attempt was successfull or once it failed. Setting the $bNonBlocking param to True changes that behaviour.
The function will return with a socket no matter if the connect attempt was successfull yet or not.

Windows is still trying to connect to the given ip and port and the result of that try is just not known yet. A connect call can simply take a while if the server is unresponsive or just if the latency is fairly high. Such a slow connect attempt would simply block / halt the server or client for the time that the connect attempt takes. That is a issue if the server also is a client to another server, because each connect attempt would simply hang up the server. Thats also true of a Client with a GUI. The gui becomes entirely unresponsive for the time the client tries to connect.

In order to solve that problem, such a connect attempt can be made non blocking. So that windows does the connect attempt and _netcode just checks frequently if it was a success or not. Once it was a success the connection event is executed or if it wasnt a success then the disconnected event is executed.

Such a pending connection socket can already have events or custom data saved to it. It is just not possible to quo packets for it yet.
