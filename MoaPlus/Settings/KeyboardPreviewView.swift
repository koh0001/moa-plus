import SwiftUI

/// Renders the production `KeyboardView` at preview scale with all gestures
/// disabled. Used in Appearance settings so theme/background changes are
/// shown using the exact same SwiftUI tree the keyboard extension renders.
///
/// Why this works without the keyboard extension running: the host app
/// target compiles the extension's `KeyboardView`, `KeyboardViewModel`,
/// and supporting types via the `MoaPlusKeyboard` synchronized folder
/// cross-membership exception set in `project.pbxproj`. The view model's
/// `delegate` stays `nil` so any internal `delegate?.insertText(...)` calls
/// silently no-op.
struct KeyboardPreviewView: View {
    @StateObject private var viewModel = KeyboardViewModel()

    /// When set, the preview routes the slot B vowel-key gesture into this
    /// closure (with the resolved Jungseong) so callers can show "what would
    /// be input" without affecting any text field. Setting this also enables
    /// hit testing on the preview — all other keys still no-op via the view
    /// model's `previewMode` flag.
    var onVowelPreview: ((Jungseong) -> Void)? = nil

    /// Same as `onVowelPreview` but also delivers the gesture start point in
    /// the keyboard preview's coordinate space (named "keyboardPreview"),
    /// so callers can position UI relative to where the user touched.
    var onVowelPreviewWithPoint: ((Jungseong, CGPoint) -> Void)? = nil

    /// When set, consonant-key gestures inside the preview route their
    /// (phase, directions, vowel) snapshot to this closure so callers (the
    /// gesture test screen) can mirror the production analyzer/resolver
    /// output without affecting any text field.
    var onConsonantPreview: ((KeyboardViewModel.PreviewGesturePhase, [GestureDirection], Jungseong?) -> Void)? = nil

    /// Forces a specific column id (1-5) for per-column gesture corrections,
    /// regardless of which consonant key the user actually touched. Used by
    /// the gesture test screen so the column-picker selection drives the
    /// rotation/width corrections applied to the live trace.
    var consonantPreviewColumnOverride: Int = 0

    /// When `true`, the gesture overlay (trail + direction arrows) is always
    /// shown inside this preview regardless of the global `showGesturePreview`
    /// setting. Set to `true` in `GestureTestView` so users can always observe
    /// the angle effect even if they have the global toggle off.
    var forceShowGesturePreview: Bool = false

    private var isInteractive: Bool {
        onVowelPreview != nil || onVowelPreviewWithPoint != nil || onConsonantPreview != nil
    }

    /// Real keyboard aspect ratio (375pt host width / 260pt extension height).
    private let kbAspect: CGFloat = 375.0 / 260.0

    var body: some View {
        KeyboardView(
            viewModel: viewModel,
            gestureState: viewModel.gestureState,
            popupState: viewModel.popupState
        )
        .aspectRatio(kbAspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        // When either preview callback is provided, hit testing is enabled
        // but the view model's `previewMode` neutralises every input path
        // except the slot B vowel gesture. Otherwise (legacy callers like
        // Appearance settings) all touches are blocked outright.
        .allowsHitTesting(isInteractive)
        .onAppear {
            viewModel.previewMode = isInteractive
            viewModel.onPreviewVowel = onVowelPreview
            viewModel.onPreviewVowelDetailed = onVowelPreviewWithPoint
            viewModel.onPreviewConsonantGesture = onConsonantPreview
            viewModel.previewColumnOverride = consonantPreviewColumnOverride
            viewModel.forceShowGesturePreview = forceShowGesturePreview
        }
        .onChange(of: isInteractive) { _, newValue in
            viewModel.previewMode = newValue
            viewModel.onPreviewVowel = onVowelPreview
            viewModel.onPreviewVowelDetailed = onVowelPreviewWithPoint
            viewModel.onPreviewConsonantGesture = onConsonantPreview
            viewModel.previewColumnOverride = consonantPreviewColumnOverride
            viewModel.forceShowGesturePreview = forceShowGesturePreview
        }
        .onChange(of: consonantPreviewColumnOverride) { _, newValue in
            viewModel.previewColumnOverride = newValue
        }
    }
}
