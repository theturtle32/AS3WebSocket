package com.worlize.websocket
{
	public final class WebSocketOpcode
	{
		public static const CONTINUATION:int = 0x00;
		public static const CONNECTION_CLOSE:int = 0x01;
		public static const PING:int = 0x02;
		public static const PONG:int = 0x03;
		public static const TEXT_FRAME:int = 0x04;
		public static const BINARY_FRAME:int = 0x05;
		// 0x06 - 0x0F = Reserved
	}
}