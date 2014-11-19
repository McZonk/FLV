#include "CMAudioCodec+FLV.h"


uint32_t CMAudioCodecGetFLVAudioCodecId(CMAudioCodecType codec)
{
	switch(codec)
	{
		case kAudioFormatMPEG4AAC :
			return 10;
			
		default:
			return 0;
	}
}
