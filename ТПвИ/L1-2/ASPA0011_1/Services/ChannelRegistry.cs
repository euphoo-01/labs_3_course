using System.Collections.Concurrent;
using Microsoft.Extensions.Options;

namespace ASPA0011_1.Services;

public sealed class ChannelRegistry
{
    private readonly ConcurrentDictionary<Guid, ChannelEntity> _channels = new();
    private readonly AppOptions _options;

    public ChannelRegistry(IOptions<AppOptions> options)
    {
        _options = options.Value;
    }

    public IReadOnlyCollection<ChannelEntity> GetAll() => _channels.Values.ToArray();

    public bool TryGet(Guid id, out ChannelEntity? channel) =>
        _channels.TryGetValue(id, out channel);

    public ChannelEntity Create(string name, string description, bool active)
    {
        var channel = new ChannelEntity(
            name,
            description,
            active,
            Math.Max(1, _options.QueueCapacity));

        _channels[channel.Id] = channel;
        return channel;
    }

    public bool Remove(Guid id, out ChannelEntity? channel) =>
        _channels.TryRemove(id, out channel);

    public int WaitEnqueueSeconds => Math.Max(1, _options.WaitEnqueue);
}
