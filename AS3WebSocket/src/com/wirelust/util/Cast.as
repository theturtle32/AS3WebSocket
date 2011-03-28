package com.wirelust.util
{
	public class Cast
	{
		public function Cast()
		{
		}

		public static function toShort(valueIn:int):int {
			// get everything except the signed bit "111 1111 1111 0001"
			var unsignedValue:Number = (valueIn & 0x7FFF);  
 
			var signedValue:Number = unsignedValue;
 
			// if the signed flag is set, flip the value
			if ((valueIn >> 15) == 1) {
				signedValue = unsignedValue - 0x8000;   // 0x800 =  32,768 (maximum 15 bit number)
			}
			return signedValue;
		}

		public static function toByte(valueIn:int):int {
			// get everything except the signed bit "1111 0001"
			var unsignedValue:Number = (valueIn & 0x7F);  
 
			var signedValue:Number = unsignedValue;
 
			// if the signed flag is set, flip the value
			var signedBit:Number = (valueIn & 0xFF)>>7;
			if (signedBit == 1) {
				signedValue = unsignedValue - 0x80;
			}
			return signedValue;
		}
	}
}