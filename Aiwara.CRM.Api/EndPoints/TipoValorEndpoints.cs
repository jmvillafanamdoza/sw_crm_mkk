using Aiwara.CRM.Api.DTOs;
using Aiwara.CRM.Api.Repositorios;
using Aiwara.CRM.Api.Utilitarios;
using AutoMapper;
using FluentValidation;

namespace Aiwara.CRM.Api.EndPoints;

/// <summary>
/// Endpoints de Tipos de Valor.
/// Retorna respuestas estructuradas con RespuestaApiDto que encapsula RespuestaOperacionDto.
/// </summary>
public static class TipoValorEndpoints
{
    public static void MapTipoValorEndpoints(this WebApplication app)
    {
        var grupo = app.MapGroup("/api/tipos-valor")
                       .WithTags(Constantes.Grupos.TipoValor);

        // GET: Obtener todos los tipos de valor con filtros opcionales
        grupo.MapGet("/", async (
            string? codigoTipoValor,
            string? tipoValor,
            string? descripcionPrincipal,
            ITipoValorRepositorio repo,
            IMapper mapper) =>
        {
            var respuestaRepo = await repo.ObtenerTodosPorSpAsync(codigoTipoValor, tipoValor, descripcionPrincipal);

            if (!respuestaRepo.EsExitoso)
            {
                return RespuestaHttp.ErrorValidacion(new[] { respuestaRepo.Mensaje });
            }

            var dtos = mapper.Map<IEnumerable<TipoValorDto>>(respuestaRepo.Datos);
            return RespuestaHttp.Ok(dtos, respuestaRepo.Mensaje);
        })
        .WithName("ObtenerTiposValor")
        .Produces<IEnumerable<TipoValorDto>>();

        // GET: Obtener un tipo de valor por código
        grupo.MapGet("/{codigoTipoValor}", async (
            string codigoTipoValor,
            ITipoValorRepositorio repo,
            IMapper mapper) =>
        {
            var respuestaRepo = await repo.ObtenerPorIdPorSpAsync(codigoTipoValor);

            if (!respuestaRepo.EsExitoso)
            {
                return RespuestaHttp.NoEncontrado(respuestaRepo.Mensaje);
            }

            var dto = mapper.Map<TipoValorDto>(respuestaRepo.Datos);
            return RespuestaHttp.Ok(dto, respuestaRepo.Mensaje);
        })
        .WithName("ObtenerTipoValorPorCodigo");

        // POST: Crear un nuevo tipo de valor
        grupo.MapPost("/", async (
            CrearTipoValorDto request,
            IValidator<CrearTipoValorDto> validator,
            ITipoValorRepositorio repo,
            IMapper mapper) =>
        {
            var validacion = await validator.ValidateAsync(request);
            if (!validacion.IsValid)
            {
                var errores = validacion.Errors.Select(e => e.ErrorMessage);
                return RespuestaHttp.ErrorValidacion(errores);
            }

            var entidad = mapper.Map<Entidades.ETipoValor>(request);
            var respuestaRepo = await repo.CrearPorSpAsync(entidad);

            if (!respuestaRepo.EsExitoso)
            {
                return RespuestaHttp.ErrorValidacion(new[] { respuestaRepo.Mensaje });
            }

            var dto = mapper.Map<TipoValorDto>(respuestaRepo.Datos);
            return RespuestaHttp.Creado($"/api/tipos-valor/{respuestaRepo.Datos?.CodigoTipoValor}", dto, respuestaRepo.Mensaje);
        })
        .WithName("CrearTipoValor");

        // PUT: Actualizar datos de un tipo de valor
        grupo.MapPut("/{codigoTipoValor}", async (
            string codigoTipoValor,
            CrearTipoValorDto request,
            IValidator<CrearTipoValorDto> validator,
            ITipoValorRepositorio repo,
            IMapper mapper) =>
        {
            var validacion = await validator.ValidateAsync(request);
            if (!validacion.IsValid)
            {
                var errores = validacion.Errors.Select(e => e.ErrorMessage);
                return RespuestaHttp.ErrorValidacion(errores);
            }

            var entidad = mapper.Map<Entidades.ETipoValor>(request);
            entidad.CodigoTipoValor = codigoTipoValor;
            var respuestaRepo = await repo.ActualizarPorSpAsync(entidad);

            if (!respuestaRepo.EsExitoso)
            {
                return RespuestaHttp.ErrorValidacion(new[] { respuestaRepo.Mensaje });
            }

            var dto = mapper.Map<TipoValorDto>(respuestaRepo.Datos);
            return RespuestaHttp.Ok(dto, respuestaRepo.Mensaje);
        })
        .WithName("ActualizarTipoValor");

        // PUT: Cambiar estado de un tipo de valor (eliminación lógica)
        grupo.MapPut("/{codigoTipoValor}/estado", async (
            string codigoTipoValor,
            CambiarEstadoTipoValorDto request,
            IValidator<CambiarEstadoTipoValorDto> validator,
            ITipoValorRepositorio repo) =>
        {
            if (codigoTipoValor != request.CodigoTipoValor)
            {
                return RespuestaHttp.ErrorValidacion(new[] { "El código en la URL no coincide con el del body." });
            }

            var validacion = await validator.ValidateAsync(request);
            if (!validacion.IsValid)
            {
                var errores = validacion.Errors.Select(e => e.ErrorMessage);
                return RespuestaHttp.ErrorValidacion(errores);
            }

            var respuestaRepo = await repo.CambiarEstadoPorSpAsync(request.CodigoTipoValor, request.TipoValor, request.Estado);

            if (!respuestaRepo.EsExitoso)
            {
                return RespuestaHttp.ErrorValidacion(new[] { respuestaRepo.Mensaje });
            }

            return RespuestaHttp.Ok(respuestaRepo.Datos, respuestaRepo.Mensaje);
        })
        .WithName("CambiarEstadoTipoValor");
    }
}
