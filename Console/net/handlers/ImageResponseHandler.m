//
//  ImageResponseHandler.m
//  TestApp
//
//  Created by wookyoung noh on 09/10/10.
//  Copyright 2010 factorcat. All rights reserved.
//

#import "ImageResponseHandler.h"
#import "Logger.h"
#import "NSStringExt.h"
#import "HTTPServer.h"
#import "ConsoleManager.h"
#import "CommandManager.h"
#import "NSStringExt.h"
#import "GeometryExt.h"
#import "NSArrayExt.h"
#import <QuartzCore/QuartzCore.h>




@implementation ImageResponseHandler


+(void) load {
	[HTTPResponseHandler registerHandler:self];
}

+ (BOOL)canHandleRequest:(CFHTTPMessageRef)aRequest
				  method:(NSString *)requestMethod
					 url:(NSURL *)requestURL
			headerFields:(NSDictionary *)requestHeaderFields {
	if ([requestURL.path hasPrefix:@"/image"]) {
		return YES;
	}
	
	return NO;
}

-(UIImage*) url_to_image {
	NSString* urlPath = [url path];
#define SLASH_IMAGE_SLASH_LENGTH 7	//	/image/
	if (urlPath.length > SLASH_IMAGE_SLASH_LENGTH) {
		NSString* addressPng = [[url path] slice:[@"/image/" length] backward:-1];
		NSString* addressStr = [addressPng slice:0 backward:-[@".png" length]-1];
		if ([@"capture" isEqualToString:addressStr]) {
			return [self capture_image];
		} else {
			size_t address = [addressStr to_size_t];
			id obj = (id)address;
			return [self obj_to_image:obj];
		}
	}
	return nil;
}

-(UIImage*) capture_image {
	UIView* view = [UIApplication sharedApplication].keyWindow;// [CONSOLEMAN navigationController].topViewController.view;
	CGRect screenRect = [[UIScreen mainScreen] bounds];    
    UIGraphicsBeginImageContext(screenRect.size);
    CGContextRef ctx = UIGraphicsGetCurrentContext(); 
    [[UIColor blackColor] set]; 
    CGContextFillRect(ctx, screenRect);
    [view.layer renderInContext:ctx];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage; 
}

-(UIImage*) obj_to_image:(id)obj {
	UIView* view = (UIView*)obj;
	UIGraphicsBeginImageContext(view.frame.size);
	[view.layer renderInContext: UIGraphicsGetCurrentContext()];
	UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();	
	return image;
}

- (void)startResponse {	
	UIImage* image = [self url_to_image];
	NSData* fileData;
	if (nil == image) {
		fileData = [NSData data];
	} else {
		fileData = UIImagePNGRepresentation(image);
	}
	
	CFHTTPMessageRef response =
	CFHTTPMessageCreateResponse(
								kCFAllocatorDefault, 200, NULL, kCFHTTPVersion1_1);
	CFHTTPMessageSetHeaderFieldValue(
									 response, (CFStringRef)@"Content-Type", (CFStringRef)@"image/png");
	CFHTTPMessageSetHeaderFieldValue(
									 response, (CFStringRef)@"Connection", (CFStringRef)@"close");
	CFHTTPMessageSetHeaderFieldValue(
									 response,
									 (CFStringRef)@"Content-Length",
									 (CFStringRef)[NSString stringWithFormat:@"%ld", [fileData length]]);
	CFDataRef headerData = CFHTTPMessageCopySerializedMessage(response);
	
	@try
	{
		[fileHandle writeData:(NSData *)headerData];
		[fileHandle writeData:fileData];
	}
	@catch (NSException *exception)
	{
		// Ignore the exception, it normally just means the client
		// closed the connection from the other end.
	}
	@finally
	{
		CFRelease(headerData);
		[server closeHandler:self];
	}
}

@end

