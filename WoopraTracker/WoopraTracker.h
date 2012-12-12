//
//  WoopraTracker.h
//  WoopraTracker
//
//  Created by Jayanth on 31/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define TRACKER_VISITOR_NAME    @"parameter_visitor_name"
#define TRACKER_VISITOR_EMAIL   @"parameter_visitor_email"

@interface WoopraTracker : NSObject<NSURLConnectionDelegate>{
    
}
+ (id)sharedInstance;
-(void)trackPageViewWithTitle:(NSString*)title andURL:(NSString*)url andCustomValues:(NSDictionary*)customDict;
-(void)trackPageViewWithTitle:(NSString *)title andURL:(NSString *)url; 
-(void)setupWithWebsite:(NSString*)hostName;
@end
