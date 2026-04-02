//
//  EmojiKeyboard.swift
//  iOSExample
//
//  Created by Om More on 29/09/25.
//
import SwiftUI

private enum EmojiKeyboardCategory: String, CaseIterable, Identifiable {
  case smileys = "Smileys"
  case animals = "Animals"
  case food = "Food"
  case activities = "Activities"
  case symbols = "Symbols"

  var id: Self {
    self
  }
}

struct EmojiKeyboard: View {
  let onSelect: (String) -> Void

  @State private var selectedCategory: EmojiKeyboardCategory = .smileys

  private let emojiByCategory: [EmojiKeyboardCategory: [String]] = [
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
      Picker("Category", selection: self.$selectedCategory) {
        ForEach(EmojiKeyboardCategory.allCases) { category in
          Text(category.rawValue).tag(category)
        }
      }
      .pickerStyle(.segmented)
      .padding([.horizontal, .top], 16)

      LazyVGrid(columns: self.columns, spacing: 10) {
        ForEach(self.emojiByCategory[self.selectedCategory] ?? [], id: \.self) { emoji in
          Text(emoji)
            .font(.system(size: 28))
            .onTapGesture {
              self.onSelect(emoji)
            }
        }
      }
      .padding()
    }
    .navigationTitle("Emoji Keyboard")
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button("Clear") {
          self.onSelect("")
        }
      }
    }
  }
}

struct EmojiKeyboard_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      EmojiKeyboard { _ in
      }
    }
  }
}

#Preview("Emoji Keyboard") {
  EmojiKeyboard { _ in }
}
