package com.worlize.websocket
{
	import flash.events.ErrorEvent;
	
	public class WebSocketErrorEvent extends ErrorEvent
	{
		public static const CONNECTION_FAIL:String = "connectionFail";
		public static const ABNORMAL_CLOSE:String = "abnormalClose";
		
		public function WebSocketErrorEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false, text:String="")
		{
			super(type, bubbles, cancelable, text);
		}
	}
}