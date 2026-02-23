import SwiftUI

struct LanguageSwitcherView: View {
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        Picker(
            KeyLocalized.language_label,
            selection: Binding(
                get: { languageManager.currentLanguage },
                set: languageManager.setLanguage
            )
        ) {
            ForEach(Language.allCases) { lang in
                Text(lang.displayName).tag(lang)
            }
        }
        .pickerStyle(MenuPickerStyle())
    }
}
