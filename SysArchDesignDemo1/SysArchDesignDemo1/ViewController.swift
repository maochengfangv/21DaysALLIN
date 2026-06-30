//
//  ViewController.swift
//  SysArchDesignDemo1
//
//  Created by maochengfang on 2026/6/30.
//

import UIKit

final class ViewController: UIViewController {

    // UI 入口：用于配置实验参数并一键触发 3 个用例或自定义用例。
    // - URL 仅用于 key 生成与拦截规则匹配，不会真实出网（回源由 LocalOriginTransport 本地生成）。
    // - 参数单位：TTL=秒；base/jitter/timeout=毫秒；概率=0~1。
    private let concurrencyField = UITextField()
    private let ttlField = UITextField()
    private let baseDelayMsField = UITextField()
    private let jitterMsField = UITextField()
    private let timeoutThresholdMsField = UITextField()
    private let timeoutProbabilityField = UITextField()
    private let errorProbabilityField = UITextField()
    private let singleFlightSwitch = UISwitch()

    private let runThreeCasesButton = UIButton(type: .system)
    private let runCustomButton = UIButton(type: .system)
    private let expireButton = UIButton(type: .system)

    private let outputTextView = UITextView()

    private let keyURL = URL(string: "https://example.local/api/item?id=42")
    private var environment: ExperimentEnvironment?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "Interceptor + Cache"

        configureFields()
        configureButtons()
        configureOutput()
        layoutUI()

        rebuildEnvironmentIfNeeded()
    }

    private func configureFields() {
        [concurrencyField, ttlField, baseDelayMsField, jitterMsField, timeoutThresholdMsField, timeoutProbabilityField, errorProbabilityField].forEach {
            $0.borderStyle = .roundedRect
            $0.keyboardType = .decimalPad
        }

        concurrencyField.keyboardType = .numberPad

        concurrencyField.placeholder = "并发数 N (默认 20)"
        ttlField.placeholder = "TTL 秒 (默认 2.0)"
        baseDelayMsField.placeholder = "延迟 base ms (默认 200)"
        jitterMsField.placeholder = "延迟 jitter ms (默认 200)"
        timeoutThresholdMsField.placeholder = "timeout 阈值 ms (默认 300)"
        timeoutProbabilityField.placeholder = "timeout 概率 0~1 (默认 0.0)"
        errorProbabilityField.placeholder = "5xx 概率 0~1 (默认 0.0)"

        concurrencyField.text = "20"
        ttlField.text = "2.0"
        baseDelayMsField.text = "200"
        jitterMsField.text = "200"
        timeoutThresholdMsField.text = "300"
        timeoutProbabilityField.text = "0.0"
        errorProbabilityField.text = "0.0"

        singleFlightSwitch.isOn = true
    }

    private func configureButtons() {
        runThreeCasesButton.setTitle("运行 3 个用例", for: .normal)
        runThreeCasesButton.addTarget(self, action: #selector(runThreeCasesTapped), for: .touchUpInside)

        runCustomButton.setTitle("运行自定义(用开关)", for: .normal)
        runCustomButton.addTarget(self, action: #selector(runCustomTapped), for: .touchUpInside)

        expireButton.setTitle("强制过期 key", for: .normal)
        expireButton.addTarget(self, action: #selector(expireTapped), for: .touchUpInside)
    }

    private func configureOutput() {
        outputTextView.isEditable = false
        outputTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        outputTextView.text = ""
    }

    private func layoutUI() {
        let formStack = UIStackView(arrangedSubviews: [
            labeledRow(title: "N", control: concurrencyField),
            labeledRow(title: "TTL", control: ttlField),
            labeledRow(title: "base(ms)", control: baseDelayMsField),
            labeledRow(title: "jitter(ms)", control: jitterMsField),
            labeledRow(title: "timeout(ms)", control: timeoutThresholdMsField),
            labeledRow(title: "pTimeout", control: timeoutProbabilityField),
            labeledRow(title: "p5xx", control: errorProbabilityField),
            labeledRow(title: "singleflight", control: singleFlightSwitch)
        ])
        formStack.axis = .vertical
        formStack.spacing = 10

        let buttonStack = UIStackView(arrangedSubviews: [runThreeCasesButton, runCustomButton, expireButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 10

        let root = UIStackView(arrangedSubviews: [formStack, buttonStack, outputTextView])
        root.axis = .vertical
        root.spacing = 16
        root.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(root)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            root.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            root.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16)
        ])

        outputTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
    }

    private func labeledRow(title: String, control: UIView) -> UIView {
        let label = UILabel()
        label.text = title
        label.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [label, control])
        row.axis = .horizontal
        row.spacing = 10
        return row
    }

    private func appendOutput(_ text: String) {
        DispatchQueue.main.async {
            if self.outputTextView.text.isEmpty {
                self.outputTextView.text = text
            } else {
                self.outputTextView.text += "\n" + text
            }
            let bottom = NSRange(location: max(self.outputTextView.text.count - 1, 0), length: 1)
            self.outputTextView.scrollRangeToVisible(bottom)
        }
    }

    private func rebuildEnvironmentIfNeeded() {
        guard let url = keyURL else {
            appendOutput("URL 无效")
            return
        }

        // 每次运行前重建环境，避免全局状态污染，保证可重复实验。
        let config = readConfig()
        environment = ExperimentEnvironment(baseURL: url, config: config)
    }

    private func readConfig() -> ExperimentConfig {
        let n = Int(concurrencyField.text ?? "") ?? 20
        let ttlSeconds = Double(ttlField.text ?? "") ?? 2.0
        let baseDelayMs = Int(baseDelayMsField.text ?? "") ?? 200
        let jitterMs = Int(jitterMsField.text ?? "") ?? 200
        let timeoutThresholdMs = Int(timeoutThresholdMsField.text ?? "") ?? 300
        let timeoutProbability = Double(timeoutProbabilityField.text ?? "") ?? 0.0
        let errorProbability = Double(errorProbabilityField.text ?? "") ?? 0.0

        return ExperimentConfig(
            concurrency: max(n, 1),
            ttl: max(ttlSeconds, 0.0),
            injection: InjectionConfig(
                baseDelayMs: max(baseDelayMs, 0),
                jitterMs: max(jitterMs, 0),
                timeoutThresholdMs: max(timeoutThresholdMs, 0),
                timeoutProbability: min(max(timeoutProbability, 0.0), 1.0),
                errorProbability: min(max(errorProbability, 0.0), 1.0)
            ),
            enableSingleFlight: singleFlightSwitch.isOn
        )
    }

    private func setButtonsEnabled(_ enabled: Bool) {
        DispatchQueue.main.async {
            self.runThreeCasesButton.isEnabled = enabled
            self.runCustomButton.isEnabled = enabled
            self.expireButton.isEnabled = enabled
        }
    }

    @objc private func expireTapped() {
        rebuildEnvironmentIfNeeded()
        // 强制过期 key：用于稳定复现“TTL 过期后瞬间 N 并发”的击穿/合并对照。
        environment?.expire()
        appendOutput("[Manual] expire(key) done")
    }

    @objc private func runThreeCasesTapped() {
        rebuildEnvironmentIfNeeded()
        guard let environment else { return }

        setButtonsEnabled(false)
        outputTextView.text = ""

        // 用例组合：
        // 1) TTL 未过期：连续请求命中缓存（origin 基本不增长）
        // 2) TTL 过期 + N 并发 + singleflight=OFF：origin ≈ N（击穿）
        // 3) TTL 过期 + N 并发 + singleflight=ON ：origin ≈ 1（合并）
        let config = readConfig()
        let runner = ExperimentRunner(environment: environment)

        runner.runThreeCases(concurrency: config.concurrency) { [weak self] output in
            self?.appendOutput(output)
            self?.setButtonsEnabled(true)
        }
    }

    @objc private func runCustomTapped() {
        rebuildEnvironmentIfNeeded()
        guard let environment else { return }

        setButtonsEnabled(false)
        outputTextView.text = ""

        let config = readConfig()
        environment.updateConfig(config)

        let runner = ExperimentRunner(environment: environment)
        runner.runSingleCase(name: "Custom", concurrency: config.concurrency, enableSingleFlight: config.enableSingleFlight) { [weak self] output in
            self?.appendOutput(output)
            self?.setButtonsEnabled(true)
        }
    }
}

