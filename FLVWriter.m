#import "FLVWriter.h"

#import <AMF/AMF.h>
#import <CoreMediaPlus/CoreMediaPlus.h>

#import "CMSampleBuffer+FLV.h"
#import "NSMutableDictionary+FLVMetadata.h"


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
@property (nonatomic, assign) CMTime audioPresentationTimeStamp;

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
		
		self.videoTimeOffset = kCMTimeInvalid;
		self.audioTimeOffset = kCMTimeInvalid;
		
		self.videoPresentationTimeStamp = kCMTimeZero;
		self.audioPresentationTimeStamp = kCMTimeZero;
	}
	return self;
}

- (BOOL)startWritingWithError:(NSError **)error
{
	NSDictionary *metadata = [NSMutableDictionary FLVMetadataWithVideoFormatDescription:self.videoFormatDescription audioFormatDescription:self.audioFormatDescription error:error];
	if(metadata == nil)
	{
		return NO;
	}

	NSOutputStream * const stream = self.stream;
	
	[stream open];

	// writer header
	{
		FLVHeader header;
		header.signature = OSSwapHostToBigInt24(' FLV');
		header.version = 1;
		header.flags = 1 | 4;
		header.length = OSSwapHostToBigInt32(sizeof(header));
		
		[stream write:(uint8_t *)&header maxLength:sizeof(header)];
		
		FLVPreviousTag previousTag = FLVPreviousTagMake(0);
		[stream write:(uint8_t *)&previousTag maxLength:sizeof(previousTag)];
	}
	
	// write metadata
	{
		NSArray *AMFObjects = @[
			@"onMetadata",
			metadata,
		];
		
		NSData *AMFData = [AMFSerialization dataWithAMFObject:AMFObjects options:AMFWritingOptionsSequence error:nil];
		
		FLVTag tag = FLVTagMake(0x12, (uint32_t)AMFData.length, 0, 0);
		
		[stream write:(uint8_t *)&tag maxLength:sizeof(tag)];
		[stream write:(uint8_t *)AMFData.bytes maxLength:AMFData.length];
		
		FLVPreviousTag previousTag = FLVPreviousTagMake(sizeof(tag) + (uint32_t)AMFData.length);
		[stream write:(uint8_t *)&previousTag maxLength:sizeof(previousTag)];
	}
	
	return YES;
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
		CMTime time = self.audioPresentationTimeStamp;
		
		const CMTime offset = self.audioTimeOffset;
		if(CMTIME_IS_INVALID(offset))
		{
			self.audioTimeOffset = pts;
			
			NSData *startData = CFBridgingRelease(CMFormatDescriptionCopyFLVAudioStartData(formatDescription));
			if(startData != NULL)
			{
				FLVTag tag = FLVTagMake(0x08, (uint32_t)startData.length, 0, 0);
				
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
		
		NSData *prefixData = CFBridgingRelease(CMFormatDescriptionCopyFLVAudioPrefixData(formatDescription));
		
		CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
		const size_t dataLength = CMBlockBufferGetDataLength(dataBuffer);
		
		NSMutableData *data = [NSMutableData dataWithCapacity:dataLength];
		CMPBlockBufferAppendToData(dataBuffer, (__bridge CFMutableDataRef)data);
		
		{
			FLVTag tag = FLVTagMake(0x08, (uint32_t)(prefixData.length + dataLength), (uint32_t)(CMTimeGetSeconds(time) * 1000), 0);
			
			[stream write:(uint8_t *)&tag maxLength:sizeof(tag)];
			[stream write:(uint8_t *)prefixData.bytes maxLength:prefixData.length];
			[stream write:(uint8_t *)data.bytes maxLength:data.length];
			
			FLVPreviousTag previousTag = FLVPreviousTagMake(sizeof(tag) + (uint32_t)(prefixData.length + data.length));
			[stream write:(uint8_t *)&previousTag maxLength:sizeof(previousTag)];
		}
	}
	
	return YES;
}

@end
