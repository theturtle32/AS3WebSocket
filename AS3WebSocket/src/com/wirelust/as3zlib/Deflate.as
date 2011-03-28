/* mode:java; c-basic-offset:2;	 */
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
	import com.wirelust.util.Cast;

	public class Deflate {

		static private
		var MAX_MEM_LEVEL: int = 9;

		static private
		var Z_DEFAULT_COMPRESSION: int = -1;

		static private var MAX_WBITS: int = 15;
		// 32K LZ77 window
		static private var DEF_MEM_LEVEL: int = 8;


		static private var STORED: int = 0;
		static private var FAST: int = 1;
		static private var SLOW: int = 2;
		static private var config_table: Array = new Array (
			new DeflateConfig(0, 0, 0, 0, STORED),
			new DeflateConfig(4, 4, 8, 4, FAST),
			new DeflateConfig(4, 5, 16, 8, FAST),
			new DeflateConfig(4, 6, 32, 32, FAST),

			new DeflateConfig(4, 4, 16, 16, SLOW),
			new DeflateConfig(8, 16, 32, 32, SLOW),
			new DeflateConfig(8, 16, 128, 128, SLOW),
			new DeflateConfig(8, 32, 128, 256, SLOW),
			new DeflateConfig(32, 128, 258, 1024, SLOW),
			new DeflateConfig(32, 258, 258, 4096, SLOW)
		);


		private var z_errmsg: Array = new Array(
			"need dictionary",
			// Z_NEED_DICT		 2
			"stream end",
			// Z_STREAM_END		 1
			"",
			// Z_OK				 0
			"file error",
			// Z_ERRNO		   (-1)
			"stream error",
			// Z_STREAM_ERROR  (-2)
			"data error",
			// Z_DATA_ERROR	   (-3)
			"insufficient memory",
			// Z_MEM_ERROR	   (-4)
			"buffer error",
			// Z_BUF_ERROR	   (-5)
			"incompatible version",
			// Z_VERSION_ERROR (-6)
			""
		);


		// block not completed, need more input or more output
		static private var NeedMore: int = 0;

		// block flush performed
		static private var BlockDone: int = 1;

		// finish started, need only more output at next deflate
		static private const FinishStarted: int = 2;

		// finish done, accept no more input or output
		static private const FinishDone: int = 3;

		// preset dictionary flag in zlib header
		static private const PRESET_DICT: int = 0x20;

		static private const Z_FILTERED: int = 1;
		static private const Z_HUFFMAN_ONLY: int = 2;
		static private const Z_DEFAULT_STRATEGY: int = 0;

		static private const Z_NO_FLUSH: int = 0;
		static private const Z_PARTIAL_FLUSH: int = 1;
		static private const Z_SYNC_FLUSH: int = 2;
		static private const Z_FULL_FLUSH: int = 3;
		static private const Z_FINISH: int = 4;

		static private const Z_OK: int = 0;
		static private const Z_STREAM_END: int = 1;
		static private const Z_NEED_DICT: int = 2;
		static private const Z_ERRNO: int = -1;
		static private const Z_STREAM_ERROR: int = -2;
		static private const Z_DATA_ERROR: int = -3;
		static private const Z_MEM_ERROR: int = -4;
		static private const Z_BUF_ERROR: int = -5;
		static private const Z_VERSION_ERROR: int = -6;

		static private const INIT_STATE: int = 42;
		static private const BUSY_STATE: int = 113;
		static private const FINISH_STATE: int = 666;

		// The deflate compression method
		static private var Z_DEFLATED: int = 8;
               
		static private const STORED_BLOCK: int = 0;
		static private const STATIC_TREES: int = 1;
		static private const DYN_TREES: int = 2;
               
		// The three kinds of block type
		static private const Z_BINARY: int = 0;
		static private const Z_ASCII: int = 1;
		static private const Z_UNKNOWN: int = 2;
               
		static private const Buf_size: int = 8 * 2;
               
		// repeat previous bit length 3-6 times (2 bits of repeat count)
		static private const REP_3_6: int = 16;

		// repeat a zero length 3-10 times	(3 bits of repeat count)
		static private const REPZ_3_10: int = 17;

		// repeat a zero length 11-138 times  (7 bits of repeat count)
		static private const REPZ_11_138: int = 18;

		static private const MIN_MATCH: int = 3;
		static private const MAX_MATCH: int = 258;
		static private const MIN_LOOKAHEAD: int = (MAX_MATCH + MIN_MATCH + 1);

		static private const MAX_BITS: int = 15;
		static private const D_CODES: int = 30;
		static private const BL_CODES: int = 19;
		static private const LENGTH_CODES: int = 29;
		static private const LITERALS: int = 256;
		static private const L_CODES: int = (LITERALS + 1 + LENGTH_CODES);
		static private const HEAP_SIZE: int = (2 * L_CODES + 1);

		static private const END_BLOCK: int = 256;

		public var strm: ZStream; // pointer back to this zlib stream
		public var status: int; // as the name implies
		public var pending_buf: ByteArray; // output still pending
		public var pending_buf_size: int; // size of pending_buf
		public var pending_out: int; // next pending byte to output to the stream
		public var pending: int; // nb of bytes in the pending buffer
		public var noheader: int; // suppress zlib header and adler32
		public var data_type: uint; // UNKNOWN, BINARY or ASCII
		public var method: uint; // STORED (for zip only) or DEFLATED
		public var last_flush: int; // value of flush param for previous deflate call
		public var w_size: int; // LZ77 window size (32K by default)
		public var w_bits: int; // log2(w_size)	 (8..16)
		public var w_mask: int; // w_size - 1
		
		public var window: ByteArray;
		// Sliding window. Input bytes are read into the second half of the window,
		// and move to the first half later to keep a dictionary of at least wSize
		// bytes. With this organization, matches are limited to a distance of
		// wSize-MAX_MATCH bytes, but this ensures that IO is always
		// performed with a length multiple of the block size. Also, it limits
		// the window size to 64K, which is quite useful on MSDOS.
		// To do: use the user input buffer as sliding window.
		public var window_size: int;
		// Actual size of window: 2*wSize, except when the user input buffer
		// is directly used as sliding window.
		public var prev: Array;
		// Link to older string with same hash index. To limit the size of this
		// array to 64K, this link is maintained only for the last 32K strings.
		// An index in this array is thus a window index modulo 32K.
		public var head: Array;
		// Heads of the hash chains or NIL.
		public var ins_h: int;
		// hash index of string to be inserted
		public var hash_size: int;
		// number of elements in hash table
		public var hash_bits: int;
		// log2(hash_size)
		public var hash_mask: int;
		// hash_size-1
		// Number of bits by which ins_h must be shifted at each input
		// step. It must be such that after MIN_MATCH steps, the oldest
		// byte no longer takes part in the hash key, that is:
		// hash_shift * MIN_MATCH >= hash_bits
		public var hash_shift: int;

		// Window position at the beginning of the current output block. Gets
		// negative when the window is moved backwards.
		public var block_start: int;

		public var match_length: int;
		// length of best match
		public var prev_match: int;
		// previous match
		public var match_available: int;
		// set if previous match exists
		public var strstart: int;
		// start of string to insert
		public var match_start: int;
		// start of matching string
		public var lookahead: int;
		// number of valid bytes ahead in window
		// Length of the best match at previous step. Matches not greater than this
		// are discarded. This is used in the lazy match evaluation.
		public var prev_length: int;

		// To speed up deflation, hash chains are never searched beyond this
		// length.	  A higher limit improves compression ratio but degrades the speed.
		public var max_chain_length: int;

		// Attempt to find a better match only when the current match is strictly
		// smaller than this value. This mechanism is used only for compression
		// levels >= 4.
		public var max_lazy_match: int;

		// Insert new strings in the hash table only if the match length is not
		// greater than this length. This saves time but degrades compression.
		// max_insert_length is used only for compression levels <= 3.
		public var level: int;
		// compression level (1..9)
		public var strategy: int;
		// favor or force Huffman coding
		// Use a faster search when the previous match is longer than this
		public var good_match: int;

		// Stop searching when current match exceeds this
		public var nice_match: int;

		internal var dyn_ltree: Array;
		// literal and length tree
		internal var dyn_dtree: Array;
		// distance tree
		internal var bl_tree: Array;
		// Huffman tree for bit lengths
		internal var l_desc: Tree = new Tree();
		// desc for literal tree
		internal var d_desc: Tree = new Tree();
		// desc for distance tree
		internal var bl_desc: Tree = new Tree();
		// desc for bit length tree
		// number of codes at each bit length for an optimal tree
		internal var bl_count: Array = new Array();

		// heap used to build the Huffman trees
		internal var heap: Array = new Array();

		internal var heap_len: int;
		// number of elements in the heap
		internal var heap_max: int;
		// element of largest frequency
		// The sons of heap[n] are heap[2*n] and heap[2*n+1]. heap[0] is not used.
		// The same heap array is used to build all trees.
		// Depth of each subtree used as tie breaker for trees of equal frequency
		internal var depth: Array = new Array();

		internal var l_buf: int;
		// index for literals or lengths */
		// Size of match buffer for literals/lengths.	 There are 4 reasons for
		// limiting lit_bufsize to 64K:
		//	 - frequencies can be kept in 16 bit counters
		//	 - if compression is not successful for the first block, all input
		//	   data is still in the window so we can still emit a stored block even
		//	   when input comes from standard input.  (This can also be done for
		//	   all blocks if lit_bufsize is not greater than 32K.)
		//	 - if compression is not successful for a file smaller than 64K, we can
		//	   even emit a stored file instead of a stored block (saving 5 bytes).
		//	   This is applicable only for zip (not gzip or zlib).
		//	 - creating new Huffman trees less frequently may not provide fast
		//	   adaptation to changes in the input data statistics. (Take for
		//	   example a binary file with poorly compressible code followed by
		//	   a highly compressible string table.) Smaller buffer sizes give
		//	   fast adaptation but have of course the overhead of transmitting
		//	   trees more frequently.
		//	 - I can't count above 4
		internal var lit_bufsize: int;

		internal var last_lit: int;
		// running index in l_buf
		// Buffer for distances. To simplify the code, d_buf and l_buf have
		// the same number of elements. To use different lengths, an extra flag
		// array would be necessary.
		internal var d_buf: int;
		// index of pendig_buf
		internal var opt_len: int;
		// bit length of current block with optimal trees
		internal var static_len: int;
		// bit length of current block with static trees
		internal var matches: int;
		// number of string matches in current block
		internal var last_eob_len: int;
		// bit length of EOB code for last block
		// Output buffer. bits are inserted starting at the bottom (least
		// significant bits).
		internal var bi_buf: Number;

		// Number of valid bits in bi_buf.	All bits above the last valid bit
		// are always zero.
		internal var bi_valid: int;

		public function Deflate() : void {
			dyn_ltree = new Array();
			dyn_dtree = new Array();
			// distance tree
			bl_tree = new Array();
			// Huffman tree for bit lengths
		}

		internal function lm_init() : void {
			window_size = 2 * w_size;

			head[hash_size - 1] = 0;
			for (var i: int = 0; i < hash_size - 1; i++) {
				head[i] = 0;
			}

			// Set the default configuration parameters:
			max_lazy_match = Deflate.config_table[level].max_lazy;
			good_match = Deflate.config_table[level].good_length;
			nice_match = Deflate.config_table[level].nice_length;
			max_chain_length = Deflate.config_table[level].max_chain;

			strstart = 0;
			block_start = 0;
			lookahead = 0;
			match_length = prev_length = MIN_MATCH - 1;
			match_available = 0;
			ins_h = 0;
		}

		// Initialize the tree data structures for a new zlib stream.
		internal function tr_init() : void {

			l_desc.dyn_tree = dyn_ltree;
			l_desc.stat_desc = StaticTree.static_l_desc;

			d_desc.dyn_tree = dyn_dtree;
			d_desc.stat_desc = StaticTree.static_d_desc;

			bl_desc.dyn_tree = bl_tree;
			bl_desc.stat_desc = StaticTree.static_bl_desc;

			bi_buf = 0;
			bi_valid = 0;
			last_eob_len = 8;
			// enough lookahead for inflate
			// Initialize the first block of the first file:
			init_block();
		}

		internal function init_block() : void {
			// Initialize the trees.
            var i:int;
			for (i = 0; i < L_CODES; i++) dyn_ltree[i * 2] = 0;
			for (i = 0; i < D_CODES; i++) dyn_dtree[i * 2] = 0;
			for (i = 0; i < BL_CODES; i++) bl_tree[i * 2] = 0;

			dyn_ltree[END_BLOCK * 2] = 1;
			opt_len = static_len = 0;
			last_lit = matches = 0;
		}

		// Restore the heap property by moving down the tree starting at node k,
		// exchanging a node with the smallest of its two sons if necessary, stopping
		// when the heap property is re-established (each father smaller than its
		// two sons).
		// tree=the tree to restore
		// k=node to move down
		internal function pqdownheap(tree: Array, k: int) : void {
			var v: int = heap[k];
			var j: int = k << 1;
			// left son of k
			while (j <= heap_len) {
				// Set j to the smallest of the two sons:
				if (j < heap_len && smaller(tree, heap[j + 1], heap[j], depth)) {
					j++;
				}
				// Exit if v is smaller than both sons
				if (smaller(tree, v, heap[j], depth)) {
					break;
				}

				// Exchange v with the smallest son
				heap[k] = heap[j];
				k = j;
				// And continue down the tree, setting j to the left son of k
				j <<= 1;
			}
			heap[k] = v;
		}

		static internal function smaller(tree: Array, n: int, m: int, depth: Array) : Boolean {
			var tn2: Number = tree[n * 2];
			var tm2: Number = tree[m * 2];
			return (tn2 < tm2 ||
			(tn2 == tm2 && depth[n] <= depth[m]));
		}

		// Scan a literal or distance tree to determine the frequencies of the codes
		// in the bit length tree.
		internal function scan_tree(tree: Array,
		// the tree to be scanned
		max_code: int
		// and its largest code of non zero frequency
		) : void {
			var n: int;
			// iterates over all tree elements
			var prevlen: int = -1;
			// last emitted length
			var curlen: int;
			// length of current code
			var nextlen: int = tree[0 * 2 + 1];
			// length of next code
			var count: int = 0;
			// repeat count of the current code
			var max_count: int = 7;
			// max repeat count
			var min_count: int = 4;
			// min repeat count
			if (nextlen == 0) {
				max_count = 138;
				min_count = 3;
			}
			tree[(max_code + 1) * 2 + 1] = 0xffff;
			// guard
			for (n = 0; n <= max_code; n++) {
				curlen = nextlen;
				nextlen = tree[(n + 1) * 2 + 1];
				if (++count < max_count && curlen == nextlen) {
					continue;
				}
				else if (count < min_count) {
					bl_tree[curlen * 2] += count;
				}
				else if (curlen != 0) {
					if (curlen != prevlen) bl_tree[curlen * 2]++;
					bl_tree[REP_3_6 * 2]++;
				}
				else if (count <= 10) {
					bl_tree[REPZ_3_10 * 2]++;
				}
				else {
					bl_tree[REPZ_11_138 * 2]++;
				}
				count = 0;
				prevlen = curlen;
				if (nextlen == 0) {
					max_count = 138;
					min_count = 3;
				}
				else if (curlen == nextlen) {
					max_count = 6;
					min_count = 3;
				}
				else {
					max_count = 7;
					min_count = 4;
				}
			}
		}

		// Construct the Huffman tree for the bit lengths and return the index in
		// bl_order of the last bit length code to send.
		public function build_bl_tree() : int {
			var max_blindex: int;
			// index of last bit length code of non zero freq
			// Determine the bit length frequencies for literal and distance trees
			scan_tree(dyn_ltree, l_desc.max_code);
			scan_tree(dyn_dtree, d_desc.max_code);

			// Build the bit length tree:
			bl_desc.build_tree(this);
			// opt_len now includes the length of the tree representations, except
			// the lengths of the bit lengths codes and the 5+5+4 bits for the counts.
			// Determine the number of bit length codes to send. The pkzip format
			// requires that at least 4 bit length codes be sent. (appnote.txt says
			// 3 but the actual value used is 4.)
			for (max_blindex = BL_CODES - 1; max_blindex >= 3; max_blindex--) {
				if (bl_tree[Tree.bl_order[max_blindex] * 2 + 1] != 0) break;
			}
			// Update opt_len to include the bit length tree and counts
			opt_len += 3 * (max_blindex + 1) + 5 + 5 + 4;

			return max_blindex;
		}


		// Send the header for a block using dynamic Huffman trees: the counts, the
		// lengths of the bit length codes, the literal tree and the distance tree.
		// IN assertion: lcodes >= 257, dcodes >= 1, blcodes >= 4.
		public function send_all_trees(lcodes: int, dcodes: int, blcodes: int) : void {
			var rank: int;
			// index in bl_order
			send_bits(lcodes - 257, 5);
			// not +255 as stated in appnote.txt
			send_bits(dcodes - 1, 5);
			send_bits(blcodes - 4, 4);
			// not -3 as stated in appnote.txt
			for (rank = 0; rank < blcodes; rank++) {
				send_bits(bl_tree[Tree.bl_order[rank] * 2 + 1], 3);
			}
			send_tree(dyn_ltree, lcodes - 1);
			// literal tree
			send_tree(dyn_dtree, dcodes - 1);
			// distance tree
		}

		// Send a literal or distance tree in compressed form, using the codes in
		// bl_tree.
		public function send_tree(tree: Array,
			// the tree to be sent
			max_code: int
			// and its largest code of non zero frequency
			) : void {
			var n: int;
			// iterates over all tree elements
			var prevlen: int = -1;
			// last emitted length
			var curlen: int;
			// length of current code
			var nextlen: int = tree[0 * 2 + 1];
			// length of next code
			var count: int = 0;
			// repeat count of the current code
			var max_count: int = 7;
			// max repeat count
			var min_count: int = 4;
			// min repeat count
			if (nextlen == 0) {
				max_count = 138;
				min_count = 3;
			}

			for (n = 0; n <= max_code; n++) {
				curlen = nextlen;
				nextlen = tree[(n + 1) * 2 + 1];
				if (++count < max_count && curlen == nextlen) {
					continue;
				}
				else if (count < min_count) {
					do {
						send_code(curlen, bl_tree);
					}
					while (--count != 0);
				}
				else if (curlen != 0) {
					if (curlen != prevlen) {
						send_code(curlen, bl_tree);
						count--;
					}
					send_code(REP_3_6, bl_tree);
					send_bits(count - 3, 2);
				}
				else if (count <= 10) {
					send_code(REPZ_3_10, bl_tree);
					send_bits(count - 3, 3);
				}
				else {
					send_code(REPZ_11_138, bl_tree);
					send_bits(count - 11, 7);
				}
				count = 0;
				prevlen = curlen;
				if (nextlen == 0) {
					max_count = 138;
					min_count = 3;
				}
				else if (curlen == nextlen) {
					max_count = 6;
					min_count = 3;
				}
				else {
					max_count = 7;
					min_count = 4;
				}
			}
		}

		// Output a byte on the stream.
		// IN assertion: there is enough room in pending_buf.
		public final function put_byte(p: ByteArray, start: int, len: int) : void {
			System.byteArrayCopy(p, start, pending_buf, pending, len);
			pending += len;
		}

		public function put_byte_withInt(c: int) : void {
			pending_buf.writeByte(c);
			pending++;
			//pending_buf[pending++] = c;
		}
		public function put_short(w: int) : void {
			// java = 
			//put_byte(byte((w
			// /*&0xff*/
			// )));
			//put_byte(w);
			//pending_buf.writeShort(w);
			//pending_buf.writeShort(w >>> 8);
			this.put_byte_withInt(w);
			this.put_byte_withInt(w >>> 8);
			//pending++;
			//pending++;
		}
		public final function putShortMSB(b: int) : void {
			this.put_byte_withInt(b>>8);
			this.put_byte_withInt(b&0xff);
		}

		public final function send_code(c: int, tree: Array) : void {
			var c2: int = c * 2;
			send_bits((tree[c2]) & 0xffff, (tree[c2 + 1] & 0xffff));
		}

		public function send_bits(value: int, length: int) : void {
			var len: int = length;
			if (bi_valid > int(Buf_size) - len) {
				var val: int = value;
				// c = bi_buf |= (val << bi_valid);
				bi_buf |= ((val << bi_valid) & 0xffff);
				put_short(bi_buf);
				bi_buf = (val >>> (Buf_size - bi_valid));
				bi_buf = Cast.toShort((val >>> (Buf_size - bi_valid)));
				bi_valid += len - Buf_size;
			} else {
				//		bi_buf |= (value) << bi_valid;
				bi_buf |= ((value << bi_valid) & 0xffff);
				bi_valid += len;
			}
		}

		// Send one empty static block to give enough lookahead for inflate.
		// This takes 10 bits, of which 7 may remain in the bit buffer.
		// The current inflate code requires 9 bits of lookahead. If the
		// last two codes for the previous block (real code plus EOB) were coded
		// on 5 bits or less, inflate may have only 5+3 bits of lookahead to decode
		// the last real code. In this case we send two empty static blocks instead
		// of one. (There are no problems if the previous block is stored or fixed.)
		// To simplify the code, we assume the worst case of last real code encoded
		// on one bit only.
		public function _tr_align() : void {
			send_bits(STATIC_TREES << 1, 3);
			send_code(END_BLOCK, StaticTree.static_ltree);

			bi_flush();

			// Of the 10 bits for the empty block, we have already sent
			// (10 - bi_valid) bits. The lookahead for the last real code (before
			// the EOB of the previous block) was thus at least one plus the length
			// of the EOB plus what we have just sent of the empty static block.
			if (1 + last_eob_len + 10 - bi_valid < 9) {
				send_bits(STATIC_TREES << 1, 3);
				send_code(END_BLOCK, StaticTree.static_ltree);
				bi_flush();
			}
			last_eob_len = 7;
		}


		// Save the match info and tally the frequency counts. Return true if
		// the current block must be flushed.
		public function _tr_tally(dist: int, // distance of matched string
			lc: int // match length-MIN_MATCH or unmatched char (if dist==0)
			) : Boolean {

			// java = 
			// pending_buf[d_buf+last_lit*2] = (byte)(dist>>>8);
			// pending_buf[d_buf+last_lit*2+1] = (byte)dist;

			pending_buf[d_buf + last_lit * 2] = Cast.toByte(dist >>> 8);
			pending_buf[d_buf + last_lit * 2 + 1] = Cast.toByte(dist);

			pending_buf[l_buf + last_lit] = lc;
			last_lit++;

			if (dist == 0) {
				// lc is the unmatched char
				dyn_ltree[lc * 2]++;
			}
			else {
				matches++;
				// Here, lc is the match length - MIN_MATCH
				dist--;
				// dist = match distance - 1
				dyn_ltree[(Tree._length_code[lc] + LITERALS + 1) * 2]++;
				dyn_dtree[Tree.d_code(dist) * 2]++;
			}

			if ((last_lit & 0x1) == 0 && level > 2) {
				// Compute an upper bound for the compressed length
				var out_length: int = last_lit * 8;
				var in_length: int = strstart - block_start;
				var dcode: int;
				for (dcode = 0; dcode < D_CODES; dcode++) {
					out_length += int(dyn_dtree[dcode * 2]) * (5 + Tree.extra_dbits[dcode]);
				}
				out_length >>>= 3;
				if ((matches < (last_lit / 2)) && out_length < in_length / 2) {
					return true;
				}
			}

			return (last_lit == lit_bufsize - 1);
			// We avoid equality with lit_bufsize because of wraparound at 64K
			// on 16 bit machines and because stored blocks are restricted to
			// 64K-1 bytes.
		}

		// Send the block data compressed using the given Huffman trees
		public function compress_block(ltree: Array, dtree: Array) : void {
			var dist: int;		// distance of matched string
			var lc: int;		// match length or unmatched char (if dist == 0)
			var lx: int = 0;	// running index in l_buf
			var code: int;		// the code to send
			var extra: int;		// number of extra bits to send
			if (last_lit != 0) {
				do {
					dist=((pending_buf[d_buf+lx*2]<<8) & 0xff00) | (pending_buf[d_buf+lx*2+1] & 0xff);
					lc=(pending_buf[l_buf+lx])&0xff;
					lx++;

					if (dist == 0) {
						send_code(lc, ltree);
						// send a literal byte
					}
					else {
						// Here, lc is the match length - MIN_MATCH
						code = Tree._length_code[lc];

						send_code(code + LITERALS + 1, ltree);
						// send the length code
						extra = Tree.extra_lbits[code];
						if (extra != 0) {
							lc -= Tree.base_length[code];
							send_bits(lc, extra);
							// send the extra length bits
						}
						dist--;
						// dist is now the match distance - 1
						code = Tree.d_code(dist);

						send_code(code, dtree);
						// send the distance code
						extra = Tree.extra_dbits[code];
						if (extra != 0) {
							dist -= Tree.base_dist[code];
							send_bits(dist, extra);
							// send the extra distance bits
						}
					}
					// literal or match pair ?
					// Check that the overlay between pending_buf and d_buf+l_buf is ok:
				}
				while (lx < last_lit);
			}

			send_code(END_BLOCK, ltree);
			last_eob_len = ltree[END_BLOCK * 2 + 1];
		}

		// Set the data type to ASCII or BINARY, using a crude approximation:
		// binary if more than 20% of the bytes are <= 6 or >= 128, ascii otherwise.
		// IN assertion: the fields freq of dyn_ltree are set and the total of all
		// frequencies does not exceed 64K (to fit in an int on 16 bit machines).
		internal function set_data_type() : void {
			var n: int = 0;
			var ascii_freq: int = 0;
			var bin_freq: int = 0;
			while (n < 7) {
				bin_freq += dyn_ltree[n * 2];
				n++;
			}
			while (n < 128) {
				ascii_freq += dyn_ltree[n * 2];
				n++;
			}
			while (n < LITERALS) {
				bin_freq += dyn_ltree[n * 2];
				n++;
			}
			// java = data_type =(byte)(bin_freq > (ascii_freq >>> 2) ? Z_BINARY : Z_ASCII);
			data_type = (bin_freq > (ascii_freq >>> 2) ? Z_BINARY: Z_ASCII);
		}

		// Flush the bit buffer, keeping at most 7 bits in it.
		public function bi_flush() : void {
			if (bi_valid == 16) {
				put_short(bi_buf);
				bi_buf = 0;
				bi_valid = 0;
			} else if (bi_valid >= 8) {
				this.put_byte_withInt(bi_buf);
				bi_buf >>>= 8;
				bi_valid -= 8;
			}
		}

		// Flush the bit buffer and align the output on a byte boundary
		public function bi_windup() : void {
			if (bi_valid > 8) {
				put_short(bi_buf);
			} else if (bi_valid > 0) {
				this.put_byte_withInt(bi_buf);
			}
			bi_buf = 0;
			bi_valid = 0;
		}

		// Copy a stored block, storing first the length and its
		// one's complement if requested.
		internal function copy_block(buf: int,
		// the input data
		len: int,
		// its length
		header: Boolean
		// true if block header must be written
		) : void {
			var index: int = 0;
			bi_windup();
			// align on byte boundary
			last_eob_len = 8;
			// enough lookahead for inflate
			if (header) {
				put_short(len);
				// java = put_short(short()~len);
				put_short(~len & 0xFFFF);
			}

			//	while(len--!=0) {
			//	  put_byte(window[buf+index]);
			//	  index++;
			//	}
			put_byte(window, buf, len);
		}

		internal function flush_block_only(eof: Boolean) : void {
			_tr_flush_block(block_start >= 0 ? block_start: -1,
			strstart - block_start,
			eof);
			block_start = strstart;
			strm.flush_pending();
		}

		// Copy without compression as much as possible from the input stream, return
		// the current block state.
		// This function does not insert new strings in the dictionary since
		// uncompressible data is probably not useful. This function is used
		// only for the level=0 compression option.
		// NOTE: this function should be optimized to avoid extra copying from
		// window to pending_buf.
		public function deflate_stored(flush: int) : int {
			// Stored blocks are limited to 0xffff bytes, pending_buf is limited
			// to pending_buf_size, and each stored block has a 5 byte header:
			var max_block_size: int = 0;
			var max_start: int;

			if (max_block_size > pending_buf_size - 5) {
				max_block_size = pending_buf_size - 5;
			}

			// Copy as much as possible from input to output:
			while (true) {
				// Fill the window as much as possible:
				if (lookahead <= 1) {
					fill_window();
					if (lookahead == 0 && flush == Z_NO_FLUSH) return NeedMore;
					if (lookahead == 0) break;
					// flush the current block
				}

				strstart += lookahead;
				lookahead = 0;

				// Emit a stored block if pending_buf will be full:
				max_start = block_start + max_block_size;
				if (strstart == 0 || strstart >= max_start) {
					// strstart == 0 is possible when wraparound on 16-bit machine
					lookahead = int((strstart - max_start));
					strstart = int(max_start);

					flush_block_only(false);
					if (strm.avail_out == 0) return NeedMore;

				}

				// Flush if we may have to slide, otherwise block_start may become
				// negative and the data will be gone:
				if (strstart - block_start >= w_size - MIN_LOOKAHEAD) {
					flush_block_only(false);
					if (strm.avail_out == 0) return NeedMore;
				}
			}

			flush_block_only(flush == Z_FINISH);
			if (strm.avail_out == 0)
			return (flush == Z_FINISH) ? FinishStarted: NeedMore;

			return flush == Z_FINISH ? FinishDone: BlockDone;
		}

		// Send a stored block
		public function _tr_stored_block(buf: int,
		// input block
		stored_len: int,
		// length of input block
		eof: Boolean
		// true if this is the last block for a file
		) : void {
			send_bits((STORED_BLOCK << 1) + (eof ? 1: 0), 3);
			// send block type
			copy_block(buf, stored_len, true);
			// with header
		}

		// Determine the best encoding for the current block: dynamic trees, static
		// trees or store, and output the encoded block to the zip file.
		internal function _tr_flush_block(buf: int,
		// input block, or NULL if too old
		stored_len: int,
		// length of input block
		eof: Boolean
		// true if this is the last block for a file
		) : void {
			var opt_lenb:int,
			static_lenb:int;
			// opt_len and static_len in bytes
			var max_blindex: int = 0;
			// index of last bit length code of non zero freq
			// Build the Huffman trees unless a stored block is forced
			if (level > 0) {
				// Check if the file is ascii or binary
				if (data_type == Z_UNKNOWN) set_data_type();

				// Construct the literal and distance trees
				l_desc.build_tree(this);

				d_desc.build_tree(this);

				// At this point, opt_len and static_len are the total bit lengths of
				// the compressed block data, excluding the tree representations.
				// Build the bit length tree for the above two trees, and get the index
				// in bl_order of the last bit length code to send.
				max_blindex = build_bl_tree();

				// Determine the best encoding. Compute first the block length in bytes
				opt_lenb = (opt_len + 3 + 7) >>> 3;
				static_lenb = (static_len + 3 + 7) >>> 3;

				if (static_lenb <= opt_lenb) opt_lenb = static_lenb;
			}
			else {
				opt_lenb = static_lenb = stored_len + 5;
				// force a stored block
			}

			if (stored_len + 4 <= opt_lenb && buf != -1) {
				// 4: two words for the lengths
				// The test buf != NULL is only necessary if LIT_BUFSIZE > WSIZE.
				// Otherwise we can't have processed more than WSIZE input bytes since
				// the last block flush, because compression would have been
				// successful. If LIT_BUFSIZE <= WSIZE, it is never too late to
				// transform a block into a stored block.
				_tr_stored_block(buf, stored_len, eof);
			}
			else if (static_lenb == opt_lenb) {
				send_bits((STATIC_TREES << 1) + (eof ? 1: 0), 3);
				compress_block(StaticTree.static_ltree, StaticTree.static_dtree);
			}
			else {
				send_bits((DYN_TREES << 1) + (eof ? 1: 0), 3);
				send_all_trees(l_desc.max_code + 1, d_desc.max_code + 1, max_blindex + 1);
				compress_block(dyn_ltree, dyn_dtree);
			}

			// The above check is made mod 2^32, for files larger than 512 MB
			// and uLong implemented on 32 bits.
			init_block();

			if (eof) {
				bi_windup();
			}
		}

		// Fill the window when the lookahead becomes insufficient.
		// Updates strstart and lookahead.
		//
		// IN assertion: lookahead < MIN_LOOKAHEAD
		// OUT assertions: strstart <= window_size-MIN_LOOKAHEAD
		//	  At least one byte has been read, or avail_in == 0; reads are
		//	  performed for at least two bytes (required for the zip translate_eol
		//	  option -- not supported here).
		internal function fill_window() : void {
			var n: int,
			m:int;
			var p: int;
			var more: int;
			// Amount of free space at the end of the window.
			do {
				more = (window_size - lookahead - strstart);

				// Deal with !@#$% 64K limit:
				if (more == 0 && strstart == 0 && lookahead == 0) {
					more = w_size;
				}
				else if (more == -1) {
					// Very unlikely, but possible on 16 bit machine if strstart == 0
					// and lookahead == 1 (input done one byte at time)
					more--;

					// If the window is almost full and there is insufficient lookahead,
					// move the upper half to the lower one to make room in the upper half.
				}
				else if (strstart >= w_size + w_size - MIN_LOOKAHEAD) {
					System.byteArrayCopy(window, w_size, window, 0, w_size);
					match_start -= w_size;
					strstart -= w_size;
					// we now have strstart >= MAX_DIST
					block_start -= w_size;

					// Slide the hash table (could be avoided with 32 bit values
					// at the expense of memory usage). We slide even when level == 0
					// to keep the hash table consistent if we switch back to level > 0
					// later. (Using level 0 permanently is not an optimal usage of
					// zlib, so we don't care about this pathological case.)
					n = hash_size;
					p = n;
					do {
						m = (head[--p]&0xffff);
						// java = head[p]=(m>=w_size ? (short)(m-w_size) : 0);
						head[p] = (m >= w_size ? Cast.toShort(m - w_size) : 0);
					}
					while (--n != 0);

					n = w_size;
					p = n;
					do {
						m = (prev[--p]&0xffff);
						// java = prev[p] = (m >= w_size ? (short)(m-w_size) : 0);
						prev[p] = (m >= w_size ? Cast.toShort(m - w_size) : 0);
						// If n is not on any hash chain, prev[n] is garbage but
						// its value will never be used.
					}
					while (--n != 0);
					more += w_size;
				}

				if (strm.avail_in == 0) return;

				// If there was no sliding:
				//	  strstart <= WSIZE+MAX_DIST-1 && lookahead <= MIN_LOOKAHEAD - 1 &&
				//	  more == window_size - lookahead - strstart
				// => more >= window_size - (MIN_LOOKAHEAD-1 + WSIZE + MAX_DIST-1)
				// => more >= window_size - 2*WSIZE + 2
				// In the BIG_MEM or MMAP case (not yet supported),
				//	 window_size == input_size + MIN_LOOKAHEAD	&&
				//	 strstart + s->lookahead <= input_size => more >= MIN_LOOKAHEAD.
				// Otherwise, window_size == 2*WSIZE so more >= 2.
				// If there was sliding, more >= WSIZE. So in all cases, more >= 2.
				n = strm.read_buf(window, strstart + lookahead, more);
				lookahead += n;

				// Initialize the hash value now that we have some input:
				if (lookahead >= MIN_MATCH) {
					ins_h = window[strstart]&0xff;
					ins_h = ((ins_h << hash_shift) ^ (window[strstart + 1]&0xff)) & hash_mask;
				}
				// If the whole input has less than MIN_MATCH bytes, ins_h is garbage,
				// but this is not important since only literal bytes will be emitted.
			}
			while (lookahead < MIN_LOOKAHEAD && strm.avail_in != 0);
		}

		// Compress as much as possible from the input stream, return the current
		// block state.
		// This function does not perform lazy evaluation of matches and inserts
		// new strings in the dictionary only for unmatched strings or for short
		// matches. It is used only for the fast compression options.
		public function deflate_fast(flush: int) : int {
			//	  short hash_head = 0; // head of the hash chain
			var hash_head: int = 0;
			// head of the hash chain
			var bflush: Boolean;
			// set if current block must be flushed
			while (true) {
				// Make sure that we always have enough lookahead, except
				// at the end of the input file. We need MAX_MATCH bytes
				// for the next match, plus MIN_MATCH bytes to insert the
				// string following the next match.
				if (lookahead < MIN_LOOKAHEAD) {
					fill_window();
					if (lookahead < MIN_LOOKAHEAD && flush == Z_NO_FLUSH) {
						return NeedMore;
					}
					if (lookahead == 0) break;
					// flush the current block
				}

				// Insert the string window[strstart .. strstart+2] in the
				// dictionary, and set hash_head to the head of the hash chain:
				if (lookahead >= MIN_MATCH) {
					ins_h = ((ins_h << hash_shift) ^ (window[(strstart) + (MIN_MATCH - 1)] & 0xff)) & hash_mask;

					//	prev[strstart&w_mask]=hash_head=head[ins_h];
					// java hash_head = (head[ins_h] & 0x);
					hash_head = (head[ins_h]);
					prev[strstart & w_mask] = head[ins_h];
					// java = head[ins_h]=(short)strstart;
					head[ins_h] = Cast.toShort(strstart);
				}

				// Find the longest match, discarding those <= prev_length.
				// At this point we have always match_length < MIN_MATCH
				// java if (hash_head != 0 && ((strstart - hash_head) & 0x) <= w_size - MIN_LOOKAHEAD) {
				if (hash_head != 0 && ((strstart - hash_head)) <= w_size - MIN_LOOKAHEAD) {
					// To simplify the code, we prevent matches with the string
					// of window index 0 (in particular we have to avoid a match
					// of the string with itself at the start of the input file).
					if (strategy != Z_HUFFMAN_ONLY) {
						match_length = longest_match(hash_head);
					}
					// longest_match() sets match_start
				}
				if (match_length >= MIN_MATCH) {
					//		  check_match(strstart, match_start, match_length);
					bflush = _tr_tally(strstart - match_start, match_length - MIN_MATCH);

					lookahead -= match_length;

					// Insert new strings in the hash table only if the match length
					// is not too large. This saves time but degrades compression.
					if (match_length <= max_lazy_match &&
					lookahead >= MIN_MATCH) {
						match_length--; // string at strstart already in hash table
						do {
							strstart++;

							ins_h = ((ins_h << hash_shift) ^ (window[(strstart) + (MIN_MATCH - 1)] & 0xff)) & hash_mask;
							//		prev[strstart&w_mask]=hash_head=head[ins_h];
							hash_head=(head[ins_h]&0xffff);
							prev[strstart & w_mask] = head[ins_h];
							// java = head[ins_h]=(short)strstart;
							head[ins_h] = Cast.toShort(strstart);

							// strstart never exceeds WSIZE-MAX_MATCH, so there are
							// always MIN_MATCH bytes ahead.
						}
						while (--match_length != 0);
						strstart++;
					} else {
						strstart += match_length;
						match_length = 0;
						// java = ins_h = window[strstart] & 0x;
						ins_h = window[strstart];

						// java = ins_h=(((ins_h)<<hash_shift)^(window[strstart+1]&0xff))&hash_mask;
						ins_h = ((ins_h << hash_shift) ^ (window[strstart + 1]&0xff)) & hash_mask;
						// If lookahead < MIN_MATCH, ins_h is garbage, but it does not
						// matter since it will be recomputed at next deflate call.
					}
				} else {
					// No match, output a literal byte
					bflush = _tr_tally(0, window[strstart] & 0xff);
					lookahead--;
					strstart++;
				}
				if (bflush) {

					flush_block_only(false);
					if (strm.avail_out == 0) return NeedMore;
				}
			}

			flush_block_only(flush == Z_FINISH);
			if (strm.avail_out == 0) {
				if (flush == Z_FINISH) return FinishStarted;
				else return NeedMore;
			}
			return flush == Z_FINISH ? FinishDone: BlockDone;
		}

		// Same as above, but achieves better compression. We use a lazy
		// evaluation for matches: a match is finally adopted only if there is
		// no better match at the next window position.
		public function deflate_slow(flush: int) : int {
			//	  short hash_head = 0;	  // head of hash chain
			var hash_head: int = 0;
			// head of hash chain
			var bflush: Boolean;
			// set if current block must be flushed
			// Process the input block.
			while (true) {
				// Make sure that we always have enough lookahead, except
				// at the end of the input file. We need MAX_MATCH bytes
				// for the next match, plus MIN_MATCH bytes to insert the
				// string following the next match.
				if (lookahead < MIN_LOOKAHEAD) {
					fill_window();
					if (lookahead < MIN_LOOKAHEAD && flush == Z_NO_FLUSH) {
						return NeedMore;
					}
					if (lookahead == 0) break;
					// flush the current block
				}

				// Insert the string window[strstart .. strstart+2] in the
				// dictionary, and set hash_head to the head of the hash chain:
				if (lookahead >= MIN_MATCH) {
					ins_h = ((ins_h << hash_shift) ^ (window[strstart + (MIN_MATCH - 1)] & 0xff)) & hash_mask;
					//	prev[strstart&w_mask]=hash_head=head[ins_h];
					hash_head = (head[ins_h] & 0xffff);
					prev[strstart & w_mask] = head[ins_h];
					// java = head[ins_h]=(short)strstart;
					head[ins_h] = Cast.toShort(strstart);
				}

				// Find the longest match, discarding those <= prev_length.
				prev_length = match_length;
				prev_match = match_start;
				match_length = MIN_MATCH - 1;

				if (hash_head != 0 && prev_length < max_lazy_match && ((strstart - hash_head)&0xffff) <= w_size - MIN_LOOKAHEAD) {
					// To simplify the code, we prevent matches with the string
					// of window index 0 (in particular we have to avoid a match
					// of the string with itself at the start of the input file).
					if (strategy != Z_HUFFMAN_ONLY) {
						match_length = longest_match(hash_head);
					}
					// longest_match() sets match_start
					if (match_length <= 5 && (strategy == Z_FILTERED ||
					(match_length == MIN_MATCH &&
					strstart - match_start > 4096))) {

						// If prev_match is also MIN_MATCH, match_start is garbage
						// but we will ignore the current match anyway.
						match_length = MIN_MATCH - 1;
					}
				}

				// If there was a match at the previous step and the current
				// match is not better, output the previous match:
				if (prev_length >= MIN_MATCH && match_length <= prev_length) {
					var max_insert: int = strstart + lookahead - MIN_MATCH;
					// Do not insert strings in hash table beyond this.
					//			check_match(strstart-1, prev_match, prev_length);
					bflush = _tr_tally(strstart - 1 - prev_match, prev_length - MIN_MATCH);

					// Insert in hash table all strings up to the end of the match.
					// strstart-1 and strstart are already inserted. If there is not
					// enough lookahead, the last two strings are not inserted in
					// the hash table.
					lookahead -= prev_length - 1;
					prev_length -= 2;
					do {
						if (++strstart <= max_insert) {
							ins_h = (((ins_h) << hash_shift) ^ (window[strstart + (MIN_MATCH - 1)] & 0xff)) & hash_mask;

							//prev[strstart&w_mask]=hash_head=head[ins_h];
							hash_head=(head[ins_h]&0xffff);
							prev[strstart&w_mask]=head[ins_h];
							// java = head[ins_h]=(short)strstart;
							head[ins_h] = Cast.toShort(strstart);
						}
					}
					while (--prev_length != 0);
					match_available = 0;
					match_length = MIN_MATCH - 1;
					strstart++;

					if (bflush) {
						flush_block_only(false);
						if (strm.avail_out == 0) return NeedMore;
					}
				} else if (match_available != 0) {

					// If there was no match at the previous position, output a
					// single literal. If there was a match but the current match
					// is longer, truncate the previous match to a single literal.
					bflush = _tr_tally(0, window[strstart - 1] & 0xff);

					if (bflush) {
						flush_block_only(false);
					}
					strstart++;
					lookahead--;
					if (strm.avail_out == 0) return NeedMore;
				} else {
					// There is no previous match to compare with, wait for
					// the next step to decide.
					match_available = 1;
					strstart++;
					lookahead--;
				}
			}

			if (match_available != 0) {
				bflush=_tr_tally(0, window[strstart-1]&0xff);
				match_available = 0;
			}
			flush_block_only(flush == Z_FINISH);

			if (strm.avail_out == 0) {
				if (flush == Z_FINISH) return FinishStarted;
				else return NeedMore;
			}

			return flush == Z_FINISH ? FinishDone: BlockDone;
		}

		internal function longest_match(cur_match: int) : int {
			var chain_length: int = max_chain_length;	// max hash chain length
			var scan: int = strstart;					// current string
			var match: int;								// matched string
			var len: int;								// length of current match
			var best_len: int = prev_length;			// best match length so far
			var limit: int = strstart > (w_size - MIN_LOOKAHEAD) ? strstart - (w_size - MIN_LOOKAHEAD) : 0;
			var nice_match: int = this.nice_match;

			// Stop when cur_match becomes <= limit. To simplify the code,
			// we prevent matches with the string of window index 0.
			var wmask: int = w_mask;

			var strend: int = strstart + MAX_MATCH;
			var scan_end1: uint = window[scan + best_len - 1];
			var scan_end: uint = window[scan + best_len];

			// The code is optimized for HASH_BITS >= 8 and MAX_MATCH-2 multiple of 16.
			// It is easy to get rid of this optimization if necessary.
			// Do not waste too much time if we already have a good match:
			if (prev_length >= good_match) {
				chain_length >>= 2;
			}

			// Do not look for matches beyond the end of the input. This is necessary
			// to make deflate deterministic.
			if (nice_match > lookahead) nice_match = lookahead;

			do {
				match = cur_match;

				// Skip to next match if the match length cannot increase
				// or if the match length is less than 2:
				if (window[match + best_len] != scan_end ||
				window[match + best_len - 1] != scan_end1 ||
				window[match] != window[scan] ||
				window[++match] != window[scan + 1]) continue;

				// The check at best_len-1 can be removed because it will be made
				// again later. (This heuristic is not always a win.)
				// It is not necessary to compare scan[2] and match[2] since they
				// are always equal when the other bytes match, given that
				// the hash keys are equal and that HASH_BITS >= 8.
				scan += 2;
				match++;

				// We check for insufficient lookahead only every 8th comparison;
				// the 256th check will be made at strstart+258.
				do {
				} while (window[++scan] == window[++match] &&
					window[++scan] == window[++match] &&
					window[++scan] == window[++match] &&
					window[++scan] == window[++match] &&
					window[++scan] == window[++match] &&
					window[++scan] == window[++match] &&
					window[++scan] == window[++match] &&
					window[++scan] == window[++match] &&
					scan < strend);

				len = MAX_MATCH - int((strend - scan));
				scan = strend - MAX_MATCH;

				if (len > best_len) {
					match_start = cur_match;
					best_len = len;
					if (len >= nice_match) break;
					scan_end1 = window[scan + best_len - 1];
					scan_end = window[scan + best_len];
				}
		    } while ((cur_match = (prev[cur_match & wmask]&0xffff)) > limit && --chain_length != 0);

			if (best_len <= lookahead) return best_len;
			return lookahead;
		}

		public function deflateInitWithBits(strm: ZStream, level: int, bits: int) : int {
			return deflateInit2(strm, level, Z_DEFLATED, bits, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY);
		}
		public function deflateInit(strm: ZStream, level: int) : int {
			return deflateInitWithBits(strm, level, MAX_WBITS);
		}
		public function deflateInit2(strm: ZStream, level: int, method: int, windowBits: int, memLevel: int, strategy: int) : int {
			var noheader: int = 0;
			//	  byte[] my_version=ZLIB_VERSION;
			//
			//	if (version == null || version[0] != my_version[0]
			//	|| stream_size != sizeof(z_stream)) {
			//	return Z_VERSION_ERROR;
			//	}
			strm.msg = null;

			if (level == Z_DEFAULT_COMPRESSION) level = 6;

			if (windowBits < 0) {
				// undocumented feature: suppress zlib header
				noheader = 1;
				windowBits = -windowBits;
			}

			if (memLevel < 1 || memLevel > MAX_MEM_LEVEL ||
			method != Z_DEFLATED ||
			windowBits < 9 || windowBits > 15 || level < 0 || level > 9 ||
			strategy < 0 || strategy > Z_HUFFMAN_ONLY) {
				return Z_STREAM_ERROR;
			}

			strm.dstate = Deflate(this);

			this.noheader = noheader;
			w_bits = windowBits;
			w_size = 1 << w_bits;
			w_mask = w_size - 1;

			hash_bits = memLevel + 7;
			hash_size = 1 << hash_bits;
			hash_mask = hash_size - 1;
			hash_shift = ((hash_bits + MIN_MATCH - 1) / MIN_MATCH);

			window = new ByteArray();
			prev = new Array();
			head = new Array();

			lit_bufsize = 1 << (memLevel + 6);
			// 16K elements by default
			// We overlay pending_buf and d_buf+l_buf. This works since the average
			// output size for (length,distance) codes is <= 24 bits.
			pending_buf = new ByteArray();
			pending_buf_size = lit_bufsize * 4;

			d_buf = lit_bufsize / 2;
			l_buf = (1 + 2) * lit_bufsize;

			this.level = level;

			//System.out.println("level="+level);
			this.strategy = strategy;
			this.method = method;

			return deflateReset(strm);
		}

		internal function deflateReset(strm: ZStream) : int {
			strm.total_in = strm.total_out = 0;
			strm.msg = null;
			//
			strm.data_type = Z_UNKNOWN;

			pending = 0;
			pending_out = 0;

			pending_buf = new ByteArray();

			if (noheader < 0) {
				noheader = 0;
				// was set to -1 by deflate(..., Z_FINISH);
			}
			status = (noheader != 0) ? BUSY_STATE: INIT_STATE;
			strm.adler = strm._adler.adler32(0, null, 0, 0);

			last_flush = Z_NO_FLUSH;

			tr_init();
			lm_init();
			return Z_OK;
		}

		internal function deflateEnd() : int {
			if (status != INIT_STATE && status != BUSY_STATE && status != FINISH_STATE) {
				return Z_STREAM_ERROR;
			}
			// Deallocate in reverse order of allocations:
			pending_buf = null;
			head = null;
			prev = null;
			window = null;
			// free
			// dstate=null;
			return status == BUSY_STATE ? Z_DATA_ERROR: Z_OK;
		}

		internal function deflateParams(strm: ZStream, _level: int, _strategy: int) : int {
			var err: int = Z_OK;

			if (_level == Z_DEFAULT_COMPRESSION) {
				_level = 6;
			}
			if (_level < 0 || _level > 9 ||
			_strategy < 0 || _strategy > Z_HUFFMAN_ONLY) {
				return Z_STREAM_ERROR;
			}

			if (config_table[level].func != config_table[_level].func &&
			strm.total_in != 0) {
				// Flush the last buffer:
				err = strm.deflate(Z_PARTIAL_FLUSH);
			}

			if (level != _level) {
				level = _level;
				max_lazy_match = config_table[level].max_lazy;
				good_match = config_table[level].good_length;
				nice_match = config_table[level].nice_length;
				max_chain_length = config_table[level].max_chain;
			}
			strategy = _strategy;
			return err;
		}

		internal function deflateSetDictionary(strm: ZStream, dictionary:ByteArray, dictLength: int) : int {
			var length: int = dictLength;
			var index: int = 0;

			if (dictionary == null || status != INIT_STATE)
			return Z_STREAM_ERROR;

			strm.adler = strm._adler.adler32(strm.adler, dictionary, 0, dictLength);

			if (length < MIN_MATCH) return Z_OK;
			if (length > w_size - MIN_LOOKAHEAD) {
				length = w_size - MIN_LOOKAHEAD;
				index = dictLength - length;
				// use the tail of the dictionary
			}
			System.byteArrayCopy(dictionary, index, window, 0, length);
			strstart = length;
			block_start = length;

			// Insert all strings in the hash table (except for the last two bytes).
			// s->lookahead stays null, so s->ins_h will be recomputed at the next
			// call of fill_window.
			ins_h = window[0]&0xff;
			ins_h=(((ins_h)<<hash_shift) ^ (window[1]&0xff)) & hash_mask;

			for (var n: int = 0; n <= length - MIN_MATCH; n++) {
				ins_h=(((ins_h)<<hash_shift) ^ (window[(n) + (MIN_MATCH-1)] & 0xff)) & hash_mask;
				prev[n & w_mask] = head[ins_h];
				// java = head[ins_h]=(short)n;
				head[ins_h] = Cast.toShort(n);
			}
			return Z_OK;
		}

		public function deflate(strm: ZStream, flush: int) : int {
			var old_flush: int;

			if (flush > Z_FINISH || flush < 0) {
				return Z_STREAM_ERROR;
			}

			if (strm.next_out == null ||
				(strm.next_in == null && strm.avail_in != 0) ||
				(status == FINISH_STATE && flush != Z_FINISH)) {
					
				strm.msg = z_errmsg[Z_NEED_DICT - Z_STREAM_ERROR];
				return Z_STREAM_ERROR;
			}
			
			if (strm.avail_out == 0) {
				strm.msg = z_errmsg[Z_NEED_DICT - Z_BUF_ERROR];
				return Z_BUF_ERROR;
			}

			this.strm = strm;
			// just in case
			old_flush = last_flush;
			last_flush = flush;

			// Write the zlib header
			if (status == INIT_STATE) {

				var header: int = (Z_DEFLATED + ((w_bits - 8) << 4)) << 8;
				var level_flags: int = ((level - 1) & 0xff) >> 1;

				if (level_flags > 3) level_flags = 3;
				header |= (level_flags << 6);
				if (strstart != 0) header |= PRESET_DICT;
				header += 31 - (header % 31);

				status = BUSY_STATE;
				putShortMSB(header);


				// Save the adler32 of the preset dictionary:
				if (strstart != 0) {
					putShortMSB(int((strm.adler >>> 16)));
					putShortMSB(int((strm.adler & 0xffff)));
				}
				strm.adler = strm._adler.adler32(0, null, 0, 0);
			}

			// Flush as much pending output as possible
			if (pending != 0) {
				strm.flush_pending();
				if (strm.avail_out == 0) {
					//System.out.println("	avail_out==0");
					// Since avail_out is 0, deflate will be called again with
					// more output space, but possibly with both pending and
					// avail_in equal to zero. There won't be anything to do,
					// but this is not an error situation so make sure we
					// return OK instead of BUF_ERROR at next call of deflate:
					last_flush = -1;
					return Z_OK;
				}

				// Make sure there is something to do and avoid duplicate consecutive
				// flushes. For repeated and useless calls with Z_FINISH, we keep
				// returning Z_STREAM_END instead of Z_BUFF_ERROR.
			}
			else if (strm.avail_in == 0 && flush <= old_flush &&
			flush != Z_FINISH) {
				strm.msg = z_errmsg[Z_NEED_DICT - (Z_BUF_ERROR)];
				return Z_BUF_ERROR;
			}

			// User must not provide more input after the first FINISH:
			if (status == FINISH_STATE && strm.avail_in != 0) {
				strm.msg = z_errmsg[Z_NEED_DICT - Z_BUF_ERROR];
				return Z_BUF_ERROR;
			}

			// Start a new block or continue the current one.
			if (strm.avail_in != 0 || lookahead != 0 ||
			(flush != Z_NO_FLUSH && status != FINISH_STATE)) {
				var bstate: int = -1;
				switch (config_table[level].func) {
				case STORED:
					bstate = deflate_stored(flush);
					break;
				case FAST:
					bstate = deflate_fast(flush);
					break;
				case SLOW:
					bstate = deflate_slow(flush);
					break;
				default:
				}

				if (bstate == FinishStarted || bstate == FinishDone) {
					status = FINISH_STATE;
				}
				if (bstate == NeedMore || bstate == FinishStarted) {
					if (strm.avail_out == 0) {
						last_flush = -1;
						// avoid BUF_ERROR next call, see above
					}
					return Z_OK;
					// If flush != Z_NO_FLUSH && avail_out == 0, the next call
					// of deflate should use the same flush parameter to make sure
					// that the flush is complete. So we don't have to output an
					// empty block here, this will be done at next call. This also
					// ensures that for a very small output buffer, we emit at most
					// one empty block.
				}

				if (bstate == BlockDone) {
					if (flush == Z_PARTIAL_FLUSH) {
						_tr_align();
					}
					else {
						// FULL_FLUSH or SYNC_FLUSH
						_tr_stored_block(0, 0, false);
						// For a full flush, this empty block will be recognized
						// as a special marker by inflate_sync().
						if (flush == Z_FULL_FLUSH) {
							//state.head[s.hash_size-1]=0;
							for (var i: int = 0; i < hash_size
							/*-1*/
							; i++)
							// forget history
							head[i] = 0;
						}
					}
					strm.flush_pending();
					if (strm.avail_out == 0) {
						last_flush = -1;
						// avoid BUF_ERROR at next call, see above
						return Z_OK;
					}
				}
			}

			if (flush != Z_FINISH) return Z_OK;
			if (noheader != 0) return Z_STREAM_END;

			// Write the zlib trailer (adler32)
			putShortMSB(int((strm.adler >>> 16)));
			putShortMSB(int((strm.adler & 0xffff)));
			strm.flush_pending();

			// If avail_out is zero, the application will call deflate again
			// to flush the rest.
			noheader = -1;
			// write the trailer only once!
			return pending != 0 ? Z_OK: Z_STREAM_END;
		}
	}
}