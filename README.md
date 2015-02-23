# oc-json-mapper
Yet another Objective-C JSON mapper object.

## Installation
* Clone this repo, copy the OCJSONMapper folder into your project, or, include this project as a gitsubmodule.
* Open Xcode and add the folders to your project and target(s).
* Add the "Other linker flags" `-ObjC`

## Usage
This project was created to keep it as simple as possible, so it relies on conventions over configurations.

Define the properties in your class:
```
@protocol Child //first convention, a protocol let you say the type of the collection later on
@end
@interface Child : NSObject
@property (strong, nonatomic) NSString* name;
@end

@interface RootObject : NSObject
@property (assign, nonatomic) int id;
@property (strong, nonatomic) NSString* name;
@property (strong, nonatomic) NSArray<Child>* children; //use protocols to tell the type of the contained objects.
@end
```

Assume you have the following JSON object:
```
{"id":1, "name":"root object", "children": [{"name":"joe"}, {"name":"jane"}] }
```

In your code:
```
#import "NSObject+JSONMapper.h"

// retrieve the JSON object from somewhere
NSData* jsonData = [NSData dataWithBytes:str.UTF8String length:str.length];

// parse the JSON string
id json = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];

// create an object from the json object.
RootObject* root = [RootObject map:json];

// access the properties of the rootObject as normally
NSLog(@"Root.id: %d", root.id);

// access the chain of properties
NSLog(@"Childs: %@, %@", root.children[0].name, root.children[1].name);

// get the JSON representation any object with properties (KVC compliant)
NSLog(@"Into JSON: %@", [root JSONString]);

```



