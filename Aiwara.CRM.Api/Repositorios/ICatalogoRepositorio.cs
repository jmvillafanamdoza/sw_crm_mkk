using Aiwara.CRM.Api.DTOs;

namespace Aiwara.CRM.Api.Repositorios;

/// <summary>
/// Interfaz del repositorio de catálogos (combos de los formularios). Solo devuelve registros vigentes.
/// </summary>
public interface ICatalogoRepositorio
{
    /// <summary>SP: [dbo].[PRMKK_CON_BOF_PERFIL]</summary>
    Task<RespuestaOperacionDto<IEnumerable<CatalogoItemDto<int>>>> ObtenerPerfilesPorSpAsync();

    /// <summary>SP: [dbo].[PRMKK_CON_BOF_SEDE]</summary>
    Task<RespuestaOperacionDto<IEnumerable<CatalogoItemDto<int>>>> ObtenerSedesPorSpAsync();

    /// <summary>SP: [dbo].[PRMKK_CON_BOF_CAMPANIA]</summary>
    Task<RespuestaOperacionDto<IEnumerable<CatalogoItemDto<int>>>> ObtenerCampaniasPorSpAsync();

    /// <summary>SP: [dbo].[PRMKK_CON_BOF_SUPERVISOR]</summary>
    Task<RespuestaOperacionDto<IEnumerable<CatalogoItemDto<int>>>> ObtenerSupervisoresPorSpAsync(int? campaniaId);

    /// <summary>
    /// Valores vigentes de un grupo de TMKK_TIP_VALOR (PUESTO_TRABAJO, MODALIDAD_TRABAJO, ...).
    /// SP: [dbo].[PRMKK_CON_BOF_TIP_VALOR_VIGENTE]
    /// </summary>
    Task<RespuestaOperacionDto<IEnumerable<CatalogoItemDto<string>>>> ObtenerTiposValorPorSpAsync(string grupo);
}
