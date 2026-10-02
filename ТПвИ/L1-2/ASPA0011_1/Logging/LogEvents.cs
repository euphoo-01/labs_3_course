namespace ASPA0011_1.Logging;

public static class LogEvents
{
    private static int _counter;

    public static EventId Next(string name) =>
        new(Interlocked.Increment(ref _counter), name);
}
