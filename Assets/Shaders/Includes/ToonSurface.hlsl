#ifndef HW_TOON_SURFACE_INCLUDED
#define HW_TOON_SURFACE_INCLUDED

#include "Noise.hlsl"

float3 ToonRamp(float diffuse, float3 highlight, float3 midtone, float3 shadow, float2 thresholds, float smoothness)
{
    float w = max(smoothness * 0.5, 0.0001);
    float toMid = smoothstep(thresholds.x - w, thresholds.x + w, diffuse);
    float toHigh = smoothstep(thresholds.y - w, thresholds.y + w, diffuse);
    return lerp(lerp(shadow, midtone, toMid), highlight, toHigh);
}

void ToonSurface_float(float3 WorldPos, float3 WorldNormal, float2 UV,
    float3 Highlight, float3 Midtone, float3 Shadow, float ShadowThreshold, float HighlightThreshold, float Smoothness,
    UnityTexture2D ShadowTex, float ShadowScale, float ShadowStrength,
    float3 RimColor, float RimPower, float RimStrength,
    float3 SpecColor, float Gloss, float SpecStrength,
    out float3 Color)
{
    float2 Thresholds = float2(ShadowThreshold, HighlightThreshold);
    float3 N = normalize(WorldNormal);
#ifdef SHADERGRAPH_PREVIEW
    float d = saturate(dot(N, normalize(float3(0.5, 0.5, -0.3))));
    Color = ToonRamp(d, Highlight, Midtone, Shadow, Thresholds, Smoothness);
#else
    float3 V = normalize(GetWorldSpaceViewDir(WorldPos));

    Light mainLight = GetMainLight(TransformWorldToShadowCoord(WorldPos));
    float nl = saturate(dot(N, mainLight.direction));
    float mainDiffuse = nl * mainLight.shadowAttenuation * mainLight.distanceAttenuation;

    // point / spot lights: add to the banding and tint by their color
    float addDiffuse = 0;
    float3 addColor = 0;
    uint count = GetAdditionalLightsCount();
    for (uint i = 0u; i < count; ++i)
    {
        Light light = GetAdditionalLight(i, WorldPos, half4(1, 1, 1, 1));
        float d = saturate(dot(N, light.direction)) * light.distanceAttenuation * light.shadowAttenuation;
        float band = smoothstep(0.15, 0.2, d);
        addDiffuse += d;
        addColor += band * light.color;
    }

    float diffuse = saturate(mainDiffuse + addDiffuse * 0.5);
    float3 col = ToonRamp(diffuse, Highlight, Midtone, Shadow, Thresholds, Smoothness);

    // crayon strokes in the shadow band, sampled with object uv
    float stroke = 1 - SAMPLE_TEXTURE2D(ShadowTex.tex, ShadowTex.samplerstate, UV * ShadowScale).r;
    float w = max(Smoothness * 0.5, 0.0001);
    float inShadow = 1 - smoothstep(Thresholds.x - w, Thresholds.x + w, diffuse);
    float3 hatched = lerp(Midtone, Shadow, saturate(stroke * 1.4));
    col = lerp(col, hatched, inShadow * ShadowStrength);

    col += Highlight * addColor * 0.2;

    // rim only on the lit side
    float rim = pow(1 - saturate(dot(N, V)), RimPower);
    float rimMask = smoothstep(0.5, 0.55, rim) * smoothstep(0.0, 0.2, nl);
    col = lerp(col, RimColor, rimMask * RimStrength);

    // hard blinn-phong spot
    float3 H = normalize(mainLight.direction + V);
    float spec = pow(saturate(dot(N, H)), Gloss * 128 + 1) * mainLight.shadowAttenuation;
    col = lerp(col, SpecColor, smoothstep(0.5, 0.55, spec) * SpecStrength);

    Color = col;
#endif
}

void HeroGlow_float(float3 BaseColor, float3 WorldPos, float3 WorldNormal, float2 UV,
    float3 GlowA, float3 GlowB, float GlowStrength, float GlowFps,
    out float3 Color)
{
#ifdef SHADERGRAPH_PREVIEW
    float3 V = float3(0, 0, -1);
    float t = 0;
#else
    float3 V = normalize(GetWorldSpaceViewDir(WorldPos));
    float t = SteppedTime(GlowFps);
#endif
    float3 N = normalize(WorldNormal);
    float n = Fbm(UV * 5 + t * 0.8);

    float3 glow = lerp(GlowA, GlowB, 0.5 + 0.5 * sin(t * 3.0 + n * 6.0));
    float fres = pow(1 - saturate(dot(N, V)), 2.0);

    // bright stripe running up the object
    float s = frac(UV.y * 1.5 - t * 0.5 + n * 0.25);
    float stripe = smoothstep(0.0, 0.05, s) * (1 - smoothstep(0.12, 0.17, s));

    float amount = saturate(smoothstep(0.35, 0.45, fres + n * 0.3) + stripe * 0.9);
    Color = lerp(BaseColor, glow, amount * GlowStrength);
}

void HeroVertex_float(float3 PositionOS, float BobHeight, float BobSpeed, float SwayAngle, float StepFps, out float3 Out)
{
#ifdef SHADERGRAPH_PREVIEW
    Out = PositionOS;
#else
    float t = SteppedTime(StepFps);
    float a = radians(SwayAngle) * sin(t * BobSpeed * 0.5) * saturate(PositionOS.y + 0.5);
    float s = sin(a);
    float c = cos(a);
    float3 p = PositionOS;
    p.xy = float2(c * p.x - s * p.y, s * p.x + c * p.y);
    p.y += sin(t * BobSpeed) * BobHeight;
    Out = p;
#endif
}

#endif
