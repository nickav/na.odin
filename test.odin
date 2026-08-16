package main

import fw "file_watcher"
import "core:os"
import "core:time"
import "core:fmt"

main :: proc() {
    path, err := os.user_downloads_dir(context.allocator)
    if err != nil {
        fmt.eprintln("failed to get downloads dir:", err)
        return
    }

    fw._example_run_wacher(path)
}