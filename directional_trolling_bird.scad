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
wing_x_pos = 55;      // X position of wing attachment (along body)
wing_span = 50;       // 50mm from body edge to wing tip
wing_chord = 20;      // 20mm chord length (X direction sweep)

/* [Resolution] */
$fn = 72;

// ─────────────────────────────────────────────────────────────
//  Utility functions
// ─────────────────────────────────────────────────────────────
function clamp01(t)    = max(0, min(1, t));
function smoothstep(t) = let(c = clamp01(t)) c*c*(3 - 2*c);

// ─────────────────────────────────────────────────────────────
//  Body profile functions
// ─────────────────────────────────────────────────────────────

// Half-width at longitudinal station x
function body_hw(x) =
    (x <= wide_x)
    ? nose_width/2 + (max_width/2  - nose_width/2)
        * (x / wide_x)  // LINEAR taper from nose to widest point
    : max_width/2  + (tail_width/2 - max_width/2)
        * smoothstep((x - wide_x) / (total_length - wide_x));

// Belly depth at longitudinal station x
function body_depth(x) =
    (x <= wide_x)
    ? nose_depth + (wide_depth - nose_depth)
        * (x / wide_x)  // LINEAR taper from nose to widest point
    : wide_depth + (tail_depth - wide_depth)
        * smoothstep((x - wide_x) / (total_length - wide_x));

// ─────────────────────────────────────────────────────────────
//  BODY MODULE
// ─────────────────────────────────────────────────────────────
N_body = 64;

module body_profile_2d(hw, d) {
    N_arc = 36;
    polygon([
        for (i = [0 : N_arc])
            let(a = 180 * i / N_arc)
            [hw * cos(a),  -d * sin(a)]
    ]);
}

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
// ─────────────────────────────────────────────────────────────
module nose_cap() {
    hw = nose_width / 2;
    d  = nose_depth;
    
    polyhedron(
        points = [
            [0, hw, 0],
            [0, -hw, 0],
            [0, 0, -d],
            [-d, 0, -d/2]
        ],
        faces = [
            [0, 2, 1],
            [0, 3, 2],
            [1, 2, 3],
            [1, 0, 3]
        ]
    );
}

// ─────────────────────────────────────────────────────────────
//  WING (single blade fin)
//  2D wing profile extruded along Z, then rotated into position.
// ─────────────────────────────────────────────────────────────
module one_wing() {
    hw = body_hw(wing_x_pos);
    d = body_depth(wing_x_pos);
    
    // 2D wing profile in X-Y plane (chord x span):
    // X: 0 to wing_chord (swept along body length)
    // Y: 0 to wing_span (extends laterally from body edge)
    wing_profile_2d = [
        [0, 0],                    // root at body edge
        [wing_chord, 0],           // trailing at body edge
        [wing_chord * 0.7, wing_span],  // trailing at tip
        [0, wing_span]             // leading at tip
    ];
    
    // Create 2D profile extruded in Z, then rotate to position on body side
    translate([wing_x_pos, hw, 0])
    rotate([90, 0, 0])
    linear_extrude(height = d * 0.15, center = false)
        polygon(wing_profile_2d);
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
