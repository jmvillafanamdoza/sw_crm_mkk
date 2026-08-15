namespace Aiwara.CRM.Api.DTOs;

/// <summary>
/// DTO de ejemplo — bórralo/reemplázalo cuando lleguen las carpetas guía
/// con las entidades reales del CRM.
/// </summary>
public class EjemploDto
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
}

public class CrearEjemploDto
{
    public string Nombre { get; set; } = string.Empty;
}
