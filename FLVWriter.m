#import "FLVWriter.h"

#import <AMF/AMF.h>
#import <CoreMediaPlus/CoreMediaPlus.h>

#import "CMSampleBuffer+FLV.h"

// TODO: rename?
#define OSSwapBigToHostInt24(x) ((((x) & 0xff0000) >> 16) | ((x) & 0x00ff00) | (((x) & 0x0000ff) << 16))
#define OSSwapHostToBigInt24(x) ((((x) & 0xff0000) >> 16) | ((x) & 0x00ff00) | (((x) & 0x0000ff) << 16))

typedef struct FLVHeader {
	unsigned signature : 24;
	unsigned version : 8;
	unsigned flags : 8;
	unsigned length : 32;
} __attribute__((packed)) FLVHeader;

typedef struct FLVTag {
	unsigned type : 8;
	unsigned length : 24;
	unsigned timestamp : 24;
	unsigned timestampExtended : 8;
	unsigned stream : 24;
	char data[0];
} __attribute((packed)) FLVTag;

typedef struct FLVPreviousTag {
	unsigned length : 32;
} __attribute((packed)) FLVPreviousTag;


static inline FLVTag FLVTagMake(uint8_t type, uint32_t length, uint32_t timestamp, uint32_t stream)
{
	FLVTag tag;
	tag.type = type;
	tag.length = (uint32_t)OSSwapHostToBigInt24(length);
	tag.timestamp = (uint32_t)OSSwapHostToBigInt24(timestamp);
	tag.timestampExtended = (timestamp >> 24) & 0x7f;
	tag.stream = OSSwapHostToLittleInt32(stream);
	return tag;
}

static inline FLVPreviousTag FLVPreviousTagMake(uint32_t length)
{
	FLVPreviousTag previousTag;
	previousTag.length = OSSwapHostToBigInt32(length);
	return previousTag;
}


@interface FLVWriter ()

@property (nonatomic, strong) NSOutputStream *stream;

@property (nonatomic, assign) CMTime videoTimeOffset;
@property (nonatomic, assign) CMTime audioTimeOffset;

@property (nonatomic, assign) CMTime videoPresentationTimeStamp;

@end


@implementation FLVWriter

- (instancetype)initWithURL:(NSURL *)URL error:(NSError **)error
{
	self = [super init];
	if(self != nil)
	{
		NSOutputStream *stream = [[NSOutputStream alloc] initWithURL:URL append:NO];
		if(stream == nil)
		{
			return nil;
		}
		
		self.stream = stream;
		
		[stream open];
		
		self.videoTimeOffset = kCMTimeInvalid;
		self.audioTimeOffset = kCMTimeInvalid;
		
		self.videoPresentationTimeStamp = kCMTimeZero;
	}
	return self;
}

- (void)startWriting
{
	NSOutputStream * const stream = self.stream;
	
	// writer header
	{
		FLVHeader header;
		header.signature = OSSwapHostToBigInt24(' FLV');
		header.version = 1;
		header.flags = 1 /*| 4*/; // TODO: audio
		header.length = OSSwapHostToBigInt32(9);
		
		[stream write:(uint8_t *)&header maxLength:sizeof(header)];
		
		FLVPreviousTag previousTag = FLVPreviousTagMake(0);
		[stream write:(uint8_t *)&previousTag maxLength:sizeof(previousTag)];
	}
	
	// write metadata
	{
		NSArray *AMFObjects = @[
			@"onMetadata",
			@{
				@"width": @720,
				@"height": @480,
				@"framerate": @30,
				@"duration": @0,
				@"videocodecid": @7,
				@"videodatarate": @125,
#if 0
				// TODO: audio
				@"audiocodecid": @5,
				@"stereo": @YES,
				@"audiosamplesize": @16,
				@"audiosamplerate": @44100,
				@"audiodatarate": @15.625,
#endif
				@"filesize": @0,
			},
		];
		
		NSData *AMFData = [AMFSerialization dataWithAMFObject:AMFObjects options:AMFWritingOptionsSequence error:nil];
		
		FLVTag tag = FLVTagMake(0x12, (uint32_t)AMFData.length, 0, 0);
		
		[stream write:(uint8_t *)&tag maxLength:sizeof(tag)];
		[stream write:(uint8_t *)AMFData.bytes maxLength:AMFData.length];
		
		FLVPreviousTag previousTag = FLVPreviousTagMake(sizeof(tag) + (uint32_t)AMFData.length);
		[stream write:(uint8_t *)&previousTag maxLength:sizeof(previousTag)];
	}
}

- (void)endWriting
{
	NSOutputStream const * stream = self.stream;
	
	if(CMTIME_IS_VALID(self.videoTimeOffset))
	{
		const CMTime time = self.videoPresentationTimeStamp;
		
		const FLVTag tag = FLVTagMake(0x09, 5, (uint32_t)(CMTimeGetSeconds(time) * 1000.0), 0);
		unsigned char end[] = {
			0x17,
			0x02,
			0x00, 0x00, 0x00,
		};
		
		[stream write:(uint8_t *)&tag maxLength:sizeof(tag)];
		[stream write:(uint8_t *)end maxLength:sizeof(end)];
	
		FLVPreviousTag previousTag = FLVPreviousTagMake(sizeof(tag) + sizeof(end));
		[stream write:(uint8_t *)&previousTag maxLength:sizeof(previousTag)];
	}
	
#if 0
	if(CMTIME_IS_VALID(self.audioTimeOffset))
	{
		
	}
#endif
	
	[stream close];
}

- (BOOL)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
	CMFormatDescriptionRef const formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
	
	const CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);
	const CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
	
	NSOutputStream * const stream = self.stream;
	
	if(mediaType == kCMMediaType_Video)
	{
		CMTime time = self.videoPresentationTimeStamp;
		
		const CMTime offset = self.videoTimeOffset;
		if(CMTIME_IS_INVALID(offset))
		{
			self.videoTimeOffset = pts;
			
			NSData *startData = CFBridgingRelease(CMFormatDescriptionCopyFLVVideoStartData(formatDescription));
			if(startData != NULL)
			{
				FLVTag tag = FLVTagMake(0x09, (uint32_t)startData.length, 0, 0);
				
				[stream write:(uint8_t *)&tag maxLength:sizeof(tag)];
				[stream write:(uint8_t *)startData.bytes maxLength:startData.length];
				
				FLVPreviousTag previousTag = FLVPreviousTagMake(sizeof(tag) + (uint32_t)startData.length);
				[stream write:(uint8_t *)&previousTag maxLength:sizeof(previousTag)];
			}
		}
		else
		{
			time = CMTimeSubtract(pts, offset);
			self.videoPresentationTimeStamp = time;
		}
		
		Boolean isKeyframe = CMPSampleBufferIsKeyframe(sampleBuffer);
		
		NSData *prefixData = CFBridgingRelease(CMFormatDescriptionCopyFLVVideoPrefixData(formatDescription, isKeyframe));
		
		CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
		const size_t dataLength = CMBlockBufferGetDataLength(dataBuffer);
		
		NSMutableData *data = [NSMutableData dataWithCapacity:dataLength];
		CMPBlockBufferAppendToData(dataBuffer, (__bridge CFMutableDataRef)data);

		{
			FLVTag tag = FLVTagMake(0x09, (uint32_t)(prefixData.length + dataLength), (uint32_t)(CMTimeGetSeconds(time) * 1000), 0);
			
			[stream write:(uint8_t *)&tag maxLength:sizeof(tag)];
			[stream write:(uint8_t *)prefixData.bytes maxLength:prefixData.length];
			[stream write:(uint8_t *)data.bytes maxLength:data.length];
			
			FLVPreviousTag previousTag = FLVPreviousTagMake(sizeof(tag) + (uint32_t)(prefixData.length + data.length));
			[stream write:(uint8_t *)&previousTag maxLength:sizeof(previousTag)];
		}
	}
	else if(mediaType == kCMMediaType_Audio)
	{
		
#if 0
		CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
		
		CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
		
		NSTimeInterval time = CMTimeGetSeconds(pts);
		
		if(self.audioTimeOffset <= 0.0)
		{
			self.audioTimeOffset = time;
			time = 0;
			
			NSData *startData = CFBridgingRelease(CMFormatDescriptionCopyFLVAudioStartData(formatDescription));
			if(startData != NULL)
			{
				FLVTag tag = FLVTagMake(0x08, (uint32_t)startData.length, 0, 0);
				
				[self.data appendBytes:&tag length:sizeof(tag)];
				[self.data appendData:startData];
				
				{
					uint32_t previousTagSize = sizeof(tag) + (uint32_t)startData.length;
					uint32_t length_be = OSSwapHostToBigInt32(previousTagSize);
					[self.data appendBytes:&length_be length:sizeof(length_be)];
				}
			}
		}
		else
		{
			time -= self.audioTimeOffset;
		}
		
		uint32_t timeI = time * 1000;
		
		NSData *audioPrefixData = CFBridgingRelease(CMFormatDescriptionCopyFLVAudioPrefixData(formatDescription));
		
		CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
		const size_t length = CMBlockBufferGetDataLength(dataBuffer);
		
		FLVTag tag = FLVTagMake(0x08, (uint32_t)(audioPrefixData.length + length), timeI, 0);
		
		[self.data appendBytes:&tag length:sizeof(tag)];
		[self.data appendData:audioPrefixData];
		CMPBlockBufferAppendToData(dataBuffer, (__bridge CFMutableDataRef)self.data);
		
		{
			uint32_t previousTagSize = sizeof(tag) + (uint32_t)(audioPrefixData.length + length);
			uint32_t length_be = OSSwapHostToBigInt32(previousTagSize);
			[self.data appendBytes:&length_be length:sizeof(length_be)];
		}
		
		return;
#endif
	}
	
	return YES;
}

@end
