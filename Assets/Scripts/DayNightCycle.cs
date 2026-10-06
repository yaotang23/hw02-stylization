using UnityEngine;

public class DayNightCycle : MonoBehaviour
{
    public Light sun;
    public StyleSwitcher switcher;

    public float dayLength = 40f;
    [Range(0, 1)] public float timeOfDay = 0.38f;
    public bool running = true;
    public KeyCode pauseKey = KeyCode.P;
    public float skipSpeed = 0.4f;

    public float maxElevation = 55f;
    public float yaw = -35f;
    public float yawRange = 140f;

    public Color dayColor = new Color(1f, 0.96f, 0.9f);
    public Color sunsetColor = new Color(1f, 0.68f, 0.45f);
    public Color moonColor = new Color(0.62f, 0.7f, 1f);
    public float sunIntensity = 1.1f;
    public float moonIntensity = 0.75f;

    public Light[] lamps;
    public float[] lampDay;
    public float[] lampNight;

    public float Night { get; private set; }

    private float skipTarget = -1f;

    static readonly int SunDirId = Shader.PropertyToID("_SunDir");
    static readonly int MoonDirId = Shader.PropertyToID("_MoonDir");
    static readonly int SunsetId = Shader.PropertyToID("_Sunset");
    static readonly int NightBlendId = Shader.PropertyToID("_NightBlend");

    void Update()
    {
        if (Input.GetKeyDown(pauseKey)) running = !running;

        float dt = Time.deltaTime;
        if (skipTarget >= 0)
        {
            float step = skipSpeed * dt;
            float remain = Mathf.Repeat(skipTarget - timeOfDay, 1f);
            if (remain <= step)
            {
                timeOfDay = skipTarget;
                skipTarget = -1f;
            }
            else
            {
                timeOfDay += step;
            }
        }
        else if (running)
        {
            timeOfDay += dt / Mathf.Max(dayLength, 0.1f);
        }
        timeOfDay = Mathf.Repeat(timeOfDay, 1f);
        Apply();
    }

    public void SkipToOther()
    {
        skipTarget = Night > 0.5f ? 0.38f : 0.95f;
    }

    public void Apply()
    {
        float s = Mathf.Sin((timeOfDay - 0.25f) * 2f * Mathf.PI);
        float elev = s * maxElevation;
        float az = yaw + (timeOfDay - 0.5f) * yawRange;

        Quaternion sunRot = Quaternion.Euler(elev, az, 0);
        Vector3 sunDir = -(sunRot * Vector3.forward);
        Night = 1f - Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(-0.12f, 0.12f, s));
        float sunset = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Abs(s) / 0.5f);

        if (sun != null)
        {
            if (s >= 0)
            {
                sun.transform.rotation = sunRot;
                sun.color = Color.Lerp(dayColor, sunsetColor, sunset);
                sun.intensity = sunIntensity * Mathf.Lerp(0.45f, 1f, Mathf.Clamp01(s / 0.3f));
            }
            else
            {
                sun.transform.rotation = Quaternion.Euler(-elev, az + 180f, 0);
                sun.color = moonColor;
                sun.intensity = moonIntensity * Mathf.Lerp(0.45f, 1f, Mathf.Clamp01(-s / 0.3f));
            }
        }

        if (lamps != null)
        {
            for (int i = 0; i < lamps.Length; i++)
            {
                lamps[i].intensity = Mathf.Lerp(lampDay[i], lampNight[i], Night);
            }
        }

        Shader.SetGlobalVector(SunDirId, sunDir);
        Shader.SetGlobalVector(MoonDirId, -sunDir);
        Shader.SetGlobalFloat(SunsetId, sunset);
        Shader.SetGlobalFloat(NightBlendId, Night);

        if (switcher != null) switcher.SetStyle(Night > 0.5f ? 1 : 0);
    }
}
