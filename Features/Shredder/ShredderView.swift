import SwiftUI
import AppKit

@MainActor
struct ShredderView: View {

    @State private var queue: [URL] = []
    @State private var passes: Int = 1
    @State private var phase: Phase = .idle
    @State private var progress: Double = 0
    @State private var currentFile: String?
    @State private var finishedMessage: String?
    @State private var lastError: String?

    enum Phase: Equatable { case idle, shredding, done }

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeader(
                icon: "scissors",
                title: "Shredder",
                subtitle: "Overwrite and delete — irreversible. SSDs use TRIM; effectiveness limited there."
            ) {
                Button {
                    pickFiles()
                } label: {
                    Label("Add Files…", systemImage: "plus")
                }
                .disabled(phase == .shredding)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    settings
                    queueSection
                    if phase != .idle {
                        progressCard
                    }
                    warningCard
                }
                .padding(Spacing.lg)
            }

            Divider()
            actionBar
        }
        .animation(.smooth(duration: 0.2), value: phase)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeading("Overwrite")
            HStack {
                Text("Passes")
                    .font(.callout)
                Stepper(value: $passes, in: 1...7) {
                    Text("\(passes)")
                        .font(.system(.body, design: .monospaced))
                        .frame(minWidth: 24)
                }
                Spacer()
                Text(passDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.md)
            .cardStyle()
        }
    }

    private var passDescription: String {
        switch passes {
        case 1: return "Single random pass — fastest"
        case 2...3: return "Multi-pass — recommended for HDDs"
        default: return "Paranoid — slow"
        }
    }

    @ViewBuilder
    private var queueSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeading("Queue", count: queue.count)
            if queue.isEmpty {
                Text("Drag files here or press Add Files…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(Spacing.lg)
                    .frame(maxWidth: .infinity)
                    .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(queue.enumerated()), id: \.offset) { (index, url) in
                        HStack {
                            Image(systemName: url.hasDirectoryPath ? "folder" : "doc")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(url.lastPathComponent).font(.system(size: 13))
                                Text(url.path)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                            Spacer()
                            Button {
                                queue.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(phase == .shredding)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, Spacing.md)
                        if index < queue.count - 1 { Divider() }
                    }
                }
                .cardStyle()
            }
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                if phase == .shredding {
                    Text("Shredding…").font(.callout.weight(.medium))
                } else if phase == .done {
                    Label(finishedMessage ?? "Finished", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(.callout, design: .monospaced))
            }
            ProgressView(value: progress)
            if let currentFile {
                Text(currentFile)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            if let lastError {
                Text(lastError).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(Spacing.md)
        .cardStyle()
    }

    private var warningCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Irreversible.").font(.callout.weight(.semibold))
                Text("Files in the queue will be overwritten with random bytes \(passes) time\(passes == 1 ? "" : "s") and then unlinked. There is no undo. On SSDs, TRIM may make multiple passes redundant — encrypt your disk with FileVault for stronger guarantees.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }

    private var actionBar: some View {
        HStack {
            Text(queue.isEmpty
                 ? "Add files to begin"
                 : "\(queue.count) file\(queue.count == 1 ? "" : "s") • \(passes) pass\(passes == 1 ? "" : "es")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Clear") { queue.removeAll() }
                .disabled(queue.isEmpty || phase == .shredding)
            Button(role: .destructive) {
                shred()
            } label: {
                Label("Shred Now", systemImage: "scissors")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(queue.isEmpty || phase == .shredding)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        if panel.runModal() == .OK {
            for url in panel.urls {
                if !queue.contains(url) { queue.append(url) }
            }
        }
    }

    private func shred() {
        guard !queue.isEmpty else { return }
        let toShred = queue
        let passCount = passes
        Task { @MainActor in
            phase = .shredding
            progress = 0
            currentFile = nil
            finishedMessage = nil
            lastError = nil

            var failed = 0
            let totalSteps = max(toShred.count, 1)
            for (idx, url) in toShred.enumerated() {
                currentFile = url.path
                let ok = await Task.detached(priority: .userInitiated) {
                    Self.shred(url: url, passes: passCount)
                }.value
                if !ok { failed += 1 }
                progress = Double(idx + 1) / Double(totalSteps)
            }

            phase = .done
            queue.removeAll()
            currentFile = nil
            if failed == 0 {
                finishedMessage = "Shredded \(toShred.count) item\(toShred.count == 1 ? "" : "s")"
            } else {
                finishedMessage = "Done. \(failed) item\(failed == 1 ? "" : "s") failed."
            }
            Log.app.info("shredder: completed \(toShred.count) items, \(failed) failed")
        }
    }

    private nonisolated static func shred(url: URL, passes: Int) -> Bool {
        let path = url.path

        // Skip whitelisted / protected paths defensively
        if WhitelistGuard.isProtected(url) {
            Log.app.fault("shredder: refused on protected \(path, privacy: .public)")
            return false
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return false }

        if isDir.boolValue {
            // Walk the directory and shred files inside, then delete the dir.
            if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
                while let item = enumerator.nextObject() as? URL {
                    if WhitelistGuard.isProtected(item) { continue }
                    if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { continue }
                    _ = overwriteAndUnlink(path: item.path, passes: passes)
                }
            }
            do {
                try FileManager.default.removeItem(at: url)
                return true
            } catch {
                Log.app.error("shredder: removing dir failed \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return false
            }
        } else {
            return overwriteAndUnlink(path: path, passes: passes)
        }
    }

    private nonisolated static func overwriteAndUnlink(path: String, passes: Int) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else { return false }

        guard let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) else { return false }
        defer { try? handle.close() }

        let chunkSize = 1 << 20  // 1 MiB
        for _ in 0..<max(1, passes) {
            try? handle.seek(toOffset: 0)
            var written: Int64 = 0
            while written < size {
                let n = min(Int64(chunkSize), size - written)
                var bytes = Data(count: Int(n))
                bytes.withUnsafeMutableBytes { buf in
                    if let base = buf.baseAddress {
                        _ = SecRandomCopyBytes(kSecRandomDefault, Int(n), base)
                    }
                }
                try? handle.write(contentsOf: bytes)
                written += n
            }
            try? handle.synchronize()
        }
        try? handle.close()

        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            Log.app.error("shredder: unlink failed \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
