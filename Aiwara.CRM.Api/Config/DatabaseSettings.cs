namespace Aiwara.CRM.Api.Config;

/// <summary>
/// Mapea la sección "ConnectionStrings" de appsettings.json.
/// Se registra en Program.cs con builder.Services.Configure&lt;DatabaseSettings&gt;(...)
/// </summary>
public class DatabaseSettings
{
    public string DefaultConnection { get; set; } = string.Empty;
}
