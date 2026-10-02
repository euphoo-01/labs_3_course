using System.Text;
using ASPA0011_1.Logging;

namespace ASPA0011_1.Middleware;

public sealed class RequestLoggingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestLoggingMiddleware> _logger;

    public RequestLoggingMiddleware(
        RequestDelegate next,
        ILogger<RequestLoggingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        _logger.LogTrace(
            LogEvents.Next("RequestTrace"),
            "Request {Method} {Path}{QueryString}",
            context.Request.Method,
            context.Request.Path,
            context.Request.QueryString);

        var requestBody = await ReadRequestBody(context.Request);
        var requestHeaders = string.Join(
            "; ",
            context.Request.Headers.Select(h => $"{h.Key}={h.Value}"));

        _logger.LogDebug(
            LogEvents.Next("RequestDebug"),
            "REQUEST method={Method}; path={Path}; query={Query}; headers=[{Headers}]; body={Body}",
            context.Request.Method,
            context.Request.Path,
            context.Request.QueryString,
            requestHeaders,
            requestBody);

        var originalBody = context.Response.Body;
        await using var responseBuffer = new MemoryStream();
        context.Response.Body = responseBuffer;

        try
        {
            await _next(context);

            responseBuffer.Position = 0;
            using var reader = new StreamReader(
                responseBuffer,
                Encoding.UTF8,
                detectEncodingFromByteOrderMarks: false,
                leaveOpen: true);

            var responseBody = await reader.ReadToEndAsync();

            _logger.LogTrace(
                LogEvents.Next("ResponseTrace"),
                "Response {StatusCode} for {Method} {Path}",
                context.Response.StatusCode,
                context.Request.Method,
                context.Request.Path);

            _logger.LogDebug(
                LogEvents.Next("ResponseDebug"),
                "RESPONSE status={StatusCode}; contentType={ContentType}; body={Body}",
                context.Response.StatusCode,
                context.Response.ContentType,
                responseBody);

            responseBuffer.Position = 0;
            await responseBuffer.CopyToAsync(originalBody);
        }
        finally
        {
            context.Response.Body = originalBody;
        }
    }

    private static async Task<string> ReadRequestBody(HttpRequest request)
    {
        if (request.ContentLength is null or 0)
            return string.Empty;

        request.EnableBuffering();
        request.Body.Position = 0;

        using var reader = new StreamReader(
            request.Body,
            Encoding.UTF8,
            detectEncodingFromByteOrderMarks: false,
            leaveOpen: true);

        var body = await reader.ReadToEndAsync();
        request.Body.Position = 0;
        return body;
    }
}
