using Aiwara.CRM.Api.DTOs;
using FluentValidation;

namespace Aiwara.CRM.Api.Validaciones;

/// <summary>
/// Validador para cambiar el estado de un Tipo de Valor.
/// </summary>
public class CambiarEstadoTipoValorDtoValidator : AbstractValidator<CambiarEstadoTipoValorDto>
{
    public CambiarEstadoTipoValorDtoValidator()
    {
        RuleFor(x => x.CodigoTipoValor)
            .NotEmpty().WithMessage("El código del tipo de valor es requerido.")
            .MaximumLength(20).WithMessage("El código no puede exceder 20 caracteres.");

        RuleFor(x => x.TipoValor)
            .NotEmpty().WithMessage("El tipo de valor es requerido.")
            .MaximumLength(8).WithMessage("El tipo de valor no puede exceder 8 caracteres.");

        RuleFor(x => x.Estado)
            .NotEmpty().WithMessage("El estado es requerido.")
            .Must(x => new[] { "A", "I" }.Contains(x.ToUpper()))
            .WithMessage("El estado debe ser 'A' (Activo) o 'I' (Inactivo).");
    }
}
