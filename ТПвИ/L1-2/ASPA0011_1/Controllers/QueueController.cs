using ASPA0011_1.Logging;
using ASPA0011_1.Models;
using ASPA0011_1.Services;
using Microsoft.AspNetCore.Mvc;

namespace ASPA0011_1.Controllers;

[ApiController]
[Route("api/queue")]
public sealed class QueueController : ControllerBase
{
    private readonly ChannelRegistry _registry;
    private readonly ILogger<QueueController> _logger;

    public QueueController(
        ChannelRegistry registry,
        ILogger<QueueController> logger)
    {
        _registry = registry;
        _logger = logger;

        _logger.LogTrace(
            LogEvents.Next("QueueControllerCreated"),
            "QueueController created");
    }

    [HttpPost]
    public async Task<IActionResult> Execute(
        [FromBody] QueueCommandRequest request,
        CancellationToken requestAborted)
    {
        _logger.LogTrace(
            LogEvents.Next("QueueCommandCalled"),
            "POST /api/queue command={Command}, id={Id}, data={Data}",
            request.Command,
            request.Id,
            request.Data);

        if (!_registry.TryGet(request.Id, out var channel) || channel is null)
        {
            _logger.LogError(
                LogEvents.Next("QueueChannelNotFound"),
                "Queue operation requested for missing channel {Id}. HTTP 404",
                request.Id);

            return NotFound(new { error = $"Channel {request.Id} not found" });
        }

        if (!channel.IsActive)
        {
            _logger.LogWarning(
                LogEvents.Next("QueueChannelClosed"),
                "Queue operation {Command} requested for CLOSED channel {Id}",
                request.Command,
                request.Id);

            return Conflict(new { error = "Channel is CLOSED" });
        }

        switch (request.Command.ToLowerInvariant())
        {
            case "enqueue":
                return await Enqueue(channel, request.Data, requestAborted);

            case "dequeue":
                channel.Queue.Reader.TryRead(out var dequeued);
                return Ok(new QueueItemDto(channel.Id, dequeued));

            case "peek":
                channel.Queue.Reader.TryPeek(out var peeked);
                return Ok(new QueueItemDto(channel.Id, peeked));

            default:
                return BadRequest(new { error = "command must be enqueue, dequeue or peek" });
        }
    }

    private async Task<IActionResult> Enqueue(
        ChannelEntity channel,
        string? data,
        CancellationToken requestAborted)
    {
        if (data is null)
            return BadRequest(new { error = "data is required for enqueue" });

        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(requestAborted);
        timeout.CancelAfter(TimeSpan.FromSeconds(_registry.WaitEnqueueSeconds));

        try
        {
            await channel.Queue.Writer.WriteAsync(data, timeout.Token);
            return Ok(new QueueItemDto(channel.Id, data));
        }
        catch (OperationCanceledException) when (!requestAborted.IsCancellationRequested)
        {
            _logger.LogWarning(
                LogEvents.Next("WaitEnqueueExpired"),
                "WaitEnqueue expired after {Seconds} s for channel {Id}",
                _registry.WaitEnqueueSeconds,
                channel.Id);

            return StatusCode(
                StatusCodes.Status408RequestTimeout,
                new
                {
                    error = "WaitEnqueue expired",
                    waitEnqueue = _registry.WaitEnqueueSeconds,
                    id = channel.Id
                });
        }
    }
}
