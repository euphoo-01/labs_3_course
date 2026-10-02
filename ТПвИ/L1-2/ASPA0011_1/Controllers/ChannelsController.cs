using ASPA0011_1.Logging;
using ASPA0011_1.Models;
using ASPA0011_1.Services;
using Microsoft.AspNetCore.Mvc;

namespace ASPA0011_1.Controllers;

[ApiController]
[Route("api/channels")]
public sealed class ChannelsController : ControllerBase
{
    private readonly ChannelRegistry _registry;
    private readonly ILogger<ChannelsController> _logger;

    public ChannelsController(
        ChannelRegistry registry,
        ILogger<ChannelsController> logger)
    {
        _registry = registry;
        _logger = logger;

        _logger.LogTrace(
            LogEvents.Next("ChannelsControllerCreated"),
            "ChannelsController created");
    }

    [HttpGet]
    public IActionResult GetAll()
    {
        _logger.LogTrace(LogEvents.Next("GetAllCalled"), "GET /api/channels called");

        var channels = _registry.GetAll().Select(x => x.ToDto()).ToArray();
        return channels.Length == 0 ? NoContent() : Ok(channels);
    }

    [HttpGet("{id:guid}")]
    public IActionResult Get(Guid id)
    {
        _logger.LogTrace(
            LogEvents.Next("GetChannelCalled"),
            "GET channel, id={Id}",
            id);

        if (!_registry.TryGet(id, out var channel) || channel is null)
        {
            _logger.LogError(
                LogEvents.Next("ChannelNotFound"),
                "Channel {Id} not found. HTTP 404",
                id);

            return NotFound(new { error = $"Channel {id} not found" });
        }

        return Ok(channel.ToDto());
    }

    [HttpPost]
    public IActionResult Create([FromBody] CreateChannelRequest request)
    {
        _logger.LogTrace(
            LogEvents.Next("CreateChannelCalled"),
            "POST create channel: command={Command}, name={Name}, state={State}",
            request.Command,
            request.Name,
            request.State);

        if (!string.Equals(request.Command, "new", StringComparison.OrdinalIgnoreCase))
            return BadRequest(new { error = "command must be 'new'" });

        var active = string.Equals(request.State, "ACTIVE", StringComparison.OrdinalIgnoreCase);
        var closed = string.Equals(request.State, "CLOSED", StringComparison.OrdinalIgnoreCase);

        if (!active && !closed)
            return BadRequest(new { error = "state must be ACTIVE or CLOSED" });

        var channel = _registry.Create(
            request.Name,
            request.Description,
            active);

        _logger.LogInformation(
            LogEvents.Next("ChannelCreated"),
            "Channel {Id} created. Name={Name}, State={State}",
            channel.Id,
            channel.Name,
            channel.IsActive ? "ACTIVE" : "CLOSED");

        if (!active)
            return NoContent();

        return CreatedAtAction(nameof(Get), new { id = channel.Id }, channel.ToDto());
    }

    [HttpPut]
    public IActionResult ChangeState([FromBody] ChannelCommandRequest request)
    {
        _logger.LogTrace(
            LogEvents.Next("ChangeStateCalled"),
            "PUT channels: command={Command}, id={Id}, reason={Reason}, state={State}",
            request.Command,
            request.Id,
            request.Reason,
            request.State);

        var command = request.Command.ToLowerInvariant();
        if (command is not ("open" or "close"))
            return BadRequest(new { error = "command must be 'open' or 'close'" });

        if (request.Id.HasValue)
        {
            if (!_registry.TryGet(request.Id.Value, out var channel) || channel is null)
            {
                _logger.LogError(
                    LogEvents.Next("ChannelNotFound"),
                    "Channel {Id} not found. HTTP 404",
                    request.Id.Value);

                return NotFound(new { error = $"Channel {request.Id.Value} not found" });
            }

            ChangeOne(channel, command, request.Reason);
            return Ok(channel.ToDto());
        }

        var all = _registry.GetAll();
        foreach (var channel in all)
            ChangeOne(channel, command, request.Reason);

        return Ok(all.Select(x => x.ToDto()).ToArray());
    }

    [HttpDelete]
    public IActionResult Delete([FromBody] ChannelCommandRequest request)
    {
        _logger.LogTrace(
            LogEvents.Next("DeleteCalled"),
            "DELETE channels: command={Command}, state={State}",
            request.Command,
            request.State);

        if (!string.Equals(request.Command, "del", StringComparison.OrdinalIgnoreCase))
            return BadRequest(new { error = "command must be 'del'" });

        var all = _registry.GetAll();
        IEnumerable<ChannelEntity> selected = all;

        if (!string.IsNullOrWhiteSpace(request.State))
        {
            if (!string.Equals(request.State, "CLOSED", StringComparison.OrdinalIgnoreCase))
                return BadRequest(new { error = "for DELETE state may only be CLOSED" });

            selected = all.Where(x => !x.IsActive);
        }

        var deleted = new List<ChannelDto>();
        foreach (var channel in selected.ToArray())
        {
            if (_registry.Remove(channel.Id, out var removed) && removed is not null)
            {
                deleted.Add(removed.ToDto());
                _logger.LogInformation(
                    LogEvents.Next("ChannelDeleted"),
                    "Channel {Id} deleted",
                    removed.Id);
            }
        }

        if (deleted.Count == 0)
        {
            _logger.LogError(
                LogEvents.Next("DeleteNothingFound"),
                "No channels matched DELETE request. HTTP 404");

            return NotFound(new { error = "No matching channels" });
        }

        return Ok(deleted);
    }

    private void ChangeOne(ChannelEntity channel, string command, string? reason)
    {
        if (command == "open")
        {
            if (channel.IsActive)
            {
                _logger.LogWarning(
                    LogEvents.Next("OpenAlreadyOpen"),
                    "OPEN requested for already ACTIVE channel {Id}",
                    channel.Id);
                return;
            }

            channel.IsActive = true;
            _logger.LogInformation(
                LogEvents.Next("ChannelOpened"),
                "Channel {Id} opened",
                channel.Id);
            return;
        }

        if (!channel.IsActive)
        {
            _logger.LogWarning(
                LogEvents.Next("CloseAlreadyClosed"),
                "CLOSE requested for already CLOSED channel {Id}. Reason={Reason}",
                channel.Id,
                reason);
            return;
        }

        channel.IsActive = false;
        _logger.LogInformation(
            LogEvents.Next("ChannelClosed"),
            "Channel {Id} closed. Reason={Reason}",
            channel.Id,
            reason);
    }
}
