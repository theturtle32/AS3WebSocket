package com.worlize.websocket
{
	import flash.utils.ByteArray;
	
	public class WebSocketMessage
	{
		public static const TYPE_BINARY:String = "binary";
		public static const TYPE_UTF8:String = "utf8";
		
		public var type:String;
		public var utf8Data:String;
		public var binaryData:ByteArray;
	}
}