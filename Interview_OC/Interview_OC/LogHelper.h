//
//  LogHelper.h
//  Interview_OC
//
//  Created by maochengfang on 2026/7/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LogHelper : NSObject

// 打印数组（支持中文）
+ (void)logArray:(NSArray *)array withLabel:(NSString *)label;

// 打印字典（支持中文）
+ (void)logDictionary:(NSDictionary *)dictionary withLabel:(NSString *)label;

// 打印对象描述（支持中文）
+ (void)logObject:(id)object withLabel:(NSString *)label;

// 漂亮的打印数组
+ (void)prettyLogArray:(NSArray *)array label:(NSString *)label;

// 漂亮的打印字典
+ (void)prettyLogDictionary:(NSDictionary *)dictionary label:(NSString *)label;

// 设置全局日志选项
+ (void)setUnicodeEncodingEnabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
