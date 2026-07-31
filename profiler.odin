package engine

import "base:runtime"
import "base:intrinsics"
import "core:time"
import "core:fmt"

PROFILER :: #config(PROFILER, ODIN_DEBUG)

when PROFILER {

read_os_timer :: proc() -> f64 {
    return f64(time.now()._nsec) / 1e9
}

read_cpu_timer :: proc() -> u64 {
    return u64(intrinsics.read_cycle_counter())
}

Profile_Anchor :: struct {
    tsc_elapsed_exclusive: u64,
    tsc_elapsed_inclusive: u64,
    hit_count:             u64,
    label:                 string,
}

Timing_f64 :: struct {
    sum:   f64,
    count: u64,
    min:   f64,
    max:   f64,
}

Profile_Frame :: struct {
    frame_count:           u64,
    frame_index:           u64,
    total_hit_count:       u64,
    label:                 string,
    tsc_elapsed_exclusive: Timing_f64,
    tsc_elapsed_inclusive: Timing_f64,
}

Profile_Block :: struct {
    label:                    string,
    file:                     string,
    line_start:               int,
    line_end:                 int,
    old_tsc_elapsed_inclusive: u64,
    start_tsc:                u64,
    anchor_index:             u32,
    parent_index:             u32,
    hash:                     u64,
}

Profiler :: struct {
    blocks:  [4096]Profile_Block,
    anchors: [4096]Profile_Anchor,
    frames:  [4096]Profile_Frame,

    block_stack:     [1024]u32,
    block_stack_pos: i64,

    start_tsc:       u64,
    end_tsc:         u64,
    start_frame_tsc: u64,
    end_frame_tsc:   u64,

    cpu_freq:    u64,
    count:       u64,
    frame_index: u64,
    parent:      u32,
}

@(private)
g_profiler: Profiler

timing_add_value :: proc(t: ^Timing_f64, v: f64) {
    t.sum   += v
    t.count += 1
    if t.count == 1 {
        t.min = v
        t.max = v
    } else {
        if v < t.min { t.min = v }
        if v > t.max { t.max = v }
    }
}

@(private)
profiler_hash :: proc(label: string, file: string) -> u64 {
    result: u64 = 5381
    for c in label { result = ((result << 5) + result) + u64(c) }
    for c in file  { result = ((result << 5) + result) + u64(c) }
    return result
}

@(private)
profiler_find_block :: proc(label: string, file: string) -> ^Profile_Block {
    hash := profiler_hash(label, file)
    index := int(hash % len(g_profiler.blocks))
    for g_profiler.blocks[index].hash != 0 && g_profiler.blocks[index].hash != hash {
        index  = (index + 1) % len(g_profiler.blocks)
    }
    it := &g_profiler.blocks[index]
    it.hash         = hash
    it.label        = label
    it.file         = file
    it.anchor_index = u32(index)
    return it
}

profiler__begin_block :: proc(label: string, file: string, line: int) {
    it := profiler_find_block(label, file)
    it.line_start = line
    it.parent_index = g_profiler.parent

    anchor := &g_profiler.anchors[it.anchor_index]
    it.old_tsc_elapsed_inclusive = anchor.tsc_elapsed_inclusive

    if u64(it.anchor_index) > g_profiler.count { g_profiler.count = u64(it.anchor_index) }

    g_profiler.parent = it.anchor_index

    assert(g_profiler.block_stack_pos < i64(len(g_profiler.block_stack)))
    g_profiler.block_stack[g_profiler.block_stack_pos] = it.anchor_index
    g_profiler.block_stack_pos += 1

    it.start_tsc = read_cpu_timer()
}

profiler__end_block :: proc(label: string, file: string, line: int) {
    end_tsc := read_cpu_timer()

    g_profiler.block_stack_pos -= 1
    assert(g_profiler.block_stack_pos >= 0)
    prev_block_index := g_profiler.block_stack[g_profiler.block_stack_pos]

    it: ^Profile_Block
    if label != "" {
        it = profiler_find_block(label, file)
        assert(it.anchor_index == prev_block_index)
    } else {
        it = &g_profiler.blocks[prev_block_index]
    }
    it.line_end = line

    elapsed := end_tsc - it.start_tsc
    g_profiler.parent = it.parent_index

    parent := &g_profiler.anchors[it.parent_index]
    anchor := &g_profiler.anchors[it.anchor_index]

    parent.tsc_elapsed_exclusive -= elapsed
    anchor.tsc_elapsed_exclusive += elapsed
    anchor.tsc_elapsed_inclusive  = it.old_tsc_elapsed_inclusive + elapsed
    anchor.hit_count             += 1
    anchor.label                  = label
}

profiler__estimate_clocks_per_second :: proc() -> u64 {
    estimate_time: f64 = 0.05
    cpu_start := read_cpu_timer()
    now := read_os_timer()
    then := now + estimate_time
    for now < then { now = read_os_timer() }
    cpu_end := read_cpu_timer()
    return u64(f64(cpu_end - cpu_start) / estimate_time)
}

profiler_init :: proc() {
    @(static) initted: bool
    if !initted {
        g_profiler.cpu_freq = profiler__estimate_clocks_per_second()
        initted = true
    }
}

profiler_begin :: proc() {
    profiler_init()
    g_profiler.start_tsc = read_cpu_timer()
}

profiler_end :: proc() {
    g_profiler.end_tsc = read_cpu_timer()
}

profiler_begin_frame :: proc() {
    profiler_init()
    g_profiler.start_frame_tsc = read_cpu_timer()
    g_profiler.count           = 0
    g_profiler.frame_index    += 1
    g_profiler.end_frame_tsc   = 0
    g_profiler.anchors          = {}
}

profiler_end_frame :: proc() {
    if g_profiler.end_frame_tsc != 0 { return }
    g_profiler.end_frame_tsc = read_cpu_timer()

    for index in 0..<len(g_profiler.anchors) {
        anchor := &g_profiler.anchors[index]
        if anchor.tsc_elapsed_inclusive == 0 { continue }

        frame := &g_profiler.frames[index]
        frame.frame_count     += 1
        frame.total_hit_count += anchor.hit_count
        frame.frame_index      = g_profiler.frame_index
        frame.label            = anchor.label

        timing_add_value(&frame.tsc_elapsed_exclusive, f64(anchor.tsc_elapsed_exclusive))
        timing_add_value(&frame.tsc_elapsed_inclusive, f64(anchor.tsc_elapsed_inclusive))
    }
}

profiler__seconds_from_clocks :: proc(clocks: u64) -> f64 {
    if g_profiler.cpu_freq == 0 { return 0 }
    return f64(clocks) / f64(g_profiler.cpu_freq)
}

profiler__percent_from_clocks :: proc(clocks: u64, total: u64) -> f64 {
    if total == 0 { return 0 }
    return 100.0 * (f64(clocks) / f64(total))
}

profiler__get_total_clocks_elapsed :: proc() -> u64 {
    if g_profiler.end_tsc >= g_profiler.start_tsc {
        return g_profiler.end_tsc - g_profiler.start_tsc
    }
    return 0
}

profiler__get_frame_clocks_elapsed :: proc() -> u64 {
    if g_profiler.end_frame_tsc >= g_profiler.start_frame_tsc {
        return g_profiler.end_frame_tsc - g_profiler.start_frame_tsc
    }
    return 0
}

profiler__get_total_seconds_elapsed :: proc() -> f64 {
    if g_profiler.end_tsc >= g_profiler.start_tsc {
        return profiler__seconds_from_clocks(g_profiler.end_tsc - g_profiler.start_tsc)
    }
    return 0
}

profiler__get_frame_seconds_elapsed :: proc() -> f64 {
    if g_profiler.end_frame_tsc >= g_profiler.start_frame_tsc {
        return profiler__seconds_from_clocks(g_profiler.end_frame_tsc - g_profiler.start_frame_tsc)
    }
    return 0
}

profiler__print_time_elapsed :: proc(anchor: ^Profile_Anchor, total_tsc: u64) {
    pct    := profiler__percent_from_clocks(anchor.tsc_elapsed_exclusive, total_tsc)
    time_ms := 1000.0 * profiler__seconds_from_clocks(anchor.tsc_elapsed_exclusive)
    fmt.printf("    %s[%v]: %v (%.2f%%|%.2fms", anchor.label, anchor.hit_count, anchor.tsc_elapsed_exclusive, pct, time_ms)
    if anchor.tsc_elapsed_inclusive != anchor.tsc_elapsed_exclusive {
        pct2 := profiler__percent_from_clocks(anchor.tsc_elapsed_inclusive, total_tsc)
        ms2  := 1000.0 * profiler__seconds_from_clocks(anchor.tsc_elapsed_inclusive)
        fmt.printf(", %.2f%%|%.2fms w/children", pct2, ms2)
    }
    fmt.printf(")\n")
}

profiler_print :: proc() {
    cpu_freq         := g_profiler.cpu_freq
    total_cpu_elapsed := g_profiler.end_tsc - g_profiler.start_tsc

    if cpu_freq != 0 {
        fmt.printf("[profiler] Total time: %.4fms (CPU time: %v)\n", 1000.0 * f64(total_cpu_elapsed) / f64(cpu_freq), total_cpu_elapsed)
        fmt.printf("[profiler] CPU freq: %v\n", cpu_freq)
    }

    for index in 0..<len(g_profiler.anchors) {
        anchor := &g_profiler.anchors[index]
        if anchor.tsc_elapsed_inclusive != 0 {
            profiler__print_time_elapsed(anchor, total_cpu_elapsed)
        }
    }
}

profiler__add_custom_timing :: proc(label: string, file: string, line: int, elapsed: u64) {
    it := profiler_find_block(label, file)
    anchor := &g_profiler.anchors[it.anchor_index]
    if u64(it.anchor_index) > g_profiler.count { g_profiler.count = u64(it.anchor_index) }

    it.line_start = line
    it.line_end   = line
    it.start_tsc  = 0

    anchor.tsc_elapsed_exclusive += elapsed
    anchor.tsc_elapsed_inclusive  = elapsed
    anchor.hit_count             += 1
    anchor.label                  = label
}

TimeBegin :: proc(label: string, file: string = #file, line: int = #line) {
    profiler__begin_block(label, file, line)
}

TimeEnd :: proc(label: string, file: string = #file, line: int = #line) {
    profiler__end_block(label, file, line)
}

//
// Usage: TimeBlock("my_block")
//
@(deferred_in=profiler__end_block)
TimeBlock :: proc(label: string, file: string = #file, line: int = #line) {
    profiler__begin_block(label, file, line)
}

//
// Usage: TimeFunction()
//
@(deferred_in=profiler__end_function_block)
TimeFunction :: proc(loc := #caller_location) {
    profiler__begin_block(loc.procedure, loc.file_path, int(loc.line))
}

profiler__end_function_block :: proc(loc: runtime.Source_Code_Location) {
    profiler__end_block(loc.procedure, loc.file_path, int(loc.line))
}


} else {

TimeBegin :: proc(label: string, file: string = #file, line: int = #line) {
}

TimeEnd :: proc(label: string, file: string = #file, line: int = #line) {
}

TimeBlock :: proc(label: string, file: string = #file, line: int = #line) {
}

TimeFunction :: proc(loc := #caller_location) {
}

} // when PROFILER
