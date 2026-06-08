import Foundation

@Observable final class ReceivedInviteState {
    private(set) var pendingInvite: RemoteInvitation?
    private(set) var senderName: String = ""

    var isPresented: Bool { pendingInvite != nil }

    func trigger(invite: RemoteInvitation, senderName: String) {
        pendingInvite = invite
        self.senderName = senderName
    }

    func clear() {
        pendingInvite = nil
        senderName = ""
    }
}
