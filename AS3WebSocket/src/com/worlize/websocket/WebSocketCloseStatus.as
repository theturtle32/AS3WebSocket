package com.worlize.websocket
{
	public final class WebSocketCloseStatus
	{
		// http://tools.ietf.org/html/draft-ietf-hybi-thewebsocketprotocol-06#section-7.4
		public static const NORMAL:int = 1000;
		public static const GOING_AWAY:int = 1001;
		public static const PROTOCOL_ERROR:int = 1002;
		public static const UNPROCESSABLE_INPUT:int = 1003;
		public static const MESSAGE_TOO_LARGE:int = 1004;
	}
}