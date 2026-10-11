using Aiwara.CRM.Api.DTOs;
using Aiwara.CRM.Api.Repositorios;
using Aiwara.CRM.Api.Utilitarios;

namespace Aiwara.CRM.Api.EndPoints;

/// <summary>
/// Endpoints de catálogos para los combos de los formularios (solo registros vigentes).
/// </summary>
public static class CatalogoEndpoints
{
    public static void MapCatalogoEndpoints(this WebApplication app)
    {
        var grupo = app.MapGroup("/api/catalogos")
                       .WithTags(Constantes.Grupos.Catalogo);

        grupo.MapGet("/perfiles", async (ICatalogoRepositorio repo) =>
            Responder(await repo.ObtenerPerfilesPorSpAsync()))
        .WithName("ObtenerCatalogoPerfiles")
        .Produces<IEnumerable<CatalogoItemDto<int>>>();

        grupo.MapGet("/sedes", async (ICatalogoRepositorio repo) =>
            Responder(await repo.ObtenerSedesPorSpAsync()))
        .WithName("ObtenerCatalogoSedes")
        .Produces<IEnumerable<CatalogoItemDto<int>>>();

        grupo.MapGet("/campanias", async (ICatalogoRepositorio repo) =>
            Responder(await repo.ObtenerCampaniasPorSpAsync()))
        .WithName("ObtenerCatalogoCampanias")
        .Produces<IEnumerable<CatalogoItemDto<int>>>();

        grupo.MapGet("/supervisores", async (int? campaniaId, ICatalogoRepositorio repo) =>
            Responder(await repo.ObtenerSupervisoresPorSpAsync(campaniaId)))
        .WithName("ObtenerCatalogoSupervisores")
        .Produces<IEnumerable<CatalogoItemDto<int>>>();

        grupo.MapGet("/puestos", async (ICatalogoRepositorio repo) =>
            Responder(await repo.ObtenerTiposValorPorSpAsync("PUESTO_TRABAJO")))
        .WithName("ObtenerCatalogoPuestos")
        .Produces<IEnumerable<CatalogoItemDto<string>>>();

        grupo.MapGet("/modalidades-trabajo", async (ICatalogoRepositorio repo) =>
            Responder(await repo.ObtenerTiposValorPorSpAsync("MODALIDAD_TRABAJO")))
        .WithName("ObtenerCatalogoModalidadesTrabajo")
        .Produces<IEnumerable<CatalogoItemDto<string>>>();
    }

    private static IResult Responder<T>(RespuestaOperacionDto<T> respuestaRepo) =>
        respuestaRepo.EsExitoso
            ? RespuestaHttp.Ok(respuestaRepo.Datos, respuestaRepo.Mensaje)
            : RespuestaHttp.ErrorValidacion(new[] { respuestaRepo.Mensaje });
}
