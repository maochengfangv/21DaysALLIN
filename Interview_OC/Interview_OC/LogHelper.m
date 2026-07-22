#import "LogHelper.h"

@implementation LogHelper

static BOOL _unicodeEncodingEnabled = NO;

+ (void)setUnicodeEncodingEnabled:(BOOL)enabled {
    _unicodeEncodingEnabled = enabled;
}

+ (void)logArray:(NSArray *)array withLabel:(NSString *)label {
    if (!array) {
        NSLog(@"%@: (nil)", label);
        return;
    }
    
    if (_unicodeEncodingEnabled) {
        // 使用 Unicode 编码显示
        NSLog(@"%@: %@", label, array);
    } else {
        // 使用 description 显示中文
        NSLog(@"%@: %@", label, [array description]);
    }
}

+ (void)logDictionary:(NSDictionary *)dictionary withLabel:(NSString *)label {
    if (!dictionary) {
        NSLog(@"%@: (nil)", label);
        return;
    }
    
    if (_unicodeEncodingEnabled) {
        NSLog(@"%@: %@", label, dictionary);
    } else {
        NSLog(@"%@: %@", label, [dictionary description]);
    }
}

+ (void)logObject:(id)object withLabel:(NSString *)label {
    if (!object) {
        NSLog(@"%@: (nil)", label);
        return;
    }
    
    NSLog(@"%@: %@", label, [object description]);
}

+ (void)prettyLogArray:(NSArray *)array label:(NSString *)label {
    NSLog(@"\n════════════════════════════════════════");
    NSLog(@"%@", label);
    NSLog(@"════════════════════════════════════════");
    
    if (!array || array.count == 0) {
        NSLog(@"  空数组");
    } else {
        for (NSInteger i = 0; i < array.count; i++) {
            id obj = array[i];
            if ([obj isKindOfClass:[NSString class]]) {
                NSLog(@"  [%ld] \"%@\"", (long)i, obj);
            } else {
                NSLog(@"  [%ld] %@", (long)i, obj);
            }
        }
    }
    
    NSLog(@"════════════════════════════════════════\n");
}

+ (void)prettyLogDictionary:(NSDictionary *)dictionary label:(NSString *)label {
    NSLog(@"\n════════════════════════════════════════");
    NSLog(@"%@", label);
    NSLog(@"════════════════════════════════════════");
    
    if (!dictionary || dictionary.count == 0) {
        NSLog(@"  空字典");
    } else {
        NSArray *sortedKeys = [[dictionary allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *key in sortedKeys) {
            id value = dictionary[key];
            if ([value isKindOfClass:[NSString class]]) {
                NSLog(@"  %@: \"%@\"", key, value);
            } else {
                NSLog(@"  %@: %@", key, value);
            }
        }
    }
    
    NSLog(@"════════════════════════════════════════\n");
}

@end
