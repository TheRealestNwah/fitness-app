import SwiftUI
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

extension Color {
    static var strideBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }

    static var strideCardBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    static var strideFill: Color {
        #if os(macOS)
        Color(nsColor: .quaternaryLabelColor)
        #else
        Color(uiColor: .tertiarySystemFill)
        #endif
    }
}

#if os(macOS)
extension NSImage {
    var cgImage: CGImage? { cgImage(forProposedRect: nil, context: nil, hints: nil) }
}

enum StrideSizeClass { case compact, regular }

private struct StrideSizeClassKey: EnvironmentKey {
    static let defaultValue: StrideSizeClass? = .regular
}

extension EnvironmentValues {
    var strideSizeClass: StrideSizeClass? {
        get { self[StrideSizeClassKey.self] }
        set { self[StrideSizeClassKey.self] = newValue }
    }
}
#else
extension EnvironmentValues {
    var strideSizeClass: UserInterfaceSizeClass? { horizontalSizeClass }
}
#endif

enum StrideKeyboard { case decimalPad, numberPad, URL }

extension SearchFieldPlacement {
    static var strideSearch: SearchFieldPlacement {
        #if os(macOS)
        .toolbar
        #else
        .navigationBarDrawer(displayMode: .always)
        #endif
    }
}

extension ToolbarItemPlacement {
    static var strideBottomBar: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .bottomBar
        #endif
    }
}

extension View {
    @ViewBuilder
    func diarySelectionMode(_ selecting: Binding<Bool>) -> some View {
        #if os(iOS)
        environment(\.editMode, Binding(get: { selecting.wrappedValue ? .active : .inactive },
                                       set: { selecting.wrappedValue = $0.isEditing }))
        #else
        self
        #endif
    }

    @ViewBuilder
    func platformWindow() -> some View {
        #if os(macOS)
        GeometryReader { geometry in
            self.environment(\.strideSizeClass, geometry.size.width >= 1000 ? .regular : .compact)
        }
        .frame(minWidth: 760, minHeight: 560)
        .formStyle(.grouped)
        #else
        self
        #endif
    }

    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func strideKeyboard(_ keyboard: StrideKeyboard) -> some View {
        #if os(iOS)
        keyboardType(keyboard == .decimalPad ? .decimalPad : keyboard == .numberPad ? .numberPad : .URL)
        #else
        self
        #endif
    }

    @ViewBuilder
    func withoutAutocapitalization() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    @ViewBuilder
    func strideListStyle() -> some View {
        #if os(macOS)
        listStyle(.inset)
        #else
        listStyle(.insetGrouped)
        #endif
    }

    @ViewBuilder
    func strideHoverEffect() -> some View {
        #if os(iOS)
        hoverEffect(.highlight)
        #else
        self
        #endif
    }

    @ViewBuilder
    func cameraPresentation<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }

    @ViewBuilder
    func platformSheetSize() -> some View {
        #if os(macOS)
        frame(minWidth: 500, idealWidth: 580, minHeight: 440, idealHeight: 650)
            .formStyle(.grouped)
        #else
        self
        #endif
    }

    func strideSheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        sheet(isPresented: isPresented) { content().platformSheetSize() }
    }

    func strideSheet<Item: Identifiable, Content: View>(item: Binding<Item?>,
                                                      @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        sheet(item: item) { content($0).platformSheetSize() }
    }
}
