using Aiwara.CRM.Api.DTOs;
using Aiwara.CRM.Api.Entidades;
using AutoMapper;

namespace Aiwara.CRM.Api.Utilitarios;

public class AutoMapperProfiles : Profile
{
    public AutoMapperProfiles()
    {
        // Mapeos de Ejemplo
        CreateMap<EEjemplo, EjemploDto>();
        CreateMap<CrearEjemploDto, EEjemplo>()
            .ForMember(dest => dest.FechaCreacion, opt => opt.MapFrom(_ => DateTime.UtcNow));

        // Mapeos de Tipo de Valor
        CreateMap<ETipoValor, TipoValorDto>();
        CreateMap<CrearTipoValorDto, ETipoValor>();
    }
}
