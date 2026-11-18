//
//  ForField.swift
//  ForPDA
//
//  Created by Xialtal on 25.11.25.
//

import SwiftUI

public struct Field<T: Hashable, BBPanel: View>: View {
    
    // MARK: - Properties
    
    @Environment(\.tintColor) private var tintColor
    @FocusState.Binding var focus: T?
    
    var content: Binding<String>
    let placeholder: LocalizedStringResource
    let focusEqual: T
    let characterLimit: Int?
    let minHeight: CGFloat?
    let maxTextHeight: CGFloat?
    var selection: Binding<NSRange?>
    let bbPanel: () -> BBPanel
    
    // MARK: - Init
    
    public init(
        content: Binding<String>,
        placeholder: LocalizedStringResource,
        focusEqual: T,
        focus: FocusState<T?>.Binding,
        characterLimit: Int? = nil,
        minHeight: CGFloat? = nil,
        maxTextHeight: CGFloat? = nil,
        selection: Binding<NSRange?> = .constant(nil),
        @ViewBuilder bbPanel: @escaping () -> BBPanel = { EmptyView() }
    ) {
        self.content = content
        self.placeholder = placeholder
        self.focusEqual = focusEqual
        self.characterLimit = characterLimit
        self.minHeight = minHeight
        self.maxTextHeight = maxTextHeight
        self.selection = selection
        self.bbPanel = bbPanel
        
        self._focus = focus
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack {
            SelectableTextView(
                content: content,
                selection: selection,
                placeholder: placeholder,
                characterLimit: characterLimit,
                maxTextHeight: maxTextHeight
            )
            
            if BBPanel.self != EmptyView.self {
                Spacer()
            }
            
            bbPanel()
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 12)
        .focused($focus, equals: focusEqual)
        .foregroundStyle(Color(.Labels.primary))
        .frame(minHeight: minHeight, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: isLiquidGlass ? 28 : 14)
                .fill(Color(.Background.teritary))
        }
        .overlay {
            RoundedRectangle(cornerRadius: isLiquidGlass ? 28 : 14)
                .stroke($focus.wrappedValue == focusEqual ? tintColor : Color(.Separator.primary), lineWidth: 1)
        }
        .onTapGesture {
            focus = focusEqual
        }
    }
}

// MARK: - Single Line Field

public struct SingleLineField<F: Hashable>: View {
    
    // MARK: - Properties
    
    @FocusState.Binding var focus: F?
    
    var content: Binding<String>
    let placeholder: LocalizedStringResource
    let focusEqual: F
    let keyboardType: UIKeyboardType
    let characterLimit: Int?
    
    // MARK: - Init
    
    public init(
        content: Binding<String>,
        placeholder: LocalizedStringResource,
        focusEqual: F,
        focus: FocusState<F?>.Binding,
        keyboardType: UIKeyboardType,
        characterLimit: Int?
    ) {
        self.content = content
        self.placeholder = placeholder
        self.focusEqual = focusEqual
        self.keyboardType = keyboardType
        self.characterLimit = characterLimit
        
        self._focus = focus
    }
    
    // MARK: - Body
    
    public var body: some View {
        FieldContainer(focus: $focus, focusEqual: focusEqual) {
            TextField(text: content, axis: .horizontal) {
                Text(placeholder)
                    .font(.body)
                    .foregroundStyle(Color(.Labels.quaternary))
            }
            .onChange(of: content.wrappedValue) { newValue in
                if let limit = characterLimit, newValue.count > limit {
                    content.wrappedValue = String(newValue.prefix(limit))
                }
            }
            .keyboardType(keyboardType)
            .frame(minHeight: nil, alignment: .top)
        }
    }
}

// MARK: - Field Container

public struct FieldContainer<F: Hashable, Content: View>: View {
    
    @Environment(\.tintColor) private var tintColor
    @FocusState.Binding public var focus: F?
    
    let focusEqual: F
    let content: () -> Content
    
    public init(
        focus: FocusState<F?>.Binding,
        focusEqual: F,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.focusEqual = focusEqual
        self.content = content
        
        self._focus = focus
    }
    
    public var body: some View {
        VStack {
            content()
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 12)
        .focused($focus, equals: focusEqual)
        .foregroundStyle(Color(.Labels.primary))
        .background {
            RoundedRectangle(cornerRadius: isLiquidGlass ? 28 : 14)
                .fill(Color(.Background.teritary))
        }
        .overlay {
            RoundedRectangle(cornerRadius: isLiquidGlass ? 28 : 14)
                .stroke($focus.wrappedValue == focusEqual ? tintColor : Color(.Separator.primary), lineWidth: 1)
        }
        .onTapGesture {
            focus = focusEqual
        }
    }
}

// MARK: - Selectable Text View

private struct SelectableTextView: UIViewRepresentable {
    @Binding var content: String
    @Binding var selection: NSRange?
    let placeholder: LocalizedStringResource
    let characterLimit: Int?
    let maxTextHeight: CGFloat?
    
    static let placeholderColor = UIColor.lightGray
    
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.text = content.isEmpty ? String(localized: placeholder) : content
        view.textColor = content.isEmpty ? Self.placeholderColor : UIColor.label
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textContainer.lineFragmentPadding = 0
        view.textContainerInset = .zero
        view.isScrollEnabled = maxTextHeight != nil
        
        view.font = UIFont.preferredFont(forTextStyle: .body)
        
        return view
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.content = $content
        context.coordinator.selection = $selection
        context.coordinator.isUpdating = true
        defer {
            context.coordinator.lastContent = content
            context.coordinator.isUpdating = false
        }

        if uiView.isEditable != context.environment.isEnabled {
            uiView.isEditable = context.environment.isEnabled
        }
        let previousText = uiView.text ?? ""
        let wasShowingPlaceholder = uiView.textColor == Self.placeholderColor

        if content.isEmpty {
            if uiView.isFirstResponder {
                let shouldClearMarkedText = !context.coordinator.lastContent.isEmpty
                if uiView.markedTextRange == nil || shouldClearMarkedText {
                    if uiView.markedTextRange != nil {
                        uiView.unmarkText()
                    }
                    if !(uiView.text ?? "").isEmpty {
                        uiView.text = ""
                    }
                }
                uiView.textColor = .label
            } else {
                let placeholderText = String(localized: placeholder)
                uiView.textColor = Self.placeholderColor

                if !wasShowingPlaceholder || previousText != placeholderText {
                    uiView.text = placeholderText
                }
            }
        } else {
            uiView.textColor = .label

            if uiView.markedTextRange == nil, wasShowingPlaceholder || previousText != content {
                uiView.text = content
            }
        }

        if (uiView.text ?? "") != previousText {
            uiView.invalidateIntrinsicContentSize()
        }

        // when range (selection binding) has been changed in external place
        if uiView.textColor != Self.placeholderColor,
           uiView.markedTextRange == nil,
           let externalSelection = selection,
           externalSelection.location != NSNotFound {
            let textLength = (uiView.text ?? "").utf16.count
            let location = min(max(0, externalSelection.location), textLength)
            let length = min(max(0, externalSelection.length), textLength - location)
            let clampedSelection = NSRange(location: location, length: length)
            if uiView.selectedRange != clampedSelection {
                uiView.selectedRange = clampedSelection
            }
        }
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let size = uiView.sizeThatFits(
            CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: min(ceil(size.height), maxTextHeight ?? .greatestFiniteMagnitude))
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(
            content: $content,
            selection: $selection,
            characterLimit: characterLimit,
            placeholder: placeholder
        )
    }
    
    final class Coordinator: NSObject, UITextViewDelegate {
        var content: Binding<String>
        var selection: Binding<NSRange?>
        let characterLimit: Int?
        let placeholder: LocalizedStringResource
        var isUpdating = false
        var lastContent: String
        
        init(
            content: Binding<String>,
            selection: Binding<NSRange?>,
            characterLimit: Int?,
            placeholder: LocalizedStringResource
        ) {
            self.content = content
            self.selection = selection
            self.characterLimit = characterLimit
            self.placeholder = placeholder
            self.lastContent = content.wrappedValue
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText: String) -> Bool {
            if let characterLimit = characterLimit {
                return textView.text.count + replacementText.count <= characterLimit
            }
            return true
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdating, textView.isFirstResponder,
                  textView.textColor != placeholderColor,
                  textView.selectedRange.location != NSNotFound
            else { return }
            if selection.wrappedValue != textView.selectedRange {
                selection.wrappedValue = textView.selectedRange
            }
        }
        
        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdating else { return }
            let updatedText = textView.textColor == placeholderColor ? "" : (textView.text ?? "")
            lastContent = updatedText
            if content.wrappedValue != updatedText {
                content.wrappedValue = updatedText
            }
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == placeholderColor {
                isUpdating = true
                textView.text = nil
                textView.textColor = UIColor.label
                isUpdating = false
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                isUpdating = true
                textView.textColor = placeholderColor
                textView.text = String(localized: placeholder)
                isUpdating = false
            }
        }
    }
}
