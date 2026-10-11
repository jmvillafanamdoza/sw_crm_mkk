using Aiwara.CRM.Api.DTOs;
using FluentValidation;

namespace Aiwara.CRM.Api.Validaciones;

/// <summary>
/// Validador para activar / inactivar un Usuario.
/// </summary>
public class CambiarEstadoUsuarioDtoValidator : AbstractValidator<CambiarEstadoUsuarioDto>
{
    public CambiarEstadoUsuarioDtoValidator()
    {
        RuleFor(x => x.Estado)
            .NotEmpty().WithMessage("El estado es requerido.")
            .Must(x => new[] { "V", "I" }.Contains(x.ToUpper()))
            .WithMessage("El estado debe ser 'V' (Activo) o 'I' (Inactivo).");

        RuleFor(x => x.UsuarioAuditoria)
            .NotEmpty().WithMessage("El usuario de auditoría es requerido.")
            .MaximumLength(16).WithMessage("El usuario de auditoría no puede exceder 16 caracteres.");
    }
}
