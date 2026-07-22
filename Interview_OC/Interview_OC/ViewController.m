//
//  ViewController.m
//  Interview_OC
//
//  Created by maochengfang on 2026/7/22.
//

#import "ViewController.h"
#import "Person.h"
@interface ViewController ()

@property (nonatomic, strong) Person *person;

@property (nonatomic, strong) Person *kvoPerson;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.person = [[Person alloc] initWithName:@"11" age:11];
    // 2. 演示 KVC 的基本用法
    [self demonstrateBasicKVC];
    
    // 3. 演示字典与模型互转
    [self demonstrateDictionaryModelConversion];
    
    // 4. 演示动态赋值
    [self demonstrateDynamicAssignment];
        
    // 5. 演示操作私有成员变量
    [self demonstratePrivateVariableAccess];
        
    // 6. 演示配合 KVO 使用
    [self demonstrateKVOWithKVC];
}

#pragma mark - 1. KVC 基本用法
- (void)demonstrateBasicKVC {
    NSLog(@"\n=== 1. KVC 基本用法演示 ===");
    // 使用 KVC 设置属性值
    [self.person setValue:@"Oliver" forKey:@"name"];
    [self.person setValue:@30 forKey:@"age"];
    
    NSString *name = [self.person valueForKey:@"name"];
    NSNumber *age = [self.person valueForKey:@"age"];
    NSLog(@"设置后: name=%@, age=%@", name, age);
    
    // 设置嵌套属性（如果 Person 有子对象）
    
    [self.person setValue:@"北京朝阳区" forKeyPath:@"address"];
    
    NSString *address = [self.person valueForKeyPath:@"address"];
    
    NSLog(@"设置后: address=%@", address);
}

#pragma mark - 2. 字典与模型互转
- (void)demonstrateDictionaryModelConversion {
    NSLog(@"\n=== 2. 字典与模型互转演示 ===");
        
    // 2.1 字典转模型
    
    NSDictionary *personDict = @{
           @"name": @"王五",
           @"age": @28,
           @"address": @"上海市浦东新区",
           @"hobbies": @[@"篮球", @"游泳", @"阅读"]
       };
    Person *personFromDict = [[Person alloc] init];
    [personFromDict setValuesForKeysWithDictionary:personDict];
    NSLog(@"字典转模型结果: %@", personFromDict);
    
    // 2.2 模型转字典
    
    NSDictionary *modelToDict = [personFromDict dictionaryWithValuesForKeys:@[@"name", @"age", @"address", @"hobbies"]];
    NSLog(@"模型转字典结果: %@", modelToDict);
    
    // 2.3 处理字典中有但模型没有的键
        NSDictionary *extraDict = @{
            @"name": @"赵六",
            @"age": @35,
            @"unknownKey": @"这个键模型中没有",
            @"address": @"广州市天河区"
        };
        
        Person *personWithExtra = [[Person alloc] init];
        @try {
            [personWithExtra setValuesForKeysWithDictionary:extraDict];
        } @catch (NSException *exception) {
            NSLog(@"捕获异常: %@", exception);
            // 安全处理：实现 setValue:forUndefinedKey: 方法
        }
}

#pragma mark - 3. 动态赋值
- (void)demonstrateDynamicAssignment {
    NSLog(@"\n=== 3. 动态赋值演示 ===");
    // 3.1 动态设置属性
    NSArray *propertyNames = @[@"name",@"age",@"address"];
    NSArray *propertyValues = @[@"动态名称",@40,@"动态地址"];
    
    for (NSInteger i = 0; i < propertyNames.count; i++) {
        NSString *key = propertyNames[i];
        id value = propertyValues[i];
        [self.person setValue:value forKey:key];
    }
    NSLog(@"动态赋值后: %@", self.person);
    
    // 3.2 动态调用集合方法
    NSArray *newHobbies = @[@"编程",@"音乐",@"旅行"];
    NSMutableArray *hobbies = [self.person mutableArrayValueForKey:@"hobbies"];
    [hobbies addObjectsFromArray:newHobbies];
    NSLog(@"添加爱好后: %@", self.person.hobbies);
    
    // 3.3 使用 KVC 进行集合操作
    NSArray *allNames = @[self.person.name,@"测试1",@"测试2"];
    NSArray *uppercasedNames = [allNames valueForKeyPath:@"uppercaseString"];
    NSLog(@"集合操作 - 大写转换: %@",  [uppercasedNames description]);
}

#pragma mark - 4. 操作私有成员变量
- (void)demonstratePrivateVariableAccess {
    NSLog(@"\n=== 4. 操作私有成员变量演示 ===");
    
    // 4.1 访问私有成员变量
    NSString *privateVar = [self.person valueForKey:@"privateVar"];
    NSNumber *privateNumber = [self.person valueForKey:@"privateNumber"];
    NSLog(@"访问私有变量: privateVar=%@, privateNumber=%@", privateVar, privateNumber);

    // 4.2 修改私有成员变量
    NSLog(@"修改前私有变量: privateVar=%@, privateNumber=%@", privateVar, privateNumber);
    
    [self.person setValue:@"修改后的私有值" forKey:@"privateVar"];
    [self.person setValue:@200 forKey:@"privateNumber"];
    
    // 4.3 重新获取修改后的值
    NSString *updatedPrivateVar = [self.person valueForKey:@"privateVar"];
    NSNumber *updatedPrivateNumber = [self.person valueForKey:@"privateNumber"];
    
    NSLog(@"修改后私有变量: privateVar=%@, privateNumber=%@", updatedPrivateVar, updatedPrivateNumber);
    
    // 4.4 验证局部变量和重新获取的值是否不同
    NSLog(@"对比 - 局部变量旧值: privateVar=%@, privateNumber=%@", privateVar, privateNumber);
    NSLog(@"对比 - 重新获取新值: privateVar=%@, privateNumber=%@", updatedPrivateVar, updatedPrivateNumber);
    
    // 4.4 访问不存在的私有变量（会触发异常）
       @try {
           id unknownValue = [self.person valueForKey:@"nonExistentPrivateVar"];
           NSLog(@"不存在的变量: %@", unknownValue);
       } @catch (NSException *exception) {
           NSLog(@"访问不存在的私有变量异常: %@", exception);
       }
}

#pragma mark - 5. 配合 KVO 使用
- (void)demonstrateKVOWithKVC {
    NSLog(@"\n=== 5. 配合 KVO 使用演示 ===");
    // 5.1 创建用于 KVO 观察的对象
    self.kvoPerson = [[Person alloc] initWithName:@"KVO测试" age:20];
    // 5.2 添加 KVO 观察
    [self.kvoPerson addObserver:self forKeyPath:@"score" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
    // 5.3 使用 KVC 触发 KVO
     NSLog(@"初始分数: %ld", (long)self.kvoPerson.score);
    
    // 通过 KVC 修改 score，会触发 KVO
    [self.kvoPerson setValue:@80 forKey:@"score"];
    NSLog(@"第一次修改后分数: %ld", (long)self.kvoPerson.score);
    
    // 再次修改
    [self.kvoPerson setValue:@90 forKey:@"score"];
    // 5.4 移除观察者
    [self.kvoPerson removeObserver:self forKeyPath:@"score"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if([keyPath isEqualToString:@"score"]) {
        NSNumber *oldValue = change[NSKeyValueChangeOldKey];
        NSNumber *newValue = change[NSKeyValueChangeNewKey];
        NSLog(@"KVO 触发 - %@: 从 %@ 变为 %@", keyPath, oldValue, newValue);
    }
}

- (void)dealloc {
    // 安全移除观察者
       @try {
           [self.kvoPerson removeObserver:self forKeyPath:@"score"];
       } @catch (NSException *exception) {
           // 观察者可能已经移除
       }
}

@end
