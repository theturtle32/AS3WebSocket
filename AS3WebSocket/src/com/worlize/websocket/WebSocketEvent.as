package com.worlize.websocket
{
	import flash.events.Event;
	import flash.utils.ByteArray;
	
	public class WebSocketEvent extends Event
	{
		public static const OPEN:String = "open";
		public static const CLOSED:String = "closed";
		public static const MESSAGE:String = "message";
		public static const FRAME:String = "frame";
		public static const PING:String = "ping";
		public static const PONG:String = "pong";
		
		public var message:WebSocketMessage;
		public var frame:WebSocketFrame;
		
		public function WebSocketEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
	}
}