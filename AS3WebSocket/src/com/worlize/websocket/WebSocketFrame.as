package com.worlize.websocket
{
	import flash.errors.IOError;
	import flash.events.IOErrorEvent;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.IDataInput;
	import flash.utils.IDataOutput;

	public class WebSocketFrame
	{
		public var fin:Boolean;
		public var rsv1:Boolean;
		public var rsv2:Boolean;
		public var rsv3:Boolean;
		public var opcode:int;
		public var rsv4:Boolean;
		private var _length:int;
		public var binaryPayload:ByteArray;
		public var utf8Payload:String;
		public var closeStatus:int;
		
		private static const NEW_FRAME:int = 0;
		private static const WAITING_FOR_16_BIT_LENGTH:int = 1;
		private static const WAITING_FOR_64_BIT_LENGTH:int = 2;
		private static const WAITING_FOR_PAYLOAD:int = 3;
		private static const COMPLETE:int = 4;
		private var parseState:int = 0; // Initialize as NEW_FRAME
		private var _frameComplete:Boolean = false;
		
		public function get length():int {
			return _length;
		}
		
		// Returns true if frame is complete, false if waiting for more data
		public function addData(input:IDataInput):Boolean {
			if (input.bytesAvailable >= 2) { // minimum frame size
				if (parseState === NEW_FRAME) {
					var firstByte:int = input.readByte();
					var secondByte:int = input.readByte();
					
					fin    = Boolean(firstByte  & 0x80);
					rsv1   = Boolean(firstByte  & 0x40);
					rsv2   = Boolean(firstByte  & 0x20);
					rsv3   = Boolean(firstByte  & 0x10);
					rsv4   = Boolean(secondByte & 0x80);
					opcode = firstByte  & 0x0F;
					_length = secondByte & 0x7F;
					
					if (_length === 126) {
						parseState = WAITING_FOR_16_BIT_LENGTH;
					}
					else if (_length === 127) {
						parseState = WAITING_FOR_64_BIT_LENGTH;
					}
					else {
						parseState = WAITING_FOR_PAYLOAD;
					}
				}
				if (parseState === WAITING_FOR_16_BIT_LENGTH) {
					if (input.bytesAvailable >= 2) {
						_length = input.readUnsignedShort();
						parseState = WAITING_FOR_PAYLOAD;
					}
				}
				else if (parseState === WAITING_FOR_64_BIT_LENGTH) {
					if (input.bytesAvailable >= 8) {
						// We can't deal with 64-bit integers in Flash..
						// So we'll just throw away the most significant
						// 32 bits and hope for the best.
						var firstHalf:uint = input.readUnsignedInt();
						if (firstHalf > 0) {
							throw new IOError("Unsupported 64-bit length frame received.");
						}
						_length = input.readUnsignedInt();
						parseState = WAITING_FOR_PAYLOAD;
					}
				}
				if (parseState === WAITING_FOR_PAYLOAD) {
					switch (opcode) {
						case WebSocketOpcode.TEXT_FRAME:
							if (input.bytesAvailable >= _length) {
								utf8Payload = input.readMultiByte(_length, 'utf-8');
								parseState = COMPLETE;
								_frameComplete = true;
							}
							break;
						
						case WebSocketOpcode.BINARY_FRAME:
							if (input.bytesAvailable >= _length) {
								binaryPayload = new ByteArray();
								binaryPayload.endian = Endian.BIG_ENDIAN;
								input.readBytes(binaryPayload, 0, _length);
								parseState = COMPLETE;
								_frameComplete = true;
							}
							break;
						
						case WebSocketOpcode.CONTINUATION:
							if (WebSocket.debug) {
								WebSocket.logger("Continuation.");
							}
							throwAwayPayload(input);
							break;
						
						case WebSocketOpcode.PING:
							if (WebSocket.debug) {
								WebSocket.logger("Ping!")
							}
							throwAwayPayload(input);
							break;
						
						case WebSocketOpcode.PONG:
							if (WebSocket.debug) {
								WebSocket.logger("Pong!");
							}
							throwAwayPayload(input);
							break;
						
						case WebSocketOpcode.CONNECTION_CLOSE:
							if (WebSocket.debug) {
								WebSocket.logger("Close Requested.");
							}
							throwAwayPayload(input);
							break;
						
						default:
							// unknown frame... eat up any data and move on.
							if (WebSocket.debug) {
								WebSocket.logger("Unknown frame!");
							}
							throwAwayPayload(input);
							break;
					}
				}
			}
			// If more data is needed but not available on the socket yet,
			// return false.  If there is enough data and the frame parsing
			// has been completed, return true.
			return _frameComplete;
		}
		
		private function throwAwayPayload(input:IDataInput):void {
			if (input.bytesAvailable >= _length) {
				for (var i:int = 0; i < _length; i++) {
					input.readByte();
				}
				parseState = COMPLETE;
				_frameComplete = true;
			}
		}
		
		public function get frameComplete():Boolean {
			return _frameComplete;
		}
		
		public function send(output:IDataOutput, useMask:Boolean = true):void {
			var maskKey:uint;
			var frameHeader:ByteArray = new ByteArray();
			frameHeader.endian = Endian.BIG_ENDIAN;
			
			if (useMask) {
				// Generate a mask key
				maskKey = Math.ceil(Math.random()*0xFFFFFFFF);
			}
			else {
				maskKey = 0x00000000;
			}
			var maskBytes:Vector.<uint> = new Vector.<uint>(4);
			maskBytes[0] = (maskKey >> 24) & 0xFF;
			maskBytes[1] = (maskKey >> 16) & 0xFF;
			maskBytes[2] = (maskKey >> 8)  & 0xFF;
			maskBytes[3] =  maskKey        & 0xFF;
			
			var data:ByteArray;
			
			var firstByte:int = 0x00;
			var secondByte:int = 0x00;
			if (fin) {
				firstByte |= 0x80;
			}
			if (rsv1) {
				firstByte |= 0x40;
			}
			if (rsv2) {
				firstByte |= 0x20;
			}
			if (rsv3) {
				firstByte |= 0x10;
			}
			if (rsv4) {
				secondByte |= 0x80;
			}
			
			firstByte |= (opcode & 0x0F);
			
			if (opcode === WebSocketOpcode.BINARY_FRAME) {
				data = binaryPayload;
				data.position = 0;
				_length = data.length;
			}
			else if (opcode === WebSocketOpcode.CONNECTION_CLOSE) {
				data = new ByteArray();
				data.endian = Endian.BIG_ENDIAN;
				data.writeShort(closeStatus);
				if (utf8Payload) {
					data.writeMultiByte(utf8Payload, 'utf-8');
				}
				data.position = 0;
				_length = data.length;
			}
			else if (utf8Payload) { // text, ping, and pong frames
				// According to the spec, ping and pong frames
				// can optionally carry a payload.
				data = new ByteArray();
				data.endian = Endian.BIG_ENDIAN;
				data.writeMultiByte(utf8Payload, 'utf-8');
				data.position = 0;
				_length = data.length;
			}
			else {
				_length = 0;
			}
			
			if (_length <= 125) {
				// encode the length directly into the two-byte frame header
				secondByte |= (_length & 0x7F);
			}
			else if (_length > 125 && _length <= 0xFFFF) {
				// Use 16-bit length
				secondByte |= 126;
			}
			else if (_length > 0xFFFF) {
				// Use 64-bit length
				secondByte |= 127;
			}
			
			// build the frame header
			frameHeader.writeByte(firstByte);
			frameHeader.writeByte(secondByte);
			
			if (_length > 125 && _length <= 0xFFFF) {
				// write 16-bit length
				frameHeader.writeShort(_length);
			}
			else if (_length > 0xFFFF) {
				// write 64-bit length
				frameHeader.writeUnsignedInt(0x00000000);
				frameHeader.writeUnsignedInt(_length);
			}
			
			frameHeader.position = 0;
			
			// write the mask key to the output
			output.writeUnsignedInt(maskKey);
			
			// Mask and send the header and payload
			var i:uint,
				j:int = 0,
				headerLength:int = frameHeader.length;
			
			for (i = 0; i < headerLength; i ++) {
				output.writeByte(frameHeader.readByte() ^ maskBytes[j]);
				j = (j + 1) & 3;
			}
			for (i = 0; i < _length; i ++) {
				output.writeByte(data.readByte() ^ maskBytes[j]);
				j = (j + 1) & 3;
			}
		}
	}
}