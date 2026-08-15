using Microsoft.OpenApi;
//using Microsoft.OpenApi.Models;

namespace Aiwara.CRM.Api.Swagger;

/// <summary>
/// Configuración del documento OpenAPI nativo de .NET 10.
/// Swashbuckle NO se usa: no es compatible con .NET 9+ (rompe con
/// TypeLoadException por el cambio de namespace en Microsoft.OpenApi 2.0).
/// La UI visual (equivalente a Swagger UI) la sirve Scalar, registrado
/// en Program.cs con app.MapScalarApiReference().
/// </summary>
public static class OpenApiConfiguration
{
    public static IServiceCollection AddAiwaraOpenApi(this IServiceCollection services)
    {
        services.AddOpenApi("v1", options =>
        {
            options.AddDocumentTransformer((document, context, cancellationToken) =>
            {
                document.Info = new OpenApiInfo
                {
                    Title = "Aiwara.CRM.Api",
                    Version = "v1",
                    Description = "API del CRM de Aiwara."
                };
                return Task.CompletedTask;
            });
        });

        return services;
    }
}
