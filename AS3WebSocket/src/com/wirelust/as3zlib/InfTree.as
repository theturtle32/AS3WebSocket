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
final internal class InfTree{

	static private const MANY:int=1440;
	
	static private const Z_OK:int=0;
	static private const Z_STREAM_END:int=1;
	static private const Z_NEED_DICT:int=2;
	static private const Z_ERRNO:int=-1;
	static private const Z_STREAM_ERROR:int=-2;
	static private const Z_DATA_ERROR:int=-3;
	static private const Z_MEM_ERROR:int=-4;
	static private const Z_BUF_ERROR:int=-5;
	static private const Z_VERSION_ERROR:int=-6;
	
	static private const fixed_bl:int= 9;
	static private const fixed_bd:int= 5;
	
	static public const fixed_tl:Array = new Array(
		96,7,256, 0,8,80, 0,8,16, 84,8,115,
		82,7,31, 0,8,112, 0,8,48, 0,9,192,
		80,7,10, 0,8,96, 0,8,32, 0,9,160,
		0,8,0, 0,8,128, 0,8,64, 0,9,224,
		80,7,6, 0,8,88, 0,8,24, 0,9,144,
		83,7,59, 0,8,120, 0,8,56, 0,9,208,
		81,7,17, 0,8,104, 0,8,40, 0,9,176,
		0,8,8, 0,8,136, 0,8,72, 0,9,240,
		80,7,4, 0,8,84, 0,8,20, 85,8,227,
		83,7,43, 0,8,116, 0,8,52, 0,9,200,
		81,7,13, 0,8,100, 0,8,36, 0,9,168,
		0,8,4, 0,8,132, 0,8,68, 0,9,232,
		80,7,8, 0,8,92, 0,8,28, 0,9,152,
		84,7,83, 0,8,124, 0,8,60, 0,9,216,
		82,7,23, 0,8,108, 0,8,44, 0,9,184,
		0,8,12, 0,8,140, 0,8,76, 0,9,248,
		80,7,3, 0,8,82, 0,8,18, 85,8,163,
		83,7,35, 0,8,114, 0,8,50, 0,9,196,
		81,7,11, 0,8,98, 0,8,34, 0,9,164,
		0,8,2, 0,8,130, 0,8,66, 0,9,228,
		80,7,7, 0,8,90, 0,8,26, 0,9,148,
		84,7,67, 0,8,122, 0,8,58, 0,9,212,
		82,7,19, 0,8,106, 0,8,42, 0,9,180,
		0,8,10, 0,8,138, 0,8,74, 0,9,244,
		80,7,5, 0,8,86, 0,8,22, 192,8,0,
		83,7,51, 0,8,118, 0,8,54, 0,9,204,
		81,7,15, 0,8,102, 0,8,38, 0,9,172,
		0,8,6, 0,8,134, 0,8,70, 0,9,236,
		80,7,9, 0,8,94, 0,8,30, 0,9,156,
		84,7,99, 0,8,126, 0,8,62, 0,9,220,
		82,7,27, 0,8,110, 0,8,46, 0,9,188,
		0,8,14, 0,8,142, 0,8,78, 0,9,252,
		96,7,256, 0,8,81, 0,8,17, 85,8,131,
		82,7,31, 0,8,113, 0,8,49, 0,9,194,
		80,7,10, 0,8,97, 0,8,33, 0,9,162,
		0,8,1, 0,8,129, 0,8,65, 0,9,226,
		80,7,6, 0,8,89, 0,8,25, 0,9,146,
		83,7,59, 0,8,121, 0,8,57, 0,9,210,
		81,7,17, 0,8,105, 0,8,41, 0,9,178,
		0,8,9, 0,8,137, 0,8,73, 0,9,242,
		80,7,4, 0,8,85, 0,8,21, 80,8,258,
		83,7,43, 0,8,117, 0,8,53, 0,9,202,
		81,7,13, 0,8,101, 0,8,37, 0,9,170,
		0,8,5, 0,8,133, 0,8,69, 0,9,234,
		80,7,8, 0,8,93, 0,8,29, 0,9,154,
		84,7,83, 0,8,125, 0,8,61, 0,9,218,
		82,7,23, 0,8,109, 0,8,45, 0,9,186,
		0,8,13, 0,8,141, 0,8,77, 0,9,250,
		80,7,3, 0,8,83, 0,8,19, 85,8,195,
		83,7,35, 0,8,115, 0,8,51, 0,9,198,
		81,7,11, 0,8,99, 0,8,35, 0,9,166,
		0,8,3, 0,8,131, 0,8,67, 0,9,230,
		80,7,7, 0,8,91, 0,8,27, 0,9,150,
		84,7,67, 0,8,123, 0,8,59, 0,9,214,
		82,7,19, 0,8,107, 0,8,43, 0,9,182,
		0,8,11, 0,8,139, 0,8,75, 0,9,246,
		80,7,5, 0,8,87, 0,8,23, 192,8,0,
		83,7,51, 0,8,119, 0,8,55, 0,9,206,
		81,7,15, 0,8,103, 0,8,39, 0,9,174,
		0,8,7, 0,8,135, 0,8,71, 0,9,238,
		80,7,9, 0,8,95, 0,8,31, 0,9,158,
		84,7,99, 0,8,127, 0,8,63, 0,9,222,
		82,7,27, 0,8,111, 0,8,47, 0,9,190,
		0,8,15, 0,8,143, 0,8,79, 0,9,254,
		96,7,256, 0,8,80, 0,8,16, 84,8,115,
		82,7,31, 0,8,112, 0,8,48, 0,9,193,
		
		80,7,10, 0,8,96, 0,8,32, 0,9,161,
		0,8,0, 0,8,128, 0,8,64, 0,9,225,
		80,7,6, 0,8,88, 0,8,24, 0,9,145,
		83,7,59, 0,8,120, 0,8,56, 0,9,209,
		81,7,17, 0,8,104, 0,8,40, 0,9,177,
		0,8,8, 0,8,136, 0,8,72, 0,9,241,
		80,7,4, 0,8,84, 0,8,20, 85,8,227,
		83,7,43, 0,8,116, 0,8,52, 0,9,201,
		81,7,13, 0,8,100, 0,8,36, 0,9,169,
		0,8,4, 0,8,132, 0,8,68, 0,9,233,
		80,7,8, 0,8,92, 0,8,28, 0,9,153,
		84,7,83, 0,8,124, 0,8,60, 0,9,217,
		82,7,23, 0,8,108, 0,8,44, 0,9,185,
		0,8,12, 0,8,140, 0,8,76, 0,9,249,
		80,7,3, 0,8,82, 0,8,18, 85,8,163,
		83,7,35, 0,8,114, 0,8,50, 0,9,197,
		81,7,11, 0,8,98, 0,8,34, 0,9,165,
		0,8,2, 0,8,130, 0,8,66, 0,9,229,
		80,7,7, 0,8,90, 0,8,26, 0,9,149,
		84,7,67, 0,8,122, 0,8,58, 0,9,213,
		82,7,19, 0,8,106, 0,8,42, 0,9,181,
		0,8,10, 0,8,138, 0,8,74, 0,9,245,
		80,7,5, 0,8,86, 0,8,22, 192,8,0,
		83,7,51, 0,8,118, 0,8,54, 0,9,205,
		81,7,15, 0,8,102, 0,8,38, 0,9,173,
		0,8,6, 0,8,134, 0,8,70, 0,9,237,
		80,7,9, 0,8,94, 0,8,30, 0,9,157,
		84,7,99, 0,8,126, 0,8,62, 0,9,221,
		82,7,27, 0,8,110, 0,8,46, 0,9,189,
		0,8,14, 0,8,142, 0,8,78, 0,9,253,
		96,7,256, 0,8,81, 0,8,17, 85,8,131,
		82,7,31, 0,8,113, 0,8,49, 0,9,195,
		80,7,10, 0,8,97, 0,8,33, 0,9,163,
		0,8,1, 0,8,129, 0,8,65, 0,9,227,
		80,7,6, 0,8,89, 0,8,25, 0,9,147,
		83,7,59, 0,8,121, 0,8,57, 0,9,211,
		81,7,17, 0,8,105, 0,8,41, 0,9,179,
		0,8,9, 0,8,137, 0,8,73, 0,9,243,
		80,7,4, 0,8,85, 0,8,21, 80,8,258,
		83,7,43, 0,8,117, 0,8,53, 0,9,203,
		81,7,13, 0,8,101, 0,8,37, 0,9,171,
		0,8,5, 0,8,133, 0,8,69, 0,9,235,
		80,7,8, 0,8,93, 0,8,29, 0,9,155,
		84,7,83, 0,8,125, 0,8,61, 0,9,219,
		82,7,23, 0,8,109, 0,8,45, 0,9,187,
		0,8,13, 0,8,141, 0,8,77, 0,9,251,
		80,7,3, 0,8,83, 0,8,19, 85,8,195,
		83,7,35, 0,8,115, 0,8,51, 0,9,199,
		81,7,11, 0,8,99, 0,8,35, 0,9,167,
		0,8,3, 0,8,131, 0,8,67, 0,9,231,
		80,7,7, 0,8,91, 0,8,27, 0,9,151,
		84,7,67, 0,8,123, 0,8,59, 0,9,215,
		82,7,19, 0,8,107, 0,8,43, 0,9,183,
		0,8,11, 0,8,139, 0,8,75, 0,9,247,
		80,7,5, 0,8,87, 0,8,23, 192,8,0,
		83,7,51, 0,8,119, 0,8,55, 0,9,207,
		81,7,15, 0,8,103, 0,8,39, 0,9,175,
		0,8,7, 0,8,135, 0,8,71, 0,9,239,
		80,7,9, 0,8,95, 0,8,31, 0,9,159,
		84,7,99, 0,8,127, 0,8,63, 0,9,223,
		82,7,27, 0,8,111, 0,8,47, 0,9,191,
		0,8,15, 0,8,143, 0,8,79, 0,9,255
	);

	static public const fixed_td:Array = new Array(
		80,5,1, 87,5,257, 83,5,17, 91,5,4097,
		81,5,5, 89,5,1025, 85,5,65, 93,5,16385,
		80,5,3, 88,5,513, 84,5,33, 92,5,8193,
		82,5,9, 90,5,2049, 86,5,129, 192,5,24577,
		80,5,2, 87,5,385, 83,5,25, 91,5,6145,
		81,5,7, 89,5,1537, 85,5,97, 93,5,24577,
		80,5,4, 88,5,769, 84,5,49, 92,5,12289,
		82,5,13, 90,5,3073, 86,5,193, 192,5,24577
	);

	// Tables for deflate from PKZIP's appnote.txt.
	// Copy lengths for literal codes 257..285
	static public const cplens:Array= new Array(
		3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
		35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, 0, 0
	);

	// see note #13 above about 258
	// Extra bits for literal codes 257..285
	static public const cplext:Array = new Array(
		0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
		3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0, 112, 112// 112==invalid
	);

	// Copy offsets for distance codes 0..29
	static public const cpdist:Array = new Array( 
		1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
		257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
		8193, 12289, 16385, 24577
	);

	// Extra bits for distance codes
	static public const cpdext:Array = new Array(
		0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
		7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
		12, 12, 13, 13
	)

	// If BMAX needs to be larger than 16, then h and x[] should be uLong.
	static public const BMAX:int=15;         // maximum bit length of any code

	public var hn:Array= null;  // hufts used in space
	public var v:Array= null;   // work area for huft_build 
	public var c:Array= null;   // bit length count table
	public var r:Array= null;   // table entry for structure assignment
	public var u:Array= null;   // table stack
	public var x:Array= null;   // bit offsets, then code stack

	private function huft_build(b:Array, // code lengths in bits (all assumed <= BMAX)
		bindex:int, 
		n:int,   // number of codes (assumed <= 288)
		s:int,   // number of simple-valued codes (0..s-1)
		d:Array, // list of base values for non-simple codes
		e:Array, // list of extra bits for non-simple codes
		t:Array, // result: starting table
		m:Array, // maximum lookup bits, returns actual
		hp:Array,// space for trees
		hn:Array,// hufts used in space
		v:Array  // working area: values in order of bit length
		):int {
			
		// Given a list of code lengths and a maximum table size, make a set of
		// tables to decode that set of codes.  Return Z_OK on success, Z_BUF_ERROR
		// if the given code set is incomplete (the tables are still built in this
		// case), Z_DATA_ERROR if the input is invalid (an over-subscribed set of
		// lengths), or Z_MEM_ERROR if not enough memory.

		var a:int;                       // counter for codes of length k
		var f:int;                       // i repeats in table every f entries
		var g:int;                       // maximum code length
		var h:int;                       // table level
		var i:int;                       // counter, current code
		var j:int;                       // counter
		var k:int;                       // number of bits in current code
		var l:int;                       // bits per table (returned in m)
		var mask:int;                    // (1 << w) - 1, to avoid cc -O bug on HP
		var p:int;                       // pointer into c[], b[], or v[]
		var q:int;                       // points to current table
		var w:int;                       // bits before this table == (l * h)
		var xp:int;                      // pointer into x
		var y:int;                       // number of dummy codes added
		var z:int;                       // number of entries in current table

		// Generate counts for each bit length

		p = 0; i = n;
		do {
			c[b[bindex+p]]++; p++; i--;   // assume all entries <= BMAX
		}while(i!=0);

		if (c[0] == n) {                // null input--all zero length codes
			t[0] = -1;
			m[0] = 0;
			return Z_OK;
		}

		// Find minimum and maximum length, bound *m by those
		l = m[0];
		for (j = 1; j <= BMAX; j++) {
			if(c[j]!=0) {
				break;
			}
		}
		k = j;                        // minimum code length
		
		if (l < j) {
			l = j;
		}
		for (i = BMAX; i!=0; i--) {
			if(c[i]!=0) {
				break;
			}
		}
		g = i;                        // maximum code length

		if (l > i) {
			l = i;
		}
		m[0] = l;

  // Adjust last length count to fill out codes, if needed
  for (y = 1<< j; j < i; j++, y <<= 1){
    if ((y -= c[j]) < 0){
      return Z_DATA_ERROR;
    }
  }
  if ((y -= c[i]) < 0){
    return Z_DATA_ERROR;
  }
  c[i] += y;

  // Generate starting offsets into the value table for each length
  x[1] = j = 0;
  p = 1;  xp = 2;
  while (--i!=0) {                 // note that i == g from above
    x[xp] = (j += c[p]);
    xp++;
    p++;
  }

  // Make a table of values in order of bit lengths
  i = 0; p = 0;
  do {
    if ((j = b[bindex+p]) != 0){
      v[x[j]++] = i;
    }
    p++;
  }
  while (++i < n);
  n = x[g];                     // set n to length of v

  // Generate the Huffman codes and for each, make the table entries
  x[0] = i = 0;                 // first Huffman code is zero
  p = 0;                        // grab values in bit order
  h = -1;                       // no tables yet--level -1
  w = -l;                       // bits decoded == (l * h)
  u[0] = 0;                     // just to keep compilers happy
  q = 0;                        // ditto
  z = 0;                        // ditto

  // go through the bit lengths (k already is bits in shortest code)
  for (; k <= g; k++){
    a = c[k];
    while (a--!=0){
  // here i is the Huffman code of length k bits for value *p
  // make tables up to required level
      while (k > w + l){
        h++;
        w += l;                 // previous table always l bits
    // compute minimum size table less than or equal to l bits
        z = g - w;
        z = (z > l) ? l : z;        // table size upper limit
        if((f=1<<(j=k-w))>a+1){     // try a k-w bit table
                                    // too few codes for k-w bit table
          f -= a + 1;               // deduct codes from patterns left
          xp = k;
          if(j < z){
            while (++j < z){        // try smaller tables up to z bits
              if((f <<= 1) <= c[++xp])
                break;              // enough codes to use up j bits
              f -= c[xp];           // else deduct codes from patterns
            }
      }
        }
        z = 1<< j;                 // table entries for j-bit table

    // allocate new table
        if (hn[0] + z > MANY){       // (note: doesn't matter for fixed)
          return Z_DATA_ERROR;       // overflow of MANY
        }
        u[h] = q = /*hp+*/ hn[0];   // DEBUG
        hn[0] += z;

    // connect to last table, if there is one
    if(h!=0){
          x[h]=i;           // save pattern for backing up
          r[0]=j;     // bits in this table
          r[1]=l;     // bits to dump before this table
          j=i>>>(w - l);
          r[2] = int((q - u[h-1] - j));               // offset to this table
          System.arrayCopy(r, 0, hp, (u[h-1]+j)*3, 3); // connect to last table
        }
        else{
          t[0] = q;               // first table is returned result
    }
      }

  // set up table entry in r
      r[1] = (k - w);
      if (p >= n){
        r[0] = 128+ 64;      // out of values--invalid code
  }
      else if (v[p] < s){
        r[0] = (v[p] < 256 ? 0 : 32 + 64);  // 256 is end-of-block
        r[2] = v[p++];          // simple code is just the value
      }
      else{
        r[0]=(e[v[p]-s]+16+64); // non-simple--look up in lists
        r[2]=d[v[p++] - s];
      }

      // fill code-like entries with r
      f=1<<(k-w);
      for (j=i>>>w;j<z;j+=f){
        System.arrayCopy(r, 0, hp, (q+j)*3, 3);
  }

  // backwards increment the k-bit code i
      for (j = 1<< (k - 1); (i & j)!=0; j >>>= 1){
        i ^= j;
  }
      i ^= j;

  // backup over finished tables
      mask = (1<< w) - 1;      // needed on HP, cc -O bug
      while ((i & mask) != x[h]){
        h--;                    // don't need to update q
        w -= l;
        mask = (1<< w) - 1;
      }
    }
  }
  // Return Z_BUF_ERROR if we were given an incomplete table
  return y != 0&& g != 1? Z_BUF_ERROR : Z_OK;
}

public function inflate_trees_bits(c:Array,  // 19 code lengths
                       bb:Array, // bits tree desired/actual depth
                       tb:Array, // bits tree result
                       hp:Array, // space for trees
                       z:ZStream // for messages
                       ):int {
  var result:int;
  initWorkArea(19);
  hn[0]=0;
  result = huft_build(c, 0, 19, 19, null, null, tb, bb, hp, hn, v);

  if(result == Z_DATA_ERROR){
    z.msg = "oversubscribed dynamic bit lengths tree";
  }
  else if(result == Z_BUF_ERROR || bb[0] == 0){
    z.msg = "incomplete dynamic bit lengths tree";
    result = Z_DATA_ERROR;
  }
  return result;
}

public function inflate_trees_dynamic(nl:int,   // number of literal/length codes
                          nd:int,   // number of distance codes
                          c:Array,  // that many (total) code lengths
                          bl:Array, // literal desired/actual bit depth
                          bd:Array, // distance desired/actual bit depth 
                          tl:Array, // literal/length tree result
                          td:Array, // distance tree result
                          hp:Array, // space for trees
                          z:ZStream // for messages
                          ):int {
  var result:int;

  // build literal/length tree
  initWorkArea(288);
  hn[0]=0;
  result = huft_build(c, 0, nl, 257, cplens, cplext, tl, bl, hp, hn, v);
  if (result != Z_OK || bl[0] == 0){
    if(result == Z_DATA_ERROR){
      z.msg = "oversubscribed literal/length tree";
    }
    else if (result != Z_MEM_ERROR){
      z.msg = "incomplete literal/length tree";
      result = Z_DATA_ERROR;
    }
    return result;
  }

  // build distance tree
  initWorkArea(288);
  result = huft_build(c, nl, nd, 0, cpdist, cpdext, td, bd, hp, hn, v);

	if (result != Z_OK || (bd[0] == 0&& nl > 257)){
		if (result == Z_DATA_ERROR){
			z.msg = "oversubscribed distance tree";
		} else if (result == Z_BUF_ERROR) {
			z.msg = "incomplete distance tree";
			result = Z_DATA_ERROR;
		} else if (result != Z_MEM_ERROR){
			z.msg = "empty distance tree with lengths";
			result = Z_DATA_ERROR;
		}
		return result;
	}

  return Z_OK;
}

	public static function inflate_trees_fixed(bl:Array,  //literal desired/actual bit depth
		bd:Array,  //distance desired/actual bit depth
		tl:Array,//literal/length tree result
		td:Array,//distance tree result 
		z:ZStream  //for memory allocation
		):int {
		bl[0]=fixed_bl;
		bd[0]=fixed_bd;
		tl[0]=fixed_tl;
		td[0]=fixed_td;
		return Z_OK;
	}

	private function initWorkArea(vsize:int):void {
		var i:int;
		if(hn==null){
			hn=new Array();
			v=new Array();
			c=new Array();
			r=new Array();
			u=new Array();
			x=new Array();
		}
		if(v.length<vsize) {
			v=new Array(); 
		}
		for(i=0; i<vsize; i++) {
			v[i]=0;
		}
		for(i=0; i<BMAX+1; i++) {
			c[i]=0;
		}
		for(i=0; i<3; i++) {
			r[i]=0;
		}
		//  for(int i=0; i<BMAX; i++){u[i]=0;}
		System.arrayCopy(c, 0, u, 0, BMAX);
		//  for(int i=0; i<BMAX+1; i++){x[i]=0;}
		System.arrayCopy(c, 0, x, 0, BMAX+1);
	}
}
}