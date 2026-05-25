import Foundation

@Observable final class ReceivedInviteState {
    private(set) var pendingInvite: RemoteInvitation?

    var isPresented: Bool { pendingInvite != nil }

    func trigger(invite: RemoteInvitation) {
        pendingInvite = invite
    }

    func clear() {
        pendingInvite = nil
    }
}
