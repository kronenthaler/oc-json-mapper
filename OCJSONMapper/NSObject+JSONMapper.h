//
//  NSObject+JSONMapper.h
//  JSONMapper
//
//  Created by Ignacio Calderon on 23/02/15.
//  Copyright (c) 2015 Ignacio Calderon. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, JSONPrintingOptions) {
    JSONPrintingOptionsKeepNull = 1,
    JSONPrintingOptionsPretty = 2
};

@interface NSObject (JSONMapper)

+ (instancetype)map:(id)jsonObject error:(NSError**)error;

- (NSString*)JSONString;
- (NSString*)JSONString:(JSONPrintingOptions)options;

@end

@protocol JSONMapper <NSObject>
@required
- (NSString*)remapPropertyName:(NSString*)propertyName;
@optional
- (instancetype)initForMap;
- (NSArray<NSString*>*)skipProperties;
@end

@protocol NSString <NSObject>
@end
