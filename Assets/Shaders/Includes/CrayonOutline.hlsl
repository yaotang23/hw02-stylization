#ifndef HW_CRAYON_OUTLINE_INCLUDED
#define HW_CRAYON_OUTLINE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Noise.hlsl"

SAMPLER(hw_point_clamp_sampler);

float EyeDepth(float2 uv)
{
    return LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
}

float3 ReadNormal(UnityTexture2D tex, float2 uv)
{
    return SAMPLE_TEXTURE2D_LOD(tex.tex, hw_point_clamp_sampler, uv, 0).rgb * 2 - 1;
}

// Normalize the Roberts cross response by depth.
float DepthEdge(float2 uv, float2 o)
{
    float d0 = EyeDepth(uv + float2(-o.x, -o.y));
    float d1 = EyeDepth(uv + float2(o.x, -o.y));
    float d2 = EyeDepth(uv + float2(-o.x, o.y));
    float d3 = EyeDepth(uv + float2(o.x, o.y));
    float g = sqrt((d0 - d3) * (d0 - d3) + (d1 - d2) * (d1 - d2));
    return g / max(min(min(d0, d1), min(d2, d3)), 0.001);
}

// Sobel filter on the normal buffer.
float NormalEdge(UnityTexture2D tex, float2 uv, float2 o)
{
    float3 gx = 0;
    float3 gy = 0;
    const float kx[9] = { -1, 0, 1, -2, 0, 2, -1, 0, 1 };
    const float ky[9] = { -1, -2, -1, 0, 0, 0, 1, 2, 1 };
    int k = 0;
    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            float3 n = ReadNormal(tex, uv + float2(x, y) * o);
            gx += n * kx[k];
            gy += n * ky[k];
            k++;
        }
    }
    return sqrt(dot(gx, gx) + dot(gy, gy));
}

void CrayonOutline_float(float2 UV, UnityTexture2D MainTex, UnityTexture2D NormalTex,
    float Thickness, float DepthThreshold, float NormalThreshold,
    float Wobble, float WobbleFreq, float BoilFps, float Grain, float3 LineColor,
    out float3 Color)
{
    float3 scene = SAMPLE_TEXTURE2D(MainTex.tex, MainTex.samplerstate, UV).rgb;
#ifdef SHADERGRAPH_PREVIEW
    Color = scene;
#else
    float2 texel = 1.0 / _ScreenParams.xy;
    float2 o = texel * Thickness;
    float t = floor(_Time.y * BoilFps);

    // Jitter depth samples only; keep normal edges steady.
    float2 jitter = float2(ValueNoise(UV * WobbleFreq + t * 13.7), ValueNoise(UV * WobbleFreq + 41.3 + t * 7.9)) - 0.5;
    float2 wuv = UV + jitter * Wobble * texel.y * 10;

    float thick = Thickness * (0.75 + 0.5 * ValueNoise(UV * WobbleFreq * 0.5 + t * 3.1));
    float de = DepthEdge(wuv, texel * thick);
    float ne = NormalEdge(NormalTex, UV, o);

    // Suppress false depth edges on the ground near the horizon.
    float nz = saturate(ReadNormal(NormalTex, UV).z);
    float dth = DepthThreshold * (1 + 12 * smoothstep(0.4, 0.95, 1 - nz));
    float depthLine = smoothstep(dth, dth * 1.5, de);
    float normalLine = smoothstep(NormalThreshold, NormalThreshold * 1.3, ne);
    float edge = max(depthLine, normalLine * 0.85);

    // crayon grain eats into the line
    float g = ValueNoise(UV * _ScreenParams.xy * 0.35 + t * 5.0);
    edge *= lerp(1, smoothstep(0.05, 0.45, g), Grain);

    Color = lerp(scene, LineColor, saturate(edge));
#endif
}

#endif
