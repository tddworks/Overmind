import SwiftUI

/// AgentNexus's Pop language (design-concept/overmind-pop.html): cream paper, ink outlines,
/// hard shadows; Cloudflare orange for today's use.
enum Pop {
    static let cream = Color(red: 0.992, green: 0.961, blue: 0.918)
    static let paper = Color.white
    static let ink = Color(red: 0.106, green: 0.086, blue: 0.075)
    static let mint = Color(red: 0.557, green: 0.890, blue: 0.690)
    static let mintDeep = Color(red: 0.361, green: 0.796, blue: 0.549)
    static let grape = Color(red: 0.545, green: 0.361, blue: 0.965)
    static let grapeSoft = Color(red: 0.914, green: 0.871, blue: 1.0)
    static let coral = Color(red: 1.0, green: 0.478, blue: 0.400)
    static let coralSoft = Color(red: 1.0, green: 0.882, blue: 0.855)
    static let butter = Color(red: 1.0, green: 0.851, blue: 0.400)
    static let butterSoft = Color(red: 1.0, green: 0.973, blue: 0.902)
    static let sky = Color(red: 0.561, green: 0.827, blue: 1.0)
    static let pink = Color(red: 1.0, green: 0.710, blue: 0.847)
    static let edge = Color(red: 0.965, green: 0.510, blue: 0.122)
    static let edgeSoft = Color(red: 1.0, green: 0.902, blue: 0.812)
    static let muted = Color(red: 0.420, green: 0.384, blue: 0.357)
    static let dash = Color(red: 0.894, green: 0.847, blue: 0.792)
    static let well = Color(red: 0.969, green: 0.945, blue: 0.910)

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .monospaced) }

    /// A definition file's colour name.
    static func named(_ name: String) -> Color {
        switch name {
        case "sky": sky
        case "butter": butter
        case "mint": mint
        case "coral": coral
        case "pink": pink
        case "grape": grapeSoft
        default: edgeSoft
        }
    }
}

/// A card: paper, an ink border, a hard offset shadow.
struct PopCard: ViewModifier {
    var fill: Color = Pop.paper
    var radius: CGFloat = 14
    var shadow: Color = Pop.ink
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Pop.ink, lineWidth: 2.5))
            .background(RoundedRectangle(cornerRadius: radius).fill(shadow).offset(x: 3, y: 3))
            .compositingGroup()
    }
}

extension View {
    func popCard(_ fill: Color = Pop.paper, radius: CGFloat = 14, shadow: Color = Pop.ink) -> some View {
        modifier(PopCard(fill: fill, radius: radius, shadow: shadow))
    }
}

/// A small pill label: "OK", "WATCH", "LIVE".
struct Chip: View {
    let text: String
    let fill: Color
    var foreground: Color = Pop.ink
    var body: some View {
        Text(text).font(Pop.label(9)).foregroundStyle(foreground).fixedSize()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(fill))
            .overlay(Capsule().stroke(Pop.ink, lineWidth: 1.5))
    }
}

/// An ink-outlined switch: a capsule with a knob.
struct PopSwitch: View {
    let isOn: Bool
    let tell: () -> Void

    var body: some View {
        Button(action: tell) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Pop.mint : Color(red: 0.914, green: 0.871, blue: 0.812))
                Circle().fill(Pop.ink).frame(width: 10, height: 10).padding(.horizontal, 2.5)
            }
            .frame(width: 28, height: 16)
            .overlay(Capsule().stroke(Pop.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

/// A chunky footer button with a hard shadow.
struct PopButton: View {
    let title: String
    var fill: Color = Pop.paper
    var width: CGFloat? = nil
    let tell: () -> Void

    var body: some View {
        Button(action: tell) {
            Text(title).font(Pop.label(12)).foregroundStyle(Pop.ink).lineLimit(1)
                .frame(maxWidth: width == nil ? .infinity : nil).frame(width: width)
                .padding(.vertical, 8).padding(.horizontal, width == nil ? 6 : 0)
                .popCard(fill, radius: 12)
        }
        .buttonStyle(.plain)
    }
}

/// A rounded square with a glyph: a service's or the app's icon.
struct Badge: View {
    let glyph: String
    let fill: Color
    var size: CGFloat = 22
    var foreground: Color = Pop.ink

    var body: some View {
        Text(glyph).font(Pop.label(size * 0.5)).foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.3).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: size * 0.3).stroke(Pop.ink, lineWidth: 2))
    }
}

/// Overmind's logo, an eye in a cloud, as a Pop tile: ink outline, hard shadow.
struct Logo: View {
    var size: CGFloat = 34

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: size * 0.3)
        Image("Logo").resizable().interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(tile)
            .overlay(tile.stroke(Pop.ink, lineWidth: 2))
            .background(tile.fill(Pop.ink).offset(x: 2, y: 2))
    }
}

/// The tilted sticker on a card: "CLOSEST TO THE LIMIT".
struct Sticker: View {
    let text: String
    var fill: Color = Pop.butter

    var body: some View {
        Text(text).font(Pop.label(9.5)).foregroundStyle(Pop.ink)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 7).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Pop.ink, style: StrokeStyle(lineWidth: 2, dash: [4, 2])))
            .background(RoundedRectangle(cornerRadius: 7).fill(Pop.ink).offset(x: 2.5, y: 2.5))
            .rotationEffect(.degrees(-4))
    }
}

/// Concentric corners (Apple HIG), as in AgentNexus: an inner shape's corners follow its
/// container's — `ConcentricRectangle` within a `.containerShape(…)` on macOS 26+; before that
/// the same rule by hand. Inside a capsule, concentric means round.
enum Concentric {
    static func shape(fallback radius: CGFloat) -> AnyShape {
        if #available(macOS 26.0, *) {
            AnyShape(ConcentricRectangle())
        } else {
            AnyShape(RoundedRectangle(cornerRadius: max(radius, 0)))
        }
    }

    static let inCapsule: CGFloat = 999
}

/// A tab pill: icon, title, and a count when there is one.
struct TabPill: View {
    let icon: String
    let title: String
    var count: String? = nil
    let tint: Color
    let isOn: Bool
    let tell: () -> Void

    var body: some View {
        Button(action: tell) {
            HStack(spacing: 4) {
                Text(icon).font(Pop.label(9.5)).foregroundStyle(Pop.ink)
                    .frame(width: 17, height: 17)
                    .background(Concentric.shape(fallback: Concentric.inCapsule).fill(tint))
                    .overlay(Concentric.shape(fallback: Concentric.inCapsule).stroke(isOn ? .white : Pop.ink, lineWidth: 2))
                Text(title).font(Pop.label(11.5)).fixedSize()
                if let count {
                    Text(count).font(Pop.label(9)).foregroundStyle(isOn ? Pop.ink : .white).fixedSize()
                        .padding(.horizontal, 5).background(Capsule().fill(isOn ? .white : Pop.ink))
                }
            }
            .foregroundStyle(isOn ? .white : Pop.ink)
            .padding(.leading, 4).padding(.trailing, 9).padding(.vertical, 4)
            .background(Capsule().fill(isOn ? Pop.grape : Pop.paper))
            .overlay(Capsule().stroke(Pop.ink, lineWidth: 2.5))
            .background(Capsule().fill(Pop.ink).offset(x: 2, y: 2))
            .containerShape(Capsule())   // what the icon is concentric with
        }
        .buttonStyle(.plain)
    }
}

/// The outlined big number: "18% of 5M".
struct Outlined: View {
    let text: String
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            ForEach([(-1.5, 0.0), (1.5, 0.0), (0.0, -1.5), (0.0, 1.5), (2.5, 2.5)], id: \.0.self) { offset in
                Text(text).font(Pop.display(size)).foregroundStyle(Pop.ink).offset(x: offset.0, y: offset.1)
            }
            Text(text).font(Pop.display(size)).foregroundStyle(.white)
        }
        .fixedSize()
    }
}

/// A rounded bar filled to `fraction`, ink-outlined.
struct Gauge: View {
    let fraction: Double
    let fill: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Pop.well)
                Rectangle().fill(fill)
                    .frame(width: max(2, geometry.size.width * min(max(fraction, 0), 1)))
                    .overlay(alignment: .trailing) { Rectangle().fill(Pop.ink).frame(width: 2) }
            }
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Pop.ink, lineWidth: 2))
        }
        .frame(height: height)
    }
}
