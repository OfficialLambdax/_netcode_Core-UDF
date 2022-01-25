Preshared AES key, means that there is a static key that is used for each and every tranmission between the server and each client from the
handshake stage.

The server requests from the client to send a sample text that is encrypted with the preshared key. The client does that and sends the encrypted
sample text to the server. The server then tries to decrypt it with its preshared key. This key then keeps to be the encryption key for
each and every further transmission.

This method is only so far safe against man in the middle attacks as long as the attacker doesnt know the key. Once he does, every transmission
between the server and any client can be read. This method is therefore not recommended.