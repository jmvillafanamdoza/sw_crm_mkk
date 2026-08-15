using Aiwara.CRM.Api.DTOs;
using FluentValidation;

namespace Aiwara.CRM.Api.Validaciones;

/// <summary>
/// Validador para crear un nuevo Tipo de Valor.
/// </summary>
public class CrearTipoValorDtoValidator : AbstractValidator<CrearTipoValorDto>
{
    public CrearTipoValorDtoValidator()
    {
        RuleFor(x => x.CodigoTipoValor)
            .NotEmpty().WithMessage("El código del tipo de valor es requerido.")
            .MaximumLength(20).WithMessage("El código no puede exceder 20 caracteres.");

        RuleFor(x => x.TipoValor)
            .NotEmpty().WithMessage("El tipo de valor es requerido.")
            .MaximumLength(8).WithMessage("El tipo de valor no puede exceder 8 caracteres.");

        RuleFor(x => x.DescripcionPrincipal)
            .NotEmpty().WithMessage("La descripción principal es requerida.")
            .MaximumLength(128).WithMessage("La descripción no puede exceder 128 caracteres.");

        RuleFor(x => x.Descripcion2)
            .MaximumLength(128).WithMessage("La descripción 2 no puede exceder 128 caracteres.")
            .When(x => !string.IsNullOrEmpty(x.Descripcion2));

        RuleFor(x => x.Descripcion3)
            .MaximumLength(128).WithMessage("La descripción 3 no puede exceder 128 caracteres.")
            .When(x => !string.IsNullOrEmpty(x.Descripcion3));

        RuleFor(x => x.UsuarioInsercion)
            .NotEmpty().WithMessage("El usuario de inserción es requerido.")
            .MaximumLength(16).WithMessage("El usuario no puede exceder 16 caracteres.");
    }
}

