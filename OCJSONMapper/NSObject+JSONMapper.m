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

+ (instancetype)map:(id)jsonObject error:(NSError**)error {
    if ([jsonObject isKindOfClass:NSDictionary.class])
        return [self mapToDictionary:jsonObject error:error];
    if ([jsonObject isKindOfClass:NSArray.class])
        return [self mapToArray:jsonObject error:error];
    return [self mapToValue:jsonObject error:error];
}

+ (instancetype)mapToDictionary:(NSDictionary*)data error:(NSError**)error {
    // instantiate the object only here.
    NSObject* instance = [self alloc];
    if ([instance respondsToSelector:@selector(initForMap)])
        instance = [((id<JSONMapper>)instance) initForMap];
    else
        instance = [instance init];

    NSArray* properties = [instance properties];
    if (properties.count == 0)
        return data;

    for (Property* property in properties) {
        id value = nil;
        if ([self conformsToProtocol:@protocol(JSONMapper)]) {
            value = data[[((id<JSONMapper>)instance) remapPropertyName:property.name]];
        } else {
            value = data[property.name];
        }

        if (value == nil) // property is not in the json, ignore it.
            continue;

        BOOL valid = NO;
        if ([value isKindOfClass:NSDictionary.class]) {
            Class class = NSClassFromString(property.type);
            if ([class isSubclassOfClass:NSDictionary.class]) // treat as a dictionary.
                valid = [instance setProperty:property value:value error:error];
            else // map as an object
                valid = [instance setProperty:property value:[class map:value error:error] error:error];
        } else if ([value isKindOfClass:NSArray.class]) {
            // see how to create the instances of the corresponding type.
            valid = [instance setProperty:property
                                value:[NSClassFromString(property.subtype) map:value error:error]
                                error:error];
        } else {
            // assign the value to the property.
            valid = [instance setProperty:property value:value error:error];
        }

        if (!valid)
            return nil;
    }

    return instance;
}

- (BOOL)setProperty:(Property*)property value:(id)value error:(NSError**)error {
    // there is an error being dragged from a previous call.
    if (error != NULL && *error)
        return NO;

    // check if the property type and value type are compatible, if not, give an error and return.
    if (value == nil || ([self isValidArray:property value:value]) ||
        (![value isKindOfClass:NSArray.class] && NSClassFromString(property.type) != nil &&
         [value isKindOfClass:NSClassFromString(property.type)]) ||
        ([value isKindOfClass:@(YES).class] && [self isBoolean:property]) ||
        ([value isKindOfClass:NSNumber.class] && [self isIntegral:property]) ||
        ([value isKindOfClass:NSNumber.class] && [self isDecimal:property])) {
        // for special cases, a dictionary can contain complex objects under it
        if (![property.subtype isEqualToString:@"NSObject"] && [value isKindOfClass:NSDictionary.class]) {
            // create a dictionary
            NSMutableDictionary* dict = [NSMutableDictionary dictionary];
            for (NSString* key in [value allKeys]) {
                dict[key] = [NSClassFromString(property.subtype) map:value[key] error:error];
            }

            value = [NSClassFromString(property.type) dictionaryWithDictionary:dict]; // make it immutable
        }

        [self setValue:value forKey:property.name];

        return YES;
    }

    // it's not null, and not a primitive type, it can accept null values
    if (value != nil && [value isKindOfClass:NSNull.class] && ![self isBoolean:property] &&
        ![self isIntegral:property] && ![self isDecimal:property]) {
        return YES;
    }

    if (error != NULL) {
        NSDictionary* info = @{
            @"NSDebugDescription" : @"Property type doesn't match with the expected from the object.",
            @"class" : self.class.description,
            @"property" : property.name,
            @"type" : property.type,
            @"value" : value,
            @"value-type" : [value class].description
        };
        *error = [NSError errorWithDomain:@"JSONMapper" code:-500 userInfo:info];
    }

    return NO;
}

+ (instancetype)mapToArray:(NSArray*)data error:(NSError**)error {
    NSMutableArray* result = [NSMutableArray array];
    for (id item in data) {
        id value = [self map:item error:error];
        if (error != NULL && *error)
            return nil;
        [result addObject:value];
    }
    return result;
}

+ (instancetype)mapToValue:(id)data error:(NSError**)error {
    if (data == nil)
        return [NSNull new];
    return data;
}

- (BOOL)isValidArray:(Property*)property value:(id)value {
    // is not an array
    if (!([value isKindOfClass:NSArray.class] && [value isKindOfClass:NSClassFromString(property.type)]))
        return NO;

    // there is no subtype specified
    if (property.subtype == nil)
        return YES;

    // the array is empty => no inconsistencies
    if (((NSArray*)value).count == 0)
        return YES;

    // all elements are consistent
    for (id item in ((NSArray*)value))
        if (![item isKindOfClass:NSClassFromString(property.subtype)])
            return NO;

    return YES;
}

- (BOOL)isBoolean:(Property*)property {
    return [property.type hasPrefix:@"TB"] || [property.type hasPrefix:@"Tc"];
}

- (BOOL)isDecimal:(Property*)property {
    return [property.type hasPrefix:@"Tf"] || [property.type hasPrefix:@"Td"];
}

- (BOOL)isIntegral:(Property*)property {
    return [property.type hasPrefix:@"Ti"] || [property.type hasPrefix:@"Ts"] || [property.type hasPrefix:@"Tl"] ||
           [property.type hasPrefix:@"Tq"] || [property.type hasPrefix:@"TI"] || [property.type hasPrefix:@"TS"] ||
           [property.type hasPrefix:@"TL"] || [property.type hasPrefix:@"TQ"];
}

- (BOOL)isReservedProperty:(objc_property_t)prop {
    unsigned int propertyObjCount;
    const char* propName = property_getName(prop);
    objc_property_t* objList = class_copyPropertyList(NSObject.class, &propertyObjCount);
    for (int j = 0; j < propertyObjCount; j++) {
        if (strcmp(propName, property_getName(objList[j])) == 0) {
            free(objList);
            return YES;
        }
    }

    NSArray* reserved = @[ @"hash", @"description", @"debugDescription", @"superclass" ];
    for (NSString* keyword in reserved) {
        if (strcmp(propName, keyword.UTF8String) == 0) {
            free(objList);
            return YES;
        }
    }

    free(objList);
    return NO;
}

- (NSArray*)properties {
    NSMutableArray* properties = [NSMutableArray array];

    Class currentClass = self.class;
    while (currentClass && currentClass != NSObject.class) {
        unsigned int propertyCount;
        objc_property_t* list = class_copyPropertyList(currentClass, &propertyCount);

        for (int i = 0; i < propertyCount; i++) {
            objc_property_t prop = list[i];

            if ([self isReservedProperty:prop]) // reserved property
                continue;

            NSString* typeString = @(property_getAttributes(prop));
            NSArray* attributes = [typeString componentsSeparatedByString:@","];
            NSString* typeAttribute = attributes[0];
            NSString* subTypeString = @"NSObject";

            if ([typeAttribute hasPrefix:@"T@"]) {
                typeString = [typeAttribute substringWithRange:NSMakeRange(3, typeAttribute.length - 4)];
                Class typeClass = NSClassFromString(typeString);
                if (typeClass == nil) {
                    NSCharacterSet* set = [NSCharacterSet characterSetWithCharactersInString:@"<>"];
                    NSArray* tokens = [typeString componentsSeparatedByCharactersInSet:set];

                    typeString = tokens[0];
                    subTypeString = tokens[1];
                }
            }

            Property* property = [[Property alloc] init];
            property.name = @(property_getName(prop));
            property.type = typeString;
            property.subtype = subTypeString;
            [properties addObject:property];
        }

        free(list);

        // copy parent properties too.
        currentClass = class_getSuperclass(currentClass);
    }

    return properties;
}

- (NSString*)JSONString {
    if (self == nil || [self isKindOfClass:NSNull.class])
        return @"null";

    if ([self isKindOfClass:NSString.class])
        return [NSString stringWithFormat:@"\"%@\"", (NSString*)self];

    if ([self isKindOfClass:NSArray.class])
        return [self JSONStringFromArray];

    if ([self isKindOfClass:[NSDictionary class]])
        return [self JSONStringFromDictionary];

    return [self JSONStringFromObject];
}

- (NSString*)JSONString:(Property*)property {
    if ([self isBoolean:property]) {
        return ((NSNumber*)self).boolValue ? @"true" : @"false";
    } else if ([self isKindOfClass:NSNumber.class]) {
        return ((NSNumber*)self).stringValue;
    }

    return [self JSONString];
}

- (NSString*)JSONStringFromArray {
    NSMutableString* buffer = [NSMutableString string];
    [buffer appendString:@"["];
    for (id item in (NSArray*)self) {
        if (buffer.length > 1)
            [buffer appendString:@","];
        [buffer appendString:[item JSONString]];
    }
    [buffer appendString:@"]"];
    return buffer;
}

- (NSString*)JSONStringFromDictionary {
    NSDictionary* dic = (NSDictionary*)self;
    NSMutableString* buffer = [NSMutableString string];
    [buffer appendString:@"{"];
    for (NSString* key in dic.allKeys) {
        NSString* propertyName = key;
        if (buffer.length > 1)
            [buffer appendString:@","];
        id value = dic[propertyName];
        if (value == nil)
            value = [NSNull new];

        if ([self conformsToProtocol:@protocol(JSONMapper)])
            propertyName = [((id<JSONMapper>)self) remapPropertyName:propertyName];

        [buffer appendString:[NSString stringWithFormat:@"\"%@\": %@", propertyName, [value JSONString]]];
    }

    [buffer appendString:@"}"];
    return buffer;
}

- (NSString*)JSONStringFromObject {
    NSMutableString* buffer = [NSMutableString string];
    [buffer appendString:@"{"];
    for (Property* property in [self properties]) {
        if (buffer.length > 1)
            [buffer appendString:@","];
        id value = [self valueForKey:property.name];
        if (value == nil)
            value = [NSNull new];

        NSString* propertyName = property.name;
        if ([self conformsToProtocol:@protocol(JSONMapper)])
            propertyName = [((id<JSONMapper>)self) remapPropertyName:propertyName];

        [buffer appendString:[NSString stringWithFormat:@"\"%@\": %@", propertyName, [value JSONString:property]]];
    }
    [buffer appendString:@"}"];
    return buffer;
}

@end
