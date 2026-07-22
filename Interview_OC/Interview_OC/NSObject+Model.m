#import "NSObject+Model.h"
#import <objc/runtime.h>

// 定义一个结构体来缓存属性信息
typedef struct {
    char *name; // 属性名
    char *typeEncoding; // 类型编码
    Class cls; // 属性的类
    BOOL isObjc; // 是否是 Objective-C 对象
    BOOL isArray; // 是否是数组
    Class genericCls; // 如果是数组，数组元素的类
} PropertyInfo;

// 缓存属性信息的字典
static NSMutableDictionary<NSString *, NSArray<NSValue *> *> *propertyCache;

@implementation NSObject (Model)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        propertyCache = [NSMutableDictionary dictionary];
    });
}

+ (instancetype)modelWithDictionary:(NSDictionary *)dictionary {
    if (!dictionary || ![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    id model = [[self alloc] init];
    
    // 获取属性映射
    NSDictionary<NSString *, NSString *> *mapper = nil;
    if ([self respondsToSelector:@selector(modelCustomPropertyMapper)]) {
        mapper = [self modelCustomPropertyMapper];
    }
    
    // 获取数组元素类型映射
    NSDictionary<NSString *, Class> *genericMapper = nil;
    if ([self respondsToSelector:@selector(modelContainerPropertyGenericClass)]) {
        genericMapper = [self modelContainerPropertyGenericClass];
    }

    // 遍历模型的所有属性
    NSArray<NSValue *> *propertyInfos = [self _modelAllPropertyInfos];
    for (NSValue *value in propertyInfos) {
        PropertyInfo propertyInfo;
        [value getValue:&propertyInfo];
        
        NSString *propertyName = [NSString stringWithUTF8String:propertyInfo.name];
        NSString *typeEncoding = [NSString stringWithUTF8String:propertyInfo.typeEncoding];
        Class propertyClass = propertyInfo.cls;
        BOOL isObjc = propertyInfo.isObjc;
        BOOL isArray = propertyInfo.isArray;
        Class genericCls = propertyInfo.genericCls;

        // 获取字典中对应的 key
        NSString *dictKey = propertyName;
        if (mapper && mapper[propertyName]) {
            dictKey = mapper[propertyName];
        }
        
        id valueFromDict = dictionary[dictKey];
        if (!valueFromDict || [valueFromDict isKindOfClass:[NSNull class]]) {
            continue; // 字典中没有这个 key 或者值为 NSNull
        }

        if (isObjc) { // Objective-C 对象类型
            if (isArray) { // 数组模型
                if ([valueFromDict isKindOfClass:[NSArray class]]) {
                    if (genericMapper && genericMapper[propertyName]) {
                        // 数组中包含自定义模型对象
                        Class itemClass = genericMapper[propertyName];
                        NSMutableArray *tempArray = [NSMutableArray array];
                        for (id itemDict in (NSArray *)valueFromDict) {
                            if ([itemDict isKindOfClass:[NSDictionary class]]) {
                                id itemModel = [itemClass modelWithDictionary:itemDict];
                                if (itemModel) {
                                    [tempArray addObject:itemModel];
                                }
                            } else {
                                // 如果数组元素不是字典，直接添加
                                [tempArray addObject:itemDict];
                            }
                        }
                        [model setValue:tempArray forKey:propertyName];
                    } else {
                        // 数组中包含基本类型或非自定义模型对象，直接赋值
                        [model setValue:valueFromDict forKey:propertyName];
                    }
                }
            } else if ([propertyClass isSubclassOfClass:[NSObject class]] && propertyClass != [NSString class] && propertyClass != [NSNumber class] && propertyClass != [NSDate class]) {
                // 嵌套模型
                if ([valueFromDict isKindOfClass:[NSDictionary class]]) {
                    id subModel = [propertyClass modelWithDictionary:valueFromDict];
                    if (subModel) {
                        [model setValue:subModel forKey:propertyName];
                    }
                }
            } else {
                // 基本对象类型（NSString, NSNumber, NSDate等），直接 KVC 赋值
                // KVC 对 NSString 和 NSNumber 有一定的类型转换容错
                @try {
                    [model setValue:valueFromDict forKey:propertyName];
                } @catch (NSException *exception) {
                    NSLog(@"[Model] 类型转换失败: 模型属性 '%@' 类型为 '%@'，字典值为 '%@' 类型为 '%@'. 异常: %@",
                          propertyName, propertyClass, valueFromDict, [valueFromDict class], exception);
                }
            }
        } else { // 基本数据类型 (int, float, BOOL, NSInteger等)
            // KVC 对基本数据类型和 NSNumber/NSString 之间有一定容错
            // 例如，字典中是 "123"，模型是 NSInteger，KVC 会自动转换
            // 字典中是 "YES"，模型是 BOOL，KVC 会自动转换
            @try {
                [model setValue:valueFromDict forKey:propertyName];
            } @catch (NSException *exception) {
                NSLog(@"[Model] 基本类型转换失败: 模型属性 '%@' 类型为 '%s'，字典值为 '%@' 类型为 '%@'. 异常: %@",
                      propertyName, propertyInfo.typeEncoding, valueFromDict, [valueFromDict class], exception);
            }
        }
    }
    
    return model;
}

// 缓存所有属性信息
+ (NSArray<NSValue *> *)_modelAllPropertyInfos {
    NSString *className = NSStringFromClass(self);
    NSArray<NSValue *> *cachedInfos = propertyCache[className];
    if (cachedInfos) {
        return cachedInfos;
    }
    
    NSMutableArray<NSValue *> *propertyInfos = [NSMutableArray array];
    
    Class currentClass = self;
    while (currentClass && currentClass != [NSObject class]) {
        unsigned int outCount = 0;
        objc_property_t *properties = class_copyPropertyList(currentClass, &outCount);
        
        for (unsigned int i = 0; i < outCount; i++) {
            objc_property_t property = properties[i];
            
            PropertyInfo info;
            info.name = (char *)property_getName(property);
            info.typeEncoding = (char *)property_getAttributes(property);
            info.cls = nil;
            info.isObjc = NO;
            info.isArray = NO;
            info.genericCls = nil;
            
            // 解析类型编码
            char *type = info.typeEncoding;
            while (*type != '\0' && *type != ',') {
                if (*type == 'T') { // 类型编码开始
                    type++;
                    if (*type == '@') { // Objective-C 对象
                        info.isObjc = YES;
                        type++;
                        if (*type == '"') { // 对象类型名
                            char *classNameStart = ++type;
                            char *classNameEnd = strchr(classNameStart, '"');
                            if (classNameEnd) {
                                size_t len = classNameEnd - classNameStart;
                                char *classNameCStr = (char *)malloc(len + 1);
                                strncpy(classNameCStr, classNameStart, len);
                                classNameCStr[len] = '\0';
                                info.cls = objc_getClass(classNameCStr);
                                free(classNameCStr);
                            }
                        }
                        // 检查是否是 NSArray
                        if (info.cls == [NSArray class] || info.cls == [NSMutableArray class]) {
                            info.isArray = YES;
                        }
                    } else { // 基本数据类型
                        // 例如：Ti, Tq, TB, Tf, Td
                        // KVC 可以处理这些基本类型
                    }
                }
                type++;
            }
            
            NSValue *value = [NSValue value:&info withObjCType:@encode(PropertyInfo)];
            [propertyInfos addObject:value];
        }
        free(properties);
        currentClass = class_getSuperclass(currentClass);
    }
    
    propertyCache[className] = propertyInfos;
    return propertyInfos;
}

// 默认实现，子类可重写
+ (nullable NSDictionary<NSString *, NSString *> *)modelCustomPropertyMapper {
    return nil;
}

// 默认实现，子类可重写
+ (nullable NSDictionary<NSString *, Class> *)modelContainerPropertyGenericClass {
    return nil;
}

@end
