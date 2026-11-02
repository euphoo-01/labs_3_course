using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public class PlaneGenerator : MonoBehaviour
{
    public GameObject prefab1;
    public Material cubeMaterial;
    public bool allowSpheres = true;
    public float spawnHeight = 7f;
    public float tiltAngle = 55f;
    public float tiltSpeed = 30f;
    private Rigidbody body;
    private bool tilted;
    private float angle;

    private void Awake()
    {
        body = GetComponent<Rigidbody>();
    }

    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Q)) SpawnCube();
        if (allowSpheres && Input.GetKeyDown(KeyCode.Space)) SpawnSphere();
        if (Input.GetKeyDown(KeyCode.W)) tilted = !tilted;
    }

    private void FixedUpdate()
    {
        angle = Mathf.MoveTowards(angle, tilted ? tiltAngle : 0f, tiltSpeed * Time.fixedDeltaTime);
        body.MoveRotation(Quaternion.Euler(0f, 0f, angle));
    }

    private Vector3 SpawnPosition()
    {
        // Размер стандартного Plane — 10 x 10. Bounds учитывает масштаб объекта.
        Bounds bounds = GetComponent<Collider>().bounds;
        float spreadX = Mathf.Min(1.2f, bounds.extents.x - 0.6f);
        float spreadZ = Mathf.Min(1.2f, bounds.extents.z - 0.6f);
        return new Vector3(bounds.center.x + Random.Range(-spreadX, spreadX),
            bounds.max.y + spawnHeight, bounds.center.z + Random.Range(-spreadZ, spreadZ));
    }

    public GameObject SpawnCube()
    {
        GameObject cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
        cube.name = "Generated Cube";
        cube.transform.position = SpawnPosition();
        cube.transform.rotation = Random.rotation;
        cube.GetComponent<Renderer>().sharedMaterial = cubeMaterial;
        cube.AddComponent<Rigidbody>();
        return cube;
    }

    public GameObject SpawnSphere()
    {
        if (prefab1 == null) return null;
        return Instantiate(prefab1, SpawnPosition(), Quaternion.identity);
    }
}
