using System.Data;

namespace Aiwara.CRM.Api.Repositorios;

/// <summary>
/// Fábrica de conexiones a base de datos, usada por los repositorios con Dapper.
/// </summary>
public interface IConnectionFactory
{
    IDbConnection CreateConnection();
}
