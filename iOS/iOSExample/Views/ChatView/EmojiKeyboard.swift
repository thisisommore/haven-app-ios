//
//  EmojiKeyboard.swift
//  iOSExample
//
//  Created by Om More on 29/09/25.
//
import SwiftUI

struct EmojiKeyboard: View {
    let onSelect: (String) -> Void

    private enum Category: String, CaseIterable, Identifiable {
        case smileys = "Smileys"
        case animals = "Animals"
        case food = "Food"
        case activities = "Activities"
        case symbols = "Symbols"
        var id: Self { self }
    }

    @State private var selectedCategory: Category = .smileys

    private let emojiByCategory: [Category: [String]] = [
        .smileys: [
            "😀", "😃", "😄", "😁", "😆", "🥹", "😂", "🤣", "😊", "😇",
            "🙂", "🙃", "😉", "😍", "😘", "😗", "😙", "😚", "🥰", "😋",
            "😜", "😝", "😛", "🫠", "🤗", "🤩", "🤔", "🤨", "😐", "😑",
            "😶", "🙄", "😏", "😣", "😥", "😮", "🤐", "😯", "😪", "😫",
            "🥱", "😴", "😌", "🤤", "😒", "😓", "😔", "😕", "🙁", "☹️",
            "😖", "😞", "😟", "😤", "😢", "😭", "😦", "😧", "😨", "😩",
            "🤯", "😮‍💨", "😵", "🥴", "🤒", "🤕", "🤢", "🤮", "🤧", "🥳",
            "🥺", "🤠", "😎", "🤓", "🧐", "🤬", "👍", "👎", "👏", "🙏",
            "🔥", "💯", "❤️", "🩵", "💔", "✨",
        ],
        .animals: [
            "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯",
            "🦁", "🐮", "🐷", "🐸", "🐵", "🐔", "🐧", "🐦", "🐤", "🐣",
            "🦆", "🦅", "🦉", "🦇", "🐺", "🦄", "🐝", "🪲", "🦋", "🐞",
            "🐢", "🐍", "🦖", "🦕", "🐙", "🦑", "🐬", "🐳", "🐟", "🐠",
        ],
        .food: [
            "🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐",
            "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑",
            "🥦", "🥬", "🥕", "🌽", "🥔", "🍠", "🌶️", "🧄", "🧅", "🍞",
            "🥐", "🥯", "🥖", "🥨", "🧀", "🥚", "🍳", "🥞", "🧇", "🍗",
            "🍖", "🍔", "🍟", "🍕", "🌭", "🌮", "🌯", "🥙", "🥗", "🍝",
            "🍜", "🍣", "🍤", "🍱", "🍙", "🍚", "🍛", "🍰", "🍪", "🍩",
            "🍫", "🍬", "🍭", "🍮", "🍦", "🍨",
        ],
        .activities: [
            "⚽️", "🏀", "🏈", "⚾️", "🎾", "🏐", "🏉", "🎱", "🏓", "🏸",
            "🥅", "🏒", "🏑", "🥍", "🏏", "⛳️", "🏹", "🥊", "🥋", "🎽",
            "🛹", "🛼", "⛸️", "🛷", "🎿", "⛷️", "🏂", "🚴‍♂️", "🚵‍♀️", "🏇",
            "🏊‍♂️", "🤽‍♀️", "🤾‍♂️", "🏌️‍♂️", "🧘‍♀️", "🎯", "🎮", "🧩", "🎲", "♟️",
            "🎻", "🎸", "🎹", "🎺", "🥁", "🎤", "🎧",
        ],
        .symbols: [
            "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔",
            "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "🔔", "🔕",
            "🔒", "🔓", "🔑", "⚙️", "🛠️", "⚠️", "⛔️", "✅", "❌", "➕",
            "➖", "➗", "✖️", "♻️", "🔄", "🔁", "🔂", "⭐️", "🌟", "✨",
            "⚡️", "🔥", "💧", "❄️", "🌈", "☀️", "☁️", "☂️",
        ],
    ]

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 8)

    var body: some View {
        ScrollView {
            Picker("Category", selection: $selectedCategory) {
                ForEach(Category.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top], 16)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(emojiByCategory[selectedCategory] ?? [], id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 28))
                        .onTapGesture {
                            onSelect(emoji)
                        }
                }
            }
            .padding()
        }
        .navigationTitle("Emoji Keyboard")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    onSelect("")
                }
            }
        }
    }
}

struct EmojiKeyboard_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EmojiKeyboard { emoji in
                print("Selected emoji: \(emoji)")
            }
        }
    }
}

#Preview("Emoji Keyboard") {
    EmojiKeyboard { _ in }
}
