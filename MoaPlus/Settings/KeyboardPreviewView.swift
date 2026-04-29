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
        // Block all touches so the preview cannot mutate composer state.
        .allowsHitTesting(false)
    }
}
