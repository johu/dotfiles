#version 300 es
precision mediump float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 FragColor;

// Contrast Adaptive Sharpening approximation. Sharpens edges based on local
// min/max contrast so flat areas are left alone. 0.0 = off, ~1.0 = strong.
const float sharpness = 0.4;

void main() {
    vec2 texel = 1.0 / vec2(textureSize(tex, 0));

    vec3 c = texture(tex, v_texcoord).rgb;
    vec3 n = texture(tex, v_texcoord + vec2(0.0, -texel.y)).rgb;
    vec3 s = texture(tex, v_texcoord + vec2(0.0,  texel.y)).rgb;
    vec3 w = texture(tex, v_texcoord + vec2(-texel.x, 0.0)).rgb;
    vec3 e = texture(tex, v_texcoord + vec2( texel.x, 0.0)).rgb;

    vec3 mn = min(c, min(min(n, s), min(w, e)));
    vec3 mx = max(c, max(max(n, s), max(w, e)));

    vec3 amp = clamp(min(mn, 1.0 - mx) / max(mx - mn, 1e-4), 0.0, 1.0);
    vec3 weight = -1.0 / mix(vec3(8.0), vec3(5.0), amp) * sharpness;

    vec3 sharpened = (n + s + w + e) * weight + c * (1.0 - 4.0 * weight);
    FragColor = vec4(clamp(sharpened, 0.0, 1.0), 1.0);
}
