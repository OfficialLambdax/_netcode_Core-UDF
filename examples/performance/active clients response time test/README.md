This example is a active sockets test. Here you can check how many active clients a server can actively handle, or much more how long it will take to get a response from a loaded server.

The client creates a set amount of connections to the server.
Then the client will send a request for each socket to the server.
The server then reponds to the request of each client with a set amount of bytes.
The client then measures the amount of time that it took to get the response.
The client will also repeat that process over and over until the process is halted.

In the server the amount of data that is send to each socket can be adjusted. And in the client the amount of clients
that should be connected.

Generally the set amount of clients are all managed in a single process and when combined with the fact that this example is likely run
on a end user computer, then expect that the resulting times are far from real when compared to when each client would run in a seperate process on a seperate machine.
