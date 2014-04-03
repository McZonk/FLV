#import <Foundation/Foundation.h>

@interface FLVWriter : NSObject

- (instancetype)initWithURL:(NSURL *)URL error:(NSError **)error;

- (void)startWriting;
- (void)endWriting;

- (BOOL)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end
