A one way transmission, from the client to the server, example.
Server allows a set amount of clients to upload data to it simultaniously.

A client can choose between the upload of single file or the upload of a whole folder and its contents.

The Autoit Wrapper is set to use the Beta. But the stable build is also compatible just as x32 and x64 is.

The example uses the Preshared RSA Key handshake method to agree on a session key.

The client.au3 uses the function _RecursiveFileListToArray() made by Oscar@Autoit.de