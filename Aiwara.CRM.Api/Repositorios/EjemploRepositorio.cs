using Aiwara.CRM.Api.Entidades;
using Dapper;
using System.Data;

namespace Aiwara.CRM.Api.Repositorios;

/// <summary>
/// Repositorio de ejemplo usando Dapper con Stored Procedures.
/// Todos los métodos consumen procedimientos almacenados en la base de datos.
/// </summary>
public class EjemploRepositorio : IEjemploRepositorio
{
    private readonly IConnectionFactory _connectionFactory;

    public EjemploRepositorio(IConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    // ==================== MÉTODOS DE LECTURA ====================

    /// <summary>
    /// Obtiene todos los registros de ejemplo mediante Stored Procedure.
    /// SP: sp_ObtenerEjemplos
    /// </summary>
    public async Task<IEnumerable<EEjemplo>> ObtenerTodosPorSpAsync()
    {
        using var connection = _connectionFactory.CreateConnection();
        const string spName = "sp_ObtenerEjemplos";

        return await connection.QueryAsync<EEjemplo>(
            spName,
            commandType: CommandType.StoredProcedure
        );
    }

    /// <summary>
    /// Obtiene un registro de ejemplo por su ID mediante Stored Procedure.
    /// SP: sp_ObtenerEjemploPorId
    /// </summary>
    public async Task<EEjemplo?> ObtenerPorIdPorSpAsync(int id)
    {
        using var connection = _connectionFactory.CreateConnection();
        const string spName = "sp_ObtenerEjemploPorId";

        return await connection.QueryFirstOrDefaultAsync<EEjemplo>(
            spName,
            new { @Id = id },
            commandType: CommandType.StoredProcedure
        );
    }

    // ==================== MÉTODOS DE ESCRITURA ====================

    /// <summary>
    /// Crea un nuevo registro de ejemplo mediante Stored Procedure.
    /// SP: sp_InsertarEjemplo
    /// Retorna: "1|mensaje" si es exitoso, "0|error" si falla
    /// </summary>
    public async Task<ResultadoOperacion> CrearPorSpAsync(EEjemplo entidad)
    {
        using var connection = _connectionFactory.CreateConnection();
        const string spName = "sp_InsertarEjemplo";

        var resultado = await connection.QueryFirstOrDefaultAsync<string>(
            spName,
            new
            {
                @Nombre = entidad.Nombre,
                @FechaCreacion = entidad.FechaCreacion
            },
            commandType: CommandType.StoredProcedure
        );

        return ParsearResultadoSp(resultado);
    }

    /// <summary>
    /// Actualiza un registro de ejemplo mediante Stored Procedure.
    /// SP: sp_ActualizarEjemplo
    /// Retorna: "1|mensaje" si es exitoso, "0|error" si falla
    /// </summary>
    public async Task<ResultadoOperacion> ActualizarPorSpAsync(EEjemplo entidad)
    {
        using var connection = _connectionFactory.CreateConnection();
        const string spName = "sp_ActualizarEjemplo";

        var resultado = await connection.QueryFirstOrDefaultAsync<string>(
            spName,
            new
            {
                @Id = entidad.Id,
                @Nombre = entidad.Nombre,
                @FechaCreacion = entidad.FechaCreacion
            },
            commandType: CommandType.StoredProcedure
        );

        return ParsearResultadoSp(resultado);
    }

    /// <summary>
    /// Elimina un registro de ejemplo mediante Stored Procedure.
    /// SP: sp_EliminarEjemplo
    /// Retorna: "1|mensaje" si es exitoso, "0|error" si falla
    /// </summary>
    public async Task<ResultadoOperacion> EliminarPorSpAsync(int id)
    {
        using var connection = _connectionFactory.CreateConnection();
        const string spName = "sp_EliminarEjemplo";

        var resultado = await connection.QueryFirstOrDefaultAsync<string>(
            spName,
            new { @Id = id },
            commandType: CommandType.StoredProcedure
        );

        return ParsearResultadoSp(resultado);
    }

    // ==================== MÉTODOS AUXILIARES ====================

    /// <summary>
    /// Parsea la respuesta del Stored Procedure en formato "1|mensaje" o "0|error"
    /// </summary>
    private static ResultadoOperacion ParsearResultadoSp(string? respuesta)
    {
        if (string.IsNullOrEmpty(respuesta))
        {
            return new ResultadoOperacion
            {
                Exitoso = false,
                Mensaje = "Sin respuesta del servidor"
            };
        }

        var partes = respuesta.Split('|');
        var exitoso = partes[0] == "1";
        var mensaje = partes.Length > 1 ? partes[1] : string.Empty;

        return new ResultadoOperacion
        {
            Exitoso = exitoso,
            Mensaje = mensaje
        };
    }
}
