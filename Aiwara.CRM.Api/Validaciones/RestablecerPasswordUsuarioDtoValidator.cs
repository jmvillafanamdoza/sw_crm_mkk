using Aiwara.CRM.Api.DTOs;
using FluentValidation;

namespace Aiwara.CRM.Api.Validaciones;

/// <summary>
/// Validador para restablecer la contraseña de un Usuario.
/// </summary>
public class RestablecerPasswordUsuarioDtoValidator : AbstractValidator<RestablecerPasswordUsuarioDto>
{
    public RestablecerPasswordUsuarioDtoValidator()
    {
        RuleFor(x => x.UsuarioAuditoria)
            .NotEmpty().WithMessage("El usuario de auditoría es requerido.")
            .MaximumLength(16).WithMessage("El usuario de auditoría no puede exceder 16 caracteres.");
    }
}
