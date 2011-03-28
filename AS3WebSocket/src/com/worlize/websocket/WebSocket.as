package com.worlize.websocket
{
	import com.adobe.crypto.SHA1;
	
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
	import flash.utils.Timer;
	
	import mx.utils.Base64Encoder;
	import mx.utils.URLUtil;
	
	public class WebSocket extends EventDispatcher
	{
		private static const MODE_UTF8:int = 0;
		private static const MODE_BINARY:int = 0;
		
		private static const PARSE_NEW_FRAME:int = 0;
		private static const PARSE_WAITING_FOR_16_BIT_LENGTH:int = 1;
		private static const PARSE_WAITING_FOR_64_BIT_LENGTH:int = 2;
		private static const PARSE_WAITING_FOR_PAYLOAD:int = 3;

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
		
		private var parseState:int = 0;
		private var nonce:ByteArray;
		private var base64nonce:String;
		private var serverHandshakeResponse:String;
		private var serverExtensions:Array;
		private var currentFrame:WebSocketFrame;
		
		private var waitingForServerClose:Boolean = false;
		private var closeTimeout:int = 5000;
		private var closeTimer:Timer;
		
		public static var debug:Boolean = true;
		
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
					trace("Connecting to " + _host + " on port " + _port);
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
			frame.send(socket);
		}
		
		public function sendBytes(data:ByteArray):void {
			verifyConnectionForSend();
			var frame:WebSocketFrame = new WebSocketFrame();
			frame.fin = true;
			frame.opcode = WebSocketOpcode.BINARY_FRAME;
			frame.binaryPayload = data;
			frame.send(socket);
		}
		
		public function ping():void {
			verifyConnectionForSend();
			var frame:WebSocketFrame = new WebSocketFrame();
			frame.fin = true;
			frame.opcode = WebSocketOpcode.PING;
			frame.send(socket);
		}
		
		public function pong():void {
			verifyConnectionForSend();
			var frame:WebSocketFrame = new WebSocketFrame();
			frame.fin = true;
			frame.opcode = WebSocketOpcode.PONG;
			frame.send(socket);
		}
		
		public function close(waitForServer:Boolean = true):void {
			if (socket.connected) {
				var frame:WebSocketFrame = new WebSocketFrame();
				frame.rsv1 = frame.rsv2 = frame.rsv3 = frame.rsv4 = false;
				frame.fin = true;
				frame.opcode = WebSocketOpcode.CONNECTION_CLOSE;
				frame.closeStatus = WebSocketCloseStatus.NORMAL;
				frame.send(socket);
				
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
				}
			}
		}
		
		private function handleSocketConnect(event:Event):void {
			if (debug) {
				trace("Socket Connected");
			}
			sendHandshake();
		}
		
		private function handleSocketClose(event:Event):void {
			if (debug) {
				trace("Socket Disconnected");
			}
			dispatchClosedEvent();
		}
		
		private function handleSocketData(event:ProgressEvent=null):void {
			if (_readyState === WebSocketState.CONNECTING) {
				readServerHandshake();
				return;
			}

			// addData returns true if the frame is complete, or false
			// if more data is needed.
			while (socket.connected && currentFrame.addData(socket)) {
				processFrame(currentFrame);
				currentFrame = new WebSocketFrame();
			}
		}
		
		private function processFrame(frame:WebSocketFrame):void {
			// for now just publish the message, ignoring fragmentation etc.
			// frameQueue.push(frame);
			var event:WebSocketEvent = new WebSocketEvent(WebSocketEvent.MESSAGE);

			if (frame.opcode === WebSocketOpcode.BINARY_FRAME) {
				event.message = new WebSocketMessage();
				event.message.type = WebSocketMessage.TYPE_BINARY;
				event.message.binaryData = frame.binaryPayload;
				dispatchEvent(event);
			}

			else if (frame.opcode === WebSocketOpcode.TEXT_FRAME) {
				event.message = new WebSocketMessage();
				event.message.type = WebSocketMessage.TYPE_UTF8;
				event.message.utf8Data = frame.utf8Payload;
				dispatchEvent(event);
			}
			
			else if (frame.opcode === WebSocketOpcode.PING) {
				if (debug) {
					trace("Received Ping");
				}
				pong();
			}
			
			else if (frame.opcode === WebSocketOpcode.PONG) {
				if (debug) {
					trace("Received Pong");
				}
			}
			
			else if (frame.opcode === WebSocketOpcode.CONNECTION_CLOSE) {
				if (debug) {
					trace("Received close from server");
				}
				if (waitingForServerClose) {
					// got confirmation from server, finish closing connection
					closeTimer.stop();
					waitingForServerClose = false;
					socket.close();
				}
				else {
					close(false);
					dispatchClosedEvent();
				}
			}
		}
		
		private function handleSocketIOError(event:IOErrorEvent):void {
			if (debug) {
				trace("IO Error: " + event);
			}
			close();
		}
		
		private function handleSocketSecurityError(event:SecurityError):void {
			if (debug) {
				trace("Security Error: " + event);
			}
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
//			var extension:String = "deflate-stream";
//			text += "Sec-WebSocket-Extensions: " + extension + "\r\n";
			text += "\r\n";
			
			if (debug) {
				trace(text);
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
						trace("Have all the http headers.");
						trace(serverHandshakeResponse);
					}
					
					var lines:Array = serverHandshakeResponse.split("\r\n");
					var responseLine:String = lines.shift();
					if (responseLine.indexOf("HTTP/1.1 101") === 0) {
						if (debug) {
							trace("101 response received!");
						}
						// got 101 response!  Woohoo!
						
						serverExtensions = [];
						
						while (lines.length > 0) {
							responseLine = lines.shift();
							var header:Array = responseLine.split(/\:\s*/);
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
							else if (lcName === 'sec-websocket-extension' && value) {
								var extensionsThisLine:Array = value.split(',');
								serverExtensions = serverExtensions.concat(extensionsThisLine);
							}
							else if (lcName === 'sec-websocket-accept') {
								var expectedKey:String = SHA1.hashToBase64(base64nonce + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
								trace("Expected Sec-WebSocket-Accept value: " + expectedKey);
								if (value === expectedKey) {
									keyValidated = true;
								}
							}
						}
						if (debug) {
							trace("UpgradeHeader: " + upgradeHeader);
							trace("ConnectionHeader: " + connectionHeader);
							trace("KeyValidated: " + keyValidated);
							trace("Server Extensions:\n" + serverExtensions.join(' | '));
						}
						if (upgradeHeader && connectionHeader && keyValidated) {
							// The connection is validated!!
							
							serverHandshakeResponse = null;
							_readyState = WebSocketState.OPEN;
							parseState = PARSE_NEW_FRAME;
							
							// prepare for first frame
							currentFrame = new WebSocketFrame();
							
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
		
		private function dispatchClosedEvent():void {
			_readyState = WebSocketState.CLOSED;
			var event:WebSocketEvent = new WebSocketEvent(WebSocketEvent.CLOSED);
			dispatchEvent(event);
		}
				
	}
}