import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            // App header with icon gradient
            Section {
                VStack(spacing: 14) {
                    Image("AppIconImage")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Color(red: 0.26, green: 0.38, blue: 0.93).opacity(0.3), radius: 8, y: 3)

                    Text("모아+")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("손끝으로 완성하는 한글")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            // Special Thanks
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Special Thanks")
                            .font(.headline)
                    }

                    Text("이 앱은 Jeffrey (Dongkyu) Kim님의 오픈소스 프로젝트를 기반으로 합니다.")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    Link(destination: URL(string: "https://github.com/vkehfdl1/ios-moaki")!) {
                        HStack {
                            Image(systemName: "link")
                            Text("원본 프로젝트 보기")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("감사의 말")
            }

            // Open Source Licenses
            Section {
                DisclosureGroup {
                    Text(mitLicenseText(copyright: "Copyright (c) 2025 Jeffrey (Dongkyu) Kim"))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } label: {
                    HStack {
                        Text("ios-moaki")
                            .font(.body)
                        Spacer()
                        Text("MIT")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                DisclosureGroup {
                    Text(mitLicenseText(copyright: "Copyright (c) 2015-2024 Tim Oliver"))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } label: {
                    HStack {
                        Text("TOCropViewController")
                            .font(.body)
                        Spacer()
                        Text("MIT")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("오픈소스 라이선스")
            }

            // Feedback
            Section {
                Link(destination: URL(string: "mailto:koh0001@outlook.kr")!) {
                    HStack {
                        Label("이메일 문의", systemImage: "envelope")
                        Spacer()
                        Text("koh0001@outlook.kr")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Link(destination: URL(string: "https://github.com/koh0001/moa-plus/issues")!) {
                    HStack {
                        Label("버그 신고 / 기능 제안", systemImage: "ladybug")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("피드백")
            } footer: {
                Text("버그, 개선 요청, 아이디어 등 무엇이든 환영합니다.")
            }

            // Links
            Section {
                Link(destination: URL(string: "https://github.com/koh0001")!) {
                    HStack {
                        Label("개발자 GitHub", systemImage: "person.crop.circle")
                        Spacer()
                        Text("0k_hyun")
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("링크")
            }

            // Footer
            Section {
            } footer: {
                VStack(spacing: 4) {
                    Text("Based on ios-moaki by Jeffrey Kim")
                    Text("Customized by 0k_hyun")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
        }
        .navigationTitle("앱 정보")
    }

    private func mitLicenseText(copyright: String) -> String {
        """
        MIT License

        \(copyright)

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
        """
    }
}

