using UnityEngine;

public class StyleSwitcher : MonoBehaviour
{
    public KeyCode key = KeyCode.Space;
    public float blendTime = 0.6f;

    public Camera cam;
    public Color dayBackground = new Color(0.97f, 0.95f, 0.91f);
    public Color nightBackground = new Color(0.12f, 0.14f, 0.24f);

    public Light mainLight;
    public Color dayLightColor = new Color(1f, 0.96f, 0.9f);
    public Color nightLightColor = new Color(0.55f, 0.65f, 1f);
    public float dayIntensity = 1.1f;
    public float nightIntensity = 0.8f;

    public DayNightCycle cycle;

    public Light[] extraLights;
    public float[] extraDayIntensity;
    public float[] extraNightIntensity;

    private MaterialSwap[] swaps;
    private int index;
    private float blend;

    static readonly int NightBlendId = Shader.PropertyToID("_NightBlend");

    void Start()
    {
        swaps = FindObjectsOfType<MaterialSwap>();
        if (cycle != null) return;
        Apply(0);
        blend = 0;
        UpdateBlend();
    }

    void Update()
    {
        if (Input.GetKeyDown(key))
        {
            if (cycle != null) cycle.SkipToOther();
            else Toggle();
        }
        // Let the cycle control lighting while it is active.
        if (cycle != null) return;
        float target = index;
        blend = Mathf.MoveTowards(blend, target, Time.deltaTime / Mathf.Max(blendTime, 0.01f));
        UpdateBlend();
    }

    public void Toggle()
    {
        index = (index + 1) % 2;
        Apply(index);
    }

    public void SetStyle(int i)
    {
        if (swaps != null && i == index) return;
        index = i;
        Apply(i);
    }

    void Apply(int i)
    {
        if (swaps == null) swaps = FindObjectsOfType<MaterialSwap>();
        foreach (var s in swaps)
        {
            s.SwapTo(i);
        }
    }

    void UpdateBlend()
    {
        Shader.SetGlobalFloat(NightBlendId, blend);
        if (cam != null) cam.backgroundColor = Color.Lerp(dayBackground, nightBackground, blend);
        if (mainLight != null)
        {
            mainLight.color = Color.Lerp(dayLightColor, nightLightColor, blend);
            mainLight.intensity = Mathf.Lerp(dayIntensity, nightIntensity, blend);
        }
        if (extraLights == null) return;
        for (int i = 0; i < extraLights.Length; i++)
        {
            extraLights[i].intensity = Mathf.Lerp(extraDayIntensity[i], extraNightIntensity[i], blend);
        }
    }

    void OnDisable()
    {
        Shader.SetGlobalFloat(NightBlendId, 0);
    }
}
