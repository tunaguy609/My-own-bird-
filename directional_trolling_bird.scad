// ============================================================
//  Directional Trolling Bird – Sterling Wide Tracker Style
//  Parametric OpenSCAD model – v1.0
// ============================================================
//
//  COORDINATE SYSTEM
//    X  : bird length (0 = nose tip,  +X toward tail)
//    Y  : lateral width (0 = centre-line, +Y = right side)
//    Z  : vertical  (Z = 0 is the FLAT TOP;  -Z = belly downward)
//
//  All dimensions in millimetres.
//  Open in OpenSCAD and use the Customizer panel to adjust parameters.
// ============================================================

/* [Main Body] */
total_length = 180;   // overall length nose to tail
nose_width   = 15;    // body width at nose tip
wide_x       = 52;    // station of maximum width (measured from nose)
max_width    = 60;    // maximum body width (at wide_x)
tail_width   = 15;    // body width at tail  (default = nose_width)

/* [Belly Depth  (flat-top surface to deepest belly point)] */
nose_depth  = 10;     // depth at nose tip
wide_depth  = 40;     // depth at widest station
tail_depth  = 10;     // depth at tail

/* [Lateral Wings] */
// Root attachment spans X = wing_start_x (top/forward edge) to
//   X = wing_end_x (bottom/rear edge), where they mould into the body.
wing_start_x = 52;    // X of wing top edge at body  (= wide_x)
wing_end_x   = 73;    // X of wing bottom edge at body
// Edge lengths measured from body junction to wing tip:
wing_top_len = 50;    // leading (top/forward) edge length
wing_bot_len = 60;    // trailing (bottom/rear) edge length
// Thickness along span:
wing_root_t  = 4;     // thickness at body junction (mould-in)
wing_mid_t   = 7;     // maximum thickness (at mid-span)
wing_tip_t   = 4;     // thickness at tip
// Planform angles:
wing_fwd_angle = 8;   // degrees the leading face leans forward

/* [Resolution] */
$fn = 72;

// ─────────────────────────────────────────────────────────────
//  Utility functions
// ─────────────────────────────────────────────────────────────
function clamp01(t)    = max(0, min(1, t));
function smoothstep(t) = let(c = clamp01(t)) c*c*(3 - 2*c);

// ─────────────────────────────────────────────────────────────
//  Body profile functions
//  Both share the same smoothstep(t) convention:
//    t = 0 at the anchor station, t = 1 at the far end.
// ─────────────────────────────────────────────────────────────

// Half-width at longitudinal station x
function body_hw(x) =
    (x <= wide_x)
    ? nose_width/2 + (max_width/2  - nose_width/2)
        * smoothstep(x / wide_x)
    : max_width/2  + (tail_width/2 - max_width/2)
        * smoothstep((x - wide_x) / (total_length - wide_x));

// Belly depth at longitudinal station x
function body_depth(x) =
    (x <= wide_x)
    ? nose_depth + (wide_depth - nose_depth)
        * smoothstep(x / wide_x)
    : wide_depth + (tail_depth - wide_depth)
        * smoothstep((x - wide_x) / (total_length - wide_x));

// ─────────────────────────────────────────────────────────────
//  BODY MODULE
//  Swept hull of flat-top / semi-ellipse cross-sections.
//
//  The 2D profile polygon (body_profile_2d) lives in a plane with:
//    1st coord (+) → lateral width (maps to 3D +Y after rotation)
//    2nd coord (-) → belly depth  (maps to 3D -Z after rotation)
//
//  rotate([90,0,90]) = Rz(90)·Rx(90) achieves:
//    2D_x   → 3D_Y  (lateral)
//    2D_y   → 3D_Z  (depth, negative = belly)
//    extr.  → 3D_X  (along bird length)
// ─────────────────────────────────────────────────────────────
N_body = 64;

//  2D semi-ellipse: arc from [hw,0] (right) to [-hw,0] (left) via [0,-d].
//  Polygon auto-closes with the flat top edge: [-hw,0] → [hw,0].
module body_profile_2d(hw, d) {
    N_arc = 36;
    polygon([
        for (i = [0 : N_arc])
            let(a = 180 * i / N_arc)
            [hw * cos(a),  -d * sin(a)]
    ]);
}

//  Wafer-thin disc perpendicular to the X axis at station cx.
module body_cross_section(cx, hw, d) {
    wafer = 0.02;
    translate([cx, 0, 0])
    rotate([90, 0, 90])
    linear_extrude(height = wafer, center = true)
        body_profile_2d(hw, d);
}

module body_solid() {
    for (i = [0 : N_body - 2]) {
        x0 = total_length *  i      / (N_body - 1);
        x1 = total_length * (i + 1) / (N_body - 1);
        hull() {
            body_cross_section(x0, body_hw(x0), body_depth(x0));
            body_cross_section(x1, body_hw(x1), body_depth(x1));
        }
    }
}

// ─────────────────────────────────────────────────────────────
//  NOSE CAP
//  A quarter-ellipsoid that rounds off the nose.
//  Occupies  X ∈ [-nose_depth, 0],  Z ∈ [-nose_depth, 0].
//  Its flat face at X = 0 matches the body's nose cross-section
//  (Y ∈ [-nose_width/2, nose_width/2],  Z ∈ [-nose_depth, 0]).
//
//  Construction in unit-sphere space, before rotate([0,90,0]):
//    • World_X = local_z  →  local_z ≤ 0  keeps World_X ≤ 0
//    • World_Z = -local_x →  local_x ≥ 0  keeps World_Z ≤ 0
//  Clip to { local_x ≥ 0, local_z ≤ 0 } → quarter-sphere.
//  Scale axes: X×nose_depth, Y×nose_width/2, Z×nose_depth.
// ─────────────────────────────────────────────────────────────
module nose_cap() {
    hw = nose_width / 2;
    d  = nose_depth;
    scale([d, hw, d])
    rotate([0, 90, 0])
    intersection() {
        sphere(r = 1);
        // Quarter-sphere clip: local_x ∈ [0,1], local_z ∈ [-1,0]
        translate([0, -1.5, -1.5])
            cube([1.5, 3, 1.5]);
    }
}

// ─────────────────────────────────────────────────────────────
//  WING THICKNESS along normalised half-span  s ∈ [0, 1]
//    s = 0 → root (at body edge)
//    s = 1 → tip
// ─────────────────────────────────────────────────────────────
function wing_t(s) =
    (s <= 0.5)
    ? wing_root_t + (wing_mid_t - wing_root_t) * smoothstep(s / 0.5)
    : wing_mid_t  + (wing_tip_t  - wing_mid_t)  * smoothstep((s - 0.5) / 0.5);

// ─────────────────────────────────────────────────────────────
//  SINGLE WING  (right-hand side, Y > 0)
//
//  Planform (top view):
//    The root chord (at body edge, s=0) runs from X=wing_start_x to
//    X=wing_end_x (21 mm root chord).
//
//    As the wing sweeps outboard:
//      • Leading edge angles forward by wing_fwd_angle.
//        Lateral span for leading edge = wing_top_len * cos(wing_fwd_angle).
//      • Trailing edge sweeps rearward so that the trailing edge
//        achieves wing_bot_len from root to tip.
//    Both edges converge to the same lateral tip Y-position (hw_tip).
//
//  Cross-section orientation:
//    Profile polygon is in the X-Z plane (chord direction × belly depth).
//    rotate([90,0,0]) = Rx(90):
//      2D_x → 3D_X  (chord, toward tail)  ✓
//      2D_y → 3D_Z  (depth, negative = belly)  ✓
//      extr.→ 3D_Y  (lateral span, centered on y_pos)  ✓
//
//  Thickness profile: 4 mm (root) → 7 mm (mid) → 4 mm (tip).
//  Top is flush with flat top (Z = 0).
//  Rear face is convex/rounded; leading face is planar and angled forward.
// ─────────────────────────────────────────────────────────────
N_wing = 24;

// Derived wing span geometry (computed from the edge-length parameters)
// hw_root : body half-width at wing attachment
// hw_tip  : lateral Y-coordinate of wing tip
// dy      : lateral span = hw_tip - hw_root
//
// Leading edge has length wing_top_len angled at wing_fwd_angle forward:
//   dy = wing_top_len * cos(wing_fwd_angle)
//   dx_le = dy * tan(wing_fwd_angle)  (X swept forward)
//
// Trailing edge has length wing_bot_len from root (X=wing_end_x) to tip:
//   dx_te = sqrt(wing_bot_len² - dy²)  (X swept rearward)
//
// Note: wing_bot_len must be ≥ dy for the geometry to be valid.
// With the defaults: dy ≈ 49.5 mm, wing_bot_len = 60 mm → dx_te ≈ 33.9 mm.

// ─────────────────────────────────────────────────────────────
//  2D wing profile in local X-Z space:
//    chord = wing chord length in X (trailing minus leading X)
//    t     = leading-edge thickness (Z depth at leading edge)
//    dz    = total belly depth at this span station
//  Shape: flat top → rounded convex rear → belly → angled leading face.
// ─────────────────────────────────────────────────────────────
module wing_profile_2d(chord, t, dz) {
    N_rear = 16;
    rear_r = chord * 0.12;    // radius of convex rear-corner arc

    pts = concat(
        // flat top: leading edge to trailing edge
        [[0, 0],  [chord, 0]],
        // convex rear arc from trailing top corner sweeping to trailing belly
        [for (i = [1 : N_rear - 1])
            let(a = 90 * i / N_rear)
            [chord - rear_r * (1 - cos(a)),
             -dz * sin(a)]
        ],
        // trailing edge belly corner
        [[chord - rear_r,  -dz]],
        // belly: flat run from trailing to just below leading edge
        [[rear_r * 0.5,    -dz]],
        // leading edge bottom (angled forward face)
        [[0, -t]]
    );
    polygon(pts);
}

module wing_cross_section(s, hw_root, hw_tip, dx_te) {
    wafer  = 0.02;
    dy     = hw_tip - hw_root;
    y_pos  = hw_root + s * dy;   // lateral position at this span station

    // Leading-edge X: sweeps forward as span increases
    x_le = wing_start_x - (y_pos - hw_root) * tan(wing_fwd_angle);
    // Trailing-edge X: sweeps rearward by dx_te over the full span
    x_te = wing_end_x   + s * dx_te;

    chord = x_te - x_le;
    t     = wing_t(s);

    // Belly depth: tapers from body depth at root to tip thickness at tip
    dz = body_depth(wing_start_x) * (1 - s) + t * s;

    translate([x_le, y_pos, 0])
    rotate([90, 0, 0])          // orient profile in X-Z plane, extrude in Y
    linear_extrude(height = wafer, center = true)
        wing_profile_2d(chord, t, dz);
}

module one_wing() {
    hw_root = body_hw(wing_start_x);
    // Lateral span from wing_top_len (leading-edge arc length and angle)
    hw_tip  = hw_root + wing_top_len * cos(wing_fwd_angle);
    dy      = hw_tip - hw_root;
    // Trailing-edge X-sweep computed from wing_bot_len
    dx_te   = sqrt(max(0, wing_bot_len * wing_bot_len - dy * dy));

    for (i = [0 : N_wing - 2]) {
        s0 = i       / (N_wing - 1);
        s1 = (i + 1) / (N_wing - 1);
        hull() {
            wing_cross_section(s0, hw_root, hw_tip, dx_te);
            wing_cross_section(s1, hw_root, hw_tip, dx_te);
        }
    }
}

// ─────────────────────────────────────────────────────────────
//  ASSEMBLY
// ─────────────────────────────────────────────────────────────
union() {
    body_solid();
    nose_cap();
    one_wing();
    mirror([0, 1, 0]) one_wing();
}
