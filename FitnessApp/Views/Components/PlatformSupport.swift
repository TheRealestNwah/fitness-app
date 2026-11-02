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
    /// The Delete key (Edit › Delete) on Mac; nothing elsewhere, where swipes and menus cover it.
    @ViewBuilder
    func deleteCommand(perform action: (() -> Void)?) -> some View {
        #if os(macOS)
        onDeleteCommand(perform: action)
        #else
        self
        #endif
    }

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
        .menuStyle(.borderlessButton)
        .macTextSize()
        #else
        self
        #endif
    }

    /// The Mac text size setting (Settings › Profile); nothing on iOS, where the system setting applies.
    @ViewBuilder
    func macTextSize() -> some View {
        #if os(macOS)
        modifier(MacTextSizeModifier())
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

    /// Picks the keyboard for a text field. Number pads have no return key, so they get a Done
    /// button above them; pass `doneButton: false` when the screen provides its own.
    @ViewBuilder
    func strideKeyboard(_ keyboard: StrideKeyboard, doneButton: Bool = true) -> some View {
        #if os(iOS)
        if keyboard == .URL {
            keyboardType(.URL)
        } else if doneButton {
            keyboardType(keyboard == .decimalPad ? .decimalPad : .numberPad)
                .modifier(NumberPadDoneButton())
        } else {
            keyboardType(keyboard == .decimalPad ? .decimalPad : .numberPad)
        }
        #else
        self
        #endif
    }

    /// Puts the keyboard away when the person taps anywhere that isn't a text field or a control.
    /// Nothing changes on the Mac, where the keyboard is physical.
    @ViewBuilder
    func dismissKeyboardOnTap() -> some View {
        #if os(iOS)
        background(KeyboardDismissingTap())
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
            .menuStyle(.borderlessButton)
        #else
        self
        #endif
    }

    func strideSheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        sheet(isPresented: isPresented) { content().platformSheetSize().scrollDismissesKeyboard(.interactively) }
    }

    func strideSheet<Item: Identifiable, Content: View>(item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        sheet(item: item) { content($0).platformSheetSize().scrollDismissesKeyboard(.interactively) }
    }
}

#if os(iOS)
/// A Done button above the keyboard while this field is being edited. Each field shows its own
/// only while focused, so a form with several number fields never stacks more than one.
private struct NumberPadDoneButton: ViewModifier {
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .toolbar {
                if focused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { focused = false }
                            .fontWeight(.semibold)
                    }
                }
            }
    }
}

/// Installs a tap recogniser on the window that ends editing. It recognises alongside every other
/// gesture and never cancels the touch, so buttons, pickers and scrolling keep working, and it
/// ignores taps on text fields and controls so tapping another field still moves focus there.
private struct KeyboardDismissingTap: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView { InstallerView() }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView, UIGestureRecognizerDelegate {
        private lazy var recognizer: UITapGestureRecognizer = {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.cancelsTouchesInView = false
            tap.delaysTouchesEnded = false
            tap.delegate = self
            return tap
        }()

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove(toWindow: newWindow)
            window?.removeGestureRecognizer(recognizer)
            newWindow?.addGestureRecognizer(recognizer)
        }

        @objc private func handleTap(_ sender: UITapGestureRecognizer) {
            sender.view?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView || current is UIControl { return false }
                view = current.superview
            }
            return true
        }
    }
}
#endif

extension Font {
    /// A text style at the Mac text size setting (Settings › Profile); the plain system style on iOS,
    /// where Dynamic Type applies. Font modifiers chain as usual: `.stride(.headline).weight(.semibold)`.
    static func stride(_ style: Font.TextStyle) -> Font {
        #if os(macOS)
        .system(size: MacTextSize.current.size(for: style), weight: style == .headline ? .bold : .regular)
        #else
        .system(style)
        #endif
    }
}

#if os(macOS)
/// Sets the window's default font to the chosen size and rebuilds the window when it changes, since
/// `Font.stride` reads the setting when a view's body runs.
private struct MacTextSizeModifier: ViewModifier {
    @AppStorage(MacTextSize.storageKey) private var textSizeRaw = MacTextSize.default.rawValue

    func body(content: Content) -> some View {
        content
            .font(.stride(.body))
            .id(textSizeRaw)
    }
}
#endif
