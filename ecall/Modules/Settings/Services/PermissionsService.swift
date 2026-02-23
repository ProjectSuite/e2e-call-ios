import Foundation
import AVFoundation
import UserNotifications
import Photos
import UIKit

final class PermissionsService {
    static let shared = PermissionsService()
    private let orderedTypes: [PermissionType] = [.microphone, .camera, .notifications, .photos]

    private init() { }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    func status(for type: PermissionType) async -> PermissionStatus {
        switch type {
        case .microphone:
            return microphoneStatus()
        case .camera:
            return cameraStatus()
        case .notifications:
            return await notificationStatus()
        case .photos:
            return photosStatus()
        }
    }

    func requestPermission(for type: PermissionType) async -> PermissionStatus {
        switch type {
        case .microphone:
            return await requestMicrophonePermission()
        case .camera:
            return await requestCameraPermission()
        case .notifications:
            return await requestNotificationPermission()
        case .photos:
            return await requestPhotosPermission()
        }
    }

    func fetchAllStatuses() async -> [PermissionItem] {
        await withTaskGroup(of: PermissionItem?.self) { group in
            for type in orderedTypes {
                group.addTask {
                    let status = await self.status(for: type)
                    return PermissionItem(type: type, status: status)
                }
            }

            var items: [PermissionItem] = []
            for await item in group {
                if let item {
                    items.append(item)
                }
            }
            let order = Dictionary(uniqueKeysWithValues: orderedTypes.enumerated().map { ($1, $0) })
            return items.sorted { (order[$0.type] ?? 0) < (order[$1.type] ?? 0) }
        }
    }

    private func microphoneStatus() -> PermissionStatus {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    private func cameraStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    private func notificationStatus() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let status: PermissionStatus
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    status = .granted
                case .denied:
                    status = .denied
                case .notDetermined:
                    status = .notDetermined
                @unknown default:
                    status = .notDetermined
                }
                continuation.resume(returning: status)
            }
        }
    }

    private func photosStatus() -> PermissionStatus {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    private func requestMicrophonePermission() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted ? .granted : .denied)
            }
        }
    }

    private func requestCameraPermission() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted ? .granted : .denied)
            }
        }
    }

    private func requestNotificationPermission() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted ? .granted : .denied)
            }
        }
    }

    private func requestPhotosPermission() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                switch status {
                case .authorized, .limited:
                    continuation.resume(returning: .granted)
                case .denied, .restricted:
                    continuation.resume(returning: .denied)
                case .notDetermined:
                    continuation.resume(returning: .notDetermined)
                @unknown default:
                    continuation.resume(returning: .notDetermined)
                }
            }
        }
    }

}
