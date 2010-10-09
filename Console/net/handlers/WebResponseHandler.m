//
//  WebResponseHandler.m
//  TestApp
//
//  Created by wookyoung noh on 09/10/10.
//  Copyright 2010 factorcat. All rights reserved.
//

#import "WebResponseHandler.h"
#import "Logger.h"
#import "NSStringExt.h"
#import "HTTPServer.h"
#import "ConsoleManager.h"
#import "CommandManager.h"
#import "NSStringExt.h"
#import "GeometryExt.h"
#import "NSArrayExt.h"
#import <QuartzCore/QuartzCore.h>
#import "NSArrayBlock.h"


#define S(obj) SWF(@"%@", obj)

@interface NSString (HTMLExtensions)

+ (NSDictionary *)htmlEscapes;
+ (NSDictionary *)htmlUnescapes;
- (NSString *)htmlEscapedString;
- (NSString *)htmlUnescapedString;

@end
@implementation NSString (HTMLExtensions)

static NSDictionary *htmlEscapes = nil;
static NSDictionary *htmlUnescapes = nil;

+ (NSDictionary *)htmlEscapes {
	if (!htmlEscapes) {
		htmlEscapes = [[NSDictionary alloc] initWithObjectsAndKeys:
					   @"&amp;", @"&",
					   @"&lt;", @"<",
					   @"&gt;", @">",
					   nil
					   ];
	}
	return htmlEscapes;
}

+ (NSDictionary *)htmlUnescapes {
	if (!htmlUnescapes) {
		htmlUnescapes = [[NSDictionary alloc] initWithObjectsAndKeys:
						 @"&", @"&amp;",
						 @"<", @"&lt;", 
						 @">", @"&gt;",
						 nil
						 ];
	}
	return htmlEscapes;
}

static NSString *replaceAll(NSString *s, NSDictionary *replacements) {
	for (NSString *key in replacements) {
		NSString *replacement = [replacements objectForKey:key];
		s = [s stringByReplacingOccurrencesOfString:key withString:replacement];
	}
	return s;
}

- (NSString *)htmlEscapedString {
	return replaceAll(self, [[self class] htmlEscapes]);
}

- (NSString *)htmlUnescapedString {
	return replaceAll(self, [[self class] htmlUnescapes]);
}

@end



@implementation WebResponseHandler


+(void) load {
	[HTTPResponseHandler registerHandler:self];
}

+ (BOOL)canHandleRequest:(CFHTTPMessageRef)aRequest
				  method:(NSString *)requestMethod
					 url:(NSURL *)requestURL
			headerFields:(NSDictionary *)requestHeaderFields {
	if ([requestURL.path isEqualToString:@"/"]) {
		return YES;
	}
	
	return NO;
}


- (void)startResponse {
	//	log_info(@"url %@", url);
	//	log_info(@"requestMethod %@", requestMethod);
	//	log_info(@"headerFields %@", headerFields);
	
	NSMutableArray* ary = [NSMutableArray array];

	NSArray* arrayLS = [COMMANDMAN array_ls:[CONSOLEMAN currentTargetObjectOrTopViewController] arg:nil];
	NSString* title = EMPTY_STRING;
	for (NSArray* pair in arrayLS) {
		int lsType = [[pair objectAtFirst] intValue];
		id obj = [pair objectAtSecond];
		switch (lsType) {
			case LS_OBJECT: {
					NSString* classNameUpper = [SWF(@"%@", [obj class]) uppercaseString];
					[ary addObject:SWF(@"[%@]: %@", classNameUpper, [S(obj) htmlEscapedString])];
					if ([obj isKindOfClass:[UIView class]]) {
						[ary addObject:SWF(@"<img src='/image/%p.png' />", obj)];
					} else if ([obj respondsToSelector:@selector(title)]) {
						title =[obj title];
					}
				}
				break;
			case LS_VIEWCONTROLLERS:
				[ary addObject:SWF(@"VIEWCONTROLLERS: %@", [S(array_prefix_index(obj)) htmlEscapedString])];
				break;
			case LS_TABLEVIEW:
				[ary addObject:SWF(@"TABLEVIEW: %@", [S(obj) htmlEscapedString])];
//				[ary addObject:SWF(@"<img src='/image/%p.png' />", obj)];
				break;
			case LS_SECTIONS: {
					NSArray* sections = [(NSArray*)obj map:^id(id sectionAry) { 
										return [sectionAry map:^id(id cell) {
											return SWF(@"<img src='/image/%p.png' /> %@", cell, [S(cell) htmlEscapedString]);
										}];
						}];
					[ary addObject:SWF(@"SECTIONS: %@", sections)];
				}
				break;
			case LS_VIEW:
				[ary addObject:SWF(@"VIEW: %@", [S(obj) htmlEscapedString])];
				[ary addObject:SWF(@"<img src='/image/%p.png' />", obj)];
				break;
			case LS_VIEW_SUBVIEWS: {
					NSArray* subviews = [obj map:^id(id subview) {
						return SWF(@"<img src='/image/%p.png' /> %@", subview, [S(subview) htmlEscapedString]);
					}];
					[ary addObject:SWF(@"VIEW.SUBVIEWS: %@", subviews)];
				}
				break;
			default:
				break;
		}
	}
	[ary addObject:@"<img src='/image/capture.png' border='20'>"];

	NSString* body = SWF(@"<pre>%@</pre>", [ary join:LF]);
	NSString* head = SWF(@"<title>%@</title>\
						 <script type=\"text/javascript\" src=\"/js/json.js\"></script>", title);
	NSString* html = SWF(@"<html><head>%@</head><body bgcolor='#d3d3d3'>%@</body></html>", head, body);
	
	NSData* fileData = [html dataUsingEncoding:NSUTF8StringEncoding];

	CFHTTPMessageRef response =
	CFHTTPMessageCreateResponse(
								kCFAllocatorDefault, 200, NULL, kCFHTTPVersion1_1);
	CFHTTPMessageSetHeaderFieldValue(
									 response, (CFStringRef)@"Content-Type", (CFStringRef)@"text/html");
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
