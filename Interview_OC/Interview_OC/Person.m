//
//  Person.m
//  Interview_OC
//
//  Created by maochengfang on 2026/7/22.
//

#import "Person.h"

@implementation Person

- (instancetype)initWithName:(NSString *)name age:(NSInteger)age{
    self = [super init];
    if (self) {
        _name = [name copy];
        _age = age;
        _hobbies = [NSMutableArray array];
        _privateVar = @"初始私有值";
        _privateNumber = 100;
    }
    return  self;
}

// 重写 description 方便打印
- (NSString *)description {
    return [NSString stringWithFormat:@"Person: name=%@, age=%ld, address=%@, hobbies=%@, privateVar=%@, privateNumber=%ld, score=%ld",
            _name, (long)_age, _address, _hobbies, _privateVar, (long)_privateNumber, (long)_score];
}

// 安全处理未定义的键
- (void)setValue:(id)value forUndefinedKey:(NSString *)key{
    NSLog(@"警告: 尝试设置未定义的键 '%@'，值: %@", key, value);
    // 可以选择记录日志、忽略或抛出异常
    // 这里我们选择忽略并记录日志
}

// 安全处理获取未定义的键
- (id)valueForUndefinedKey:(NSString *)key {
    NSLog(@"警告: 尝试获取未定义的键 '%@'", key);
    return nil;
}

@end
