package com.worlize.websocket
{
	public class WebSocketConfig
	{
		// 1 MiB max frame size
		public var maxReceivedFrameSize:uint = 0x100000;
		
		// 8 MiB max message size, only applicable if
		// assembleFragments is true
		public var maxMessageSize:uint = 0x800000; // 8 MiB

		// Outgoing messages larger than fragmentationThreshold will be
		// split into multiple fragments.
		public var fragmentOutgoingMessages:Boolean = true;

		// Outgoing frames are fragmented if they exceed this threshold.
		// Default is 16KiB
		public var fragmentationThreshold:uint = 0x4000;
		
		// If true, fragmented messages will be automatically assembled
		// and the full message will be emitted via a 'message' event.
		// If false, each frame will be emitted via a 'frame' event and
		// the application will be responsible for aggregating multiple
		// fragmented frames.  Single-frame messages will emit a 'message'
		// event in addition to the 'frame' event.
		// Most users will want to leave this set to 'true'
		public var assembleFragments:Boolean = true;
		
		// The number of milliseconds to wait after sending a close frame
		// for an acknowledgement to come back before giving up and just
		// closing the socket.
		public var closeTimeout:uint = 5000;
	}
}