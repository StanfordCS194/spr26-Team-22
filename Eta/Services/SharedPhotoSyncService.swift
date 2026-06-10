import Foundation

/// Syncs activity photos with friends via Supabase.
///
/// On every app foreground:
/// - Uploads any local photos that haven't been shared yet
/// - Downloads photos uploaded by friends and stores them in ActivityPhotoRepository
///   so NudgeService can include them in nudge notifications automatically
///
/// Supabase table required (run in SQL editor):
///
/// CREATE TABLE shared_photos (
///   id           TEXT PRIMARY KEY,
///   uploader_id  TEXT NOT NULL,        -- devices.device_id of the uploader
///   activity     TEXT NOT NULL,        -- Activity.rawValue
///   image_data   TEXT NOT NULL,        -- base64-encoded JPEG
///   created_at   TIMESTAMPTZ DEFAULT now()
/// );
/// ALTER TABLE shared_photos ENABLE ROW LEVEL SECURITY;
/// CREATE POLICY "allow all" ON shared_photos FOR ALL USING (true) WITH CHECK (true);
final class SharedPhotoSyncService {
    private let supabaseService: SupabaseService
    private let photoRepository: ActivityPhotoRepository

    private static let lastDownloadKey = "me.Eta.sharedPhoto.lastDownload"
    private static let uploadedIDsKey  = "me.Eta.sharedPhoto.uploadedIDs"

    private var uploadedIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.uploadedIDsKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: Self.uploadedIDsKey) }
    }

    init(supabaseService: SupabaseService, photoRepository: ActivityPhotoRepository) {
        self.supabaseService = supabaseService
        self.photoRepository = photoRepository
    }

    func sync() async {
        guard supabaseService.isConfigured else { return }
        async let up: () = upload()
        async let down: () = download()
        _ = await (up, down)
    }

    // MARK: - Private

    /// Uploads local photos that haven't been shared yet (tracked by ID in UserDefaults).
    private func upload() async {
        let recent = photoRepository.recentPhotos(withinDays: 30)
        var ids = uploadedIDs
        for photo in recent where !ids.contains(photo.id.uuidString) {
            await supabaseService.uploadSharedPhoto(
                activity: photo.activityRawValue,
                imageData: photo.imageData
            )
            ids.insert(photo.id.uuidString)
        }
        uploadedIDs = ids
    }

    /// Downloads photos uploaded by other devices since the last sync and stores them locally.
    private func download() async {
        let since = UserDefaults.standard.object(forKey: Self.lastDownloadKey) as? Date ?? .distantPast
        let rows = await supabaseService.fetchNewSharedPhotos(since: since)
        for row in rows {
            guard let activity = Activity(rawValue: row.activity) else { continue }
            let photo = ActivityPhoto(activity: activity, imageData: row.imageData)
            try? photoRepository.add(photo)
        }
        if !rows.isEmpty {
            UserDefaults.standard.set(Date(), forKey: Self.lastDownloadKey)
        }
    }
}
