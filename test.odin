package engine

import fw "file_watcher"
import "core:time"
import "core:fmt"

main :: proc() {
    path := ""
    when OS == .Windows {
        path = "C:/Users/Nick/Downloads"
    } else when OS == .Darwin {
        path = "/Users/Nick/Downloads"
    } else when OS == .Linux {
        path = "/home/nick/Downloads"
    }

    fw._example_run_wacher(path)
}