//
//  NSObject+JSONMapper.m
//  JSONMapper
//
//  Created by Ignacio Calderon on 23/02/15.
//  Copyright (c) 2015 Ignacio Calderon. All rights reserved.
//

#import "NSObject+JSONMapper.h"
#import <objc/runtime.h>

@interface Property : NSObject
@property (strong, nonatomic) NSString* name;
@property (strong, nonatomic) NSString* type;
@property (strong, nonatomic) NSString* subtype;
@end
@implementation Property
@end

@implementation NSObject (JSONMapper)

+(instancetype) map:(id)jsonObject{
    return [[[self class] alloc] mapTo:jsonObject];
}

-(instancetype) mapTo:(id)jsonObject{
    if([jsonObject isKindOfClass:[NSDictionary class]])
        return [self mapToDictionary:jsonObject];
    if([jsonObject isKindOfClass:[NSArray class]])
        return [self mapToArray:jsonObject];
    return [self mapToValue:jsonObject];
}

-(instancetype) mapToDictionary:(NSDictionary*)data{
    for(Property* property in [self getProperties]){
        id value = nil;
        if([self conformsToProtocol:@protocol(JSONMapper)]){
            value = data[[((id<JSONMapper>)self) remapPropertyName:property.name]];
        }else{
            value = data[property.name];
        }
        
        if(value == nil) //property is not in the json, ignore it.
            continue;
        
        if([value isKindOfClass:[NSDictionary class]]){
            Class class = NSClassFromString(property.type);
            if([class isSubclassOfClass:[NSDictionary class]]) //treat as a dictionary.
                [self setValue:value forKey:property.name];
            else //map as an object
                [self setValue:[class map:value] forKey:property.name];
        }else if([value isKindOfClass:[NSArray class]]){
            //see how to create the instances of the corresponding type.
            [self setValue:[NSClassFromString(property.subtype) map:value] forKey:property.name];
        }else{
            //assign the value to the property.
            [self setValue:value forKey:property.name];
        }
    }
    
    return self;
}

-(instancetype) mapToArray:(NSArray*)data{
    NSMutableArray* result = [NSMutableArray array];
    for(id item in data){
        [result addObject:[[self class] map:item]];
    }
    return result;
}

-(instancetype) mapToValue:(id)data{
    if(data == nil) return [NSNull alloc];
    return data;
}

-(NSArray*) getProperties{
    NSMutableArray* properties = [NSMutableArray array];
    
    Class currentClass=[self class];
    while (currentClass && currentClass != [NSObject class]) {
        unsigned int propertyCount;
        objc_property_t* list = class_copyPropertyList(currentClass, &propertyCount);
        
        for(int i=0;i<propertyCount;i++){
            objc_property_t prop = list[i];
            if(strcmp("description", property_getName(prop)) == 0) //reserved property
                continue;
            
            const char* type = property_getAttributes(prop);
            NSString* typeString = [NSString stringWithUTF8String:type];
            NSArray* attributes = [typeString componentsSeparatedByString:@","];
            NSString* typeAttribute = [attributes objectAtIndex:0];
            NSString* subTypeString=nil;
            
            if ([typeAttribute hasPrefix:@"T@"]) {
                typeString = [typeAttribute substringWithRange:NSMakeRange(3, [typeAttribute length]-4)];
                Class typeClass = NSClassFromString(typeString);
                if(typeClass == nil){
                    NSArray* tokens = [typeString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];

                    typeString = tokens[0];
                    subTypeString = tokens[1];
                }
            }
            
            Property* property = [[Property alloc] init];
            property.name = [NSString stringWithCString:property_getName(prop) encoding:NSUTF8StringEncoding];
            property.type = typeString;
            property.subtype = subTypeString;
            [properties addObject:property];
        }
        
        free(list);
        
        //copy parent properties too.
        currentClass = class_getSuperclass(currentClass);
    }

    return properties;
}

-(NSString*) JSONString {
    if(self == nil || [self isKindOfClass:[NSNull class]])
        return @"null";
    
    if([self isKindOfClass:[NSNumber class]]){
        if([self isKindOfClass:[@(YES) class]])
            return [((NSNumber*)self) boolValue] ? @"true" : @"false";

        return [((NSNumber*)self) stringValue];
    }
    
    if([self isKindOfClass:[NSString class]])
        return [NSString stringWithFormat:@"\"%@\"",(NSString*)self];
    
    
    if([self isKindOfClass:[NSArray class]]){
        NSMutableString* buffer = [NSMutableString string];
        [buffer appendString:@"["];
        for(id item in (NSArray*)self){
            if(buffer.length > 1) [buffer appendString:@","];
            [buffer appendString:[item JSONString]];
        }
        [buffer appendString:@"]"];
        return buffer;
    }
    
    //else is an object
    NSMutableString* buffer = [NSMutableString string];
    [buffer appendString:@"{"];
    for(Property* property in [self getProperties]){
        if(buffer.length > 1) [buffer appendString:@","];
        id value = [self valueForKey:property.name];
        [buffer appendString:[NSString stringWithFormat:@"\"%@\": %@", property.name, [value JSONString]]];
    }
    [buffer appendString:@"}"];
    return buffer;
}

@end