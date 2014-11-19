#import "NSMutableDictionary+FLVMetadata.h"

#import "CMAudioFormatDescription+FLV.h"
#import "CMVideoFormatDescription+FLV.h"


@implementation NSMutableDictionary (FLVMetadata)

+ (instancetype)FLVMetadataWithVideoFormatDescription:(CMVideoFormatDescriptionRef)videoFormatDescription audioFormatDescription:(CMAudioFormatDescriptionRef)audioFormatDescription error:(NSError **)error
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
	
	const uint32_t videoCodec = CMVideoFormatDescriptionGetFLVCodec(videoFormatDescription);
	if(videoCodec == 0)
	{
		// TODO: error handling
		NSLog(@"%s:%d:Error: Invalid videoCodec", __FUNCTION__, __LINE__);
		return nil;
	}
	metadata[@"videocodecid"] = @(videoCodec);
	
	const Float64 videoFrameRate = CMVideoFormatDescriptionGetFLVFrameRate(videoFormatDescription);
	metadata[@"framerate"] = @(videoFrameRate);
	
	const Float64 videoDataRate = CMVideoFormatDescriptionGetFLVDataRate(videoFormatDescription);
	metadata[@"videodatarate"] = @(videoDataRate);
	
	
	const uint32_t audioCodec = CMAudioFormatDescriptionGetFLVCodec(audioFormatDescription);
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

	const Float64 audioDataRate = CMAudioFormatDescriptionGetFLVDataRate(audioFormatDescription);
	metadata[@"audiodatarate"] = @(audioDataRate);
	
	return metadata;
}

@end
