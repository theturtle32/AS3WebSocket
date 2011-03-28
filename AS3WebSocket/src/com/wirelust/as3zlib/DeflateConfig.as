package com.wirelust.as3zlib {
	public class DeflateConfig {
		public var good_length:int; // reduce lazy search above this match length
		public var max_lazy:int;    // do not perform lazy search above this match length
		public var nice_length:int; // quit search above this match length
		public var max_chain:int;
		public var func:int;

		public function DeflateConfig (good_length:int, max_lazy:int, nice_length:int, max_chain:int, func:int) {
			this.good_length=good_length;
			this.max_lazy=max_lazy;
			this.nice_length=nice_length;
			this.max_chain=max_chain;
			this.func=func;
		}
	}
}