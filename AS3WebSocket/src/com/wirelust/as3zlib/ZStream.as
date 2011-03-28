/* -*-mode:java; c-basic-offset:2; indent-tabs-mode:nil -*- */
/*
Copyright (c) 2000,2001,2002,2003 ymnk, JCraft,Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

  1. Redistributions of source code must retain the above copyright notice,
	 this list of conditions and the following disclaimer.

  2. Redistributions in binary form must reproduce the above copyright 
	 notice, this list of conditions and the following disclaimer in 
	 the documentation and/or other materials provided with the distribution.

  3. The names of the authors may not be used to endorse or promote products
	 derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL JCRAFT,
INC. OR ANY CONTRIBUTORS TO THIS SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
/*
 * This program is based on zlib-1.1.3, so all credit should go authors
 * Jean-loup Gailly(jloup@gzip.org) and Mark Adler(madler@alumni.caltech.edu)
 * and contributors of zlib.
 */

package com.wirelust.as3zlib {
	import flash.utils.ByteArray;
	
	final public class ZStream {

		static private
		var MAX_WBITS: int = 15;
		// 32K LZ77 window
		static private
		var DEF_WBITS: int = MAX_WBITS;

		static private var Z_NO_FLUSH: int = 0;
		static private var Z_PARTIAL_FLUSH: int = 1;
		static private var Z_SYNC_FLUSH: int = 2;
		static private var Z_FULL_FLUSH: int = 3;
		static private var Z_FINISH: int = 4;

		static private var MAX_MEM_LEVEL: int = 9;

		static private var Z_OK: int = 0;
		static private var Z_STREAM_END: int = 1;
		static private var Z_NEED_DICT: int = 2;
		static private var Z_ERRNO: int = -1;
		static private var Z_STREAM_ERROR: int = -2;
		static private var Z_DATA_ERROR: int = -3;
		static private var Z_MEM_ERROR: int = -4;
		static private var Z_BUF_ERROR: int = -5;
		static private var Z_VERSION_ERROR: int = -6;

		public var next_in: ByteArray;
		// next input byte
		public var next_in_index: int;
		public var avail_in: int;
		// number of bytes available at next_in
		public var total_in: Number;
		// total nb of input bytes read so far
		public var next_out: ByteArray;
		// next output byte should be put there
		public var next_out_index: int;
		public var avail_out: int;
		// remaining free space at next_out
		public var total_out: Number;
		// total nb of bytes output so far
		public var msg: String;

		public var dstate: Deflate;
		public var istate: Inflate;

		public var data_type: int;
		// best guess about the data type: ascii or binary
		public var adler: Number;
		public var _adler: Adler32 = new Adler32();

		public function inflateInit() : int {
			return inflateInitWithWbits(DEF_WBITS);
		}
		public function inflateInitWithNoWrap(nowrap: Boolean) : int {
			return inflateInitWithWbitsNoWrap(DEF_WBITS, nowrap);
		}
		public function inflateInitWithWbits(w: int) : int {
			return this.inflateInitWithWbitsNoWrap(w, false);
		}

		public function inflateInitWithWbitsNoWrap(w: int, nowrap: Boolean) : int {
			istate = new Inflate();
			return istate.inflateInit(this, nowrap ? -w: w);
		}

		public function inflate(f: int) : int {
			if (istate == null) return Z_STREAM_ERROR;
			return istate.inflate(this, f);
		}
		public function inflateEnd() : int {
			if (istate == null) return Z_STREAM_ERROR;
			var ret: int = istate.inflateEnd(this);
			istate = null;
			return ret;
		}
		public function inflateSync() : int {
			if (istate == null)
			return Z_STREAM_ERROR;
			return istate.inflateSync(this);
		}
		public function inflateSetDictionary(dictionary: ByteArray, dictLength: int) : int {
			if (istate == null)
			return Z_STREAM_ERROR;
			return istate.inflateSetDictionary(this, dictionary, dictLength);
		}

		public function deflateInit(level: int) : int {
			return this.deflateInitWithIntInt(level, MAX_WBITS);
		}
		public function deflateInitWithBoolean(level: int, nowrap: Boolean) : int {
			return this.deflateInitWithIntIntBoolean(level, MAX_WBITS, nowrap);
		}
		public function deflateInitWithIntInt(level: int, bits: int) : int {
			return deflateInitWithIntIntBoolean(level, bits, false);
		}
		public function deflateInitWithIntIntBoolean(level: int, bits: int, nowrap: Boolean) : int {
			dstate = new Deflate();
			return dstate.deflateInitWithBits(this, level, nowrap ? -bits: bits);
		}
		public function deflate(flush: int) : int {
			if (dstate == null) {
				return Z_STREAM_ERROR;
			}
			return dstate.deflate(this, flush);
		}
		public function deflateEnd() : int {
			if (dstate == null) return Z_STREAM_ERROR;
			var ret: int = dstate.deflateEnd();
			dstate = null;
			return ret;
		}
		public function deflateParams(level: int, strategy: int) : int {
			if (dstate == null) return Z_STREAM_ERROR;
			return dstate.deflateParams(this, level, strategy);
		}
		public function deflateSetDictionary(dictionary:ByteArray, dictLength: int) : int {
			if (dstate == null)
			return Z_STREAM_ERROR;
			return dstate.deflateSetDictionary(this, dictionary, dictLength);
		}

		// Flush as much pending output as possible. All deflate() output goes
		// through this function so some applications may wish to modify it
		// to avoid allocating a large strm->next_out buffer and copying into it.
		// (See also read_buf()).
		public function flush_pending() : void {
			var len: int = dstate.pending;

			if (len > avail_out) len = avail_out;
			if (len == 0) return;

			if (dstate.pending_buf.length <= dstate.pending_out ||
				next_out.length <= next_out_index ||
				dstate.pending_buf.length < (dstate.pending_out + len) ||
				next_out.length < (next_out_index + len)) {
				
				// this is a check that is relevant in java but not in actionscript because we are using
				// dynamically sized arrays.
				// todo: inspect this check to see if we can do something similar for debugging. 
				//System.println(dstate.pending_buf.length + ", " + dstate.pending_out +
				//", " + next_out.length + ", " + next_out_index + ", " + len);
				//System.println("avail_out=" + avail_out);
			}

			System.byteArrayCopy(dstate.pending_buf, dstate.pending_out, next_out, next_out_index, len);

			next_out_index += len;
			dstate.pending_out += len;
			total_out += len;
			avail_out -= len;
			dstate.pending -= len;
			if (dstate.pending == 0) {
				dstate.pending_out = 0;
				dstate.pending_buf = new ByteArray();
			}
		}

		// Read a new buffer from the current input stream, update the adler32
		// and total number of bytes read.	All deflate() input goes through
		// this function so some applications may wish to modify it to avoid
		// allocating a large strm->next_in buffer and copying from it.
		// (See also flush_pending()).
		public function read_buf(buf: ByteArray, start: int, size: int) : int {
			var len: int = avail_in;

			if (len > size) len = size;
			if (len == 0) return 0;

			avail_in -= len;

			if (dstate.noheader == 0) {
				adler = _adler.adler32(adler, next_in, next_in_index, len);
			}
			System.byteArrayCopy(next_in, next_in_index, buf, start, len);
			next_in_index += len;
			total_in += len;
			return len;
		}

		public function free() : void {
			next_in = null;
			next_out = null;
			msg = null;
			_adler = null;
		}
	}
}