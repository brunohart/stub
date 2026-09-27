#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// The edition's surfaces (ADR-015). Three passes, one light. `light` is the light's direction across the card
// in points-space (x right, y down), with z taken as 1: at rest it comes from the upper left, the way the house's
// offset shadows fall, and tilting the card moves it. Nothing here moves on its own; there is no time.

static float edition_hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise, for the stock's fibre.
static float edition_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = edition_hash(i);
    float b = edition_hash(i + float2(1.0, 0.0));
    float c = edition_hash(i + float2(0.0, 1.0));
    float d = edition_hash(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// A broad soft band across the card, positioned by the light: where the sheen sits. 1 on the band, 0 far from it.
static float edition_sheen(float2 uv, float2 light, float width) {
    float along = dot(uv - 0.5, normalize(float2(0.8, 0.6)));
    float shift = (light.x + 0.45) * 0.9 + (light.y + 0.6) * 0.6;
    float t = (along + shift) * width;
    return exp(-t * t);
}

// How far a pixel of the inks layer is pressed into the stock. Ink is pressed in, darker ink a little further,
// so a word knocked out of a band of colour still has an edge.
static float edition_height(half4 s) {
    return float(s.a) - 0.6 * float(dot(s.rgb, half3(0.299h, 0.587h, 0.114h)));
}

// The stock. Grain on every card; cotton adds a long fibre; coated card has a satin gloss that follows the light.
[[ stitchable ]] half4 stock(float2 position, half4 color, float4 bounds, float2 light, float grain, float fibre, float gloss, float seed) {
    float2 uv = (position - bounds.xy) / max(bounds.zw, float2(1.0));
    float n = edition_hash(floor(position) + seed) - 0.5;
    // Cotton rag: short fibres, a little longer across than down, two octaves so it reads as paper, not grain.
    float f = edition_noise(position * float2(0.11, 0.32) + seed * 13.0) * 0.65
        + edition_noise(position * float2(0.31, 0.9) + seed * 7.0) * 0.35 - 0.5;
    float s = edition_sheen(uv, light, 2.2) * gloss;
    float3 rgb = float3(color.rgb) + n * grain + f * fibre + s;
    return half4(half3(clamp(rgb, 0.0, 1.0)) * color.a, color.a);
}

// The relief. The inks layer as a height field, lit: a highlight on the walls that face the light and a shadow on
// the walls that do not, and nothing on the flat, so a card is not washed out by its own lighting. The shading
// falls on the ink's edge and on the paper just beside it. `depth` is how hard the plate was pressed; `reach` is
// how wide the wall is, in points.
[[ stitchable ]] half4 relief(float2 position, SwiftUI::Layer layer, float2 light, float depth, float reach) {
    half4 c = layer.sample(position);
    float l = edition_height(layer.sample(position - float2(reach, 0.0)));
    float r = edition_height(layer.sample(position + float2(reach, 0.0)));
    float u = edition_height(layer.sample(position - float2(0.0, reach)));
    float d = edition_height(layer.sample(position + float2(0.0, reach)));
    // Pressed in: the surface is -depth * height, and its normal is (depth * dh/dx, depth * dh/dy, 1), scaled.
    float3 n = normalize(float3((r - l) * depth, (d - u) * depth, 2.0 * reach));
    float3 L = normalize(float3(light, 1.0));
    float shade = clamp((dot(n, L) - L.z) * 1.6, -1.0, 1.0);
    half4 tone = shade > 0.0
        ? half4(1.0h, 1.0h, 1.0h, 1.0h) * half(shade * 0.5)
        : half4(0.0h, 0.0h, 0.0h, 1.0h) * half(-shade * 0.55);
    return tone + c * (1.0h - tone.a);
}

// The foil. The layer is the foil's shape in white; this stamps it in metal. The stamp stands a little proud, so
// its edges catch the light; a fine brushed grain runs across the card; a broad sheen slides over it as the card
// turns. `holographic` 1 lays a thin-film rainbow over the metal whose colour depends on where the light is.
// `lightGround` 1 keeps the film darker, so holographic foil reads on pale card as well as dark.
[[ stitchable ]] half4 foil(float2 position, SwiftUI::Layer layer, float4 bounds, float2 light, half4 metal, float holographic, float lightGround) {
    half4 m = layer.sample(position);
    if (m.a < 0.002h) { return half4(0.0h); }
    float2 uv = (position - bounds.xy) / max(bounds.zw, float2(1.0));
    float e = 0.6;
    float l = float(layer.sample(position - float2(e, 0.0)).a);
    float r = float(layer.sample(position + float2(e, 0.0)).a);
    float u = float(layer.sample(position - float2(0.0, e)).a);
    float d = float(layer.sample(position + float2(0.0, e)).a);
    // Raised: the surface is +height, so the normal leans the other way from the relief's.
    float3 n = normalize(float3(-(r - l) * 1.4, -(d - u) * 1.4, 2.0 * e));
    float3 L = normalize(float3(light, 1.0));
    float3 H = normalize(L + float3(0.0, 0.0, 1.0));
    float spec = pow(max(dot(n, H), 0.0), 48.0);
    float edge = clamp((dot(n, L) - L.z) * 2.0, -1.0, 1.0);
    float sheen = edition_sheen(uv, light, 3.2);
    float brush = edition_hash(float2(0.0, floor(position.y * 2.0))) - 0.5;

    float3 base = float3(metal.rgb);
    float3 colour;
    if (holographic > 0.5) {
        // A diffraction grating: fine bands of colour across the stamp that slide as the light moves.
        float t = dot(uv, float2(0.9, 0.5)) * 4.2 + light.x * 2.2 + light.y * 1.4;
        float3 film = 0.5 + 0.5 * cos(6.28318 * (t + float3(0.0, 0.33, 0.67)));
        film = mix(film, film * 0.62, lightGround);
        colour = mix(base, film, 0.38) * (0.78 + 0.55 * sheen);
    } else {
        colour = base * (0.62 + 0.72 * sheen);
    }
    // Holographic film is smooth; only metal foil shows the brush.
    colour += spec * 0.35 + edge * 0.18 + brush * (holographic > 0.5 ? 0.015 : 0.045);
    colour = clamp(colour, 0.0, 1.0);
    return half4(half3(colour) * m.a, m.a);
}
