import Cocoa
import SwiftUI
import Carbon
final class Model: ObservableObject {
 let store = LogStore(url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Dayline/entries.json"))
 @Published var revision = 0
 @Published var draft = ""
 @Published var day = Date()
 @Published var error = ""
 @Published var selectedID: UUID?
 func save() { do { try store.add(draft); draft = ""; day = Date(); revision += 1; error = "" } catch { self.error = error.localizedDescription } }
}
struct SubmitEditor: NSViewRepresentable {
 @Binding var text: String
 var submit: () -> Void
 func makeCoordinator() -> Coordinator { Coordinator(self) }
 func makeNSView(context: Context) -> NSScrollView {
 let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
 let editor = Editor(); editor.isRichText = false; editor.font = .systemFont(ofSize: 14); editor.delegate = context.coordinator
 editor.string = text; editor.submit = submit
 editor.isVerticallyResizable = true; editor.isHorizontallyResizable = false
 editor.textContainer?.widthTracksTextView = true; editor.autoresizingMask = [.width]
 scroll.documentView = editor
 return scroll
 }
 func updateNSView(_ scroll: NSScrollView, context: Context) {
 context.coordinator.parent = self
 if let editor = scroll.documentView as? Editor { editor.submit = submit; if editor.string != text { editor.string = text } }
 }
 final class Coordinator: NSObject, NSTextViewDelegate {
 var parent: SubmitEditor
 init(_ parent: SubmitEditor) { self.parent = parent }
 func textDidChange(_ notification: Notification) { if let editor = notification.object as? NSTextView { parent.text = editor.string } }
 }
 final class Editor: NSTextView {
 var submit: (() -> Void)?
 override func insertNewline(_ sender: Any?) {
 if hasMarkedText() || NSApp.currentEvent?.modifierFlags.contains(.shift) == true { super.insertNewline(sender) } else { submit?() }
 }
 }
}
struct EntryEditor: View {
 @ObservedObject var model: Model
 let item: Entry
 @Environment(\.dismiss) var dismiss
 @State private var text: String
 @State private var date: Date
 @State private var error = ""
 init(model: Model, item: Entry) { self.model = model; self.item = item; _text = State(initialValue: item.text); _date = State(initialValue: item.date) }
 func save() {
 do { try model.store.update(id: item.id, text: text, date: date); model.selectedID = item.id; model.day = date; model.revision += 1; dismiss() } catch { self.error = error.localizedDescription }
 }
 var body: some View {
 VStack(alignment: .leading, spacing: 16) {
 Text("修改事项").font(.headline)
 DatePicker("时间", selection: $date)
 SubmitEditor(text: $text, submit: save).frame(height: 110)
 Text("回车保存 · Shift＋回车换行").font(.caption).foregroundStyle(.secondary)
 if !error.isEmpty { Text(error).foregroundStyle(.red).font(.caption) }
 HStack {
 Button("删除事项", role: .destructive) {
 do { try model.store.delete(id: item.id); model.revision += 1; dismiss() } catch { self.error = error.localizedDescription }
 }
 Button("取消") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); Button("保存") {
 save()
 }.keyboardShortcut(.defaultAction) }
 }.padding(20).frame(width: 330).preferredColorScheme(.light)
 }
}
final class AxisPanel: NSPanel {
 override var canBecomeKey: Bool { true }
 override var canBecomeMain: Bool { false }
}
struct ResizeHandle: NSViewRepresentable {
 var left = false
 var visible = true
 func makeNSView(context: Context) -> Grip { let grip = Grip(); grip.left = left; grip.visible = visible; return grip }
 func updateNSView(_ nsView: Grip, context: Context) {}
 final class Grip: NSView {
 var left = false
 var visible = true
 override var mouseDownCanMoveWindow: Bool { false }
 override func draw(_ dirtyRect: NSRect) {
 guard visible else { return }; NSColor.secondaryLabelColor.setStroke()
 for n in [5.0, 10.0, 15.0] { let p = NSBezierPath(); p.move(to: NSPoint(x: bounds.width-n, y: 3)); p.line(to: NSPoint(x: bounds.width-3, y: n)); p.stroke() }
 }
 override func mouseDown(with event: NSEvent) {
 guard let window else { return }
 let initial = window.frame; let origin = NSEvent.mouseLocation
 while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
 if next.type == .leftMouseUp { break }
 let point = NSEvent.mouseLocation
 let width = min(window.maxSize.width, max(window.minSize.width, initial.width + (left ? origin.x-point.x : point.x-origin.x)))
 let height = min(window.maxSize.height, max(window.minSize.height, initial.height - point.y+origin.y))
 window.setFrame(NSRect(x: left ? initial.maxX-width : initial.minX, y: initial.maxY-height, width: width, height: height), display: true)
 }
 window.saveFrame(usingName: "DaylineAxisFrame")
 }
 }
}
struct Timeline: View {
 @ObservedObject var model: Model
 @FocusState var focused: Bool
 @State var composing = false
 @State var editing: Entry?
 let hourHeight: CGFloat = 100
 var entries: [Entry] { model.store.items.filter { Calendar.current.isDate($0.date, inSameDayAs: model.day) } }
 func position(_ date: Date) -> CGFloat {
 let c = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
 return CGFloat(c.hour ?? 0) * hourHeight + CGFloat(c.minute ?? 0) * hourHeight / 60
 }
 var body: some View {
 VStack(alignment: .leading, spacing: 8) {
 HStack {
 Button { model.day = Calendar.current.date(byAdding: .day, value: -1, to: model.day)! } label: { Image(systemName: "chevron.left") }
 Text(model.day, format: .dateTime.month().day()).font(.system(size: 12, weight: .semibold))
 Button { model.day = Date() } label: { Text("今天") }
 Button { model.day = Calendar.current.date(byAdding: .day, value: 1, to: model.day)! } label: { Image(systemName: "chevron.right") }
 Spacer()
 Button { composing.toggle(); focused = composing } label: { Image(systemName: "plus") }
 Button { NSApp.hide(nil) } label: { Image(systemName: "minus") }
 }.font(.system(size: 11)).buttonStyle(.plain).padding(10).background(.ultraThinMaterial, in: Capsule())
 ScrollViewReader { proxy in
 ScrollView(.vertical, showsIndicators: false) {
 LazyVStack(alignment: .leading, spacing: 0) {
 ForEach(0..<24) { hour in
 VStack(alignment: .leading, spacing: 8) {
 HStack(spacing: 8) {
 Text(String(format: "%02d:00", hour)).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
 Rectangle().fill(.gray.opacity(0.3)).frame(height: 1)
 }.id(hour)
 ForEach(entries.filter { Calendar.current.component(.hour, from: $0.date) == hour }) { item in
 HStack(alignment: .top, spacing: 8) {
 Circle().fill(.teal).frame(width: 7, height: 7).padding(.top, 7)
 VStack(alignment: .leading, spacing: 5) {
 HStack {
 Text(item.date, style: .time).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
 Spacer()
 Button { editing = item } label: { Image(systemName: "pencil") }.buttonStyle(.plain).help("修改内容和时间")
 }
 Text(item.text).font(.system(size: 13, weight: .medium)).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
 }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
 .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 10))
 .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.18)))
 }.id(item.id)
 }
 }.padding(.leading, 12).padding(.trailing, 8).padding(.bottom, 16)
 .frame(minHeight: 90, alignment: .top)
 .overlay(alignment: .leading) { Rectangle().fill(.teal.opacity(0.35)).frame(width: 1).padding(.leading, 3) }
 }
 }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
 }.onAppear { proxy.scrollTo(max(0, Calendar.current.component(.hour, from: Date()) - 1), anchor: .top) }
 .onChange(of: model.revision) { _, _ in
 if let id = model.selectedID ?? entries.last?.id { withAnimation { proxy.scrollTo(id, anchor: .center) } }; model.selectedID = nil
 }
 .onChange(of: model.day) { _, _ in
 proxy.scrollTo(Calendar.current.isDateInToday(model.day) ? Calendar.current.component(.hour, from: Date()) : 8, anchor: .top)
 }

 }
 if composing {
 VStack(alignment: .leading, spacing: 8) {
 TextField("此刻在做什么？", text: $model.draft).textFieldStyle(.plain).focused($focused).onSubmit { model.save(); if model.error.isEmpty { composing = false } }
 HStack { Text("⌥⌘J · 回车记录").foregroundStyle(.secondary); Spacer(); Button("记录") { model.save(); if model.error.isEmpty { composing = false } } }.font(.system(size: 10))
 }.padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
 }
 if !model.error.isEmpty { Text(model.error).font(.caption).foregroundStyle(.red).padding(6).background(.regularMaterial) }
 }.padding(8).frame(minWidth: 220, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity, alignment: .topLeading)
 .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
 .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18))
 .overlay(RoundedRectangle(cornerRadius: 18).stroke(.gray.opacity(0.25)))
 .overlay(alignment: .bottomTrailing) {
 ResizeHandle().frame(width: 22, height: 22).help("拖动调整窗口大小")
 }
 .overlay(alignment: .bottomLeading) {
 ResizeHandle(left: true, visible: false).frame(width: 8, height: 28).help("向左拖动加宽窗口，向右拖动缩窄")
 }
 .preferredColorScheme(.light)
 .sheet(item: $editing) { item in EntryEditor(model: model, item: item) }
 .onReceive(NotificationCenter.default.publisher(for: Notification.Name("focusEntry"))) { _ in composing = true; focused = true }
 }
}
final class Delegate: NSObject, NSApplicationDelegate {
 var panel: NSPanel!
 var status: NSStatusItem!
 var hotkey: EventHotKeyRef?
 let model = Model()
 func applicationDidFinishLaunching(_ notification: Notification) {
 panel = AxisPanel(contentRect: NSRect(x: 0,y: 0,width: 344,height: 720), styleMask: [.borderless, .nonactivatingPanel, .resizable], backing: .buffered, defer: false)
 panel.title = "Dayline"; panel.titleVisibility = .hidden; panel.titlebarAppearsTransparent = true
 panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false; panel.hidesOnDeactivate = false; panel.level = .statusBar; panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]; panel.isReleasedWhenClosed = false; panel.isMovableByWindowBackground = true
 let hosting = NSHostingView(rootView: Timeline(model: model)); hosting.sizingOptions = []; panel.contentView = hosting; panel.minSize = NSSize(width: 220,height: 320); panel.maxSize = NSSize(width: 800,height: 1600)
 if let screen = NSScreen.main { let r = screen.visibleFrame; panel.setFrame(NSRect(x: r.maxX-310,y:r.minY+12,width:306,height:r.height-24),display:true) }
 panel.setFrameAutosaveName("DaylineAxisFrame")
 status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength); status.button?.title = "◷"
 let menu = NSMenu(); menu.addItem(withTitle:"显示时间轴 ⌥⌘J",action:#selector(show),keyEquivalent:""); menu.addItem(.separator()); menu.addItem(withTitle:"退出 Dayline",action:#selector(quit),keyEquivalent:"q"); for item in menu.items { item.target = self }; status.menu = menu
 var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),eventKind: UInt32(kEventHotKeyPressed))
 InstallEventHandler(GetApplicationEventTarget(), { _,_,data in
 guard let data else { return OSStatus(eventNotHandledErr) }
 let delegate = Unmanaged<Delegate>.fromOpaque(data).takeUnretainedValue(); delegate.show(); return noErr
 },1,&spec,Unmanaged.passUnretained(self).toOpaque(),nil)
 let result = RegisterEventHotKey(UInt32(kVK_ANSI_J),UInt32(optionKey | cmdKey),EventHotKeyID(signature: 0x4441594c,id:1),GetApplicationEventTarget(),0,&hotkey)
 if result != noErr { model.error = "快捷键被占用，请从菜单栏 ◷ 打开。" }
 panel.orderFrontRegardless()
 }
 @objc func show() { NSApp.activate(ignoringOtherApps:true); panel.makeKeyAndOrderFront(nil); NotificationCenter.default.post(name:Notification.Name("focusEntry"),object:nil) }
 @objc func quit() { NSApp.terminate(nil) }
}
let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
