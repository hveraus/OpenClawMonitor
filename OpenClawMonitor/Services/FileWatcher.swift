import Foundation

/// Watches a file for write events using DispatchSource and calls `onChange`
/// after a 0.5 s debounce to avoid thrashing on rapid saves.
final class FileWatcher {

    private var source: DispatchSourceFileSystemObject?
    private var debounceItem: DispatchWorkItem?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    deinit { stop() }

    // MARK: - Public

    func start(watching path: String) {
        stop()
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .global(qos: .utility)
        )
        src.setEventHandler { [weak self] in self?.scheduleReload() }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    func stop() {
        source?.cancel()
        source = nil
        debounceItem?.cancel()
        debounceItem = nil
    }

    // MARK: - Private

    private func scheduleReload() {
        debounceItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async { self?.onChange() }
        }
        debounceItem = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5, execute: item)
    }
}
