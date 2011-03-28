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
final public class JZlib{
  public var version:String="1.0.2";
  public static function get version():String {return version;}

  // compression levels
  static public var Z_NO_COMPRESSION:int=0;
  static public var Z_BEST_SPEED:int=1;
  static public var Z_BEST_COMPRESSION:int=9;
  static public var Z_DEFAULT_COMPRESSION:int=(-1);

  // compression method
  static public var Z_DEFLATED: int = 8;
  
  // compression strategy
  static public var Z_FILTERED:int=1;
  static public var Z_HUFFMAN_ONLY:int=2;
  static public var Z_DEFAULT_STRATEGY:int=0;

  static public var Z_NO_FLUSH:int=0;
  static public var Z_PARTIAL_FLUSH:int=1;
  static public var Z_SYNC_FLUSH:int=2;
  static public var Z_FULL_FLUSH:int=3;
  static public var Z_FINISH:int=4;

  static public var Z_OK:int=0;
  static public var Z_STREAM_END:int=1;
  static public var Z_NEED_DICT:int=2;
  static public var Z_ERRNO:int=-1;
  static public var Z_STREAM_ERROR:int=-2;
  static public var Z_DATA_ERROR:int=-3;
  static public var Z_MEM_ERROR:int=-4;
  static public var Z_BUF_ERROR:int=-5;
  static public var Z_VERSION_ERROR:int=-6;
}
}