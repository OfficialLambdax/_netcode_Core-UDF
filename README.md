# _netcode_Core-UDF
a extended event based TCP/IP (IPv4/6) libary for Autoit3 (Support for Win XP, Vista, 7, 8, 8.1, 10 and Linux - X32 and X64 - Autoit Stable and Beta)

First of all. This Libary (commonly referred as UDF for User Defined Functions) is neither yet Alpha nor Beta or Stable. The libary is still in its Concept Creation Phase. This means that features are missing eg. IPv6, TLS, Double Ratchet and that already included systems and features require complete overhauls. If you are going to use this UDF then expect alot of script breaking changes with updates and incomaptibilities wih older versions. In such a event the changelog will provide information about that and what to change. Also, because of the amount of changes that still need to be made, the UDF has no documentation yet.

If you already worked with event based libaries then it should be easy to get into this libary. And you can get a basic understanding on how to use this UDF from the variety of examples in the examples folder.

One aim of this UDF is to give programmers the ability to very quickly write complex and clear scripts for various intends, while making it very easy to identify and solve bugs. And another aim is, to make the libary so easy to use that less experienced programmers finally get the ability to easiely use well acknowledged crypto algorhytms and handshake methods in their projects.

Stable > Easy to use > Secure > Performant

Alot of things need to be done and well tested. But to give you a glimps of the scope of this UDF here is a list.

_netcode is ment to Offer
- Security         - Perfect Forwarded Secrecy (TLS v1.2-3), End to End encryption (Double Ratchet) and the ability to easiely implement your own methods.
- Performance      - The entire UDF is ment to be as fast as possible. Different data managers are going to be implemented, some entirely stream based and other package based. As of now the 'netcode' package based mode can process around ~90 mb/s and the 'rawlinked' stream based mode can process around 200 mb/s. Both values come from a modern end user pc.
- Compatibility    - As long as the environment provides the required crypto api's and the required TCP/IP libaries, the UDF should run without any issue.
Generally it shouldnt matter if one process runs on a windows and another on a linux. If a Operating system requires specific settings or files, then i will likely write a document specifying what has to be done. Another part of the Compatibility will be the ability to implement fully custom manage modes. So that the UDF is compatible with other Event based libaries from Autoit or another language. It would generally also be possible to for example implement a http processor and their required stages for TLS, so that a browser can speak with a netcode server and that the server can execute the http packets in the event scope. The general option to do that, without having to develop a entire UDF around it, is ment to be possible with this libary.
- Configurability  - Each and every Server and Client can be configured independent from another. Completly different rule sets can be applied to each and every socket if necessary. So one server could run http processor and the other a netcode processor. One with TLS another with a pre shared key.
- Interchangeable  - Alot of functions within the UDF should be overwriteable. So that any dev has the ability to implement his own methods. This would be done in a way that it isnt necessary to mess around within the UDF. The Interchangeable is also going to required for various addons that might add certain
features that wouldnt work with the default functions.
- Interceptable    - It is ment to have a variety of options to intercept UDF processes to identify and / or protect against attacks and to solve certain errors that might arise while or after the development.
- Error Manageable - The UDF features a tracer to trace down all processes to identify errors and alike. A machine friendly to read error list that can call on set callbacks is ment to be included too
- Anti DDOS        - It is meant that the UDF comes at default with a toggleable Rule set to combat DDOS attacks that automatically engage when certain behaviours are recognized by a client or multiple.
- Scallable        - There will be a Addon specific to automatically Sync data between processes, and a Addon ment to offer Groups where sockets can be linked to. So that all can share and use the same data pool.
- User Management  - The Core will come at default with a Optional User Management. If enabled for the Listener then every Client has to provide a Username and Password in order to sucessfully stage through. The Database is not ment to be basic. It is ment to have an Active Userdatabase thats always loaded in the memory, a inactive Database for larger data sets and a encrypted db which only the specific user has access to (think of Tutanota). Overall all kinds of Rules and Events can be linked to users and etc. The feature will also allow for Extended Authentications like 2FA or MFA.
- Manageable       - The UDF makes use of 'select' so that only the active sockets get managed. The loop takes 1.5 ms with 1000 inactive sockets and 0.15 ms with none on a modern end user pc.

Additional information can be read within the Concept Plan.

Required libaries
The _storageS-UDF from https://github.com/OfficialLambdax/_storageS-UDF

There are also addons

https://github.com/OfficialLambdax/_netcode_Router-UDF

https://github.com/OfficialLambdax/_netcode_Proxy-UDF

https://github.com/OfficialLambdax/_netcode_Relay-UDF

Why do i develop addons before i finish the Core? Because i yet have to figure out what all needs to be in the Core to make the Addons work smooth without much additional code or Core code replacements.
