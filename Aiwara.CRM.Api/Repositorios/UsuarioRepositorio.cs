using Aiwara.CRM.Api.DTOs;
using Aiwara.CRM.Api.Entidades;
using Aiwara.CRM.Api.Utilitarios;
using Dapper;
using System.Data;

namespace Aiwara.CRM.Api.Repositorios;

/// <summary>
/// Repositorio de Usuarios usando Dapper con Stored Procedures.
/// Patrón: DynamicParameters explícitos + respuestas robustas con RespuestaOperacionDto
/// </summary>
public class UsuarioRepositorio : IUsuarioRepositorio
{
    private readonly IConnectionFactory _connectionFactory;

    public UsuarioRepositorio(IConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    // ==================== MÉTODOS DE LECTURA ====================

    public async Task<RespuestaOperacionDto<IEnumerable<EUsuario>>> ObtenerTodosPorSpAsync(FiltroUsuarioDto filtro)
    {
        try
        {
            using var connection = _connectionFactory.CreateConnection();
            const string spName = "[dbo].[PRMKK_CON_BOF_USUARIO]";

            var parametros = new DynamicParameters();
            parametros.Add("@i_CPFL_ID_PERFIL", filtro.PerfilId);
            parametros.Add("@i_CCAM_ID_CAMPANIA", filtro.CampaniaId);
            parametros.Add("@i_CSED_ID_SEDE", filtro.SedeId);
            parametros.Add("@i_SOLO_VENCIDOS", filtro.SoloVencidos == true ? "S" : "N");
            parametros.Add("@i_ESTADO", filtro.Estado ?? "");
            parametros.Add("@i_TEXTO", filtro.Texto?.Trim() ?? "");

            var resultado = await connection.QueryAsync<UsuarioSpResultDto>(
                spName,
                parametros,
                commandType: CommandType.StoredProcedure
            );

            var datos = resultado.Select(MapearEntidad).ToList();

            return RespuestaOperacionDto<IEnumerable<EUsuario>>.Exitoso(
                datos,
                $"Se obtuvieron {datos.Count} usuarios correctamente.");
        }
        catch (Exception ex)
        {
            return RespuestaOperacionDto<IEnumerable<EUsuario>>.Error(
                $"Error al obtener usuarios: {ex.Message}");
        }
    }

    public async Task<RespuestaOperacionDto<EUsuario>> ObtenerPorIdPorSpAsync(int id)
    {
        try
        {
            using var connection = _connectionFactory.CreateConnection();
            const string spName = "[dbo].[PRMKK_CON_BOF_USUARIO]";

            var parametros = new DynamicParameters();
            parametros.Add("@i_CUSU_ID_USUARIO", id);

            var resultado = await connection.QueryFirstOrDefaultAsync<UsuarioSpResultDto>(
                spName,
                parametros,
                commandType: CommandType.StoredProcedure
            );

            if (resultado == null)
            {
                return RespuestaOperacionDto<EUsuario>.Error($"No se encontró el usuario con ID '{id}'.");
            }

            return RespuestaOperacionDto<EUsuario>.Exitoso(
                MapearEntidad(resultado),
                "Usuario obtenido correctamente.");
        }
        catch (Exception ex)
        {
            return RespuestaOperacionDto<EUsuario>.Error(
                $"Error al obtener usuario: {ex.Message}");
        }
    }

    public async Task<RespuestaOperacionDto<UsuarioResumenDto>> ObtenerResumenPorSpAsync()
    {
        try
        {
            using var connection = _connectionFactory.CreateConnection();
            const string spName = "[dbo].[PRMKK_CON_BOF_USUARIO_RESUMEN]";

            using var resultados = await connection.QueryMultipleAsync(
                spName,
                commandType: CommandType.StoredProcedure
            );

            var totales = await resultados.ReadFirstOrDefaultAsync<UsuarioResumenTotalesSpResultDto>();
            var porCampania = await resultados.ReadAsync<UsuarioResumenCampaniaSpResultDto>();
            var porSede = await resultados.ReadAsync<UsuarioResumenSedeSpResultDto>();

            var resumen = new UsuarioResumenDto
            {
                Activos = totales?.NACTIVOS ?? 0,
                ContratosVencidos = totales?.NCONTRATOS_VENCIDOS ?? 0,
                PorCampania = porCampania.Select(c => new UsuarioResumenGrupoDto
                {
                    Id = c.CCAM_ID_CAMPANIA,
                    Nombre = c.SCAM_NOMBRE ?? string.Empty,
                    Usuarios = c.NUSUARIOS
                }).ToList(),
                PorSede = porSede.Select(s => new UsuarioResumenGrupoDto
                {
                    Id = s.CSED_ID_SEDE,
                    Nombre = s.SSED_NOMBRE ?? string.Empty,
                    Usuarios = s.NUSUARIOS
                }).ToList()
            };

            return RespuestaOperacionDto<UsuarioResumenDto>.Exitoso(resumen, "Resumen obtenido correctamente.");
        }
        catch (Exception ex)
        {
            return RespuestaOperacionDto<UsuarioResumenDto>.Error(
                $"Error al obtener el resumen de usuarios: {ex.Message}");
        }
    }

    // ==================== MÉTODOS DE ESCRITURA ====================

    public async Task<RespuestaOperacionDto<int>> CrearPorSpAsync(EUsuario entidad, string passwordHash)
    {
        try
        {
            using var connection = _connectionFactory.CreateConnection();
            const string spName = "[dbo].[PRMKK_INS_BOF_USUARIO]";

            var parametros = ParametrosGuardar(entidad);
            parametros.Add("@i_PASSWORD_HASH", passwordHash);
            parametros.Add("@i_AUD_INS_USER", entidad.UsuarioAuditoria ?? "ADMIN");
            parametros.Add("@o_CUSU_ID_USUARIO", dbType: DbType.Int32, direction: ParameterDirection.Output);
            parametros.Add("@o_CPEL_ID_PERSONAL", dbType: DbType.Int32, direction: ParameterDirection.Output);
            parametros.Add("@o_resultMessage", dbType: DbType.String, size: 500, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(
                spName,
                parametros,
                commandType: CommandType.StoredProcedure
            );

            var respuesta = RespuestaSp.Parsear(parametros.Get<string>("@o_resultMessage"));

            if (!respuesta.EsExitoso)
            {
                return RespuestaOperacionDto<int>.Error(respuesta.Mensaje);
            }

            return RespuestaOperacionDto<int>.Exitoso(
                parametros.Get<int>("@o_CUSU_ID_USUARIO"),
                respuesta.Mensaje);
        }
        catch (Exception ex)
        {
            return RespuestaOperacionDto<int>.Error(
                $"Error al crear usuario: {ex.Message}");
        }
    }

    public async Task<RespuestaOperacionDto<object>> ActualizarPorSpAsync(EUsuario entidad)
    {
        try
        {
            using var connection = _connectionFactory.CreateConnection();
            const string spName = "[dbo].[PRMKK_UPD_BOF_USUARIO]";

            var parametros = ParametrosGuardar(entidad);
            parametros.Add("@i_CUSU_ID_USUARIO", entidad.Id);
            parametros.Add("@i_AUD_UPD_USER", entidad.UsuarioAuditoria ?? "ADMIN");
            parametros.Add("@o_resultMessage", dbType: DbType.String, size: 500, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(
                spName,
                parametros,
                commandType: CommandType.StoredProcedure
            );

            var respuesta = RespuestaSp.Parsear(parametros.Get<string>("@o_resultMessage"));

            if (!respuesta.EsExitoso)
            {
                return RespuestaOperacionDto<object>.Error(respuesta.Mensaje);
            }

            return RespuestaOperacionDto<object>.Exitoso(new { entidad.Id }, respuesta.Mensaje);
        }
        catch (Exception ex)
        {
            return RespuestaOperacionDto<object>.Error(
                $"Error al actualizar usuario: {ex.Message}");
        }
    }

    public async Task<RespuestaOperacionDto<object>> CambiarEstadoPorSpAsync(int id, string estado, string usuarioAuditoria)
    {
        try
        {
            using var connection = _connectionFactory.CreateConnection();
            const string spName = "[dbo].[PRMKK_UPD_BOF_EST_USUARIO]";

            var parametros = new DynamicParameters();
            parametros.Add("@i_CUSU_ID_USUARIO", id);
            parametros.Add("@i_ESTADO", estado.ToUpper());
            parametros.Add("@i_AUD_UPD_USER", usuarioAuditoria);
            parametros.Add("@o_resultMessage", dbType: DbType.String, size: 500, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(
                spName,
                parametros,
                commandType: CommandType.StoredProcedure
            );

            var respuesta = RespuestaSp.Parsear(parametros.Get<string>("@o_resultMessage"));

            if (!respuesta.EsExitoso)
            {
                return RespuestaOperacionDto<object>.Error(respuesta.Mensaje);
            }

            var estadoDescripcion = estado.ToUpper() == "V" ? "activado" : "inactivado";
            return RespuestaOperacionDto<object>.Exitoso(
                new { Id = id, Estado = estado.ToUpper() },
                $"Usuario {estadoDescripcion} correctamente.");
        }
        catch (Exception ex)
        {
            return RespuestaOperacionDto<object>.Error(
                $"Error al cambiar estado del usuario: {ex.Message}");
        }
    }

    public async Task<RespuestaOperacionDto<object>> RestablecerPasswordPorSpAsync(int id, string passwordHash, string usuarioAuditoria)
    {
        try
        {
            using var connection = _connectionFactory.CreateConnection();
            const string spName = "[dbo].[PRMKK_UPD_BOF_CAMBIAR_PASSWORD]";

            var parametros = new DynamicParameters();
            parametros.Add("@i_CUSU_ID_USUARIO", id);
            parametros.Add("@i_PASSWORD_HASH", passwordHash);
            parametros.Add("@i_FORZAR_CAMBIO", "S");
            parametros.Add("@i_CERRAR_SESIONES", "S");
            parametros.Add("@i_AUD_UPD_USER", usuarioAuditoria);
            parametros.Add("@o_resultMessage", dbType: DbType.String, size: 500, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(
                spName,
                parametros,
                commandType: CommandType.StoredProcedure
            );

            var respuesta = RespuestaSp.Parsear(parametros.Get<string>("@o_resultMessage"));

            if (!respuesta.EsExitoso)
            {
                return RespuestaOperacionDto<object>.Error(respuesta.Mensaje);
            }

            return RespuestaOperacionDto<object>.Exitoso(new { Id = id }, "Contraseña restablecida correctamente.");
        }
        catch (Exception ex)
        {
            return RespuestaOperacionDto<object>.Error(
                $"Error al restablecer la contraseña: {ex.Message}");
        }
    }

    // ==================== MÉTODOS AUXILIARES ====================

    /// <summary>
    /// Parámetros comunes de PRMKK_INS_BOF_USUARIO y PRMKK_UPD_BOF_USUARIO.
    /// </summary>
    private static DynamicParameters ParametrosGuardar(EUsuario entidad)
    {
        var parametros = new DynamicParameters();
        parametros.Add("@i_NOMBRE_COMPLETO", entidad.NombreCompleto.Trim());
        parametros.Add("@i_TIP_DOC", entidad.TipoDocumento, DbType.Byte);
        parametros.Add("@i_NRO_DOC", entidad.NroDocumento?.Trim() ?? "");
        parametros.Add("@i_CORREO", entidad.Correo?.Trim() ?? "");
        parametros.Add("@i_CELULAR", entidad.Celular?.Trim() ?? "");
        parametros.Add("@i_USERNAME", entidad.Usuario.Trim());
        parametros.Add("@i_CPFL_ID_PERFIL", entidad.PerfilId);
        parametros.Add("@i_CCAM_ID_CAMPANIA", entidad.CampaniaId);
        parametros.Add("@i_CSED_ID_SEDE", entidad.SedeId);
        parametros.Add("@i_CPEL_PUESTO", entidad.Puesto ?? "");
        parametros.Add("@i_FPEL_MODALIDAD", entidad.Modalidad ?? "");
        parametros.Add("@i_CPEL_ID_SUPERVISOR", entidad.SupervisorId);
        parametros.Add("@i_ID_BIO", entidad.IdBio?.Trim() ?? "");
        parametros.Add("@i_ID_VENTA", entidad.IdVenta?.Trim() ?? "");
        parametros.Add("@i_ID_OVER", entidad.IdOver?.Trim() ?? "");
        parametros.Add("@i_ID_VICI", entidad.IdVici?.Trim() ?? "");
        parametros.Add("@i_HORA_INICIO", AHora(entidad.HoraInicio), DbType.Time);
        parametros.Add("@i_HORA_FIN", AHora(entidad.HoraFin), DbType.Time);
        parametros.Add("@i_FEC_INGRESO", AFecha(entidad.FechaIngreso), DbType.Date);
        parametros.Add("@i_CONTRATO_INICIO", AFecha(entidad.ContratoInicio), DbType.Date);
        parametros.Add("@i_CONTRATO_FIN", AFecha(entidad.ContratoFin), DbType.Date);
        parametros.Add("@i_NUM_CUENTA", entidad.NumCuenta?.Trim() ?? "");
        parametros.Add("@i_ESTADO", entidad.Estado.ToUpper());

        return parametros;
    }

    private static TimeSpan? AHora(string? hora) =>
        TimeSpan.TryParse(hora, out var valor) ? valor : null;

    private static DateTime? AFecha(DateOnly? fecha) =>
        fecha?.ToDateTime(TimeOnly.MinValue);

    private static DateOnly? ADateOnly(DateTime? fecha) =>
        fecha.HasValue ? DateOnly.FromDateTime(fecha.Value) : null;

    private static EUsuario MapearEntidad(UsuarioSpResultDto r) => new()
    {
        Id = r.CUSU_ID_USUARIO,
        PersonalId = r.CPEL_ID_PERSONAL,
        TipoDocumento = r.FPER_TIP_DOC_IDENTIDAD ?? 1,
        NroDocumento = r.SNRO_DOCUMENTO,
        NombreCompleto = r.SNOMBRE_COMPLETO ?? string.Empty,
        Correo = r.SCORREO,
        Celular = r.SCELULAR,
        Usuario = r.SUSU_USERNAME ?? string.Empty,
        PerfilId = r.CPFL_ID_PERFIL ?? 0,
        Perfil = r.SPERFIL,
        CampaniaId = r.CCAM_ID_CAMPANIA,
        Campania = r.SCAMPANIA,
        SedeId = r.CSED_ID_SEDE,
        Sede = r.SSEDE,
        Puesto = r.CPEL_PUESTO,
        Modalidad = r.FPEL_MODALIDAD,
        SupervisorId = r.CPEL_ID_SUPERVISOR,
        IdBio = r.SID_BIO,
        IdVenta = r.SID_VENTA,
        IdOver = r.SID_OVER,
        IdVici = r.SID_VICI,
        NumCuenta = r.SNUM_CUENTA,
        HoraInicio = r.SHORA_INICIO,
        HoraFin = r.SHORA_FIN,
        FechaIngreso = ADateOnly(r.DFEC_INGRESO),
        FechaFin = ADateOnly(r.DFEC_FIN),
        ContratoInicio = ADateOnly(r.DCONTRATO_INICIO),
        ContratoFin = ADateOnly(r.DCONTRATO_FIN),
        ContratoVencido = r.FCONTRATO_VENCIDO == "S",
        Estado = r.FUSU_ESTADO ?? "I",
        UltimoLogin = r.DUSU_ULTIMO_LOGIN
    };
}
