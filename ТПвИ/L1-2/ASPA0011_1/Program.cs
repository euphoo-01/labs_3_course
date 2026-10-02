using ASPA0011_1.Logging;
using ASPA0011_1.Middleware;
using ASPA0011_1.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.Configure<AppOptions>(builder.Configuration.GetSection("App"));
builder.Services.AddSingleton<ChannelRegistry>();

// По лекции: очищаем стандартный набор провайдеров и явно подключаем нужные.
builder.Logging.ClearProviders();
builder.Logging.AddConfiguration(builder.Configuration.GetSection("Logging"));
builder.Logging.AddConsole();
builder.Logging.AddDebug();
builder.Logging.AddProvider(
    new FileLoggerProvider(Path.Combine(builder.Environment.ContentRootPath, "app.log")));

var app = builder.Build();

app.UseMiddleware<RequestLoggingMiddleware>();
app.MapControllers();

var logger = app.Services.GetRequiredService<ILoggerFactory>()
    .CreateLogger("ASPA0011_1.Application");

app.Lifetime.ApplicationStarted.Register(() =>
    logger.LogInformation(LogEvents.Next("ApplicationStarted"), "Application started"));

app.Lifetime.ApplicationStopping.Register(() =>
    logger.LogInformation(LogEvents.Next("ApplicationStopping"), "Application is stopping"));

app.Run();
