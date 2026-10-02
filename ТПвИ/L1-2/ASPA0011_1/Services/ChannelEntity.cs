using System.Threading.Channels;
using ASPA0011_1.Models;

namespace ASPA0011_1.Services;

public sealed class ChannelEntity
{
    public Guid Id { get; } = Guid.NewGuid();
    public string Name { get; }
    public string Description { get; }
    public bool IsActive { get; set; }
    public Channel<string> Queue { get; }

    public ChannelEntity(string name, string description, bool isActive, int capacity)
    {
        Name = name;
        Description = description;
        IsActive = isActive;

        Queue = Channel.CreateBounded<string>(new BoundedChannelOptions(capacity)
        {
            FullMode = BoundedChannelFullMode.Wait,
            SingleReader = false,
            SingleWriter = false
        });
    }

    public ChannelDto ToDto() =>
        new(Id, Name, IsActive ? "ACTIVE" : "CLOSED", Description);
}
