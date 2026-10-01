import SwiftUI

public extension String {
    static let cisumIconAppStore = "storefront"
    static let cisumIconArrowUpCircle = "arrow.up.circle"
    static let cisumIconBackward = "backward"
    static let cisumIconCheckmarkSimple = "checkmark"
    static let cisumIconClose = "xmark.circle.fill"
    static let cisumIconCloud = "cloud"
    static let cisumIconDocument = "doc.text"
    static let cisumIconFinder = "macwindow"
    static let cisumIconFolder = "folder"
    static let cisumIconForward = "forward"
    static let cisumIconHeart = "heart"
    static let cisumIconInfo = "info.circle"
    static let cisumIconList = "list.bullet"
    static let cisumIconMore = "ellipsis"
    static let cisumIconMusicFill = "music.note"
    static let cisumIconMusicLibrary = "music.note.house"
    static let cisumIconMusicNote = "music.note"
    static let cisumIconMusicNoteList = "music.note.list"
    static let cisumIconPauseFill = "pause.fill"
    static let cisumIconPhotosFill = "photo.on.rectangle.fill"
    static let cisumIconPlayFill = "play.fill"
    static let cisumIconPreviousPage = "chevron.backward"
    static let cisumIconNextPage = "chevron.forward"
    static let cisumIconRepeat1 = "repeat.1"
    static let cisumIconRepeatAll = "repeat"
    static let cisumIconReset = "arrow.counterclockwise"
    static let cisumIconShowInFinder = "arrow.forward.circle"
    static let cisumIconShuffle = "shuffle"
}

public extension Image {
    static var cisumAppStore: Image { Image(systemName: .cisumIconAppStore) }
    static var cisumBackward: Image { Image(systemName: .cisumIconBackward) }
    static var cisumClose: Image { Image(systemName: .cisumIconClose) }
    static var cisumForward: Image { Image(systemName: .cisumIconForward) }
    static var cisumInfo: Image { Image(systemName: .cisumIconInfo) }
    static var cisumList: Image { Image(systemName: .cisumIconList) }
    static var cisumMore: Image { Image(systemName: .cisumIconMore) }
    static var cisumMusicFill: Image { Image(systemName: .cisumIconMusicFill) }
    static var cisumMusicNote: Image { Image(systemName: .cisumIconMusicNote) }
    static var cisumNextPage: Image { Image(systemName: .cisumIconNextPage) }
    static var cisumPauseFill: Image { Image(systemName: .cisumIconPauseFill) }
    static var cisumPlayFill: Image { Image(systemName: .cisumIconPlayFill) }
    static var cisumPreviousPage: Image { Image(systemName: .cisumIconPreviousPage) }
    static var cisumReset: Image { Image(systemName: .cisumIconReset) }

    static func cisumCoffeeReelIcon(
        useDefaultBackground: Bool = true,
        plateColor: Color = .white,
        handleRotation: Double = 30,
        size: CGFloat? = nil
    ) -> some View {
        makeCoffeeReelIcon(
            useDefaultBackground: useDefaultBackground,
            plateColor: plateColor,
            handleRotation: handleRotation,
            size: size
        )
    }

    static func makeCoffeeReelIcon(
        useDefaultBackground: Bool = true,
        plateColor: Color = .white,
        handleRotation: Double = 30,
        size: CGFloat? = nil
    ) -> some View {
        CoffeeReelIcon(
            useDefaultBackground: useDefaultBackground,
            plateColor: plateColor,
            handleRotation: handleRotation
        )
        .frame(width: size, height: size)
    }
}

private struct CoffeeReelIcon: View {
    let showBrownCircle: Bool = true
    let showRedCircle: Bool = false
    let useDefaultBackground: Bool
    let plateColor: Color
    let handleRotation: Double
    let cupColor: Color = Color(red: 0.8, green: 0.6, blue: 0.2)

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let plateSize = size * 0.6
            let cupSize = plateSize * 0.8
            let brownCircleSize = cupSize * 1
            let redCircleSize = brownCircleSize * 0.5
            let dotSize = redCircleSize * 0.5
            let dotOffset = redCircleSize * 0.5
            let centerDotSize = dotSize * 0.6
            let handleWidth = cupSize * 0.16
            let handleLength = cupSize * 0.7

            ZStack {
                if useDefaultBackground {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.2, green: 0.5, blue: 0.4),
                            Color(red: 0.2, green: 0.5, blue: 0.7),
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.clear
                }

                Circle()
                    .stroke(plateColor, lineWidth: plateSize - cupSize)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 3)
                    .frame(width: plateSize, height: plateSize)
                    .mask {
                        Circle()
                            .stroke(.white, lineWidth: plateSize - cupSize)
                            .frame(width: plateSize, height: plateSize)
                            .overlay {
                                Capsule()
                                    .frame(width: handleLength, height: handleWidth)
                                    .offset(x: cupSize * 0.3)
                                    .rotationEffect(.degrees(handleRotation))
                                    .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 2)
                                    .blendMode(.destinationOut)
                            }
                    }

                Circle()
                    .fill(Color.clear)
                    .stroke(cupColor, lineWidth: cupSize * 0.15)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
                    .frame(width: cupSize, height: cupSize)

                if showBrownCircle {
                    Circle()
                        .fill(Color(red: 0.35, green: 0.22, blue: 0.17))
                        .frame(width: brownCircleSize, height: brownCircleSize)
                        .mask {
                            Circle()
                                .fill(Color.white)
                                .frame(width: brownCircleSize, height: brownCircleSize)
                                .overlay {
                                    ZStack {
                                        ForEach(0 ..< 4) { index in
                                            Circle()
                                                .frame(width: dotSize, height: dotSize)
                                                .offset(
                                                    x: dotOffset * cos(Double(index) * .pi / 2),
                                                    y: dotOffset * sin(Double(index) * .pi / 2)
                                                )
                                                .blendMode(.destinationOut)
                                        }

                                        Circle()
                                            .frame(width: centerDotSize, height: centerDotSize)
                                            .blendMode(.destinationOut)
                                    }
                                }
                        }
                }
            }
        }
    }
}
