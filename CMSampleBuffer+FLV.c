#include "CMSampleBuffer+FLV.h"

#include <CoreMediaPlus/CoreMediaPlus.h>

#include <AudioToolbox/AudioToolbox.h>

typedef struct AACHeader {
	unsigned audioCodec : 8;
	unsigned type : 8;
} __attribute__((packed)) AACHeader;

typedef struct AVCHeader {
	unsigned videoCodec : 8;
	unsigned nalu : 8;
	unsigned time : 24;
} __attribute__((packed)) AVCHeader;


static uint8_t getFLVAudioCodec(FourCharCode mediaSubType)
{
	switch(mediaSubType) {
		case kAudioFormatLinearPCM:
			return 0x00;
			
		case kAudioFormatMPEGLayer3:
			return 0x20;
			
		case kAudioFormatALaw:
			return 0x70;
			
		case kAudioFormatULaw:
			return 0x80;
			
		case kAudioFormatMPEG4AAC:
			return 0xa0;
	}
	
	return 0;
}

static uint8_t getFLVAudioLayout(const AudioStreamBasicDescription *description)
{
	uint8_t layout = 0;
	
	if(description->mChannelsPerFrame == 2)
	{
		layout |= 0x01;
	}
	
	// assume that aac is always 16 bit
	if(description->mBitsPerChannel == 16 || description->mFormatID == kAudioFormatMPEG4AAC)
	{
		layout |= 0x02;
	}
	
	const int sampleRate = description->mSampleRate;
	if(sampleRate == 11025)
	{
		layout |= 0x04;
	}
	else if(sampleRate == 22050)
	{
		layout |= 0x08;
	}
	else if(sampleRate == 44100)
	{
		layout |= 0x0c;
	}
	
	return layout;
}

static uint8_t getFLVVideoCodec(FourCharCode mediaSubType)
{
	switch(mediaSubType)
	{
		case kCMVideoCodecType_H263:
			return 0x02;
			
		case kCMVideoCodecType_H264:
			return 0x07;
			
		case kCMVideoCodecType_MPEG4Video:
			return 0x09;
	}
	return 0;
}

static uint8_t getFLVFrametype(Boolean isKeyframe)
{
	if(isKeyframe)
	{
		return 0x10;
	}
	else
	{
		return 0x20;
	}
}


uint8_t CMFormatDescriptionGetFLVAudioHeader(CMFormatDescriptionRef formatDescription)
{
	const CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);
	if(mediaType != kCMMediaType_Audio)
	{
		return 0;
	}
	
	const FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription);
	
	const uint8_t audioCodec = getFLVAudioCodec(mediaSubType);
	
	const AudioStreamBasicDescription *description = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
	
	const uint8_t audioLayout = getFLVAudioLayout(description);
	
	return audioCodec | audioLayout;
}

CFDataRef CMFormatDescriptionCopyFLVAudioPrefixData(CMFormatDescriptionRef formatDescription)
{
	const CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);
	if(mediaType != kCMMediaType_Audio)
	{
		return NULL;
	}
	
	const FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription);
	
	const uint8_t audioHeader = CMFormatDescriptionGetFLVAudioHeader(formatDescription);
	
	if(mediaSubType == kAudioFormatMPEG4AAC)
	{
		AACHeader aacheader;
		aacheader.audioCodec = audioHeader;
		aacheader.type = 0x01;
		
		return CFDataCreate(NULL, (UInt8 *)&aacheader, sizeof(aacheader));
	}
	else
	{
		return CFDataCreate(NULL, (UInt8 *)&audioHeader, sizeof(audioHeader));
	}
}

CFDataRef CMFormatDescriptionCopyFLVAudioStartData(CMFormatDescriptionRef formatDescription)
{
	const CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);
	if(mediaType != kCMMediaType_Audio)
	{
		return NULL;
	}
	
	const FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription);
	
	const uint8_t audioHeader = CMFormatDescriptionGetFLVAudioHeader(formatDescription);
	
	if(mediaSubType == kAudioFormatMPEG4AAC)
	{
		CFDataRef extradata = NULL;
		CMPAudioFormatDescriptionCopyExtradata(NULL, formatDescription, &extradata);
		
		AACHeader aacheader;
		aacheader.audioCodec = audioHeader;
		aacheader.type = 0x00;
		
		CFMutableDataRef data = CFDataCreateMutable(NULL, sizeof(aacheader) + CFDataGetLength(extradata));
		
		CFDataAppendBytes(data, (UInt8 *)&aacheader, sizeof(aacheader));
		CFDataAppendBytes(data, CFDataGetBytePtr(extradata), CFDataGetLength(extradata));
		
		CFRelease(extradata);
		
		return data;
	}
	else
	{
		return NULL;
	}
}

CFDataRef CMFormatDescriptionCopyFLVAudioFinishData(CMFormatDescriptionRef formatDescription)
{
	return NULL;
}

uint8_t CMFormatDescriptionGetFLVVideoHeader(CMFormatDescriptionRef formatDescription, Boolean isKeyframe)
{
	const CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);
	if(mediaType != kCMMediaType_Video)
	{
		return 0;
	}
	
	const FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription);
	
	const uint8_t videoCodec = getFLVVideoCodec(mediaSubType);
	if(videoCodec == 0)
	{
		return 0;
	}
	
	const uint8_t frameType = getFLVFrametype(isKeyframe);
	
	return videoCodec | frameType;
}

CFDataRef CMFormatDescriptionCopyFLVVideoPrefixData(CMFormatDescriptionRef formatDescription, Boolean isKeyframe)
{
	const CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);
	if(mediaType != kCMMediaType_Video)
	{
		return NULL;
	}
	
	const FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription);
	
	const uint8_t videoHeader = CMFormatDescriptionGetFLVVideoHeader(formatDescription, isKeyframe);
	
	if(mediaSubType == kCMVideoCodecType_H264 || mediaSubType == kCMVideoCodecType_H264)
	{
		AVCHeader avcheader;
		avcheader.videoCodec = videoHeader;
		avcheader.nalu = 0x01;
		avcheader.time = 0; // TODO
		
		return CFDataCreate(NULL, (UInt8 *)&avcheader, sizeof(avcheader));
	}
	else
	{
		return CFDataCreate(NULL, (UInt8 *)&videoHeader, sizeof(videoHeader));
	}
}

Boolean CMFormatDescriptionHasFLVVideoStartData(CMFormatDescriptionRef formatDescription)
{
	const CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);
	if(mediaType != kCMMediaType_Video)
	{
		return false;
	}

	const FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription);
	if(mediaSubType == kCMVideoCodecType_H264 || mediaSubType == kCMVideoCodecType_MPEG4Video)
	{
		return true;
	}
	
	return false;
}

CFDataRef CMFormatDescriptionCopyFLVVideoStartData(CMFormatDescriptionRef formatDescription)
{
	const CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);
	if(mediaType != kCMMediaType_Video)
	{
		return NULL;
	}
	
	const FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription);
	
	const uint8_t videoHeader = CMFormatDescriptionGetFLVVideoHeader(formatDescription, true);
	
	if(mediaSubType == kCMVideoCodecType_H264 || mediaSubType == kCMVideoCodecType_MPEG4Video)
	{
		CFDataRef extradata = NULL;
		CMPVideoFormatDescriptionCopyExtradata(NULL, formatDescription, &extradata);
		
		AVCHeader avcheader;
		avcheader.videoCodec = videoHeader;
		avcheader.nalu = 0x00;
		avcheader.time = 0; // TODO
		
		CFMutableDataRef data = CFDataCreateMutable(NULL, sizeof(avcheader) + CFDataGetLength(extradata));
		
		CFDataAppendBytes(data, (UInt8 *)&avcheader, sizeof(avcheader));
		CFDataAppendBytes(data, CFDataGetBytePtr(extradata), CFDataGetLength(extradata));
		
		CFRelease(extradata);
		
		return data;
	}
	else
	{
		return NULL;
	}
	
}

Boolean CMFormatDescriptionHasFLVVideoFinishData(CMFormatDescriptionRef formatDescription)
{
	const CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);
	if(mediaType != kCMMediaType_Video)
	{
		return false;
	}
	
	const FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription);
	if(mediaSubType == kCMVideoCodecType_H264 || mediaSubType == kCMVideoCodecType_MPEG4Video)
	{
		return true;
	}
	
	return false;
}

CFDataRef CMFormatDescriptionCopyFLVVideoFinishData(CMFormatDescriptionRef formatDescription)
{
	const CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);
	if(mediaType != kCMMediaType_Video)
	{
		return NULL;
	}
	
	const FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription);
	
	const uint8_t videoHeader = CMFormatDescriptionGetFLVVideoHeader(formatDescription, true);
	
	if(mediaSubType == kCMVideoCodecType_H264 || mediaSubType == kCMVideoCodecType_H264)
	{
		AVCHeader avcheader;
		avcheader.videoCodec = videoHeader;
		avcheader.nalu = 0x02;
		avcheader.time = 0; // TODO
		
		return CFDataCreate(NULL, (UInt8 *)&avcheader, sizeof(avcheader));
	}
	else
	{
		return NULL;
	}
}
