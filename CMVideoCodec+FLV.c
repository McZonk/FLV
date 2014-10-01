#include "CMVideoCodec+FLV.h"


uint32_t CMVideoCodecGetFLVVideoCodecId(CMVideoCodecType codec)
{
	switch(codec)
	{
		case kCMVideoCodecType_H264 :
			return 7;
		
		default:
			return 0;
	}
}

// videocodecid