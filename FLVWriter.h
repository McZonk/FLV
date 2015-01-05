#import <Foundation/Foundation.h>

#import <CoreMedia/CoreMedia.h>


@interface FLVWriter : NSObject

- (instancetype)initWithURL:(NSURL *)URL error:(NSError **)error;

@property (nonatomic, strong) __attribute__((NSObject)) CMVideoFormatDescriptionRef videoFormatDescription;
@property (nonatomic, strong) __attribute__((NSObject)) CMAudioFormatDescriptionRef audioFormatDescription;

@property (nonatomic, copy) NSDictionary *videoEncoderSettings;
@property (nonatomic, copy) NSDictionary *audioEncoderSettings;

- (BOOL)startWritingWithError:(NSError **)error;
- (void)endWriting;

- (BOOL)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end
