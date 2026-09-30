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

// How rubbed a point of the card is, 0 to 1: frayed along the cut edge near each corner, not stained. Lighter fibre
// hugs the rounded outline for a few points and fades out along the sides away from the corner. `p` and `size` in card
// points.
static float edition_rub(float2 p, float2 size) {
    float2 q = abs(p - size * 0.5) - (size * 0.5 - 10.0);
    float inside = -(length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 10.0);
    float2 near = min(p, size - p);
    float corner = 1.0 - smoothstep(8.0, 34.0, length(near));
    float fray = 1.0 - smoothstep(0.0, 3.5 + edition_noise(p * 0.6) * 3.0, inside);
    return fray * corner;
}

// What the foxing multiplies a point by: 1 clear of every spot, rust at a spot's core. Each spot (x, y, radius,
// strength, in card points) is a small stain in the paper, soft-edged, a little darker at its core.
static float3 edition_fox(float2 p, device const float *spots, int count) {
    float3 f = float3(1.0);
    for (int i = 0; i + 3 < count; i += 4) {
        float2 c = float2(spots[i], spots[i + 1]);
        float r = spots[i + 2];
        float d = distance(p, c);
        if (d > r * 2.6) { continue; }
        float edge = r * (1.0 + (edition_noise(p * 0.8 + c) - 0.5) * 0.7);
        float core = 1.0 - smoothstep(r * 0.2, edge, d);
        float halo = (1.0 - smoothstep(edge, r * 2.6, d)) * 0.3;
        f *= mix(float3(1.0), float3(0.8, 0.62, 0.44), spots[i + 3] * max(core, halo));
    }
    return f;
}

// Patina (brief §6.2): what the stock has earned since the night it was seen. `warmth` yellows the ground, `wear`
// rubs the four corners light, and the spots are foxing. All three come from `Patina` in Swift, which makes them zero at
// age 0, and the caller skips this entirely there, so a new card is exactly the stock.
static float3 edition_patina(float3 rgb, float2 p, float2 size, float warmth, float wear, device const float *spots, int count) {
    rgb = mix(rgb, rgb * float3(1.0, 0.95, 0.82), warmth);
    float3 rubbed = mix(rgb, float3(0.93, 0.91, 0.86), 0.6);
    rgb = mix(rgb, rubbed, edition_rub(p, size) * wear);
    return rgb * edition_fox(p, spots, count);
}

// The stock. Cotton has a long soft fibre; coated card has a satin gloss that follows the light. No per-pixel grain:
// speckle over a whole card reads as noise on a screen, not as paper (ADR-017). `age` in years; at 0 there is no patina.
[[ stitchable ]] half4 stock(float2 position, half4 color, float4 bounds, float2 light, float fibre, float gloss, float seed,
                             float age, float warmth, float wear, device const float *spots, int count) {
    float2 uv = (position - bounds.xy) / max(bounds.zw, float2(1.0));
    // Cotton rag: short fibres, a little longer across than down, two octaves so it reads as paper, not grain.
    float f = edition_noise(position * float2(0.11, 0.32) + seed * 13.0) * 0.65
        + edition_noise(position * float2(0.31, 0.9) + seed * 7.0) * 0.35 - 0.5;
    float s = edition_sheen(uv, light, 2.2) * gloss;
    float3 rgb = float3(color.rgb) + f * fibre;
    if (age > 0.0) {
        rgb = edition_patina(rgb, position - bounds.xy, bounds.zw, warmth, wear, spots, count);
    }
    rgb += s;
    return half4(half3(clamp(rgb, 0.0, 1.0)) * color.a, color.a);
}

// The patina on what is printed over the stock (2026-09-30). Until then it lived only in the stock, under the plates,
// so an inked corner or a spot under a band of ink stayed pristine. Where a thumb has rubbed a corner the ink is worn
// through to the stock, which is rubbed light under it. Foxing is in the paper, so it comes up through ink, which is
// thin, a little fainter than on bare stock; `fox` 0 for foil, which is metal and never shows it. Warmth stays in the
// stock: the paper yellows, the ink keeps its colour. `origin` is where this layer sits on the card and `card` the
// card's size, both in points, so a layer smaller than the card ages in the card's places.
[[ stitchable ]] half4 aged(float2 position, half4 color, float4 bounds, float2 origin, float2 card, float wear, float fox,
                            device const float *spots, int count) {
    if (color.a < 0.002h) { return color; }
    float2 p = position - bounds.xy + origin;
    float3 rgb = float3(color.rgb);
    if (fox > 0.0) { rgb *= mix(float3(1.0), edition_fox(p, spots, count), fox); }
    float worn = edition_rub(p, card) * wear;
    return half4(half3(rgb), color.a) * half(1.0 - worn);
}

// The relief. The inks layer as a height field, lit: a highlight on the walls that face the light and a shadow on
// the walls that do not, and nothing on the flat, so a card is not washed out by its own lighting. The shading
// falls on the ink's edge and on the paper just beside it. `depth` is how hard the plate was pressed; `reach` is
// how wide the wall is, in points. `wet` 1 is ink just pulled: a tight gloss over the inked areas, a narrow band that
// slides with the one light, drying away to 0 as the press's timeline decays it (ADR-016). At 0 it costs nothing.
[[ stitchable ]] half4 relief(float2 position, SwiftUI::Layer layer, float4 bounds, float2 light, float depth, float reach, float wet) {
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
    half4 out = tone + c * (1.0h - tone.a);
    if (wet > 0.001) {
        float2 uv = (position - bounds.xy) / max(bounds.zw, float2(1.0));
        float3 H = normalize(L + float3(0.0, 0.0, 1.0));
        float glint = pow(max(dot(n, H), 0.0), 40.0);
        float gloss = wet * float(c.a) * (edition_sheen(uv, light, 7.0) * 0.5 + glint * 0.18);
        out.rgb = min(out.rgb + half3(gloss) * out.a, out.a);
    }
    return out;
}

// The foil. The layer is the foil's shape in white; this stamps it in metal. The stamp stands a little proud, so
// its edges catch the light; fine brush lines run across the metal; a broad sheen slides over it as the card
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

// The flood (ADR-016, brief §5.6): new inks spreading outward from where a draw-down was dropped, the way ink wicks
// into paper. The card in the new inks is revealed where this returns its colour: inside `radius` of `origin`, with an
// edge `soft` points wide pushed in and out by the stock's own noise, `wander` points either way. Cotton wicks wide and
// soft; coated card holds a crisper edge. It is the consequence of a drop and it ends; there is no time here either.
[[ stitchable ]] half4 flood(float2 position, half4 color, float2 origin, float radius, float soft, float wander, float seed) {
    float n = edition_noise(position * 0.06 + seed) - 0.5;
    float fine = edition_noise(position * 0.19 + seed * 3.1) - 0.5;
    float d = distance(position, origin) + (n * 0.75 + fine * 0.25) * 2.0 * wander;
    float a = 1.0 - smoothstep(radius - soft, radius + soft, d);
    return color * half(a);
}
