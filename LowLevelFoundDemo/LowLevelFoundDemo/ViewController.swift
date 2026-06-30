//
//  ViewController.swift
//  LowLevelFoundDemo
//
//  Created by maochengfang on 2026/6/29.
//

import UIKit
import MachO
import Darwin
import Darwin.Mach

private typealias DyldAddImageCallback = @convention(c) (UnsafePointer<mach_header>?, Int) -> Void

private let dyldEventQueue = DispatchQueue(label: "demo.dyld.events")
private var dyldAddImageEvents: [String] = []
private var dyldObserverRegistered = false
private let dyldStartAbsTime: UInt64 = mach_absolute_time()
private let dyldTimebase: mach_timebase_info_data_t = {
    var tb = mach_timebase_info_data_t()
    mach_timebase_info(&tb)
    return tb
}()

private func dyldNowMS() -> Double {
    let elapsed = mach_absolute_time() &- dyldStartAbsTime
    let nanos = Double(elapsed) * Double(dyldTimebase.numer) / Double(dyldTimebase.denom)
    return nanos / 1_000_000.0
}

private let dyldAddImageCallback: DyldAddImageCallback = { header, slide in
    let ms = dyldNowMS()
    var path = "(unknown)"
    if let header {
        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            if let h = _dyld_get_image_header(i), h == header {
                if let name = _dyld_get_image_name(i) {
                    path = String(cString: name)
                }
                break
            }
        }
    }

    dyldEventQueue.sync {
        dyldAddImageEvents.append(String(format: "%.3f ms add_image slide=0x%llx %@", ms, UInt64(bitPattern: Int64(slide)), path))
        if dyldAddImageEvents.count > 80 {
            dyldAddImageEvents.removeFirst(dyldAddImageEvents.count - 80)
        }
    }
}

private func ensureDyldObserverRegistered() {
    if dyldObserverRegistered { return }
    dyldObserverRegistered = true
    _dyld_register_func_for_add_image(dyldAddImageCallback)
}

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

    private let perfTitleLabel = UILabel()
    private let perfSnapshotButton = UIButton(type: .system)
    private let perfBenchmarkButton = UIButton(type: .system)
    private let perfCopyJSONButton = UIButton(type: .system)
    private let perfTextView = UITextView()

    private var lastPerfReportJSON: String = ""

    private let securityTitleLabel = UILabel()
    private let securityModeControl = UISegmentedControl(items: ["Real", "Demo"])
    private let securityInspectButton = UIButton(type: .system)
    private let securityCopyJSONButton = UIButton(type: .system)
    private let securityTextView = UITextView()

    private var lastJailbreakReportJSON: String = ""

    private let rolloutTitleLabel = UILabel()
    private let rolloutVariantControl = UISegmentedControl(items: ["Stable", "Canary"])
    private let rolloutFaultControl = UISegmentedControl(items: ["OK", "Fault"])
    private let rolloutApplyButton = UIButton(type: .system)
    private let rolloutResetButton = UIButton(type: .system)
    private let rolloutStatusLabel = UILabel()
    private let rolloutTextView = UITextView()

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

        ensureDyldObserverRegistered()
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

        perfTitleLabel.font = .preferredFont(forTextStyle: .headline)
        perfTitleLabel.text = "5. 启动/首帧性能（dyld 工作量）"
        perfSnapshotButton.setTitle("Snapshot dyld Workload", for: .normal)
        perfSnapshotButton.addTarget(self, action: #selector(onPerfSnapshot), for: .touchUpInside)
        perfBenchmarkButton.setTitle("Benchmark dlopen (Lazy vs Now)", for: .normal)
        perfBenchmarkButton.addTarget(self, action: #selector(onPerfBenchmark), for: .touchUpInside)
        perfCopyJSONButton.setTitle("Copy JSON", for: .normal)
        perfCopyJSONButton.addTarget(self, action: #selector(onPerfCopyJSON), for: .touchUpInside)
        configureTextView(perfTextView, height: 240)

        securityTitleLabel.font = .preferredFont(forTextStyle: .headline)
        securityTitleLabel.text = "6. 安全与签名（段权限/代码签名信息）"

        securityModeControl.selectedSegmentIndex = 0
        securityModeControl.addTarget(self, action: #selector(onSecurityModeChanged), for: .valueChanged)

        securityInspectButton.setTitle("Inspect", for: .normal)
        securityInspectButton.addTarget(self, action: #selector(onSecurityInspect), for: .touchUpInside)

        securityCopyJSONButton.setTitle("Copy JSON", for: .normal)
        securityCopyJSONButton.addTarget(self, action: #selector(onSecurityCopyJSON), for: .touchUpInside)

        configureTextView(securityTextView, height: 260)

        let runLoopButtons = UIStackView(arrangedSubviews: [runLoopActionButton, runLoopStopButton])
        runLoopButtons.axis = .horizontal
        runLoopButtons.spacing = 12
        runLoopButtons.distribution = .fillEqually

        let perfButtons = UIStackView(arrangedSubviews: [perfSnapshotButton, perfBenchmarkButton, perfCopyJSONButton])
        perfButtons.axis = .horizontal
        perfButtons.spacing = 12
        perfButtons.distribution = .fillEqually

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

        contentStack.addArrangedSubview(makeSection([
            perfTitleLabel,
            perfButtons,
            perfTextView
        ]))

        let securityButtons = UIStackView(arrangedSubviews: [securityInspectButton, securityCopyJSONButton])
        securityButtons.axis = .horizontal
        securityButtons.spacing = 12
        securityButtons.distribution = .fillEqually

        contentStack.addArrangedSubview(makeSection([
            securityTitleLabel,
            securityModeControl,
            securityButtons,
            securityTextView
        ]))

        rolloutTitleLabel.font = .preferredFont(forTextStyle: .headline)
        rolloutTitleLabel.text = "7. 灰度发布与回滚（本地模拟）"

        rolloutVariantControl.selectedSegmentIndex = loadRolloutVariantIndex()
        rolloutFaultControl.selectedSegmentIndex = loadRolloutFaultIndex()

        rolloutVariantControl.addTarget(self, action: #selector(onRolloutSelectionChanged), for: .valueChanged)
        rolloutFaultControl.addTarget(self, action: #selector(onRolloutSelectionChanged), for: .valueChanged)

        rolloutApplyButton.setTitle("Apply", for: .normal)
        rolloutApplyButton.addTarget(self, action: #selector(onRolloutApply), for: .touchUpInside)

        rolloutResetButton.setTitle("Reset", for: .normal)
        rolloutResetButton.addTarget(self, action: #selector(onRolloutReset), for: .touchUpInside)

        rolloutStatusLabel.font = .preferredFont(forTextStyle: .subheadline)
        rolloutStatusLabel.numberOfLines = 0

        let rolloutButtons = UIStackView(arrangedSubviews: [rolloutApplyButton, rolloutResetButton])
        rolloutButtons.axis = .horizontal
        rolloutButtons.spacing = 12
        rolloutButtons.distribution = .fillEqually

        configureTextView(rolloutTextView, height: 180)

        contentStack.addArrangedSubview(makeSection([
            rolloutTitleLabel,
            rolloutVariantControl,
            rolloutFaultControl,
            rolloutButtons,
            rolloutStatusLabel,
            rolloutTextView
        ]))

        renderRolloutStatus(persist: false)
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
        perfTextView.text = "点击 Snapshot 观察 dyld image 数量与主二进制 load commands 概览。\n点击 Benchmark 比较 dlopen 的 Lazy/Now（演示 dyld 绑定策略对启动/首次调用的影响）。\n点击 Copy JSON 复制结构化报告（type/timestamp/text）。"
        securityTextView.text = "选择 Real/Demo 后点击 Inspect 输出：LC_CODE_SIGNATURE/段权限/VM protections + 越狱检测证据与评分。\n点击 Copy JSON 可复制结构化报告。"
        rolloutTextView.text = "选择 Stable/Canary 与 OK/Fault，点击 Apply 观察最终生效版本与回滚兜底。"
        renderRolloutStatus(persist: false)
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

    @objc private func onPerfSnapshot() {
        let text = renderDyldWorkloadSnapshot()
        lastPerfReportJSON = makePerfReportJSON(type: "dyld_snapshot", text: text)
        perfTextView.text = text
    }

    @objc private func onPerfBenchmark() {
        let text = renderDlopenBenchmark()
        lastPerfReportJSON = makePerfReportJSON(type: "dlopen_benchmark", text: text)
        perfTextView.text = text
    }

    @objc private func onPerfCopyJSON() {
        if lastPerfReportJSON.isEmpty {
            let text = renderDyldWorkloadSnapshot()
            lastPerfReportJSON = makePerfReportJSON(type: "dyld_snapshot", text: text)
        }
        UIPasteboard.general.string = lastPerfReportJSON
    }

    private func makePerfReportJSON(type: String, text: String) -> String {
        let dict: [String: Any] = [
            "type": type,
            "timestamp": Date().timeIntervalSince1970,
            "text": text
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "{}"
    }

    @objc private func onSecurityModeChanged() {
        lastJailbreakReportJSON = ""
        securityTextView.text = "选择 Real/Demo 后点击 Inspect 输出：LC_CODE_SIGNATURE/段权限/VM protections + 越狱检测证据与评分。\n点击 Copy JSON 可复制结构化报告。"
    }

    @objc private func onSecurityInspect() {
        let simulate = securityModeControl.selectedSegmentIndex == 1
        lastJailbreakReportJSON = renderJailbreakReportJSON(simulate: simulate)
        securityTextView.text = renderSecurityAndSigningReport(simulate: simulate)
    }

    @objc private func onSecurityCopyJSON() {
        let simulate = securityModeControl.selectedSegmentIndex == 1
        if lastJailbreakReportJSON.isEmpty {
            lastJailbreakReportJSON = renderJailbreakReportJSON(simulate: simulate)
        }
        UIPasteboard.general.string = lastJailbreakReportJSON
    }

    @objc private func onRolloutSelectionChanged() {
        renderRolloutStatus(persist: false)
    }

    @objc private func onRolloutApply() {
        renderRolloutStatus(persist: true)
    }

    @objc private func onRolloutReset() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "demo.rollout.variant")
        defaults.removeObject(forKey: "demo.rollout.fault")
        rolloutVariantControl.selectedSegmentIndex = loadRolloutVariantIndex()
        rolloutFaultControl.selectedSegmentIndex = loadRolloutFaultIndex()
        renderRolloutStatus(persist: false)
    }

    private func loadRolloutVariantIndex() -> Int {
        let v = UserDefaults.standard.integer(forKey: "demo.rollout.variant")
        return (v == 1) ? 1 : 0
    }

    private func loadRolloutFaultIndex() -> Int {
        return UserDefaults.standard.bool(forKey: "demo.rollout.fault") ? 1 : 0
    }

    private enum RolloutError: Error {
        case simulatedReleaseFault
    }

    private func renderRolloutStatus(persist: Bool) {
        let selectedVariant = rolloutVariantControl.selectedSegmentIndex
        let selectedFault = rolloutFaultControl.selectedSegmentIndex == 1

        if persist {
            let defaults = UserDefaults.standard
            defaults.set(selectedVariant, forKey: "demo.rollout.variant")
            defaults.set(selectedFault, forKey: "demo.rollout.fault")
        }

        let selected = (selectedVariant == 1) ? "Canary" : "Stable"
        var effective = selected
        var reason = "config"
        var payload = ""

        if selectedVariant == 1 {
            do {
                payload = try renderCanaryFeature(simulateFault: selectedFault)
            } catch {
                effective = "Stable"
                reason = "rollback(hardcoded)"
                payload = renderStableFeature()
            }
        } else {
            payload = renderStableFeature()
        }

        rolloutStatusLabel.text = "selected: \(selected)\neffective: \(effective)\nreason: \(reason)"
        rolloutTextView.text = payload
    }

    private func renderStableFeature() -> String {
        let dict: [String: Any] = [
            "version": "stable",
            "ts": Date().timeIntervalSince1970,
            "message": "稳定版本逻辑（老分支）"
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "{}"
    }

    private func renderCanaryFeature(simulateFault: Bool) throws -> String {
        if simulateFault {
            throw RolloutError.simulatedReleaseFault
        }
        let dict: [String: Any] = [
            "version": "canary",
            "ts": Date().timeIntervalSince1970,
            "message": "灰度版本逻辑（新分支）",
            "extra": ["new_ui": true, "algo": "v2"]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "{}"
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

        guard let main = mainMachO64() else {
            return "未能定位主可执行文件的 Mach-O header。"
        }

        lines.append("image: \(main.path)")
        lines.append("slide: \(formatHex(UInt64(bitPattern: Int64(main.slide))))")
        lines.append("ncmds: \(main.header.pointee.ncmds), sizeofcmds: \(main.header.pointee.sizeofcmds)")
        lines.append("")

        // Mach-O header 后面紧跟着一串 load commands。
        // 这里按 cmdsize 线性推进指针，只挑 LC_SEGMENT_64 做段表展示。
        var cursor = UnsafeRawPointer(main.header).advanced(by: MemoryLayout<mach_header_64>.size)
        var segmentCount = 0

        for _ in 0..<Int(main.header.pointee.ncmds) {
            let loadCommand = cursor.assumingMemoryBound(to: load_command.self).pointee

            if loadCommand.cmd == UInt32(LC_SEGMENT_64) {
                let segment = cursor.assumingMemoryBound(to: segment_command_64.self).pointee
                segmentCount += 1

                let segmentName = fixedWidthString(from: segment.segname)
                lines.append("[\(segmentCount)] \(segmentName.isEmpty ? "<unnamed>" : segmentName)")
                lines.append("  vmaddr=\(formatHex(segment.vmaddr)) vmsize=\(formatHex(segment.vmsize)) fileoff=\(formatHex(segment.fileoff)) nsects=\(segment.nsects) initprot=\(vmProtString(segment.initprot)) maxprot=\(vmProtString(segment.maxprot))")

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

    private func renderDyldWorkloadSnapshot() -> String {
        ensureDyldObserverRegistered()
        var lines: [String] = []
        let imageCount = _dyld_image_count()
        lines.append("dyld image count: \(imageCount)")

        var totalCmds: UInt64 = 0
        var totalCmdBytes: UInt64 = 0

        let t0 = clockNow()
        for i in 0..<imageCount {
            guard let header = _dyld_get_image_header(i) else { continue }
            if header.pointee.magic == MH_MAGIC_64 || header.pointee.magic == MH_CIGAM_64 {
                let h64 = UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self)
                totalCmds += UInt64(h64.pointee.ncmds)
                totalCmdBytes += UInt64(h64.pointee.sizeofcmds)
            }
        }
        let elapsed = clockElapsedMS(since: t0)
        lines.append("iterate images (sum ncmds/sizeofcmds): \(String(format: "%.3f", elapsed)) ms")
        lines.append("total ncmds: \(totalCmds), total sizeofcmds: \(totalCmdBytes) bytes")
        lines.append("")

        if let main = mainMachO64() {
            lines.append("main image: \(main.path)")
            lines.append("slide: \(formatHex(UInt64(bitPattern: Int64(main.slide))))")
            lines.append("main ncmds: \(main.header.pointee.ncmds), sizeofcmds: \(main.header.pointee.sizeofcmds)")
        }

        lines.append("")
        lines.append("loaded images (top 24):")
        let listLimit = min(Int(imageCount), 24)
        for i in 0..<listLimit {
            guard let name = _dyld_get_image_name(UInt32(i)) else { continue }
            let path = String(cString: name)
            let slide = _dyld_get_image_vmaddr_slide(UInt32(i))
            lines.append(String(format: "  [%02d] slide=0x%llx %@", i, UInt64(bitPattern: Int64(slide)), path))
        }

        lines.append("")
        lines.append("+load execution (instrumented, app-side):")
        lines.append(fetchObjCLoadLogs())

        lines.append("")
        lines.append("dyld add_image events (since observer registration):")
        let events = dyldEventQueue.sync { dyldAddImageEvents }
        if events.isEmpty {
            lines.append("  (none yet) try running dlopen benchmark to trigger add_image")
        } else {
            lines.append(contentsOf: events.map { "  \($0)" })
        }

        lines.append("")
        lines.append("提示：")
        lines.append("- 启动慢常和 dyld 需要处理的镜像数量、绑定/修指针量（fixups）相关。")
        lines.append("- 工程层面“加库变慢”，通常体现在 imageCount 增加、绑定信息变多。")
        lines.append("- 系统/三方库的 +load 执行细节需要在对应镜像里显式埋点或借助更底层的 tracing 工具；本 demo 展示的是可控的 app 侧 +load 顺序与线程信息。")
        return lines.joined(separator: "\n")
    }

    private func renderDlopenBenchmark() -> String {
        ensureDyldObserverRegistered()
        let candidates: [String] = [
            "/usr/lib/libobjc.A.dylib",
            "/usr/lib/libSystem.B.dylib",
            "/usr/lib/libc++.1.dylib",
            "/usr/lib/libsqlite3.dylib"
        ]

        var openedPath: String?
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                openedPath = path
                break
            }
        }

        guard let path = openedPath else {
            return "未找到可用于 dlopen 的系统 dylib 路径（模拟器/系统差异）。"
        }

        func measure(flag: Int32, rounds: Int) -> (ms: Double, ok: Int, fail: Int) {
            var ok = 0
            var fail = 0
            let start = clockNow()
            for _ in 0..<rounds {
                if let handle = dlopen(path, flag) {
                    ok += 1
                    dlclose(handle)
                } else {
                    fail += 1
                }
            }
            let ms = clockElapsedMS(since: start)
            return (ms, ok, fail)
        }

        let rounds = 200
        let lazy = measure(flag: RTLD_LAZY, rounds: rounds)
        let now = measure(flag: RTLD_NOW, rounds: rounds)

        var lines: [String] = []
        lines.append("dlopen benchmark target: \(path)")
        lines.append("rounds: \(rounds)")
        lines.append(String(format: "RTLD_LAZY: %.3f ms (ok=%d fail=%d)", lazy.ms, lazy.ok, lazy.fail))
        lines.append(String(format: "RTLD_NOW : %.3f ms (ok=%d fail=%d)", now.ms, now.ok, now.fail))
        lines.append("")
        lines.append("解释：")
        lines.append("- RTLD_NOW 倾向更早做符号解析（更接近 eager bind）。")
        lines.append("- RTLD_LAZY 把部分解析延迟到首次使用（更接近 lazy bind）。")
        lines.append("- 在系统库已缓存/已加载的情况下差异可能很小，但概念对应 dyld 的启动/首帧权衡。")
        return lines.joined(separator: "\n")
    }

    private func renderSecurityAndSigningReport(simulate: Bool) -> String {
        guard let main = mainMachO64() else {
            return "未能定位主可执行文件的 Mach-O header。"
        }

        var lines: [String] = []
        lines.append("main image: \(main.path)")
        lines.append("slide: \(formatHex(UInt64(bitPattern: Int64(main.slide))))")
        lines.append("")

        var codeSig: (off: UInt32, size: UInt32)?
        var encryption: (cryptoff: UInt32, cryptsize: UInt32, cryptid: UInt32)?
        var segments: [(name: String, vmaddr: UInt64, vmsize: UInt64, initprot: vm_prot_t, maxprot: vm_prot_t)] = []

        var cursor = UnsafeRawPointer(main.header).advanced(by: MemoryLayout<mach_header_64>.size)
        for _ in 0..<Int(main.header.pointee.ncmds) {
            let cmd = cursor.assumingMemoryBound(to: load_command.self).pointee
            if cmd.cmd == UInt32(LC_CODE_SIGNATURE) {
                let cs = cursor.assumingMemoryBound(to: linkedit_data_command.self).pointee
                codeSig = (cs.dataoff, cs.datasize)
            } else if cmd.cmd == UInt32(LC_ENCRYPTION_INFO_64) {
                let e = cursor.assumingMemoryBound(to: encryption_info_command_64.self).pointee
                encryption = (e.cryptoff, e.cryptsize, e.cryptid)
            } else if cmd.cmd == UInt32(LC_SEGMENT_64) {
                let seg = cursor.assumingMemoryBound(to: segment_command_64.self).pointee
                let name = fixedWidthString(from: seg.segname)
                segments.append((name: name, vmaddr: seg.vmaddr, vmsize: seg.vmsize, initprot: seg.initprot, maxprot: seg.maxprot))
            }
            cursor = cursor.advanced(by: Int(cmd.cmdsize))
        }

        if let codeSig {
            lines.append("LC_CODE_SIGNATURE: dataoff=\(formatHex(codeSig.off)) datasize=\(formatHex(codeSig.size))")
        } else {
            lines.append("LC_CODE_SIGNATURE: not found")
        }

        if let encryption {
            lines.append("LC_ENCRYPTION_INFO_64: cryptoff=\(formatHex(encryption.cryptoff)) cryptsize=\(formatHex(encryption.cryptsize)) cryptid=\(encryption.cryptid)")
        } else {
            lines.append("LC_ENCRYPTION_INFO_64: not found")
        }

        lines.append("")
        lines.append("segment init/max prot (from Mach-O):")
        for seg in segments where seg.name == "__TEXT" || seg.name == "__DATA" || seg.name == "__DATA_CONST" || seg.name == "__LINKEDIT" {
            lines.append("  \(seg.name): init=\(vmProtString(seg.initprot)) max=\(vmProtString(seg.maxprot))")
        }

        lines.append("")
        lines.append("runtime VM protections (from mach_vm_region):")
        for seg in segments where seg.name == "__TEXT" || seg.name == "__DATA" || seg.name == "__DATA_CONST" || seg.name == "__LINKEDIT" {
            let addr = UInt64(bitPattern: Int64(main.slide)) &+ seg.vmaddr
            if let info = vmRegionInfo(at: addr) {
                lines.append("  \(seg.name): cur=\(vmProtString(info.protection)) max=\(vmProtString(info.maxProtection)) regionSize=\(formatHex(info.regionSize))")
            } else {
                lines.append("  \(seg.name): vm_region query failed")
            }
        }

        lines.append("")
        lines.append("jailbreak checks (")
        lines[lines.count - 1] += simulate ? "demo" : "real"
        lines[lines.count - 1] += "):\n" + renderJailbreakReportText(simulate: simulate)

        lines.append("")
        lines.append("说明：")
        lines.append("- 代码签名的 blob 位置通过 LC_CODE_SIGNATURE 指向，iOS 内核/AMFI 会强制校验完整性。")
        lines.append("- __TEXT 通常为 r-x（不可写），__DATA 多为 r-w，__LINKEDIT 多为 r--。")
        lines.append("- __DATA_CONST 体现“启动期可写、运行期尽量只读”的策略，用于降低指针表被篡改风险。")
        lines.append("- 越狱检测属于启发式：单个特征不一定代表越狱，但多个特征同时命中时可信度更高。")
        return lines.joined(separator: "\n")
    }

    private struct JailbreakCheck {
        let key: String
        let passed: Bool
        let weight: Int
        let details: [String]
    }

    private func renderJailbreakReportText(simulate: Bool) -> String {
        let report = jailbreakReport(simulate: simulate)
        var lines: [String] = []
        lines.append("  environment: \(report.environment)")

        for check in report.checks {
            if check.passed {
                lines.append("  \(check.key): ok")
            } else {
                lines.append("  \(check.key): HIT")
                if !check.details.isEmpty {
                    lines.append(contentsOf: check.details.prefix(12).map { "    - \($0)" })
                }
            }
        }

        lines.append("  summary: score=\(report.score) (0=not detected; higher=more suspicious)")
        return lines.joined(separator: "\n")
    }

    private func renderJailbreakReportJSON(simulate: Bool) -> String {
        let report = jailbreakReport(simulate: simulate)
        let dict: [String: Any] = [
            "mode": simulate ? "demo" : "real",
            "environment": report.environment,
            "score": report.score,
            "checks": report.checks.map { c in
                [
                    "key": c.key,
                    "passed": c.passed,
                    "weight": c.weight,
                    "details": c.details
                ]
            }
        ]

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "{}"
    }

    private func jailbreakReport(simulate: Bool) -> (environment: String, score: Int, checks: [JailbreakCheck]) {
        if simulate {
            let checks: [JailbreakCheck] = [
                JailbreakCheck(key: "path scan", passed: false, weight: 3, details: ["/Applications/Cydia.app (simulated)", "/Library/MobileSubstrate/MobileSubstrate.dylib (simulated)", "/var/jb (simulated)"]),
                JailbreakCheck(key: "sandbox write", passed: false, weight: 2, details: ["wrote /private/lowlevel_found_demo_jb_test.txt (simulated)"]),
                JailbreakCheck(key: "dyld images", passed: false, weight: 1, details: ["/usr/lib/FridaGadget.dylib (simulated)"]),
                JailbreakCheck(key: "env vars", passed: false, weight: 1, details: ["DYLD_INSERT_LIBRARIES=/usr/lib/FridaGadget.dylib (simulated)"]),
                JailbreakCheck(key: "dlsym hooks", passed: false, weight: 2, details: ["MSHookFunction=0x11111111 in /usr/lib/libsubstrate.dylib (simulated)", "rebind_symbols=0x22222222 in /usr/lib/libfishhook.dylib (simulated)"])
            ]
            let score = checks.reduce(0) { $0 + $1.weight }
            return ("simulated", score, checks)
        }

        #if targetEnvironment(simulator)
        let environment = "simulator"
        #else
        let environment = "device"
        #endif

        var checks: [JailbreakCheck] = []

        let suspiciousPaths: [String] = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt",
            "/bin/bash",
            "/usr/bin/ssh",
            "/var/jb"
        ]

        var pathDetails: [String] = []
        for p in suspiciousPaths where FileManager.default.fileExists(atPath: p) {
            if let d = fileStatDetail(path: p) {
                pathDetails.append("\(p) \(d)")
            } else {
                pathDetails.append("\(p) (stat unavailable)")
            }
        }
        checks.append(JailbreakCheck(key: "path scan", passed: pathDetails.isEmpty, weight: pathDetails.count, details: pathDetails))

        let writeTestTargets: [String] = [
            "/private/lowlevel_found_demo_jb_test.txt",
            "/var/tmp/lowlevel_found_demo_jb_test.txt"
        ]

        var writeSucceeded: [String] = []
        for target in writeTestTargets {
            do {
                try "jb_test".write(toFile: target, atomically: true, encoding: .utf8)
                writeSucceeded.append(target)
                try? FileManager.default.removeItem(atPath: target)
            } catch {
            }
        }
        checks.append(JailbreakCheck(key: "sandbox write", passed: writeSucceeded.isEmpty, weight: writeSucceeded.isEmpty ? 0 : 2, details: writeSucceeded.map { "wrote \($0)" }))

        let suspiciousImageKeywords: [String] = [
            "MobileSubstrate",
            "SubstrateLoader",
            "TweakInject",
            "libhooker",
            "frida",
            "FridaGadget",
            "cycript",
            "SSLKillSwitch",
            "CydiaSubstrate"
        ]

        var matchedImages: [String] = []
        let imageCount = _dyld_image_count()
        if imageCount > 0 {
            for i in 0..<imageCount {
                guard let cName = _dyld_get_image_name(i) else { continue }
                let path = String(cString: cName)
                for key in suspiciousImageKeywords where path.localizedCaseInsensitiveContains(key) {
                    matchedImages.append(path)
                    break
                }
            }
        }
        checks.append(JailbreakCheck(key: "dyld images", passed: matchedImages.isEmpty, weight: matchedImages.count, details: matchedImages))

        let envKeys = ["DYLD_INSERT_LIBRARIES", "DYLD_LIBRARY_PATH", "DYLD_FRAMEWORK_PATH"]
        var envHits: [String] = []
        for key in envKeys {
            if let v = getenv(key), let s = String(validatingUTF8: v), !s.isEmpty {
                envHits.append("\(key)=\(s)")
            }
        }
        checks.append(JailbreakCheck(key: "env vars", passed: envHits.isEmpty, weight: envHits.count, details: envHits))

        let symLines = symbolHookCheckLines()
        checks.append(JailbreakCheck(key: "dlsym hooks", passed: symLines.isEmpty, weight: symLines.count, details: symLines))

        let score = checks.reduce(0) { $0 + $1.weight }
        return (environment, score, checks)
    }

    private func fileStatDetail(path: String) -> String? {
        var st = stat()
        let rc = path.withCString { cPath in
            lstat(cPath, &st)
        }
        guard rc == 0 else { return nil }

        let mode = UInt32(st.st_mode)
        let typeBits = mode & UInt32(S_IFMT)
        let isSymlink = typeBits == UInt32(S_IFLNK)
        let perms = mode & 0o777

        return String(format: "(type=%@ perms=%03o uid=%u gid=%u)", isSymlink ? "symlink" : "file/dir", perms, st.st_uid, st.st_gid)
    }

    private func symbolHookCheckLines() -> [String] {
        let symbols: [String] = [
            "MSHookFunction",
            "MSFindSymbol",
            "MSGetImageByName",
            "LHHookFunctions",
            "LHHookMessageEx",
            "frida_agent_main",
            "gum_init_embedded",
            "rebind_symbols"
        ]

        guard let handle = dlopen(nil, RTLD_NOW) else { return [] }
        defer { dlclose(handle) }

        var hits: [String] = []
        for sym in symbols {
            let ptr = dlsym(handle, sym)
            guard let ptr else { continue }
            let owner = imageOwner(of: ptr) ?? "(unknown image)"
            let addr = UInt64(UInt(bitPattern: ptr))
            hits.append(String(format: "%@=0x%llx in %@", sym, addr, owner))
        }
        return hits
    }

    private func imageOwner(of pointer: UnsafeMutableRawPointer) -> String? {
        var info = Dl_info()
        let rc = dladdr(pointer, &info)
        guard rc != 0 else { return nil }
        if let fname = info.dli_fname {
            return String(cString: fname)
        }
        return nil
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

        7. 启动/首帧性能（dyld）
        - 考点：imageCount、load commands、rebase/bind、lazy vs non-lazy
        - 实操：点击 “Snapshot dyld Workload” / “Benchmark dlopen (Lazy vs Now)”
        - 追问：为什么加库会变慢、为什么首次调用某些符号会卡一下

        8. 安全与签名
        - 考点：LC_CODE_SIGNATURE、段权限（r-x / r-w）、__DATA_CONST 意义
        - 实操：点击 “Inspect Code Signature & VM Protections”
        - 追问：代码签名如何保证完整性、为什么 __TEXT 不能写
        """
    }

    private func mainMachO64() -> (index: UInt32, header: UnsafePointer<mach_header_64>, slide: Int, path: String)? {
        guard let executablePath = Bundle.main.executablePath else { return nil }
        let executableName = URL(fileURLWithPath: executablePath).lastPathComponent

        let imageCount = _dyld_image_count()
        for index in 0..<imageCount {
            guard let cName = _dyld_get_image_name(index) else { continue }
            let path = String(cString: cName)
            if path == executablePath || path.hasSuffix("/\(executableName)") {
                guard let headerPointer = _dyld_get_image_header(index) else { continue }
                let magic = headerPointer.pointee.magic
                guard magic == MH_MAGIC_64 || magic == MH_CIGAM_64 else { return nil }
                let header = UnsafeRawPointer(headerPointer).assumingMemoryBound(to: mach_header_64.self)
                let slide = _dyld_get_image_vmaddr_slide(index)
                return (index, header, slide, path)
            }
        }

        return nil
    }

    private func vmProtString(_ prot: vm_prot_t) -> String {
        var parts: [String] = []
        parts.append((prot & VM_PROT_READ) != 0 ? "r" : "-")
        parts.append((prot & VM_PROT_WRITE) != 0 ? "w" : "-")
        parts.append((prot & VM_PROT_EXECUTE) != 0 ? "x" : "-")
        return parts.joined()
    }

    private func vmRegionInfo(at address: UInt64) -> (protection: vm_prot_t, maxProtection: vm_prot_t, regionSize: UInt64)? {
        var addr = vm_address_t(address)
        var size: vm_size_t = 0
        var info = vm_region_basic_info_64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_region_basic_info_64>.stride / MemoryLayout<natural_t>.stride)
        var objectName: mach_port_t = 0

        let kr: kern_return_t = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                vm_region_64(mach_task_self_, &addr, &size, VM_REGION_BASIC_INFO_64, intPtr, &count, &objectName)
            }
        }

        guard kr == KERN_SUCCESS else { return nil }
        return (info.protection, info.max_protection, UInt64(size))
    }

    private func clockNow() -> UInt64 {
        mach_absolute_time()
    }

    private func clockElapsedMS(since start: UInt64) -> Double {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let end = mach_absolute_time()
        let elapsed = end &- start
        let nanos = Double(elapsed) * Double(timebase.numer) / Double(timebase.denom)
        return nanos / 1_000_000.0
    }

    private func fixedWidthString<T>(from value: T) -> String {
        withUnsafeBytes(of: value) { rawBuffer in
            let prefix = rawBuffer.prefix { $0 != 0 }
            return String(decoding: prefix, as: UTF8.self)
        }
    }

    private func fetchObjCLoadLogs() -> String {
        guard let cls = NSClassFromString("LFForwardingEntry") as AnyObject? else {
            return "  (LFForwardingEntry not found)"
        }
        let sel = NSSelectorFromString("loadLogSnapshot")
        guard cls.responds(to: sel) else {
            return "  (loadLogSnapshot not available)"
        }
        let value = cls.perform(sel)?.takeUnretainedValue() as? String
        if let value, !value.isEmpty {
            return value.split(separator: "\n").map { "  \($0)" }.joined(separator: "\n")
        }
        return "  (empty)"
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
