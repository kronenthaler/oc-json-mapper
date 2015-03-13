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

+(instancetype) map:(id)jsonObject error:(NSError**)error{
    return [[[self class] alloc] mapTo:jsonObject error:error];
}

-(instancetype) mapTo:(id)jsonObject error:(NSError**)error{
    if([jsonObject isKindOfClass:[NSDictionary class]])
        return [self mapToDictionary:jsonObject error:error];
    if([jsonObject isKindOfClass:[NSArray class]])
        return [self mapToArray:jsonObject error:error];
    return [self mapToValue:jsonObject error:error];
}

-(instancetype) mapToDictionary:(NSDictionary*)data error:(NSError**)error{
    for(Property* property in [self getProperties]){
        id value = nil;
        if([self conformsToProtocol:@protocol(JSONMapper)]){
            value = data[[((id<JSONMapper>)self) remapPropertyName:property.name]];
        }else{
            value = data[property.name];
        }
        
        if(value == nil) //property is not in the json, ignore it.
            continue;

        BOOL valid = NO;
        if([value isKindOfClass:[NSDictionary class]]){
            Class class = NSClassFromString(property.type);
            if([class isSubclassOfClass:[NSDictionary class]]) //treat as a dictionary.
                valid = [self setProperty:property value:value forKey:property.name error:error];
            else //map as an object
                valid = [self setProperty:property
                            value:[class map:value error:error]
                           forKey:property.name
                            error:error];
        }else if([value isKindOfClass:[NSArray class]]){
            //see how to create the instances of the corresponding type.
            valid = [self setProperty:property
                        value:[NSClassFromString(property.subtype) map:value error:error]
                       forKey:property.name
                        error:error];
        }else{
            //assign the value to the property.
            valid = [self setProperty:property value:value forKey:property.name error:error];
        }
        
        if(!valid)
            return nil;
    }
    
    return self;
}

-(BOOL) setProperty:(Property*)property value:(id)value forKey:(NSString*)key error:(NSError**)error{
    //there is an error being dragged from a previous call.
    if(error != NULL && *error)
        return NO;
    
    //check if the property type and value type are compatible, if not, give an error and return.
    if(value == nil ||
       (NSClassFromString(property.type) != nil && [value isKindOfClass:NSClassFromString(property.type)]) ||
       ([value isKindOfClass:[@(YES) class]] && [self isBoolean:property]) ||
       ([value isKindOfClass:[NSNumber class]] && [self isIntegral:property]) ||
       ([value isKindOfClass:[NSNumber class]] && [self isDecimal:property])) {
        [self setValue:value forKey:property.name];
        return YES;
    }
    
    // it's not null, and not a primitive type, it can accept null values
    if(value != nil &&
       [value isKindOfClass:[NSNull class]] &&
       ![self isBoolean:property] &&
       ![self isIntegral:property] &&
       ![self isDecimal:property]){
        return YES;
    }
    
    if(error != NULL){
        NSDictionary* info =@{
                              @"NSDebugDescription":@"Property type doesn't match with the expected from the object.",
                              @"class":[[self class] description],
                              @"property":property.name,
                              @"type":property.type,
                              @"value":value,
                              @"value-type":[[value class]description]};
       *error = [NSError errorWithDomain:@"JSONMapper"
                                     code:-500
                                 userInfo:info];
    }

    return NO;
}

-(instancetype) mapToArray:(NSArray*)data error:(NSError**)error{
    NSMutableArray* result = [NSMutableArray array];
    for(id item in data){
        id value = [[self class] map:item error:error];
        if(error != NULL && *error)
            return nil;
        [result addObject:value];
    }
    return result;
}

-(instancetype) mapToValue:(id)data error:(NSError**)error{
    if(data == nil) return [NSNull alloc];
    return data;
}

-(BOOL) isBoolean:(Property*)property{
    return
        [property.type hasPrefix:@"TB"] ||
        [property.type hasPrefix:@"Tc"];
}

-(BOOL) isDecimal:(Property*)property{
    return
        [property.type hasPrefix:@"Tf"] ||
        [property.type hasPrefix:@"Td"];
}

-(BOOL) isIntegral:(Property*)property{
    return
        [property.type hasPrefix:@"Ti"] ||
        [property.type hasPrefix:@"Ts"] ||
        [property.type hasPrefix:@"Tl"] ||
        [property.type hasPrefix:@"Tq"] ||
        [property.type hasPrefix:@"TI"] ||
        [property.type hasPrefix:@"TS"] ||
        [property.type hasPrefix:@"TL"] ||
        [property.type hasPrefix:@"TQ"];
}

-(BOOL) isReservedProperty:(objc_property_t)prop{
    unsigned int propertyObjCount;
    objc_property_t* objList = class_copyPropertyList([NSObject class], &propertyObjCount);
    for(int j=0;j<propertyObjCount;j++){
        if(strcmp(property_getName(prop), property_getName(objList[j]))==0){
            return YES;
        }
    }
    return NO;
}

-(NSArray*) getProperties{
    NSMutableArray* properties = [NSMutableArray array];
    
    Class currentClass = [self class];
    while (currentClass && currentClass != [NSObject class]) {
        unsigned int propertyCount;
        objc_property_t* list = class_copyPropertyList(currentClass, &propertyCount);
        
        for(int i=0;i<propertyCount;i++){
            objc_property_t prop = list[i];
            
            if([self isReservedProperty:prop]) //reserved property
                continue;
            
            NSString* typeString = [NSString stringWithUTF8String:property_getAttributes(prop)];
            NSArray* attributes = [typeString componentsSeparatedByString:@","];
            NSString* typeAttribute = attributes[0];
            NSString* subTypeString = @"NSObject";
            
            if ([typeAttribute hasPrefix:@"T@"]) {
                typeString = [typeAttribute substringWithRange:NSMakeRange(3, [typeAttribute length]-4)];
                Class typeClass = NSClassFromString(typeString);
                if(typeClass == nil){
                    NSCharacterSet* set = [NSCharacterSet characterSetWithCharactersInString:@"<>"];
                    NSArray* tokens = [typeString componentsSeparatedByCharactersInSet:set];

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
    
    
    if([self isKindOfClass:[NSArray class]])
        return [self JSONStringFromArray];
    
    return [self JSONStringFromObject];
}

-(NSString*) JSONStringFromArray{
    NSMutableString* buffer = [NSMutableString string];
    [buffer appendString:@"["];
    for(id item in (NSArray*)self){
        if(buffer.length > 1) [buffer appendString:@","];
        [buffer appendString:[item JSONString]];
    }
    [buffer appendString:@"]"];
    return buffer;
}

-(NSString*) JSONStringFromObject{
    NSMutableString* buffer = [NSMutableString string];
    [buffer appendString:@"{"];
    for(Property* property in [self getProperties]){
        if(buffer.length > 1) [buffer appendString:@","];
        id value = [self valueForKey:property.name];
        if(value == nil) value = [NSNull new];
        [buffer appendString:[NSString stringWithFormat:@"\"%@\": %@", property.name, [value JSONString]]];
    }
    [buffer appendString:@"}"];
    return buffer;
}

@end