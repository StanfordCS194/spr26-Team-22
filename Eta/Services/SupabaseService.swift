import Foundation

// MARK: - Supabase setup
//
// Required tables (run in Supabase SQL editor).
//
// friend_nudges table (for 6.3 friend-suggested reminders):
//
// CREATE TABLE friend_nudges (
//   id            TEXT PRIMARY KEY,
//   from_device   TEXT NOT NULL,
//   from_name     TEXT NOT NULL,
//   to_identifier TEXT NOT NULL,   -- matches devices.identifier on receiver's side
//   created_at    TIMESTAMPTZ DEFAULT now()
// );
// ALTER TABLE friend_nudges ENABLE ROW LEVEL SECURITY;
// CREATE POLICY "allow all" ON friend_nudges FOR ALL USING (true) WITH CHECK (true);
//
// Original tables:
//
// CREATE TABLE devices (
//   device_id   TEXT PRIMARY KEY,
//   identifier  TEXT UNIQUE NOT NULL,   -- normalized phone (e.g. "16505551234") or email
//   updated_at  TIMESTAMPTZ DEFAULT now()
// );
//
// CREATE TABLE invitations (
//   id              TEXT PRIMARY KEY,
//   from_device     TEXT NOT NULL,
//   from_identifier TEXT NOT NULL,      -- sender's normalized phone or email
//   to_identifier   TEXT NOT NULL,      -- matches devices.identifier on receiver's side
//   friend_name     TEXT NOT NULL,
//   activity        TEXT NOT NULL,
//   start_time      TIMESTAMPTZ NOT NULL,
//   end_time        TIMESTAMPTZ NOT NULL,
//   status          TEXT NOT NULL DEFAULT 'pending',
//   created_at      TIMESTAMPTZ DEFAULT now()
// );
//
// Enable Row Level Security and add permissive policies for both tables:
//
//   ALTER TABLE devices    ENABLE ROW LEVEL SECURITY;
//   ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;
//   CREATE POLICY "allow all" ON devices    FOR ALL USING (true) WITH CHECK (true);
//   CREATE POLICY "allow all" ON invitations FOR ALL USING (true) WITH CHECK (true);

final class SupabaseService {
    private let baseURL: String
    private let anonKey: String
    let deviceID: String

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let raw = try dec.singleValueContainer().decode(String.self)
            // Supabase returns ISO8601 with timezone offset (e.g. "2026-05-13T12:00:00+00:00")
            let formatters: [ISO8601DateFormatter] = [
                { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }(),
                { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }()
            ]
            for f in formatters {
                if let date = f.date(from: raw) { return date }
            }
            throw DecodingError.dataCorruptedError(
                in: try dec.singleValueContainer(),
                debugDescription: "Unrecognized date: \(raw)"
            )
        }
        return d
    }()

    init() {
        let host = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String) ?? ""
        self.baseURL = host.isEmpty ? "" : "https://\(host)"
        self.anonKey = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String) ?? ""

        // Use the App Group suite so the device ID matches what the iMessage extension writes.
        // App Groups must be enabled on both targets (group.me.Eta) in Signing & Capabilities.
        let sharedDefaults = UserDefaults(suiteName: "group.me.Eta") ?? .standard
        if let saved = sharedDefaults.string(forKey: "supabaseDeviceID") {
            self.deviceID = saved
        } else if let migrated = UserDefaults.standard.string(forKey: "supabaseDeviceID") {
            sharedDefaults.set(migrated, forKey: "supabaseDeviceID")
            self.deviceID = migrated
        } else {
            let id = UUID().uuidString
            sharedDefaults.set(id, forKey: "supabaseDeviceID")
            UserDefaults.standard.set(id, forKey: "supabaseDeviceID")
            self.deviceID = id
        }
        print("[Supabase] configured=\(isConfigured) baseURL=\(baseURL.prefix(30)) deviceID=\(deviceID.prefix(8))")
    }

    var isConfigured: Bool { !baseURL.isEmpty && !anonKey.isEmpty }

    // MARK: - Device registration

    func registerDevice(identifier: String) async {
        guard isConfigured else { return }
        let body: [String: Any] = ["device_id": deviceID, "identifier": identifier, "updated_at": iso(Date())]
        try? await request(path: "/rest/v1/devices?on_conflict=identifier", method: "POST", body: body, upsert: true)
    }

    /// Returns the device_id UUID for a given identifier (phone or email), or nil if not registered.
    func lookupDeviceID(for identifier: String) async -> String? {
        guard isConfigured else { return nil }
        let encoded = urlEncoded(identifier)
        guard let data = try? await request(path: "/rest/v1/devices?identifier=eq.\(encoded)&select=device_id", method: "GET"),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let deviceID = rows.first?["device_id"] as? String else { return nil }
        return deviceID
    }

    // MARK: - Invitations

    func postInvitation(_ inv: RemoteInvitation) async throws {
        let body: [String: Any] = [
            "id": inv.id,
            "from_device": inv.fromDevice,
            "from_identifier": inv.fromIdentifier,
            "to_identifier": inv.toIdentifier,
            "friend_name": inv.friendName,
            "activity": inv.activity,
            "start_time": iso(inv.startTime),
            "end_time": iso(inv.endTime),
            "status": "pending"
        ]
        try await request(path: "/rest/v1/invitations", method: "POST", body: body)
    }

    /// Returns invitations sent to this device that are still pending.
    func fetchPendingReceived() async throws -> [RemoteInvitation] {
        print("[Supabase] polling with deviceID=\(deviceID)")
        let path = "/rest/v1/invitations?to_identifier=eq.\(deviceID)&status=eq.pending&from_device=neq.\(deviceID)&select=*"
        let data = try await request(path: path, method: "GET")
        return (try? Self.decoder.decode([RemoteInvitation].self, from: data)) ?? []
    }

    /// Returns invitations sent from this device that now have a non-pending status.
    func fetchSentUpdates() async throws -> [RemoteInvitation] {
        let path = "/rest/v1/invitations?from_device=eq.\(deviceID)&status=neq.pending&select=*"
        let data = try await request(path: path, method: "GET")
        return (try? Self.decoder.decode([RemoteInvitation].self, from: data)) ?? []
    }

    func respondToInvitation(id: String, accepted: Bool) async throws {
        let body: [String: Any] = ["status": accepted ? "confirmed" : "declined"]
        try await request(path: "/rest/v1/invitations?id=eq.\(id)", method: "PATCH", body: body)
    }

    func deleteInvitation(id: String) async {
        try? await request(path: "/rest/v1/invitations?id=eq.\(id)", method: "DELETE")
    }

    // MARK: - Friend nudges

    /// Sends a nudge from the current user to a contact identified by phone/email.
    func sendFriendNudge(to toIdentifier: String, fromName: String) async {
        guard isConfigured else { return }
        let body: [String: Any] = [
            "id": UUID().uuidString,
            "from_device": deviceID,
            "from_name": fromName,
            "to_identifier": toIdentifier
        ]
        try? await request(path: "/rest/v1/friend_nudges", method: "POST", body: body)
    }

    /// Fetches nudges sent to `myIdentifier`, deletes them from Supabase, and returns sender names.
    func fetchAndDeleteReceivedNudges(myIdentifier: String) async -> [String] {
        guard isConfigured else { return [] }
        let encoded = urlEncoded(myIdentifier)
        guard let data = try? await request(
            path: "/rest/v1/friend_nudges?to_identifier=eq.\(encoded)&select=id,from_name",
            method: "GET"
        ),
        let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }

        let names = rows.compactMap { $0["from_name"] as? String }
        for id in rows.compactMap({ $0["id"] as? String }) {
            try? await request(path: "/rest/v1/friend_nudges?id=eq.\(id)", method: "DELETE")
        }
        return names
    }

    /// Deletes sent invitations that are still pending but whose end_time has passed.
    func deleteExpiredSentInvitations() async {
        let now = iso(Date())
        let path = "/rest/v1/invitations?from_device=eq.\(deviceID)&status=eq.pending&end_time=lt.\(now)"
        try? await request(path: path, method: "DELETE")
    }

    // MARK: - Private helpers

    @discardableResult
    private func request(
        path: String,
        method: String,
        body: [String: Any]? = nil,
        upsert: Bool = false
    ) async throws -> Data {
        guard isConfigured, let url = URL(string: baseURL + path) else { return Data() }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if upsert { req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer") }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }

        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    private func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    private func urlEncoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}
