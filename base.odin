package main

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:path/filepath"
import virtual_memory "core:mem/virtual"
import "core:strings"
import "core:strconv"
import "core:time"
import "core:os"
import "core:unicode"
import "core:unicode/utf8"
import "core:encoding/base64"
import "core:encoding/json"
import win32 "core:sys/windows"

//
// Basic
//

OS :: ODIN_OS
DEBUG :: ODIN_DEBUG

KB :: 1024
MB :: 1024 * 1024
GB :: 1024 * 1024 * 1024
TB :: 1024 * 1024 * 1024 * 1024

Kilobytes :: proc(x: uint) -> uint { return x * 1024 }
Megabytes :: proc(x: uint) -> uint { return x * 1024 * 1024 }
Gigabytes :: proc(x: uint) -> uint { return x * 1024 * 1024 * 1024 }
Terabytes :: proc(x: uint) -> uint { return x * 1024 * 1024 * 1024 * 1024 }

print :: fmt.print
println :: fmt.println
printf :: fmt.printf

count_of :: len

Dump :: proc(args: ..any) {
    for x in args {
        print(x)
        print(" ")
    }
    print("\n")
}

breakpoint :: proc() {
    when ODIN_DEBUG {
        intrinsics.debug_trap()
    }
}

//
// OS
//

os_init :: proc() {
    when ODIN_OS == .Windows {
        os_attach_parent_console()
    }
    _ = os_time()
}

os_free :: proc() {
    when ODIN_OS == .Windows {
        os_detach_parent_console()
    }
}

when ODIN_OS == .Windows {
    os_attach_parent_console :: proc() {
        ATTACH_PARENT_PROCESS :: ~win32.DWORD(0)

        if win32.GetStdHandle(win32.STD_OUTPUT_HANDLE) != nil do return
        if !win32.AttachConsole(ATTACH_PARENT_PROCESS) do return

        os.stdout = os.new_file(uintptr(win32.GetStdHandle(win32.STD_OUTPUT_HANDLE)), "<stdout>")
        os.stderr = os.new_file(uintptr(win32.GetStdHandle(win32.STD_ERROR_HANDLE)), "<stderr>")
        g_attached_parent_console = true
    }

    os_detach_parent_console :: proc() {
        if !g_attached_parent_console do return
        g_attached_parent_console = false

        records: [2]win32.INPUT_RECORD
        for &record, i in records {
            record.EventType = .KEY_EVENT
            record.Event.KeyEvent = {
                bKeyDown         = i == 0,
                wRepeatCount     = 1,
                wVirtualKeyCode  = win32.VK_RETURN,
                wVirtualScanCode = win32.WORD(win32.MapVirtualKeyW(win32.VK_RETURN, win32.MAPVK_VK_TO_VSC)),
            }
            record.Event.KeyEvent.uChar.UnicodeChar = '\r'
        }

        written: win32.DWORD
        WriteConsoleInputW(win32.GetStdHandle(win32.STD_INPUT_HANDLE), &records[0], len(records), &written)
        win32.FreeConsole()
    }

    @(private="file")
    g_attached_parent_console: bool

    foreign import kernel32_console "system:Kernel32.lib"

    @(default_calling_convention = "system")
    foreign kernel32_console {
        WriteConsoleInputW :: proc(hConsoleInput: win32.HANDLE, lpBuffer: ^win32.INPUT_RECORD, nLength: win32.DWORD, lpNumberOfEventsWritten: ^win32.DWORD) -> win32.BOOL ---
    }
}

// Time in seconds since program start
os_time :: proc() -> f64 {
    @(static) start_time_nsec: i64
    @(static) initted: bool
    if !initted {
        start_time_nsec = time.now()._nsec
        initted = true
    }

    return f64(time.now()._nsec - start_time_nsec) / 1e9
}

os_cpu_time :: proc() -> u64 {
    return u64(intrinsics.read_cycle_counter())
}

os_read_entire_file :: proc(file: string, allocator := context.allocator) -> ([]u8, bool) {
    data, err := os.read_entire_file(file, allocator)
    return data, err == nil
}

os_write_entire_file :: proc(file: string, data: []u8) -> bool {
    return os.write_entire_file(file, data) != nil
}

os_scan_folder :: proc(folder: string, allocator := context.allocator) -> [dynamic]string {
    result := make([dynamic]string, 0, allocator)

    handle, err := os.open(folder)
    if err != nil { return result }
    defer os.close(handle)

    infos, rerr := os.read_dir(handle, -1, context.temp_allocator)
    if rerr != nil { return result }

    for info in infos {
        if strings.has_prefix(info.name, ".") { continue }
        append(&result, strings.clone(info.name, allocator))
    }

    return result
}

//
// Arena
//

MemoryCopy :: mem.copy

Arena :: virtual_memory.Arena

arena_alloc :: proc(reserved: uint = virtual_memory.DEFAULT_ARENA_GROWING_MINIMUM_BLOCK_SIZE) -> ^Arena {
    arena := new(Arena)
    err := virtual_memory.arena_init_growing(arena, reserved)
    if err != nil {
        free(arena)
        arena = nil
    }
    return arena
}

arena_alloc_from_static :: proc(
    reserved:    uint = virtual_memory.DEFAULT_ARENA_STATIC_RESERVE_SIZE,
    commit_size: uint = virtual_memory.DEFAULT_ARENA_STATIC_COMMIT_SIZE,
) -> ^Arena {
    arena := new(Arena)
    err := virtual_memory.arena_init_static(arena, reserved, commit_size)
    if err != nil {
        free(arena)
        arena = nil
    }
    return arena
}

arena_alloc_from_buffer :: proc(buffer: []byte) -> ^Arena {
    arena := new(Arena)
    err := virtual_memory.arena_init_buffer(arena, buffer)
    if err != nil {
        free(arena)
        arena = nil
    }
    return arena
}

arena_suballoc :: proc(parent: ^Arena, size: uint, pow2_align: u64 = 16) -> ^Arena {
    total := size + size_of(virtual_memory.Memory_Block)
    data := ([^]byte)(arena_push(parent, u64(total), pow2_align, false))
    return arena_alloc_from_buffer(data[:total])
}

arena_free :: proc(arena: ^Arena) {
    if arena == nil {
        return
    }
    virtual_memory.arena_destroy(arena)
    free(arena)
}

arena_pop_to :: proc(arena: ^Arena, pos: u64) {
    pos := min(pos, u64(arena.total_used))
    for arena.curr_block != nil && u64(arena.total_used - arena.curr_block.used) > pos {
        virtual_memory.arena_growing_free_last_memory_block(arena)
    }
    if block := arena.curr_block; block != nil {
        local_pos := uint(pos) - (arena.total_used - block.used)
        amount := block.used - local_pos
        mem.zero_slice(block.base[local_pos:][:amount])
        block.used = local_pos
        arena.total_used = uint(pos)
    }
}

arena_pop :: proc(arena: ^Arena, size: u64) {
    used := u64(arena.total_used)
    arena_pop_to(arena, size < used ? used - size : 0)
}

arena_set_pos :: proc(arena: ^Arena, pos: u64) {
    arena_pop_to(arena, pos)
}

arena_get_pos :: proc(arena: ^Arena) -> u64 {
    return u64(arena.total_used)
}

arena_get_data :: proc(arena: ^Arena) -> rawptr {
    block := arena.curr_block
    return block != nil ? rawptr(block.base) : nil
}

arena_push :: proc(arena: ^Arena, size: u64, pow2_align: u64, zero: bool) -> rawptr {
    mode := zero ? runtime.Allocator_Mode.Alloc : runtime.Allocator_Mode.Alloc_Non_Zeroed
    data, err := virtual_memory.arena_allocator_proc(arena, mode, int(size), int(pow2_align), nil, 0)
    ensure(err == nil)
    return raw_data(data)
}

arena_write :: proc(arena: ^Arena, data: [^]u8, size: u64) -> bool {
    dst := arena_push(arena, size, 1, false)
    if dst == nil {
        return false
    }
    mem.copy(dst, data, int(size))
    return true
}

// NOTE(nick): this clobbers any sub-allocators (including sub-arenas!)
arena_reset :: proc(arena: ^Arena) {
    virtual_memory.arena_free_all(arena)
}

PushArrayZero :: proc(a: ^Arena, $T: typeid, c: u64) -> [^]T {
    return ([^]T)(arena_push(a, size_of(T) * c, u64(align_of(T)), true))
}

PushArrayNoZero :: proc(a: ^Arena, $T: typeid, c: u64) -> [^]T {
    return ([^]T)(arena_push(a, size_of(T) * c, u64(align_of(T)), false))
}

PushStructZero :: proc(a: ^Arena, $T: typeid) -> ^T {
    return (^T)(arena_push(a, size_of(T), u64(align_of(T)), true))
}

PushStructNoZero :: proc(a: ^Arena, $T: typeid) -> ^T {
    return (^T)(arena_push(a, size_of(T), u64(align_of(T)), false))
}

PushStruct :: PushStructZero
PushArray :: PushArrayZero

Arena_Temp :: virtual_memory.Arena_Temp

SCRATCH_ARENA_COUNT :: 2

@(thread_local)
g_scratch_arenas: [SCRATCH_ARENA_COUNT]^Arena

scratch_begin :: proc(conflicts: [^]^Arena = nil, conflict_count: u64 = 0) -> Arena_Temp {
    for i in 0 ..< SCRATCH_ARENA_COUNT {
        if g_scratch_arenas[i] == nil {
            g_scratch_arenas[i] = arena_alloc()
        }
    }
    outer: for candidate in g_scratch_arenas {
        for i in 0 ..< conflict_count {
            if conflicts[i] == candidate {
                continue outer
            }
        }
        return virtual_memory.arena_temp_begin(candidate)
    }
    panic("no scratch arena available")
}

scratch_end :: proc(temp: Arena_Temp) {
    virtual_memory.arena_temp_end(temp)
}

temp_arena :: proc() -> ^Arena { return scratch_begin(nil, 0).arena }

allocator_from_arena :: proc(arena: ^Arena) -> runtime.Allocator { return virtual_memory.arena_allocator(arena) }

//
// Strings
//

sprint :: fmt.aprintf
tprint :: fmt.tprintf

string_concat :: proc(strs: ..string, allocator := context.temp_allocator) -> string {
    return strings.concatenate(strs, allocator)
}

string_join :: proc(arr: []string, delim: string, allocator := context.temp_allocator) -> string {
    return strings.join(arr, delim, allocator)
}

string_split :: proc(str: string, sep: string, allocator := context.temp_allocator) -> []string {
    return strings.split(str, sep, allocator)
}

string_index :: proc(str: string, search: string) -> int {
    return strings.index(str, search)
}

string_slice :: proc(s: string, start, end: int) -> string {
    e := clamp(end, 0, len(s))
    b := clamp(start, 0, e)
    return s[b:e]
}

string_skip :: proc(s: string, n: int) -> string {
    return s[min(n, len(s)):]
}

string_chop :: proc(s: string, offset: int) -> string {
    return string_slice(s, 0, len(s) - offset)
}

string_prefix :: proc(s: string, count: int) -> string {
    return string_slice(s, 0, count)
}

string_suffix :: proc(s: string, count: int) -> string {
    return string_slice(s, len(s) - count, len(s))
}

string_split_iterator :: strings.split_iterator

string_to_cstring :: proc(str: string, allocator := context.temp_allocator) -> cstring {
    return strings.clone_to_cstring(str, allocator)
}

string_to_int :: proc(s: string) -> int {
    v, _ := strconv.parse_int(s)
    return v
}

string_replace_all :: proc(s: string, old: string, new: string, allocator := context.temp_allocator) -> string {
    result, _ := strings.replace_all(s, old, new, allocator)
    return result
}

string_trim_whitespace :: proc(s: string) -> string {
    return strings.trim_space(s)
}

string_includes :: proc(str: string, substr: string) -> bool {
    return strings.contains(str, substr)
}

string_equals :: proc(a, b: string, ignore_case := false) -> bool
{
    if ignore_case { return strings.equal_fold(a, b) }
    return a == b
}

string_starts_with :: proc(str: string, prefix: string) -> bool {
    return strings.has_prefix(str, prefix)
}

string_ends_with :: proc(str: string, suffix: string) -> bool {
    return strings.has_suffix(str, suffix)
}

string_to_lower :: proc(a: string, allocator := context.temp_allocator) -> string {
    return strings.to_lower(a, allocator)
}

string_alloc :: proc(s: string, allocator := context.allocator) -> string {
    return strings.clone(s, allocator)
}

string_from_codepoint :: proc(r: rune, allocator := context.allocator) -> string {
    bytes, n := utf8.encode_rune(r)
    return string_alloc(string(bytes[:n]), allocator)
}

string_push :: proc(arena: ^Arena, s: string) -> string
{
    if len(s) == 0 { return "" }
    data := PushArrayNoZero(arena, u8, u64(len(s)))
    buf := data[:len(s)]
    copy(buf, s)
    return string(buf)
}

string_insert :: proc(arena: ^Arena, s: string, pos: i64, insert: string, delete_count: i64) -> string
{
    pos := int(clamp(pos, 0, i64(len(s))))
    delete_count := int(clamp(delete_count, 0, i64(len(s) - pos)))

    before := s[:pos]
    after := s[pos + delete_count:]

    total := len(before) + len(insert) + len(after)
    if total == 0 { return "" }

    data := PushArrayNoZero(arena, u8, u64(total))
    buf := data[:total]

    n := copy(buf, before)
    n += copy(buf[n:], insert)
    copy(buf[n:], after)

    return string(buf)
}

string_seek_utf8 :: proc(text: string, pos: i64, amount: i64) -> i64
{
    pos := pos

    if amount > 0
    {
        for _ in 0 ..< amount
        {
            if pos >= i64(len(text)) { break }
            _, size := utf8.decode_rune(text[pos:])
            pos += i64(size)
        }
    }
    else if amount < 0
    {
        for _ in 0 ..< -amount
        {
            if pos <= 0 { break }
            _, size := utf8.decode_last_rune(text[:pos])
            pos -= i64(size)
        }
    }

    return pos
}

string_move_word :: proc(text: string, pos: i64, amount: i64) -> i64
{
    pos := pos
    forward := amount > 0

    for _ in 0 ..< abs(amount)
    {
        if forward
        {
            for pos < i64(len(text))
            {
                r, size := utf8.decode_rune(text[pos:])
                if !unicode.is_space(r) { break }
                pos += i64(size)
            }
            for pos < i64(len(text))
            {
                r, size := utf8.decode_rune(text[pos:])
                if unicode.is_space(r) { break }
                pos += i64(size)
            }
        }
        else
        {
            for pos > 0
            {
                r, size := utf8.decode_last_rune(text[:pos])
                if !unicode.is_space(r) { break }
                pos -= i64(size)
            }
            for pos > 0
            {
                r, size := utf8.decode_last_rune(text[:pos])
                if unicode.is_space(r) { break }
                pos -= i64(size)
            }
        }
    }

    return pos
}

string_word_bounds :: proc(text: string, pos: i64) -> (left: i64, right: i64)
{
    left = clamp(pos, 0, i64(len(text)))
    right = left

    at_space := false
    if right < i64(len(text)) {
        r, _ := utf8.decode_rune(text[right:])
        at_space = unicode.is_space(r)
    }

    for left > 0 {
        r, size := utf8.decode_last_rune(text[:left])
        if unicode.is_space(r) != at_space { break }
        left -= i64(size)
    }

    for right < i64(len(text)) {
        r, size := utf8.decode_rune(text[right:])
        if unicode.is_space(r) != at_space { break }
        right += i64(size)
    }

    return
}

string_line_start :: proc(text: string, pos: i64) -> i64
{
    p := clamp(pos, 0, i64(len(text)))
    for p > 0 && text[p - 1] != '\n' {
        p -= 1
    }
    return p
}

string_line_end :: proc(text: string, pos: i64) -> i64
{
    p := clamp(pos, 0, i64(len(text)))
    for p < i64(len(text)) && text[p] != '\n' {
        p += 1
    }
    return p
}

string_strip_newlines :: proc(s: string, allocator := context.allocator) -> string
{
    buf := make([]u8, len(s), allocator)
    n := 0
    for i in 0 ..< len(s) {
        c := s[i]
        if c == '\n' || c == '\r' { continue }
        buf[n] = c
        n += 1
    }
    return string(buf[:n])
}

string_forward_match :: proc(item: string, query: string) -> bool
{
    if len(query) == 0 { return true }

    item_lower := strings.to_lower(item, context.temp_allocator)
    query_lower := strings.to_lower(query, context.temp_allocator)

    qi := 0
    for i in 0..<len(item_lower) {
        if qi >= len(query_lower) { break }
        if item_lower[i] == query_lower[qi] { qi += 1 }
    }
    return qi >= len(query_lower)
}

string_array_includes :: proc(arr: []string, x: string) -> bool {
    for it in arr {
        if it == x { return true }
    }
    return false
}

String_Builder :: strings.Builder

sb_create :: proc(it: ^String_Builder, allocator := context.allocator) {
    it^ = strings.builder_make(allocator)
}

sb_push :: proc(it: ^String_Builder, str: string) {
    if it == nil {
        it^ = strings.builder_make()
    }

    strings.write_string(it, str)
}

sb_print :: proc(it: ^String_Builder, format_string: string, args: ..any) {
    if it == nil {
        it^ = strings.builder_make()
    }

    fmt.sbprintf(it, format_string, ..args)
}

sb_len :: proc(it: ^String_Builder) -> int {
    if it == nil { return 0 }
    return strings.builder_len(it^)
}

sb_truncate :: proc(it: ^String_Builder, length: int) {
    if it != nil {
        resize(&it.buf, clamp(length, 0, len(it.buf)))
    }
}

sb_reset :: proc(it: ^String_Builder) {
    if it != nil {
        strings.builder_reset(it)
    }
}

sb_to_string :: proc(it: ^String_Builder) -> string {
    if it == nil { return "" }
    return strings.to_string(it^)
}

sb_destroy :: proc(it: ^String_Builder) {
    if it != nil {
        strings.builder_destroy(it)
    }
}

//
// Paths
//

path_filename :: proc(path: string) -> string
{
    return filepath.base(path)
}

path_dirname :: proc(path: string) -> string
{
    return filepath.dir(path)
}

path_extension :: proc(path: string) -> string
{
    return filepath.ext(path)
}

path_strip_extension :: proc(path: string) -> string
{
    return path[:len(path) - len(filepath.ext(path))]
}

path_join :: proc(parts: ..string, allocator := context.temp_allocator) -> string
{
    result, _ := filepath.join(parts, allocator)
    return result
}

path_is_absolute :: proc(path: string) -> bool
{
    return filepath.is_abs(path)
}

path_absolute :: proc(path: string, allocator := context.temp_allocator) -> string
{
    result, _ := filepath.abs(path, allocator)
    return result
}

path_contains :: proc(dir: string, path: string) -> bool
{
    rel, err := filepath.rel(dir, path, context.temp_allocator)
    if err != .None { return false }
    if rel == "." { return true }
    return !filepath.is_abs(rel) && rel != ".." && !string_starts_with(rel, "../") && !string_starts_with(rel, "..\\")
}

path_sanitize :: proc(name: string, allocator := context.allocator) -> string {
    b := make([]u8, len(name), context.temp_allocator)
    copy(b, name)
    for i in 0 ..< len(b) {
        switch b[i] {
        case '/', '\\', ':', '*', '?', '"', '<', '>', '|':
            b[i] = '_'
        }
    }
    return strings.clone(string(b), allocator)
}

//
// Dates
//

date_month_from_string :: proc(mon: string) -> int {
    months := [?]string{"", "Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
    m := mon
    if len(m) > 3 { m = m[:3] }
    for i in 1 ..< len(months) {
        if string_equals(months[i], m, ignore_case = true) { return i }
    }
    return 0
}

time_local_to_utc :: proc(year, mon, day, hour, min, sec, utc_offset_mins: int) -> (t: time.Time, ok: bool) {
    t = time.components_to_time(year, mon, day, hour, min, sec) or_return
    return time.time_add(t, -time.Duration(utc_offset_mins) * time.Minute), true
}

time_to_sql_date :: proc(t: time.Time, allocator := context.allocator) -> string {
    y, m, d := time.date(t)
    return fmt.aprintf("%04d-%02d-%02d", y, int(m), d, allocator = allocator)
}

//
// Base64
//

base64_encode :: proc(input: string, url_safe: bool, allocator := context.allocator) -> string {
    if url_safe {
        out, _ := base64.encode(transmute([]u8)input, base64.ENC_URL_TABLE, allocator)
        return strings.trim_right(out, "=")
    }
    out, _ := base64.encode(transmute([]u8)input, base64.ENC_TABLE, allocator)
    return out
}

base64_decode :: proc(input: string, allocator := context.allocator) -> string {
    s := input
    if r := len(s) % 4; r != 0 {
        pad := "==="
        s = strings.concatenate({s, pad[:4-r]}, context.temp_allocator)
    }
    tbl := strings.contains_any(s, "-_") ? base64.DEC_URL_TABLE : base64.DEC_TABLE
    out, _ := base64.decode(s, tbl, allocator = allocator)
    return string(out)
}

//
// JSON
//

json_parse :: proc(text: string, allocator := context.temp_allocator) -> json.Value {
    value, err := json.parse_string(text, allocator = allocator)
    if err != .None { return nil }
    return value
}

json_find :: proc(v: json.Value, key: string) -> json.Value {
    obj, ok := v.(json.Object)
    if !ok { return nil }
    return obj[key]
}

json_dig :: proc(v: json.Value, keys: ..string) -> json.Value {
    v := v
    for key in keys {
        v = json_find(v, key)
        if v == nil { return nil }
    }
    return v
}

json_to_string :: proc(v: json.Value) -> string {
    s, ok := v.(string)
    return ok ? s : ""
}

//
// YAML
//

yaml_find :: proc(text, key: string) -> string {
    text := text

    for line in string_split_iterator(&text, "\n")
    {
        if string_starts_with(line, key) {
            return string_trim_whitespace(line[len(key):])
        }
    }
    return ""
}

string_extract_yaml_frontmatter :: proc(text: string) -> string
{
    open := string_index(text, "---\n")
    if open >= 0 {
        body := text[open+4:]
        close := string_index(body, "---\n")
        if close >= 0
        {
            return body[:close]
        }
        return body
    }
    return text
}