#include "CMVideoFormatDescription+FLV.h"

#include <CoreMediaPlus/CoreMediaPlus.h>
#include "CMVideoCodec+FLV.h"


Float64 CMVideoFormatDescriptionGetFLVFrameRate(CMVideoFormatDescriptionRef videoFormatDescription)
{
	CFDictionaryRef videoFrameRateDictionary = CMFormatDescriptionGetExtension(videoFormatDescription, kCMPFormatDescriptionExtension_FrameRate);
	if(videoFrameRateDictionary == NULL)
	{
		return 0.0;
	}
	
	CMTime time = CMTimeMakeFromDictionary(videoFrameRateDictionary);
	if(CMTIME_IS_INVALID(time))
	{
		return 0.0;
	}
	
	return (Float64)time.timescale / (Float64)time.value;
}

Float64 CMVideoFormatDescriptionGetFLVDataRate(CMVideoFormatDescriptionRef videoFormatDescription)
{
	CFNumberRef bitRateValue = CMFormatDescriptionGetExtension(videoFormatDescription, kCMPFormatDescriptionExtension_BitRate);
	if(bitRateValue == NULL)
	{
		return 0.0;
	}
	
	Float64 bitRate = 0.0;
	CFNumberGetValue(bitRateValue, kCFNumberFloat64Type, &bitRate);
	return bitRate / 1024.0;
}

uint32_t CMVideoFormatDescriptionGetFLVCodec(CMVideoFormatDescriptionRef videoFormatDescription)
{
	CMVideoCodecType videoCodec = CMVideoFormatDescriptionGetCodecType(videoFormatDescription);
	return CMVideoCodecGetFLVVideoCodecId(videoCodec);
}
