namespace Aiwara.CRM.Api.DTOs;

/// <summary>
/// DTO interno para mapear la respuesta exacta de PRMKK_CON_BOF_USUARIO.
/// </summary>
public class UsuarioSpResultDto
{
    public int CUSU_ID_USUARIO { get; set; }
    public int? CPEL_ID_PERSONAL { get; set; }
    public int CPER_ID_PERSONA { get; set; }
    public byte? FPER_TIP_DOC_IDENTIDAD { get; set; }
    public string? SNRO_DOCUMENTO { get; set; }
    public string? SNOMBRE_COMPLETO { get; set; }
    public string? SCORREO { get; set; }
    public string? SCELULAR { get; set; }
    public string? SUSU_USERNAME { get; set; }
    public int? CPFL_ID_PERFIL { get; set; }
    public string? SPERFIL { get; set; }
    public int? CCAM_ID_CAMPANIA { get; set; }
    public string? SCAMPANIA { get; set; }
    public int? CSED_ID_SEDE { get; set; }
    public string? SSEDE { get; set; }
    public string? CPEL_PUESTO { get; set; }
    public string? FPEL_MODALIDAD { get; set; }
    public int? CPEL_ID_SUPERVISOR { get; set; }
    public string? SID_BIO { get; set; }
    public string? SID_VENTA { get; set; }
    public string? SID_OVER { get; set; }
    public string? SID_VICI { get; set; }
    public string? SNUM_CUENTA { get; set; }
    public string? SHORA_INICIO { get; set; }
    public string? SHORA_FIN { get; set; }
    public DateTime? DFEC_INGRESO { get; set; }
    public DateTime? DFEC_FIN { get; set; }
    public DateTime? DCONTRATO_INICIO { get; set; }
    public DateTime? DCONTRATO_FIN { get; set; }
    public string? FCONTRATO_VENCIDO { get; set; }
    public string? FUSU_ESTADO { get; set; }
    public DateTime? DUSU_ULTIMO_LOGIN { get; set; }
}

/// <summary>
/// Result set 1 de PRMKK_CON_BOF_USUARIO_RESUMEN.
/// </summary>
public class UsuarioResumenTotalesSpResultDto
{
    public int? NACTIVOS { get; set; }
    public int? NCONTRATOS_VENCIDOS { get; set; }
}

/// <summary>
/// Result set 2 (activos por campaña) de PRMKK_CON_BOF_USUARIO_RESUMEN.
/// </summary>
public class UsuarioResumenCampaniaSpResultDto
{
    public int CCAM_ID_CAMPANIA { get; set; }
    public string? SCAM_NOMBRE { get; set; }
    public int NUSUARIOS { get; set; }
}

/// <summary>
/// Result set 3 (activos por sede) de PRMKK_CON_BOF_USUARIO_RESUMEN.
/// </summary>
public class UsuarioResumenSedeSpResultDto
{
    public int CSED_ID_SEDE { get; set; }
    public string? SSED_NOMBRE { get; set; }
    public int NUSUARIOS { get; set; }
}
