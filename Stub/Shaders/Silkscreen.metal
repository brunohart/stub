#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// The silkscreen pass. A photograph printed onto parchment: a little desaturated, a little more
// contrast, multiplied against the paper so the paper shows through. No grain (ADR-017).
// `strength` 0 = the photograph, 1 = fully printed. Reward attention by easing strength toward 0.
[[ stitchable ]] half4 silkscreen(float2 position, half4 color, half4 paper, float strength) {
    half a = max(color.a, half(0.0001));
    half3 rgb = color.rgb / a; // un-premultiply
    half l = dot(rgb, half3(0.299h, 0.587h, 0.114h));
    half3 desat = mix(rgb, half3(l), half(0.18 * strength));
    half3 contrasted = (desat - 0.5h) * half(1.0 + 0.08 * strength) + 0.5h;
    half3 printed = contrasted * paper.rgb;
    half3 out = clamp(mix(rgb, printed, half(strength)), 0.0h, 1.0h);
    return half4(out * color.a, color.a);
}

// The misregistered plate. One colour pass that did not line up. We sample the layer's own alpha
// shifted by `offset` and lay a translucent ink of that shape under the artwork.
[[ stitchable ]] half4 misregister(float2 position, SwiftUI::Layer layer, float2 offset, half4 ink, float amount) {
    half4 base = layer.sample(position);
    half4 shifted = layer.sample(position - offset);
    half plateAlpha = shifted.a * half(amount);
    // Ink shows where the plate is and the artwork is not (or is translucent).
    half3 plate = ink.rgb * plateAlpha;
    half3 rgb = base.rgb + plate * (1.0h - base.a);
    half a = base.a + plateAlpha * (1.0h - base.a);
    return half4(rgb, a);
}

