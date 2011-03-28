package com.worlize.websocket
{
	import com.adobe.crypto.SHA1;
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
	
	import mx.utils.Base64Encoder;
	import mx.utils.URLUtil;
	
	public class WebSocket extends EventDispatcher
	{
		private static const MODE_UTF8:int = 0;
		private static const MODE_BINARY:int = 0;
		
		private var _bufferedAmount:int = 0;
		
		private var _readyState:int;
		private var _uri:String;
		private var _protocol:String;
		private var _host:String;
		private var _port:uint;
		private var _resource:String;
		private var _secure:Boolean;
		private var _origin:String;
		
		private var socket:Socket;
		private var timeout:uint;
		
		private var nonce:ByteArray;
		private var base64nonce:String;
		private var serverHandshakeResponse:String;
		private var serverExtensions:Array;
		private var currentFrame:WebSocketFrame;
		
		private var waitingForServerClose:Boolean = false;
		private var closeTimeout:int = 5000;
		private var closeTimer:Timer;
		
		private var deflateStream:Boolean = false;
		private var zstreamOut:ZStream;
		private var zstreamIn:ZStream;
		
		private var incomingBuffer:ByteArray;
		private var outgoingBuffer:ByteArray;
		
		public var enableDeflateStream:Boolean = true;
		
		public static var debug:Boolean = true;
		
		public static var logger:Function = function(text:String):void {
			logger(text);
		};
		
		public function WebSocket(url:String, origin:String, protocol:String = null, timeout:uint = 20000, socket:Socket = null)
		{
			super(null);
			_uri = url;
			_protocol = protocol;
			_origin = origin;
			this.timeout = timeout;
			if (socket) {
				this.socket = socket;
			}
			else {
				this.socket = new Socket();
			}
			init();
		}
		
		private function init():void {
			parseUrl();
			this.socket.timeout = timeout;
			this.socket.endian = Endian.BIG_ENDIAN;
			this.socket.addEventListener(Event.CONNECT, handleSocketConnect);
			this.socket.addEventListener(Event.CLOSE, handleSocketClose);
			this.socket.addEventListener(ProgressEvent.SOCKET_DATA, handleSocketData);
			this.socket.addEventListener(IOErrorEvent.IO_ERROR, handleSocketIOError);
			this.socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, handleSocketSecurityError);
			
			closeTimer = new Timer(closeTimeout, 1);
			closeTimer.addEventListener(TimerEvent.TIMER, handleCloseTimer);
			
			_readyState = WebSocketState.INIT;
		}
		
		public function connect():void {
			if (_readyState === WebSocketState.INIT || _readyState === WebSocketState.CLOSED) {
				_readyState = WebSocketState.CONNECTING;
				generateNonce();
				
				socket.connect(_host, _port);
				if (debug) {
					logger("Connecting to " + _host + " on port " + _port);
				}
			}
		}
		
		private function parseUrl():void {
			_host = URLUtil.getServerName(_uri);
			var protocol:String = URLUtil.getProtocol(_uri).toLocaleLowerCase();
			if (protocol === 'wss') {
				_secure = true;
				_port = 443;
			}
			else if (protocol === 'ws') {
				_secure = false;
				_port = 80;
			}
			else {
				throw new Error("Unsupported Protocol: " + protocol);
			}
			
			var tempPort:uint = URLUtil.getPort(_uri);
			if (tempPort > 0) {
				_port = tempPort;
			}
			
			var temp:String = _uri;
			if (temp.indexOf('//') !== -1) {
				temp = temp.slice(temp.indexOf('//')+2);
			}
			if (temp.indexOf('/') !== -1) {
				temp = temp.slice(temp.indexOf('/'));
				_resource = temp;
			}
			else {
				_resource = "/";
			}
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
			frame.fin = true;
			frame.opcode = WebSocketOpcode.TEXT_FRAME;
			frame.utf8Payload = data;
			var buffer:ByteArray = new ByteArray();
			frame.send(buffer);
			sendData(buffer);
		}
		
		public function sendBytes(data:ByteArray):void {
			verifyConnectionForSend();
			var frame:WebSocketFrame = new WebSocketFrame();
			frame.fin = true;
			frame.opcode = WebSocketOpcode.BINARY_FRAME;
			frame.binaryPayload = data;
			var buffer:ByteArray = new ByteArray();
			frame.send(buffer);
			sendData(buffer);
		}
		
		public function ping():void {
			verifyConnectionForSend();
			var frame:WebSocketFrame = new WebSocketFrame();
			frame.fin = true;
			frame.opcode = WebSocketOpcode.PING;
			var buffer:ByteArray = new ByteArray();
			frame.send(buffer);
			sendData(buffer);
		}
		
		public function pong():void {
			verifyConnectionForSend();
			var frame:WebSocketFrame = new WebSocketFrame();
			frame.fin = true;
			frame.opcode = WebSocketOpcode.PONG;
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
				zstreamOut.next_in.clear();
				zstreamOut.next_out.clear();
			}
			else {
				socket.writeBytes(data, 0, data.bytesAvailable);
				data.clear();
			}
		}
		
		public function close(waitForServer:Boolean = true):void {
			if (socket.connected) {
				var frame:WebSocketFrame = new WebSocketFrame();
				frame.rsv1 = frame.rsv2 = frame.rsv3 = frame.rsv4 = false;
				frame.fin = true;
				frame.opcode = WebSocketOpcode.CONNECTION_CLOSE;
				frame.closeStatus = WebSocketCloseStatus.NORMAL;
				var buffer:ByteArray = new ByteArray();
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
						throw new Error("Zlib error inflate: " + err);
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
			while (currentFrame.addData(incomingBuffer)) {
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
			// for now just publish the message, ignoring fragmentation etc.
			// frameQueue.push(frame);
			var event:WebSocketEvent = new WebSocketEvent(WebSocketEvent.MESSAGE);

			switch (frame.opcode) {
				case WebSocketOpcode.BINARY_FRAME:
					event.message = new WebSocketMessage();
					event.message.type = WebSocketMessage.TYPE_BINARY;
					event.message.binaryData = frame.binaryPayload;
					dispatchEvent(event);
					break;
				case WebSocketOpcode.TEXT_FRAME:
					event.message = new WebSocketMessage();
					event.message.type = WebSocketMessage.TYPE_UTF8;
					event.message.utf8Data = frame.utf8Payload;
					dispatchEvent(event);
					break;
				case WebSocketOpcode.PING:
					if (debug) {
						logger("Received Ping");
					}
					pong();
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
						dispatchClosedEvent();
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
			close();
		}
		
		private function handleSocketSecurityError(event:SecurityErrorEvent):void {
			if (debug) {
				logger("Security Error: " + event);
			}
			dispatchEvent(event.clone());
			close();
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
			text += "Sec-WebSocket-Version: 6\r\n";
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
		}
		
		private function failHandshake():void {
			_readyState = WebSocketState.CLOSED;
			socket.close();
		}
		
		private function readServerHandshake():void {
			var upgradeHeader:Boolean = false;
			var connectionHeader:Boolean = false;
			var serverProtocolHeaderMatch:Boolean = false;
			var keyValidated:Boolean = false;
			
			while (socket.bytesAvailable) {
			
				try {
					readHandshakeLine();
				}
				catch (e:WebSocketError) {
					return;
				}
	
				if (serverHandshakeResponse.indexOf("\r\n\r\n") !== -1) {
					// have all the http headers
					
					if (debug) {
						logger("Have all the http headers.");
						logger(serverHandshakeResponse);
					}
					
					var lines:Array = serverHandshakeResponse.split("\r\n");
					var responseLine:String = lines.shift();
					if (responseLine.indexOf("HTTP/1.1 101") === 0) {
						if (debug) {
							logger("101 response received!");
						}
						// got 101 response!  Woohoo!
						
						serverExtensions = [];
						
						while (lines.length > 0) {
							responseLine = lines.shift();
							var header:Array = responseLine.split(/\: */);
							var name:String = header[0];
							var value:String = header[1];
							if (name === null || value === null) {
								continue;
							}
							var lcName:String = name.toLocaleLowerCase();
							var lcValue:String = value.toLocaleLowerCase();
							if (lcName === 'upgrade' && lcValue === 'websocket') {
								upgradeHeader = true;
							}
							else if (lcName === 'connection' && lcValue === 'upgrade') {
								connectionHeader = true;
							}
							else if (lcName === 'sec-websocket-extensions' && value) {
								var extensionsThisLine:Array = value.split(',');
								serverExtensions = serverExtensions.concat(extensionsThisLine);
							}
							else if (lcName === 'sec-websocket-accept') {
								var expectedKey:String = SHA1.hashToBase64(base64nonce + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
								logger("Expected Sec-WebSocket-Accept value: " + expectedKey);
								if (value === expectedKey) {
									keyValidated = true;
								}
							}
						}
						if (debug) {
							logger("UpgradeHeader: " + upgradeHeader);
							logger("ConnectionHeader: " + connectionHeader);
							logger("KeyValidated: " + keyValidated);
							logger("Server Extensions: " + serverExtensions.join(' | '));
						}
						if (upgradeHeader && connectionHeader && keyValidated) {
							// The connection is validated!!
							
							serverHandshakeResponse = null;
							_readyState = WebSocketState.OPEN;
							
							if (serverExtensions.indexOf('deflate-stream') !== -1) {
								initDeflateStream();
							}
							
							// prepare for first frame
							currentFrame = new WebSocketFrame();
							
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
						else {
							failHandshake();
							return;
						}
					}
					else {
						failHandshake();
						return;
					}
				}
			}
		}
		
		private function readHandshakeLine():String {
			var line:String = "";
			var char:String;
			while (socket.bytesAvailable) {
				char = socket.readMultiByte(1, 'us-ascii');
				line += char;
				if (char == "\n") {
					break;
				}
			}
			serverHandshakeResponse += line;
			if (line.indexOf("\n") === -1) {
				throw new WebSocketError("Not enough bytes to form a line yet.");
			}
			return line;
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
				throw new Error("Error calling deflateInitWithIntIntBoolean() - " + err);
			}
			
			err = zstreamIn.inflateInitWithWbitsNoWrap(windowBitsIn, true);
			if (err !== JZlib.Z_OK) {
				throw new Error("Error calling inflateInitWithWbitsNoWrap() - " + err);
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
			_readyState = WebSocketState.CLOSED;
			var event:WebSocketEvent = new WebSocketEvent(WebSocketEvent.CLOSED);
			dispatchEvent(event);
		}
				
	}
}