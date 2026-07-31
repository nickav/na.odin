package engine

import "core:fmt"
import vmem "core:mem/virtual"
import "core:container/small_array"

KB :: 1024
MB :: 1024 * 1024
GB :: 1024 * 1024 * 1024
TB :: 1024 * 1024 * 1024 * 1024

Kilobytes :: proc(x: int) -> int { return x * 1024 }
Megabytes :: proc(x: int) -> int { return x * 1024 * 1024 }
Gigabytes :: proc(x: int) -> int { return x * 1024 * 1024 * 1024 }
Terabytes :: proc(x: int) -> int { return x * 1024 * 1024 * 1024 * 1024 }

Dump :: proc(args: ..any) {
    for x in args {
        print(x)
        print(" ")
    }
    print("\n")
}

print :: fmt.println

sprint :: fmt.tprintf

Arena :: vmem.Arena

arena_create :: proc() -> ^Arena {
    arena, err := vmem.arena_growing_bootstrap_new_by_offset(Arena, size_of(Arena))
    ensure(err == nil)
    return arena
}
