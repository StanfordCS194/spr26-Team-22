import Foundation
import SwiftData

/// Seeds 12 mock friends, 4 goals, and 60 days of hangout history so the
/// home page renders meaningfully on first build. Only runs if the database
/// has no contacts yet.
final class MockDataSeeder {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func seedIfNeeded() {
        let existing = try? modelContext.fetch(FetchDescriptor<TrackedContact>())
        guard existing?.isEmpty != false else { return }
        seed()
    }

    private func seed() {
        let contacts = makeMockContacts()
        for contact in contacts { modelContext.insert(contact) }

        makeHangoutHistory(contacts: contacts)
        makeGoals(contacts: contacts)

        try? modelContext.save()
    }

    // MARK: - Contacts

    private func makeMockContacts() -> [TrackedContact] {
        let data: [(given: String, family: String, phone: String)] = [
            ("Maya",   "Chen",       "+16505551001"),
            ("Jordan", "Kim",        "+16505551002"),
            ("Sam",    "Patel",      "+16505551003"),
            ("Alex",   "Rivera",     "+16505551004"),
            ("Taylor", "Johnson",    "+16505551005"),
            ("Jamie",  "Williams",   "+16505551006"),
            ("Riley",  "Martinez",   "+16505551007"),
            ("Morgan", "Brown",      "+16505551008"),
            ("Casey",  "Davis",      "+16505551009"),
            ("Drew",   "Thompson",   "+16505551010"),
            ("Sage",   "Garcia",     "+16505551011"),
            ("Quinn",  "Anderson",   "+16505551012"),
        ]
        return data.map { entry in
            TrackedContact(
                cnContactIdentifier: UUID().uuidString,
                name: "\(entry.given) \(entry.family)",
                givenName: entry.given,
                familyName: entry.family,
                phoneNumber: entry.phone,
                emailAddress: "\(entry.given.lowercased()).\(entry.family.lowercased())@example.com"
            )
        }
    }

    // MARK: - Hangout history

    private func makeHangoutHistory(contacts: [TrackedContact]) {
        // (contactIndex, daysAgo): confirmed past hangouts
        let schedule: [(Int, Int)] = [
            (0, 7), (0, 14), (0, 28), (0, 42),  // Maya — frequent
            (1, 35), (1, 63),                     // Jordan — drifting
            (2, 30), (2, 58),                     // Sam — moderate
            (3, 62),                              // Alex — very overdue
            (4, 3),  (4, 18),                    // Taylor — recent
            (5, 10),                              // Jamie — recently seen
            (6, 44), (6, 59),                    // Riley — drifting
            (7, 1),  (7, 15),                    // Morgan — very recent
            (8, 27),                             // Casey
            // Drew (9): no history — weak tie
            (10, 21), (10, 45),                  // Sage
            (11, 55),                            // Quinn — long gap
        ]

        let activities = Activity.allCases
        for (contactIndex, daysAgo) in schedule {
            guard contactIndex < contacts.count else { continue }
            let contact = contacts[contactIndex]
            let startDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
            let endDate = startDate.addingTimeInterval(3600)
            let activity = activities[daysAgo % activities.count]
            let hangout = ScheduledHangout(
                contact: contact,
                activity: activity.rawValue,
                selectedTime: DateInterval(start: startDate, end: endDate),
                scheduledAt: startDate.addingTimeInterval(-86400)
            )
            hangout.inviteeResponse = .confirmed
            modelContext.insert(hangout)
        }
    }

    // MARK: - Goals

    private func makeGoals(contacts: [TrackedContact]) {
        guard contacts.count >= 4 else { return }

        let cal = Calendar.current
        let now = Date()

        // Monthly window
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) ?? now

        // Weekly window
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let weekEnd = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? now

        // Quarterly window
        let month = cal.component(.month, from: now)
        let qStartMonth = ((month - 1) / 3) * 3 + 1
        var qComps = cal.dateComponents([.year], from: now)
        qComps.month = qStartMonth; qComps.day = 1
        let quarterStart = cal.date(from: qComps) ?? now
        let quarterEnd = cal.date(byAdding: .month, value: 3, to: quarterStart) ?? now

        let goals: [Goal] = [
            Goal(
                title: "See Maya twice a month",
                friendIDs: [contacts[0].id],
                cadence: .monthly,
                target: 2,
                windowStart: monthStart,
                windowEnd: monthEnd,
                progress: 1,
                status: .atRisk,
                source: .manual
            ),
            Goal(
                title: "Weekly walks with Jordan",
                friendIDs: [contacts[1].id],
                cadence: .weekly,
                target: 1,
                windowStart: weekStart,
                windowEnd: weekEnd,
                progress: 1,
                status: .onTrack,
                source: .manual
            ),
            Goal(
                title: "Monthly coffee with Alex",
                friendIDs: [contacts[3].id],
                cadence: .monthly,
                target: 1,
                windowStart: monthStart,
                windowEnd: monthEnd,
                progress: 0,
                status: .behind,
                source: .aiAccepted
            ),
            Goal(
                title: "Quarterly catch-up with Sam",
                friendIDs: [contacts[2].id],
                cadence: .quarterly,
                target: 1,
                windowStart: quarterStart,
                windowEnd: quarterEnd,
                progress: 1,
                status: .achieved,
                source: .manual
            ),
        ]

        for goal in goals { modelContext.insert(goal) }
    }
}
