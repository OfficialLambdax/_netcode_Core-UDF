# _netcode_Core-UDF
a extended TCP/TLS/IPv4/IPv6 UDF for Autoit3

DO NOT USE.
This lib is neither a stable release nor a Beta or a Alpha. This isnt even a prerelease. The lib is still in the concept creation phase.
It is unsafe to use, major and minior bugs exists. Everything is subject to change and many yet already thought out systems arent included. On the other hand there are features already included that need complete overhauls etc. TLS and IPv6 is missing too.

There is little to zero documentation and no support for anything. I just uploaded it here for me to have access to it from everyhwere and to speak with other devs about certain ideas.


However if you are still interested in what this is about:
I try to create a very performant and secure TCP UDF for Autoit3. The aim is to make it very easy to use too and to provide many options. This lib is ment to be opensource and ment to be used in a variety of systems, ranging from personal to coorperate usages while also providing usefullness and security to not so experiences coders. The UDF is event based, packages the data, encrypts it in all kinds of desired ways and so on. It is ment todo everything for you that it netcode related, while keeping it easy, fast, scallable and secure. The UDF also can identify corrupted and missing packets and either repairs them or requests resends while making sure that the packets are executed in order and lots more. It is quite the ambitious project and to be honest alot of the knowledge fields i have yet never touched before. So it takes time to bring this through the Concept phase into alpha.

The lib is compatible with X32 and X64. You can use the Autoit Stable or Beta Release. Beta IS faster.

There are also addons
https://github.com/OfficialLambdax/_netcode_Router-UDF

https://github.com/OfficialLambdax/_netcode_Proxy-UDF

https://github.com/OfficialLambdax/_netcode_Relay-UDF

Why do i develop addons before i finish the Core? Because i yet have to figure out what all needs to be in the Core to make the Addons work smooth without much additional code or Core code replacements.
