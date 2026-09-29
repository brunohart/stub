#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

// The room's light (ADR-018). The card on a real table is lit by RealityKit from the room itself; this is the one
// surface its physically based material cannot draw: holographic film, whose colour depends on the angle it is seen
// from. It is `foil`'s thin film from Edition.metal, driven by the real view direction instead of the phone's tilt.
// Everywhere the foil is not, it is the physically based material exactly.
[[visible]]
void holographic(realitykit::surface_parameters params)
{
    constexpr sampler bilinear(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::linear);
    auto tex = params.textures();
    auto surface = params.surface();
    float2 uv = params.geometry().uv0();
    uv.y = 1.0 - uv.y;

    half4 colour = tex.base_color().sample(bilinear, uv);
    half metal = tex.metallic().sample(bilinear, uv).r;
    float3 view = normalize(params.geometry().view_direction());

    // A diffraction grating: bands of colour across the stamp that slide as the viewer moves.
    float t = dot(uv, float2(0.9, 0.5)) * 4.2 + view.x * 2.2 + view.z * 1.4;
    float3 film = 0.5 + 0.5 * cos(6.28318 * (t + float3(0.0, 0.33, 0.67)));
    half3 base = mix(colour.rgb, half3(mix(float3(colour.rgb), film, 0.38)), metal);

    surface.set_base_color(base);
    surface.set_normal(float3(realitykit::unpack_normal(tex.normal().sample(bilinear, uv).rgb)));
    surface.set_roughness(tex.roughness().sample(bilinear, uv).r);
    surface.set_metallic(metal);
    surface.set_opacity(tex.opacity().sample(bilinear, uv).r);
    surface.set_clearcoat(0.25h);
    surface.set_clearcoat_roughness(0.35h);
}
