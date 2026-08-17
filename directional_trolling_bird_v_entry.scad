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
nose_entry_len   = 12;   // shorter V-entry zone for crisper wedge nose
nose_entry_frac  = 0.38; // less early depth build to reduce nose bulge

/* [Nose Chine Line Tuning] */
chine_len = 40;          // length of straight-ish chine region from nose
chine_drop = 0.80;       // fraction of local depth reached by chine at chine_len (0.7..0.9)
chine_blend_power = 1.0; // 1 = linear side profile along chine (matches drawn white line)

/* [Belly Shape Tuning] */
belly_shape_power = 2.8; // >1 flattens side shoulders and reduces nose belly bulge

/* [Belly Depth] */
nose_depth  = 15;     // depth at nose tip
wide_depth  = 34;     // depth at widest station
tail_depth  = 23.5;   // depth at tail

/* [Crown/Back Roundness] */
crown_height = 18;     // peak crown height
nose_peak_power = 2.4; // >1 = flatter near nose, sharper near center (wedge-like top)

/* [Side Wings] */
wing_x_pos = 55;         // X position of wing attachment (along body)
wing_span = 50;          // span of wing (Y direction - outward from body to tip)
wing_height = 32;        // wing height (Z direction)
wing_thickness = 4;      // thickness of wing blade (X direction)
wing_sink = 6;           // how far wings sink into body for blending
wing_forward_tilt = 8;   // degrees: top leans forward (+X)
wing_tip_round = 5;      // radius for outside tip rounding
wing_back_round = 1.5;   // slight rounding on trailing/back face
wing_root_blend = 3.5;   // blend radius where wing meets body

/* [Resolution] */
$fn = 64;

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

// Crown height profile: sharper rise nose->wide_x, smooth taper wide_x->tail
function crown_at_x(x) =
    (x <= wide_x)
    ? crown_height * pow(x / wide_x, nose_peak_power)
    : crown_height * (1 - smoothstep((x - wide_x) / (total_length - wide_x)));

// Nose chine target depth (for straight side-profile line near nose)
function chine_target_depth(x, d_local) =
    (x <= chine_len)
    ? d_local * chine_drop * pow(clamp01(x / chine_len), chine_blend_power)
    : d_local;

// BODY MODULE - ROUNDED BACK PROFILE
N_body = 72;

module body_profile_2d(hw, d, cr, cx) {
    // Belly: combine section shape control + nose chine linearization
    // Back: rounded arch curving upward with crown height cr
    N = 44;

    d_ch = chine_target_depth(cx, d);

    // Belly: from left to right (downward)
    // For each lateral sample, blend between chine line depth and section depth profile.
    belly = [for (i = [0 : N])
        let(a = 180 * i / N,
            s = max(0, sin(a)),
            z_round = -d * pow(s, belly_shape_power),
            z_chine = -d_ch * pow(s, 0.9),
            w = smoothstep(s))
        [hw * cos(a), (1 - w) * z_chine + w * z_round]
    ];

    // Back: upward rounded arch from right to left (same winding as belly)
    // symmetric arch: 0 at both ends, peak at center
    back = [for (i = [0 : N])
        let(a = 180 * i / N)
        [hw * cos(a), cr * sin(a)]
    ];

    polygon(concat(belly, back));
}

module body_cross_section(cx, hw, d, cr) {
    wafer = 0.01;
    translate([cx, 0, 0])
    rotate([90, 0, 90])
    linear_extrude(height = wafer, center = true)
        body_profile_2d(hw, d, cr, cx);
}

module body_solid() {
    for (i = [0 : N_body - 2]) {
        x0 = total_length *  i      / (N_body - 1);
        x1 = total_length * (i + 1) / (N_body - 1);
        hull() {
            body_cross_section(x0, body_hw(x0), body_depth(x0), crown_at_x(x0));
            body_cross_section(x1, body_hw(x1), body_depth(x1), crown_at_x(x1));
        }
    }
}

// Wing primitives: rounded outer tip + slight rounded trailing/back edge
module wing_plate_rounded(span, h, th, tip_r, back_r) {
    // Build as a rounded 2D profile in YZ and extrude in X (thickness)
    linear_extrude(height = th, center = false)
    offset(r = back_r)
    offset(delta = -back_r)
    polygon(points = concat(
        // Root bottom -> root top
        [[0, 0], [0, h]],
        // Top edge to tip with rounded outer corner arc
        [for (a = [90:-5:0])
            [span - tip_r + tip_r*cos(a), h - tip_r + tip_r*sin(a)]],
        // Tip down to bottom with rounded lower corner arc
        [for (a = [0:-5:-90])
            [span - tip_r + tip_r*cos(a), tip_r + tip_r*sin(a)]],
        // Back to root bottom
        [[0, 0]]
    ));
}

module right_wing() {
    hw = body_hw(wing_x_pos);
    // sink into body and tilt slightly forward
    translate([wing_x_pos - wing_thickness/2, hw - wing_root_blend, -wing_sink])
    rotate([0, -wing_forward_tilt, 0])
        wing_plate_rounded(wing_span, wing_height, wing_thickness, wing_tip_round, wing_back_round);
}

module left_wing() {
    hw = body_hw(wing_x_pos);
    // mirrored in Y
    mirror([0,1,0])
    translate([wing_x_pos - wing_thickness/2, hw - wing_root_blend, -wing_sink])
    rotate([0, -wing_forward_tilt, 0])
        wing_plate_rounded(wing_span, wing_height, wing_thickness, wing_tip_round, wing_back_round);
}

// Smooth blend union for body + wings
module blended_assembly() {
    mink_r = wing_root_blend;
    minkowski() {
        union() {
            body_solid();
            right_wing();
            left_wing();
        }
        sphere(r = mink_r);
    }
}

// Re-sharpen overall silhouette after blend to avoid overgrowth
module final_assembly() {
    mink_r = wing_root_blend;
    difference() {
        blended_assembly();
        // trim oversize shell caused by minkowski by subtracting a shifted copy
        // This keeps root blend while avoiding bulky inflation.
        translate([0,0,0])
        minkowski() {
            union() {
                body_solid();
                right_wing();
                left_wing();
            }
            sphere(r = max(0, mink_r - 1.5));
        }
    }
}

// ASSEMBLY
final_assembly();
