//
//  FLVTests.m
//  FLVTests
//
//  Created by Maximilian Christ on 27/09/14.
//  Copyright (c) 2014 McZonk. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "FLV.h"


@interface FLVTests : XCTestCase

@end

@implementation FLVTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testWriteEmptyMovie
{
	NSString *movieName = [NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"flv"];
	NSURL *tempURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
	NSURL *movieURL = [tempURL URLByAppendingPathComponent:movieName];
	
	[NSFileManager.defaultManager createDirectoryAtURL:tempURL withIntermediateDirectories:YES attributes:nil error:nil];
	
	FLVWriter *writer = [[FLVWriter alloc] initWithURL:movieURL error:nil];
	
	writer.videoWidth = 320;
	writer.videoHeight = 240;
	writer.videoCodec = kCMVideoCodecType_H264;
	writer.videoFrameRate = CMTimeMake(1, 30);
	
	writer.audioCodec = kAudioFormatMPEG4AAC;
	writer.audioSampleRate = CMTimeMake(1, 44100);
	
	NSError *error = nil;
	XCTAssertTrue([writer startWritingWithError:&error], @"Error: %@", error);
	
	[writer endWriting];
	
	NSLog(@"Empty Movie: %@", movieURL.path);
}

@end
