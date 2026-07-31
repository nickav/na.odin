package file_watcher

import win32 "core:sys/windows"
import "core:strings"
import "core:path/filepath"
import "core:mem"

// NOTE(nick): Odin's built-in type uses snake_case for some reason (even though literally all the other win32 structs don't)
FILE_NOTIFY_INFORMATION :: struct {
    NextEntryOffset: win32.DWORD,
    Action:          win32.DWORD,
    FileNameLength:  win32.DWORD,
    FileName:        [1]win32.WCHAR,
}

File_Watch_Path :: struct {
    path: string,
    file: win32.HANDLE,
    flags: win32.DWORD,
    overlapped: win32.OVERLAPPED,
    buffer: [2048]u8,
}

File_Watcher :: struct {
    paths: [dynamic]File_Watch_Path,
}

init :: proc(self: ^File_Watcher) {
}

add_path :: proc(self: ^File_Watcher, path: string) -> bool {
    wpath := win32.utf8_to_wstring(path)
    file := win32.CreateFileW(
        wpath,
        win32.FILE_LIST_DIRECTORY,
        win32.FILE_SHARE_READ | win32.FILE_SHARE_WRITE | win32.FILE_SHARE_DELETE,
        nil,
        win32.OPEN_EXISTING,
        win32.FILE_FLAG_BACKUP_SEMANTICS | win32.FILE_FLAG_OVERLAPPED,
        nil,
    )
    if file == win32.INVALID_HANDLE_VALUE {
        return false
    }

    // win32.FILE_NOTIFY_CHANGE_SIZE
    flags : win32.DWORD = win32.FILE_NOTIFY_CHANGE_FILE_NAME | win32.FILE_NOTIFY_CHANGE_DIR_NAME | win32.FILE_NOTIFY_CHANGE_LAST_WRITE | win32.FILE_NOTIFY_CHANGE_CREATION

    it := File_Watch_Path{}
    it.path = strings.clone(path)
    it.file = file
    it.flags = flags
    it.overlapped.hEvent = win32.CreateEventW(nil, false, false, nil)

    if _, err := append(&self.paths, it); err != nil {
        return false
    }

    win32.ReadDirectoryChangesW(it.file, &it.buffer[0], len(it.buffer), true, it.flags, nil, &it.overlapped, nil)
    return true
}

remove_path :: proc(self: ^File_Watcher, path: string) -> bool {
    for it, index in self.paths {
        if path == it.path {
            delete(it.path)
            if it.file != nil {
                win32.CloseHandle(it.file)
            }
            if it.overlapped.hEvent != nil {
                win32.CloseHandle(it.overlapped.hEvent)
            }
            unordered_remove(&self.paths, index)
            return true
        }
    }
    return false
}

read_changes :: proc(self: ^File_Watcher, allocator := context.temp_allocator) -> [dynamic]File_Watch_Change {
    results: [dynamic]File_Watch_Change

    for &w in self.paths {
        if win32.WaitForSingleObject(w.overlapped.hEvent, 0) != win32.WAIT_OBJECT_0 do continue

        bytes_transferred: win32.DWORD
        ok := win32.GetOverlappedResult(w.file, &w.overlapped, &bytes_transferred, false)
        if !ok || bytes_transferred == 0 {
            win32.ReadDirectoryChangesW(w.file, &w.buffer[0], len(w.buffer), true, w.flags, nil, &w.overlapped, nil)
            continue
        }

        event := cast(^FILE_NOTIFY_INFORMATION)&w.buffer[0]

        for {
            name_count := int(event.FileNameLength / size_of(u16))
            name_ptr := cast([^]u16)&event.FileName[0]
            name, _    := win32.utf16_to_utf8(name_ptr[:name_count], allocator)

            change: File_Watch_Change
            change.name = name

            switch event.Action
            {
                case win32.FILE_ACTION_ADDED:    change.type = .Added
                case win32.FILE_ACTION_REMOVED:  change.type = .Removed
                case win32.FILE_ACTION_MODIFIED: change.type = .Modified
                // NOTE(nick): I think typically you get an OLD_NAME followed by a NEW_NAME (which is already handled by the OLD_NAME branch)
                // Adding this in case there are weird edge cases?
                case win32.FILE_ACTION_RENAMED_NEW_NAME: change.type = .Renamed
                case win32.FILE_ACTION_RENAMED_OLD_NAME:

                    change.type      = .Renamed
                    change.prev_name = change.name
                    change.name      = ""

                    if event.NextEntryOffset != 0 {
                        next := cast(^FILE_NOTIFY_INFORMATION)(uintptr(event) + uintptr(event.NextEntryOffset))
                        if next.Action == win32.FILE_ACTION_RENAMED_NEW_NAME
                        {
                            nc   := int(next.FileNameLength / size_of(u16))
                            nptr := cast([^]u16)&next.FileName[0]
                            change.name, _ = win32.utf16_to_utf8(nptr[:nc], allocator)
                            event = cast(^FILE_NOTIFY_INFORMATION)(uintptr(event) + uintptr(event.NextEntryOffset))
                        }
                    }
            }

            // @Speed @Memory: think about ways to simplify this...
            if change.type != .Null && len(change.name) > 0 {
                file, _ := filepath.join({ w.path, change.name }, allocator)

                // NOTE(nick): deduplicate file changes
                skip := false
                when DEDUPLICATE_CHANGES {
                    if len(results) > 0 {
                        prev_change := results[len(results) - 1]

                        if prev_change.file == file && prev_change.type == change.type {
                            delete(file, allocator)
                            skip = true
                        }
                    }
                }

                if !skip {
                    change.file = file

                    if len(change.prev_name) > 0 {
                        prev_file, _ := filepath.join({ w.path, change.prev_name }, allocator)
                        change.prev_file = prev_file
                    }
                    append(&results, change)
                }
            }

            if event.NextEntryOffset == 0 do break
            event = cast(^FILE_NOTIFY_INFORMATION)(uintptr(event) + uintptr(event.NextEntryOffset))
        }

        win32.ReadDirectoryChangesW(w.file, &w.buffer[0], len(w.buffer), true, w.flags, nil, &w.overlapped, nil)
    }

    return results
}

free :: proc(self: ^File_Watcher) {
    for &w in self.paths {
        remove_path(self, w.path)
    }
    delete(self.paths)
}