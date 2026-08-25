import Foundation
import PartoutRuntime

public actor VPNProfileStore {
    private var profiles: [Profile] = []
    private var continuations: [UUID: AsyncStream<ProfilesEvent>.Continuation] = [:]

    public init() {}

    public func stream() -> AsyncStream<ProfilesEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            continuation.yield(.snapshot(profiles))
            continuations[id] = continuation
            continuation.onTermination = { _ in
                Task { await self.removeContinuation(id) }
            }
        }
    }

    public func upsert(_ profile: Profile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        emit(.changes([.upsert(profile)]))
    }

    public func remove(_ profileId: Profile.ID) {
        profiles.removeAll { $0.id == profileId }
        emit(.changes([.remove(profileId)]))
    }

    public func current() -> [Profile] {
        profiles
    }

    /// Replace in-memory list and emit snapshot so NETunnelStrategy reloads iOS managers before save.
    public func seedSnapshot(_ profiles: [Profile]) {
        self.profiles = profiles
        emit(.snapshot(profiles))
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    private func emit(_ event: ProfilesEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }
}
