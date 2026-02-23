import SwiftUI

struct IntroPageItem: Identifiable {
    let id: String
    var image: String
    var title: String
    var scale: CGFloat
    var anchor: UnitPoint
    var offset: CGFloat
    var rotation: CGFloat
    var zindex: CGFloat
    var extraOffset: CGFloat
    var description: String

    init(
        id: String = UUID().uuidString,
        image: String,
        title: String,
        scale: CGFloat = 1,
        anchor: UnitPoint = .center,
        offset: CGFloat = .zero,
        rotation: CGFloat = .zero,
        zindex: CGFloat = .zero,
        extraOffset: CGFloat = -350,
        description: String
    ) {
        self.id = id
        self.image = image
        self.title = title
        self.scale = scale
        self.anchor = anchor
        self.offset = offset
        self.rotation = rotation
        self.zindex = zindex
        self.extraOffset = extraOffset
        self.description = description
    }
}

extension IntroPageItem {
    static var placeholder: IntroPageItem {
        .init(image: "shield.lock", title: "", description: "")
    }
}
