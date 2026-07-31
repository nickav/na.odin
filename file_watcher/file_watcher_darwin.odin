package file_watcher

import "core:c"
import "core:strings"
import "core:path/filepath"
import "core:runtime"

foreign import CoreServices "system:CoreServices.framework"
foreign import CoreFoundation "system:CoreFoundation.framework"

CFAllocatorRef :: rawptr
CFStringRef    :: rawptr
CFArrayRef     :: rawptr
CFRunLoopRef   :: rawptr
CFIndex        :: int
CFTimeInterval :: f64

FSEventStreamRef        :: rawptr
FSEventStreamEventFlags :: u32
FSEventStreamEventId    :: u64

FSEventStreamCallback :: #type proc "c" (
    streamRef:  FSEventStreamRef,
    info:       rawptr,
    numEvents:  c.size_t,
    eventPaths: rawptr,
    eventFlags: [^]FSEventStreamEventFlags,
    eventIds:   [^]FSEventStreamEventId,
)

FSEventStreamContext :: struct {
    version:          CFIndex,
    info:             rawptr,
    retain:           rawptr,
    release:          rawptr,
    copy_description: rawptr,
}

CFArrayCallBacks :: struct {
    version:         CFIndex,
    retain:          rawptr,
    release:         rawptr,
    copyDescription: rawptr,
    equal:           rawptr,
}

kFSEventStreamEventIdSinceNow      :: max(u64)
kFSEventStreamCreateFlagFileEvents :: 0x00000010
kCFStringEncodingUTF8              :: 0x08000100

kFSEventStreamEventFlagItemCreated  :: 0x00000100
kFSEventStreamEventFlagItemRemoved  :: 0x00000200
kFSEventStreamEventFlagItemRenamed  :: 0x00000800
kFSEventStreamEventFlagItemModified :: 0x00001000

@(default_calling_convention="c")
foreign CoreFoundation {
    kCFRunLoopDefaultMode: CFStringRef
    kCFTypeArrayCallBacks: CFArrayCallBacks
}

@(default_calling_convention="c")
foreign CoreServices {
    CFStringCreateWithCString :: proc(alloc: CFAllocatorRef, cStr: cstring, encoding: u32) -> CFStringRef ---
    CFArrayCreate             :: proc(alloc: CFAllocatorRef, values: [^]rawptr, numValues: CFIndex, callBacks: ^CFArrayCallBacks) -> CFArrayRef ---
    CFRelease                 :: proc(cf: rawptr) ---
    CFRunLoopGetCurrent        :: proc() -> CFRunLoopRef ---
    CFRunLoopRunInMode         :: proc(mode: CFStringRef, seconds: CFTimeInterval, returnAfterSourceHandled: c.bool) -> i32 ---

    FSEventStreamCreate              :: proc(alloc: CFAllocatorRef, callback: FSEventStreamCallback, ctx: ^FSEventStreamContext, pathsToWatch: CFArrayRef, sinceWhen: FSEventStreamEventId, latency: CFTimeInterval, flags: u32) -> FSEventStreamRef ---
    FSEventStreamScheduleWithRunLoop :: proc(streamRef: FSEventStreamRef, runLoop: CFRunLoopRef, runLoopMode: CFStringRef) ---
    FSEventStreamStart               :: proc(streamRef: FSEventStreamRef) -> c.bool ---
    FSEventStreamStop                :: proc(streamRef: FSEventStreamRef) ---
    FSEventStreamInvalidate          :: proc(streamRef: FSEventStreamRef) ---
    FSEventStreamRelease             :: proc(streamRef: FSEventStreamRef) ---
}

File_Watcher :: struct {
    paths:   [dynamic]string,
    stream:  FSEventStreamRef,
    pending: [dynamic]File_Watch_Change,
}


macos__fsevent_callback :: proc "c" (
    streamRef: FSEventStreamRef, info: rawptr, numEvents: c.size_t, eventPaths: rawptr,
    eventFlags: [^]FSEventStreamEventFlags, eventIds: [^]FSEventStreamEventId,
) {
    context = runtime.default_context()

    self  := cast(^File_Watcher)info
    paths := cast([^]cstring)eventPaths

    for i in 0 ..< int(numEvents) {
        flags := eventFlags[i]

        created  := flags & kFSEventStreamEventFlagItemCreated  != 0
        removed  := flags & kFSEventStreamEventFlagItemRemoved  != 0
        renamed  := flags & kFSEventStreamEventFlagItemRenamed  != 0
        modified := flags & kFSEventStreamEventFlagItemModified != 0

        type: File_Change_Type
        switch {
        case created:  type = .Added
        case removed:  type = .Removed
        case renamed:  type = .Renamed
        case modified: type = .Modified
        }

        if type != .Null && paths[i] != nil {
            change: File_Watch_Change
            change.type = type
            change.file = strings.clone(string(paths[i]))
            change.name = filepath.base(change.file)
            append(&self.pending, change)
        }
    }
}

macos__rebuild_stream :: proc(self: ^File_Watcher) -> bool {
    if self.stream != nil {
        FSEventStreamStop(self.stream)
        FSEventStreamInvalidate(self.stream)
        FSEventStreamRelease(self.stream)
        self.stream = nil
    }

    if len(self.paths) == 0 do return true

    cf_paths := make([]rawptr, len(self.paths), context.temp_allocator)
    for path, i in self.paths {
        cpath := strings.clone_to_cstring(path, context.temp_allocator)
        cf_paths[i] = CFStringCreateWithCString(nil, cpath, kCFStringEncodingUTF8)
    }

    paths_array := CFArrayCreate(nil, raw_data(cf_paths), len(cf_paths), &kCFTypeArrayCallBacks)

    ctx := FSEventStreamContext{ info = self }

    self.stream = FSEventStreamCreate(
        nil, macos__fsevent_callback, &ctx, paths_array,
        kFSEventStreamEventIdSinceNow, 0.05, kFSEventStreamCreateFlagFileEvents,
    )
    if self.stream == nil {
        return false
    }

    FSEventStreamScheduleWithRunLoop(self.stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)
    FSEventStreamStart(self.stream)

    for cf in cf_paths do CFRelease(cf)
    CFRelease(paths_array)
    return true
}


init :: proc(self: ^File_Watcher) {
}

add_path :: proc(self: ^File_Watcher, path: string) -> bool {
    for it in self.paths {
        if it == path do return true
    }

    append(&self.paths, strings.clone(path))
    macos__rebuild_stream(self) or_return
    return true
}

remove_path :: proc(self: ^File_Watcher, path: string) -> bool {
    for p, index in self.paths {
        if path == p {
            delete(p)
            unordered_remove(&self.paths, index)
            macos__rebuild_stream(self)
            return true
        }
    }
    return false
}

read_changes :: proc(self: ^File_Watcher, allocator := context.temp_allocator) -> [dynamic]File_Watch_Change {
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.0, false)

    results := self.pending
    self.pending = {}
    return results
}

free :: proc(self: ^File_Watcher) {
    if self.stream != nil {
        FSEventStreamStop(self.stream)
        FSEventStreamInvalidate(self.stream)
        FSEventStreamRelease(self.stream)
        self.stream = nil
    }
    for p in self.paths do delete(p)
    delete(self.paths)
    delete(self.pending)
}