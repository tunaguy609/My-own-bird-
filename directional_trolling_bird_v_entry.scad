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
nose_width_power = 1.15;   // >1 narrows faster near nose for a sharper taper

/* [Nose Entry Tuning] */
nose_entry_len   = 26;   // longer V-entry zone for straighter wedge nose
nose_entry_frac  = 0.18; // less early depth build to reduce nose bulge

/* [Nose Chine Line Tuning] */
chine_len = 55;          // length of straight-ish chine region from nose
chine_drop = 0.72;       // fraction of local depth reached by chine at chine_len
chine_blend_power = 0.9; // near-linear side profile along chine

/* [Belly Shape Tuning] */
belly_shape_power = 1.9; // lower value reduces shoulder bulge and straightens taper

/* [Belly Depth] */
nose_depth  = 12.5;   // depth at nose tip (reduced for cleaner taper)
wide_depth  = 34;     // depth at widest station
tail_depth  = 23.5;   // depth at tail

/* [Crown/Back Roundness] */
crown_height = 18;     // peak crown height
nose_peak_power = 1.35; // lower value gives cleaner top slope toward tip

/* [Side Wings] */
wing_x_pos = 55;         // X position of wing attachment (along body)
wing_span = 50;          // span of wing (Y direction - outward from body to tip)
wing_height = 32;        // wing height (Z direction)
wing_thickness = 4;      // thickness of wing blade (X direction)
wing_sink = 6;           // how far wings sink into body
wing_forward_tilt = 8;   // degrees: top leans forward (+X)
wing_tip_round = 5;      // radius for outside tip rounding
wing_back_round = 1.5;   // slight rounding on trailing/back face
wing_root_fillet = 3.5;  // local hull fillet at wing root (lightweight)

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
N_body = 64;

module body_profile_2d(hw, d, cr, cx) {
    N = 36;

    d_ch = chine_target_depth(cx, d);

    belly = [for (i = [0 : N])
        let(a = 180 * i / N,
            s = max(0, sin(a)),
            z_round = -d * pow(s, belly_shape_power),
            z_chine = -d_ch * pow(s, 0.9),
            w = smoothstep(s))
        [hw * cos(a), (1 - w) * z_chine + w * z_round]
    ];

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

// Wing profile with rounded tip + slight trailing edge softening
module wing_plate_rounded(span, h, th, tip_r, back_r) {
    linear_extrude(height = th, center = false)
    offset(r = back_r)
    offset(delta = -back_r)
    polygon(points = concat(
        [[0, 0], [0, h]],
        [for (a = [90:-6:0])
            [span - tip_r + tip_r*cos(a), h - tip_r + tip_r*sin(a)]],
        [for (a = [0:-6:-90])
            [span - tip_r + tip_r*cos(a), tip_r + tip_r*sin(a)]],
        [[0, 0]]
    ));
}

module right_wing_raw() {
    hw = body_hw(wing_x_pos);
    translate([wing_x_pos - wing_thickness/2, hw - wing_root_fillet, -wing_sink])
    rotate([0, -wing_forward_tilt, 0])
        wing_plate_rounded(wing_span, wing_height, wing_thickness, wing_tip_round, wing_back_round);
}

module left_wing_raw() {
    hw = body_hw(wing_x_pos);
    mirror([0,1,0])
    translate([wing_x_pos - wing_thickness/2, hw - wing_root_fillet, -wing_sink])
    rotate([0, -wing_forward_tilt, 0])
        wing_plate_rounded(wing_span, wing_height, wing_thickness, wing_tip_round, wing_back_round);
}

// Lightweight root blend: local hull between each wing and small embedded root pad
module right_wing_blended() {
    hw = body_hw(wing_x_pos);
    hull() {
        right_wing_raw();
        translate([wing_x_pos - wing_thickness/2, hw - 1.2*wing_root_fillet, -wing_sink - 1])
            cube([wing_thickness, wing_root_fillet*2.2, wing_height*0.35]);
    }
}

module left_wing_blended() {
    hw = body_hw(wing_x_pos);
    hull() {
        left_wing_raw();
        mirror([0,1,0])
        translate([wing_x_pos - wing_thickness/2, hw - 1.2*wing_root_fillet, -wing_sink - 1])
            cube([wing_thickness, wing_root_fillet*2.2, wing_height*0.35]);
    }
}

// ASSEMBLY (lightweight and render-safe)
union() {
    body_solid();
    right_wing_blended();
    left_wing_blended();
}
