// PSX_POST — full-screen overlay. Put it on a ColorRect that covers the screen.
// Makes the image look like a PS1 running on an old CRT TV:
//   - curved glass, colour fringing, scanlines, dark corners, a little static
//   - 15-bit color: fewer shades per channel + a 4x4 dither pattern
// Every effect has a slider; set it to 0 to turn that effect off.
shader_type canvas_item;

// Everything already drawn on screen (the 3D world) — read with no smoothing.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

group_uniforms PS1_Color;
// Shades per color channel. 32 = authentic PS1. Try 16 or 8 for a grittier look.
uniform float color_levels : hint_range(2.0, 256.0) = 32.0;
// 0 = no dithering, 1 = normal, 2 = heavy.
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;

group_uniforms CRT;
// How bulged the "glass" is. 0 = flat screen.
uniform float curvature : hint_range(0.0, 0.2) = 0.04;
// Red/blue split toward the edges, in game pixels.
uniform float chromatic_aberration : hint_range(0.0, 3.0) = 1.0;
// Darkens every other row of pixels.
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.15;
// Darkens the corners.
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;
// Flickering TV static.
uniform float noise_strength : hint_range(0.0, 0.3) = 0.04;
group_uniforms;

// Classic 4x4 Bayer ordered-dither thresholds (values 0..15).
const mat4 BAYER = mat4(
	vec4( 0.0, 12.0,  3.0, 15.0),
	vec4( 8.0,  4.0, 11.0,  7.0),
	vec4( 2.0, 14.0,  1.0, 13.0),
	vec4(10.0,  6.0,  9.0,  5.0)
);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Bend the picture like curved CRT glass.
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	centered *= 1.0 + curvature * dot(centered, centered);
	vec2 uv = centered * 0.5 + 0.5;

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);  // outside the bent screen = black border
	} else {
		// Colour fringing: red and blue sampled slightly apart, more toward the edges.
		vec2 offset = centered * chromatic_aberration * SCREEN_PIXEL_SIZE;
		vec3 color;
		color.r = texture(screen_tex, uv + offset).r;
		color.g = texture(screen_tex, uv).g;
		color.b = texture(screen_tex, uv - offset).b;

		// Scanlines, dark corners and static.
		ivec2 pixel = ivec2(FRAGCOORD.xy);
		if (pixel.y % 2 == 1) {
			color *= 1.0 - scanline_strength;
		}
		color *= 1.0 - vignette_strength * dot(centered, centered) * 0.5;
		color += (hash(FRAGCOORD.xy + fract(TIME) * 100.0) - 0.5) * noise_strength;

		// Dither, then crush to the limited PS1 palette.
		ivec2 cell = pixel % 4;
		float threshold = BAYER[cell.x][cell.y] / 16.0 - 0.5;
		color += threshold * dither_strength / color_levels;
		color = floor(color * (color_levels - 1.0) + 0.5) / (color_levels - 1.0);
		COLOR = vec4(color, 1.0);
	}
}
