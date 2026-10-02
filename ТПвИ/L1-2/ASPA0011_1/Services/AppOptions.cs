namespace ASPA0011_1.Services;

public sealed class AppOptions
{
    public int WaitEnqueue { get; set; } = 3;
    public int QueueCapacity { get; set; } = 1;
}
