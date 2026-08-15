namespace Aiwara.CRM.Api.Entidades;

/// <summary>
/// Clase para manejar la respuesta de operaciones con Stored Procedures.
/// Formato esperado: "1|mensaje" para éxito, "0|error" para error
/// </summary>
public class ResultadoOperacion
{
    public bool Exitoso { get; set; }
    public string Mensaje { get; set; } = string.Empty;
}
