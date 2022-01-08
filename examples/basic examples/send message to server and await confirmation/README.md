Run the example in SciTE.

This example is fairly basic. The server will start a listener at port 1225. Every client connected to it, can
send a message to the "MyServerEvent" Callback Event. The server will then log that message to the console and
additionaly will confirm that it got the message to the client, by sending a notice to the "MyClientEvent"
callback event.