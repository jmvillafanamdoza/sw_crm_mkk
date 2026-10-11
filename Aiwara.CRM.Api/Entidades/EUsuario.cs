namespace Aiwara.CRM.Api.Entidades;

/// <summary>
/// Entidad de Usuario (Mantenimiento > Usuarios).
/// Un usuario del front = TPLS_PERSONA + TMKK_USUARIO + TMKK_USUARIO_PERFIL + TMKK_PERSONAL;
/// los SPs PRMKK_*_BOF_USUARIO mantienen las cuatro tablas sincronizadas.
/// </summary>
public class EUsuario
{
    /// <summary>CUSU_ID_USUARIO</summary>
    public int Id { get; set; }

    /// <summary>CPEL_ID_PERSONAL</summary>
    public int? PersonalId { get; set; }

    /// <summary>TMKK_TIP_DOC_IDENTIDAD (1 = DNI)</summary>
    public byte TipoDocumento { get; set; } = 1;
    public string? NroDocumento { get; set; }

    public string NombreCompleto { get; set; } = string.Empty;
    public string? Correo { get; set; }
    public string? Celular { get; set; }

    /// <summary>SUSU_USERNAME</summary>
    public string Usuario { get; set; } = string.Empty;

    public int PerfilId { get; set; }
    public string? Perfil { get; set; }

    public int? CampaniaId { get; set; }
    public string? Campania { get; set; }

    /// <summary>TMKK_SEDE: LOS OLIVOS, SAN JUAN DE LURIGANCHO, SURCO</summary>
    public int? SedeId { get; set; }
    public string? Sede { get; set; }

    /// <summary>TIP_VALOR 'PUESTO_TRABAJO'</summary>
    public string? Puesto { get; set; }

    /// <summary>TIP_VALOR 'MODALIDAD_TRABAJO' (P = presencial, R = remoto)</summary>
    public string? Modalidad { get; set; }

    /// <summary>CPEL_ID_PERSONAL del supervisor</summary>
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

    /// <summary>Fecha de cese; se registra desde HeadCount > Registro-Bajas</summary>
    public DateOnly? FechaFin { get; set; }

    public DateOnly? ContratoInicio { get; set; }
    public DateOnly? ContratoFin { get; set; }
    public bool ContratoVencido { get; set; }

    /// <summary>V = activo, I = inactivo</summary>
    public string Estado { get; set; } = "V";

    public DateTime? UltimoLogin { get; set; }

    public string? UsuarioAuditoria { get; set; }
}
