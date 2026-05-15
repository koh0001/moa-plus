import UIKit
import SwiftUI
import AudioToolbox

class KeyboardViewController: UIInputViewController, UIInputViewAudioFeedback {

    // Required for playInputClick() to work
    var enableInputClicksWhenVisible: Bool { return true }

    private var keyboardView: UIViewController?
    private let viewModel = KeyboardViewModel()
    private var feedbackGenerator: UIImpactFeedbackGenerator?
    private var heightConstraint: NSLayoutConstraint?
    /// First viewDidAppear is the cold start — no prior lifecycle to recover
    /// from, so we skip the isUserInteractionEnabled toggle that exists for
    /// recovering touch delivery after background→foreground transitions.
    private var hasAppearedOnce = false
    /// True while our own insert/delete is in flight. Our text edits always
    /// fire textWillChange→textDidChange and incidentally move the selection;
    /// a user tapping elsewhere in the field fires selectionDidChange WITHOUT
    /// a text change. This flag lets selectionDidChange tell the two apart so
    /// only a genuine external caret move clears the composer (the
    /// "안욥하세욥" bug). Cleared on the next runloop tick after textDidChange
    /// because selectionDidChange arrives synchronously within the same edit.
    private var isProgrammaticTextChange = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // self.view (the input container) is briefly stretched to full
        // screen (~956pt) for a frame or two on every globe-key switch —
        // a system layout transient we cannot fully prevent while a height
        // constraint lives on self.view. A solid background painted that
        // big is exactly the giant gray flash the user sees. Keep it clear
        // and clip to bounds so only the hosting view (pinned to 260 via
        // sizingOptions=[]) is ever visible; the SwiftUI KeyboardView paints
        // its own Color(.systemGray6)/background within that 260.
        view.backgroundColor = .clear
        view.clipsToBounds = true

        // Keyboard height. The cumulative globe-switch growth is an iOS 26
        // input-container transition defect (the system directly mutates
        // self.view's frame; verified across 10 attempts, device + simulator,
        // independent Codex + Apple-docs review). This required 260 height
        // is the best-available baseline: it keeps the keyboard content at
        // 260 (via the GeometryReader clamp + sizingOptions=[]) even though
        // it cannot prevent the system's transient container inflation.
        guard let rootView = self.view else { return }
        let heightConstraint = NSLayoutConstraint(
            item: rootView,
            attribute: .height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1.0,
            constant: KeyboardMetrics.keyboardHeight
        )
        heightConstraint.priority = .required
        rootView.addConstraint(heightConstraint)
        self.heightConstraint = heightConstraint

        viewModel.delegate = self
        // Settings must be loaded before SwiftUI hosts the keyboard so the
        // first measure pass sees the user's layout/theme — otherwise the
        // initial frame uses defaults and visibly re-renders once
        // viewWillAppear's loadAll() lands.
        KeyboardSettings.shared.loadAll()
        setupKeyboardView()
        setupHapticFeedback()
        // Audio session warmup removed: it ignored clickSoundEnabled and
        // played an unconditional click on every keyboard show, audible
        // even to users who disabled sounds and inconsistent with normal
        // typing volume. iOS routes the first real AudioServicesPlaySystemSound
        // call fine without explicit warmup.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The keyboard extension lives in a separate process from the main
        // app, so @Published mutations there don't notify our singleton.
        // Reload from App Group UserDefaults on every appearance to pick up
        // theme/gesture/etc. changes the user just made in the host app.
        // No forced layoutIfNeeded — letting UIKit/SwiftUI run their normal
        // layout pass once avoids a visible double-layout flicker on first
        // appearance.
        KeyboardSettings.shared.loadAll()
        // Strip stale self-referential height constraints and re-add a
        // single fresh required 260 so our constraint never compounds with
        // ones the system may add. (This does not stop the system's own
        // direct frame mutation during the transition — that is an iOS 26
        // defect outside extension control — but keeps our side clean.)
        view.constraints
            .filter { $0.firstAttribute == .height && $0.secondItem == nil && ($0.firstItem as? UIView) === view }
            .forEach { view.removeConstraint($0) }
        let h = NSLayoutConstraint(item: view!, attribute: .height,
                                   relatedBy: .equal, toItem: nil,
                                   attribute: .notAnAttribute,
                                   multiplier: 1, constant: KeyboardMetrics.keyboardHeight)
        h.priority = .required
        view.addConstraint(h)
        heightConstraint = h
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Skip the touch-recovery toggle on the very first appearance. It
        // exists to fix touch delivery after background→foreground cycles,
        // and applying it on cold start causes a visible reattach flash.
        if hasAppearedOnce, let hostingView = keyboardView?.view {
            hostingView.isUserInteractionEnabled = false
            hostingView.isUserInteractionEnabled = true
        }
        hasAppearedOnce = true

        // Reset any stuck gesture state (e.g., user was mid-drag when backgrounding)
        viewModel.resetGestureState()
    }

    private func setupKeyboardView() {
        let rootView = KeyboardView(viewModel: viewModel, gestureState: viewModel.gestureState, popupState: viewModel.popupState).ignoresSafeArea(.all)
        let hostingController = UIHostingController(rootView: rootView)
        // Kill the self-sizing feedback loop behind the cumulative
        // globe-switch growth: KeyboardView is a GeometryReader, so it fills
        // whatever height the parent gives and scales keyHeight to it. With
        // default sizingOptions (.intrinsicContentSize) the hosting view
        // reports that grown size back as an Auto Layout constraint that
        // outranks our 999 height — each switch pushed self.view ~+228pt
        // (260→488→716→…→3908). Empty sizingOptions makes the hosting view
        // obey the parent's height constraint instead of inflating it.
        hostingController.sizingOptions = []
        // Keyboard extensions have non-standard safe-area insets; left
        // injected, SwiftUI measures at an unexpected height that feeds back
        // into intrinsicContentSize. Zero them so the 260 stays clean.
        hostingController.additionalSafeAreaInsets = .zero
        hostingController.view.backgroundColor = .clear
        // Manual layout, NOT Auto Layout. During a globe-switch the system
        // directly frame-manipulates self.view (→ ~956pt) and ignores the
        // hosting view's Auto Layout constraints (verified: bottom-pin had
        // zero effect on hostFrame.origin.y). So we position the hosting
        // view by hand in viewDidLayoutSubviews every pass instead.
        hostingController.view.translatesAutoresizingMaskIntoConstraints = true
        hostingController.view.autoresizingMask = []

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        keyboardView = hostingController
        layoutKeyboardHostFrame()
    }

    /// Force the keyboard host to the bottom KeyboardMetrics.keyboardHeight
    /// of self.view, whatever transient height the system imposed. Auto
    /// Layout is bypassed (constraints are ignored mid globe-switch), so
    /// this manual frame is the single source of truth and the keyboard's
    /// on-screen position never moves.
    private func layoutKeyboardHostFrame() {
        guard let host = keyboardView?.view else { return }
        let h = KeyboardMetrics.keyboardHeight
        let w = view.bounds.width
        host.frame = CGRect(x: 0, y: view.bounds.height - h, width: w, height: h)
    }

    private func setupHapticFeedback() {
        feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        feedbackGenerator?.prepare()
    }

    override func textWillChange(_ textInput: UITextInput?) {
        // A text edit is starting. Mark it so the selectionDidChange that
        // rides along with our own insert/delete is not mistaken for the
        // user tapping elsewhere.
        isProgrammaticTextChange = true
    }

    override func textDidChange(_ textInput: UITextInput?) {
        // Reset composer state when text field is cleared externally
        // (e.g., when user sends a message and the app clears the input field)
        // Only reset if the text field is completely empty
        if textDocumentProxy.documentContextBeforeInput == nil &&
           textDocumentProxy.documentContextAfterInput == nil {
            viewModel.resetComposer()
        }
        // Clear on the NEXT runloop tick: the selectionDidChange caused by
        // this same edit fires synchronously before we return here, so the
        // flag must stay set until the edit fully settles.
        DispatchQueue.main.async { [weak self] in
            self?.isProgrammaticTextChange = false
        }
    }

    override func selectionWillChange(_ textInput: UITextInput?) {}

    override func selectionDidChange(_ textInput: UITextInput?) {
        // Selection moved without an accompanying text edit ⇒ the user
        // tapped elsewhere in the host field; iOS already repositioned the
        // caret. Freeze the composer so the next keystroke starts fresh at
        // the new caret. Our programmatic caret moves (moveCursor /
        // auto-bracket) also land here but already cleared the composer, so
        // handleExternalCursorMove is a harmless no-op there.
        if isProgrammaticTextChange { return }
        viewModel.handleExternalCursorMove()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutKeyboardHostFrame()
    }
}

// MARK: - KeyboardViewModelDelegate
extension KeyboardViewController: KeyboardViewModelDelegate {
    func insertText(_ text: String) {
        textDocumentProxy.insertText(text)
    }

    func deleteBackward() {
        textDocumentProxy.deleteBackward()
    }

    func updateComposingText(from previous: String, to current: String) {
        // iOS keyboard extensions don't support marked text directly,
        // so we simulate it by deleting the previous composing text
        // and inserting the new composing text.

        // Delete previous composing characters
        for _ in previous {
            textDocumentProxy.deleteBackward()
        }

        // Insert new composing characters
        if !current.isEmpty {
            textDocumentProxy.insertText(current)
        }
    }

    func switchToNextKeyboard() {
        advanceToNextInputMode()
    }

    func triggerHapticFeedback() {
        HapticManager.shared.playTap()
        if KeyboardSettings.shared.clickSoundEnabled {
            AudioServicesPlaySystemSound(KeyboardMetrics.clickSoundID)
        }
    }

    func moveCursor(by offset: Int) {
        textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
    }
}
