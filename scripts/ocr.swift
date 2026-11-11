import Foundation
import CoreGraphics
import Vision
import AppKit
// call-copilot: снять окно Zoom «Мои заметки» и распознать текст локально (Vision OCR).
// Печатает строки текста, либо NOWIN (окна нет на экране), либо ERR ...
// Сети и нейросетей в облаке нет: всё на этом Маке.
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
var wid: Int? = nil
for w in list {
  let owner = w[kCGWindowOwnerName as String] as? String ?? ""
  let name = (w[kCGWindowName as String] as? String ?? "").lowercased()
  let layer = w[kCGWindowLayer as String] as? Int ?? 0
  let b = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
  let width = b["Width"] as? Double ?? 0
  if owner.contains("ZoomHybridConf") && layer == 0 && width > 300
     && (name.isEmpty || name.contains("аметк") || name.contains("notes") || name.contains("нотатк")) {
    wid = w[kCGWindowNumber as String] as? Int; break
  }
}
guard let id = wid else { print("NOWIN"); exit(0) }
let png = NSTemporaryDirectory() + "call-copilot-zoomnotes.png"
let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
p.arguments = ["-x", "-o", "-l", String(id), png]
try? p.run(); p.waitUntilExit()
guard let img = NSImage(contentsOfFile: png), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("ERR capture (нет разрешения «Запись экрана»?)"); exit(0) }
let req = VNRecognizeTextRequest()
req.recognitionLevel = .accurate
req.recognitionLanguages = ["ru-RU", "uk-UA", "en-US"]
req.usesLanguageCorrection = true
try? VNImageRequestHandler(cgImage: cg).perform([req])
let lines = (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }
print(lines.joined(separator: "\n"))
