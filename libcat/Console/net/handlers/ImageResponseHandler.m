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
#import "iPadExt.h"

#if USE_OPENGL
	#import "UIViewOpenGLExt.h"
#endif

@implementation ImageResponseHandler

+ (NSUInteger)priority
{
	return 1;
}

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

#pragma GCC diagnostic ignored "-Wundeclared-selector"
-(UIImage*) capture_image {
	UIWindow* window = [UIApplication sharedApplication].keyWindow;
	if ([window respondsToSelector:@selector(hasOpenGLView)]) {
		if ([window performSelector:@selector(hasOpenGLView)]) {
			if ([window respondsToSelector:@selector(opengl_to_image)]) {
				return [window performSelector:@selector(opengl_to_image)];
			}
		}
	}
	CGRect screenRect = [[UIScreen mainScreen] bounds];    
    UIGraphicsBeginImageContextWithOptions(window.bounds.size, window.opaque, 0.0);
	CGContextRef ctx = UIGraphicsGetCurrentContext(); 
	[[UIColor blackColor] set]; 
	CGContextFillRect(ctx, screenRect);
	for (UIWindow* window in [UIApplication sharedApplication].windows) {
		[window.layer renderInContext:ctx];		
	}
	if (! CGRectIsEmpty([UIApplication sharedApplication].statusBarFrame)) {
        CALayer* statusbarLayer = [CALayer layer];
        statusbarLayer.frame = [UIApplication sharedApplication].statusBarFrame;
        Class statusBarWindow = NSClassFromString(@"UIStatusBarWindow");
        if (NULL == statusBarWindow) {
//            if (IS_IPAD) {
//                statusbarLayer.contents = (id) [[UIImage imageNamed:@"libcat_statusbar~ipad.png"] CGImage];            
//            } else {
//                statusbarLayer.contents = (id) [[UIImage imageNamed:(IS_RETINA ? @"libcat_statusbar@2x.png" : @"libcat_statusbar.png")] CGImage];
//            }
        } else {
            UIWindow* statusBarWindow = [UIApplication.sharedApplication performSelector:@selector(statusBarWindow)];
            UIView* view = [statusBarWindow.subviews objectAtIndex:0];
            statusbarLayer.contents = (id) [[self obj_to_image:view] CGImage];
        }
        [statusbarLayer renderInContext:ctx];
	}
	UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return newImage; 	
}

-(UIImage*) obj_to_image:(id)obj {
	UIImage* image = nil;
	if ([obj isKindOfClass:[UIView class]]) {
		UIView* view = obj;
		if ([view respondsToSelector:@selector(isOpenGLView)]) {
			if ([view performSelector:@selector(isOpenGLView)]) {
				if ([view respondsToSelector:@selector(opengl_to_image)]) {
					return [view performSelector:@selector(opengl_to_image)];
				}
			}
		}
        UIGraphicsBeginImageContextWithOptions(view.frame.size, view.opaque, 0.0);
		[view.layer renderInContext: UIGraphicsGetCurrentContext()];
		image = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();	
	} else if ([obj isKindOfClass:[UIImage class]]) {
		image = obj;
	} else if ([obj isKindOfClass:[CALayer class]]) {
		CALayer* layer = obj;
		UIGraphicsBeginImageContext(layer.frame.size);
		[layer renderInContext: UIGraphicsGetCurrentContext()];
		image = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();						
	}
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
									 (CFStringRef)[NSString stringWithFormat:@"%d", [fileData length]]);
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


