namespace ASPA0011_1.Models;

public sealed record ChannelDto(
    Guid Id,
    string Name,
    string State,
    string Description);

public sealed class CreateChannelRequest
{
    public string Command { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string State { get; set; } = "ACTIVE";
    public string Description { get; set; } = string.Empty;
}

public sealed class ChannelCommandRequest
{
    public string Command { get; set; } = string.Empty;
    public Guid? Id { get; set; }
    public string? Reason { get; set; }
    public string? State { get; set; }
}

public sealed class QueueCommandRequest
{
    public string Command { get; set; } = string.Empty;
    public Guid Id { get; set; }
    public string? Data { get; set; }
}

public sealed record QueueItemDto(Guid Id, string? Data);
