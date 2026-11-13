import SwiftUI

/// 轻量 Markdown 渲染器。只覆盖用途说明会用到的语法：
/// 标题、段落、无序/有序列表、引用、代码块、分隔线与行内样式。
/// 不引入第三方 Markdown 依赖，保持「轻」。
struct MarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    // MARK: - 渲染

    @ViewBuilder
    private func view(for block: Block) -> some View {
        switch block {
        case .heading(let level, let content):
            inline(content)
                .font(.system(size: level == 1 ? 15 : level == 2 ? 13.5 : 12.8, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 3)

        case .paragraph(let content):
            inline(content)
                .font(.system(size: 12.8))
                .foregroundStyle(.secondary)
                .lineSpacing(4)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("•")
                            .font(.system(size: 12.8, weight: .semibold))
                            .foregroundStyle(Theme.accent.opacity(0.8))
                        inline(item)
                            .font(.system(size: 12.8))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

        case .ordered(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("\(index + 1).")
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(Theme.accent.opacity(0.85))
                            .frame(width: 16, alignment: .trailing)
                        inline(item)
                            .font(.system(size: 12.8))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

        case .code(let content):
            Text(content)
                .font(.system(size: 11.2, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 7).fill(Theme.surfaceStrong)
                )

        case .quote(let content):
            HStack(alignment: .top, spacing: 9) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent.opacity(0.5))
                    .frame(width: 2)
                inline(content)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .divider:
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
                .padding(.vertical, 2)
        }
    }

    private func inline(_ string: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(string)
    }

    // MARK: - 解析

    private enum Block {
        case heading(Int, String)
        case paragraph(String)
        case bullets([String])
        case ordered([String])
        case code(String)
        case quote(String)
        case divider
    }

    private var blocks: [Block] {
        var result: [Block] = []
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        var index = 0
        var paragraph: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            result.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph.removeAll()
        }

        while index < lines.count {
            let rawLine = lines[index]
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                flushParagraph()
                var code: [String] = []
                index += 1
                while index < lines.count,
                      !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[index])
                    index += 1
                }
                result.append(.code(code.joined(separator: "\n")))
                index += 1
                continue
            }

            if line.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            if line.hasPrefix("#") {
                flushParagraph()
                let level = line.prefix { $0 == "#" }.count
                let content = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
                result.append(.heading(min(level, 3), content))
                index += 1
                continue
            }

            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                flushParagraph()
                var items: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard candidate.hasPrefix("- ") || candidate.hasPrefix("* ") || candidate.hasPrefix("+ ") else {
                        break
                    }
                    items.append(String(candidate.dropFirst(2)))
                    index += 1
                }
                result.append(.bullets(items))
                continue
            }

            if let firstItem = orderedItem(line) {
                flushParagraph()
                var items = [firstItem]
                index += 1
                while index < lines.count,
                      let next = orderedItem(lines[index].trimmingCharacters(in: .whitespaces)) {
                    items.append(next)
                    index += 1
                }
                result.append(.ordered(items))
                continue
            }

            if line.hasPrefix("> ") {
                flushParagraph()
                result.append(.quote(String(line.dropFirst(2))))
                index += 1
                continue
            }

            if line == "---" || line == "***" {
                flushParagraph()
                result.append(.divider)
                index += 1
                continue
            }

            paragraph.append(line)
            index += 1
        }

        flushParagraph()
        return result
    }

    private func orderedItem(_ line: String) -> String? {
        guard let dot = line.firstIndex(of: ".") else { return nil }
        let number = line[..<dot]
        guard !number.isEmpty,
              number.count <= 2,
              number.allSatisfy(\.isNumber) else { return nil }
        let rest = line[line.index(after: dot)...]
        guard rest.hasPrefix(" ") else { return nil }
        return String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
    }
}
