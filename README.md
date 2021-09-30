# _netcode_Core-UDF
a extended TCP/TLS/IPv4/IPv6 UDF for Autoit3 (Support for Win XP, Vista, 7, 8, 8.1, 10 - X32 and X64 - Autoit Stable and Beta)

Beaware that the UDF (User Defined Functions) is neither Alpha nor Beta or Stable. It is still in its Concept Creation Phase. This means that features a missing eg. IPv6 and TLS and that already included Features require complete Overhauls. So its best that you do not use it yet. There also is little to no Documentation yet (including UDF headers), because its pointless to create a whole .chm yet where everything is still subject to change.


The UDF is ment to be Stable, Easy to use, Performant, Secure and Configurable. And overall ment to offer code for any network related usages. Autoit3 already has alot of TCP UDF's but through my testings i found that most, not to say all, are to slow, insecure and just have the bare minimum feature set. I had to create something that can be used in as many situations as possible.

_netcode is going to Offer
- Security         - TLS v1.2 and v1.3 (AES-256-GCM, AES-256-CBC, RSA, and your customs)
- Speed            - 'netcode' managemode = 60 mb/s, 'rawlinked' managemode = 190 mb/s - tested on my pc
- Compatibility    - IPv4 and IPv6, Windows XP, Vista, 7, 8, 8.1, 10
- Configurability  - Each and every Server and Client can be configured independent from another. Completly different rule sets can be applied to each and every socket if necessary.
- Interchangeable  - Every Function will be overwriteable aka replaceable without the need of doing actual code changes inside the UDF
- Interceptable    - It is ment to have a variety of options to intercept UDF processes to identify and / or protect against attacks and to solve certain errors that may arise
- Error Manageable - The UDF features a tracer to trace down all processes to identify errors and alike. A machine friendly to read error list that can call on set callbacks is ment to be included too
- Anti DDOS        - It is meant that the UDF comes at default with a Rule set to combat DDOS attacks that automatically engage when certain behaviours are recognized by a client or multiple
- Scallable        - There will be a Addon specific to automatically Sync data between processes, and a Addon ment to offer Groups where sockets can be linked to. So that all can share and use the same data pool.
- User Management  - The Core will come at default with a Optional User Management. If enabled for the Listener then every Client has to provide a Username and Password in order to sucessfully stage through. The Database is not ment to be basic. It is ment to have an Active Userdatabase thats always loaded in the memory, a inactive Database for larger data sets and a encrypted db which only the specific user has access to (think of Tutanota). Overall all kinds of Rules and Events can be linked to users and etc. The feature will also allow for 2FA authentications.
- Manageable       - The UDF makes use of 'select' to that only the active sockets get managed. The loop takes 1.5 ms with 1000 inactive sockets and 0.15 ms with none (test results from my pc)


There are also addons

https://github.com/OfficialLambdax/_netcode_Router-UDF

https://github.com/OfficialLambdax/_netcode_Proxy-UDF

https://github.com/OfficialLambdax/_netcode_Relay-UDF

https://github.com/OfficialLambdax/_netcode_P2PCentralized-UDF

https://github.com/OfficialLambdax/_netcode_P2PDecentralized-UDF

Why do i develop addons before i finish the Core? Because i yet have to figure out what all needs to be in the Core to make the Addons work smooth without much additional code or Core code replacements.
