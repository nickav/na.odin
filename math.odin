package main

import "core:math"
import la "core:math/linalg"

PI     :: math.PI
TAU    :: math.TAU
SQRT_2 :: f32(0.70710678118)

EPSILON_F32 :: f32(1.1920929e-7)
EPSILON_F64 :: f64(2.220446e-16)

//
// Types
//

Vector2  :: [2]f32
Vector3  :: [3]f32
Vector4  :: [4]f32

Vector2i :: [2]i32
Vector3i :: [3]i32
Vector4i :: [4]i32

Rectangle2 :: struct { p0, p1: Vector2 }
Rectangle2i :: struct { p0, p1: Vector2i }
Rectangle3  :: struct { p0, p1: Vector3 }

// NOTE: la.Matrix4f32 is column-major; indexing is m[col, row]
Matrix3    :: la.Matrix3f32
Matrix4    :: la.Matrix4f32
Quaternion :: quaternion128

//
// Constants
//

v2_zero         :: Vector2{0, 0}
v2_one          :: Vector2{1, 1}
v2_half         :: Vector2{0.5, 0.5}
v2_center       :: Vector2{0.5, 0.5}
v2_top_left     :: Vector2{0, 0}
v2_bottom_left  :: Vector2{0, 1}
v2_center_left  :: Vector2{0, 0.5}
v2_top_right    :: Vector2{1, 0}
v2_bottom_right :: Vector2{1, 1}
v2_center_right :: Vector2{1, 0.5}

v3_zero   :: Vector3{0, 0, 0}
v3_one    :: Vector3{1, 1, 1}
v3_half   :: Vector3{0.5, 0.5, 0.5}
v3_center :: Vector3{0.5, 0.5, 0.5}

v4_zero    :: Vector4{0, 0, 0, 0}
v4_one     :: Vector4{1, 1, 1, 1}
v4_half    :: Vector4{0.5, 0.5, 0.5, 0.5}
v4_center  :: Vector4{0.5, 0.5, 0.5, 0.5}
v4_black   :: Vector4{0, 0, 0, 1}
v4_white   :: Vector4{1, 1, 1, 1}
v4_red     :: Vector4{1, 0, 0, 1}
v4_green   :: Vector4{0, 1, 0, 1}
v4_blue    :: Vector4{0, 0, 1, 1}
v4_cyan    :: Vector4{0, 1, 1, 1}
v4_magenta :: Vector4{1, 0, 1, 1}
v4_yellow  :: Vector4{1, 1, 0, 1}

r2_zero :: Rectangle2{}

//
// Constructors
//

v2 :: #force_inline proc "contextless" (x, y: f32) -> Vector2  { return {x, y} }

v3 :: #force_inline proc "contextless" (x, y, z: f32) -> Vector3 { return {x, y, z} }

v4 :: #force_inline proc "contextless" (x, y, z, w: f32) -> Vector4 { return {x, y, z, w} }

v2i :: #force_inline proc "contextless" (x, y: i32) -> Vector2i { return {x, y} }

v2if :: #force_inline proc "contextless" (x, y: f32) -> Vector2i { return {i32(x), i32(y)} }

v3i :: #force_inline proc "contextless" (x, y, z: i32) -> Vector3i { return {x, y, z} }

v4i :: #force_inline proc "contextless" (x, y, z, w: i32) -> Vector4i { return {x, y, z, w} }

v2_from_v2i :: #force_inline proc "contextless" (v: Vector2i) -> Vector2 { return {f32(v.x), f32(v.y)} }

v3_from_v3i :: #force_inline proc "contextless" (v: Vector3i) -> Vector3 { return {f32(v.x), f32(v.y), f32(v.z)} }
v3_from_v2f :: #force_inline proc "contextless" (xy: Vector2, z: f32) -> Vector3 { return {xy.x, xy.y, z} }

v4_from_v2  :: #force_inline proc "contextless" (a, b: Vector2) -> Vector4 { return {a.x, a.y, b.x, b.y} }
v4_from_v3f :: #force_inline proc "contextless" (v: Vector3, w: f32) -> Vector4 { return {v.x, v.y, v.z, w} }
v4_from_v4f :: #force_inline proc "contextless" (v: Vector4, w: f32) -> Vector4 { return {v.x, v.y, v.z, w} }

v2i_from_v2 :: #force_inline proc "contextless" (v: Vector2) -> Vector2i { return {i32(v.x), i32(v.y)} }

v3i_from_v3 :: #force_inline proc "contextless" (v: Vector3) -> Vector3i { return {i32(v.x), i32(v.y), i32(v.z)} }

v4_rgba :: #force_inline proc "contextless" (r, g, b, a: f32) -> Vector4 {
    return {clamp(r, 0, 255)/255, clamp(g, 0, 255)/255, clamp(b, 0, 255)/255, clamp(a, 0, 1)}
}

v4_rgb :: #force_inline proc "contextless" (r, g, b: f32) -> Vector4 {
    return v4_rgba(r, g, b, 1)
}

//
// Basic math
//

clamp :: math.clamp
floor :: math.floor
ceil :: math.ceil
round :: math.round

sin :: math.sin
cos :: math.cos
tan :: math.tan
atan2 :: math.atan2

abs :: math.abs
sqrt :: math.sqrt
mod :: math.mod
pow :: math.pow

lerp :: math.lerp

min_f32   :: #force_inline proc "contextless" (a, b: f32) -> f32 { return min(a, b) }
max_f32   :: #force_inline proc "contextless" (a, b: f32) -> f32 { return max(a, b) }

floor_i32 :: #force_inline proc "contextless" (x: f32) -> i32 { return i32(floor(x)) }
floor_f32 :: #force_inline proc "contextless" (x: f32) -> f32 { return floor(x) }

sign_i32 :: #force_inline proc "contextless" (x: i32) -> i32 { return i32(int(x > 0) - int(x < 0)) }
sign_f32 :: #force_inline proc "contextless" (x: f32) -> f32 { return f32(int(x > 0) - int(x < 0)) }
sign_f64 :: #force_inline proc "contextless" (x: f64) -> f64 { return f64(int(x > 0) - int(x < 0)) }

clamp_f32 :: #force_inline proc "contextless" (a, b, t: f32) -> f32 { return clamp(a, b, t) }

clamp_01_f32 :: #force_inline proc "contextless" (x: f32) -> f32 { return clamp(x, f32(0), f32(1)) }
clamp_01_f64 :: #force_inline proc "contextless" (x: f64) -> f64 { return clamp(x, f64(0), f64(1)) }

wrap_f32 :: proc "contextless" (value, lower, upper: f32) -> f32 {
    v, r := value, upper - lower
    for v > upper do v -= r
    for v < lower do v += r
    return v
}

f32_is_zero :: #force_inline proc "contextless" (x: f32) -> bool { return abs(x) <= EPSILON_F32 }

degrees_to_radians :: #force_inline proc "contextless" (deg: f32) -> f32 { return math.to_radians(deg) }

radians_to_degrees :: #force_inline proc "contextless" (rad: f32) -> f32 { return math.to_degrees(rad) }

lerp_f32 :: #force_inline proc "contextless" (a, b, t: f32) -> f32 { return lerp(a, b, t) }
lerp_v2 :: #force_inline proc "contextless" (a, b: Vector2, t: f32) -> Vector2 { return a + (b - a)*t }
lerp_v3 :: #force_inline proc "contextless" (a, b: Vector3, t: f32) -> Vector3 { return a + (b - a)*t }
lerp_v4 :: #force_inline proc "contextless" (a, b: Vector4, t: f32) -> Vector4 { return a + (b - a)*t }

unlerp_f32 :: #force_inline proc "contextless" (a, b, v: f32) -> f32 { return (v - a) / (b - a) }

remap_f32  :: #force_inline proc "contextless" (in_min, in_max, out_min, out_max, v: f32) -> f32 {
    return lerp(out_min, out_max, unlerp_f32(in_min, in_max, v))
}

move_f32 :: #force_inline proc "contextless" (a, b, amount: f32) -> f32 {
    return max(a - amount, b) if a > b else min(a + amount, b)
}

approach_f32 :: #force_inline proc "contextless" (a, b, inc, dec: f32) -> f32 {
    return max(a - dec, b) if a > b else min(a + inc, b)
}

snap_f32 :: #force_inline proc "contextless" (value, grid: f32) -> f32 {
    return round(value / grid) * grid
}

angle_between :: #force_inline proc "contextless" (p0, p1: Vector2) -> f32 {
    return atan2(p1.y - p0.y, p1.x - p0.x)
}

direction_v2 :: #force_inline proc "contextless" (p: Vector2) -> f32 {
    return -atan2(-p.y, p.x)
}

//
// Vector2
//

v2_equals :: #force_inline proc "contextless" (a, b: Vector2) -> bool {
    return abs(a.x - b.x) <= EPSILON_F32 && abs(a.y - b.y) <= EPSILON_F32
}

v2_is_zero :: #force_inline proc "contextless" (a: Vector2) -> bool { return v2_equals(a, v2_zero) }

v2_dot :: #force_inline proc "contextless" (a, b: Vector2) -> f32 { return a.x*b.x + a.y*b.y }

v2_perp :: #force_inline proc "contextless" (a: Vector2) -> Vector2 { return {-a.y, a.x} }

v2_length_squared :: #force_inline proc "contextless" (a: Vector2) -> f32 { return v2_dot(a, a) }

v2_length :: #force_inline proc "contextless" (a: Vector2) -> f32 { return sqrt(v2_length_squared(a)) }

v2_distance_squared :: #force_inline proc "contextless" (a, b: Vector2) -> f32 { return v2_length_squared(a - b) }

v2_distance :: #force_inline proc "contextless" (a, b: Vector2) -> f32 { return v2_length(a - b) }

v2_normalize :: proc "contextless" (a: Vector2) -> Vector2 {
    l := v2_length(a)
    if l == 0 do return {}
    return a * (1.0 / l)
}

v2_arm :: #force_inline proc "contextless" (angle: f32) -> Vector2 {
    return {cos(angle), sin(angle)}
}

v2_triangle_area :: #force_inline proc "contextless" (a, b, c: Vector2) -> f32 {
    return ((c.x - a.x)*(b.y - a.y) - (b.x - a.x)*(c.y - a.y)) * 0.5
}

floor_v2 :: #force_inline proc "contextless" (a: Vector2) -> Vector2 { return {floor(a.x), floor(a.y)} }

round_v2 :: #force_inline proc "contextless" (a: Vector2) -> Vector2 { return {round(a.x), round(a.y)} }

ceil_v2  :: #force_inline proc "contextless" (a: Vector2) -> Vector2 { return {ceil(a.x),  ceil(a.y)} }

abs_v2   :: #force_inline proc "contextless" (a: Vector2) -> Vector2 { return {abs(a.x), abs(a.y)} }

sign_v2  :: #force_inline proc "contextless" (a: Vector2) -> Vector2 { return {sign_f32(a.x), sign_f32(a.y)} }

min_v2   :: #force_inline proc "contextless" (a, b: Vector2) -> Vector2 { return {min(a.x, b.x), min(a.y, b.y)} }

max_v2   :: #force_inline proc "contextless" (a, b: Vector2) -> Vector2 { return {max(a.x, b.x), max(a.y, b.y)} }

clamp_v2 :: #force_inline proc "contextless" (a, lo, hi: Vector2) -> Vector2 {
    return {clamp(a.x, lo.x, hi.x), clamp(a.y, lo.y, hi.y)}
}

move_v2 :: #force_inline proc "contextless" (a, b: Vector2, amount: f32) -> Vector2 {
    return {move_f32(a.x, b.x, amount), move_f32(a.y, b.y, amount)}
}

approach_v2 :: #force_inline proc "contextless" (a, b: Vector2, inc, dec: f32) -> Vector2 {
    return {approach_f32(a.x, b.x, inc, dec), approach_f32(a.y, b.y, inc, dec)}
}

snap_v2 :: #force_inline proc "contextless" (pos, grid: Vector2) -> Vector2 {
    return {snap_f32(pos.x, grid.x), snap_f32(pos.y, grid.y)}
}

//
// Vector3
//

v3_equals :: #force_inline proc "contextless" (a, b: Vector3) -> bool {
    return abs(a.x-b.x) <= EPSILON_F32 && abs(a.y-b.y) <= EPSILON_F32 && abs(a.z-b.z) <= EPSILON_F32
}

v3_is_zero :: #force_inline proc "contextless" (a: Vector3) -> bool { return v3_equals(a, v3_zero) }

v3_dot :: #force_inline proc "contextless" (a, b: Vector3) -> f32 { return a.x*b.x + a.y*b.y + a.z*b.z }

v3_length_squared :: #force_inline proc "contextless" (a: Vector3) -> f32 {
    return v3_dot(a, a)
}

v3_length :: #force_inline proc "contextless" (a: Vector3) -> f32 {
    return sqrt(v3_length_squared(a))
}

v3_distance_squared :: #force_inline proc "contextless" (a, b: Vector3) -> f32 {
    return v3_length_squared(a - b)
}

v3_distance :: #force_inline proc "contextless" (a, b: Vector3) -> f32 { return v3_length(a - b) }

v3_normalize :: proc "contextless" (a: Vector3) -> Vector3 {
    l := v3_length(a)
    if l == 0 do return {}
    return a * (1.0 / l)
}
v3_cross :: #force_inline proc "contextless" (a, b: Vector3) -> Vector3 {
    return {a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x}
}

floor_v3 :: #force_inline proc "contextless" (a: Vector3) -> Vector3 { return {floor(a.x), floor(a.y), floor(a.z)} }
round_v3 :: #force_inline proc "contextless" (a: Vector3) -> Vector3 { return {round(a.x), round(a.y), round(a.z)} }
ceil_v3  :: #force_inline proc "contextless" (a: Vector3) -> Vector3 { return {ceil(a.x),  ceil(a.y),  ceil(a.z)} }
abs_v3   :: #force_inline proc "contextless" (a: Vector3) -> Vector3 { return {abs(a.x), abs(a.y), abs(a.z)} }
sign_v3  :: #force_inline proc "contextless" (a: Vector3) -> Vector3 { return {sign_f32(a.x), sign_f32(a.y), sign_f32(a.z)} }
min_v3   :: #force_inline proc "contextless" (a, b: Vector3) -> Vector3 { return {min(a.x,b.x), min(a.y,b.y), min(a.z,b.z)} }
max_v3   :: #force_inline proc "contextless" (a, b: Vector3) -> Vector3 { return {max(a.x,b.x), max(a.y,b.y), max(a.z,b.z)} }
clamp_v3 :: #force_inline proc "contextless" (a, lo, hi: Vector3) -> Vector3 {
    return {clamp(a.x,lo.x,hi.x), clamp(a.y,lo.y,hi.y), clamp(a.z,lo.z,hi.z)}
}

//
// Vector4
//

v4_equals :: #force_inline proc "contextless" (a, b: Vector4) -> bool {
    return abs(a.x-b.x) <= EPSILON_F32 && abs(a.y-b.y) <= EPSILON_F32 &&
           abs(a.z-b.z) <= EPSILON_F32 && abs(a.w-b.w) <= EPSILON_F32
}
v4_is_zero :: #force_inline proc "contextless" (a: Vector4) -> bool { return v4_equals(a, v4_zero) }

v4_dot            :: #force_inline proc "contextless" (a, b: Vector4) -> f32 { return a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w }
v4_length_squared :: #force_inline proc "contextless" (a: Vector4) -> f32 { return v4_dot(a, a) }
v4_length         :: #force_inline proc "contextless" (a: Vector4) -> f32 { return sqrt(v4_length_squared(a)) }

v4_normalize :: proc "contextless" (a: Vector4) -> Vector4 {
    l := v4_length(a)
    if l == 0 do return {}
    return a * (1.0 / l)
}

floor_v4 :: #force_inline proc "contextless" (a: Vector4) -> Vector4 { return {floor(a.x), floor(a.y), floor(a.z), floor(a.w)} }
round_v4 :: #force_inline proc "contextless" (a: Vector4) -> Vector4 { return {round(a.x), round(a.y), round(a.z), round(a.w)} }
ceil_v4  :: #force_inline proc "contextless" (a: Vector4) -> Vector4 { return {ceil(a.x),  ceil(a.y),  ceil(a.z),  ceil(a.w)} }
abs_v4   :: #force_inline proc "contextless" (a: Vector4) -> Vector4 { return {abs(a.x), abs(a.y), abs(a.z), abs(a.w)} }
sign_v4  :: #force_inline proc "contextless" (a: Vector4) -> Vector4 { return {sign_f32(a.x), sign_f32(a.y), sign_f32(a.z), sign_f32(a.w)} }
min_v4   :: #force_inline proc "contextless" (a, b: Vector4) -> Vector4 { return {min(a.x,b.x), min(a.y,b.y), min(a.z,b.z), min(a.w,b.w)} }
max_v4   :: #force_inline proc "contextless" (a, b: Vector4) -> Vector4 { return {max(a.x,b.x), max(a.y,b.y), max(a.z,b.z), max(a.w,b.w)} }
clamp_v4 :: #force_inline proc "contextless" (a, lo, hi: Vector4) -> Vector4 {
    return {clamp(a.x,lo.x,hi.x), clamp(a.y,lo.y,hi.y), clamp(a.z,lo.z,hi.z), clamp(a.w,lo.w,hi.w)}
}

//
// Rectangle2
//

r2 :: #force_inline proc "contextless" (x0, y0, x1, y1: f32) -> Rectangle2 {
    return {p0 = {x0, y0}, p1 = {x1, y1}}
}
r2_from_v2  :: #force_inline proc "contextless" (p0, p1: Vector2) -> Rectangle2 { return {p0, p1} }
r2_from_v4  :: #force_inline proc "contextless" (v: Vector4) -> Rectangle2 { return {{v.x, v.y}, {v.z, v.w}} }
r2_from_r2i :: #force_inline proc "contextless" (r: Rectangle2i) -> Rectangle2 {
    return {{f32(r.p0.x), f32(r.p0.y)}, {f32(r.p1.x), f32(r.p1.y)}}
}

r2_from_size  :: #force_inline proc "contextless" (size: Vector2) -> Rectangle2 { return {{0,0}, size} }

r2_width        :: #force_inline proc "contextless" (r: Rectangle2) -> f32 { return r.p1.x - r.p0.x }
r2_height       :: #force_inline proc "contextless" (r: Rectangle2) -> f32 { return r.p1.y - r.p0.y }
r2_size         :: #force_inline proc "contextless" (r: Rectangle2) -> Vector2 { return r.p1 - r.p0 }
r2_aspect_ratio :: #force_inline proc "contextless" (r: Rectangle2) -> f32 { s := r2_size(r); return s.x / s.y }
r2_center       :: #force_inline proc "contextless" (r: Rectangle2) -> Vector2 { return (r.p0 + r.p1) * 0.5 }
r2_top_left     :: #force_inline proc "contextless" (r: Rectangle2) -> Vector2 { return r.p0 }
r2_top_right    :: #force_inline proc "contextless" (r: Rectangle2) -> Vector2 { return {r.p1.x, r.p1.y} } // matches C (has a bug, bottom-right)
r2_bottom_left  :: #force_inline proc "contextless" (r: Rectangle2) -> Vector2 { return {r.p0.x, r.p1.y} }
r2_bottom_right :: #force_inline proc "contextless" (r: Rectangle2) -> Vector2 { return r.p1 }
r2_center_right :: #force_inline proc "contextless" (r: Rectangle2) -> Vector2 { return {r.p1.x, (r.p0.y + r.p1.y) * 0.5} }
r2_center_left  :: #force_inline proc "contextless" (r: Rectangle2) -> Vector2 { return {r.p0.x, (r.p0.y + r.p1.y) * 0.5} }

r2_intersects :: #force_inline proc "contextless" (a, b: Rectangle2) -> bool {
    return a.p0.x < b.p1.x && a.p1.x > b.p0.x && a.p0.y < b.p1.y && a.p1.y > b.p0.y
}
r2_contains :: #force_inline proc "contextless" (r: Rectangle2, p: Vector2) -> bool {
    return p.x >= r.p0.x && p.x < r.p1.x && p.y >= r.p0.y && p.y < r.p1.y
}
r2_equals :: #force_inline proc "contextless" (a, b: Rectangle2) -> bool {
    return a.p0 == b.p0 && a.p1 == b.p1
}

r2_scale_to_fit :: #force_inline proc "contextless" (r01, dest: Rectangle2) -> Rectangle2 {
    s := r2_size(dest)
    return {dest.p0 + r01.p0 * s, dest.p0 + r01.p1 * s}
}

r2_split_from_bottom :: #force_inline proc "contextless" (r: Rectangle2, amount: f32) -> Rectangle2 { return {{r.p0.x, r.p1.y - amount}, r.p1} }
r2_split_from_top    :: #force_inline proc "contextless" (r: Rectangle2, amount: f32) -> Rectangle2 { return {r.p0, {r.p1.x, r.p0.y + amount}} }
r2_split_from_left   :: #force_inline proc "contextless" (r: Rectangle2, amount: f32) -> Rectangle2 { return {r.p0, {r.p0.x + amount, r.p1.y}} }
r2_split_from_right  :: #force_inline proc "contextless" (r: Rectangle2, amount: f32) -> Rectangle2 { return {{r.p1.x - amount, r.p0.y}, r.p1} }
r2_trim_from_top     :: #force_inline proc "contextless" (r: Rectangle2, amount: f32) -> Rectangle2 { return {{r.p0.x, r.p0.y + amount}, r.p1} }
r2_trim_from_left    :: #force_inline proc "contextless" (r: Rectangle2, amount: f32) -> Rectangle2 { return {{r.p0.x + amount, r.p0.y}, r.p1} }

abs_r2 :: #force_inline proc "contextless" (r: Rectangle2) -> Rectangle2 {
    return {{min(r.p0.x, r.p1.x), min(r.p0.y, r.p1.y)}, {max(r.p0.x, r.p1.x), max(r.p0.y, r.p1.y)}}
}
r2_union :: #force_inline proc "contextless" (a, b: Rectangle2) -> Rectangle2 {
    a, b := abs_r2(a), abs_r2(b)
    return {{min(a.p0.x, b.p0.x), min(a.p0.y, b.p0.y)}, {max(a.p1.x, b.p1.x), max(a.p1.y, b.p1.y)}}
}
r2_intersection :: #force_inline proc "contextless" (a, b: Rectangle2) -> Rectangle2 {
    a, b := abs_r2(a), abs_r2(b)
    return {{max(a.p0.x, b.p0.x), max(a.p0.y, b.p0.y)}, {min(a.p1.x, b.p1.x), min(a.p1.y, b.p1.y)}}
}
r2_clip :: proc "contextless" (a, b: Rectangle2) -> Rectangle2 {
    if a.p0 == (Vector2{}) && a.p1 == (Vector2{}) do return b
    return r2_intersection(a, b)
}
r2_shift       :: #force_inline proc "contextless" (r: Rectangle2, v: Vector2) -> Rectangle2 { return {r.p0 + v, r.p1 + v} }
r2_pad         :: #force_inline proc "contextless" (r: Rectangle2, p: Vector2) -> Rectangle2 { return {r.p0 - p, r.p1 + p} }
r2f_pad        :: #force_inline proc "contextless" (r: Rectangle2, p: f32) -> Rectangle2 { return r2_pad(r, {p, p}) }
r2_pad_inner_v2 :: #force_inline proc "contextless" (r: Rectangle2, p: Vector2) -> Rectangle2 { return {r.p0 + p, r.p1 - p} }
r2_pad_inner_v4 :: #force_inline proc "contextless" (r: Rectangle2, p: Vector4) -> Rectangle2 {
    return {{r.p0.x + p.x, r.p0.y + p.y}, {r.p1.x - p.z, r.p1.y - p.w}}
}
r2_pad_outer_v4 :: #force_inline proc "contextless" (r: Rectangle2, p: Vector4) -> Rectangle2 {
    return {{r.p0.x - p.x, r.p0.y - p.y}, {r.p1.x + p.z, r.p1.y + p.w}}
}
r2_bounds :: #force_inline proc "contextless" (pos, size, anchor, scale: Vector2) -> Rectangle2 {
    ss := size * scale
    p0 := pos - anchor * ss
    return abs_r2({p0, p0 + ss})
}

//
// Rectangle2i
//

r2i        :: #force_inline proc "contextless" (x0, y0, x1, y1: i32) -> Rectangle2i { return {{x0,y0},{x1,y1}} }
r2i_size   :: #force_inline proc "contextless" (r: Rectangle2i) -> Vector2i { return r.p1 - r.p0 }
r2i_width  :: #force_inline proc "contextless" (r: Rectangle2i) -> i32 { return r.p1.x - r.p0.x }
r2i_height :: #force_inline proc "contextless" (r: Rectangle2i) -> i32 { return r.p1.y - r.p0.y }

aspect_ratio_fit :: proc "contextless" (src_w, src_h, dst_w, dst_h: u32) -> Rectangle2i {
    r := Rectangle2i{}

    if src_w == 0 || src_h == 0 || dst_w == 0 || dst_h == 0 do return {}
    opt_w := f32(dst_h) * f32(src_w) / f32(src_h)
    opt_h := f32(dst_w) * f32(src_h) / f32(src_w)

    if opt_w > f32(dst_w)
    {
        r.p0.x = 0; r.p1.x = i32(dst_w)
        he := i32(round(0.5 * (f32(dst_h) - opt_h)))
        r.p0.y = he; r.p1.y = he + i32(round(opt_h))
    }
    else
    {
        r.p0.y = 0; r.p1.y = i32(dst_h)
        he := i32(round(0.5 * (f32(dst_w) - opt_w)))
        r.p0.x = he; r.p1.x = he + i32(round(opt_w))
    }

    return r
}

aspect_ratio_fit_pixel_perfect :: proc "contextless" (src_w, src_h, dst_w, dst_h: u32) -> Rectangle2i {
    if src_w == 0 || src_h == 0 || dst_w == 0 || dst_h == 0 do return {}

    scale := min(dst_w / src_w, dst_h / src_h)
    sw, sh := i32(scale * src_w), i32(scale * src_h)
    cx, cy := (i32(dst_w) - sw) / 2, (i32(dst_h) - sh) / 2

    return {{cx, cy}, {cx + sw, cy + sh}}
}

aspect_ratio_fill :: proc "contextless" (src_w, src_h, dst_w, dst_h: u32) -> Rectangle2i {
    r := Rectangle2i{}

    if src_w == 0 || src_h == 0 || dst_w == 0 || dst_h == 0 do return r

    opt_w := f32(dst_h) * f32(src_w) / f32(src_h)
    opt_h := f32(dst_w) * f32(src_h) / f32(src_w)

    if opt_w > f32(dst_w)
    {
        r.p0.y = 0; r.p1.y = i32(dst_h)
        ov := opt_w - f32(dst_w)
        r.p0.x = -i32(round(0.5 * ov))
        r.p1.x = i32(dst_w) + i32(round(0.5 * ov))
    }
    else
    {
        r.p0.x = 0; r.p1.x = i32(dst_w)
        ov := opt_h - f32(dst_h)
        r.p0.y = -i32(round(0.5 * ov))
        r.p1.y = i32(dst_h) + i32(round(0.5 * ov))
    }

    return r
}

aspect_ratio_fill_pixel_perfect :: proc "contextless" (src_w, src_h, dst_w, dst_h: u32) -> Rectangle2i {
    if src_w == 0 || src_h == 0 || dst_w == 0 || dst_h == 0 do return {}
    scale := max(
        i32(ceil(f32(dst_w) / f32(src_w))),
        i32(ceil(f32(dst_h) / f32(src_h))),
    )
    w, h := scale * i32(src_w), scale * i32(src_h)
    cx, cy := (i32(dst_w) - w) / 2, (i32(dst_h) - h) / 2
    return {{cx, cy}, {cx + w, cy + h}}
}

//
// Rectangle3
//

r3 :: #force_inline proc "contextless" (p0, p1: Vector3) -> Rectangle3 { return {p0, p1} }

r3_size   :: #force_inline proc "contextless" (r: Rectangle3) -> Vector3 { return r.p1 - r.p0 }
r3_center :: #force_inline proc "contextless" (r: Rectangle3) -> Vector3 { return (r.p0 + r.p1) * 0.5 }

r3_intersects :: #force_inline proc "contextless" (a, b: Rectangle3) -> bool {
    return b.p1.x > a.p0.x && b.p0.x < a.p1.x &&
           b.p1.y > a.p0.y && b.p0.y < a.p1.y &&
           b.p1.z > a.p0.z && b.p0.z < a.p1.z
}
r3_contains :: #force_inline proc "contextless" (r: Rectangle3, p: Vector3) -> bool {
    return p.x >= r.p0.x && p.x <= r.p1.x &&
           p.y >= r.p0.y && p.y <= r.p1.y &&
           p.z >= r.p0.z && p.z <= r.p1.z
}

//
// Matrix4
// NOTE: Odin matrices are column-major; m[col, row]
// Literals fill column-by-column: Matrix4{c0r0,c0r1,c0r2,c0r3, c1r0,...}
//

matrix4_identity :: #force_inline proc "contextless" () -> Matrix4 {
    return la.MATRIX4F32_IDENTITY
}

matrix4_diagonal :: #force_inline proc "contextless" (d: f32) -> Matrix4 {
    return Matrix4{
        d,0,0,0,
        0,d,0,0,
        0,0,d,0,
        0,0,0,d
    }
}

// Constructs from row vectors (transposes for column-major storage)
matrix4_from_rows :: #force_inline proc "contextless" (r0, r1, r2, r3: Vector4) -> Matrix4 {
    return Matrix4{
        r0.x, r1.x, r2.x, r3.x,
        r0.y, r1.y, r2.y, r3.y,
        r0.z, r1.z, r2.z, r3.z,
        r0.w, r1.w, r2.w, r3.w,
    }
}

matrix4_translation :: #force_inline proc "contextless" (t: Vector3) -> Matrix4 {
    return Matrix4{
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        t.x,t.y,t.z,1
    }
}
matrix4_translation_2d :: #force_inline proc "contextless" (t: Vector2) -> Matrix4 {
    return matrix4_translation({t.x, t.y, 0})
}
matrix4_translate :: #force_inline proc "contextless" (a: Matrix4, t: Vector3) -> Matrix4 {
    r := a; r[3, 0] += t.x; r[3, 1] += t.y; r[3, 2] += t.z; return r
}
matrix4_translate_2d :: #force_inline proc "contextless" (a: Matrix4, t: Vector2) -> Matrix4 {
    return matrix4_translate(a, {t.x, t.y, 0})
}

matrix4_scale :: #force_inline proc "contextless" (s: Vector3) -> Matrix4 {
    return Matrix4{
        s.x,0,0,0,
        0,s.y,0,0,
        0,0,s.z,0,
        0,0,0,1
    }
}
matrix4_scale_2d      :: #force_inline proc "contextless" (s: Vector2) -> Matrix4 { return matrix4_scale({s.x, s.y, 1}) }
matrix4_scale_uniform :: #force_inline proc "contextless" (s: f32)     -> Matrix4 { return matrix4_scale({s, s, s}) }

matrix4_rotation_x :: #force_inline proc "contextless" (angle: f32) -> Matrix4 {
    c, s := cos(angle), sin(angle)
    return Matrix4{
        1,0,0,0,
        0,c,s,0,
        0,-s,c,0,
        0,0,0,1
    }
}
matrix4_rotation_y :: #force_inline proc "contextless" (angle: f32) -> Matrix4 {
    c, s := cos(angle), sin(angle)
    return Matrix4{
        c,0,-s,0,
        0,1,0,0,
        s,0,c,0,
        0,0,0,1
    }
}
matrix4_rotation_z :: #force_inline proc "contextless" (angle: f32) -> Matrix4 {
    c, s := cos(angle), sin(angle)
    return Matrix4{
        c,s,0,0,
        -s,c,0,0,
        0,0,1,0,
        0,0,0,1
    }
}

matrix4_rotate :: proc "contextless" (angle_degrees: f32, axis: Vector3) -> Matrix4 {
    ax := v3_normalize(axis)
    st := sin(degrees_to_radians(angle_degrees))
    ct := cos(degrees_to_radians(angle_degrees))
    cv := 1.0 - ct
    r  := matrix4_identity()
    // C uses e[row][col]; Odin uses m[col, row]
    r[0, 0] = ax.x*ax.x*cv + ct;        r[0, 1] = ax.x*ax.y*cv + ax.z*st; r[0, 2] = ax.x*ax.z*cv - ax.y*st
    r[1, 0] = ax.y*ax.x*cv - ax.z*st;   r[1, 1] = ax.y*ax.y*cv + ct;      r[1, 2] = ax.y*ax.z*cv + ax.x*st
    r[2, 0] = ax.z*ax.x*cv + ax.y*st;   r[2, 1] = ax.z*ax.y*cv - ax.x*st; r[2, 2] = ax.z*ax.z*cv + ct
    return r
}

matrix4_transpose :: #force_inline proc "contextless" (a: Matrix4) -> Matrix4 { return la.transpose(a) }
matrix4_inverse   :: #force_inline proc "contextless" (a: Matrix4) -> Matrix4 { return la.matrix4_inverse(a) }
matrix4_mul       :: #force_inline proc "contextless" (a, b: Matrix4) -> Matrix4 { return a * b }

matrix4_mulv4 :: #force_inline proc "contextless" (m: Matrix4, p: Vector4) -> Vector4 { return m * p }
matrix4_mulv3 :: #force_inline proc "contextless" (m: Matrix4, p: Vector3) -> Vector3 {
    return (m * Vector4{p.x, p.y, p.z, 1}).xyz
}
matrix4_transform_v4 :: #force_inline proc "contextless" (m: Matrix4, p: Vector4) -> Vector4 { return m * p }
matrix4_transform_v3 :: #force_inline proc "contextless" (m: Matrix4, p: Vector3) -> Vector3 { return matrix4_mulv3(m, p) }
matrix4_transform_v2 :: #force_inline proc "contextless" (m: Matrix4, p: Vector2) -> Vector2 {
    return {m[0,0]*p.x + m[1,0]*p.y + m[3,0], m[0,1]*p.x + m[1,1]*p.y + m[3,1]}
}

// reasonable values: perspective_camera(aspect_ratio, 1.0, 0.1, 100.0)
matrix4_perspective_camera :: #force_inline proc "contextless" (aspect, focal_length, near_z, far_z: f32) -> Matrix4 {
    c, n, f := focal_length, near_z, far_z
    d := (n + f) / (n - f)
    e := (2 * f * n) / (n - f)
    return Matrix4{
        c,0,0,0,
        0,aspect*c,0,0,
        0,0,d,-1, 
        0,0,e,0
    }
}

matrix4_perspective :: #force_inline proc "contextless" (fov, aspect_ratio, near_z, far_z: f32) -> Matrix4 {
    return la.matrix4_perspective_f32(degrees_to_radians(fov), aspect_ratio, near_z, far_z)
}

matrix4_orthographic_camera :: #force_inline proc "contextless" (aspect, near_z, far_z: f32) -> Matrix4 {
    n, f := near_z, far_z
    d := 2.0 / (n - f)
    e := (n + f) / (n - f)
    return Matrix4{
        1,0,0,0,
        0,aspect,0,0,
        0,0,d,0,
        0,0,e,1
    }
}

matrix4_orthographic :: #force_inline proc "contextless" (left, right, bottom, top, near_z, far_z: f32) -> Matrix4 {
    return la.matrix_ortho3d_f32(left, right, bottom, top, near_z, far_z)
}

// left-handed screen space: origin top-left
matrix4_window :: #force_inline proc "contextless" (screen: Vector2) -> Matrix4 {
    return matrix4_orthographic(0, screen.x, screen.y, 0, -1, 1)
}

matrix4_lookat :: #force_inline proc "contextless" (eye, center, up: Vector3) -> Matrix4 {
    return la.matrix4_look_at_f32(eye, center, up)
}

//
// Quaternion
// Odin quaternion128: real(q)=w, imag(q)=x, jmag(q)=y, kmag(q)=z
//

quaternion_identity  :: #force_inline proc "contextless" () -> Quaternion { return quaternion(w=1, x=0, y=0, z=0) }
quaternion_invert    :: #force_inline proc "contextless" (q: Quaternion) -> Quaternion {
    return quaternion(w=real(q), x=-imag(q), y=-jmag(q), z=-kmag(q))
}
quaternion_mul       :: #force_inline proc "contextless" (a, b: Quaternion) -> Quaternion { return a * b }

quaternion_from_angle :: #force_inline proc "contextless" (angle: f32, axis: Vector3) -> Quaternion {
    a := axis * sin(angle / 2)
    return quaternion(w=cos(angle / 2), x=a.x, y=a.y, z=a.z)
}

quaternion_to_rotation_matrix :: proc "contextless" (q: Quaternion) -> Matrix4 {
    x, y, z, w := imag(q), jmag(q), kmag(q), real(q)
    r := matrix4_identity()
    r[0, 0] = 1 - 2*y*y - 2*z*z;  r[1, 0] = 2*x*y - 2*z*w;      r[2, 0] = 2*x*z + 2*y*w
    r[0, 1] = 2*x*y + 2*z*w;      r[1, 1] = 1 - 2*x*x - 2*z*z;  r[2, 1] = 2*y*z - 2*x*w
    r[0, 2] = 2*x*z - 2*y*w;      r[1, 2] = 2*y*z + 2*x*w;      r[2, 2] = 1 - 2*x*x - 2*y*y
    return r
}

quaternion_vector3_mul :: #force_inline proc "contextless" (q: Quaternion, v: Vector3) -> Vector3 {
    return matrix4_transform_v3(quaternion_to_rotation_matrix(q), v)
}

quaternion_from_euler :: proc "contextless" (pitch, yaw, roll: f32) -> Quaternion {
    p, y, r := pitch/2, yaw/2, roll/2
    sp, cp := sin(p), cos(p)
    sy, cy := sin(y), cos(y)
    sr, cr := sin(r), cos(r)
    return quaternion(
        w = cr*cp*cy + sr*sp*sy,
        x = sr*cp*cy - cr*sp*sy,
        y = cr*sp*cy + sr*cp*sy,
        z = cr*cp*sy - sr*sp*cy,
    )
}

//
// Colors
//

hsv_from_rgb :: proc "contextless" (rgb: Vector3) -> Vector3 {
    r, g, b, k := rgb.x, rgb.y, rgb.z, f32(0)
    if g < b { g, b, k = b, g, -1 }
    if r < g { r, g, k = g, r, -2.0/6.0 - k }
    chroma := r - min(g, b)
    return {abs(k + (g - b) / (6*chroma + 1e-20)), chroma / (r + 1e-20), r}
}

rgb_from_hsv :: proc "contextless" (hsv: Vector3) -> Vector3 {
    if hsv.y == 0 do return {hsv.z, hsv.z, hsv.z}

    h, s, v := hsv.x, hsv.y, hsv.z
    if h >= 1 do h -= 10 * 1e-6
    if s >= 1 do s -= 10 * 1e-6
    if v >= 1 do v -= 10 * 1e-6

    h = mod(h, f32(1)) / (60.0/360.0)
    i := int(h)
    f := h - f32(i)
    p := v * (1 - s)
    q := v * (1 - s*f)
    t := v * (1 - s*(1 - f))

    switch i {
        case 0: return {v, t, p}
        case 1: return {q, v, p}
        case 2: return {p, v, t}
        case 3: return {p, q, v}
        case 4: return {t, p, v}
        case:   return {v, p, q}
    }
}

rgba_from_hsv :: #force_inline proc "contextless" (hsv: Vector3) -> Vector4 { return v4_from_v3f(rgb_from_hsv(hsv), 1) }

v4_argb_from_u32 :: #force_inline proc "contextless" (hex: u32) -> Vector4 {
    return {
        f32((hex >> 16) & 0xff) / 255,
        f32((hex >>  0) & 0xff) / 255,
        f32((hex >>  8) & 0xff) / 255,
        f32((hex >> 24) & 0xff) / 255,
    }
}
u32_argb_from_v4 :: #force_inline proc "contextless" (v: Vector4) -> u32 {
    return u32(v.w*255) << 24 | u32(v.x*255) << 16 | u32(v.y*255) << 8 | u32(v.z*255)
}
v4_rgba_from_u32 :: #force_inline proc "contextless" (hex: u32) -> Vector4 {
    return {
        f32((hex >>  0) & 0xff) / 255,
        f32((hex >>  8) & 0xff) / 255,
        f32((hex >> 16) & 0xff) / 255,
        f32((hex >> 24) & 0xff) / 255,
    }
}
v4_rgba_from_u8 :: #force_inline proc "contextless" (r, g, b, a: u8) -> Vector4 {
    return {f32(r)/255, f32(g)/255, f32(b)/255, f32(a)/255}
}
v4_rgb_from_u8 :: #force_inline proc "contextless" (r, g, b: u8) -> Vector4 {
    return {f32(r)/255, f32(g)/255, f32(b)/255, 1}
}
u32_rgba_from_v4 :: #force_inline proc "contextless" (v: Vector4) -> u32 {
    return u32(v.w*255) << 24 | u32(v.z*255) << 16 | u32(v.y*255) << 8 | u32(v.x*255)
}
u32_rgba_from_u8 :: #force_inline proc "contextless" (r, g, b, a: u8) -> u32 {
    return u32(a) << 24 | u32(b) << 16 | u32(g) << 8 | u32(r)
}
u32_rgb_from_u8 :: #force_inline proc "contextless" (r, g, b: u8) -> u32 {
    return 0xFF << 24 | u32(b) << 16 | u32(g) << 8 | u32(r)
}

v4_linear_to_srgb   :: #force_inline proc "contextless" (c: Vector4) -> Vector4 { return {pow(c.x, f32(1.0/2.2)), pow(c.y, f32(1.0/2.2)), pow(c.z, f32(1.0/2.2)), c.w} }
v4_srgb_to_linear   :: #force_inline proc "contextless" (c: Vector4) -> Vector4 { return {pow(c.x, f32(2.2)), pow(c.y, f32(2.2)), pow(c.z, f32(2.2)), c.w} }
v4_premultiply_alpha :: #force_inline proc "contextless" (c: Vector4) -> Vector4 { return {c.x*c.w, c.y*c.w, c.z*c.w, 1} }

//
// Collisions
//

rectangle_circle_collision :: #force_inline proc "contextless" (rect: Rectangle2, circle: Vector2, radius: f32) -> bool {
    dx := circle.x - clamp(circle.x, rect.p0.x, rect.p1.x)
    dy := circle.y - clamp(circle.y, rect.p0.y, rect.p1.y)
    return dx*dx + dy*dy < radius*radius
}

circle_intersects :: #force_inline proc "contextless" (c0: Vector2, r0: f32, c1: Vector2, r1: f32) -> bool {
    rad := r0 + r1
    return v2_length_squared(c0 - c1) <= rad*rad
}

// Returns (hit, point)
line_intersects_line :: proc "contextless" (p0, p1, p2, p3: Vector2) -> (bool, Vector2) {
    s1, s2 := p1 - p0, p3 - p2
    denom := -s2.x*s1.y + s1.x*s2.y
    s := (-s1.y*(p0.x - p2.x) + s1.x*(p0.y - p2.y)) / denom
    t := ( s2.x*(p0.y - p2.y) - s2.y*(p0.x - p2.x)) / denom
    if s >= 0 && s <= 1 && t >= 0 && t <= 1 {
        return true, p0 + (p1 - p0) * t
    }
    return false, {}
}

line_intersects_rectangle :: proc "contextless" (p0, p1: Vector2, rect: Rectangle2) -> bool {
    tl := Vector2{rect.p0.x, rect.p0.y}; tr := Vector2{rect.p1.x, rect.p0.y}
    bl := Vector2{rect.p0.x, rect.p1.y}; br := Vector2{rect.p1.x, rect.p1.y}
    if ok, _ := line_intersects_line(p0, p1, tl, tr); ok do return true
    if ok, _ := line_intersects_line(p0, p1, tr, br); ok do return true
    if ok, _ := line_intersects_line(p0, p1, bl, br); ok do return true
    if ok, _ := line_intersects_line(p0, p1, tl, bl); ok do return true
    return false
}

line_intersects_circle :: #force_inline proc "contextless" (p1, p2, circle: Vector2, radius: f32) -> bool {
    ac, ab := circle - p1, p2 - p1
    t := clamp(v2_dot(ac, ab) / v2_dot(ab, ab), f32(0), f32(1))
    h := ab*t + p1 - circle
    return v2_dot(h, h) <= radius*radius
}

screen_to_ndc :: #force_inline proc "contextless" (window, screen: Vector2) -> Vector3 {
    return {2*screen.x/window.x - 1, 1 - 2*screen.y/window.y, 1}
}

camera_ray_from_point :: proc "contextless" (proj, view: Matrix4, window, point: Vector2) -> Vector3 {
    ray_clip := Vector4{2*point.x/window.x - 1, 1 - 2*point.y/window.y, -1, 1}
    ray_eye  := matrix4_inverse(proj) * ray_clip
    ray_eye   = {ray_eye.x, ray_eye.y, -1, 0}
    return v3_normalize((matrix4_inverse(view) * ray_eye).xyz)
}

world_to_ndc :: #force_inline proc "contextless" (proj: Matrix4, world: Vector3) -> Vector3 {
    h := proj * Vector4{world.x, world.y, world.z, 1}
    return h.xyz / h.w
}

world_to_screen :: #force_inline proc "contextless" (proj: Matrix4, world: Vector3, window: Vector2) -> Vector3 {
    h   := proj * Vector4{world.x, world.y, world.z, 1}
    ndc := h.xyz / h.w
    return {(ndc.x + 1)/2 * window.x, (1 - ndc.y)/2 * window.y, ndc.z}
}

point_in_triangle :: #force_inline proc "contextless" (point, a, b, c: Vector2) -> bool {
    tri_sign :: #force_inline proc "contextless" (p1, p2, p3: Vector2) -> f32 {
        return (p1.x - p3.x)*(p2.y - p3.y) - (p2.x - p3.x)*(p1.y - p3.y)
    }
    d1, d2, d3 := tri_sign(point, a, b), tri_sign(point, b, c), tri_sign(point, c, a)
    return !((d1 < 0 || d2 < 0 || d3 < 0) && (d1 > 0 || d2 > 0 || d3 > 0))
}

sd_box :: #force_inline proc "contextless" (p, b: Vector2) -> f32 {
    d := abs_v2(p) - b
    return v2_length(max_v2(d, {})) + min(max(d.x, d.y), f32(0))
}

sd_box_rect :: #force_inline proc "contextless" (rect: Rectangle2, point: Vector2) -> f32 {
    return sd_box(point - r2_center(rect), r2_size(rect) * 0.5)
}