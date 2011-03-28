package com.worlize.websocket
{
	public class WebSocketError extends Error
	{
		public function WebSocketError(message:*="", id:*=0)
		{
			super(message, id);
		}
	}
}