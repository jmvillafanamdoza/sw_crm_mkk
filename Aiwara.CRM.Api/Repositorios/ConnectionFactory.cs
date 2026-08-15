using System.Data;
using Aiwara.CRM.Api.Config;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace Aiwara.CRM.Api.Repositorios;

public class ConnectionFactory : IConnectionFactory
{
    private readonly string _connectionString;

    public ConnectionFactory(IOptions<DatabaseSettings> settings)
    {
        _connectionString = settings.Value.DefaultConnection;
    }

    public IDbConnection CreateConnection() => new SqlConnection(_connectionString);
}
