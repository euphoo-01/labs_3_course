using Microsoft.Extensions.Logging;

namespace ASPA0011_1.Logging;

[ProviderAlias("Logfile")]
public sealed class FileLoggerProvider : ILoggerProvider
{
    private readonly string _path;

    public FileLoggerProvider(string path)
    {
        _path = path;
    }

    public ILogger CreateLogger(string categoryName) =>
        new FileLogger(_path, categoryName);

    public void Dispose()
    {
    }
}

public sealed class FileLogger : ILogger
{
    private static readonly object Sync = new();
    private readonly string _filePath;
    private readonly string _category;

    public FileLogger(string filePath, string category)
    {
        _filePath = filePath;
        _category = category;
    }

    public IDisposable BeginScope<TState>(TState state) where TState : notnull =>
        NullScope.Instance;

    public bool IsEnabled(LogLevel logLevel) => logLevel != LogLevel.None;

    public void Log<TState>(
        LogLevel logLevel,
        EventId eventId,
        TState state,
        Exception? exception,
        Func<TState, Exception?, string> formatter)
    {
        if (!IsEnabled(logLevel))
            return;

        var message = formatter(state, exception);
        if (exception is not null)
            message += $" | {exception.GetType().Name}: {exception.Message}";

        var line =
            $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} " +
            $"#{eventId.Id:0000} [{logLevel}] {_category} " +
            $"({eventId.Name}) {message}{Environment.NewLine}";

        lock (Sync)
        {
            File.AppendAllText(_filePath, line);
        }
    }

    private sealed class NullScope : IDisposable
    {
        public static NullScope Instance { get; } = new();
        public void Dispose()
        {
        }
    }
}
