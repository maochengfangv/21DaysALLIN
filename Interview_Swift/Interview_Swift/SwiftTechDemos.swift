//
//  SwiftTechDemos.swift
//  Interview_Swift
//
//  Swift 面试核心技术要点 - 最少可运行 Demo 集合
//  🟢=验收通过  🔴=常见坑点  ⭐=面试要点  🟣=原理说明
//

import Foundation
import UIKit
import Combine
import SwiftUI
import CoreData

// MARK: ============================================================
// MARK: 🔷 Demo 1: Struct vs Class & COW 写时复制
// ================================================================
/// ⭐ 面试题：Swift 为什么推荐用 Struct？COW 是怎么实现的？
enum StructClassDemo {
    
    // 值类型：拷贝 = 深拷贝（语义上），实际存储通过 COW 优化
    struct UserStruct: CustomStringConvertible {
        var name: String
        var age: Int
        var description: String { "Struct[\(name), \(age)]" }
    }
    
    // 引用类型：拷贝 = 只拷贝指针，共享同一块内存
    class UserClass: CustomStringConvertible {
        var name: String
        var age: Int
        init(name: String, age: Int) { self.name = name; self.age = age }
        var description: String { "Class[\(name), \(age)]" }
    }
    
    static func run() {
        print("\n🟣 ========== Demo1: Struct vs Class & COW ==========")
        
        // ---- Struct: 值语义 ----
        var s1 = UserStruct(name: "张三", age: 25)
        var s2 = s1  // 值拷贝：语义上 s2 是独立副本
        s2.name = "李四"
        print("⭐ Struct 值语义: s1=\(s1), s2=\(s2)")
        assert(s1.name == "张三" && s2.name == "李四", "❌ Struct 值语义失败")
        print("🟢 Struct 值语义：验收通过")
        
        // ---- Class: 引用语义 ----
        let c1 = UserClass(name: "张三", age: 25)
        let c2 = c1  // 引用拷贝：指向同一块内存
        c2.name = "李四"
        print("⭐ Class 引用语义: c1=\(c1), c2=\(c2)")
        assert(c1.name == "李四" && c2.name == "李四", "❌ Class 引用语义失败")
        print("🟢 Class 引用语义：验收通过")
        
        // ---- COW 写时复制：Array 底层 ----
        var arr1 = [1, 2, 3]
        var arr2 = arr1
        print("🟣 COW 写入前: arr1 指针相同? ", terminator: "")
        arr1.withUnsafeBufferPointer { p1 in
            arr2.withUnsafeBufferPointer { p2 in
                print(p1.baseAddress == p2.baseAddress ? "✅ 共享存储" : "❌ 已独立")
            }
        }
        arr2.append(4)  // 触发写入 → 真正拷贝
        print("🟣 COW 写入后: arr1 指针相同? ", terminator: "")
        arr1.withUnsafeBufferPointer { p1 in
            arr2.withUnsafeBufferPointer { p2 in
                print(p1.baseAddress == p2.baseAddress ? "❌ 共享存储" : "✅ 已独立拷贝")
            }
        }
        print("🟢 COW 写时复制：验收通过")
    }
}

// MARK: ============================================================
// MARK: 🔷 Demo 2: Optional 深度解包
// ================================================================
/// ⭐ 面试题：if let / guard let / flatMap / ?? 的区别与适用场景
enum OptionalDemo {
    static func run() {
        print("\n🟣 ========== Demo2: Optional 深度解包 ==========")
        
        let nickname: String? = "   Swift   "
        
        // 1. if let：适合分支处理
        if let name = nickname {
            print("⭐ if let 解包: \(name)")
        }
        
        // 2. guard let：适合"早退出"，提升代码扁平度
        func process(_ name: String?) {
            guard let name = name, !name.isEmpty else {
                print("🔴 guard let 拦截：空值直接 return")
                return
            }
            print("⭐ guard let 解包后可继续使用: \(name)")
        }
        process(nickname)
        
        // 3. map：对包装值做变换，保持 Optional 壳（层数不变）
        let mapped = nickname.map { $0.count }
        print("⭐ map: 值=\(mapped ?? -1), 真实类型=\(type(of: mapped))")
        
        // 4. 🚩 面试高频坑：Int("123") 本身返回 Int?，用 map 会导致 二重壳！
        let numStr: String? = "123"
        let doubleWrapped = numStr.map { Int($0) }   // ❌ Int??
        let singleWrapped = numStr.flatMap { Int($0) } // ✅ Int?
        print("🔴 map + Int() 二重可选坑: \(type(of: doubleWrapped)) = \(doubleWrapped ?? nil)")
        print("🟢 flatMap + Int() 自动拍扁: \(type(of: singleWrapped)) = \(singleWrapped ?? -1)")
        
        // 5. flatMap：解包嵌套 Optional（二重可选 → 一重）
        let nested: String?? = "双层包装"
        let viaMap = nested.map { $0 }       // ❌ 层数不变：String??
        let viaFlatMap = nested.flatMap { $0 } // ✅ 压平一层：String?
        print("🔴 nested.map  结果类型: \(type(of: viaMap))")
        print("🟢 nested.flatMap 结果类型: \(type(of: viaFlatMap))")
        print("⭐ flatMap 解嵌套值: \(viaFlatMap ?? "空")")
        
        // 5. ?? 空合运算符：提供默认值
        let unknown: String? = nil
        print("⭐ ?? 默认值: \(unknown ?? "匿名用户")")
        
        // 6. Optional 链式调用
        let str: String? = "hello"
        let upper = str?.uppercased().appending("!")
        print("⭐ 链式调用: \(upper ?? "空")")
        
        print("🟢 Optional 解包：验收通过")
    }
}

// MARK: ============================================================
// MARK: 🔷 Demo 3: Enum 关联值 + 模式匹配
// ================================================================
/// ⭐ 面试题：Enum 相比 OC 增强了什么？递归 Enum 怎么用？
enum EnumDemo {
    // 关联值：每个 case 可以携带不同类型的参数
    enum NetworkResult {
        case success(data: Data, statusCode: Int)
        case failure(error: Error)
        case loading(progress: Float)
    }
    
    // 递归 Enum：间接引用自身
    indirect enum BinaryTree {
        case empty
        case node(value: Int, left: BinaryTree, right: BinaryTree)
    }
    
    enum APIError: Error {
        case networkError(code: Int, message: String)
        case parseError
        case unauthorized
    }
    
    static func run() {
        print("\n🟣 ========== Demo3: Enum 关联值 + 模式匹配 ==========")
        
        // 关联值用法
        let result: NetworkResult = .success(data: Data(), statusCode: 200)
        switch result {
        case .success(let data, let code) where code == 200:
            print("⭐ 关联值匹配: success data=\(data.count)bytes, code=\(code)")
        case .failure(let err):
            print("🔴 失败: \(err.localizedDescription)")
        case .loading(let p) where p > 0.5:
            print("⭐ 加载过半: \(p)")
        default: break
        }
        
        // if case let 简化匹配
        if case .success(let data, _) = result {
            print("⭐ if case let: data 大小 = \(data.count)")
        }
        
        // 递归 Enum：二叉树求和
        let tree: BinaryTree = .node(
            value: 1,
            left: .node(value: 2, left: .empty, right: .empty),
            right: .node(value: 3, left: .empty, right: .empty)
        )
        func sum(_ tree: BinaryTree) -> Int {
            switch tree {
            case .empty: return 0
            case .node(let v, let l, let r): return v + sum(l) + sum(r)
            }
        }
        print("⭐ 递归 Enum 二叉树求和: 1+2+3 = \(sum(tree))")
        assert(sum(tree) == 6, "❌ 二叉树求和失败")
        
        print("🟢 Enum 高级用法：验收通过")
    }
}

// MARK: ============================================================
// MARK: 🔷 Demo 4: 闭包 & 循环引用 & @escaping
// ================================================================
/// ⭐ 面试题：@escaping 什么意思？闭包循环引用怎么解决？
enum ClosureDemo {
    
    class NetworkManager {
        var completion: ((String) -> Void)?
        // @escaping：闭包逃逸出函数作用域，需要异步回调时必须标注
        func fetchData(completion: @escaping (String) -> Void) {
            self.completion = completion  // 保存到属性 → 逃逸
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                completion("网络数据返回")  // 异步执行 → 逃逸
            }
        }
        deinit { print("🔴 NetworkManager deinit") }
    }
    
    class ViewControllerSim {
        var name = "VC"
        var manager: NetworkManager?
        var data: String = ""
        // 🔴 循环引用：VC 强引用 manager → manager 强引用 closure → closure 强引用 VC
        func leakDemo() {
            manager = NetworkManager()
            manager?.fetchData { [weak self] result in  // ✅ weak self 打破循环
                guard let self = self else { return }
                self.data = result
                print("⭐ @escaping 闭包捕获数据: \(self.data)")
            }
        }
        deinit { print("🔴 ViewControllerSim deinit") }
    }
    
    static func run() {
        print("\n🟣 ========== Demo4: 闭包 & 循环引用 & @escaping ==========")
        var vc: ViewControllerSim? = ViewControllerSim()
        vc?.leakDemo()
        
        // 同步触发回调验证
        vc?.manager?.completion?("手动触发")
        print("⭐ 验证 data: \(vc?.data ?? "空")")
        
        vc = nil  // 释放 VC，观察 deinit 顺序
        print("🟢 若上面打印了两次 deinit 说明无循环引用：验收通过")
    }
}

// MARK: ============================================================
// MARK: 🔷 Demo 5: 错误处理 throw / Result
// ================================================================
/// ⭐ 面试题：throws / rethrows / Result<T,E> 的区别？
enum ErrorDemo {
    
    enum ValidationError: Error, LocalizedError {
        case emptyName
        case invalidAge(min: Int, max: Int)
        var errorDescription: String? {
            switch self {
            case .emptyName: return "名字不能为空"
            case .invalidAge(let min, let max): return "年龄必须在 \(min)~\(max) 之间"
            }
        }
    }
    
    // throws：函数内部可能抛出错误
    static func validateUser(name: String, age: Int) throws -> String {
        guard !name.isEmpty else { throw ValidationError.emptyName }
        guard (18...60).contains(age) else {
            throw ValidationError.invalidAge(min: 18, max: 60)
        }
        return "用户\(name)年龄\(age)校验通过"
    }
    
    // rethrows：参数闭包抛错时，函数才跟着抛错
    static func transform<T>(_ value: T, _ fn: (T) throws -> T) rethrows -> T {
        try fn(value)
    }
    
    static func run() {
        print("\n🟣 ========== Demo5: 错误处理 throw / Result ==========")
        
        // 1. do-catch 完整处理
        do {
            let result = try validateUser(name: "张三", age: 25)
            print("⭐ do-catch 正常: \(result)")
        } catch ValidationError.emptyName {
            print("🔴 名字空")
        } catch let ValidationError.invalidAge(min, max) {
            print("🔴 年龄非法 \(min)-\(max)")
        } catch {
            print("🔴 未知错误: \(error.localizedDescription)")
        }
        
        // 2. try?：错误 → nil
        let ok = try? validateUser(name: "张三", age: 25)
        let fail = try? validateUser(name: "", age: 0)
        print("⭐ try? 合法用户: \(ok ?? "nil"), 非法用户: \(String(describing: fail))")
        
        // 3. Result<T,E>：把错误包装成值，适合异步回调传递
        let asyncResult: Result<String, ValidationError> = .success("OK")
        switch asyncResult {
        case .success(let msg): print("⭐ Result 成功: \(msg)")
        case .failure(let err): print("🔴 Result 失败: \(err.localizedDescription)")
        }
        
        // 4. rethrows
        let doubled = try? transform(5) { $0 * 2 }
        print("⭐ rethrows 变换: \(doubled ?? -1)")
        
        print("🟢 错误处理：验收通过")
    }
}

// MARK: ============================================================
// MARK: 🔷 Demo 6: Protocol Extension & POP 面向协议编程
// ================================================================
/// ⭐ 面试题：POP 相比 OOP 优势是什么？协议扩展能提供默认实现？

// 协议 + 关联类型（必须在文件作用域声明）
protocol Stackable {
    associatedtype Element
    mutating func push(_ element: Element)
    mutating func pop() -> Element?
    func peek() -> Element?
}

// 协议扩展：提供默认实现（extension 只能在文件作用域）
extension Stackable {
    func peek() -> Element? { nil }  // 默认实现：遵循者可以不实现
    
    // 扩展方法：所有遵循者自动获得
    mutating func pushAll(_ elements: [Element]) {
        elements.forEach { push($0) }
    }
}

enum POPDemo {
    
    // Int 栈：只需实现 push/pop，peek 和 pushAll 由协议扩展提供
    struct IntStack: Stackable {
        typealias Element = Int
        private var items: [Int] = []
        mutating func push(_ element: Int) { items.append(element) }
        mutating func pop() -> Int? { items.popLast() }
        func peek() -> Int? { items.last }  // 覆写默认实现
    }
    
    // 协议作为类型约束（泛型约束 vs 存在类型 any）
    static func processStack<S: Stackable>(_ stack: inout S) where S.Element: Numeric {
        stack.pushAll([1, 2, 3] as! [S.Element])
    }
    
    static func run() {
        print("\n🟣 ========== Demo6: Protocol Extension & POP ==========")
        
        var stack = IntStack()
        stack.pushAll([10, 20, 30])  // ✅ 协议扩展方法
        print("⭐ POP pushAll: peek=\(stack.peek() ?? -1)")
        print("⭐ POP pop: \(stack.pop() ?? -1), \(stack.pop() ?? -1)")
        assert(stack.peek() == 10, "❌ 栈操作失败")
        
        print("🟢 POP 面向协议编程：验收通过")
    }
}

// MARK: ============================================================
// MARK: 🔷 Demo 7: Combine 响应式编程
// ================================================================
/// ⭐ 面试题：Publisher / Operator / Subject 是什么？和 RxSwift 区别？
enum CombineDemo {
    
    class FormViewModel: ObservableObject {
        @Published var username: String = ""
        @Published var password: String = ""
        @Published var isSubmitEnabled: Bool = false
        private var cancellables = Set<AnyCancellable>()
        
        init() {
            // 组合两个 Publisher → 映射 → 绑定
            Publishers.CombineLatest($username, $password)
                .map { !$0.isEmpty && $1.count >= 6 }
                .receive(on: DispatchQueue.main)
                .assign(to: \.isSubmitEnabled, on: self)
                .store(in: &cancellables)
        }
    }
    
    static func run() {
        print("\n🟣 ========== Demo7: Combine 响应式 ==========")
        
        var cancellables = Set<AnyCancellable>()
        
        // 1. 基础 Publisher + 链式 Operator
        [1, 2, 3, 4, 5].publisher
            .filter { $0 % 2 == 0 }  // 过滤偶数
            .map { $0 * $0 }          // 平方
            .sink { completion in
                print("⭐ Combine 完成: \(completion)")
            } receiveValue: { value in
                print("⭐ Combine 偶数平方: \(value)")
            }.store(in: &cancellables)
        
        // 2. CurrentValueSubject：有初始值的 Subject
        let subject = CurrentValueSubject<String, Never>("初始")
        subject.sink { print("⭐ Subject 订阅1: \($0)") }.store(in: &cancellables)
        subject.send("更新1")
        subject.send("更新2")
        
        // 3. @Published + ObservableObject（表单校验）
        // 🟣 触发 4 次日志原因：
        //   第1次 false → username @Published 初始化 emit("")
        //   第2次 false → password @Published 初始化 emit("")
        //   第3次 false → vm.username = "user" (password 仍为空 < 6位)
        //   第4次 true  → vm.password = "123456" (username非空 && ≥6位)
        let vm = FormViewModel()
        vm.$isSubmitEnabled
            .removeDuplicates()   // ✅ 连续相同值去重：避免初始 2 次 false 重复输出
            .sink { print("⭐ @Published 表单可提交: \($0)") }
           .store(in: &cancellables) 
        vm.username = "user"        // → emit user (pwd 空 → false，已去重不重复打)
        vm.password = "123456"      // ≥6位 → emit true
        
        // 4. 异步时序：Debounce 防抖
        let searchText = PassthroughSubject<String, Never>()
        searchText
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { print("⭐ Debounce 防抖搜索: \($0)") }
            .store(in: &cancellables)
        searchText.send("s"); searchText.send("sw"); searchText.send("swift")
        
        // 同步等待一下 debounce 执行
        RunLoop.main.run(until: Date() + 0.1)
        
        print("🟢 Combine：验收通过")
    }
}

// MARK: ============================================================
// MARK: 🔷 Demo 8: SwiftUI 声明式 UI
// ================================================================
/// ⭐ 面试题：@State / @Binding / @ObservedObject / @EnvironmentObject 区别？
enum SwiftUIDemo {
    
    // ViewModel: 必须是 class 并遵守 ObservableObject
    class CounterVM: ObservableObject {
        @Published var count = 0
    }
    
    // SwiftUI 声明式视图
    struct CounterView: View {
        // @State: 视图内部私有状态，struct 修饰后可变
        @State private var localCount = 0
        // @ObservedObject: 外部传入的 ViewModel，引用类型
        @ObservedObject var vm: CounterVM
        // @Binding: 父视图向子视图传递"读写绑定"
        @Binding var sharedValue: Int
        
        var body: some View {
            VStack(spacing: 16) {
                Text("@State 本地计数: \(localCount)")
                Button("+1 @State") { localCount += 1 }
                
                Text("@ObservedObject VM 计数: \(vm.count)")
                Button("+1 VM") { vm.count += 1 }
                
                Text("@Binding 共享值: \(sharedValue)")
                Button("+1 Binding") { sharedValue += 1 }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // 📌 关键：@Binding 必须绑定到真实的 @State 源
    // 新增一层容器 View 持有 @State（不能把 @State 放在函数局部变量里，要放在 struct View 里）
    struct StateHolderView: View {
        @StateObject private var vm = CounterVM()   // @StateObject：VC 持有的 ViewModel，生命周期随 View
        @State private var sharedSource: Int = 0     // ✅ 真·@State 源：SwiftUI 运行时托管的响应式变量
        
        var body: some View {
            // $sharedSource = 自动语法糖：把 @State<Int> 投影成 Binding<Int>
            CounterView(vm: vm, sharedValue: $sharedSource)
                .onChange(of: sharedSource) { _, newValue in
                    print("🟣 @Binding 真实触发(来自 @State onChange): sharedSource = \(newValue)")
                }
        }
    }
    
    // 容器 VC：把 SwiftUI 嵌入 UIKit
    static func makeHostingController() -> UIViewController {
        // ✅ 用 StateHolderView 承载 @State，不再用手动 Binding(get:set:) 绑普通局部变量
        let swiftUIView = StateHolderView()
        let host = UIHostingController(rootView: swiftUIView)
        host.title = "SwiftUI Demo"
        return host
    }
    
    static func run() {
        print("\n🟣 ========== Demo8: SwiftUI ==========")
        print("⭐ @State：struct 内部，View 私有，值类型，修改触发 body 重渲染")
        print("⭐ @Binding：$ 前缀语法糖，传递读写引用，父子双向同步")
        print("⭐ @ObservedObject：class ViewModel，@Published 属性变动通知订阅者")
        print("⭐ @EnvironmentObject：全局注入，跨层级共享，需要祖先先 inject")
        print("⚠️  点击上方『SwiftUI 演示』按钮查看实际渲染效果")
        print("🟢 SwiftUI 概念：验收通过")
    }
}

// MARK: ============================================================
// MARK: 🔷 Demo 9: CoreData 持久化
// ================================================================
/// ⭐ 面试题：CoreData 的并发注意事项？NSFetchedResultsController 作用？
enum CoreDataDemo {
    
    // 纯代码初始化 NSPersistentContainer（无需 .xcdatamodeld 即可 Demo）
    static func makeContainer() -> NSPersistentContainer {
        // 动态构建 ManagedObjectModel（In-Memory Store，不持久化到磁盘）
        let model = NSManagedObjectModel()
        
        // Person 实体
        let personEntity = NSEntityDescription()
        personEntity.name = "Person"
        personEntity.managedObjectClassName = "Person"
        
        let nameAttr = NSAttributeDescription()
        nameAttr.name = "name"
        nameAttr.attributeType = .stringAttributeType
        nameAttr.isOptional = false
        
        let ageAttr = NSAttributeDescription()
        ageAttr.name = "age"
        ageAttr.attributeType = .integer32AttributeType
        ageAttr.isOptional = false
        
        personEntity.properties = [nameAttr, ageAttr]
        model.entities = [personEntity]
        
        let container = NSPersistentContainer(name: "DemoModel", managedObjectModel: model)
        // 使用 In-Memory 存储：只在内存中，退出即清除，避免文件依赖
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { desc, err in
            if let err = err { fatalError("CoreData 加载失败: \(err)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }
    
    // 动态创建的 Person 实体，需要这个类定义
    class Person: NSManagedObject {
        @NSManaged var name: String
        @NSManaged var age: Int32
    }
    
    static func run() {
        print("\n🟣 ========== Demo9: CoreData In-Memory ==========")
        
        let container = makeContainer()
        let ctx = container.viewContext
        
        // 1. 插入
        let person = Person(entity: container.managedObjectModel.entitiesByName["Person"]!,
                            insertInto: ctx)
        person.name = "Swift学员"
        person.age = 28
        do {
            try ctx.save()
            print("⭐ CoreData 插入: \(person.name) 年龄\(person.age)")
        } catch {
            print("🔴 CoreData 插入失败: \(error)")
        }
        
        // 2. 查询
        let fetch = NSFetchRequest<Person>(entityName: "Person")
        fetch.predicate = NSPredicate(format: "age > %d", 20)
        do {
            let results = try ctx.fetch(fetch)
            print("⭐ CoreData 查询 (age>20): \(results.count) 条 → \(results.map { $0.name })")
            assert(results.count == 1, "❌ 查询失败")
        } catch {
            print("🔴 查询失败: \(error)")
        }
        
        // 3. ⭐ 并发规则：不能跨 Context 传 NSManagedObject，只能传 NSManagedObjectID
        let bgCtx = container.newBackgroundContext()
        let objectID = person.objectID
        bgCtx.perform {
            if let bgPerson = try? bgCtx.existingObject(with: objectID) as? Person {
                bgPerson.age = 99
                try? bgCtx.save()
                print("⭐ CoreData 后台 Context 修改 age→99 (通过 ObjectID 跨队列)")
            }
        }
        
        // 等待后台执行
        RunLoop.main.run(until: Date() + 0.05)
        print("⭐ 修改后主 Context 读取(自动合并): age=\(person.age)")
        
        print("🟢 CoreData：验收通过")
    }
}

// MARK: ============================================================
// MARK: 🔷 Demo 10: 泛型 + some/any + 关联类型
// ================================================================
/// ⭐ 面试题：some T 和 any T 的区别？什么是存在类型容器？
enum GenericsDemo {
    
    protocol Shape {
        var area: Double { get }
        func describe() -> String
    }
    
    struct Circle: Shape {
        let radius: Double
        var area: Double { .pi * radius * radius }
        func describe() -> String { "圆形 r=\(radius)" }
    }
    
    struct Square: Shape {
        let side: Double
        var area: Double { side * side }
        func describe() -> String { "方形 s=\(side)" }
    }
    
    // some T：不透明类型，编译期确定单一具体类型 → 性能好，可链式调用协议方法
    static func makeRandomShape() -> some Shape {
        return Circle(radius: 5)  // 只能返回一种确定的类型
    }
    
    // any T：存在类型，运行时可以装任意实现者 → 灵活但有性能开销
    static func makeShape(isCircle: Bool) -> any Shape {
        isCircle ? Circle(radius: 3) : Square(side: 4)
    }
    
    static func run() {
        print("\n🟣 ========== Demo10: 泛型 + some vs any ==========")
        
        // some：编译期类型固定，返回值类型一致才能比较/运算
        let s1 = makeRandomShape()
        let s2 = makeRandomShape()
        print("⭐ some Shape: 面积和 = \(s1.area + s2.area)  (编译器已知是同类型)")
        
        // any：运行时类型擦除，放入异构数组必须用 any
        let shapes: [any Shape] = [Circle(radius: 1), Square(side: 2), Circle(radius: 3)]
        let total = shapes.map { $0.area }.reduce(0, +)
        print("⭐ [any Shape] 异构数组总面积: \(total)")
        shapes.forEach { print("   - \($0.describe())") }
        
        // 泛型约束写法对比
        func sameTypeConstraint<S: Shape>(_ s: S) { print("⭐ 泛型约束: \(type(of: s))") }
        sameTypeConstraint(Circle(radius: 1))
        
        print("🟢 泛型 some/any：验收通过")
    }
}
