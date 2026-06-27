shader_type canvas_item;

const float TOLERANCE = 1.0;
const int PALETTE_SIZE = 62;

// indices into PALETTE to skip during matching — tune freely
const int IGNORE_COUNT = 7;
bool is_ignored(int i) {
    return i == 26 // bright vivid red
        || i == 34 // bright vivid orange
        || i == 35 // bright vivid orange
        || i == 36 // bright vivid orange-red
        || i == 37 // bright vivid orange
        || i == 38 // bright vivid orange-red
        || i == 58; // bright mid cyan
}

const vec3 PALETTE[62] = {
    // near black
    vec3(0.047, 0.043, 0.078), // [0]
    vec3(0.055, 0.055, 0.098), // [1]
    vec3(0.059, 0.071, 0.110), // [2]
    vec3(0.063, 0.012, 0.024), // [3]
    vec3(0.071, 0.063, 0.114), // [4]
    vec3(0.082, 0.082, 0.082), // [5]
    vec3(0.082, 0.114, 0.118), // [6]

    // dark gray
    vec3(0.125, 0.129, 0.125), // [7]
    vec3(0.141, 0.141, 0.137), // [8]

    // mid gray
    vec3(0.435, 0.467, 0.463), // [9]

    // light gray
    vec3(0.800, 0.776, 0.780), // [10]

    // dark red / dark pink-red
    vec3(0.188, 0.000, 0.004), // [11]
    vec3(0.204, 0.122, 0.129), // [12]
    vec3(0.298, 0.051, 0.000), // [13]

    // mid red / pink-red / purple
    vec3(0.161, 0.106, 0.118), // [14]
    vec3(0.180, 0.098, 0.192), // [15]
    vec3(0.259, 0.153, 0.141), // [16]
    vec3(0.310, 0.129, 0.239), // [17]
    vec3(0.329, 0.192, 0.169), // [18]
    vec3(0.380, 0.137, 0.231), // [19]
    vec3(0.380, 0.173, 0.251), // [20]
    vec3(0.510, 0.161, 0.212), // [21]
    vec3(0.510, 0.208, 0.251), // [22]
    vec3(0.616, 0.561, 0.569), // [23]
    vec3(0.655, 0.267, 0.318), // [24]

    // bright vivid red / orange-red
    vec3(0.439, 0.067, 0.000), // [25]
    vec3(0.835, 0.196, 0.024), // [26]

    // orange
    vec3(0.267, 0.149, 0.078), // [27]
    vec3(0.357, 0.235, 0.184), // [28]
    vec3(0.400, 0.278, 0.133), // [29]
    vec3(0.416, 0.341, 0.227), // [30]
    vec3(0.471, 0.455, 0.341), // [31]
    vec3(0.522, 0.541, 0.435), // [32]
    vec3(0.529, 0.318, 0.165), // [33]
    vec3(0.698, 0.459, 0.094), // [34]
    vec3(0.796, 0.565, 0.125), // [35]
    vec3(0.988, 0.557, 0.000), // [36]
    vec3(0.980, 0.702, 0.216), // [37]
    vec3(1.000, 0.706, 0.322), // [38]

    // yellow-green
    vec3(0.569, 0.616, 0.286), // [39]
    vec3(0.384, 0.518, 0.267), // [40]

    // green
    vec3(0.200, 0.329, 0.239), // [41]
    vec3(0.251, 0.427, 0.235), // [42]

    // teal
    vec3(0.129, 0.192, 0.192), // [43]
    vec3(0.153, 0.235, 0.212), // [44]
    vec3(0.208, 0.263, 0.275), // [45]
    vec3(0.286, 0.325, 0.314), // [46]
    vec3(0.506, 0.573, 0.565), // [47]

    // cyan
    vec3(0.067, 0.184, 0.227), // [48]
    vec3(0.071, 0.247, 0.278), // [49]
    vec3(0.094, 0.333, 0.388), // [50]
    vec3(0.098, 0.133, 0.137), // [51]
    vec3(0.118, 0.424, 0.498), // [52]
    vec3(0.137, 0.212, 0.239), // [53]
    vec3(0.169, 0.592, 0.639), // [54]
    vec3(0.231, 0.780, 0.776), // [55]
    vec3(0.239, 0.318, 0.341), // [56]
    vec3(0.337, 0.416, 0.439), // [57]
    vec3(0.545, 0.906, 0.902), // [58]

    // blue-cyan
    vec3(0.075, 0.114, 0.161), // [59]
    vec3(0.094, 0.157, 0.196), // [60]

    // placeholder to keep PALETTE_SIZE at 62
    vec3(0.180, 0.204, 0.196) // [61]
	};

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    if (col.a < 0.1) discard;
    vec3 rgb = col.rgb;
    float best_dist = 1e9;
    vec3 best_color = rgb;
    for (int i = 0; i < PALETTE_SIZE; i++) {
        if (is_ignored(i)) continue;
        vec3 diff = rgb - PALETTE[i];
        float dist = dot(diff, diff);
        if (dist < best_dist) {
            best_dist = dist;
            best_color = PALETTE[i];
        }
    }
    vec3 final_color = mix(rgb, best_color, TOLERANCE);
    COLOR = vec4(final_color, col.a);
}