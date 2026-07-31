package file_watcher

DEDUPLICATE_CHANGES :: #config(FW_DEDUPE, true)

File_Change_Type :: enum u32 {
    Null,
    Added,
    Removed,
    Modified,
    Renamed,
}

File_Watch_Change :: struct {
    type: File_Change_Type,
    name: string,
    file: string,
    prev_name: string,
    prev_file: string,
}
