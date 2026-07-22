//
//  Article.h
//  Interview_OC
//
//  Created by maochengfang on 2026/7/22.
//

#import <Foundation/Foundation.h>
#import "Book.h"
#import "Author.h"

NS_ASSUME_NONNULL_BEGIN

@interface Article : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) NSInteger views;
@property (nonatomic, strong) Book *book; // 嵌套模型
@property (nonatomic, strong) NSArray<Author *> *authors; // 数组模型
@property (nonatomic, copy) NSString *publishDate; // 字符串日期，测试类型转换
@property (nonatomic, assign) BOOL isHot; // 布尔值，测试类型转换

@end

NS_ASSUME_NONNULL_END
