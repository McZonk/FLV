#import <Foundation/Foundation.h>

#import <CoreMedia/CoreMedia.h>


@interface FLVWriter : NSObject

- (instancetype)initWithURL:(NSURL *)URL error:(NSError **)error;

@property (nonatomic, assign) int videoWidth;
@property (nonatomic, assign) int videoHeight;
@property (nonatomic, assign) CMTime videoFrameRate;
@property (nonatomic, assign) CMVideoCodecType videoCodec;

@property (nonatomic, assign) CMTime audioSampleRate;
@property (nonatomic, assign) CMAudioCodecType audioCodec;

- (BOOL)startWritingWithError:(NSError **)error;
- (void)endWriting;

- (BOOL)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end
