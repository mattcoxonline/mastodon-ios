//
//  ComposeContentToolbarView.swift
//
//
//  Created by MainasuK on 22/10/18.
//

import SwiftUI
import UIKit
import MastodonAsset
import MastodonLocalization
import MastodonSDK

protocol ComposeContentToolbarViewDelegate: AnyObject {
    func composeContentToolbarView(_ viewModel: ComposeContentToolbarView.ViewModel, toolbarItemDidPressed action: ComposeContentToolbarView.ViewModel.Action)
    func composeContentToolbarView(_ viewModel: ComposeContentToolbarView.ViewModel, attachmentMenuDidPressed action: ComposeContentToolbarView.ViewModel.AttachmentAction)
}

struct ComposeContentToolbarView: View {

    static var toolbarHeight: CGFloat { 64 }

    @ObservedObject var viewModel: ViewModel

    @State private var showingLanguagePicker = false
    @State private var didChangeLanguage = false

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    // Renders the compose actions as a standard bottom-bar toolbar, which iOS 26
    // presents as a Liquid Glass capsule (replacing the former custom grey bar).
    // The navigation bar of the enclosing stack is unused: it exists only as the
    // toolbar container, so the bar is hidden.
    var body: some View {
        NavigationStack {
            Color.clear
                .toolbar(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        ForEach(ComposeContentToolbarView.ViewModel.Action.allCases.filter { $0 != .visibility }, id: \.self) { action in
                            toolbarControl(for: action)
                        }
                    }
                    if #available(iOS 26.0, *) {
                        ToolbarSpacer(.flexible, placement: .bottomBar)
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        characterCounter
                    }
                }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.Scene.Compose.Accessibility.postOptions)
    }

    @ViewBuilder private func toolbarControl(for action: ComposeContentToolbarView.ViewModel.Action) -> some View {
        switch action {
        case .attachment:
            Menu {
                ForEach(ComposeContentToolbarView.ViewModel.AttachmentAction.allCases, id: \.self) { attachmentAction in
                    Button {
                        viewModel.delegate?.composeContentToolbarView(viewModel, attachmentMenuDidPressed: attachmentAction)
                    } label: {
                        Label {
                            Text(attachmentAction.title)
                        } icon: {
                            Image(uiImage: attachmentAction.image)
                        }
                    }
                }
            } label: {
                label(for: action)
            }
            .disabled(!viewModel.isAttachmentButtonEnabled)
        case .poll:
            Button {
                viewModel.delegate?.composeContentToolbarView(viewModel, toolbarItemDidPressed: action)
            } label: {
                label(for: action)
            }
            .disabled(!viewModel.isPollButtonEnabled)
        case .language:
            Menu {
                Section {} // workaround a bug where the “Suggested” section doesn’t appear
                if !viewModel.suggestedLanguages.isEmpty {
                    Section(L10n.Scene.Compose.Language.suggested) {
                        ForEach(viewModel.suggestedLanguages.compactMap(Language.init(id:))) { lang in
                            Toggle(isOn: languageBinding(for: lang.id)) {
                                Text(lang.label)
                            }
                        }
                    }
                }
                let recent = viewModel.recentLanguages.filter { !viewModel.suggestedLanguages.contains($0) }
                if !recent.isEmpty {
                    Section(L10n.Scene.Compose.Language.recent) {
                        ForEach(recent.compactMap(Language.init(id:))) { lang in
                            Toggle(isOn: languageBinding(for: lang.id)) {
                                Text(lang.label)
                            }
                        }
                    }
                }
                if !(recent + viewModel.suggestedLanguages).contains(viewModel.language) {
                    Toggle(isOn: languageBinding(for: viewModel.language)) {
                        Text(Language(id: viewModel.language)?.label ?? AttributedString("\(viewModel.language)"))
                    }
                }
                Button(L10n.Scene.Compose.Language.other) {
                    showingLanguagePicker = true
                }
            } label: {
                Image(systemName: "character.book.closed")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 24, height: 24)
                    .accessibilityLabel(L10n.Scene.Compose.Language.title)
                    .accessibilityValue(Text(Language(id: viewModel.language)?.label ?? AttributedString("\(viewModel.language)")))
                    .overlay(alignment: .topTrailing) {
                        Group {
                            if let suggested = viewModel.highConfidenceSuggestedLanguage,
                               suggested != viewModel.language,
                               !didChangeLanguage {
                                Circle().fill(.blue)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .transition(.opacity)
                        .animation(.default, value: [viewModel.highConfidenceSuggestedLanguage, viewModel.language])
                    }
            }
            .popover(isPresented: $showingLanguagePicker) {
                let picker = LanguagePickerNavigationView(selectedLanguage: viewModel.language) { newLanguage in
                    viewModel.language = newLanguage
                    didChangeLanguage = true
                    showingLanguagePicker = false
                }
                if verticalSizeClass == .regular && horizontalSizeClass == .regular {
                    // explicitly size picker when it’s a popover
                    picker.frame(width: 400, height: 500)
                } else {
                    picker
                }
            }
        default:
            Button {
                viewModel.delegate?.composeContentToolbarView(viewModel, toolbarItemDidPressed: action)
            } label: {
                label(for: action)
            }
        }
    }

    private var characterCounter: some View {
        let count: Int = {
            if viewModel.isContentWarningActive {
                return viewModel.contentWeightedLength + viewModel.contentWarningWeightedLength
            } else {
                return viewModel.contentWeightedLength
            }
        }()
        let remains = viewModel.maxTextInputLimit - count
        let isOverflow = remains < 0
        return Text("\(remains)")
            .foregroundColor(Color(isOverflow ? UIColor.systemRed : UIColor.secondaryLabel))
            .font(.system(size: isOverflow ? 18 : 16, weight: isOverflow ? .medium : .regular))
            .accessibilityLabel(L10n.A11y.Plural.Count.charactersLeft(remains))
    }

    func label(for image: UIImage) -> some View {
        Image(uiImage: image)
            .foregroundColor(Color(Asset.Scene.Compose.buttonTint.color))
            .frame(width: 24, height: 24, alignment: .center)
    }

    private func languageBinding(for code: String) -> Binding<Bool> {
        Binding {
            code == viewModel.language
        } set: { newValue in
            if newValue {
                viewModel.language = code
            }
            didChangeLanguage = true
        }
    }
}

extension ComposeContentToolbarView {
    func label(for action: ComposeContentToolbarView.ViewModel.Action) -> some View {
        Image(uiImage: viewModel.image(for: action))
            .foregroundColor(Color(Asset.Scene.Compose.buttonTint.color))
            .frame(width: 24, height: 24, alignment: .center)
            .accessibilityLabel(viewModel.label(for: action))
    }
}

extension Mastodon.Entity.Status.Visibility {
}
