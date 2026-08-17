// ============================================================
//  Directional Trolling Bird - Sterling Wide Tracker Style
//  Parametric OpenSCAD model - v1.0
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
total_length = 210;   // overall length nose to tail
nose_width   = 15;    // body width at nose tip
wide_x       = 52;    // station of maximum width (measured from nose)
max_width    = 50;    // maximum body width (at wide_x)
tail_width   = 15;    // body width at tail  (default = nose_width)

/* [Nose Width Entry Tuning] */
nose_width_power = 0.70;   // <1 widens faster near nose; try 0.65 to 0.85

/* [Nose Entry Tuning] */
nose_entry_len   = 15;   // mm from tip for V-entry zone
nose_entry_frac  = 0.48; // fraction of (wide_depth-nose_depth) reached at nose_entry_len

/* [Belly Depth] */
nose_depth  = 15;     // depth at nose tip
wide_depth  = 34;     // depth at widest station
tail_depth  = 23.5;   // depth at tail

/* [Crown/Back Roundness] */
crown_height = 6;     // height of rounded back (CONSTANT along body)

/* [Side Wings] */
wing_x_pos = 55;      // X position of wing attachment (along body)
wing_span = 50;       // span of wing (Y direction - 50mm outward from body to tip)
wing_height = 32;     // height of wing (Z direction - 32mm flat face)
wing_thickness = 3;   // thickness of wing blade (X direction)

/* [Resolution] */
$fn = 48;

// Utility functions
function clamp01(t)    = max(0, min(1, t));
function smoothstep(t) = let(c = clamp01(t)) c*c*(3 - 2*c);

// Half-width at longitudinal station x
function body_hw(x) =
    (x <= wide_x)
    ? nose_width/2 + (max_width/2 - nose_width/2)
        * pow(x / wide_x, nose_width_power)
    : max_width/2 + (tail_width/2 - max_width/2)
        * smoothstep((x - wide_x) / (total_length - wide_x));

// Belly depth at longitudinal station x
function body_depth(x) =
    (x <= nose_entry_len)
    ? nose_depth + (wide_depth - nose_depth) * nose_entry_frac
        * (x / nose_entry_len)
    : (x <= wide_x)
        ? (nose_depth + (wide_depth - nose_depth) * nose_entry_frac)
          + (wide_depth - (nose_depth + (wide_depth - nose_depth) * nose_entry_frac))
            * smoothstep((x - nose_entry_len) / (wide_x - nose_entry_len))
        : wide_depth + (tail_depth - wide_depth)
            * smoothstep((x - wide_x) / (total_length - wide_x));

// BODY MODULE - ROUNDED BACK PROFILE
N_body = 48;

module body_profile_2d(hw, d, cr) {
    // Belly: semicircle dipping down with depth d
    // Back: rounded arch curving upward with crown height cr
    N = 25;
    
    // Belly: semicircle from left to right (downward)
    belly = [for (i = [0 : N])
        let(a = 180 * i / N)
        [hw * cos(a), -d * sin(a)]
    ];
    
    // Back: upward rounded arch from right to left (same winding as belly)
    // (1 - cos(a)) peaks at center (a=90), zero at ends
    back = [for (i = [0 : N])
        let(a = 180 * i / N)
        [hw * cos(a), cr * (1 - cos(a))]
    ];
    
    polygon(concat(belly, back));
}

module body_cross_section(cx, hw, d, cr) {
    wafer = 0.01;
    translate([cx, 0, 0])
    rotate([90, 0, 90])
    linear_extrude(height = wafer, center = true)
        body_profile_2d(hw, d, cr);
}

module body_solid() {
    for (i = [0 : N_body - 2]) {
        x0 = total_length *  i      / (N_body - 1);
        x1 = total_length * (i + 1) / (N_body - 1);
        hull() {
            // Use CONSTANT crown_height for rounded back at all stations
            body_cross_section(x0, body_hw(x0), body_depth(x0), crown_height);
            body_cross_section(x1, body_hw(x1), body_depth(x1), crown_height);
        }
    }
}

// NOSE CAP
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

// FLAT VERTICAL WINGS
module right_wing() {
    hw = body_hw(wing_x_pos);
    translate([wing_x_pos, hw, 0])
    cube([wing_thickness, wing_span, wing_height]);
}

module left_wing() {
    hw = body_hw(wing_x_pos);
    translate([wing_x_pos, -(hw + wing_span), 0])
    cube([wing_thickness, wing_span, wing_height]);
}

// ASSEMBLY
union() {
    body_solid();
    nose_cap();
    right_wing();
    left_wing();
}
