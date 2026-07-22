#import "Article.h"
#import "NSObject+Model.h" // 导入分类

@implementation Article

- (NSString *)description {
    return [NSString stringWithFormat:@"<Article: %p>\n  title = %@\n  views = %ld\n  book = %@\n  authors = %@\n  publishDate = %@\n  isHot = %@",
            self, self.title, (long)self.views, self.book, self.authors, self.publishDate, self.isHot ? @"YES" : @"NO"];
}

// KVC 安全处理：防止 setValuesForKeysWithDictionary: 遇到未定义 key 时崩溃
- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    NSLog(@"[Article] 警告: 尝试设置未定义的键 '%@'，值: %@", key, value);
}

// KVC 安全处理：防止 valueForKey: 遇到未定义 key 时崩溃
- (id)valueForUndefinedKey:(NSString *)key {
    NSLog(@"[Article] 警告: 尝试获取未定义的键 '%@'", key);
    return nil;
}

#pragma mark - NSObject+Model 协议方法
// 字典 key 和模型属性名不一致的映射
+ (NSDictionary<NSString *, NSString *> *)modelCustomPropertyMapper {
    return @{
        // 如果字典中有 "id"，而模型属性是 "articleID"，则可以这样映射
        // @"articleID": @"id"
    };
}

// 数组属性中元素的模型类
+ (NSDictionary<NSString *, Class> *)modelContainerPropertyGenericClass {
    return @{
        @"authors": [Author class] // 指定 authors 数组中存放的是 Author 对象
    };
}

@end
