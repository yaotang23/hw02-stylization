#ifndef HW_PAPER_POST_INCLUDED
#define HW_PAPER_POST_INCLUDED

#include "Noise.hlsl"

// DayNightCycle or StyleSwitcher sets this: 0 = day, 1 = night.
float _NightBlend;

void PaperPost_float(float2 UV, UnityTexture2D MainTex, UnityTexture2D PaperTex,
    float PaperScale, float PaperStrength, float Warmth, float Vignette,
    float3 NightTint, float3 FogColor, float FogStrength,
    out float3 Color)
{
    float3 c = SAMPLE_TEXTURE2D(MainTex.tex, MainTex.samplerstate, UV).rgb;
#ifdef SHADERGRAPH_PREVIEW
    float night = 0;
    float aspect = 1;
    float time = 0;
#else
    float night = saturate(_NightBlend);
    float aspect = _ScreenParams.x / _ScreenParams.y;
    float time = _Time.y;
#endif
    float lum = Luminance(c);

    // Slightly desaturate and warm the daytime colors.
    float3 day = lerp(lum.xxx, c, 0.92);
    day *= float3(1 + 0.05 * Warmth, 1 + 0.015 * Warmth, 1 - 0.06 * Warmth);

    // Blue tint and drifting fog in the lower part of the screen.
    float3 nightCol = lerp(lum.xxx * NightTint, c * NightTint, 0.35);
    nightCol += smoothstep(0.75, 1.0, lum) * 0.15;
    float fog = Fbm(float2(UV.x * aspect * 2.5 + time * 0.05, UV.y * 4 - time * 0.02));
    float fogMask = smoothstep(0.35, 0.8, fog) * smoothstep(0.75, 0.15, UV.y);
    nightCol = lerp(nightCol, FogColor, fogMask * FogStrength);

    c = lerp(day, nightCol, night);

    float3 paper = SAMPLE_TEXTURE2D(PaperTex.tex, PaperTex.samplerstate, UV * float2(aspect, 1) * PaperScale).rgb;
    c *= lerp(1.0.xxx, paper, PaperStrength);

    float2 p = (UV - 0.5) * float2(aspect, 1);
    float v = smoothstep(1.1, 0.35, length(p));
    c *= lerp(1, v, saturate(Vignette * (1 + night)));

    Color = c;
}

#endif
