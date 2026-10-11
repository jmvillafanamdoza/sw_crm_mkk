using Aiwara.CRM.Api.DTOs;
using Dapper;
using System.Data;

namespace Aiwara.CRM.Api.Repositorios;

/// <summary>
/// Repositorio de catálogos usando Dapper con Stored Procedures.
/// </summary>
public class CatalogoRepositorio : ICatalogoRepositorio
{
    private readonly IConnectionFactory _connectionFactory;

    public CatalogoRepositorio(IConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public Task<RespuestaOperacionDto<IEnumerable<CatalogoItemDto<int>>>> ObtenerPerfilesPorSpAsync() =>
        ConsultarAsync<int>("[dbo].[PRMKK_CON_BOF_PERFIL]", "perfiles",
            new { i_ESTADO = "V" }, "CPFL_ID_PERFIL", "SPFL_NOMBRE");

    public Task<RespuestaOperacionDto<IEnumerable<CatalogoItemDto<int>>>> ObtenerSedesPorSpAsync() =>
        ConsultarAsync<int>("[dbo].[PRMKK_CON_BOF_SEDE]", "sedes",
            new { i_ESTADO = "V" }, "CSED_ID_SEDE", "SSED_NOMBRE");

    public Task<RespuestaOperacionDto<IEnumerable<CatalogoItemDto<int>>>> ObtenerCampaniasPorSpAsync() =>
        ConsultarAsync<int>("[dbo].[PRMKK_CON_BOF_CAMPANIA]", "campañas",
            new { i_ESTADO = "V" }, "CCAM_ID_CAMPANIA", "SCAM_NOMBRE");

    public Task<RespuestaOperacionDto<IEnumerable<CatalogoItemDto<int>>>> ObtenerSupervisoresPorSpAsync(int? campaniaId) =>
        ConsultarAsync<int>("[dbo].[PRMKK_CON_BOF_SUPERVISOR]", "supervisores",
            new { i_CCAM_ID_CAMPANIA = campaniaId }, "CPEL_ID_PERSONAL", "SNOMBRE_COMPLETO");

    public Task<RespuestaOperacionDto<IEnumerable<CatalogoItemDto<string>>>> ObtenerTiposValorPorSpAsync(string grupo) =>
        ConsultarAsync<string>("[dbo].[PRMKK_CON_BOF_TIP_VALOR_VIGENTE]", $"valores de {grupo}",
            new { i_COD_TIP_VALOR = grupo }, "CTPV_TIP_VALOR", "STPV_DES_TIP_VALOR_1");

    // ==================== MÉTODOS AUXILIARES ====================

    /// <summary>
    /// Ejecuta un SP de consulta y proyecta las columnas de id y nombre indicadas.
    /// </summary>
    private async Task<RespuestaOperacionDto<IEnumerable<CatalogoItemDto<TId>>>> ConsultarAsync<TId>(
        string spName, string descripcion, object parametrosSp, string columnaId, string columnaNombre)
    {
        try
        {
            using var connection = _connectionFactory.CreateConnection();

            // Los nombres de propiedad se envían como @nombre (p. ej. i_ESTADO -> @i_ESTADO)
            var parametros = new DynamicParameters(parametrosSp);

            var filas = await connection.QueryAsync(
                spName,
                parametros,
                commandType: CommandType.StoredProcedure
            );

            var datos = filas
                .Cast<IDictionary<string, object?>>()
                .Select(f => new CatalogoItemDto<TId>
                {
                    Id = (TId)Convert.ChangeType(f[columnaId]!, typeof(TId)),
                    Nombre = f[columnaNombre]?.ToString() ?? string.Empty
                })
                .ToList();

            return RespuestaOperacionDto<IEnumerable<CatalogoItemDto<TId>>>.Exitoso(
                datos,
                $"Se obtuvieron {datos.Count} {descripcion}.");
        }
        catch (Exception ex)
        {
            return RespuestaOperacionDto<IEnumerable<CatalogoItemDto<TId>>>.Error(
                $"Error al obtener {descripcion}: {ex.Message}");
        }
    }
}
