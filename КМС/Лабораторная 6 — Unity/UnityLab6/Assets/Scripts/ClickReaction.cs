using UnityEngine;
using UnityEngine.EventSystems;

[RequireComponent(typeof(Renderer), typeof(Rigidbody))]
public class ClickReaction : MonoBehaviour, IPointerClickHandler
{
    public float force = 650f;
    private Material ownMaterial;

    public void OnPointerClick(PointerEventData eventData)
    {
        if (eventData.button != PointerEventData.InputButton.Left) return;
        if (ownMaterial == null) ownMaterial = GetComponent<Renderer>().material;
        float red = Random.Range(0f, 1f);
        float green = Random.Range(0f, 1f);
        float blue = Random.Range(0f, 1f);
        ownMaterial.color = new Color(red, green, blue);

        Camera camera = eventData.pressEventCamera != null ? eventData.pressEventCamera : Camera.main;
        if (camera == null) return;
        Vector3 target = eventData.pointerPressRaycast.worldPosition;
        Vector3 distance = (target - camera.transform.position).normalized;
        GetComponent<Rigidbody>().AddForceAtPosition(distance * force, target);
    }

    private void OnDestroy()
    {
        if (ownMaterial == null) return;
        if (Application.isPlaying) Destroy(ownMaterial);
        else DestroyImmediate(ownMaterial);
    }
}
