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
		public var mask:Boolean;
		private var _length:int;
		public var binaryPayload:ByteArray;
		public var closeStatus:int;
		
		public var protocolError:Boolean = false;
		public var frameTooLarge:Boolean = false;
		public var dropReason:String;
		
		private static const NEW_FRAME:int = 0;
		private static const WAITING_FOR_16_BIT_LENGTH:int = 1;
		private static const WAITING_FOR_64_BIT_LENGTH:int = 2;
		private static const WAITING_FOR_PAYLOAD:int = 3;
		private static const COMPLETE:int = 4;
		private var parseState:int = 0; // Initialize as NEW_FRAME
		
		public function get length():int {
			return _length;
		}
		
		// Returns true if frame is complete, false if waiting for more data
		public function addData(input:IDataInput, fragmentationType:int, config:WebSocketConfig):Boolean {
			if (input.bytesAvailable >= 2) { // minimum frame size
				if (parseState === NEW_FRAME) {
					var firstByte:int = input.readByte();
					var secondByte:int = input.readByte();
					
					fin    = Boolean(firstByte  & 0x80);
					rsv1   = Boolean(firstByte  & 0x40);
					rsv2   = Boolean(firstByte  & 0x20);
					rsv3   = Boolean(firstByte  & 0x10);
					mask   = Boolean(secondByte & 0x80);
					opcode = firstByte  & 0x0F;
					_length = secondByte & 0x7F;
					
					if (mask) {
						protocolError = true;
						dropReason = "Received an illegal masked frame from the server.";
						return true;
					}
					
					if (opcode > 0x07) {
						if (_length > 125) {
							protocolError = true;
							dropReason = "Illegal control frame larger than 125 bytes.";
							return true;
						}
						if (!fin) {
							protocolError = true;
							dropReason = "Received illegal fragmented control message.";
							return true;
						}
					}
					
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
							frameTooLarge = true;
							dropReason = "Unsupported 64-bit length frame received.";
							return true;
						}
						_length = input.readUnsignedInt();
						parseState = WAITING_FOR_PAYLOAD;
					}
				}
				if (parseState === WAITING_FOR_PAYLOAD) {
					if (_length > config.maxReceivedFrameSize) {
						frameTooLarge = true;
						dropReason = "Received frame size of " + _length + 
									 "exceeds maximum accepted frame size of " + config.maxReceivedFrameSize;
						return true;
					}
					else {
						if (_length === 0) {
							binaryPayload = new ByteArray();
							parseState = COMPLETE;
							return true;
						}
						if (input.bytesAvailable >= _length) {
							binaryPayload = new ByteArray();
							binaryPayload.endian = Endian.BIG_ENDIAN;
							input.readBytes(binaryPayload, 0, _length);
							binaryPayload.position = 0;
							parseState = COMPLETE;
							return true;
						}
					}
				}
			}
			// If more data is needed but not available on the socket yet,
			// return false.  If there is enough data and the frame parsing
			// has been completed, return true.
			return false;
		}
		
		private function throwAwayPayload(input:IDataInput):void {
			if (input.bytesAvailable >= _length) {
				for (var i:int = 0; i < _length; i++) {
					input.readByte();
				}
				parseState = COMPLETE;
			}
		}
		
		public function send(output:IDataOutput):void {
			var frameHeader:ByteArray = new ByteArray();
			frameHeader.endian = Endian.BIG_ENDIAN;
			
			if (this.mask) {
				// Generate a mask key
				var maskKey:uint = Math.ceil(Math.random()*0xFFFFFFFF);
				var maskBytes:Vector.<uint> = new Vector.<uint>(4);
				maskBytes[0] = (maskKey >> 24) & 0xFF;
				maskBytes[1] = (maskKey >> 16) & 0xFF;
				maskBytes[2] = (maskKey >> 8)  & 0xFF;
				maskBytes[3] =  maskKey        & 0xFF;
			}
			
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
			if (mask) {
				secondByte |= 0x80;
			}
			
			firstByte |= (opcode & 0x0F);
			
			if (opcode === WebSocketOpcode.CONNECTION_CLOSE) {
				data = new ByteArray();
				data.endian = Endian.BIG_ENDIAN;
				data.writeShort(closeStatus);
				if (binaryPayload) {
					binaryPayload.position = 0;
					data.writeBytes(binaryPayload);
				}
				data.position = 0;
				_length = data.length;
			}
			else if (binaryPayload) {
				data = binaryPayload;
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
			
			// output the frame header
			output.writeByte(firstByte);
			output.writeByte(secondByte);
			
			if (_length > 125 && _length <= 0xFFFF) {
				// write 16-bit length
				output.writeShort(_length);
			}
			else if (_length > 0xFFFF) {
				// write 64-bit length
				output.writeUnsignedInt(0x00000000);
				output.writeUnsignedInt(_length);
			}
			
			if (this.mask) {
				// write the mask key to the output	
				output.writeUnsignedInt(maskKey);
				// Mask and send the payload
				var i:uint,
				j:int = 0;
				for (i = 0; i < _length; i ++) {
					output.writeByte(data.readByte() ^ maskBytes[j]);
					j = (j + 1) & 3;
				}
			}
			else {
				// Send the payload unmasked
				output.writeBytes(data, 0, data.length);
			}
		}
	}
}