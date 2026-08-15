using Aiwara.CRM.Api.DTOs;
using Aiwara.CRM.Api.Entidades;

namespace Aiwara.CRM.Api.Repositorios;

/// <summary>
/// Interfaz del repositorio de Tipos de Valor.
/// Retorna RespuestaOperacionDto con estructura: esExitoso, mensaje, datos
/// </summary>
public interface ITipoValorRepositorio
{
    /// <summary>
    /// Obtiene todos los tipos de valor con filtros opcionales mediante SP.
    /// SP: [dbo].[PRMKK_CON_BOF_TIP_VALOR]
    /// </summary>
    Task<RespuestaOperacionDto<IEnumerable<ETipoValor>>> ObtenerTodosPorSpAsync(
        string? codigoTipoValor = null,
        string? tipoValor = null,
        string? descripcion = null);

    /// <summary>
    /// Obtiene un tipo de valor por su código mediante SP.
    /// </summary>
    Task<RespuestaOperacionDto<ETipoValor>> ObtenerPorIdPorSpAsync(string codigoTipoValor);

    /// <summary>
    /// Crea un nuevo tipo de valor mediante SP.
    /// SP: [dbo].[PRMKK_INS_BOF_TIP_VALOR]
    /// Retorna respuesta con esExitoso, mensaje y datos del registro creado.
    /// </summary>
    Task<RespuestaOperacionDto<ETipoValor>> CrearPorSpAsync(ETipoValor entidad);

    /// <summary>
    /// Actualiza los datos de un tipo de valor mediante SP.
    /// SP: [dbo].[PRMKK_UPD_BOF_TIP_VALOR]
    /// Retorna respuesta con esExitoso, mensaje y datos del registro actualizado.
    /// </summary>
    Task<RespuestaOperacionDto<ETipoValor>> ActualizarPorSpAsync(ETipoValor entidad);

    /// <summary>
    /// Cambia el estado de un tipo de valor (eliminación lógica) mediante SP.
    /// SP: [dbo].[PRMKK_UPD_BOF_EST_TIP_VALOR]
    /// Retorna respuesta con esExitoso y mensaje.
    /// </summary>
    Task<RespuestaOperacionDto<object>> CambiarEstadoPorSpAsync(string codigoTipoValor, string tipoValor, string estado);

    /// <summary>
    /// Elimina un tipo de valor mediante SP (eliminación física).
    /// SP: [dbo].[PRMKK_DEL_BOF_TIP_VALOR]
    /// Retorna respuesta con esExitoso y mensaje.
    /// </summary>
    Task<RespuestaOperacionDto<object>> EliminarPorSpAsync(string codigoTipoValor);
}
