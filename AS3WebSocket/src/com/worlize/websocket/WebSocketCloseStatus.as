package com.worlize.websocket
{
	public final class WebSocketCloseStatus
	{
		// http://tools.ietf.org/html/rfc6455#section-7.4
		public static const NORMAL:int = 1000;
		public static const GOING_AWAY:int = 1001;
		public static const PROTOCOL_ERROR:int = 1002;
		public static const UNPROCESSABLE_INPUT:int = 1003;
		public static const UNDEFINED:int = 1004;
		public static const NO_CODE:int = 1005;
		public static const NO_CLOSE:int = 1006;
		public static const BAD_PAYLOAD:int = 1007;
		public static const POLICY_VIOLATION:int = 1008;
		public static const MESSAGE_TOO_LARGE:int = 1009;
		public static const REQUIRED_EXTENSION:int = 1010;
		public static const SERVER_ERROR:int = 1011;
		public static const FAILED_TLS_HANDSHAKE:int = 1015;
	}
}