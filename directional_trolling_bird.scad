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
wing_start_x = 52;    // X position where wings attach (at widest section)
wing_root_chord = 15; // root chord length at body (X direction)
wing_length = 50;     // total length from body surface to wing tip
wing_tip_y = 50;      // lateral distance from centerline to tip (Y direction)

/* [Resolution] */
$fn = 72;

// ─────────────────────────────────────────────────────────────
//  Utility functions
// ─────────────────────────────────────────────────────────────
function clamp01(t)    = max(0, min(1, t));
function smoothstep(t) = let(c = clamp01(t)) c*c*(3 - 2*c);

// ─────────────────────────────────────────────────────────────
//  Body profile functions
//  Nose section: uses linear interpolation for gradual taper
//  Tail section: uses smoothstep for gentle transition
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
//  A wedge/angular nose tip that tapers to a point.
// ─────────────────────────────────────────────────────────────
module nose_cap() {
    hw = nose_width / 2;
    d  = nose_depth;
    
    polyhedron(
        points = [
            [0, hw, 0],           // right top
            [0, -hw, 0],          // left top
            [0, 0, -d],           // bottom belly
            [-d, 0, -d/2]         // tip point
        ],
        faces = [
            [0, 2, 1],            // rear face
            [0, 3, 2],            // right wedge
            [1, 2, 3],            // left wedge
            [1, 0, 3]             // top surface
        ]
    );
}

// ─────────────────────────────────────────────────────────────
//  WING (single fin)
//  Simple tapered fin from body surface to tip.
//  50mm length measured from body surface.
// ──────────────────────────────────────────────────���──────────
module one_wing() {
    hw_root = body_hw(wing_start_x);  // body half-width at attachment
    d_root = body_depth(wing_start_x); // body depth at attachment
    
    N_wing = 16;  // cross-sections along the fin
    
    for (i = [0 : N_wing - 2]) {
        s = i / (N_wing - 1);           // 0 at root, 1 at tip
        s_next = (i + 1) / (N_wing - 1);
        
        // Position along the 50mm wing length
        // Tapers from body edge (hw_root) outward to tip
        y_pos = hw_root + s * (wing_tip_y - hw_root);
        y_next = hw_root + s_next * (wing_tip_y - hw_root);
        
        // Blend with body belly depth
        z_pos = -d_root * (1 - s * 0.5);
        z_next = -d_root * (1 - s_next * 0.5);
        
        // Slight X sweep along the chord
        x_pos = wing_start_x + s * wing_root_chord * 0.4;
        x_next = wing_start_x + s_next * wing_root_chord * 0.4;
        
        // Chord tapers with span
        chord = wing_root_chord * (1 - s);
        chord_next = wing_root_chord * (1 - s_next);
        
        // Thickness tapers
        t = d_root * 0.4 * (1 - s);
        t_next = d_root * 0.4 * (1 - s_next);
        
        hull() {
            // Current section: flat top, angled belly
            translate([x_pos, y_pos, z_pos])
            rotate([90, 0, 0])
            linear_extrude(height = 0.02, center = true)
                polygon([
                    [0, 0],              // top leading
                    [chord, 0],          // top trailing
                    [chord * 0.8, -t],   // belly trailing
                    [0, -t * 0.5]        // belly leading
                ]);
            
            // Next section
            translate([x_next, y_next, z_next])
            rotate([90, 0, 0])
            linear_extrude(height = 0.02, center = true)
                polygon([
                    [0, 0],
                    [chord_next, 0],
                    [chord_next * 0.8, -t_next],
                    [0, -t_next * 0.5]
                ]);
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
