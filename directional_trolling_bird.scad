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
wing_start_x = 50;    // X position where wings start
wing_end_x = 80;      // X position where wings end
wing_span = 50;       // total span from body centerline to tip

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
//  Thin blade-like fin that spans laterally 50mm from body edge.
//  Attaches along the body from wing_start_x to wing_end_x.
// ─────────────────────────────────────────────────────────────
module one_wing() {
    N_wing_x = 12;   // sections along chord (X direction)
    N_wing_y = 16;   // sections along span (Y direction)
    
    for (ix = [0 : N_wing_x - 2]) {
        for (iy = [0 : N_wing_y - 2]) {
            // X progression: along the body attachment
            x0 = wing_start_x + (wing_end_x - wing_start_x) * ix / (N_wing_x - 1);
            x1 = wing_start_x + (wing_end_x - wing_start_x) * (ix + 1) / (N_wing_x - 1);
            
            // Y progression: from body edge to tip (50mm span)
            s0 = iy / (N_wing_y - 1);
            s1 = (iy + 1) / (N_wing_y - 1);
            
            hw0 = body_hw(x0);
            hw1 = body_hw(x1);
            d0 = body_depth(x0);
            d1 = body_depth(x1);
            
            // Wing tip position
            y_tip0 = hw0 + wing_span;
            y_tip1 = hw1 + wing_span;
            
            // Current positions along span
            y0_start = hw0;
            y0_end = hw0 + s0 * wing_span;
            y1_start = hw1;
            y1_end = hw1 + s1 * wing_span;
            
            // Blade thickness tapers: thick at root, thin at tip
            thick0 = d0 * (1 - s0) * 0.3;
            thick1 = d1 * (1 - s1) * 0.3;
            
            // Create small tetrahedron-like sections that sweep along the fin
            hull() {
                // Root section (at body)
                translate([x0, y0_start, 0])
                sphere(r = 0.5);
                
                // Tip section (at wing tip)
                translate([x0, y0_end, -thick0 * 0.5])
                sphere(r = 0.3);
                
                // Next X station root
                translate([x1, y1_start, 0])
                sphere(r = 0.5);
                
                // Next X station tip
                translate([x1, y1_end, -thick1 * 0.5])
                sphere(r = 0.3);
            }
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
