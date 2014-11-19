#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface NSMutableDictionary (FLVMetadata)

+ (instancetype)FLVMetadataWithVideoFormatDescription:(CMVideoFormatDescriptionRef)videoFormatDescription audioFormatDescription:(CMAudioFormatDescriptionRef)audioFormatDescription error:(NSError **)error;

@end
