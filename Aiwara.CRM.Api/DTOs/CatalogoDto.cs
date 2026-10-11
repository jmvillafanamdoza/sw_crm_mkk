namespace Aiwara.CRM.Api.DTOs;

/// <summary>
/// Elemento de un combo. TId es int para tablas maestras (perfiles, sedes,
/// campañas, supervisores) y string para grupos de TMKK_TIP_VALOR ('P', 'R', ...).
/// </summary>
public class CatalogoItemDto<TId>
{
    public TId Id { get; set; } = default!;
    public string Nombre { get; set; } = string.Empty;
}
