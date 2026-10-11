namespace Aiwara.CRM.Api.Utilitarios;

/// <summary>
/// Lectura del parámetro @o_resultMessage que devuelven los SPs de escritura.
/// </summary>
public static class RespuestaSp
{
    /// <summary>
    /// Parsea la respuesta del Stored Procedure en formato "1|mensaje" o "0|error"
    /// Retorna objeto con EsExitoso y Mensaje
    /// </summary>
    public static (bool EsExitoso, string Mensaje) Parsear(string? respuesta)
    {
        if (string.IsNullOrEmpty(respuesta))
        {
            return (false, "Sin respuesta del servidor");
        }

        var partes = respuesta.Split('|');
        var esExitoso = partes[0] == "1";
        var mensaje = partes.Length > 1 ? string.Join("|", partes.Skip(1)) : string.Empty;

        return (esExitoso, mensaje);
    }
}
