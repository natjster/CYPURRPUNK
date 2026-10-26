// PSX_LIT — put this on every 3D object to get the PS1 / RuneScape look.
// It does these retro tricks:
//   1. VERTEX JITTER: snaps every corner of every triangle to a coarse screen grid,
//      so models wobble and "swim" slightly as the camera moves.
//   2. AFFINE TEXTURES: maps textures without perspective correction, so they warp
//      and bend on big surfaces — exactly like the original hardware.
//   3. FLAT SHADING: every triangle gets one solid shade, like Old School RuneScape.
//   4. EMISSION: makes things glow (neon signs, lamps, headlights). Energy above ~1
//      triggers the bloom/glow set up in the WorldEnvironment.
shader_type spatial;

render_mode diffuse_lambert, specular_schlick_ggx;

// --- Color & texture ---
// Base tint. Multiplied with the texture.
uniform vec4 albedo_color : source_color = vec4(1.0);
// Optional texture. Leave empty for a flat color.
// filter_nearest_mipmap = crunchy pixels up close (no smoothing), but far away it switches to
// pre-shrunk copies of the texture (mipmaps) so distant windows don't sparkle and crawl.
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_nearest_mipmap, repeat_enable;
// How many times the texture repeats across the surface.
uniform vec2 uv_scale = vec2(1.0, 1.0);
// World UVs: the texture is laid out by real-world metres instead of per object, so windows
// stay the same size on every building no matter how big it is (used by the city generator).
uniform bool world_uv = false;
// With world_uv on: how many texture repeats per metre (0.25 = one texture every 4 m).
uniform float world_uv_scale = 0.25;
// Per-object colour tint, set from code with set_instance_shader_parameter("instance_tint", ...).
// Lets every building/sign share ONE material but still look different. Also tints the glow.
instance uniform vec4 instance_tint : source_color = vec4(1.0);

// --- Glow ---
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// 0 = no glow. 2-6 = neon.
uniform float emission_energy : hint_range(0.0, 16.0) = 1.0;
// Makes the BRIGHT pixels of the texture glow (e.g. lit windows at night). 0 = off.
uniform float texture_glow : hint_range(0.0, 8.0) = 0.0;

// --- Shine (for wet streets) ---
// 0 = matte, 0.5 = wet sheen. Leave at 0 for most things.
uniform float specular : hint_range(0.0, 1.0) = 0.0;
// Low = sharp mirror-ish highlights, high = soft.
uniform float roughness : hint_range(0.0, 1.0) = 1.0;

// --- Retro effects ---
// The grid vertices snap to. LOWER numbers = MORE wobble. (320x240 = subtle, 160x120 = classic, 80x60 = chaos)
uniform vec2 snap_resolution = vec2(160.0, 120.0);
// Turn the texture-warping effect on/off.
uniform bool affine_mapping = true;
// One flat shade per triangle (RuneScape look). Off = smooth shading.
uniform bool flat_shading = true;
// Game-wide switch from the Settings menu ("PS1 WOBBLE"): 1 = wobble + warp on, 0 = both off.
// It's a "global" uniform, defined in Project Settings > Shader Globals, so one setting
// changes every PS1 material at once.
global uniform float psx_wobble;

// Carries (uv * w, w) from vertex to fragment so we can undo perspective correction.
varying vec3 affine_uv;

void vertex() {
	if (world_uv) {
		// Pick the two world axes this face lies along, so the texture never stretches.
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 facing = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
		if (facing.y > 0.5) {
			UV = world_pos.xz;                       // roofs and floors
		} else if (facing.x > 0.5) {
			UV = vec2(world_pos.z, -world_pos.y);    // walls facing east/west
		} else {
			UV = vec2(world_pos.x, -world_pos.y);    // walls facing north/south
		}
		UV *= world_uv_scale;
	} else {
		UV *= uv_scale;
	}

	// Work out where this vertex lands on screen (clip space).
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// Snap its on-screen x/y to the low-res grid -> vertex jitter.
	vec2 grid = snap_resolution * 0.5;
	// On widescreen the picture is wider than 4:3, so widen the grid to match:
	// keeps the wobble the same size (square steps) on every monitor shape.
	grid.x *= (VIEWPORT_SIZE.x / VIEWPORT_SIZE.y) / (4.0 / 3.0);
	vec2 ndc = clip.xy / clip.w;
	ndc = mix(ndc, round(ndc * grid) / grid, psx_wobble);
	clip.xy = ndc * clip.w;
	POSITION = clip;

	// Pre-multiply UV by depth; dividing it back out per-pixel gives affine (warpy) mapping.
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = (affine_mapping && psx_wobble > 0.5) ? affine_uv.xy / affine_uv.z : UV;
	vec4 tex = texture(albedo_texture, uv);
	ALBEDO = albedo_color.rgb * tex.rgb * instance_tint.rgb;
	EMISSION = emission_color.rgb * emission_energy * instance_tint.rgb;
	float brightness = max(tex.r, max(tex.g, tex.b));
	EMISSION += tex.rgb * texture_glow * smoothstep(0.5, 0.8, brightness);
	SPECULAR = specular;
	ROUGHNESS = roughness;

	if (flat_shading) {
		// Work out the triangle's true facing from how the surface changes across
		// neighbouring pixels — every pixel of the triangle gets the same normal.
		NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	}
}
