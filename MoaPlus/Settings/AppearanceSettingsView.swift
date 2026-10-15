import SwiftUI
import PhotosUI
import TOCropViewController

struct AppearanceSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var backgroundPreview: UIImage?
    @State private var cropItem: CropItem?

    var body: some View {
        List {
            Section {
                Picker("모드", selection: $settings.themeSettings.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("테마 모드")
            }

            Section {
                ForEach(ButtonTheme.allCases.filter { $0 != .custom }) { theme in
                    Button(action: {
                        settings.themeSettings.buttonTheme = theme
                    }) {
                        HStack {
                            themePreviewSwatch(
                                bg: theme.keyBackgroundColor,
                                text: theme.keyTextColor
                            )
                            Text(theme.displayName)
                                .foregroundColor(Color(.label))
                            Spacer()
                            if settings.themeSettings.buttonTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }

                // Custom option
                Button(action: {
                    settings.themeSettings.buttonTheme = .custom
                }) {
                    HStack {
                        themePreviewSwatch(
                            bg: settings.themeSettings.customKeyBackground.color,
                            text: settings.themeSettings.customKeyText.color
                        )
                        Text("커스텀")
                            .foregroundColor(Color(.label))
                        Spacer()
                        if settings.themeSettings.buttonTheme == .custom {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            } header: {
                Text("버튼 색상 테마")
            }

            // Custom color pickers
            if settings.themeSettings.buttonTheme == .custom {
                Section {
                    ColorPicker("키 배경색", selection: customKeyBgBinding)
                    ColorPicker("키 글자색", selection: customKeyTextBinding)
                    ColorPicker("기능키 배경색", selection: customFuncBgBinding)
                } header: {
                    Text("커스텀 색상")
                } footer: {
                    Text("키보드 미리보기에서 실시간으로 확인할 수 있습니다.")
                }
            }

            // Key opacity
            Section {
                HStack {
                    Text("키 배경 투명도")
                    Spacer()
                    Text("\(Int(settings.themeSettings.keyBackgroundOpacity * 100))%")
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.themeSettings.keyBackgroundOpacity, in: 0.1...1.0, step: 0.05)

                HStack {
                    Text("기능키 배경 투명도")
                    Spacer()
                    Text("\(Int(settings.themeSettings.functionKeyBackgroundOpacity * 100))%")
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.themeSettings.functionKeyBackgroundOpacity, in: 0.1...1.0, step: 0.05)
            } header: {
                Text("키 투명도")
            } footer: {
                Text("배경 이미지를 사용할 때 키를 반투명하게 하면 배경이 보입니다.")
            }

            // Background Image
            Section {
                // Keyboard preview — renders the real production KeyboardView
                // so theme / background / opacity changes match exactly what
                // the user sees when typing.
                KeyboardPreviewView()
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                // Image picker
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("사진 선택", systemImage: "photo.on.rectangle")
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    Task {
                        guard let data = try? await newItem?.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else { return }
                        await MainActor.run {
                            cropItem = CropItem(image: image)
                        }
                    }
                }

                // Remove background
                if settings.themeSettings.backgroundImageId != nil {
                    Button(role: .destructive) {
                        if let oldId = settings.themeSettings.backgroundImageId {
                            BackgroundImageManager.shared.deleteUserImage(withId: oldId)
                        }
                        settings.themeSettings.backgroundImageId = nil
                        backgroundPreview = nil
                    } label: {
                        Label("배경 이미지 제거", systemImage: "trash")
                    }
                }

                // 사진 맞춤 · 크기 (이슈 #39 — 앱스토어 리뷰 "키보드 배경 사진 크기 작게 안 됩니다")
                // 사진이 있을 때만 의미가 있다. 위 미리보기가 실제 키보드와 같은 뷰라 바로 반영된다.
                if settings.themeSettings.backgroundImageId != nil {
                    // 세그먼트 피커는 제목을 화면에 그리지 않는다 — 위에 따로 보이게 두고,
                    // VoiceOver 에도 같은 이름을 준다.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("사진 맞춤")
                        Picker("사진 맞춤", selection: $settings.themeSettings.backgroundImageContentMode) {
                            ForEach(BackgroundImageContentMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .accessibilityLabel("사진 맞춤")
                    }

                    HStack {
                        Text("사진 크기")
                        Spacer()
                        Text("\(backgroundImageScalePercent)%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: backgroundImageScaleBinding,
                           in: ThemeSettings.backgroundImageScaleRange,
                           step: ThemeSettings.backgroundImageScaleStep)
                        .accessibilityLabel("사진 크기")
                        .accessibilityValue("\(backgroundImageScalePercent)%")
                }

                // Opacity slider
                HStack {
                    Text("배경 투명도")
                    Spacer()
                    Text("\(Int(settings.themeSettings.backgroundOpacity * 100))%")
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.themeSettings.backgroundOpacity, in: 0...0.6, step: 0.05)
            } header: {
                Text("배경 이미지")
            } footer: {
                // 이슈 #39 리뷰: 자르기 화면은 사진을 **고정 비율 375:260** 으로 자른다(아래 `.sheet`).
                // 실제 키보드 비율은 폰 폭(375~440pt)·높이 배율(85~135%)에 따라 달라서, 꽉 채우기는
                // 그 차이만큼 가장자리를 더 자르고(440pt 폰 기본 높이에서 사진 높이의 ~15%) 전체 보이기는
                // 그만큼을 되살린다. 자를 때 뺀 부분은 어떤 설정으로도 돌아오지 않는다 — 다시 골라야 한다.
                Text("사진을 고를 때 자른 범위가 배경이 됩니다. 꽉 채우기는 키보드 폭·높이에 맞추느라 가장자리가 조금 더 잘릴 수 있고, ‘전체 보이기’는 자른 범위를 빠짐없이 보여 줍니다. 사진 크기를 줄이면 사진이 덮지 않는 곳은 기본 배경색으로 보입니다. 자를 때 뺀 부분을 쓰려면 사진을 다시 고르세요. 투명도를 조절하여 키 가독성을 유지하세요.")
            }
        }
        .navigationTitle("외형")
        .onAppear {
            if let imageId = settings.themeSettings.backgroundImageId {
                backgroundPreview = BackgroundImageManager.shared.loadUserImage(withId: imageId)
            }
        }
        .sheet(item: $cropItem) { item in
            CropViewWrapper(
                image: item.image,
                aspectRatio: CGSize(width: 375, height: 260)
            ) { cropped in
                saveCroppedImage(cropped)
            }
        }
    }

    // MARK: - Helpers

    /// "사진 크기 N%" — 그리는 크기와 같은 잘라 쓴 값 (`ThemeSettings.backgroundImageScalePercent`).
    private var backgroundImageScalePercent: Int {
        ThemeSettings.backgroundImageScalePercent(settings.themeSettings.backgroundImageScale)
    }

    /// 슬라이더도 그리는 크기와 같은 잘라 쓴 값을 보여 준다 — 범위 밖·NaN 저장값이어도
    /// 슬라이더 위치와 % 표시, 실제 크기가 서로 어긋나지 않는다.
    private var backgroundImageScaleBinding: Binding<Double> {
        Binding(
            get: { ThemeSettings.clampedBackgroundImageScale(settings.themeSettings.backgroundImageScale) },
            set: { settings.themeSettings.backgroundImageScale = $0 }
        )
    }

    private func saveCroppedImage(_ image: UIImage) {
        let imageId = UUID().uuidString
        if BackgroundImageManager.shared.saveUserImage(image, withId: imageId) {
            if let oldId = settings.themeSettings.backgroundImageId {
                BackgroundImageManager.shared.deleteUserImage(withId: oldId)
            }
            settings.themeSettings.backgroundImageId = imageId
            backgroundPreview = image
        }
    }

    private func themePreviewSwatch(bg: Color, text: Color) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(bg)
            .overlay(
                Text("ㄱ")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(text)
            )
            .frame(width: 36, height: 36)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
    }

    private var customKeyBgBinding: Binding<Color> {
        Binding(
            get: { settings.themeSettings.customKeyBackground.color },
            set: { settings.themeSettings.customKeyBackground = CodableColor(from: $0) }
        )
    }

    private var customKeyTextBinding: Binding<Color> {
        Binding(
            get: { settings.themeSettings.customKeyText.color },
            set: { settings.themeSettings.customKeyText = CodableColor(from: $0) }
        )
    }

    private var customFuncBgBinding: Binding<Color> {
        Binding(
            get: { settings.themeSettings.customFunctionKeyBackground.color },
            set: { settings.themeSettings.customFunctionKeyBackground = CodableColor(from: $0) }
        )
    }
}

// MARK: - TOCropViewController SwiftUI Wrapper

struct CropViewWrapper: UIViewControllerRepresentable {
    let image: UIImage
    let aspectRatio: CGSize
    let onCrop: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UINavigationController {
        let cropVC = TOCropViewController(image: image)
        cropVC.delegate = context.coordinator
        cropVC.aspectRatioPreset = aspectRatio
        cropVC.aspectRatioLockEnabled = true
        cropVC.resetAspectRatioEnabled = false
        cropVC.aspectRatioPickerButtonHidden = true
        cropVC.toolbarPosition = .bottom
        cropVC.doneButtonTitle = "적용"
        cropVC.cancelButtonTitle = "취소"
        return UINavigationController(rootViewController: cropVC)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCrop: onCrop, dismiss: dismiss)
    }

    class Coordinator: NSObject, TOCropViewControllerDelegate {
        let onCrop: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCrop: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCrop = onCrop
            self.dismiss = dismiss
        }

        func cropViewController(_ cropViewController: TOCropViewController, didCropTo image: UIImage, with cropRect: CGRect, angle: Int) {
            onCrop(image)
            dismiss()
        }

        func cropViewController(_ cropViewController: TOCropViewController, didFinishCancelled cancelled: Bool) {
            dismiss()
        }
    }
}

// MARK: - Keyboard Preview Card

struct KeyboardPreviewCard: View {
    let backgroundImage: UIImage?
    let opacity: Double
    let themeSettings: ThemeSettings

    // Actual keyboard ratio
    private let kbRatio: CGFloat = 375.0 / 260.0

    var body: some View {
        // Fixed aspect ratio container
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))

            if let image = backgroundImage {
                KeyboardBackgroundImageView(
                    image: image,
                    opacity: opacity,
                    contentMode: themeSettings.backgroundImageContentMode,
                    scale: themeSettings.backgroundImageScale
                )
            }

            // Keys
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let pad: CGFloat = 4
                let sp: CGFloat = 2
                let innerW = w - pad * 2
                let sideRatio = CGFloat(KeyboardSettings.shared.sideKeyWidthRatio)
                // Same formula as KeyboardMetrics: side = center * sideRatio
                let ckw = innerW / (sideRatio * 2 + 5 + sp * 6 / (innerW / (sideRatio * 2 + 5)))
                let sw = ckw * sideRatio
                let rowH = (h - pad * 2 - sp * 4) / 5  // 4 key rows + 1 func row

                VStack(spacing: sp) {
                    keyRow(["~"], ["ㅃ","ㅉ","ㄸ","ㄲ","ㅆ"], ["#"], sw: sw, ckw: ckw, sp: sp, h: rowH)
                    // Row 1: backspace moved into col 6
                    HStack(spacing: sp) {
                        sideCell("^", w: sw, h: rowH)
                        ForEach(["ㅂ","ㅈ","ㄷ","ㄱ","ㅅ"], id: \.self) { keyCell($0, w: ckw, h: rowH) }
                        funcCell("⌫", w: sw, h: rowH)
                    }
                    // Row 2: ㅣ vowel primitive in col 6
                    keyRow([";"], ["ㅁ","ㄴ","ㅇ","ㄹ","ㅎ"], ["ㅣ"], sw: sw, ckw: ckw, sp: sp, h: rowH)
                    // Row 3: ㅡ at col 5, ㆍ at col 6 (천지인 vowel primitives)
                    HStack(spacing: sp) {
                        sideCell("*", w: sw, h: rowH)
                        ForEach(["ㅋ","ㅌ","ㅊ","ㅍ","ㅡ"], id: \.self) { keyCell($0, w: ckw, h: rowH) }
                        sideCell("ㆍ", w: sw, h: rowH)
                    }
                    // Function row: [123] [한/영] [space (drag cursor)] [punct] [⏎]
                    HStack(spacing: sp) {
                        let funcW = innerW - sp * 4
                        funcCell("123", w: funcW * 0.12, h: rowH)
                        funcCell("한/영", w: funcW * 0.14, h: rowH)
                        funcCell("", w: funcW * 0.50, h: rowH)
                        funcCell("·", w: funcW * 0.10, h: rowH)
                        funcCell("⏎", w: funcW * 0.14, h: rowH)
                    }
                }
                .padding(pad)
            }
        }
        .aspectRatio(kbRatio, contentMode: .fit)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    private func keyRow(_ left: [String], _ center: [String], _ right: [String], sw: CGFloat, ckw: CGFloat, sp: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: sp) {
            ForEach(left, id: \.self) { sideCell($0, w: sw, h: h) }
            ForEach(center, id: \.self) { keyCell($0, w: ckw, h: h) }
            ForEach(right, id: \.self) { sideCell($0, w: sw, h: h) }
        }
    }

    private func keyCell(_ label: String, w: CGFloat, h: CGFloat) -> some View {
        Text(label)
            .font(.system(size: min(h * 0.5, 10), weight: .medium))
            .foregroundColor(themeSettings.resolvedKeyText)
            .frame(width: w, height: h)
            .background(themeSettings.resolvedKeyBackground.opacity(0.9))
            .cornerRadius(2)
    }

    private func sideCell(_ label: String, w: CGFloat, h: CGFloat) -> some View {
        Text(label)
            .font(.system(size: min(h * 0.4, 7), weight: .medium))
            .foregroundColor(themeSettings.resolvedKeyText.opacity(0.7))
            .frame(width: w, height: h)
            .background(themeSettings.resolvedFunctionKeyBackground.opacity(0.7))
            .cornerRadius(2)
    }

    private func funcCell(_ label: String, w: CGFloat, h: CGFloat) -> some View {
        Text(label)
            .font(.system(size: min(h * 0.45, 8), weight: .medium))
            .foregroundColor(themeSettings.resolvedKeyText)
            .frame(width: w, height: h)
            .background(themeSettings.resolvedFunctionKeyBackground.opacity(0.9))
            .cornerRadius(2)
    }

    private func miniKey(_ label: String, width: CGFloat) -> some View {
        Text(label)
            .font(.system(size: min(width * 0.4, 11), weight: .medium))
            .foregroundColor(themeSettings.resolvedKeyText)
            .frame(width: width, height: 20)
            .background(themeSettings.resolvedKeyBackground.opacity(0.9))
            .cornerRadius(3)
    }

    private func miniSideKey(_ label: String, width: CGFloat) -> some View {
        Text(label)
            .font(.system(size: 7, weight: .medium))
            .foregroundColor(themeSettings.resolvedKeyText.opacity(0.7))
            .frame(width: width, height: 20)
            .background(themeSettings.resolvedFunctionKeyBackground.opacity(0.7))
            .cornerRadius(3)
    }

    private func miniFuncKey(_ label: String, width: CGFloat) -> some View {
        Text(label)
            .font(.system(size: min(width * 0.35, 9), weight: .medium))
            .foregroundColor(themeSettings.resolvedKeyText)
            .frame(width: width, height: 20)
            .background(themeSettings.resolvedFunctionKeyBackground.opacity(0.9))
            .cornerRadius(3)
    }
}

// MARK: - Crop Item (Identifiable wrapper for sheet(item:))

struct CropItem: Identifiable {
    let id = UUID()
    let image: UIImage
}
