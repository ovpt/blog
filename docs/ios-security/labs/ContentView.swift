import SwiftUI
import Security
import os
@preconcurrency import WebKit

extension Logger {
    static let lab = Logger(subsystem: "securitylab", category: "lab")
}

enum LabMode: String {
    case blank
    case https
    case http
    case bridge
    case injected
}

@MainActor
final class LabModel: ObservableObject {
    @Published var log = "点下面的按钮。一次只做一个实验。"
    @Published var mode: LabMode = .blank

    func write(_ text: String) {
        let combined = text + "\n" + log
        log = combined.split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(12)
            .joined(separator: "\n")
        Logger.lab.notice("\(text, privacy: .public)")
    }
}

struct ContentView: View {
    @StateObject private var model = LabModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SecurityLab")
                .font(.title2)
            Text(model.log)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            LabWebView(mode: model.mode, model: model)
                .id(model.mode)
                .frame(height: 220)
                .overlay(Rectangle().stroke(Color.gray, lineWidth: 1))
            ScrollView {
                VStack(spacing: 8) {
                    Button("1 沙盒读写") { runSandbox() }
                    Button("2 加载 HTTPS") { model.mode = .https }
                    Button("3 加载 HTTP") { model.mode = .http }
                    Button("4 钥匙串") { runKeychain() }
                    Button("5 本地消息桥") { model.mode = .bridge }
                    Button("6 注入到 example.com") { model.mode = .injected }
                    Button("7 故意崩溃") {
                        Logger.lab.notice("deliberate crash")
                        fatalError("SecurityLab deliberate crash")
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .onOpenURL { url in
            model.write("onOpenURL \(url.absoluteString)")
        }
    }

    private func runSandbox() {
        let home = NSHomeDirectory()
        let documents = (home as NSString).appendingPathComponent("Documents")
        try? FileManager.default.createDirectory(atPath: documents, withIntermediateDirectories: true)
        let inside = (documents as NSString).appendingPathComponent("inside.txt")
        let outside = "/var/mobile/Library/Preferences/securitylab-outside.txt"
        let insideResult = writeProbe(path: inside)
        let outsideResult = writeProbe(path: outside)
        model.write("home=\(home)\ninside=\(insideResult)\noutside=\(outsideResult)")
    }

    private func writeProbe(path: String) -> String {
        do {
            try "ok".write(toFile: path, atomically: true, encoding: .utf8)
            return "成功 \(path)"
        } catch {
            let ns = error as NSError
            return "失败 domain=\(ns.domain) code=\(ns.code)"
        }
    }

    private func runKeychain() {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "lab",
            kSecAttrService as String: "SecurityLab"
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data("lab-secret".utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        var read = base
        read[kSecReturnData as String] = true
        read[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let readStatus = SecItemCopyMatching(read as CFDictionary, &item)
        let value: String
        if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
            value = text
        } else {
            value = "nil"
        }
        model.write("keychain add=\(addStatus) read=\(readStatus) value=\(value)")
    }
}

struct LabWebView: UIViewRepresentable {
    let mode: LabMode
    let model: LabModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> WKWebView {
        let content = WKUserContentController()
        content.add(context.coordinator, name: "lab")
        if mode == .injected {
            let source = "window.webkit.messageHandlers.lab.postMessage('injected')"
            let script = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            content.addUserScript(script)
        }
        let config = WKWebViewConfiguration()
        config.userContentController = content
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        switch mode {
        case .blank:
            break
        case .https:
            webView.load(URLRequest(url: URL(string: "https://example.com/")!))
        case .http:
            webView.load(URLRequest(url: URL(string: "http://example.com/")!))
        case .bridge:
            let html = """
            <!DOCTYPE html><meta charset="utf-8"><body>
            <p>bridge page</p>
            <button onclick="webkit.messageHandlers.lab.postMessage('clicked')">send</button>
            </body>
            """
            webView.loadHTMLString(html, baseURL: URL(string: "https://lab.local/page.html"))
        case .injected:
            webView.load(URLRequest(url: URL(string: "https://example.com/")!))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let model: LabModel

        init(model: LabModel) {
            self.model = model
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let host = message.frameInfo.request.url?.host ?? "nil"
            let body = String(describing: message.body)
            let line: String
            if host == "lab.local" {
                line = "bridge host=\(host) body=\(body)"
            } else {
                line = "bridge ignored host=\(host) body=\(body)"
            }
            Task { @MainActor in
                self.model.write(line)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let url = webView.url?.absoluteString ?? "nil"
            Task { @MainActor in
                self.model.write("load finished \(url)")
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let ns = error as NSError
            Task { @MainActor in
                self.model.write("load failed domain=\(ns.domain) code=\(ns.code)")
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let ns = error as NSError
            Task { @MainActor in
                self.model.write("load failed domain=\(ns.domain) code=\(ns.code)")
            }
        }
    }
}

#Preview {
    ContentView()
}
