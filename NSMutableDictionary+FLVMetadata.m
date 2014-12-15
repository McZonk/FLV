#import "NSMutableDictionary+FLVMetadata.h"

#import <AudioToolbox/AudioToolbox.h>
#import <VideoToolbox/VideoToolbox.h>
#import "CMAudioCodec+FLV.h"
#import "CMVideoCodec+FLV.h"


@implementation NSMutableDictionary (FLVMetadata)

+ (instancetype)FLVMetadataWithVideoFormatDescription:(CMVideoFormatDescriptionRef)videoFormatDescription videoEncoderSettings:(NSDictionary *)videoEncoderSettings audioFormatDescription:(CMAudioFormatDescriptionRef)audioFormatDescription audioEncoderSettings:(NSDictionary *)audioEncoderSettings error:(NSError **)error
{
	NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
	metadata[@"duration"] = @0;
	metadata[@"filesize"] = @0;
	
	const CMVideoDimensions videoDimensions = CMVideoFormatDescriptionGetDimensions(videoFormatDescription);
	if(videoDimensions.width <= 0 || videoDimensions.height <= 0)
	{
		// TODO: error handling
		NSLog(@"%s:%d:Error: Invalid videoDimensions", __FUNCTION__, __LINE__);
		return nil;
	}
	metadata[@"width"] = @(videoDimensions.width);
	metadata[@"height"] = @(videoDimensions.height);
	
	const uint32_t videoCodec = CMVideoCodecGetFLVVideoCodecId(CMFormatDescriptionGetMediaSubType(videoFormatDescription));
	if(videoCodec == 0)
	{
		// TODO: error handling
		NSLog(@"%s:%d:Error: Invalid videoCodec", __FUNCTION__, __LINE__);
		return nil;
	}
	metadata[@"videocodecid"] = @(videoCodec);

	NSNumber * const videoFrameRate = videoEncoderSettings[(__bridge NSString *)kVTCompressionPropertyKey_ExpectedFrameRate];
	if([videoFrameRate isKindOfClass:NSNumber.class])
	{
		metadata[@"framerate"] = videoFrameRate;
	}
	
//	NSNumber * const videoConstantBitRate = audioEncoderSettings[(__bridge NSString *)kVTCompressionPropertyKey_DataRateLimits];
	NSNumber * const videoBitRate = videoEncoderSettings[(__bridge NSString *)kVTCompressionPropertyKey_AverageBitRate];
	if([videoBitRate isKindOfClass:NSNumber.class])
	{
		const Float64 videoDataRate = videoBitRate.doubleValue / 1024.0;
		metadata[@"videodatarate"] = @(videoDataRate);
	}
	
	const uint32_t audioCodec = CMAudioCodecGetFLVAudioCodecId(CMFormatDescriptionGetMediaSubType(audioFormatDescription));
	if(audioCodec == 0)
	{
		// TODO: error handling
		NSLog(@"%s:%d:Error: Invalid audioCodec", __FUNCTION__, __LINE__);
		return nil;
	}
	metadata[@"audiocodecid"] = @(audioCodec);
	
	const AudioStreamBasicDescription *audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDescription);
	if(audioStreamBasicDescription == NULL)
	{
		// TODO: error handling
		NSLog(@"%s:%d:Error: Invalid audioStreamBasicDescription", __FUNCTION__, __LINE__);
		return nil;
	}
	
	const Float64 audioSampleRate = audioStreamBasicDescription->mSampleRate;
	metadata[@"audiosamplerate"] = @(audioSampleRate);
	
	const UInt32 audioSampleSize = audioStreamBasicDescription->mBitsPerChannel;
	metadata[@"audiosamplesize"] = @(audioSampleSize);

	const UInt32 audioChannels = audioStreamBasicDescription->mChannelsPerFrame;
	metadata[@"stereo"] = audioChannels == 2 ? @YES : @NO;
	
	NSNumber * const audioBitRate = audioEncoderSettings[@(kAudioConverterEncodeBitRate)];
	if([audioBitRate isKindOfClass:NSNumber.class])
	{
		const Float64 audioDataRate = audioBitRate.doubleValue / 1024.0;
		metadata[@"audiodatarate"] = @(audioDataRate);
	}

	return metadata;
}

@end
