This example is a active sockets test. Here you can check how many active clients a server can actively handle, or much more how long it will take to get a response from a loaded server.

The client creates a set amount of connections to the server.
Then the client will send data for each socket to the server.
The server then reponds to the request of each client with a set amount of bytes.
The client then measures the amount of time that it took to get the response.
The client will also repeat that process over and over until the process is halted.

In the server the amount of data that is send to each socket can be adjusted. And in the client the amount of clients
that should be connected.