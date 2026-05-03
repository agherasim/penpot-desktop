import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = PenpotMenuBar()
app.delegate = delegate
app.run()
