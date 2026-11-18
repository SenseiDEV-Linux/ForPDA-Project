import BBPanelFeature
import ComposableArchitecture
@testable import CreateChatFeature
import Foundation
import QMSClient
@testable import QMSFeature
import TCAExtensions
import Testing
import UploadBoxFeature

@MainActor
struct QMSComposerTests {
    @Test func sizeButtonChangesTheChatDraft() async {
        let store = TestStore(initialState: QMSFeature.State(chatId: 42)) { QMSFeature() }
        await store.send(.bbPanel(.view(.fontSizeButtonTapped(5))))
        await store.receive(\.bbPanel.delegate) {
            $0.draft = BBCodeDraft(text: "[SIZE=5][/SIZE]", selection: NSRange(location: 8, length: 0))
            $0.focusedChatId = 42
        }
    }

    @Test func quoteButtonFormatsTheFirstMessageNotTheChatTitle() async {
        var state = CreateChatFeature.State()
        state.chatTitle = "Тема"
        state.draft = BBCodeDraft(text: "Привет", selection: NSRange(location: 0, length: 6))
        let store = TestStore(initialState: state) { CreateChatFeature() }
        await store.send(.bbPanel(.view(.tagButtonTapped(.quote))))
        await store.receive(\.bbPanel.delegate) {
            $0.draft = BBCodeDraft(text: "[QUOTE]Привет[/QUOTE]", selection: NSRange(location: 7, length: 6))
            $0.focus = .message
        }
    }

    @Test func failedSendPreservesFormattedTextSelectionAndAttachment() async {
        struct Offline: Error {}
        let draft = BBCodeDraft(text: "[B]Да[/B]", selection: NSRange(location: 3, length: 2))
        var state = QMSFeature.State(chatId: 42)
        state.draft = draft
        state.upload.files = [UploadBoxFile(name: "note.pdf", type: .file, serverId: 123)]
        let store = TestStore(initialState: state) { QMSFeature() } withDependencies: {
            var client = QMSClient()
            client.sendMessage = { chatId, text, ids in
                #expect(chatId == 42)
                #expect(text == draft.text)
                #expect(ids == [123])
                throw Offline()
            }
            $0.qmsClient = client
        }
        await store.send(.view(.sendMessageButtonTapped)) { $0.isSending = true }
        await store.receive(\.internal) {
            $0.isSending = false
            $0.alert = .somethingWentWrong
        }
        #expect(store.state.draft == draft)
        #expect(store.state.uploadedAttachmentIDs == [123])
    }

    @Test func successClearsDraftAndOnlyTheFilesThatWereSent() {
        var state = QMSFeature.State(chatId: 42)
        state.draft = BBCodeDraft(text: "[QUOTE]Да[/QUOTE]", selection: NSRange(location: 7, length: 2))
        state.isSending = true
        let notSent = UploadBoxFile(name: "later.pdf", type: .file, uploadingError: .uploadFailure)
        state.upload.files = [UploadBoxFile(name: "now.pdf", type: .file, serverId: 123), notSent]
        // Test the state transition, without starting its follow-up network refresh.
        _ = QMSFeature().reduce(into: &state, action: .internal(.messageSent([123])))
        #expect(state.draft == BBCodeDraft())
        #expect(!state.isSending)
        #expect(state.upload.files == [notSent])
    }

    @Test func attachmentOnlySendAndUploadGuard() {
        var state = QMSFeature.State(chatId: 42)
        #expect(!state.canSendMessage)
        state.upload.files = [UploadBoxFile(name: "note.pdf", type: .file, serverId: 123)]
        #expect(state.canSendMessage)
        state.upload.isAnyFileUploading = true
        #expect(!state.canSendMessage)
        state.upload.isAnyFileUploading = false
        state.isSending = true
        #expect(!state.canSendMessage)
    }
}
