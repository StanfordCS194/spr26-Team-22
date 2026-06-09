import Foundation

// MARK: - Supabase setup
//
// Required tables (run in Supabase SQL editor):
//
// CREATE TABLE devices (
//   device_id   TEXT PRIMARY KEY,
//   identifier  TEXT UNIQUE NOT NULL,   -- normalized phone (e.g. "16505551234") or email
//   updated_at  TIMESTAMPTZ DEFAULT now()
// );
//
// CREATE TABLE invitations (
//   id                    TEXT PRIMARY KEY,
//   from_device           TEXT NOT NULL,
//   from_identifier       TEXT NOT NULL,      -- sender's normalized phone or email
//   to_identifier         TEXT NOT NULL,      -- matches devices.identifier on receiver's side
//   friend_name           TEXT NOT NULL,
//   activity              TEXT NOT NULL,
//   start_time            TIMESTAMPTZ NOT NULL,
//   end_time              TIMESTAMPTZ NOT NULL,
//   status                TEXT NOT NULL DEFAULT 'pending',
//   previous_invitation_id TEXT,              -- set when editing an existing event
//   created_at            TIMESTAMPTZ DEFAULT now()
// );
//
// CREATE TABLE cancellations (
//   id              TEXT PRIMARY KEY,         -- invitation ID of the original invite
//   from_identifier TEXT NOT NULL,
//   to_identifier   TEXT NOT NULL,
//   friend_name     TEXT NOT NULL,
//   activity        TEXT NOT NULL,
//   created_at      TIMESTAMPTZ DEFAULT now()
// );
//
// Enable Row Level Security and add permissive policies for all tables:
//
//   ALTER TABLE devices       ENABLE ROW LEVEL SECURITY;
//   ALTER TABLE invitations   ENABLE ROW LEVEL SECURITY;
//   ALTER TABLE cancellations ENABLE ROW LEVEL SECURITY;
//   CREATE POLICY "allow all" ON devices       FOR ALL USING (true) WITH CHECK (true);
//   CREATE POLICY "allow all" ON invitations   FOR ALL USING (true) WITH CHECK (true);
//   CREATE POLICY "allow all" ON cancellations FOR ALL USING (true) WITH CHECK (true);

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

        if let saved = UserDefaults.standard.string(forKey: "supabaseDeviceID") {
            self.deviceID = saved
        } else {
            let id = UUID().uuidString
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
        var body: [String: Any] = [
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
        if let prev = inv.previousInvitationID { body["previous_invitation_id"] = prev }
        try await request(path: "/rest/v1/invitations", method: "POST", body: body)
    }

    // MARK: - Cancellations

    func postCancellation(_ c: RemoteCancellation) async throws {
        let body: [String: Any] = [
            "id": c.id,
            "from_identifier": c.fromIdentifier,
            "to_identifier": c.toIdentifier,
            "friend_name": c.friendName,
            "activity": c.activity
        ]
        try await request(path: "/rest/v1/cancellations", method: "POST", body: body)
    }

    func fetchCancellations() async throws -> [RemoteCancellation] {
        let encoded = urlEncoded(deviceID)
        let path = "/rest/v1/cancellations?to_identifier=eq.\(encoded)&select=*"
        let data = try await request(path: path, method: "GET")
        return (try? Self.decoder.decode([RemoteCancellation].self, from: data)) ?? []
    }

    func deleteCancellation(id: String) async {
        try? await request(path: "/rest/v1/cancellations?id=eq.\(id)", method: "DELETE")
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
