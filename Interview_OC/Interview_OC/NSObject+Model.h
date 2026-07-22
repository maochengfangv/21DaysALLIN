//
//  NSObject+Model.h
//  Interview_OC
//
//  Created by maochengfang on 2026/7/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (Model)

/**
 *  将字典转换为模型对象
 *
 *  @param dictionary 待转换的字典
 *
 *  @return 转换后的模型对象
 */

+ (instancetype)modelWithDictionary:(NSDictionary *)dictionary;

/**
 *  提供一个字典，用于指定模型属性名和字典 key 的映射关系。
 *  例如：@{@"ID": @"id", @"desc": @"description"}
 *  如果字典 key 和模型属性名不一致，可以在此方法中提供映射。
 *
 *  @return 映射字典
 */

+ (nullable NSDictionary<NSString *, NSString *> *)modelCustomPropertyMapper;

/**
 *  提供一个字典，用于指定数组属性中元素的模型类。
 *  例如：@{@"authors": [Author class], @"books": [Book class]}
 *  如果数组中包含自定义模型对象，需要在此方法中指定其类型。
 *
 *  @return 数组元素类型字典
 */

+ (nullable NSDictionary<NSString* , Class> *)modelContainerPropertyGenericClass;

@end

NS_ASSUME_NONNULL_END
