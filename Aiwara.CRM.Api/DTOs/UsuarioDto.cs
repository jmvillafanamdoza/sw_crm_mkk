namespace Aiwara.CRM.Api.DTOs;

/// <summary>
/// DTO de Usuario para consultas (Mantenimiento > Usuarios).
/// </summary>
public class UsuarioDto
{
    public int Id { get; set; }
    public int? PersonalId { get; set; }
    public byte TipoDocumento { get; set; }
    public string? NroDocumento { get; set; }
    public string NombreCompleto { get; set; } = string.Empty;
    public string? Correo { get; set; }
    public string? Celular { get; set; }
    public string Usuario { get; set; } = string.Empty;
    public int PerfilId { get; set; }
    public string? Perfil { get; set; }
    public int? CampaniaId { get; set; }
    public string? Campania { get; set; }
    public int? SedeId { get; set; }
    public string? Sede { get; set; }
    public string? Puesto { get; set; }
    public string? Modalidad { get; set; }
    public int? SupervisorId { get; set; }
    public string? IdBio { get; set; }
    public string? IdVenta { get; set; }
    public string? IdOver { get; set; }
    public string? IdVici { get; set; }
    public string? NumCuenta { get; set; }
    public string? HoraInicio { get; set; }
    public string? HoraFin { get; set; }
    public DateOnly? FechaIngreso { get; set; }
    public DateOnly? FechaFin { get; set; }
    public DateOnly? ContratoInicio { get; set; }
    public DateOnly? ContratoFin { get; set; }
    public bool ContratoVencido { get; set; }
    /// <summary>V = activo, I = inactivo</summary>
    public string Estado { get; set; } = "V";
    public DateTime? UltimoLogin { get; set; }
}

/// <summary>
/// DTO para crear o actualizar un Usuario (drawer "Nuevo / Editar Usuario").
/// La contraseña no viaja aquí: la API genera una temporal al crear.
/// </summary>
public class GuardarUsuarioDto
{
    public string NombreCompleto { get; set; } = string.Empty;
    public byte TipoDocumento { get; set; } = 1;
    public string? NroDocumento { get; set; }
    public string? Correo { get; set; }
    public string? Celular { get; set; }
    public string Usuario { get; set; } = string.Empty;
    public int PerfilId { get; set; }
    public int? CampaniaId { get; set; }
    public int? SedeId { get; set; }
    public string? Puesto { get; set; }
    public string? Modalidad { get; set; }
    public int? SupervisorId { get; set; }
    public string? IdBio { get; set; }
    public string? IdVenta { get; set; }
    public string? IdOver { get; set; }
    public string? IdVici { get; set; }
    public string? NumCuenta { get; set; }
    /// <summary>Formato HH:mm</summary>
    public string? HoraInicio { get; set; }
    /// <summary>Formato HH:mm</summary>
    public string? HoraFin { get; set; }
    public DateOnly? FechaIngreso { get; set; }
    public DateOnly? ContratoInicio { get; set; }
    public DateOnly? ContratoFin { get; set; }
    /// <summary>V = activo, I = inactivo</summary>
    public string Estado { get; set; } = "V";
    public string UsuarioAuditoria { get; set; } = "ADMIN";
}

/// <summary>
/// DTO para activar / inactivar un Usuario.
/// </summary>
public class CambiarEstadoUsuarioDto
{
    /// <summary>V = activo, I = inactivo</summary>
    public string Estado { get; set; } = "V";
    public string UsuarioAuditoria { get; set; } = "ADMIN";
}

/// <summary>
/// DTO para restablecer la contraseña de un Usuario.
/// </summary>
public class RestablecerPasswordUsuarioDto
{
    public string UsuarioAuditoria { get; set; } = "ADMIN";
}

/// <summary>
/// Respuesta al crear un usuario o restablecer su contraseña. La contraseña
/// temporal se muestra una sola vez; el usuario debe cambiarla en su primer login.
/// </summary>
public class UsuarioPasswordTemporalDto
{
    public UsuarioDto? Usuario { get; set; }
    public string PasswordTemporal { get; set; } = string.Empty;
}

/// <summary>
/// DTO para filtrar Usuarios.
/// </summary>
public class FiltroUsuarioDto
{
    public int? PerfilId { get; set; }
    /// <summary>-1 = sin campaña</summary>
    public int? CampaniaId { get; set; }
    /// <summary>-1 = sin sede</summary>
    public int? SedeId { get; set; }
    public bool? SoloVencidos { get; set; }
    public string? Estado { get; set; }
    public string? Texto { get; set; }
}

/// <summary>
/// Tarjetas de Mantenimiento > Usuarios.
/// </summary>
public class UsuarioResumenDto
{
    public int Activos { get; set; }
    public int ContratosVencidos { get; set; }
    public IEnumerable<UsuarioResumenGrupoDto> PorCampania { get; set; } = [];
    public IEnumerable<UsuarioResumenGrupoDto> PorSede { get; set; } = [];
}

public class UsuarioResumenGrupoDto
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public int Usuarios { get; set; }
}
