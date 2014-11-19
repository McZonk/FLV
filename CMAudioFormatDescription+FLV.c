#include "CMAudioFormatDescription+FLV.h"

#include <CoreMediaPlus/CoreMediaPlus.h>
#include "CMAudioCodec+FLV.h"


Float64 CMAudioFormatDescriptionGetFLVDataRate(CMAudioFormatDescriptionRef audioFormatDescription)
{
	CFNumberRef bitRateValue = CMFormatDescriptionGetExtension(audioFormatDescription, kCMPFormatDescriptionExtension_BitRate);
	if(bitRateValue == NULL)
	{
		return 0.0;
	}
	
	Float64 bitRate = 0.0;
	CFNumberGetValue(bitRateValue, kCFNumberFloat64Type, &bitRate);
	return bitRate / 1024.0;
}

uint32_t CMAudioFormatDescriptionGetFLVCodec(CMAudioFormatDescriptionRef audioFormatDescription)
{
	const AudioStreamBasicDescription *audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDescription);
	if(audioStreamBasicDescription == NULL)
	{
		return 0;
	}
	
	return CMAudioCodecGetFLVAudioCodecId(audioStreamBasicDescription->mFormatID);
}
