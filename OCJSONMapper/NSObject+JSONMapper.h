//
//  NSObject+JSONMapper.h
//  JSONMapper
//
//  Created by Ignacio Calderon on 23/02/15.
//  Copyright (c) 2015 Ignacio Calderon. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (JSONMapper)

+(instancetype) map:(id)jsonObject;
-(NSString*) JSONString;

@end

@protocol JSONMapper <NSObject>
@required
-(NSString*) remapPropertyName:(NSString*)propertyName;
@end

@protocol NSString<NSObject>
@end