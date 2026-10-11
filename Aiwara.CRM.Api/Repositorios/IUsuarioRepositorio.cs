using Aiwara.CRM.Api.DTOs;
using Aiwara.CRM.Api.Entidades;

namespace Aiwara.CRM.Api.Repositorios;

/// <summary>
/// Interfaz del repositorio de Usuarios (Mantenimiento > Usuarios).
/// Retorna RespuestaOperacionDto con estructura: esExitoso, mensaje, datos
/// </summary>
public interface IUsuarioRepositorio
{
    /// <summary>
    /// Obtiene los usuarios con filtros opcionales.
    /// SP: [dbo].[PRMKK_CON_BOF_USUARIO]
    /// </summary>
    Task<RespuestaOperacionDto<IEnumerable<EUsuario>>> ObtenerTodosPorSpAsync(FiltroUsuarioDto filtro);

    /// <summary>
    /// Obtiene un usuario por su ID.
    /// SP: [dbo].[PRMKK_CON_BOF_USUARIO]
    /// </summary>
    Task<RespuestaOperacionDto<EUsuario>> ObtenerPorIdPorSpAsync(int id);

    /// <summary>
    /// Totales de las tarjetas: activos, contratos vencidos, activos por campaña y por sede.
    /// SP: [dbo].[PRMKK_CON_BOF_USUARIO_RESUMEN]
    /// </summary>
    Task<RespuestaOperacionDto<UsuarioResumenDto>> ObtenerResumenPorSpAsync();

    /// <summary>
    /// Crea persona, usuario, perfil, personal y primer periodo laboral. Retorna el ID del usuario.
    /// SP: [dbo].[PRMKK_INS_BOF_USUARIO]
    /// </summary>
    Task<RespuestaOperacionDto<int>> CrearPorSpAsync(EUsuario entidad, string passwordHash);

    /// <summary>
    /// Actualiza los datos del usuario (abre un nuevo periodo laboral si se reactiva).
    /// SP: [dbo].[PRMKK_UPD_BOF_USUARIO]
    /// </summary>
    Task<RespuestaOperacionDto<object>> ActualizarPorSpAsync(EUsuario entidad);

    /// <summary>
    /// Activa (V) o inactiva (I) el usuario; al inactivar cierra sus sesiones.
    /// SP: [dbo].[PRMKK_UPD_BOF_EST_USUARIO]
    /// </summary>
    Task<RespuestaOperacionDto<object>> CambiarEstadoPorSpAsync(int id, string estado, string usuarioAuditoria);

    /// <summary>
    /// Reemplaza la contraseña, obliga a cambiarla en el próximo login y cierra sus sesiones.
    /// SP: [dbo].[PRMKK_UPD_BOF_CAMBIAR_PASSWORD]
    /// </summary>
    Task<RespuestaOperacionDto<object>> RestablecerPasswordPorSpAsync(int id, string passwordHash, string usuarioAuditoria);
}
