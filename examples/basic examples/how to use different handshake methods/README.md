_netcode as of version v0.1.5.23 does not yet provide a perfect forward secrecy method. Only 3 basic are offered right know.
The general aim is to defeat any man in the middle attacks.

Whats a man in the middle attack?
"In cryptography and computer security, a man-in-the-middle [...] attack is a cyberattack where the attacker secretly relays and possibly alters
the communications between two parties who believe that they are directly communicating with each other, as the attacker has inserted themselves
between the two parties."
https://en.wikipedia.org/wiki/Man-in-the-middle_attack


Available methods:

1. (default)
	The Random RSA method is the default because it requires no additional setup. An attacker can only decrypt the transmitted traffic if he
	runs a man in the middle attack.
	
2. (recommended)
	The Preshared RSA Key method requires that the server has a static private key and that the client have the public keys stored somewhere
	(or hardcoded). An attacker can only decrypt packets if he has access to the individual client software that he wants to decrypt
	data from. He needs to replace the public key and run a man in the middle attack. Otherwise this method should be safe.
	
3. (not safe)
	The Preshared AES Key method uses a static AES key for each and every client. Once an attacker knows that, he can without a Man in
	the middle attack, decrypt traffic between the server and any client.
	
	The preshared aes key method is only implemented for development, for me to play around with attack technics. Specificaly to develop the seed
	based packet wrapper strings, where when done right it might make it extra hard for one to decrypt any traffic, even if one guesses the
	right encryption password.

