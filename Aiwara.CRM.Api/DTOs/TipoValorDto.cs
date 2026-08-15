namespace Aiwara.CRM.Api.DTOs;

/// <summary>
/// DTO de Tipo de Valor para consultas.
/// </summary>
public class TipoValorDto
{
    public string CodigoTipoValor { get; set; } = string.Empty;
    public string TipoValor { get; set; } = string.Empty;
    public string DescripcionPrincipal { get; set; } = string.Empty;
    public string? Descripcion2 { get; set; }
    public string? Descripcion3 { get; set; }
    public string? UsuarioInsercion { get; set; }
    public string? UsuarioActualizacion { get; set; }
    public string? Estado { get; set; }
    public DateTime? FechaCreacion { get; set; }
    public DateTime? FechaActualizacion { get; set; }
}

/// <summary>
/// DTO para crear un nuevo Tipo de Valor.
/// </summary>
public class CrearTipoValorDto
{
    public string CodigoTipoValor { get; set; } = string.Empty;
    public string TipoValor { get; set; } = string.Empty;
    public string DescripcionPrincipal { get; set; } = string.Empty;
    public string? Descripcion2 { get; set; }
    public string? Descripcion3 { get; set; }
    public string UsuarioInsercion { get; set; } = "ADMIN";
}

/// <summary>
/// DTO para actualizar datos de un Tipo de Valor.
/// </summary>
public class ActualizarTipoValorDto
{
    public string CodigoTipoValor { get; set; } = string.Empty;
    public string TipoValor { get; set; } = string.Empty;
    public string DescripcionPrincipal { get; set; } = string.Empty;
    public string? Descripcion2 { get; set; }
    public string? Descripcion3 { get; set; }
    public string UsuarioActualizacion { get; set; } = "ADMIN";
}

/// <summary>
/// DTO para cambiar el estado de un Tipo de Valor (eliminación lógica).
/// </summary>
public class CambiarEstadoTipoValorDto
{
    public string CodigoTipoValor { get; set; } = string.Empty;
    public string TipoValor { get; set; } = string.Empty;
    /// <summary>Estado: A=Activo, I=Inactivo</summary>
    public string Estado { get; set; } = "A";
}

/// <summary>
/// DTO para filtrar Tipos de Valor.
/// </summary>
public class FiltroTipoValorDto
{
    public string? CodigoTipoValor { get; set; }
    public string? TipoValor { get; set; }
    public string? DescripcionPrincipal { get; set; }
}
