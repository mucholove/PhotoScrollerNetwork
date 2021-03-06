/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *
 * This file is part of PhotoScrollerNetwork -- An iOS project that smoothly and efficiently
 * renders large images in progressively smaller ones for display in a CATiledLayer backed view.
 * Images can either be local, or more interestingly, downloaded from the internet.
 * Images can be rendered by an iOS CGImageSource, libjpeg-turbo, or incrmentally by
 * libjpeg (the turbo version) - the latter gives the best speed.
 *
 * Parts taken with minor changes from Apple's PhotoScroller sample code, the
 * ConcurrentOp from my ConcurrentOperations github sample code, and TiledImageBuilder
 * was completely original source code developed by me.
 *
 * Copyright 2012-2019 David Hoerl All Rights Reserved.
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#import "ConcurrentOp.h"

#import "TiledImageBuilder.h"


@implementation ConcurrentOp
{
	NSMutableData *data;
}

- (uint32_t)milliSeconds
{
	return _imageBuilder.milliSeconds;
}

- (NSMutableURLRequest *)setup
{
	data = [NSMutableData dataWithCapacity:10000];
	self.imageBuilder = [[TiledImageBuilder alloc] initForNetworkDownloadWithDecoder:_decoder size:CGSizeMake(320, 320) orientation:_orientation];
	return [super setup];
}

- (void)setWebData:(NSData *)webData
{
	super.webData = webData;

#ifdef LIBJPEG
	if(_decoder == libjpegIncremental) {
		// Since the SesslonDelegate is trying to be sophisticated, and use the chained dispatch_data obhects,
		// our consumer is just consuming chunks at its own pace. So we'll always keep the webData at 0 byes,
		// and use our own internal mutable object to transfer bytes. Its the best compromise we can use.
		if([webData length]) {
			[data appendData:webData];
			BOOL consumed = [_imageBuilder jpegAdvance:data];
			if(consumed) {
				// This use to be hidden in the imagebuilder class, really was hard to spot
				[data setLength:0];
			}
			dispatch_queue_t q	= dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
			void *argNull = NULL;
			super.webData = (NSData *)dispatch_data_create(argNull, 0, q, ^{});
			super.currentReceiveSize = 0;
		}
	}
#endif
}

- (void)completed
{
	
#ifdef LIBJPEG
	if(_decoder == libjpegIncremental) {
		if(_imageBuilder.failed) {
			NSLog(@"FAILED!");
			self.imageBuilder = nil;
		}
	} else
#endif
	{
		[_imageBuilder writeToImageFile:self.webData];
		[_imageBuilder dataFinished];
	}

	[super completed];
}

@end
