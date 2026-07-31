package file_watcher

import "core:time"
import "core:fmt"

_example_run_wacher :: proc(path: string) {
    self := File_Watcher{}
    if !add_path(&self, path)  {
        fmt.printf("Failed to watch: %s\n", path)
    }

    fmt.printf("Watching path for changes: %s\n", path)

    for {
        changes := read_changes(&self)
        for it in changes {
            switch it.type {
            case .Added:
                fmt.printf("[Added] %s\n", it.file)
            case .Removed:
                fmt.printf("[Removed] %s\n", it.file)
            case .Modified:
                fmt.printf("[Modified] %s\n", it.file)
            case .Renamed:
                fmt.printf("[Renamed] %s -> %s\n", it.prev_file, it.file)
            case .Null:
            }
        }

        time.sleep(50 * time.Millisecond)
    }
}