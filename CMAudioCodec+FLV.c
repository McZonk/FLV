#include "CMAudioCodec+FLV.h"


uint32_t CMAudioCodecGetFLVAudioCodecId(CMAudioCodecType codec)
{
	switch(codec)
	{
		case kAudioFormatMPEG4AAC :
			return 5;
			
		default:
			return 0;
	}
}
