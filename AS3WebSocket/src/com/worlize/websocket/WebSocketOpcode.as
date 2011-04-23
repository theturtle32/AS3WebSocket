package com.worlize.websocket
{
	public final class WebSocketOpcode
	{
		// non-control opcodes		
		public static const CONTINUATION:int = 0x00;
		public static const TEXT_FRAME:int = 0x01;
		public static const BINARY_FRAME:int = 0x02;
		// 0x03 - 0x07 = Reserved for further control frames
		
		// Control opcodes 
		public static const CONNECTION_CLOSE:int = 0x08;
		public static const PING:int = 0x09;
		public static const PONG:int = 0x0A;
		// 0x0B - 0x0F = Reserved for further control frames
	}
}