import Cocoa

protocol TitleViewDelegate: class {

	func titleViewDidChangeVisibility(_ titleView: TitleView)

}

class TitleView: NSVisualEffectView {

	weak var delegate: TitleViewDelegate?

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		initialize()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		initialize()
	}

	private func initialize() {
		wantsLayer = true
		blendingMode = .withinWindow
		material = .titlebar

		let overlay = CALayer()
		overlay.frame = layer?.bounds ?? .zero
		overlay.backgroundColor = NSColor(deviceWhite: 0, alpha: 0.4).cgColor
		overlay.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
		layer?.addSublayer(overlay)

		let shadow = NSShadow()
		shadow.shadowBlurRadius = 1
		shadow.shadowColor = NSColor(deviceWhite: 0, alpha: 0.5)
		self.shadow = shadow
	}

	var shouldHideWhenInactive: Bool = false {
		didSet { updateVisibility() }
	}

	override var mouseDownCanMoveWindow: Bool {
		return true
	}

	override func hitTest(_ point: NSPoint) -> NSView? {
		guard self.frame.contains(point) else {
			return nil
		}

		return self.superview
	}

	private var keyWindowObservers: [Any]?

	override func viewWillMove(toWindow newWindow: NSWindow?) {
		keyWindowObservers?.forEach { NotificationCenter.default.removeObserver($0) }
		keyWindowObservers = nil
	}

	override func viewDidMoveToWindow() {
		let handler: (_ notification: Notification) -> Void = { [weak self] _ in
			self?.updateVisibility()
		}

		let becomeKey = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main, using: handler)
		let resignKey = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main, using: handler)
		let enterFullScreen = NotificationCenter.default.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: nil, queue: .main, using: handler)
		let exitFullScreen = NotificationCenter.default.addObserver(forName: NSWindow.didExitFullScreenNotification, object: nil, queue: .main, using: handler)

		keyWindowObservers = [becomeKey, resignKey, enterFullScreen, exitFullScreen]
		updateVisibility()
	}

	@IBOutlet private var heightConstraint: NSLayoutConstraint?

	override func layout() {
		super.layout()

		if let heightConstraint = heightConstraint,
			let themeFrame = window?.contentView?.superview,
			let unmanagedTitlebarViewController = themeFrame.perform(NSSelectorFromString("titlebarViewController")),
			let titlebarViewController = unmanagedTitlebarViewController.takeUnretainedValue() as? NSViewController {
			heightConstraint.constant = titlebarViewController.view.bounds.size.height
		}
	}

	override var isHidden: Bool {
		didSet { delegate?.titleViewDidChangeVisibility(self) }
	}

	private func updateVisibility() {
		guard let window = window else {
			return
		}

		let shouldHide = window.styleMask.contains(.fullScreen) || (shouldHideWhenInactive && !window.isKeyWindow)

		guard isHidden != shouldHide else {
			return
		}

		isHidden = shouldHide
	}

}
