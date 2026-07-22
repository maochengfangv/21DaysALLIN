//
//  Person.h
//  Interview_OC
//
//  Created by maochengfang on 2026/7/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Person : NSObject
{
    NSString *_privateVar;
    NSInteger _privateNumber;
}
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, copy) NSString *address;
@property (nonatomic, strong) NSMutableArray<NSString *> *hobbies;

@property (nonatomic, readonly) NSString *readOnlyStr;

- (instancetype)initWithName:(NSString *)name age:(NSInteger)age;

@property (nonatomic, assign) NSInteger score;

@property (nonatomic, strong) NSNumber *cc;

@end

NS_ASSUME_NONNULL_END
