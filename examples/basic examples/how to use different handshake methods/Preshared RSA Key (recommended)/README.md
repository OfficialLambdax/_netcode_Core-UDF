The Preshared RSA Key method is a way where the server has static RSA key pairs. The client has to have the public in order to handshake
a session key with the server.

The server requests from the client that it creates a session key and encrypts it with the known public key. The client will do that and will
send it back to the server. The server then will try to decrypt the session key with its private key. This password then becomes the encryption
key for each and every further transmission.

This method is only man in the middle safe until the client no longer uses the public key of the server but a third.
An attacker can know the public key that doesnt matter, but once he can replace his with the one in the client then the traffic becomes readable.
But since the public key isnt shared over TCP/IP, the attacker would need access to the computer where the client is running on in order to change
the key.

So this method is generally recommended. Use static rsa keys for your server and hardcode the public into the clients that can only be replaced
through safe updates.