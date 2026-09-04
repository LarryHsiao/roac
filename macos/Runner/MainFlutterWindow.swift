import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // The mascot floats over other apps, so everything the sprite does not
    // paint must be see-through. Flutter's own window options cannot reach
    // these three properties; without them the window draws an opaque ground.
    self.isOpaque = false
    self.backgroundColor = .clear
    flutterViewController.backgroundColor = .clear

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  /// macOS spends the first click on an inactive app activating it, and Roäc
  /// runs as an accessory app with no Dock icon to click instead — so the
  /// mascot appeared to ignore you until the second click, for both the
  /// speech bubble and the right-click pin.
  ///
  /// Activating here, before the event is passed on, lets that first click
  /// land where it was aimed. It fires only for a click already inside Roäc's
  /// own window, so it takes focus from nothing the user was not already
  /// reaching for — unlike focusing on hover, which would steal the keyboard
  /// from whatever they were typing in the moment the pointer crossed by.
  override func sendEvent(_ event: NSEvent) {
    if !isKeyWindow,
      event.type == .leftMouseDown || event.type == .rightMouseDown
    {
      NSApp.activate(ignoringOtherApps: true)
      makeKeyAndOrderFront(nil)
    }
    super.sendEvent(event)
  }
}
