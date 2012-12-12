//
//  WoopraTracker.m
//  WoopraTracker
//
//  Created by Jayanth on 31/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "WoopraTracker.h"

#define TRACK_REQUEST_URL @"http://mobile.woopra.com.woopra-ns.com/ce/"
#define META_USERDEFAULT_KEY    @"com_woopra_tracker_meta_userdefault_key"
#define UNIQUE_IDENTIFIER_KEY   @"com_woopra_tracker_unique_identifier_key"

NSString *mCookie;
NSString *mUserAgent;
NSURLConnection *urlConnection;
NSMutableData *responseData;
NSString *currentElement;
NSString *mHostName;
NSTimer *pingTimer;

@implementation WoopraTracker
+(void)initialize{
    NSDictionary *infoDict      =   [[NSBundle mainBundle] infoDictionary];
    NSString *bundleVersion     =   [infoDict objectForKey:@"CFBundleVersion"];
    NSString *appName           =   [infoDict objectForKey:@"CFBundleName"];
    
    NSUserDefaults *def         =   [NSUserDefaults standardUserDefaults];
    if ([def valueForKey:UNIQUE_IDENTIFIER_KEY]) {
        mCookie                 =   [def valueForKey:UNIQUE_IDENTIFIER_KEY];
    }else {
        // Create universally unique identifier (object)
        CFUUIDRef uuidObject    = CFUUIDCreate(kCFAllocatorDefault);
        // Get the string representation of CFUUID object.
        NSString *uuidStr       =   (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuidObject);
        mCookie                 =   [uuidStr retain];
        [def setValue:uuidStr forKey:UNIQUE_IDENTIFIER_KEY];
        CFRelease(uuidObject);
        CFRelease(uuidStr);
    }
    mUserAgent                  =   [[NSString stringWithFormat:@"woopra/os=%@&browser=%@ %@&device=%@",[[UIDevice currentDevice]systemVersion],appName,bundleVersion,[[UIDevice currentDevice]model]]retain];
    responseData                =   [[NSMutableData alloc]init];
}

+(id)sharedInstance{
    static dispatch_once_t pred =   0;
    __strong static id _sharedObject    =   nil;
    dispatch_once(&pred, ^{
        _sharedObject           =   [[self alloc] init];
    });
    return _sharedObject;
}

-(oneway void)release{
}

-(void)setupWithWebsite:(NSString*)hostName{
    mHostName                   =   [hostName retain];
}







#pragma mark - PING REQUEST AND RESPONSE
-(void)pingRequest{
    NSString *objMetaString     =   [[[NSUserDefaults standardUserDefaults] stringForKey:META_USERDEFAULT_KEY] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    NSString *urlString         =   nil;
    if([objMetaString length] > 0)
        urlString               =   [NSString stringWithFormat:@"http://%@.woopra-ns.com/ping/?&response=json&cookie=%@&meta=%@",mHostName,mCookie,objMetaString];
    else
        urlString               =   [NSString stringWithFormat:@"http://%@.woopra-ns.com/ping/?&response=json&cookie=%@",mHostName,mCookie];
    
    NSMutableURLRequest *pingRequest    =   [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    [pingRequest setValue:mUserAgent forHTTPHeaderField: @"User-Agent"];
    urlConnection               =   [[[NSURLConnection alloc] initWithRequest:pingRequest delegate:self] autorelease]; 
    [pingRequest release];
}

-(void)pingToServer{
    if(pingTimer){
        [pingTimer invalidate];
        pingTimer = nil;
    }
    pingTimer   =   [NSTimer  scheduledTimerWithTimeInterval:12.0 target:self selector:@selector(pingRequest) userInfo:nil repeats:YES];
}





#pragma mark - TRACK PAGEVIEW
-(void)trackPageViewWithTitle:(NSString*)title andURL:(NSString*)url andCustomValues:(NSDictionary*)customDict{
    NSString *extraParams       =   @"";
    NSString *urlString         =   nil;
    
    if (title && [title length]) {
        extraParams             =   [extraParams stringByAppendingFormat:@"&ce_name=%@",title];
    }
    if (url && [url length]) {
        extraParams             =   [extraParams stringByAppendingFormat:@"&ce_url=%@",url];
    }
    if (customDict) {
        for (id key in customDict) {
            NSString *sKey      =   (NSString*)key;
            NSString *value     =   [customDict valueForKey:key];
            if ([sKey isEqualToString:TRACKER_VISITOR_NAME]) {
                extraParams     =   [extraParams stringByAppendingFormat:@"&cv_name=%@",value];
            }else if([sKey isEqualToString:TRACKER_VISITOR_EMAIL]){
                extraParams     =   [extraParams stringByAppendingFormat:@"&cv_email=%@",value];
            }
        }
    }
    /*Get meta key if any*/
    NSString *objMetaString     =  [[[NSUserDefaults standardUserDefaults] stringForKey:META_USERDEFAULT_KEY] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    if([objMetaString length] > 0)
        urlString               =   [NSString stringWithFormat:@"http://%@.woopra-ns.com/visit/&response=json&cookie=%@&meta=%@",mHostName,mCookie,objMetaString];
    else
        urlString               =   [NSString stringWithFormat:@"http://%@.woopra-ns.com/visit/&response=json&cookie=%@",mHostName,mCookie];
    
    //Extra parameters from views
    if([extraParams length] > 0){
        urlString               =   [urlString stringByAppendingString:extraParams];
    }
    urlString                   =   [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableURLRequest *trackRequest   =   [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]]; 
    [trackRequest setValue:mUserAgent  forHTTPHeaderField: @"User-Agent"];
    [trackRequest setValue:@"http://mobile.woopra.com" forHTTPHeaderField:@"Referrer"];
    
    urlConnection               =   [[[NSURLConnection alloc] initWithRequest:trackRequest delegate:self] autorelease];
    
    [trackRequest release];
    
    [self pingToServer];
}

-(void)trackPageViewWithTitle:(NSString *)title andURL:(NSString *)url{
    [self trackPageViewWithTitle:title andURL:url andCustomValues:nil];
}

-(void)parseTrackingResponse:(NSData *)data{
    NSError *error              =   nil;
    NSDictionary *outerDic      =   [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    if (error != noErr) {
        return;
    }
    if ([[outerDic valueForKey:@"success"] boolValue]) {
        NSString *meta          =   [outerDic valueForKey:@"meta"];
        if (meta && [meta length]) {
            NSUserDefaults *userDefaults   =   [NSUserDefaults standardUserDefaults];
            [userDefaults setValue:meta forKey:META_USERDEFAULT_KEY];
            [userDefaults synchronize];
        }
    }
}






#pragma mark - HTTP CONNECTION DELEGATES
- (void)connection:(NSURLConnection *)connections didReceiveResponse:(NSURLResponse *)response{
    [responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connections didReceiveData:(NSData *)data{
    [responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connections {
    [self parseTrackingResponse:responseData];
}

- (void)connection:(NSURLConnection *)connections didFailWithError:(NSError *)error{
}
@end
