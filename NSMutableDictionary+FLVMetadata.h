#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface NSMutableDictionary (FLVMetadata)

+ (instancetype)FLVMetadataWithVideoFormatDescription:(CMVideoFormatDescriptionRef)videoFormatDescription videoEncoderSettings:(NSDictionary *)videoEncoderSettings audioFormatDescription:(CMAudioFormatDescriptionRef)audioFormatDescription audioEncoderSettings:(NSDictionary *)audioEncoderSettings error:(NSError **)error
;

@end
