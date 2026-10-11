using Aiwara.CRM.Api.DTOs;
using FluentValidation;

namespace Aiwara.CRM.Api.Validaciones;

/// <summary>
/// Validador para crear o actualizar un Usuario. Los largos máximos siguen las
/// columnas de TPLS_PERSONA, TMKK_USUARIO y TMKK_PERSONAL.
/// </summary>
public class GuardarUsuarioDtoValidator : AbstractValidator<GuardarUsuarioDto>
{
    private const string PatronHora = @"^([01]\d|2[0-3]):[0-5]\d$";

    public GuardarUsuarioDtoValidator()
    {
        RuleFor(x => x.NombreCompleto)
            .NotEmpty().WithMessage("El nombre completo es requerido.")
            .MaximumLength(200).WithMessage("El nombre no puede exceder 200 caracteres.");

        RuleFor(x => x.Usuario)
            .NotEmpty().WithMessage("El usuario es requerido.")
            .MaximumLength(50).WithMessage("El usuario no puede exceder 50 caracteres.")
            .Matches(@"^\S+$").WithMessage("El usuario no puede contener espacios.");

        RuleFor(x => x.PerfilId)
            .GreaterThan(0).WithMessage("El perfil es requerido.");

        RuleFor(x => x.SedeId).Cascade(CascadeMode.Stop)
            .NotNull().WithMessage("La sede es requerida.")
            .GreaterThan(0).WithMessage("La sede es requerida.");

        RuleFor(x => x.NroDocumento)
            .MaximumLength(16).WithMessage("El número de documento no puede exceder 16 caracteres.");

        RuleFor(x => x.NroDocumento)
            .Matches(@"^\d{8}$").WithMessage("El DNI debe tener 8 dígitos.")
            .When(x => x.TipoDocumento == 1 && !string.IsNullOrEmpty(x.NroDocumento));

        RuleFor(x => x.Correo)
            .MaximumLength(100).WithMessage("El correo no puede exceder 100 caracteres.")
            .EmailAddress().WithMessage("El correo no es válido.")
            .When(x => !string.IsNullOrEmpty(x.Correo));

        RuleFor(x => x.Celular)
            .MaximumLength(16).WithMessage("El celular no puede exceder 16 caracteres.");

        RuleFor(x => x.Puesto)
            .MaximumLength(8).WithMessage("El puesto no es válido.");

        RuleFor(x => x.Modalidad)
            .Must(m => string.IsNullOrEmpty(m) || m.Length == 1).WithMessage("La modalidad no es válida.");

        RuleFor(x => x.IdBio).MaximumLength(16).WithMessage("El ID Bio no puede exceder 16 caracteres.");
        RuleFor(x => x.IdVenta).MaximumLength(30).WithMessage("El ID Venta no puede exceder 30 caracteres.");
        RuleFor(x => x.IdOver).MaximumLength(16).WithMessage("El ID Over no puede exceder 16 caracteres.");
        RuleFor(x => x.IdVici).MaximumLength(16).WithMessage("El ID Vici no puede exceder 16 caracteres.");
        RuleFor(x => x.NumCuenta).MaximumLength(30).WithMessage("El número de cuenta no puede exceder 30 caracteres.");

        RuleFor(x => x.HoraInicio).Cascade(CascadeMode.Stop)
            .NotEmpty().WithMessage("La hora de inicio es requerida.")
            .Matches(PatronHora).WithMessage("La hora de inicio debe tener el formato HH:mm.");

        RuleFor(x => x.HoraFin).Cascade(CascadeMode.Stop)
            .NotEmpty().WithMessage("La hora de fin es requerida.")
            .Matches(PatronHora).WithMessage("La hora de fin debe tener el formato HH:mm.");

        RuleFor(x => x.FechaIngreso)
            .NotNull().WithMessage("La fecha de ingreso es requerida.");

        RuleFor(x => x.ContratoFin)
            .GreaterThanOrEqualTo(x => x.ContratoInicio)
            .WithMessage("La fecha fin de contrato no puede ser menor a la de inicio.")
            .When(x => x.ContratoInicio.HasValue && x.ContratoFin.HasValue);

        RuleFor(x => x.Estado)
            .NotEmpty().WithMessage("El estado es requerido.")
            .Must(x => new[] { "V", "I" }.Contains(x.ToUpper()))
            .WithMessage("El estado debe ser 'V' (Activo) o 'I' (Inactivo).");

        RuleFor(x => x.UsuarioAuditoria)
            .NotEmpty().WithMessage("El usuario de auditoría es requerido.")
            .MaximumLength(16).WithMessage("El usuario de auditoría no puede exceder 16 caracteres.");
    }
}
