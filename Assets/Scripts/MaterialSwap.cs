using UnityEngine;

public class MaterialSwap : MonoBehaviour
{
    [System.Serializable]
    public class MaterialSet
    {
        public Material[] materials;
    }

    // One set per style; keep all slots for meshes with multiple materials.
    public MaterialSet[] sets;

    private Renderer rend;

    void Awake()
    {
        rend = GetComponent<Renderer>();
    }

    public void SwapTo(int index)
    {
        if (rend == null) rend = GetComponent<Renderer>();
        if (rend == null || sets == null || sets.Length == 0) return;
        rend.sharedMaterials = sets[index % sets.Length].materials;
    }
}
