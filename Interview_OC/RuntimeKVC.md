
## 1. 概述

`NSObject+Model` 是一个基于 Runtime + KVC 封装的字典转模型工具分类，解决纯 KVC（`setValuesForKeysWithDictionary:`）在字典转模型场景中的四大核心缺陷：

| 缺陷 | 纯 KVC 表现 | NSObject+Model 解决方案 |
|------|-------------|------------------------|
| 不支持嵌套模型 | 字典属性无法转换为子模型对象 | 递归调用 `modelWithDictionary:` 自动转换 |
| 不支持数组模型 | 数组中的字典元素无法转换为模型对象 | 通过 `modelContainerPropertyGenericClass` 指定元素类型，自动转换 |
| 类型转换容错差 | 类型不匹配时可能导致崩溃 | 按属性类型分派，try-catch 保护，基本类型与 NSString/NSNumber 兜底 |
| 无 key 校验易崩溃 | 未实现 `setValue:forUndefinedKey:` 时直接崩溃 | 仅处理模型已有属性，多余 key 直接忽略 |

## 2. 文件结构

```
Interview_OC/
├── NSObject+Model.h          # 公开 API 头文件
└── NSObject+Model.m          # 核心实现（Runtime + KVC）
```

## 3. 依赖

- `#import <Foundation/Foundation.h>`
- `#import <objc/runtime.h>` — 用于 `class_copyPropertyList`、`property_getName`、`property_getAttributes` 等 Runtime 函数

## 4. 架构设计

### 4.1 整体流程

```mermaid
flowchart TD
    A[modelWithDictionary:] --> B{字典校验}
    B -->|nil 或非字典| C[return nil]
    B -->|合法字典| D[alloc init 创建模型]
    D --> E[获取 modelCustomPropertyMapper 映射]
    D --> F[获取 modelContainerPropertyGenericClass 映射]
    E --> G[遍历所有属性 PropertyInfo]
    F --> G
    G --> H{属性类型?}
    H -->|isObjc 对象| I{是数组?}
    H -->|基本数据类型| J[@try KVC 赋值]
    I -->|是| K{有 genericMapper?}
    I -->|否| L{是自定义对象?}
    K -->|有| M[遍历数组元素，递归 modelWithDictionary:]
    K -->|无| N[直接 KVC 赋值]
    L -->|是| O[递归 modelWithDictionary:]
    L -->|否 (NSString/NSNumber/NSDate)| P[@try KVC 赋值]
    M --> Q[return model]
    N --> Q
    O --> Q
    P --> Q
    J --> Q

    style A fill:#c8e6c9,color:#1a5e20
    style M fill:#bbdefb,color:#0d47a1
    style O fill:#bbdefb,color:#0d47a1
    style B fill:#fff3e0,color:#e65100
```

### 4.2 核心数据结构

```c
typedef struct {
    char *name;           // 属性名，如 "title"
    char *typeEncoding;   // 原始类型编码，如 "T@"NSString",&,N,V_title"
    Class  cls;           // 属性类，如 NSString.class
    BOOL   isObjc;        // 是否为 OC 对象（id 类型）
    BOOL   isArray;       // 是否为 NSArray / NSMutableArray
    Class  genericCls;    // 数组元素类型（暂未使用，预留扩展）
} PropertyInfo;
```

属性信息缓存在全局静态字典 `propertyCache` 中，以类名 `NSStringFromClass(self)` 为 key，`NSArray<NSValue *>` 为 value，避免重复遍历属性列表。

## 5. API 参考

### 5.1 核心方法

```objc
+ (instancetype)modelWithDictionary:(NSDictionary *)dictionary;
```

| 参数 | 类型 | 说明 |
|------|------|------|
| `dictionary` | `NSDictionary *` | 待转换的原始字典 |
| 返回值 | `instancetype` | 转换完成的模型实例，失败返回 nil |

**处理逻辑：**

1. 空值 / 非字典 → 返回 nil
2. 遍历模型所有 `@property`（含父类属性，直到 NSObject）
3. 根据 `modelCustomPropertyMapper` 映射字典 key → 模型属性名
4. 根据属性类型走不同分支：
   - **数组 + 有 generic 映射** → 递归转换每个元素
   - **自定义对象（非 NSString/NSNumber/NSDate）** → 递归调用 `modelWithDictionary:`
   - **基本对象类型 / 基本数据类型** → 直接 KVC 赋值（try-catch 保护）

### 5.2 可重写协议方法

#### modelCustomPropertyMapper

```objc
+ (nullable NSDictionary<NSString *, NSString *> *)modelCustomPropertyMapper;
```

**用途：** 当字典 key 与模型属性名不一致时提供映射关系。

**示例：**

```objc
// 服务端返回：{ "id": 1001, "desc": "描述文本" }
// 模型属性：articleID、descText

+ (NSDictionary<NSString *, NSString *> *)modelCustomPropertyMapper {
    return @{
        @"articleID": @"id",
        @"descText":  @"desc"
    };
}
```

#### modelContainerPropertyGenericClass

```objc
+ (nullable NSDictionary<NSString *, Class> *)modelContainerPropertyGenericClass;
```

**用途：** 指定数组属性中存放的模型类型。**缺省时数组元素保持原始字典，不会转换为模型。**

**示例：**

```objc
// Article 模型：
// @property NSArray<Author *> *authors;

+ (NSDictionary<NSString *, Class> *)modelContainerPropertyGenericClass {
    return @{
        @"authors": [Author class]
    };
}
```

### 5.3 内部私有方法

| 方法 | 说明 |
|------|------|
| `+_modelAllPropertyInfos` | 遍历类及父类所有 `@property`，解析类型编码，返回 `NSArray<NSValue *>`（缓存） |
| `+ (void)load` | 初始化 `propertyCache` 字典（dispatch_once 保证线程安全） |

## 6. 类型编码参考

Runtime `property_getAttributes` 返回的类型编码前缀：

| 编码 | 类型 | 示例 |
|------|------|------|
| `T@` | OC 对象 | `T@"NSString"` → NSString |
| `Ti` | int | |
| `Tq` | NSInteger / long long | |
| `TB` | BOOL | |
| `Tf` | float | |
| `Td` | double | |
| `Tc` | char | |
| `TS` | unsigned short | |

解析时通过 `T@` 判断 isObjc，通过类名 `NSArray` / `NSMutableArray` 判断 isArray。

## 7. 使用示例

### 7.1 模型定义

```objc
// Book.h
@interface Book : NSObject
@property (nonatomic, copy) NSString *bookName;
@property (nonatomic, assign) NSInteger price;
@end

// Author.h
@interface Author : NSObject
@property (nonatomic, copy) NSString *authorName;
@property (nonatomic, assign) NSInteger age;
@end

// Article.h
@interface Article : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) Book *book;               // 嵌套模型
@property (nonatomic, strong) NSArray<Author *> *authors; // 数组模型
@end
```

### 7.2 实现协议方法

```objc
// Article.m
+ (NSDictionary<NSString *, Class> *)modelContainerPropertyGenericClass {
    return @{ @"authors": [Author class] };
}
```

### 7.3 调用转换

```objc
NSDictionary *dict = @{
    @"title": @"深入理解 KVC",
    @"book":  @{ @"bookName": @"Objective-C 高级编程", @"price": @99 },
    @"authors": @[
        @{ @"authorName": @"张三", @"age": @30 },
        @{ @"authorName": @"李四", @"age": @35 }
    ]
};

Article *article = [Article modelWithDictionary:dict];
// article.book  →  Book 对象
// article.authors → NSArray<Author *>，每个元素都是 Author 对象
```

## 8. 边界条件与异常处理

| 场景 | 处理策略 |
|------|----------|
| 传入 nil | 返回 nil |
| 传入非字典类型 | 返回 nil |
| 字典值为 NSNull | 跳过该属性 |
| 字典 key 不在模型中 | 忽略，不会触发 `setValue:forUndefinedKey:` |
| 数组元素非字典 | 原样追加到目标数组 |
| 基本类型转换异常 | @try-@catch 捕获，打印日志，不崩溃 |
| 自定义对象属性值为非字典 | 跳过，不赋值 |

## 9. 已知局限

1. **不支持 NSArray 中存放基本类型（如 `NSArray<NSNumber *>`）** — 无需特殊处理，直接 KVC 赋值即可。
2. **不支持从 `NSMutableString` / `NSMutableDictionary` 等可变子类型自动转换** — 需手动赋值。
3. **类型编码解析未处理 `@` 后的协议部分**（如 `id<NSCoding>`），仅提取了类名。
4. **`genericCls` 字段暂未启用** — 当前通过 `modelContainerPropertyGenericClass` 返回的映射来获取数组元素类型。
5. **`malloc` 后 `free` 在循环内** — 每次属性解析都 malloc/free，高频调用下可考虑用栈数组优化。
6. **线程安全** — `propertyCache` 为全局静态字典，`dispatch_once` 仅保护初始化，但后续读写未加锁，在多线程并发创建不同模型时可能存在竞争（通常不会同时 `+modelWithDictionary:` 同一个类）。

## 10. 常见问题 FAQ

### Q1: 为什么数组模型转换必须在模型中实现 `modelContainerPropertyGenericClass`？

因为 Objective-C 的 `@property NSArray<Author *> *authors` 中 `<Author *>` 是编译器语法糖，运行时无法通过 `property_getAttributes` 获取到泛型信息。因此需要显式声明。

### Q2: 与 YYModel / MJExtension 的区别？

- **YYModel / MJExtension**：功能更完善（黑名单、白名单、NSCoding、JSONModel 等），性能优化（CoreFoundation 桥接、IMP 缓存）。
- **NSObject+Model**：轻量级教学实现，聚焦于 KVC 缺陷演示，约 200 行代码，适合理解 Runtime 字典转模型原理。

### Q3: 如何支持 JSON 字符串直接转模型？

```objc
+ (instancetype)modelWithJSON:(NSString *)jsonString {
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [self modelWithDictionary:dict];
}
```

### Q4: 如何处理父类属性？

`_modelAllPropertyInfos` 通过 `while` 循环向上遍历 `class_getSuperclass`，直到 NSObject，因此会包含所有父类中声明的 `@property`。

## 11. 维护与扩展建议

| 扩展方向 | 实现思路 |
|----------|----------|
| 支持 NSCoding | 新增 `modelEncodeWithCoder:` / `modelDecodeWithCoder:`，基于属性遍历序列化 |
| 属性黑白名单 | 新增 `+modelPropertyBlacklist` / `+modelPropertyWhitelist` 协议方法 |
| 模型转字典 | 基于属性遍历 + `valueForKey:` 反向转换 |
| 性能优化 | 使用 `CFDictionary` 替代 `@{}`，使用 `IMP` 缓存 setter 调用 |
| JSON 直接转换 | 封装 `NSJSONSerialization` 方法，参考 Q3 |
```