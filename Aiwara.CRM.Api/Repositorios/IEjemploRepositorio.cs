using Aiwara.CRM.Api.Entidades;

namespace Aiwara.CRM.Api.Repositorios;

public interface IEjemploRepositorio
{
    // Métodos de lectura con Stored Procedures
    Task<IEnumerable<EEjemplo>> ObtenerTodosPorSpAsync();
    Task<EEjemplo?> ObtenerPorIdPorSpAsync(int id);

    // Métodos de escritura con Stored Procedures
    Task<ResultadoOperacion> CrearPorSpAsync(EEjemplo entidad);
    Task<ResultadoOperacion> ActualizarPorSpAsync(EEjemplo entidad);
    Task<ResultadoOperacion> EliminarPorSpAsync(int id);
}
