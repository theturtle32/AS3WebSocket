/* -*-mode:java; c-basic-offset:2; -*- */
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
	
	public final class Inflate {

		static private const MAX_WBITS: int = 15;
		// 32K LZ77 window
		// preset dictionary flag in zlib header
		static private const PRESET_DICT: int = 0x20;

		static public const Z_NO_FLUSH: int = 0;
		static public const Z_PARTIAL_FLUSH: int = 1;
		static public const Z_SYNC_FLUSH: int = 2;
		static public const Z_FULL_FLUSH: int = 3;
		static public const Z_FINISH: int = 4;

		static private const Z_DEFLATED: int = 8;

		static private const Z_OK: int = 0;
		static private const Z_STREAM_END: int = 1;
		static private const Z_NEED_DICT: int = 2;
		static private const Z_ERRNO: int = -1;
		static private const Z_STREAM_ERROR: int = -2;
		static private const Z_DATA_ERROR: int = -3;
		static private const Z_MEM_ERROR: int = -4;
		static private const Z_BUF_ERROR: int = -5;
		static private const Z_VERSION_ERROR: int = -6;

		static public const METHOD: int = 0;
		// waiting for method byte
		static public const FLAG: int = 1;
		// waiting for flag byte
		static public const DICT4: int = 2;
		// four dictionary check bytes to go
		static public const DICT3: int = 3;
		// three dictionary check bytes to go
		static public const DICT2: int = 4;
		// two dictionary check bytes to go
		static public const DICT1: int = 5;
		// one dictionary check byte to go
		static public const DICT0: int = 6;
		// waiting for inflateSetDictionary
		static public const BLOCKS: int = 7;
		// decompressing blocks
		static public const CHECK4: int = 8;
		// four check bytes to go
		static public const CHECK3: int = 9;
		// three check bytes to go
		static public const CHECK2: int = 10;
		// two check bytes to go
		static public const CHECK1: int = 11;
		// one check byte to go
		static public const DONE: int = 12;
		// finished check, done
		static public const BAD: int = 13;
		// got an error--stay here
		public var mode: int;
		// current inflate mode
		// mode dependent information
		public var method: int;
		// if FLAGS, method byte
		// if CHECK, check values to compare
		public var was: Array = new Array();
		// computed check value
		public var need: Number;
		// stream check value
		// if BAD, inflateSync's marker bytes count
		public var marker: int;

		// mode independent information
		public var nowrap: int;
		// flag for no wrapper
		public var wbits: int;
		// log2(window size)  (8..15, defaults to 15)
		public var blocks: InfBlocks;
		// current inflate_blocks state
		public function inflateReset(z: ZStream) : int {
			if (z == null || z.istate == null) return Z_STREAM_ERROR;

			z.total_in = z.total_out = 0;
			z.msg = null;
			z.istate.mode = z.istate.nowrap != 0 ? BLOCKS: METHOD;
			z.istate.blocks.reset(z, null);
			return Z_OK;
		}

		public function inflateEnd(z: ZStream) : int {
			if (blocks != null)
			blocks.free(z);
			blocks = null;
			//	  ZFREE(z, z->state);
			return Z_OK;
		}

		public function inflateInit(z: ZStream, w: int) : int {
			z.msg = null;
			blocks = null;

			// handle undocumented nowrap option (no zlib header or check)
			nowrap = 0;
			if (w < 0) {
				w = -w;
				nowrap = 1;
			}

			// set window size
			if (w < 8 || w > 15) {
				inflateEnd(z);
				return Z_STREAM_ERROR;
			}
			wbits = w;

			z.istate.blocks = new InfBlocks(z,
			z.istate.nowrap != 0 ? null: this,
			1 << w);

			// reset state
			inflateReset(z);
			return Z_OK;
		}

		public function inflate(z: ZStream, f: int) : int {
			var r: int;
			var b: int;

			if (z == null || z.istate == null || z.next_in == null)
			return Z_STREAM_ERROR;
			f = f == Z_FINISH ? Z_BUF_ERROR: Z_OK;
			r = Z_BUF_ERROR;
			while (true) {
				//System.println("mode: "+z.istate.mode);
				switch (z.istate.mode) {
				case METHOD:

					if (z.avail_in == 0) return r;
					r = f;

					z.avail_in--;
					z.total_in++;
					if (((z.istate.method = z.next_in[z.next_in_index++])&0xf) != Z_DEFLATED) {
						z.istate.mode = BAD;
						z.msg = "unknown compression method";
						z.istate.marker = 5;
						// can't try inflateSync
						break;
					}
					if ((z.istate.method >> 4) + 8 > z.istate.wbits) {
						z.istate.mode = BAD;
						z.msg = "invalid window size";
						z.istate.marker = 5;
						// can't try inflateSync
						break;
					}
					z.istate.mode = FLAG;
				case FLAG:

					if (z.avail_in == 0) return r;
					r = f;

					z.avail_in--;
					z.total_in++;
					b = (z.next_in[z.next_in_index++])&0xff;

					var checksum:int = (((z.istate.method << 8) + b) % 31); 
					if (checksum != 0) {
						z.istate.mode = BAD;
						z.msg = "incorrect header check";
						z.istate.marker = 5;
						// can't try inflateSync
						break;
					}

					if ((b & PRESET_DICT) == 0) {
						z.istate.mode = BLOCKS;
						break;
					}
					z.istate.mode = DICT4;
				case DICT4:

					if (z.avail_in == 0) return r;
					r = f;

					z.avail_in--;
					z.total_in++;
					// java = z.istate.need=((z.next_in[z.next_in_index++]&0xff)<<24)&0xff000000L;
					z.istate.need = ((z.next_in[z.next_in_index++]&0xff)<<24) & 0xff000000;
					z.istate.mode = DICT3;
				case DICT3:

					if (z.avail_in == 0) return r;
					r = f;

					z.avail_in--;
					z.total_in++;
					// java = z.istate.need+=((z.next_in[z.next_in_index++]&0xff)<<16)&0xff0000L;
					z.istate.need += ((z.next_in[z.next_in_index++] & 0xff)<<16) & 0xff0000;
					z.istate.mode = DICT2;
				case DICT2:

					if (z.avail_in == 0) return r;
					r = f;

					z.avail_in--;
					z.total_in++;
					// java = z.istate.need+=((z.next_in[z.next_in_index++]&0xff)<<8)&0xff00L;
					z.istate.need += ((z.next_in[z.next_in_index++] & 0xff)<<8) & 0xff00;
					z.istate.mode = DICT1;
				case DICT1:

					if (z.avail_in == 0) return r;
					r = f;

					z.avail_in--;
					z.total_in++;
					// java = z.istate.need += (z.next_in[z.next_in_index++]&0xffL);
					z.istate.need += (z.next_in[z.next_in_index++] & 0xff);
					z.adler = z.istate.need;
					z.istate.mode = DICT0;
					return Z_NEED_DICT;
				case DICT0:
					z.istate.mode = BAD;
					z.msg = "need dictionary";
					z.istate.marker = 0;
					// can try inflateSync
					return Z_STREAM_ERROR;
				case BLOCKS:

					r = z.istate.blocks.proc(z, r);
					if (r == Z_DATA_ERROR) {
						z.istate.mode = BAD;
						z.istate.marker = 0;
						// can try inflateSync
						break;
					}
					if (r == Z_OK) {
						r = f;
					}
					if (r != Z_STREAM_END) {
						return r;
					}
					r = f;
					z.istate.blocks.reset(z, z.istate.was);
					if (z.istate.nowrap != 0) {
						z.istate.mode = DONE;
						break;
					}
					z.istate.mode = CHECK4;
				case CHECK4:

					if (z.avail_in == 0) return r;
					r = f;

					z.avail_in--;
					z.total_in++;
					// java = z.istate.need=((z.next_in[z.next_in_index++]&0xff)<<24)&0xff000000L;;
					z.istate.need = ((z.next_in[z.next_in_index++]&0xff) << 24) & 0xff000000;
					z.istate.mode = CHECK3;
				case CHECK3:

					if (z.avail_in == 0) return r;
					r = f;

					z.avail_in--;
					z.total_in++;
					// java = z.istate.need+=((z.next_in[z.next_in_index++]&0xff)<<16)&0xff0000L;
					z.istate.need += ((z.next_in[z.next_in_index++]&0xff) << 16)&0xff0000;
					z.istate.mode = CHECK2;
				case CHECK2:

					if (z.avail_in == 0) return r;
					r = f;

					z.avail_in--;
					z.total_in++;
					// java = z.istate.need+=((z.next_in[z.next_in_index++]&0xff)<<8)&0xff00L;;
					z.istate.need += ((z.next_in[z.next_in_index++]&0xff) << 8) & 0xff00;
					z.istate.mode = CHECK1;
				case CHECK1:

					if (z.avail_in == 0) return r;
					r = f;

					z.avail_in--;
					z.total_in++;
					// java = z.istate.need+=(z.next_in[z.next_in_index++]&0xffL);
					z.istate.need += (z.next_in[z.next_in_index++] & 0xff);

					if ((int((z.istate.was[0]))) != (int((z.istate.need)))) {
						z.istate.mode = BAD;
						z.msg = "incorrect data check";
						z.istate.marker = 5;
						// can't try inflateSync
						break;
					}

					z.istate.mode = DONE;
				case DONE:
					return Z_STREAM_END;
				case BAD:
					return Z_DATA_ERROR;
				default:
					return Z_STREAM_ERROR;
				}
			}
			return Z_STREAM_ERROR;
		}

		public function inflateSetDictionary(z:ZStream, dictionary:ByteArray, dictLength:int):int {
			var index: int = 0;
			var length: int = dictLength;
			if (z == null || z.istate == null || z.istate.mode != DICT0)
			return Z_STREAM_ERROR;

			// java = if (z._adler.adler32(1L, dictionary, 0, dictLength) != z.adler) {
			if (z._adler.adler32(1, dictionary, 0, dictLength) != z.adler) {
				return Z_DATA_ERROR;
			}

			z.adler = z._adler.adler32(0, null, 0, 0);

			if (length >= (1 << z.istate.wbits)) {
				length = (1 << z.istate.wbits) - 1;
				index = dictLength - length;
			}
			z.istate.blocks.set_dictionary(dictionary, index, length);
			z.istate.mode = BLOCKS;
			return Z_OK;
		}

		static private var mark: Array = new Array(
			0,
			0,
			0xff,
			0xff
		);

		public function inflateSync(z: ZStream) : int {
			var n: int;
			// number of bytes to look at
			var p: int;
			// pointer to bytes
			var m: int;
			// number of marker bytes found in a row
			var r: Number, w:Number;
			// temporaries to save total_in and total_out
			// set up
			if (z == null || z.istate == null)
			return Z_STREAM_ERROR;
			if (z.istate.mode != BAD) {
				z.istate.mode = BAD;
				z.istate.marker = 0;
			}
			if ((n = z.avail_in) == 0)
			return Z_BUF_ERROR;
			p = z.next_in_index;
			m = z.istate.marker;

			// search
			while (n != 0 && m < 4) {
				if (z.next_in[p] == mark[m]) {
					m++;
				}
				else if (z.next_in[p] != 0) {
					m = 0;
				}
				else {
					m = 4 - m;
				}
				p++;
				n--;
			}

			// restore
			z.total_in += p - z.next_in_index;
			z.next_in_index = p;
			z.avail_in = n;
			z.istate.marker = m;

			// return no joy or set up to restart on a new block
			if (m != 4) {
				return Z_DATA_ERROR;
			}
			r = z.total_in;
			w = z.total_out;
			inflateReset(z);
			z.total_in = r;
			z.total_out = w;
			z.istate.mode = BLOCKS;
			return Z_OK;
		}

		// Returns true if inflate is currently at the end of a block generated
		// by Z_SYNC_FLUSH or Z_FULL_FLUSH. This function is used by one PPP
		// implementation to provide an additional safety check. PPP uses Z_SYNC_FLUSH
		// but removes the length bytes of the resulting empty stored block. When
		// decompressing, PPP checks that at the end of input packet, inflate is
		// waiting for these length bytes.
		public function inflateSyncPoint(z: ZStream) : int {
			if (z == null || z.istate == null || z.istate.blocks == null)
			return Z_STREAM_ERROR;
			return z.istate.blocks.sync_point();
		}
	}
}