//
//  ViewController.swift
//  LowLevelFoundDemo
//
//  Created by maochengfang on 2026/6/29.
//

import UIKit
import MachO

final class ViewController: UIViewController, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let introLabel = UILabel()

    private let machOTitleLabel = UILabel()
    private let machOActionButton = UIButton(type: .system)
    private let machOTextView = UITextView()

    private let forwardingTitleLabel = UILabel()
    private let forwardingActionButton = UIButton(type: .system)
    private let forwardingTextView = UITextView()

    private let runLoopTitleLabel = UILabel()
    private let runLoopActionButton = UIButton(type: .system)
    private let runLoopStopButton = UIButton(type: .system)
    private let runLoopStatusLabel = UILabel()
    private let runLoopDefaultLabel = UILabel()
    private let runLoopCommonLabel = UILabel()
    private let runLoopLogTextView = UITextView()
    private let trackingScrollView = UIScrollView()
    private let trackingStack = UIStackView()

    private let interviewTitleLabel = UILabel()
    private let interviewActionButton = UIButton(type: .system)
    private let interviewTextView = UITextView()

    private var defaultModeTimer: Timer?
    private var commonModeTimer: Timer?
    private var defaultModeTick = 0
    private var commonModeTick = 0
    private var runLoopEvents: [String] = []

    deinit {
        stopRunLoopDemo()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "LowLevelFoundDemo"

        buildUI()
        renderInitialContent()
    }

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 16

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        introLabel.font = .preferredFont(forTextStyle: .headline)
        introLabel.numberOfLines = 0
        introLabel.text = "底层基础独立小工程：Mach-O 段表解析、Objective-C 消息转发、RunLoop Mode 切换与面试实操题库。"

        machOTitleLabel.font = .preferredFont(forTextStyle: .headline)
        machOTitleLabel.text = "1. Mach-O 段表解析工具"
        machOActionButton.setTitle("Parse Main Executable", for: .normal)
        machOActionButton.addTarget(self, action: #selector(onParseMachO), for: .touchUpInside)
        configureTextView(machOTextView, height: 260)

        forwardingTitleLabel.font = .preferredFont(forTextStyle: .headline)
        forwardingTitleLabel.text = "2. 简单消息转发 Demo"
        forwardingActionButton.setTitle("Run Forwarding Demo", for: .normal)
        forwardingActionButton.addTarget(self, action: #selector(onRunForwardingDemo), for: .touchUpInside)
        configureTextView(forwardingTextView, height: 200)

        runLoopTitleLabel.font = .preferredFont(forTextStyle: .headline)
        runLoopTitleLabel.text = "3. RunLoop Mode 切换演示"
        runLoopActionButton.setTitle("Start RunLoop Demo", for: .normal)
        runLoopActionButton.addTarget(self, action: #selector(onStartRunLoopDemo), for: .touchUpInside)
        runLoopStopButton.setTitle("Stop Demo", for: .normal)
        runLoopStopButton.addTarget(self, action: #selector(onStopRunLoopDemo), for: .touchUpInside)

        runLoopStatusLabel.font = .preferredFont(forTextStyle: .subheadline)
        runLoopStatusLabel.numberOfLines = 0

        runLoopDefaultLabel.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        runLoopCommonLabel.font = .monospacedSystemFont(ofSize: 14, weight: .medium)

        configureTextView(runLoopLogTextView, height: 170)

        trackingScrollView.translatesAutoresizingMaskIntoConstraints = false
        trackingScrollView.showsHorizontalScrollIndicator = true
        trackingScrollView.backgroundColor = .secondarySystemBackground
        trackingScrollView.layer.cornerRadius = 12
        trackingScrollView.delegate = self
        NSLayoutConstraint.activate([
            trackingScrollView.heightAnchor.constraint(equalToConstant: 72)
        ])

        trackingStack.translatesAutoresizingMaskIntoConstraints = false
        trackingStack.axis = .horizontal
        trackingStack.spacing = 10
        trackingStack.alignment = .center
        trackingScrollView.addSubview(trackingStack)

        NSLayoutConstraint.activate([
            trackingStack.leadingAnchor.constraint(equalTo: trackingScrollView.contentLayoutGuide.leadingAnchor, constant: 12),
            trackingStack.trailingAnchor.constraint(equalTo: trackingScrollView.contentLayoutGuide.trailingAnchor, constant: -12),
            trackingStack.topAnchor.constraint(equalTo: trackingScrollView.contentLayoutGuide.topAnchor, constant: 12),
            trackingStack.bottomAnchor.constraint(equalTo: trackingScrollView.contentLayoutGuide.bottomAnchor, constant: -12),
            trackingStack.heightAnchor.constraint(equalTo: trackingScrollView.frameLayoutGuide.heightAnchor, constant: -24)
        ])

        for title in ["拖动这里", "观察 Default", "观察 Common", "Tracking 模式", "Main RunLoop", "UITrackingRunLoopMode", "RunLoopCommonModes", "Timer"] {
            trackingStack.addArrangedSubview(makeChip(title: title))
        }

        interviewTitleLabel.font = .preferredFont(forTextStyle: .headline)
        interviewTitleLabel.text = "4. 底层面试实操题库"
        interviewActionButton.setTitle("Load Question Bank", for: .normal)
        interviewActionButton.addTarget(self, action: #selector(onLoadInterviewBank), for: .touchUpInside)
        configureTextView(interviewTextView, height: 320)

        let runLoopButtons = UIStackView(arrangedSubviews: [runLoopActionButton, runLoopStopButton])
        runLoopButtons.axis = .horizontal
        runLoopButtons.spacing = 12
        runLoopButtons.distribution = .fillEqually

        contentStack.addArrangedSubview(makeSection([
            introLabel
        ]))
        contentStack.addArrangedSubview(makeSection([
            machOTitleLabel,
            machOActionButton,
            machOTextView
        ]))
        contentStack.addArrangedSubview(makeSection([
            forwardingTitleLabel,
            forwardingActionButton,
            forwardingTextView
        ]))
        contentStack.addArrangedSubview(makeSection([
            runLoopTitleLabel,
            runLoopStatusLabel,
            runLoopDefaultLabel,
            runLoopCommonLabel,
            runLoopButtons,
            trackingScrollView,
            runLoopLogTextView
        ]))
        contentStack.addArrangedSubview(makeSection([
            interviewTitleLabel,
            interviewActionButton,
            interviewTextView
        ]))
    }

    private func makeSection(_ views: [UIView]) -> UIView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = 10
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        stack.layer.cornerRadius = 14
        stack.layer.borderColor = UIColor.separator.cgColor
        stack.layer.borderWidth = 1
        return stack
    }

    private func makeChip(title: String) -> UIView {
        let label = PaddingLabel()
        label.text = title
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .label
        label.backgroundColor = .systemBackground
        label.layer.cornerRadius = 10
        label.layer.borderWidth = 1
        label.layer.borderColor = UIColor.separator.cgColor
        label.clipsToBounds = true
        return label
    }

    private func configureTextView(_ textView: UITextView, height: CGFloat) {
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isEditable = false
        textView.layer.cornerRadius = 10
        textView.backgroundColor = .secondarySystemBackground
        NSLayoutConstraint.activate([
            textView.heightAnchor.constraint(equalToConstant: height)
        ])
    }

    private func renderInitialContent() {
        machOTextView.text = "点击 Parse Main Executable 读取主二进制的 load commands / segment / section 概览。"
        forwardingTextView.text = "点击 Run Forwarding Demo 观察 Objective-C runtime 的动态方法解析、快速转发、完整转发。"
        renderRunLoopStatus()
        runLoopLogTextView.text = "点击 Start RunLoop Demo 后，水平拖动上方区域。\n预期：Default timer 在 tracking 期间暂停，Common timer 继续增长。"
        interviewTextView.text = renderInterviewBank()
    }

    @objc private func onParseMachO() {
        machOTextView.text = renderMachOReport()
    }

    @objc private func onRunForwardingDemo() {
        forwardingTextView.text = runForwardingDemo()
    }

    @objc private func onStartRunLoopDemo() {
        startRunLoopDemo()
    }

    @objc private func onStopRunLoopDemo() {
        stopRunLoopDemo()
        renderRunLoopStatus()
    }

    @objc private func onLoadInterviewBank() {
        interviewTextView.text = renderInterviewBank()
    }

    private func startRunLoopDemo() {
        // 这个 demo 的关键是并排放两个 Timer：
        // 1. default mode timer 只在 kCFRunLoopDefaultMode 下触发
        // 2. common mode timer 被加入 RunLoopCommonModes，切到 tracking mode 时仍可继续触发
        stopRunLoopDemo()
        defaultModeTick = 0
        commonModeTick = 0
        runLoopEvents.removeAll()

        appendRunLoopLog("run loop demo started")
        appendRunLoopLog("拖动上方横向 scroll view 时，主线程 RunLoop 会进入 UITrackingRunLoopMode。")

        let defaultTimer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.defaultModeTick += 1
            self.renderRunLoopStatus()
        }
        RunLoop.main.add(defaultTimer, forMode: .default)
        self.defaultModeTimer = defaultTimer

        let commonTimer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.commonModeTick += 1
            self.renderRunLoopStatus()
        }
        RunLoop.main.add(commonTimer, forMode: .common)
        self.commonModeTimer = commonTimer

        renderRunLoopStatus()
    }

    private func stopRunLoopDemo() {
        defaultModeTimer?.invalidate()
        defaultModeTimer = nil
        commonModeTimer?.invalidate()
        commonModeTimer = nil
    }

    private func renderRunLoopStatus() {
        let isRunning = defaultModeTimer != nil || commonModeTimer != nil
        runLoopStatusLabel.text = isRunning ? "状态：演示运行中。请拖动横向区域观察 mode 切换。" : "状态：演示已停止。"
        runLoopDefaultLabel.text = "default mode ticks: \(defaultModeTick)"
        runLoopCommonLabel.text = "common mode ticks: \(commonModeTick)"
    }

    private func appendRunLoopLog(_ line: String) {
        runLoopEvents.append(line)
        if runLoopEvents.count > 12 {
            runLoopEvents.removeFirst(runLoopEvents.count - 12)
        }
        runLoopLogTextView.text = runLoopEvents.joined(separator: "\n")
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView === trackingScrollView else { return }
        appendRunLoopLog("begin dragging -> RunLoop 切到 UITrackingRunLoopMode，default timer 预计暂停。")
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView === trackingScrollView else { return }
        appendRunLoopLog("end dragging -> 即将回到 default/common mode。")
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === trackingScrollView else { return }
        appendRunLoopLog("end decelerating -> main run loop 回到默认处理路径。")
    }

    private func runForwardingDemo() -> String {
        // Swift 不直接参与消息转发链路细节，而是通过 runtime 反射找到 Objective-C 类，
        // 再用 perform 触发 demo，保证展示的是标准 ObjC message forwarding 行为。
        guard let cls = NSClassFromString("LFForwardingEntry") as? NSObject.Type else {
            return "找不到 Objective-C runtime 示例类 LFForwardingEntry。\n请确认 LFForwardingEntry.m 已编译进 target。"
        }

        let instance = cls.init()
        let selector = NSSelectorFromString("runDemo")
        guard instance.responds(to: selector) else {
            return "LFForwardingEntry 未响应 runDemo。"
        }

        let result = instance.perform(selector)?.takeUnretainedValue() as? String
        return result ?? "消息转发 demo 未返回结果。"
    }

    private func renderMachOReport() -> String {
        var lines: [String] = []
        let imageCount = _dyld_image_count()
        lines.append("dyld image count: \(imageCount)")

        guard let executablePath = Bundle.main.executablePath else {
            return "无法读取主程序 executablePath。"
        }

        let executableName = URL(fileURLWithPath: executablePath).lastPathComponent
        var matchIndex: UInt32?
        for index in 0..<imageCount {
            guard let cName = _dyld_get_image_name(index) else { continue }
            let path = String(cString: cName)
            if path == executablePath || path.hasSuffix("/\(executableName)") {
                matchIndex = index
                break
            }
        }

        guard let imageIndex = matchIndex, let headerPointer = _dyld_get_image_header(imageIndex) else {
            return "没有在 dyld image list 中找到主可执行文件。"
        }

        let magic = headerPointer.pointee.magic
        guard magic == MH_MAGIC_64 || magic == MH_CIGAM_64 else {
            return "当前 demo 仅处理 64-bit Mach-O，实际 magic = \(magic)。"
        }

        let header = UnsafeRawPointer(headerPointer).assumingMemoryBound(to: mach_header_64.self)
        let slide = _dyld_get_image_vmaddr_slide(imageIndex)
        lines.append("image: \(executablePath)")
        lines.append("slide: \(formatHex(UInt64(bitPattern: Int64(slide))))")
        lines.append("ncmds: \(header.pointee.ncmds), sizeofcmds: \(header.pointee.sizeofcmds)")
        lines.append("")

        // Mach-O header 后面紧跟着一串 load commands。
        // 这里按 cmdsize 线性推进指针，只挑 LC_SEGMENT_64 做段表展示。
        var cursor = UnsafeRawPointer(header).advanced(by: MemoryLayout<mach_header_64>.size)
        var segmentCount = 0

        for _ in 0..<Int(header.pointee.ncmds) {
            let loadCommand = cursor.assumingMemoryBound(to: load_command.self).pointee

            if loadCommand.cmd == UInt32(LC_SEGMENT_64) {
                let segment = cursor.assumingMemoryBound(to: segment_command_64.self).pointee
                segmentCount += 1

                let segmentName = fixedWidthString(from: segment.segname)
                lines.append("[\(segmentCount)] \(segmentName.isEmpty ? "<unnamed>" : segmentName)")
                lines.append("  vmaddr=\(formatHex(segment.vmaddr)) vmsize=\(formatHex(segment.vmsize)) fileoff=\(formatHex(segment.fileoff)) nsects=\(segment.nsects)")

                // segment_command_64 后面紧跟 section_64 数组，所以继续顺序解析 section。
                var sectionCursor = cursor.advanced(by: MemoryLayout<segment_command_64>.size)
                let sectionLimit = min(Int(segment.nsects), 6)
                for _ in 0..<sectionLimit {
                    let section = sectionCursor.assumingMemoryBound(to: section_64.self).pointee
                    let sectionName = fixedWidthString(from: section.sectname)
                    let ownerSegmentName = fixedWidthString(from: section.segname)
                    lines.append("    - \(ownerSegmentName)/\(sectionName) addr=\(formatHex(section.addr)) size=\(formatHex(section.size))")
                    sectionCursor = sectionCursor.advanced(by: MemoryLayout<section_64>.size)
                }

                if segment.nsects > 6 {
                    lines.append("    ...")
                }
            }

            cursor = cursor.advanced(by: Int(loadCommand.cmdsize))
        }

        lines.append("")
        lines.append("说明：")
        lines.append("1. Mach-O 头后面是连续的 load commands。")
        lines.append("2. 段表解析重点看 LC_SEGMENT_64 / segment_command_64 / section_64。")
        lines.append("3. 面试里常问 __TEXT、__DATA_CONST、__LINKEDIT 的作用与 dyld slide 含义。")
        return lines.joined(separator: "\n")
    }

    private func renderInterviewBank() -> String {
        return """
        题库（每个考点配套当前工程内可运行示例）：

        1. Mach-O 基础
        - 考点：mach_header_64、load_command、segment_command_64、section_64
        - 实操：点击 “Parse Main Executable”
        - 追问：__TEXT / __DATA / __LINKEDIT 分别承载什么

        2. dyld 与镜像装载
        - 考点：_dyld_image_count / _dyld_get_image_name / slide
        - 实操：解析主程序 image 与 slide
        - 追问：ASLR 为什么需要 slide

        3. Objective-C 消息转发
        - 考点：resolveInstanceMethod / forwardingTargetForSelector / forwardInvocation
        - 实操：点击 “Run Forwarding Demo”
        - 追问：三阶段谁优先、什么场景适合快速转发

        4. RunLoop Mode
        - 考点：default mode、UITrackingRunLoopMode、common modes
        - 实操：启动 RunLoop demo 后拖动横向 scroll view
        - 追问：为什么 NSTimer 在滑动 tableView 时会暂停

        5. Timer 与主线程卡顿
        - 考点：timer 加入哪个 mode 决定回调时机
        - 实操：对比 default timer 与 common timer 的 tick 差异
        - 追问：CADisplayLink 和 Timer 的使用边界

        6. 底层实操建议
        - 先复现：按钮触发 + 日志可见
        - 再观察：LLDB / Debug navigator / Instruments
        - 最后追源码：Runtime / dyld / CFRunLoop
        """
    }

    private func fixedWidthString<T>(from value: T) -> String {
        withUnsafeBytes(of: value) { rawBuffer in
            let prefix = rawBuffer.prefix { $0 != 0 }
            return String(decoding: prefix, as: UTF8.self)
        }
    }

    private func formatHex<T: BinaryInteger>(_ value: T) -> String {
        String(format: "0x%llx", UInt64(value))
    }
}

private final class PaddingLabel: UILabel {
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)))
    }

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        return CGSize(width: base.width + 20, height: base.height + 12)
    }
}
