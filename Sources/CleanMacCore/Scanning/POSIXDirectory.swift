import Darwin

/// Fast directory listing with `readdir` + `fstatat`, the same calls `du` uses. Avoids creating
/// a Foundation URL per file, which dominates scan time on millions of files.
enum POSIXDirectory {
    enum Kind { case directory, symlink, file }

    struct Entry {
        let name: String
        let kind: Kind
        /// Bytes allocated on disk (`st_blocks * 512`).
        let allocated: Int64
    }

    enum ListError: Error { case unreadable, missing }

    static func entries(of path: String) -> Result<[Entry], ListError> {
        guard let dir = opendir(path) else {
            return .failure(errno == ENOENT || errno == ENOTDIR ? .missing : .unreadable)
        }
        defer { closedir(dir) }
        let fd = dirfd(dir)
        var result: [Entry] = []
        while let entry = readdir(dir) {
            var raw = entry.pointee.d_name
            let name = withUnsafeBytes(of: &raw) { buffer in
                String(cString: buffer.bindMemory(to: CChar.self).baseAddress!)
            }
            if name == "." || name == ".." { continue }
            var info = Darwin.stat()
            // A failure here means the entry vanished between listing and reading: skip it.
            guard fstatat(fd, name, &info, AT_SYMLINK_NOFOLLOW) == 0 else { continue }
            result.append(Entry(name: name, kind: kind(of: info.st_mode), allocated: Int64(info.st_blocks) * 512))
        }
        return .success(result)
    }

    /// Kind and allocated size of a single path, without following a final symlink.
    static func stat(path: String) -> (kind: Kind, allocated: Int64)? {
        var info = Darwin.stat()
        guard lstat(path, &info) == 0 else { return nil }
        return (kind(of: info.st_mode), Int64(info.st_blocks) * 512)
    }

    /// Recursive allocated size of `path`; unreadable folders are counted, not fatal.
    static func totalSize(of path: String, unreadable: inout Int) -> Int64 {
        guard let top = stat(path: path) else { return 0 }
        guard top.kind == .directory else { return top.allocated }
        switch entries(of: path) {
        case .failure(.unreadable):
            unreadable += 1
            return 0
        case .failure:
            return 0
        case .success(let children):
            var total: Int64 = 0
            for child in children {
                if child.kind == .directory {
                    total += totalSize(of: join(path, child.name), unreadable: &unreadable)
                } else {
                    total += child.allocated
                }
            }
            return total
        }
    }

    static func join(_ parent: String, _ name: String) -> String {
        parent == "/" ? "/" + name : parent + "/" + name
    }

    private static func kind(of mode: mode_t) -> Kind {
        switch mode & S_IFMT {
        case S_IFDIR: .directory
        case S_IFLNK: .symlink
        default: .file
        }
    }
}
