Shader "Skybox/Sketch Sky"
{
    Properties
    {
        _DayZenith ("Day Zenith", Color) = (0.76, 0.86, 0.96, 1)
        _DayHorizon ("Day Horizon", Color) = (0.98, 0.97, 0.94, 1)
        _SunsetZenith ("Sunset Zenith", Color) = (0.6, 0.58, 0.78, 1)
        _SunsetHorizon ("Sunset Horizon", Color) = (0.99, 0.7, 0.48, 1)
        _NightZenith ("Night Zenith", Color) = (0.07, 0.08, 0.18, 1)
        _NightHorizon ("Night Horizon", Color) = (0.22, 0.26, 0.45, 1)
        _GroundDay ("Ground Day", Color) = (0.93, 0.9, 0.84, 1)
        _GroundNight ("Ground Night", Color) = (0.4, 0.44, 0.6, 1)
        _SunColor ("Sun Color", Color) = (1, 0.85, 0.5, 1)
        _MoonColor ("Moon Color", Color) = (0.94, 0.95, 1, 1)
        _LineColor ("Line Color", Color) = (0.17, 0.14, 0.12, 1)
        _SunSize ("Sun Size", Range(0.02, 0.3)) = 0.1
        _MoonSize ("Moon Size", Range(0.02, 0.3)) = 0.07
        _Bands ("Sky Bands", Range(1, 10)) = 5
        _CloudScale ("Cloud Scale", Float) = 1.4
        _CloudSpeed ("Cloud Speed", Float) = 0.03
        _CloudCover ("Cloud Cover", Range(0, 1)) = 0.42
        _StarDensity ("Star Density", Range(0, 1)) = 0.3
        _BoilFps ("Boil Fps", Float) = 6
    }

    SubShader
    {
        Tags { "Queue" = "Background" "RenderType" = "Background" "PreviewType" = "Skybox" "RenderPipeline" = "UniversalPipeline" }
        Cull Off
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Includes/Noise.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _DayZenith, _DayHorizon, _SunsetZenith, _SunsetHorizon, _NightZenith, _NightHorizon;
                float4 _GroundDay, _GroundNight, _SunColor, _MoonColor, _LineColor;
                float _SunSize, _MoonSize, _Bands, _CloudScale, _CloudSpeed, _CloudCover, _StarDensity, _BoilFps;
            CBUFFER_END

            // set by DayNightCycle
            float3 _SunDir;
            float3 _MoonDir;
            float _Sunset;
            float _NightBlend;

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 dir : TEXCOORD0;
            };

            Varyings vert(Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.dir = v.positionOS.xyz;
                return o;
            }

            // disk with a wobbly crayon edge, x = fill, y = outline
            float2 Disk(float3 d, float3 center, float size, float t)
            {
                float a = acos(clamp(dot(d, center), -1, 1));
                float r = size + (ValueNoise(d.xz * 60 + d.y * 30 + t * 7) - 0.5) * size * 0.15;
                float fill = 1 - smoothstep(r - 0.003, r, a);
                float ring = smoothstep(r - size * 0.14, r - size * 0.08, a) * fill;
                return float2(fill, ring);
            }

            float4 frag(Varyings i) : SV_Target
            {
                float3 d = normalize(i.dir);
                float h = d.y;
                float up = saturate(h);
                float night = saturate(_NightBlend);
                float sunset = saturate(_Sunset);
                float t = SteppedTime(_BoilFps);

                float3 sunDir = dot(_SunDir, _SunDir) > 0.01 ? normalize(_SunDir) : normalize(float3(0.4, 0.6, -0.5));
                float3 moonDir = dot(_MoonDir, _MoonDir) > 0.01 ? normalize(_MoonDir) : -sunDir;

                float3 zenith = lerp(lerp(_DayZenith.rgb, _SunsetZenith.rgb, sunset * (1 - night)), _NightZenith.rgb, night);
                float3 horizon = lerp(lerp(_DayHorizon.rgb, _NightHorizon.rgb, night), _SunsetHorizon.rgb, sunset);

                // sky gradient in a few soft bands, like layers of colored pencil
                float g = pow(up, 0.6) * _Bands;
                g = (floor(g) + smoothstep(0.35, 0.65, frac(g))) / _Bands;
                float3 col = lerp(horizon, zenith, g);

                // warm glow on the sun side at sunset
                float toSun = saturate(dot(d, sunDir));
                col = lerp(col, _SunsetHorizon.rgb, sunset * smoothstep(0.5, 1.0, toSun) * (1 - up) * 0.7);

                // stars, only at night and above the horizon
                float2 sp = float2(atan2(d.x, d.z), asin(h)) * 45;
                float2 cell = floor(sp);
                float2 f = frac(sp) - 0.5 + (float2(Hash21(cell + 7.1), Hash21(cell + 3.3)) - 0.5) * 0.6;
                float star = step(1 - _StarDensity * 0.25, Hash21(cell)) * (1 - smoothstep(0.04, 0.1, length(f)));
                float twinkle = step(0.25, Hash21(cell + floor(t * 2)));
                col = lerp(col, float3(1, 0.98, 0.9), star * twinkle * night * smoothstep(0.05, 0.2, h));

                // sun and moon
                float2 sunD = Disk(d, sunDir, _SunSize, t) * (1 - night) * step(-0.05, sunDir.y);
                col = lerp(col, _SunColor.rgb, sunD.x);
                col = lerp(col, _LineColor.rgb, sunD.y);

                float2 moonD = Disk(d, moonDir, _MoonSize, t) * night * step(-0.05, moonDir.y);
                float3 side = normalize(cross(moonDir, float3(0, 1, 0)) + 0.0001);
                float2 shade = Disk(d, normalize(moonDir + side * _MoonSize * 0.7), _MoonSize * 0.95, t);
                float3 moonCol = lerp(_MoonColor.rgb, _MoonColor.rgb * 0.7, shade.x);
                col = lerp(col, moonCol, moonD.x);
                col = lerp(col, _LineColor.rgb, moonD.y);

                // clouds drifting over the dome, two tones with a line on the edge
                float2 cp = d.xz / (h + 0.25) * _CloudScale + float2(_Time.y * _CloudSpeed, 0);
                float c = Fbm(cp) + (ValueNoise(cp * 8 + t * 3.1) - 0.5) * 0.03;
                float edge = 1 - _CloudCover;
                float cloud = smoothstep(edge, edge + 0.006, c) * smoothstep(0.03, 0.15, h);
                float rim = cloud * (1 - smoothstep(edge + 0.008, edge + 0.018, c));
                float lower = 1 - smoothstep(0.0, 0.05, Fbm(cp + float2(0, 0.15)) - edge);
                float3 cloudCol = lerp(lerp(float3(1, 1, 0.98), _SunsetHorizon.rgb * 1.08, sunset), _NightHorizon.rgb * 1.5, night);
                float3 cloudShade = cloudCol * float3(0.9, 0.91, 0.95);
                col = lerp(col, lerp(cloudCol, cloudShade, lower), cloud);
                col = lerp(col, _LineColor.rgb, rim * 0.85);

                // below the horizon use the ground color so the edge of the plane does not show sky
                float3 ground = lerp(_GroundDay.rgb, _GroundNight.rgb, night);
                col = lerp(ground, col, smoothstep(-0.02, 0.01, h));

                return float4(col, 1);
            }
            ENDHLSL
        }
    }
}
