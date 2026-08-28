package file_watcher

import linux "core:sys/linux"
import "core:strings"
import "core:path/filepath"
import "core:c"

// NOTE(nick): need to exclude name from the size
INOTIFY_EVENT_SIZE :: 16

Inotify_Event :: struct {
    wd:     linux.Wd,
    mask:   c.uint32_t,
    cookie: c.uint32_t,
    len:    c.uint32_t,
    name:   [1]u8,
}

#assert(size_of(Inotify_Event) == 20)

IN_CREATE     :: 0x00000100
IN_DELETE     :: 0x00000200
IN_MODIFY     :: 0x00000002
IN_MOVED_FROM :: 0x00000040
IN_MOVED_TO   :: 0x00000080

File_Watch_Path :: struct {
    path: string,
    wd:   linux.Wd,
}

File_Watcher :: struct {
    fd:    linux.Fd,
    paths: [dynamic]File_Watch_Path,
    initted: bool,
}

Pending_Rename :: struct {
    cookie: u32,
    name:   string,
    file:   string,
}

@(private)
linux__path_for_wd :: proc(self: ^File_Watcher, wd: linux.Wd) -> string {
    for it in self.paths {
        if it.wd == wd do return it.path
    }
    return ""
}


@(private)
linux__init :: proc(self: ^File_Watcher) -> bool {
    if self.initted do return true

    fd, errno := linux.inotify_init1({.NONBLOCK})
    if errno != .NONE do return false
    self.fd = fd
    self.initted = true
    return true
}

add_path :: proc(self: ^File_Watcher, path: string) -> bool {
    linux__init(self)

    for it in self.paths {
        if it.path == path do return true
    }

    cpath := strings.clone_to_cstring(path, context.temp_allocator)
    wd, errno := linux.inotify_add_watch(self.fd, cpath, {.CREATE, .DELETE, .MODIFY, .MOVED_FROM, .MOVED_TO})
    if errno != .NONE {
        // fmt.println("inotify_add_watch errno:", errno, "path:", path)
        return false
    }

    it := File_Watch_Path{ path = strings.clone(path), wd = wd }
    if _, err := append(&self.paths, it); err != nil {
        linux.inotify_rm_watch(self.fd, wd)
        delete(it.path)
        return false
    }

    return true
}

remove_path :: proc(self: ^File_Watcher, path: string) -> bool {
    for it, index in self.paths {
        if path == it.path {
            linux.inotify_rm_watch(self.fd, it.wd)
            delete(it.path)
            unordered_remove(&self.paths, index)
            return true
        }
    }
    return false
}

read_changes :: proc(self: ^File_Watcher, allocator := context.temp_allocator) -> [dynamic]File_Watch_Change {
    linux__init(self)

    results: [dynamic]File_Watch_Change

    pending_renames: [64]Pending_Rename
    pending_rename_count := 0

    buf: [4096]u8

    for {
        n, errno := linux.read(self.fd, buf[:])
        if errno != .NONE || n <= 0 do break

        ptr := 0
        for ptr < n {
            // NOTE(nick): can't use size_of(Inotify_Event) because it doesn't match the C struct
            event := cast(^Inotify_Event)&buf[ptr]
            ptr += INOTIFY_EVENT_SIZE + int(event.len)

            watch_path := linux__path_for_wd(self, event.wd)
            if len(watch_path) == 0 do continue

            name: string
            if event.len > 0 {
                name_ptr := cast([^]u8)&event.name[0]
                name, _ = strings.clone_from_cstring(cast(cstring)name_ptr, allocator)
            }
            if len(name) == 0 do continue

            file, _ := filepath.join({ watch_path, name }, allocator)
            name = filepath.base(file)

            if event.mask & IN_MOVED_FROM != 0 {
                if pending_rename_count < len(pending_renames) {
                    pending_renames[pending_rename_count] = Pending_Rename{ cookie = event.cookie, name = name, file = file }
                    pending_rename_count += 1
                }
                continue
            }

            change: File_Watch_Change
            change.name = name
            change.file = file

            switch {
            case event.mask & IN_CREATE != 0: change.type = .Added
            case event.mask & IN_DELETE != 0: change.type = .Removed
            case event.mask & IN_MODIFY != 0: change.type = .Modified
            case event.mask & IN_MOVED_TO != 0:
                change.type = .Renamed
                for i := 0; i < pending_rename_count; i += 1 {
                    if pending_renames[i].cookie == event.cookie {
                        change.prev_name = pending_renames[i].name
                        change.prev_file = pending_renames[i].file
                        pending_rename_count -= 1
                        pending_renames[i] = pending_renames[pending_rename_count]
                        break
                    }
                }
            }

            if change.type != .Null {
                append(&results, change)
            }
        }
    }

    for i := 0; i < pending_rename_count; i += 1 {
        change: File_Watch_Change
        change.type = .Removed
        change.name = pending_renames[i].name
        change.file = pending_renames[i].file
        append(&results, change)
    }

    return results
}

free :: proc(self: ^File_Watcher) {
    for it in self.paths {
        linux.inotify_rm_watch(self.fd, it.wd)
        delete(it.path)
    }
    delete(self.paths)
    linux.close(self.fd)
    self.fd = 0
    self.initted = false
}