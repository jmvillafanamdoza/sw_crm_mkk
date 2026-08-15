namespace Aiwara.CRM.Api.DTOs.Common;

/// <summary>
/// Envoltorio estándar de respuesta para todos los endpoints de la API.
/// </summary>
public class RespuestaApiDto<T>
{
    public bool Exitoso { get; set; }
    public string? Mensaje { get; set; }
    public T? Datos { get; set; }
    public IEnumerable<string>? Errores { get; set; }

    public static RespuestaApiDto<T> Ok(T datos, string? mensaje = null) => new()
    {
        Exitoso = true,
        Datos = datos,
        Mensaje = mensaje
    };

    public static RespuestaApiDto<T> Error(string mensaje, IEnumerable<string>? errores = null) => new()
    {
        Exitoso = false,
        Mensaje = mensaje,
        Errores = errores
    };
}
