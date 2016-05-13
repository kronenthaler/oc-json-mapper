//
//  NSObject+JSONMapper.h
//  JSONMapper
//
//  Created by Ignacio Calderon on 23/02/15.
//  Copyright (c) 2015 Ignacio Calderon. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (JSONMapper)

+ (instancetype)map:(id)jsonObject error:(NSError**)error;
- (NSString*)JSONString;

@end

@protocol JSONMapper <NSObject>
@required
- (NSString*)remapPropertyName:(NSString*)propertyName;
@optional
- (instancetype)initForMap;
@end

@protocol NSString <NSObject>
@end