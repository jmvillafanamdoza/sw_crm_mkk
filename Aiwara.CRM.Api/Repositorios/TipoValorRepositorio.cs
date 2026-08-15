using Aiwara.CRM.Api.DTOs;
using Aiwara.CRM.Api.Entidades;
using Dapper;
using System.Data;

namespace Aiwara.CRM.Api.Repositorios;

/// <summary>
/// Repositorio de Tipos de Valor usando Dapper con Stored Procedures.
/// Patrón: DynamicParameters explícitos + respuestas robustas con RespuestaOperacionDto
/// </summary>
public class TipoValorRepositorio : ITipoValorRepositorio
{
    private readonly IConnectionFactory _connectionFactory;

    public TipoValorRepositorio(IConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    // ==================== MÉTODOS DE LECTURA ====================

    /// <summary>
    /// Obtiene todos los tipos de valor con filtros opcionales.
    /// SP: [dbo].[PRMKK_CON_BOF_TIP_VALOR]
    /// Retorna columnas: id, descripcion
    /// </summary>
    public async Task<RespuestaOperacionDto<IEnumerable<ETipoValor>>> ObtenerTodosPorSpAsync(
        string? tipoEstado = null,
        string? valor = null,
        string? descripcion = null)
    {
        try
        {
            using var connection = _connectionFactory.CreateConnection();
            const string spName = "[dbo].[PRMKK_CON_BOF_TIP_VALOR]";

            // Parámetros explícitos con DynamicParameters
            var parametros = new DynamicParameters();
            parametros.Add("@i_TIP_ESTADO", tipoEstado ?? "");
            parametros.Add("@i_TIP_VALOR", valor ?? "");
            parametros.Add("@i_DESCRIPCION", descripcion ?? "");

            var resultado = await connection.QueryAsync<TipoValorSpResultDto>(
                spName,
                parametros,
                commandType: CommandType.StoredProcedure
            );

            if (!resultado.Any())
            {
                return RespuestaOperacionDto<IEnumerable<ETipoValor>>.Error(
                    "No se encontraron tipos de valor con los filtros especificados.");
            }

            // Mapear los resultados a ETipoValor
            var datos = resultado.Select(r => new ETipoValor
            {
                CodigoTipoValor = r.CTPV_COD_TIP_VALOR ?? r.id?.ToString() ?? string.Empty,
                TipoValor = r.CTPV_TIP_VALOR ?? string.Empty,
                DescripcionPrincipal = r.STPV_DES_TIP_VALOR_1 ?? r.descripcion ?? string.Empty,
                Descripcion2 = r.STPV_DES_TIP_VALOR_2,
                Descripcion3 = r.STPV_DES_TIP_VALOR_3,
                UsuarioInsercion = r.AUD_INS_USER,
                FechaCreacion = r.AUD_INS_DATE
            }).ToList();

            return RespuestaOperacionDto<IEnumerable<ETipoValor>>.Exitoso(
                datos,
                $"Se obtuvieron {datos.Count} tipos de valor correctamente.");
        }
        catch (Exception ex)
        {
            return RespuestaOperacionDto<IEnumerable<ETipoValor>>.Error(
                $"Error al obtener tipos de valor: {ex.Message}");
        }
    }

    /// <summary>
    /// Obtiene un tipo de valor por su ID.
    /// SP: [dbo].[PRMKK_CON_BOF_TIP_VALOR]
    /// </summary>
    public async Task<RespuestaOperacionDto<ETipoValor>> ObtenerPorIdPorSpAsync(string id)
    {
        try
        {
            if (string.IsNullOrEmpty(id))
            {
                return RespuestaOperacionDto<ETipoValor>.Error("El ID del tipo de valor es requerido.");
            }

            using var connection = _connectionFactory.CreateConnection();
            const string spName = "[dbo].[PRMKK_CON_BOF_TIP_VALOR]";

            var parametros = new DynamicParameters();
            parametros.Add("@i_TIP_VALOR", id);

            var resultado = await connection.QueryFirstOrDefaultAsync<TipoValorSpResultDto>(
                spName,
                parametros,
                commandType: CommandType.StoredProcedure
            );

            if (resultado == null)
            {
                return RespuestaOperacionDto<ETipoValor>.Error(
                    $"No se encontró tipo de valor con ID '{id}'.");
            }

            var entidad = new ETipoValor
            {
                CodigoTipoValor = resultado.CTPV_COD_TIP_VALOR ?? resultado.id?.ToString() ?? string.Empty,
                TipoValor = resultado.CTPV_TIP_VALOR ?? string.Empty,
                DescripcionPrincipal = resultado.STPV_DES_TIP_VALOR_1 ?? resultado.descripcion ?? string.Empty,
                Descripcion2 = resultado.STPV_DES_TIP_VALOR_2,
                Descripcion3 = resultado.STPV_DES_TIP_VALOR_3,
                UsuarioInsercion = resultado.AUD_INS_USER,
                FechaCreacion = resultado.AUD_INS_DATE
            };

            return RespuestaOperacionDto<ETipoValor>.Exitoso(
                entidad,
                "Tipo de valor obtenido correctamente.");
        }
        catch (Exception ex)
        {
            return RespuestaOperacionDto<ETipoValor>.Error(
                $"Error al obtener tipo de valor: {ex.Message}");
        }
    }

    // ==================== MÉTODOS DE ESCRITURA ====================

    /// <summary>
    /// Crea un nuevo tipo de valor mediante SP.
    /// SP: [dbo].[PRMKK_INS_BOF_TIP_VALOR]
    /// Retorna respuesta con esExitoso, mensaje y datos del registro creado.
    /// </summary>
    public async Task<RespuestaOperacionDto<ETipoValor>> CrearPorSpAsync(ETipoValor entidad)
    {
        try
        {
            // Validaciones básicas
            if (string.IsNullOrEmpty(entidad.CodigoTipoValor))
            {
                return RespuestaOperacionDto<ETipoValor>.Error("El código del tipo de valor es requerido.");
            }

            if (string.IsNullOrEmpty(entidad.TipoValor))
            {
                return RespuestaOperacionDto<ETipoValor>.Error("El tipo de valor es requerido.");
            }

            if (string.IsNullOrEmpty(entidad.DescripcionPrincipal))
            {
                return RespuestaOperacionDto<ETipoValor>.Error("La descripción principal es requerida.");
            }

            using var connection = _connectionFactory.CreateConnection();
            const string spName = "[dbo].[PRMKK_INS_BOF_TIP_VALOR]";

            // Parámetros explícitos según el SP: PRMKK_INS_BOF_TIP_VALOR
            var parametros = new DynamicParameters();
            parametros.Add("@i_CTPV_COD_TIP_VALOR", entidad.CodigoTipoValor);
            parametros.Add("@i_CTPV_TIP_VALOR", entidad.TipoValor);
            parametros.Add("@i_STPV_DES_TIP_VALOR_1", entidad.DescripcionPrincipal);
            parametros.Add("@i_STPV_DES_TIP_VALOR_2", entidad.Descripcion2 ?? "");
            parametros.Add("@i_STPV_DES_TIP_VALOR_3", entidad.Descripcion3 ?? "");
            parametros.Add("@i_AUD_INS_USER", entidad.UsuarioInsercion ?? "ADMIN");

            // Parámetro OUTPUT para recibir el mensaje de respuesta
            parametros.Add("@o_resultMessage", dbType: DbType.String, size: 500, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(
                spName,
                parametros,
                commandType: CommandType.StoredProcedure
            );

            // Obtener el mensaje de resultado del OUTPUT parameter
            var mensajeRespuesta = parametros.Get<string>("@o_resultMessage");
            var respuesta = ParsearRespuestaSp(mensajeRespuesta);

            if (!respuesta.EsExitoso)
            {
                return RespuestaOperacionDto<ETipoValor>.Error(respuesta.Mensaje);
            }

            return RespuestaOperacionDto<ETipoValor>.Exitoso(
                entidad,
                respuesta.Mensaje);
        }
        catch (Exception ex)
        {
            return RespuestaOperacionDto<ETipoValor>.Error(
                $"Error al crear tipo de valor: {ex.Message}");
        }
    }

    /// <summary>
    /// Actualiza los datos de un tipo de valor mediante SP.
    /// SP: [dbo].[PRMKK_UPD_BOF_TIP_VALOR]
    /// Retorna respuesta con esExitoso, mensaje y datos del registro actualizado.
    /// </summary>
    public async Task<RespuestaOperacionDto<ETipoValor>> ActualizarPorSpAsync(ETipoValor entidad)
    {
        try
        {
            if (string.IsNullOrEmpty(entidad.CodigoTipoValor))
            {
                return RespuestaOperacionDto<ETipoValor>.Error("El código del tipo de valor es requerido.");
            }

            using var connection = _connectionFactory.CreateConnection();
            const string spName = "[dbo].[PRMKK_UPD_BOF_TIP_VALOR]";

            var parametros = new DynamicParameters();
            parametros.Add("@i_CTPV_COD_TIP_VALOR", entidad.CodigoTipoValor);
            parametros.Add("@i_CTPV_TIP_VALOR", entidad.TipoValor ?? "");
            parametros.Add("@i_STPV_DES_TIP_VALOR_1", entidad.DescripcionPrincipal ?? "");
            parametros.Add("@i_STPV_DES_TIP_VALOR_2", entidad.Descripcion2 ?? "");
            parametros.Add("@i_STPV_DES_TIP_VALOR_3", entidad.Descripcion3 ?? "");
            parametros.Add("@i_AUD_UPD_USER", entidad.UsuarioActualizacion ?? "ADMIN");
            parametros.Add("@o_resultMessage", dbType: DbType.String, size: 4000, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(
                spName,
                parametros,
                commandType: CommandType.StoredProcedure
            );

            var mensajeRespuesta = parametros.Get<string>("@o_resultMessage");
            var respuesta = ParsearRespuestaSp(mensajeRespuesta);

            if (!respuesta.EsExitoso)
            {
                return RespuestaOperacionDto<ETipoValor>.Error(respuesta.Mensaje);
            }

            return RespuestaOperacionDto<ETipoValor>.Exitoso(
                entidad,
                respuesta.Mensaje);
        }
        catch (Exception ex)
        {
            return RespuestaOperacionDto<ETipoValor>.Error(
                $"Error al actualizar tipo de valor: {ex.Message}");
        }
    }

    /// <summary>
    /// Cambia el estado de un tipo de valor (eliminación lógica) mediante SP.
    /// SP: [dbo].[PRMKK_UPD_BOF_EST_TIP_VALOR]
    /// Retorna respuesta con esExitoso y mensaje.
    /// Estado: A=Activo, I=Inactivo
    /// </summary>
    public async Task<RespuestaOperacionDto<object>> CambiarEstadoPorSpAsync(string codigoTipoValor, string tipoValor, string estado)
    {
        try
        {
            if (string.IsNullOrEmpty(codigoTipoValor))
            {
                return RespuestaOperacionDto<object>.Error("El código del tipo de valor es requerido.");
            }

            if (string.IsNullOrEmpty(tipoValor))
            {
                return RespuestaOperacionDto<object>.Error("El tipo de valor es requerido.");
            }

            // Validar que estado sea A o I
            if (!new[] { "A", "I" }.Contains(estado.ToUpper()))
            {
                return RespuestaOperacionDto<object>.Error("El estado debe ser 'A' (Activo) o 'I' (Inactivo).");
            }

            using var connection = _connectionFactory.CreateConnection();
            const string spName = "[dbo].[PRMKK_UPD_BOF_EST_TIP_VALOR]";

            var parametros = new DynamicParameters();
            parametros.Add("@i_CTPV_COD_TIP_VALOR", codigoTipoValor);
            parametros.Add("@i_CTPV_TIP_VALOR", tipoValor);
            parametros.Add("@i_FTPV_ESTADO", estado.ToUpper());
            parametros.Add("@o_resultMessage", dbType: DbType.String, size: 4000, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(
                spName,
                parametros,
                commandType: CommandType.StoredProcedure
            );

            var mensajeRespuesta = parametros.Get<string>("@o_resultMessage");
            var respuesta = ParsearRespuestaSp(mensajeRespuesta);

            if (!respuesta.EsExitoso)
            {
                return RespuestaOperacionDto<object>.Error(respuesta.Mensaje);
            }

            var estadoDescripcion = estado.ToUpper() == "A" ? "Activado" : "Desactivado";
            return RespuestaOperacionDto<object>.Exitoso(
                new { CodigoTipoValor = codigoTipoValor, Estado = estadoDescripcion },
                $"Tipo de valor {estadoDescripcion} correctamente.");
        }
        catch (Exception ex)
        {
            return RespuestaOperacionDto<object>.Error(
                $"Error al cambiar estado del tipo de valor: {ex.Message}");
        }
    }

    /// <summary>
    /// Elimina un tipo de valor mediante SP.
    /// SP: [dbo].[PRMKK_DEL_BOF_TIP_VALOR]
    /// Retorna respuesta con esExitoso y mensaje.
    /// </summary>
    public async Task<RespuestaOperacionDto<object>> EliminarPorSpAsync(string id)
    {
        try
        {
            if (string.IsNullOrEmpty(id))
            {
                return RespuestaOperacionDto<object>.Error("El código del tipo de valor es requerido.");
            }

            using var connection = _connectionFactory.CreateConnection();
            const string spName = "[dbo].[PRMKK_DEL_BOF_TIP_VALOR]";

            var parametros = new DynamicParameters();
            parametros.Add("@i_CTPV_COD_TIP_VALOR", id);
            parametros.Add("@o_resultMessage", dbType: DbType.String, size: 500, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(
                spName,
                parametros,
                commandType: CommandType.StoredProcedure
            );

            var mensajeRespuesta = parametros.Get<string>("@o_resultMessage");
            var respuesta = ParsearRespuestaSp(mensajeRespuesta);

            if (!respuesta.EsExitoso)
            {
                return RespuestaOperacionDto<object>.Error(respuesta.Mensaje);
            }

            return RespuestaOperacionDto<object>.Exitoso(
                new { CodigoTipoValor = id },
                respuesta.Mensaje);
        }
        catch (Exception ex)
        {
            return RespuestaOperacionDto<object>.Error(
                $"Error al eliminar tipo de valor: {ex.Message}");
        }
    }

    // ==================== MÉTODOS AUXILIARES ====================

    /// <summary>
    /// Parsea la respuesta del Stored Procedure en formato "1|mensaje" o "0|error"
    /// Retorna objeto con EsExitoso y Mensaje
    /// </summary>
    private static (bool EsExitoso, string Mensaje) ParsearRespuestaSp(string? respuesta)
    {
        if (string.IsNullOrEmpty(respuesta))
        {
            return (false, "Sin respuesta del servidor");
        }

        var partes = respuesta.Split('|');
        var esExitoso = partes[0] == "1";
        var mensaje = partes.Length > 1 ? string.Join("|", partes.Skip(1)) : string.Empty;

        return (esExitoso, mensaje);
    }
}
