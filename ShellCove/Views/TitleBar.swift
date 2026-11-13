import SwiftUI

struct TitleBar: View {
    @Environment(AppStore.self) private var store
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var store = store

        HStack(spacing: 11) {
            BrandMark()
            Text("ShellCove")
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.2)

            Spacer(minLength: 16)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)

                TextField("搜索服务器", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .focused($searchFocused)

                if !store.searchText.isEmpty {
                    Button {
                        store.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                } else {
                    Text("⌘F")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(.horizontal, 9)
            .frame(width: 232, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7).fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.hairline)
            )
            .onTapGesture { searchFocused = true }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.42, green: 0.49, blue: 1.0),
                            Color(red: 0.62, green: 0.36, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Text("L")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .frame(width: 24, height: 24)
        }
        // 左侧留出系统红绿灯的位置
        .padding(.leading, 78)
        .padding(.trailing, 16)
        .frame(height: Theme.titleBarHeight)
    }
}
