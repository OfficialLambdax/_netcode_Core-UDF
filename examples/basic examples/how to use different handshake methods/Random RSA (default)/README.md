RandomRSA is the easiest, because it doesnt require any pre shared keys. And it also is the default method.
Beaware that this method is not Man in the Midle safe.

The server creates a random RSA key pair for each connecting client. It sends the public key encrypted with AES to the client. The client then
generates a 40 char long password for AES. And encrypts that password with the public RSA key. The RSA encrypted text is then also
double encrypted with the pre handshake AES key. The encrypted text is then send to the server. The server then encrypts the text to get the
40 char long password. This password is then the session key for all further tranmissions.