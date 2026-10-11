using Aiwara.CRM.Api.DTOs;
using Aiwara.CRM.Api.Entidades;
using Aiwara.CRM.Api.Repositorios;
using Aiwara.CRM.Api.Utilitarios;
using AutoMapper;
using FluentValidation;

namespace Aiwara.CRM.Api.EndPoints;

/// <summary>
/// Endpoints de Mantenimiento > Usuarios.
/// Retorna respuestas estructuradas con RespuestaApiDto que encapsula RespuestaOperacionDto.
/// </summary>
public static class UsuarioEndpoints
{
    public static void MapUsuarioEndpoints(this WebApplication app)
    {
        var grupo = app.MapGroup("/api/usuarios")
                       .WithTags(Constantes.Grupos.Usuario);

        // GET: Listado con filtros opcionales (perfil, campaña, sede, vencidos, estado, texto)
        grupo.MapGet("/", async (
            [AsParameters] FiltroUsuarioDto filtro,
            IUsuarioRepositorio repo,
            IMapper mapper) =>
        {
            var respuestaRepo = await repo.ObtenerTodosPorSpAsync(filtro);

            if (!respuestaRepo.EsExitoso)
            {
                return RespuestaHttp.ErrorValidacion(new[] { respuestaRepo.Mensaje });
            }

            var dtos = mapper.Map<IEnumerable<UsuarioDto>>(respuestaRepo.Datos);
            return RespuestaHttp.Ok(dtos, respuestaRepo.Mensaje);
        })
        .WithName("ObtenerUsuarios")
        .Produces<IEnumerable<UsuarioDto>>();

        // GET: Totales de las tarjetas (activos, vencidos, por campaña y por sede)
        grupo.MapGet("/resumen", async (IUsuarioRepositorio repo) =>
        {
            var respuestaRepo = await repo.ObtenerResumenPorSpAsync();

            if (!respuestaRepo.EsExitoso)
            {
                return RespuestaHttp.ErrorValidacion(new[] { respuestaRepo.Mensaje });
            }

            return RespuestaHttp.Ok(respuestaRepo.Datos, respuestaRepo.Mensaje);
        })
        .WithName("ObtenerResumenUsuarios")
        .Produces<UsuarioResumenDto>();

        // GET: Obtener un usuario por ID
        grupo.MapGet("/{id:int}", async (
            int id,
            IUsuarioRepositorio repo,
            IMapper mapper) =>
        {
            var respuestaRepo = await repo.ObtenerPorIdPorSpAsync(id);

            if (!respuestaRepo.EsExitoso)
            {
                return RespuestaHttp.NoEncontrado(respuestaRepo.Mensaje);
            }

            var dto = mapper.Map<UsuarioDto>(respuestaRepo.Datos);
            return RespuestaHttp.Ok(dto, respuestaRepo.Mensaje);
        })
        .WithName("ObtenerUsuarioPorId")
        .Produces<UsuarioDto>();

        // POST: Crear un usuario con contraseña temporal (se devuelve una sola vez)
        grupo.MapPost("/", async (
            GuardarUsuarioDto request,
            IValidator<GuardarUsuarioDto> validator,
            IUsuarioRepositorio repo,
            IMapper mapper) =>
        {
            var validacion = await validator.ValidateAsync(request);
            if (!validacion.IsValid)
            {
                var errores = validacion.Errors.Select(e => e.ErrorMessage);
                return RespuestaHttp.ErrorValidacion(errores);
            }

            var entidad = mapper.Map<EUsuario>(request);
            var passwordTemporal = GeneradorPassword.GenerarTemporal();
            var respuestaRepo = await repo.CrearPorSpAsync(entidad, GeneradorPassword.Hashear(passwordTemporal));

            if (!respuestaRepo.EsExitoso)
            {
                return RespuestaHttp.ErrorValidacion(new[] { respuestaRepo.Mensaje });
            }

            var creado = await repo.ObtenerPorIdPorSpAsync(respuestaRepo.Datos);
            var dto = new UsuarioPasswordTemporalDto
            {
                Usuario = creado.EsExitoso ? mapper.Map<UsuarioDto>(creado.Datos) : null,
                PasswordTemporal = passwordTemporal
            };

            return RespuestaHttp.Creado($"/api/usuarios/{respuestaRepo.Datos}", dto, respuestaRepo.Mensaje);
        })
        .WithName("CrearUsuario")
        .Produces<UsuarioPasswordTemporalDto>(StatusCodes.Status201Created);

        // PUT: Actualizar datos de un usuario
        grupo.MapPut("/{id:int}", async (
            int id,
            GuardarUsuarioDto request,
            IValidator<GuardarUsuarioDto> validator,
            IUsuarioRepositorio repo,
            IMapper mapper) =>
        {
            var validacion = await validator.ValidateAsync(request);
            if (!validacion.IsValid)
            {
                var errores = validacion.Errors.Select(e => e.ErrorMessage);
                return RespuestaHttp.ErrorValidacion(errores);
            }

            var entidad = mapper.Map<EUsuario>(request);
            entidad.Id = id;
            var respuestaRepo = await repo.ActualizarPorSpAsync(entidad);

            if (!respuestaRepo.EsExitoso)
            {
                return RespuestaHttp.ErrorValidacion(new[] { respuestaRepo.Mensaje });
            }

            var actualizado = await repo.ObtenerPorIdPorSpAsync(id);
            return RespuestaHttp.Ok(actualizado.EsExitoso ? mapper.Map<UsuarioDto>(actualizado.Datos) : null, respuestaRepo.Mensaje);
        })
        .WithName("ActualizarUsuario")
        .Produces<UsuarioDto>();

        // PUT: Activar / inactivar un usuario (al inactivar se cierran sus sesiones)
        grupo.MapPut("/{id:int}/estado", async (
            int id,
            CambiarEstadoUsuarioDto request,
            IValidator<CambiarEstadoUsuarioDto> validator,
            IUsuarioRepositorio repo) =>
        {
            var validacion = await validator.ValidateAsync(request);
            if (!validacion.IsValid)
            {
                var errores = validacion.Errors.Select(e => e.ErrorMessage);
                return RespuestaHttp.ErrorValidacion(errores);
            }

            var respuestaRepo = await repo.CambiarEstadoPorSpAsync(id, request.Estado, request.UsuarioAuditoria);

            if (!respuestaRepo.EsExitoso)
            {
                return RespuestaHttp.ErrorValidacion(new[] { respuestaRepo.Mensaje });
            }

            return RespuestaHttp.Ok(respuestaRepo.Datos, respuestaRepo.Mensaje);
        })
        .WithName("CambiarEstadoUsuario");

        // PUT: Restablecer la contraseña (genera una temporal y obliga a cambiarla al ingresar)
        grupo.MapPut("/{id:int}/password", async (
            int id,
            RestablecerPasswordUsuarioDto request,
            IValidator<RestablecerPasswordUsuarioDto> validator,
            IUsuarioRepositorio repo) =>
        {
            var validacion = await validator.ValidateAsync(request);
            if (!validacion.IsValid)
            {
                var errores = validacion.Errors.Select(e => e.ErrorMessage);
                return RespuestaHttp.ErrorValidacion(errores);
            }

            var passwordTemporal = GeneradorPassword.GenerarTemporal();
            var respuestaRepo = await repo.RestablecerPasswordPorSpAsync(
                id, GeneradorPassword.Hashear(passwordTemporal), request.UsuarioAuditoria);

            if (!respuestaRepo.EsExitoso)
            {
                return RespuestaHttp.ErrorValidacion(new[] { respuestaRepo.Mensaje });
            }

            return RespuestaHttp.Ok(new UsuarioPasswordTemporalDto { PasswordTemporal = passwordTemporal }, respuestaRepo.Mensaje);
        })
        .WithName("RestablecerPasswordUsuario")
        .Produces<UsuarioPasswordTemporalDto>();
    }
}
