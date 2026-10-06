#ifndef HW_NOISE_INCLUDED
#define HW_NOISE_INCLUDED

float Hash21(float2 p)
{
    p = frac(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return frac(p.x * p.y);
}

float ValueNoise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = Hash21(i);
    float b = Hash21(i + float2(1, 0));
    float c = Hash21(i + float2(0, 1));
    float d = Hash21(i + float2(1, 1));
    return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
}

float Fbm(float2 p)
{
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++)
    {
        v += amp * ValueNoise(p);
        p = p * 2.03 + 17.1;
        amp *= 0.5;
    }
    return v;
}

// time snapped to a low frame rate, gives the hand drawn "boiling" feel
float SteppedTime(float fps)
{
    return floor(_Time.y * fps) / max(fps, 0.001);
}

#endif
