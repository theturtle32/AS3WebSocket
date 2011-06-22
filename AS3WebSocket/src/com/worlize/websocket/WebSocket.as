package com.worlize.websocket
{
	import com.adobe.crypto.SHA1;
	import com.adobe.net.URI;
	import com.adobe.net.URIEncodingBitmap;
	import com.hurlant.crypto.tls.TLSConfig;
	import com.hurlant.crypto.tls.TLSEngine;
	import com.hurlant.crypto.tls.TLSSecurityParameters;
	import com.hurlant.crypto.tls.TLSSocket;
	import com.wirelust.as3zlib.Deflate;
	import com.wirelust.as3zlib.Inflate;
	import com.wirelust.as3zlib.JZlib;
	import com.wirelust.as3zlib.ZStream;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.IDataInput;
	import flash.utils.Timer;
	
	import flashx.textLayout.debug.assert;
	
	import mx.utils.Base64Encoder;
	import mx.utils.URLUtil;
	
	[Event(name="connectionFail",type="com.worlize.websocket.WebSocketErrorEvent")]
	[Event(name="message",type="com.worlize.websocket.WebSocketEvent")]
	[Event(name="open",type="com.worlize.websocket.WebSocketEvent")]
	[Event(name="closed",type="com.worlize.websocket.WebSocketEvent")]
	public class WebSocket extends EventDispatcher
	{
		private static const MODE_UTF8:int = 0;
		private static const MODE_BINARY:int = 0;
		
		private static const MAX_HANDSHAKE_BYTES:int = 10 * 1024; // 10KiB
		
		private var _bufferedAmount:int = 0;
		
		private var _readyState:int;
		private var _uri:URI;
		private var _protocol:String;
		private var _host:String;
		private var _port:uint;
		private var _resource:String;
		private var _secure:Boolean;
		private var _origin:String;
		
		private var rawSocket:Socket;
		private var socket:Socket;
		private var timeout:uint;
		
		private var nonce:ByteArray;
		private var base64nonce:String;
		private var serverHandshakeResponse:String;
		private var serverExtensions:Array;
		private var currentFrame:WebSocketFrame;
		private var frameQueue:Vector.<WebSocketFrame>;
		private var fragmentationOpcode:int = 0;
		
		private var waitingForServerClose:Boolean = false;
		private var closeTimeout:int = 5000;
		private var closeTimer:Timer;
		
		private var handshakeBytesReceived:int;
		private var handshakeTimer:Timer;
		private var handshakeTimeout:int = 5000;
		
		private var deflateStream:Boolean = false;
		private var zstreamOut:ZStream;
		private var zstreamIn:ZStream;
		
		private var incomingBuffer:ByteArray;
		private var outgoingBuffer:ByteArray;
		
		private var tlsConfig:TLSConfig;
		private var tlsSocket:TLSSocket;
		
		private var URIpathExcludedBitmap:URIEncodingBitmap =
			new URIEncodingBitmap(URI.URIpathEscape);
		
		public var enableDeflateStream:Boolean = true;
		
		public var config:WebSocketConfig = new WebSocketConfig();
		
		public static var debug:Boolean = false;
		
		public static var logger:Function = function(text:String):void {
			trace(text);
		};
		
		public function WebSocket(uri:String, origin:String, protocol:String = null, timeout:uint = 10000)
		{
			super(null);
			_uri = new URI(uri);
			_protocol = protocol;
			_origin = origin;
			this.timeout = timeout;
			this.handshakeTimeout = timeout;
			init();
		}
		
		private function init():void {
			parseUrl();
			
			validateProtocol();

			closeTimer = new Timer(closeTimeout, 1);
			closeTimer.addEventListener(TimerEvent.TIMER, handleCloseTimer);
			
			handshakeTimer = new Timer(handshakeTimeout, 1);
			handshakeTimer.addEventListener(TimerEvent.TIMER, handleHandshakeTimer);
			
			rawSocket = socket = new Socket();
			socket.timeout = timeout;
			
			if (secure) {
				tlsConfig = new TLSConfig(TLSEngine.CLIENT,
										  null, null, null, null, null,
										  TLSSecurityParameters.PROTOCOL_VERSION);
				tlsConfig.trustAllCertificates = true;
				tlsConfig.ignoreCommonNameMismatch = true;
				socket = tlsSocket = new TLSSocket();
			}
			
			rawSocket.addEventListener(Event.CONNECT, handleSocketConnect);
			rawSocket.addEventListener(Event.CLOSE, handleSocketClose);
			rawSocket.addEventListener(IOErrorEvent.IO_ERROR, handleSocketIOError);
			rawSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, handleSocketSecurityError);
			
			socket.addEventListener(ProgressEvent.SOCKET_DATA, handleSocketData);
			
			_readyState = WebSocketState.INIT;
		}
		
		private function validateProtocol():void {
			if (_protocol) {
				var separators:Array = [
					"(", ")", "<", ">", "@",
					",", ";", ":", "\\", "\"",
					"/", "[", "]", "?", "=",
					"{", "}", " ", String.fromCharCode(9)
				];
				for (var i:int = 0; i < _protocol.length; i++) {
					var charCode:int = _protocol.charCodeAt(i);
					var char:String = _protocol.charAt(i);
					if (charCode < 0x21 || charCode > 0x7E || separators.indexOf(char) !== -1) {
						throw new WebSocketError("Illegal character '" + String.fromCharCode(char) + "' in subprotocol.");
					}
				}
			}
		}
		
		public function connect():void {
			if (_readyState === WebSocketState.INIT || _readyState === WebSocketState.CLOSED) {
				_readyState = WebSocketState.CONNECTING;
				generateNonce();
				handshakeBytesReceived = 0;
				
				rawSocket.connect(_host, _port);
				if (debug) {
					logger("Connecting to " + _host + " on port " + _port);
				}
			}
		}
		
		private function parseUrl():void {
			_host = _uri.authority;
			var scheme:String = _uri.scheme.toLocaleLowerCase();
			if (scheme === 'wss') {
				_secure = true;
				_port = 443;
			}
			else if (scheme === 'ws') {
				_secure = false;
				_port = 80;
			}
			else {
				throw new Error("Unsupported scheme: " + scheme);
			}
			
			var tempPort:uint = parseInt(_uri.port, 10);
			if (!isNaN(tempPort) && tempPort !== 0) {
				_port = tempPort;
			}
			
			var path:String = URI.fastEscapeChars(_uri.path, URIpathExcludedBitmap);
			if (path.length === 0) {
				path = "/";
			}
			var query:String = _uri.queryRaw;
			if (query.length > 0) {
				query = "?" + query;
			}
			_resource = path + query;
		}
		
		private function generateNonce():void {
			nonce = new ByteArray();
			for (var i:int = 0; i < 16; i++) {
				nonce.writeByte(Math.round(Math.random()*0xFF));
			}
			nonce.position = 0;
			var encoder:Base64Encoder = new Base64Encoder();
			encoder.encodeBytes(nonce);
			base64nonce = encoder.flush();
		}
		
		public function get readyState():int {
			return _readyState;
		}
		
		public function get bufferedAmount():int {
			return _bufferedAmount;
		}
		
		public function get uri():String {
			var uri:String;
			uri = _secure ? "wss://" : "ws://";
			uri += _host;
			if ((_secure && _port !== 443) || (!_secure && _port !== 80)) {
				uri += (":" + _port.toString())
			}
			uri += _resource;
			return uri;
		}
		
		public function get protocol():String {
			return _protocol;
		}
		
		public function get host():String {
			return _host;
		}
		
		public function get port():uint {
			return _port;
		}
		
		public function get resource():String {
			return _resource;
		}
		
		public function get secure():Boolean {
			return _secure;
		}
		
		public function get connected():Boolean {
			return readyState === WebSocketState.OPEN;
		}
		
		private function verifyConnectionForSend():void {
			if (_readyState === WebSocketState.CONNECTING) {
				throw new WebSocketError("Invalid State: Cannot send data before connected.");
			}
		}
		
		public function sendUTF(data:String):void {
			verifyConnectionForSend();
			var frame:WebSocketFrame = new WebSocketFrame();
			frame.opcode = WebSocketOpcode.TEXT_FRAME;
			frame.binaryPayload = new ByteArray();
			frame.binaryPayload.writeMultiByte(data, 'utf-8');
			fragmentAndSend(frame);
		}
		
		public function sendBytes(data:ByteArray):void {
			verifyConnectionForSend();
			var frame:WebSocketFrame = new WebSocketFrame();
			frame.opcode = WebSocketOpcode.BINARY_FRAME;
			frame.binaryPayload = data;
			fragmentAndSend(frame);
		}
		
		public function ping():void {
			verifyConnectionForSend();
			var frame:WebSocketFrame = new WebSocketFrame();
			frame.fin = true;
			frame.opcode = WebSocketOpcode.PING;
			sendFrame(frame);
		}
		
		private function pong(binaryPayload:ByteArray = null):void {
			verifyConnectionForSend();
			var frame:WebSocketFrame = new WebSocketFrame();
			frame.fin = true;
			frame.opcode = WebSocketOpcode.PONG;
			frame.binaryPayload = binaryPayload;
			sendFrame(frame);
		}
		
		private function fragmentAndSend(frame:WebSocketFrame):void {
			if (frame.opcode > 0x07) {
				throw new WebSocketError("You cannot fragment control frames.");
			}
			
			var threshold:uint = config.fragmentationThreshold;
						
			if (config.fragmentOutgoingMessages && frame.binaryPayload && frame.binaryPayload.length > threshold) {
				frame.binaryPayload.position = 0;
				var length:int = frame.binaryPayload.length;
				var numFragments:int = Math.ceil(length / threshold);
				for (var i:int = 1; i <= numFragments; i++) {
					var currentFrame:WebSocketFrame = new WebSocketFrame();
					
					// continuation opcode except for first frame.
					currentFrame.opcode = (i === 1) ? frame.opcode : 0x00;
					
					// fin set on last frame only
					currentFrame.fin = (i === numFragments);
					
					// length is likely to be shorter on the last fragment
					var currentLength:int = (i === numFragments) ? length - (threshold * (i-1)) : threshold;
					frame.binaryPayload.position  = threshold * (i-1);
					
					// Slice the right portion of the original payload
					currentFrame.binaryPayload = new ByteArray();
					frame.binaryPayload.readBytes(currentFrame.binaryPayload, 0, currentLength);
					
					sendFrame(currentFrame);
				}
			}
			else {
				frame.fin = true;
				sendFrame(frame);
			}
		}
		
		private function sendFrame(frame:WebSocketFrame):void {
			frame.mask = true;
			var buffer:ByteArray = new ByteArray();
			frame.send(buffer);
			sendData(buffer);
		}
		
		private function sendData(data:ByteArray, fullFlush:Boolean = false):void {
			if (!connected) { return; }
			data.position = 0;
			if (deflateStream) {
				zstreamOut.next_in = data;
				zstreamOut.avail_in = data.bytesAvailable;
				zstreamOut.next_in_index = 0;
				zstreamOut.next_out = new ByteArray();
				zstreamOut.next_out_index = 0;
				zstreamOut.total_out = zstreamOut.avail_out = 0x7FFFFFFF;
				var err:int = zstreamOut.deflate(fullFlush ? JZlib.Z_FULL_FLUSH : JZlib.Z_PARTIAL_FLUSH);
				if (err === JZlib.Z_STREAM_ERROR) {
					throw new Error("Zlib error deflate: " + err);
				}
				zstreamOut.next_out.position = 0;
				socket.writeBytes(zstreamOut.next_out, 0, zstreamOut.next_out.length);
				socket.flush();
				zstreamOut.next_in.clear();
				zstreamOut.next_out.clear();
			}
			else {
				socket.writeBytes(data, 0, data.bytesAvailable);
				socket.flush();
				data.clear();
			}
		}
		
		public function close(waitForServer:Boolean = true):void {
			if (socket.connected) {
				var frame:WebSocketFrame = new WebSocketFrame();
				frame.rsv1 = frame.rsv2 = frame.rsv3 = frame.mask = false;
				frame.fin = true;
				frame.opcode = WebSocketOpcode.CONNECTION_CLOSE;
				frame.closeStatus = WebSocketCloseStatus.NORMAL;
				var buffer:ByteArray = new ByteArray();
				frame.mask = true;
				frame.send(buffer);
				sendData(buffer, true);
				
				if (waitForServer) {
					waitingForServerClose = true;
					closeTimer.stop();
					closeTimer.reset();
					closeTimer.start();
				}
				dispatchClosedEvent();
			}
		}
		
		private function handleCloseTimer(event:TimerEvent):void {
			if (waitingForServerClose) {
				// server hasn't responded to our request to close the
				// connection, so we'll just close it.
				if (socket.connected) {
					socket.close();
					destructDeflateStream();
				}
			}
		}
		
		private function handleSocketConnect(event:Event):void {
			if (debug) {
				logger("Socket Connected");
			}
			if (secure) {
				if (debug) {
					logger("starting SSL/TLS");
				}
				tlsSocket.startTLS(rawSocket, _host, tlsConfig);
			}
			socket.endian = Endian.BIG_ENDIAN;
			sendHandshake();
		}
		
		private function handleSocketClose(event:Event):void {
			if (debug) {
				logger("Socket Disconnected");
			}
			dispatchClosedEvent();
		}
		
		private function handleSocketData(event:ProgressEvent=null):void {
			if (_readyState === WebSocketState.CONNECTING) {
				readServerHandshake();
				return;
			}

			if (socket.connected && socket.bytesAvailable > 0) {
				if (deflateStream) {
					zstreamIn.next_in = new ByteArray();
					zstreamIn.avail_in = socket.bytesAvailable;
					zstreamIn.next_in_index = 0;
					socket.readBytes(zstreamIn.next_in, 0, socket.bytesAvailable);
					zstreamIn.next_out = new ByteArray();
					zstreamIn.next_out_index = 0;
					zstreamIn.avail_out = 0x7FFFFFFF;
					var err:int = zstreamIn.inflate(JZlib.Z_SYNC_FLUSH);
					if (err === JZlib.Z_NEED_DICT ||
						err === JZlib.Z_DATA_ERROR ||
					 	err === JZlib.Z_MEM_ERROR) {
						failConnection("Zlib error inflate: " + err);
					}
					zstreamIn.next_out.position = 0;
					zstreamIn.next_out.readBytes(incomingBuffer, incomingBuffer.position, zstreamIn.next_out.bytesAvailable);
					zstreamIn.next_in.clear();
					zstreamIn.next_out.clear();
				}
				else {
					socket.readBytes(incomingBuffer, incomingBuffer.position, socket.bytesAvailable);
				}
			}

			// addData returns true if the frame is complete, and false
			// if more data is needed.
			while (currentFrame.addData(incomingBuffer, fragmentationOpcode, config)) {
				if (!config.assembleFragments) {
					var frameEvent:WebSocketEvent = new WebSocketEvent(WebSocketEvent.FRAME);
					frameEvent.frame = currentFrame;
					dispatchEvent(frameEvent);
				}
				processFrame(currentFrame);
				currentFrame = new WebSocketFrame();
			}
			
			if (incomingBuffer.bytesAvailable > 0) {
				// If there is still unused data left in the buffer, delete
				// the used data and reset the buffer to contain only the
				// new, unused data.
				var tempBuffer:ByteArray = new ByteArray();
				incomingBuffer.readBytes(tempBuffer, 0, incomingBuffer.bytesAvailable);
				incomingBuffer.clear();
				tempBuffer.readBytes(incomingBuffer, 0, tempBuffer.bytesAvailable);
				tempBuffer.clear();
			}
			else {
				incomingBuffer.clear();
			}
			
		}
		
		private function processFrame(frame:WebSocketFrame):void {
			var event:WebSocketEvent;
			var i:int;
			var currentFrame:WebSocketFrame;

			switch (frame.opcode) {
				case WebSocketOpcode.BINARY_FRAME:
					if (frame.fin) {
						event = new WebSocketEvent(WebSocketEvent.MESSAGE);
						event.message = new WebSocketMessage();
						event.message.type = WebSocketMessage.TYPE_BINARY;
						event.message.binaryData = frame.binaryPayload;
						dispatchEvent(event);
					}
					else if (frameQueue.length === 0) {
						if (config.assembleFragments) {
							// beginning of a fragmented message
							frameQueue.push(frame);
							fragmentationOpcode = frame.opcode;
						}
					}
					else {
						throw new WebSocketError("Illegal BINARY_FRAME received in the middle of a fragmented message.  Expected a continuation or control frame.");
					}
					break;
				case WebSocketOpcode.TEXT_FRAME:
					if (frame.fin) {
						event = new WebSocketEvent(WebSocketEvent.MESSAGE);
						event.message = new WebSocketMessage();
						event.message.type = WebSocketMessage.TYPE_UTF8;
						event.message.utf8Data = frame.binaryPayload.readMultiByte(frame.length, 'utf-8');
						dispatchEvent(event);
					}
					else if (frameQueue.length === 0) {
						if (config.assembleFragments) {
							// beginning of a fragmented message
							frameQueue.push(frame);
							fragmentationOpcode = frame.opcode;
						}
					}
					else {
						throw new WebSocketError("Illegal TEXT_FRAME received in the middle of a fragmented message.  Expected a continuation or control frame.");
					}
					break;
				case WebSocketOpcode.CONTINUATION:
					if (!config.assembleFragments) {
						return;
					}
					frameQueue.push(frame);
					if (frame.fin) {
						// end of fragmented message, so we process the whole
						// message now.  We also have to decode the utf-8 data
						// for text frames after combining all the fragments.
						event = new WebSocketEvent(WebSocketEvent.MESSAGE);
						event.message = new WebSocketMessage();
						var messageOpcode:int = frameQueue[0].opcode;
						var binaryData:ByteArray = new ByteArray();
						var totalLength:int = 0;
						for (i=0; i < frameQueue.length; i++) {
							totalLength += frameQueue[i].length;
						}
						if (totalLength > config.maxMessageSize) {
							throw new WebSocketError("Message size of " + totalLength +
								" bytes exceeds maximum accepted message size of " +
								config.maxMessageSize + " bytes.");
						}
						for (i=0; i < frameQueue.length; i++) {
							currentFrame = frameQueue[i];
							binaryData.writeBytes(
								currentFrame.binaryPayload,
								0,
								currentFrame.binaryPayload.length
							);
							currentFrame.binaryPayload.clear();
						}
						binaryData.position = 0;
						switch (messageOpcode) {
							case WebSocketOpcode.BINARY_FRAME:
								event.message.type = WebSocketMessage.TYPE_BINARY;
								event.message.binaryData = binaryData;
								break;
							case WebSocketOpcode.TEXT_FRAME:
								event.message.type = WebSocketMessage.TYPE_UTF8;
								event.message.utf8Data = binaryData.readMultiByte(binaryData.length, 'utf-8');
								break;
							default:
								throw new WebSocketError("Unexpected first opcode in fragmentation sequence: 0x" + messageOpcode.toString(16));
						}
						frameQueue = new Vector.<WebSocketFrame>();
						fragmentationOpcode = 0;
						dispatchEvent(event);
					}
					break;
				case WebSocketOpcode.PING:
					if (debug) {
						logger("Received Ping");
					}
					pong(frame.binaryPayload);
					break;
				case WebSocketOpcode.PONG:
					if (debug) {
						logger("Received Pong");
					}
					break;
				case WebSocketOpcode.CONNECTION_CLOSE:
					if (debug) {
						logger("Received close from server");
					}
					if (waitingForServerClose) {
						// got confirmation from server, finish closing connection
						closeTimer.stop();
						waitingForServerClose = false;
						socket.close();
						destructDeflateStream();
					}
					else {
						close(false);
					}
					break;
				default:
					if (debug) {
						logger("Unrecognized Opcode: 0x" + frame.opcode.toString(16));
					}
					break;
			}
		}
		
		private function handleSocketIOError(event:IOErrorEvent):void {
			if (debug) {
				logger("IO Error: " + event);
			}
			dispatchEvent(event.clone());
			dispatchClosedEvent();
		}
		
		private function handleSocketSecurityError(event:SecurityErrorEvent):void {
			if (debug) {
				logger("Security Error: " + event);
			}
			dispatchEvent(event.clone());
			dispatchClosedEvent();
		}
		
		private function sendHandshake():void {
			serverHandshakeResponse = "";
			
			var text:String = "";
			text += "GET " + resource + " HTTP/1.1\r\n";
			text += "Host: " + host + "\r\n";
			text += "Upgrade: websocket\r\n";
			text += "Connection: Upgrade\r\n";
			text += "Sec-WebSocket-Key: " + base64nonce + "\r\n";
			text += "Sec-Websocket-Origin: " + _origin + "\r\n";
			text += "Sec-WebSocket-Version: 8\r\n";
			if (protocol) {
				text += "Sec-WebSocket-Protocol: " + protocol + "\r\n";
			}
			// TODO: Handle Extensions
			if (enableDeflateStream) {
				var extension:String = "deflate-stream";
				text += "Sec-WebSocket-Extensions: " + extension + "\r\n";
			}
			text += "\r\n";
			
			if (debug) {
				logger(text);
			}
			
			socket.writeMultiByte(text, 'us-ascii');
			
			handshakeTimer.stop();
			handshakeTimer.reset();
			handshakeTimer.start();
		}
		
		private function failHandshake(message:String = "Unable to complete websocket handshake."):void {
			_readyState = WebSocketState.CLOSED;
			if (socket.connected) {
				socket.close();
			}
			
			handshakeTimer.stop();
			handshakeTimer.reset();
			
			var errorEvent:WebSocketErrorEvent = new WebSocketErrorEvent(WebSocketErrorEvent.CONNECTION_FAIL);
			errorEvent.text = message;
			dispatchEvent(errorEvent);
			
			var event:WebSocketEvent = new WebSocketEvent(WebSocketEvent.CLOSED);
			dispatchEvent(event);
		}
		
		private function failConnection(message:String):void {
			_readyState = WebSocketState.CLOSED;
			if (socket.connected) {
				socket.close();
			}
			
			var errorEvent:WebSocketErrorEvent = new WebSocketErrorEvent(WebSocketErrorEvent.CONNECTION_FAIL);
			errorEvent.text = message;
			dispatchEvent(errorEvent);
			
			var event:WebSocketEvent = new WebSocketEvent(WebSocketEvent.CLOSED);
			dispatchEvent(event);
		}
		
		private function readServerHandshake():void {
			var upgradeHeader:Boolean = false;
			var connectionHeader:Boolean = false;
			var serverProtocolHeaderMatch:Boolean = false;
			var keyValidated:Boolean = false;
			var headersTerminatorIndex:int = -1;
			
			// Load in HTTP Header lines until we encounter a double-newline.
			while (headersTerminatorIndex === -1 && readHandshakeLine()) {
				if (handshakeBytesReceived > MAX_HANDSHAKE_BYTES) {
					failHandshake("Received more than " + MAX_HANDSHAKE_BYTES + " bytes during handshake.");
					return;
				}

				headersTerminatorIndex = serverHandshakeResponse.search(/\r?\n\r?\n/);
			}
			if (headersTerminatorIndex === -1) {
				return;
			}

			if (debug) {
				logger("Server Response Headers:\n" + serverHandshakeResponse);
			}
			
			// Slice off the trailing \r\n\r\n from the handshake data
			serverHandshakeResponse = serverHandshakeResponse.slice(0, headersTerminatorIndex);
			
			var lines:Array = serverHandshakeResponse.split(/\r?\n/);

			// Validate status line
			var responseLine:String = lines.shift();
			var responseLineMatch:Array = responseLine.match(/^(HTTP\/\d\.\d) (\d{3}) ?(.*)$/i); 
			if (responseLineMatch.length === 0) {
				failHandshake("Unable to find correctly-formed HTTP status line.");
				return;
			}
			var httpVersion:String = responseLineMatch[1];
			var statusCode:int = parseInt(responseLineMatch[2], 10);
			var statusDescription:String = responseLineMatch[3];
			if (debug) {
				logger("HTTP Status Received: " + statusCode + " " + statusDescription);
			}
			
			// Verify correct status code received
			if (statusCode !== 101) {
				failHandshake("An HTTP response code other than 101 was received.  Actual Response Code: " + statusCode + " " + statusDescription);
				return;
			}

			// Interpret HTTP Response Headers
			serverExtensions = [];
			try {
				while (lines.length > 0) {
					responseLine = lines.shift();
					var header:Object = parseHTTPHeader(responseLine);
					var lcName:String = header.name.toLocaleLowerCase();
					var lcValue:String = header.value.toLocaleLowerCase();
					if (lcName === 'upgrade' && lcValue === 'websocket') {
						upgradeHeader = true;
					}
					else if (lcName === 'connection' && lcValue === 'upgrade') {
						connectionHeader = true;
					}
					else if (lcName === 'sec-websocket-extensions' && header.value) {
						var extensionsThisLine:Array = header.value.split(',');
						serverExtensions = serverExtensions.concat(extensionsThisLine);
					}
					else if (lcName === 'sec-websocket-accept') {
						var expectedKey:String = SHA1.hashToBase64(base64nonce + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
						if (debug) {
							logger("Expected Sec-WebSocket-Accept value: " + expectedKey);
						}
						if (header.value === expectedKey) {
							keyValidated = true;
						}
					}
				}
			}
			catch(e:Error) {
				failHandshake("There was an error while parsing the following HTTP Header line:\n" + responseLine);
				return;
			}
			
			if (!upgradeHeader) {
				failHandshake("The server response did not include a valid Upgrade: websocket header.");
				return;
			}
			if (!connectionHeader) {
				failHandshake("The server response did not include a valid Connection: upgrade header.");
				return;
			}
			if (!keyValidated) {
				failHandshake("Unable to validate server response for Sec-Websocket-Accept header.");
				return;
			}

			if (debug) {
				logger("Server Extensions: " + serverExtensions.join(' | '));
			}
			
			// The connection is validated!!
			handshakeTimer.stop();
			handshakeTimer.reset()
			
			serverHandshakeResponse = null;
			_readyState = WebSocketState.OPEN;
			
			if (serverExtensions.indexOf('deflate-stream') !== -1) {
				initDeflateStream();
			}
			
			// prepare for first frame
			currentFrame = new WebSocketFrame();
			frameQueue = new Vector.<WebSocketFrame>();
			
			// Initialize Stream Buffers
			incomingBuffer = new ByteArray();
			incomingBuffer.endian = Endian.BIG_ENDIAN;
			outgoingBuffer = new ByteArray();
			outgoingBuffer.endian = Endian.BIG_ENDIAN;
			
			dispatchEvent(new WebSocketEvent(WebSocketEvent.OPEN));
			
			// Start reading data
			handleSocketData();
			return;
		}
		
		private function handleHandshakeTimer(event:TimerEvent):void {
			failHandshake();
		}
		
		private function parseHTTPHeader(line:String):Object {
			var header:Array = line.split(/\: +/);
			return header.length === 2 ? {
				name: header[0],
				value: header[1]
			} : null;
		}
		
		// Return true if the header is completely read
		private function readHandshakeLine():Boolean {
			var char:String;
			while (socket.bytesAvailable) {
				char = socket.readMultiByte(1, 'us-ascii');
				handshakeBytesReceived ++;
				serverHandshakeResponse += char;
				if (char == "\n") {
					return true;
				}
			}
			return false;
		}
		
		private function initDeflateStream():void {
			var err:int;
			// JZlib and subsequently as3zlib only support a minimum window
			// bits size of 9 for deflate, not 8 like C zlib.  So we'll use
			// that I guess.  Had initially planned to use 8 because that's
			// the value that Andy Green's libwebsockets C library uses.
			var windowBitsOut:int = 9;
			var windowBitsIn:int = 8;
			
			deflateStream = true;
			zstreamOut = new ZStream();
			zstreamIn = new ZStream();
			
			err = zstreamOut.deflateInitWithIntIntBoolean(JZlib.Z_BEST_SPEED, windowBitsOut, true);
			if (err !== JZlib.Z_OK) {
				failConnection("Error calling deflateInitWithIntIntBoolean() - " + err);
			}
			
			err = zstreamIn.inflateInitWithWbitsNoWrap(windowBitsIn, true);
			if (err !== JZlib.Z_OK) {
				failConnection("Error calling inflateInitWithWbitsNoWrap() - " + err);
			}
			
			if (debug) {
				logger("ZLib constructed");
			}
		}
		
		private function destructDeflateStream():void {
			if (deflateStream) {
				zstreamIn.inflateEnd();
				zstreamOut.deflateEnd();
				zstreamIn = null;
				zstreamOut = null;
				if (debug) {
					logger("ZLib destructed");
				}
			}
		}
		
		private function dispatchClosedEvent():void {
			if (handshakeTimer.running) {
				handshakeTimer.stop();
			}
			if (_readyState !== WebSocketState.CLOSED) {
				_readyState = WebSocketState.CLOSED;
				var event:WebSocketEvent = new WebSocketEvent(WebSocketEvent.CLOSED);
				dispatchEvent(event);
			}
		}
				
	}
}
