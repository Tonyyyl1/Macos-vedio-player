import SwiftUI

/// Transient bottom toast shown right after a resume, offering "Start over".
struct ResumeToastView: View {
    let message: String
    let onStartOver: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message).foregroundStyle(.white)
            Button("Start over", action: onStartOver)
                .buttonStyle(.borderless)
                .foregroundStyle(Color.aetherPurple)
        }
        .font(.callout)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.black.opacity(0.7), in: Capsule())
    }
}
