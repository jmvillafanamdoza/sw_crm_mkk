namespace Aiwara.CRM.Api.Entidades;

/// <summary>
/// Entidad de Tipo de Valor (ETipoValor).
/// Representa los tipos de valores que se pueden usar en el CRM.
/// Mapea a tabla TMKK_TIP_VALOR
/// </summary>
public class ETipoValor
{
    /// <summary>Código del tipo de valor (Clave primaria)</summary>
    public string CodigoTipoValor { get; set; } = string.Empty;

    /// <summary>Tipo/Categoría del valor</summary>
    public string TipoValor { get; set; } = string.Empty;

    /// <summary>Descripción principal del tipo de valor</summary>
    public string DescripcionPrincipal { get; set; } = string.Empty;

    /// <summary>Descripción secundaria 1</summary>
    public string? Descripcion2 { get; set; }

    /// <summary>Descripción secundaria 2</summary>
    public string? Descripcion3 { get; set; }

    /// <summary>Usuario que creó el registro</summary>
    public string? UsuarioInsercion { get; set; }

    /// <summary>Usuario que actualizó el registro</summary>
    public string? UsuarioActualizacion { get; set; }

    /// <summary>Estado del registro para eliminación lógica (A=Activo, I=Inactivo)</summary>
    public string? Estado { get; set; }

    /// <summary>Fecha de creación (se asigna en la BD)</summary>
    public DateTime? FechaCreacion { get; set; }

    /// <summary>Fecha de actualización (se asigna en la BD)</summary>
    public DateTime? FechaActualizacion { get; set; }
}
