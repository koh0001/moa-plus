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
        // When `onVowelPreview` is provided, hit testing is enabled but the
        // view model's `previewMode` neutralises every input path except the
        // slot B vowel gesture. Otherwise (legacy callers like Appearance
        // settings) all touches are blocked outright.
        .allowsHitTesting(onVowelPreview != nil)
        .onAppear {
            viewModel.previewMode = onVowelPreview != nil
            viewModel.onPreviewVowel = onVowelPreview
        }
        .onChange(of: onVowelPreview != nil) { _, isInteractive in
            viewModel.previewMode = isInteractive
            viewModel.onPreviewVowel = onVowelPreview
        }
    }
}
