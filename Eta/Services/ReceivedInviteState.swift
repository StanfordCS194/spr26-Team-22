import Foundation

@Observable final class ReceivedInviteState {
    private(set) var pendingInvite: RemoteInvitation?
    private(set) var senderName: String = ""
    private(set) var isEdit: Bool = false

    var isPresented: Bool { pendingInvite != nil }

    func trigger(invite: RemoteInvitation, senderName: String, isEdit: Bool = false) {
        pendingInvite = invite
        self.senderName = senderName
        self.isEdit = isEdit
    }

    func clear() {
        pendingInvite = nil
        senderName = ""
        isEdit = false
    }
}
