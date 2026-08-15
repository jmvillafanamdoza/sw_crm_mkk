namespace Aiwara.CRM.Api.DTOs;

/// <summary>
/// DTO interno para mapear la respuesta exacta del Stored Procedure.
/// </summary>
public class TipoValorSpResultDto
{
    // Columnas de la tabla TMKK_TIP_VALOR
    public string? CTPV_COD_TIP_VALOR { get; set; }
    public string? CTPV_TIP_VALOR { get; set; }
    public string? STPV_DES_TIP_VALOR_1 { get; set; }
    public string? STPV_DES_TIP_VALOR_2 { get; set; }
    public string? STPV_DES_TIP_VALOR_3 { get; set; }
    public string? FTPV_ESTADO { get; set; }
    public string? AUD_INS_USER { get; set; }
    public string? AUD_UPD_USER { get; set; }
    public DateTime? AUD_INS_DATE { get; set; }
    public DateTime? AUD_UPD_DATE { get; set; }

    // Alternativas en caso de naming diferente
    public int? id { get; set; }
    public string? descripcion { get; set; }
}
