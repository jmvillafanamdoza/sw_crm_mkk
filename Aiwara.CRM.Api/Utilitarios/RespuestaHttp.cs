using Aiwara.CRM.Api.DTOs.Common;
using Microsoft.AspNetCore.Http;

namespace Aiwara.CRM.Api.Utilitarios;

/// <summary>
/// Helpers para devolver IResult consistentes desde los EndPoints (Minimal API).
/// </summary>
public static class RespuestaHttp
{
    public static IResult Ok<T>(T datos, string? mensaje = null) =>
        Results.Ok(RespuestaApiDto<T>.Ok(datos, mensaje));

    public static IResult Creado<T>(string uri, T datos, string? mensaje = null) =>
        Results.Created(uri, RespuestaApiDto<T>.Ok(datos, mensaje));

    public static IResult NoEncontrado(string mensaje = "Recurso no encontrado.") =>
        Results.NotFound(RespuestaApiDto<object>.Error(mensaje));

    public static IResult ErrorValidacion(IEnumerable<string> errores) =>
        Results.BadRequest(RespuestaApiDto<object>.Error("Errores de validación.", errores));
}
