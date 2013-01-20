// **********************************************************************************
//
// BSD License.
// This file is part of upnpx.
//
// Copyright (c) 2010-2011, Bruno Keymolen, email: bruno.keymolen@gmail.com
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, 
// are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice, 
// this list of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this 
// list of conditions and the following disclaimer in the documentation and/or other 
// materials provided with the distribution.
// Neither the name of "Bruno Keymolen" nor the names of its contributors may be 
// used to endorse or promote products derived from this software without specific 
// prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
// IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT 
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
// POSSIBILITY OF SUCH DAMAGE.
//
// **********************************************************************************


#import "SoapAction.h"

@interface SoapAction ()
@property (strong) NSURL *actionURL;
@property (strong) NSURL *eventURL;
@property (strong) NSString *upnpNameSpace;
@property (strong) NSDictionary *mOutput;
@end

@implementation SoapAction

-(id)initWithActionURL:(NSURL *)aUrl eventURL:(NSURL *)eUrl upnpnamespace:(NSString *)ns {
  self = [super initWithNamespaceSupport:YES];
  if (self) {
    _actionURL = aUrl;
    _eventURL = eUrl;
    _upnpNameSpace = ns;
  }
  return self;
}

- (int)action:(NSString *)soapAction parameters:(NSDictionary *)parameters returnValues:(NSDictionary *)output {
	int len = 0;
	int ret = 0;
	
	self.mOutput = output;//we need it as a member to fill it during parsing
	
	//SOAP Message to Send
	NSMutableString *body = [[NSMutableString alloc] init];
	[body appendString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
	[body appendString:@"<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">"];
	[body appendString:@"<s:Body>"];
	[body appendFormat:@"<u:%@ xmlns:u=\"%@\">", soapAction, self.upnpNameSpace];
	for (id key in parameters) {		
		[body appendFormat:@"<%@>%@</%@>", key, [parameters objectForKey:key], key];
	}
	[body appendFormat:@"</u:%@>", soapAction];
	[body appendFormat:@"</s:Body></s:Envelope>"];
	len = [body length];

	//Construct the HTML POST 
	NSMutableURLRequest* urlRequest=[NSMutableURLRequest requestWithURL:self.actionURL
															cachePolicy:NSURLRequestReloadIgnoringCacheData
														timeoutInterval:15.0];
	
	[urlRequest setValue:[NSString stringWithFormat:@"\"%@#%@\"", self.upnpNameSpace, soapAction] forHTTPHeaderField:@"SOAPACTION"];
	[urlRequest setValue:[NSString stringWithFormat:@"%d", len] forHTTPHeaderField:@"CONTENT-LENGTH"];
	[urlRequest setValue:@"text/xml; charset=\"utf-8\"" forHTTPHeaderField:@"CONTENT-TYPE"];

	/*
	[urlRequest setValue:@"" forHTTPHeaderField:@"Accept-Language"];
	[urlRequest setValue:@"" forHTTPHeaderField:@"Accept-Encoding"];
	*/
	
	//POST (Synchronous)
	[urlRequest setHTTPMethod:@"POST"];	
	[urlRequest setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]]; 
	
	
	
	NSHTTPURLResponse *urlResponse;
	NSData *resp = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&urlResponse error:nil];
	
	//Check the Server Return Code @TODO
	if ([urlResponse statusCode] != 200) {
		ret = 0 - [urlResponse statusCode];
	} else {
		ret = 0;
	}
	
	if (ret == 0 && [resp length] > 0) {
    //Parse result
    //Clear the assets becuase the action can be re-used
    [self clearAllAssets];
    NSString *responseGroupTag = [NSString stringWithFormat:@"%@Response", soapAction];
    for (id key in output) {
      [self addAsset:[NSArray arrayWithObjects: @"Envelope", @"Body", responseGroupTag, (NSString *)key, nil] callfunction:nil functionObject:nil setStringValueFunction:@selector(setStringValueForFoundAsset:) setStringValueObject:self];
    }
				
    //uShare Issues here, can not handle names like 'Bj~rk
    ret = [super parseFromData:resp];
	}	
  
  self.mOutput = nil;
  return ret;
}

- (void)setStringValueForFoundAsset:(NSString *)value {
	if (value) {
		//Check which asset is active in our stack
		BasicParserAsset* asset = [self getAssetForElementStack:self.elementStack];
		if (asset) {
			NSString *elementName = [[asset path] lastObject];
			if (elementName) {
				NSMutableString *output = [self.mOutput objectForKey:elementName];
				if (output){	
					[output setString:value];
				}
			}
		}
	}	
}

@end
