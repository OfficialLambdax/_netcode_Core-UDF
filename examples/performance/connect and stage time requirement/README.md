The client in this example will connect $nTestAmount of times (100 default) to the server and will measure how long that took.
In the end the clinet will log the results, including the average time per connect and stage through, to the console.

Staging through means that both the server and client are ready to trigger events on each other. Or in other words
both parties synced options with each other, handshaked a session key and so on.