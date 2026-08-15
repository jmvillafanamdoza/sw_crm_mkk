using System.Net;
using Aiwara.CRM.Api.DTOs.Common;
using Aiwara.CRM.Api.Utilitarios;

namespace Aiwara.CRM.Api.Filtros;

/// <summary>
/// Captura cualquier excepción no manejada y devuelve una respuesta
/// consistente en formato RespuestaApiDto en vez de un stack trace crudo.
/// Registrar en Program.cs con app.UseMiddleware&lt;ExceptionHandlingMiddleware&gt;();
/// </summary>
public class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Excepción no controlada procesando {Path}", context.Request.Path);

            context.Response.ContentType = "application/json";
            context.Response.StatusCode = (int)HttpStatusCode.InternalServerError;

            var respuesta = RespuestaApiDto<object>.Error(Constantes.Mensajes.ErrorInterno);
            await context.Response.WriteAsJsonAsync(respuesta);
        }
    }
}
