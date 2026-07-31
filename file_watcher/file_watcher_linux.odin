package file_watcher

File_Watch_Path :: struct {
    path: string
}

File_Watcher :: struct {
    paths: [dynamic]File_Watch_Path,
}

init :: proc(self: ^File_Watcher) {
}

add_path :: proc(self: ^File_Watcher, path: string) -> bool {
    return false
}

remove_path :: proc(self: ^File_Watcher, path: string) -> bool {
    return false
}

read_changes :: proc(self: ^File_Watcher, allocator := context.temp_allocator) -> [dynamic]File_Watch_Change {
    results: [dynamic]File_Watch_Change
    return results
}

free :: proc(self: ^File_Watcher) {
    for &w in self.paths {
        remove_path(self, w.path)
    }
    delete(self.paths)
}