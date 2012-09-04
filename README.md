Background
==========

Lehto is the name of a very simple new networked virtual world technology, proposed to be hosted under the realXtend umbrella. It was developed as the ‘Light Version’ in the Berlin Virtual Gallery Weekend project during spring 2012, for Spinningwire Ltd by Playsign. It was then made into a generic open source engine / library during summer 2012 to be used by anyone interested, similar to other realXtend technologies. It is mature and proven robust enough for public web services and commercial use.

Architecture
============

Technologywise Lehto is two unrelated things: Flash and XMPP. Both are new and experimental within realXtend, and may be applied independently, as explained in the following:

1. Flash client
---------------

Lehto basically is a realXtend client made with Flash, utilizing the new Stage3d hardware accelerated graphics technology, via the Away3d open source 3d engine.

Static 3d scenes are loaded from normal files, we are currently using the .obj format and have exported the meshes from Blender.

Besides displaying the scene, any functionality can be added in applications by simply writing it using the Flash and Away3d Actionscript (Adobe’s Javascript/ECMAscript variant).

The client can be deployed via the web, typically for desktop and laptop computer use, in which case the user uses any web browser with the Flash plugin available. For mobile platforms such as iOS and Android, the same client application can be packaged as a standalone application (‘app’), in which the runtime is called Air (which is Flash + extra things such as accelerometers and camera access etc).

Lehto does not connect to realXtend Tundra, it does not require Tundra servers to operate. Plain web hosting suffices for single user applications, and XMPP is used for communication (chat) and presence (avatar movements). A Tundra client (for example with kNet protocol) could be implemented with Flash, and we have tested it minimally in so-called FlashNaali, but Lehto does not feature that (currently).

2. XMPP
-------

Lehto uses XMPP for all messaging (i.e. all networking except the HTTP used for data downloads).

For the application messaging in a 3d scene there is a corresponding XMPP room, utilizing the XMPP Multi-User Chat extension (MUC). Or in the case of a large or otherwise optimized scene, multiple MUCs for different parts of the scene. It is technically identical to human chat channels, but utilized by Lehto clients to send control messages, such as avatar movements.

There is no scene server in the XMPP level, but server side like functionality is implemented with XMPP bots. For example, the feature to teleport to a user by clicking the user’s name in the chat roster is implemented with a server side XMPP bot (automated client) tracking movements and being able to reply to queries about current positions.

A standard normal XMPP server suffices, no custom extensions are needed for it apart from the standard MUC extension. So far we have been happily using ejabberd. The client side code uses the open source XIFF AS3 library from igniterealtime.com.

Use of XMPP for authentication, presence, chat etc. with virtual worlds is of course not limited to Flash clients. It is easy to use it also with e.g. HTML+Javascript written clients such as WebNaali (with Strophe.js), and in the native C++ written Ogre+Qt Tundra (with QTXMPP). This is however not made yet -- we’ll see if a ‘WebLehto’ or TundraLehto or something makes sense.

Normal XMPP clients, IM apps such as Adium, can be used to participate in human XMPP chats. Google talk and Facebook chat also use XMPP, but do not currently feature rooms (except Google hangouts?!), they as applications do not work to join in public XMPP/Lehto chats. For authentication when using the Lehto client FB and gmail accounts might just work (with xmpp federation), we haven’t tested that yet.