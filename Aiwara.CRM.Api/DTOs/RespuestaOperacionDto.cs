namespace Aiwara.CRM.Api.DTOs;

/// <summary>
/// DTO genérico para respuestas de operaciones en repositorio.
/// Sigue el patrón: esExitoso, mensaje, datos
/// </summary>
public class RespuestaOperacionDto<T>
{
    public bool EsExitoso { get; set; }
    public string Mensaje { get; set; } = string.Empty;
    public T? Datos { get; set; }

    public static RespuestaOperacionDto<T> Exitoso(T? datos, string mensaje = "Operación exitosa")
    {
        return new RespuestaOperacionDto<T>
        {
            EsExitoso = true,
            Mensaje = mensaje,
            Datos = datos
        };
    }

    public static RespuestaOperacionDto<T> Error(string mensaje)
    {
        return new RespuestaOperacionDto<T>
        {
            EsExitoso = false,
            Mensaje = mensaje,
            Datos = default
        };
    }
}
