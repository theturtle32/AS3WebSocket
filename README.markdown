ActionScript 3 WebSocket Client
===============================

*This is an AS3 implementation of a client library of the WebSocket protocol, as specified in the -06 draft.*

Explanation
-----------
THIS CLIENT WILL NOT WORK with draft-75 or draft-76/-00 servers that are deployed on the internet.  It is only for the most recent -06 draft.  Once the -07 draft is released I will update this client to work only with -07, and so on, until the final version of the protocol is ratified by the IETF.  I will keep a version tracking each of the IETF drafts in its own branch, with master tracking the latest.

I intend to keep this library updated to the latest draft of the IETF WebSocket protocol when new versions are released.  I built this library because I wanted to be able to make use of the latest draft of the protocol, but no browser implements it yet.

See the [WebSocket Protocol draft specification](http://www.ietf.org/id/draft-ietf-hybi-thewebsocketprotocol-06.txt).


The AS3WebSocket directory contains a Flash Builder 4 Library Project that contains the WebSocket client library.

The testApp directory contains a Flash Builder 4 Air Project that uses the AS3WebSocket library and implements two of the test subprotocols from Andy Green's libwebsockets test server, the dumb-increment-protocol, and the lws-mirror-protocol.  [Click here](http://git.warmcat.com/cgi-bin/cgit/libwebsockets) for more detail about the libwebsockets test server.


Download
--------
- The Adobe Air test application is available under the "Downloads" section above.


Features
--------
- Based on -06 draft of the WebSocket protocol
- Support for deflate-stream extension
- wss:// TLS support w/ hurlant as3crypto library
  - Learn more here: [as3crypto on Google Code](http://code.google.com/p/as3crypto/)
- Handle receiving fragmented frames (theoretically. I haven't set up a server that can send fragmented packets against which to test this.)
- Test Adobe Air app implements two of the subprotocols supported by Andy Green's libwebsockets-test-server:
  - *dumb-increment-protocol* (simple streaming incrementing numbers)
  - *lws-mirror-protocol* (shared drawing canvas)
  - Added *fraggle-protocol* to the list, but I'm having difficulty testing as there seems to be a problem with the libwebsockets-test-fraggle server (its own client complains of corrupt data intermittently when I run it on my machine)


Known Issues:
-------------
- Fragmentation is not well tested
- There is no user-provided extension API implemented
- Only the libwebsocket-test-server subprotocols mentioned have been tested so far


Usage Example
-------------

    var websocket:WebSocket = new WebSocket("wss://localhost:4321/foo?bing=baz", "*", "my-chat-protocol");
    websocket.enableDeflateStream = true;
    websocket.addEventListener(WebSocketEvent.CLOSED, handleWebSocketClosed);
    websocket.addEventListener(WebSocketEvent.OPEN, handleWebSocketOpen);
    websocket.addEventListener(WebSocketEvent.MESSAGE, handleWebSocketMessage);
    websocket.addEventListener(WebSocketErrorEvent.CONNECTION_FAIL, handleConnectionFail);
    websocket.connect();

    function handleWebSocketOpen(event:WebSocketEvent):void {
      trace("Connected");
      websocket.sendUTF("Hello World!\n");
      
      var binaryData:ByteArray = new ByteArray();
      binaryData.writeUTF("Hello as Binary Message!");
      websocket.sendBytes(binaryData);
    }

    function handleWebSocketClosed(event:WebSocketEvent):void {
      trace("Disconnected");
    }

    private function handleConnectionFail(event:WebSocketErrorEvent):void {
      trace("Connection Failure: " + event.text);
    }

    function handleWebSocketMessage(event:WebSocketEvent):void {
      if (event.message.type === WebSocketMessage.TYPE_UTF8) {
        trace("Got message: " + event.message.utf8Data);
      }
      else if (event.message.type === WebSocketMessage.TYPE_BINARY) {
        trace("Got binary message of length " + event.message.binaryData.length);
      }
    }
