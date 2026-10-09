import Foundation
import AppKit

/// Tells the account to refresh every `interval`, and at once after the Mac wakes
/// (TARGET_ARCHITECTURE §2). Reads the clock so the domain doesn't have to.
@MainActor
public final class Refresher {
    let account: Account
    let clock: @MainActor () -> Date
    private var loop: Task<Void, Never>?
    private var wake: NSObjectProtocol?

    public init(account: Account, clock: @escaping @MainActor () -> Date = { .now }) {
        self.account = account
        self.clock = clock
    }

    public func start() {
        loop = Task { [weak self] in
            guard let self else { return }
            await account.start(at: clock())
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(account.interval))
                await account.refresh(at: clock())
            }
        }
        wake = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await self.account.refresh(at: self.clock())
            }
        }
    }
}
