using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using ProTons.Data;
using ProTons.Models;

namespace ProTons.Services;

public class AreaService
{
    private readonly AreaRepositorioJson _repositorio;
    private readonly List<AreaAplicacao> _areas;

    // Carrega as áreas cadastradas e insere dados iniciais se necessário.
    public AreaService(AreaRepositorioJson repositorio)
    {
        _repositorio = repositorio;
        _areas = _repositorio.Carregar();

        if (_areas.Count == 0)
            PopularDadosIniciais();
    }

    // Valida e cadastra uma área, salvando os dados no JSON.
    public AreaAplicacao Cadastrar(AreaAplicacao area)
    {
        if (area == null)
            throw new ValidationException("Dados da área não informados.");

        area.Nome = NormalizarEspacos(area.Nome);
        area.Descricao = area.Descricao?.Trim() ?? string.Empty;
        area.Curiosidade = area.Curiosidade?.Trim() ?? string.Empty;

        var erros = new List<ValidationResult>();

        if (!Validator.TryValidateObject(area, new ValidationContext(area), erros, true))
            throw new ValidationException(string.Join(" | ", erros.Select(e => e.ErrorMessage)));

        if (_areas.Any(a => a.Setor == area.Setor && Normalizar(a.Nome) == Normalizar(area.Nome)))
            throw new RegraNegocioException($"Já existe a área \"{area.Nome}\" no setor {area.Setor.Rotulo()}.");

        if (Normalizar(area.Curiosidade) == Normalizar(area.Descricao))
            throw new RegraNegocioException("A curiosidade não pode ser igual à descrição.");

        area.Id = _areas.Count == 0 ? 1 : _areas.Max(a => a.Id) + 1;
        area.DataCadastro = DateTime.Now;

        _areas.Add(area);

        try
        {
            _repositorio.Salvar(_areas);
        }
        catch
        {
            _areas.Remove(area);
            throw;
        }

        return area;
    }

    // Valida um único campo e retorna a mensagem de erro, se houver.
    public static string? ValidarCampo(string propriedade, string valor)
    {
        var contexto = new ValidationContext(new AreaAplicacao()) { MemberName = propriedade };
        var erros = new List<ValidationResult>();

        if (Validator.TryValidateProperty(valor, contexto, erros))
            return null;

        return string.Join(" | ", erros.Select(e => e.ErrorMessage));
    }

    // Remove espaços extras do início, do fim e entre as palavras.
    public static string NormalizarEspacos(string? texto)
    {
        return Regex.Replace(texto?.Trim() ?? string.Empty, @"\s+", " ");
    }

    // Retorna todas as áreas ordenadas por setor e nome.
    public List<AreaAplicacao> ListarTodas()
    {
        return _areas.OrderBy(a => a.Setor).ThenBy(a => a.Nome).ToList();
    }

    // Retorna as áreas pertencentes ao setor informado.
    public List<AreaAplicacao> BuscarPorSetor(Setor setor)
    {
        return _areas.Where(a => a.Setor == setor).OrderBy(a => a.Nome).ToList();
    }

    // Busca áreas pelo nome, ignorando acentos e diferenças entre maiúsculas e minúsculas.
    public List<AreaAplicacao> BuscarPorNome(string termo)
    {
        if (string.IsNullOrWhiteSpace(termo))
            throw new ValidationException("Informe um termo de busca.");

        string termoNormalizado = Normalizar(termo);

        return _areas
            .Where(a => Normalizar(a.Nome).Contains(termoNormalizado))
            .OrderBy(a => a.Nome)
            .ToList();
    }

    // Retorna a área correspondente ao ID informado, se existir.
    public AreaAplicacao? BuscarPorId(int id)
    {
        return _areas.FirstOrDefault(a => a.Id == id);
    }

    // Conta quantas áreas existem em cada setor.
    public Dictionary<Setor, int> ContarPorSetor()
    {
        var resultado = new Dictionary<Setor, int>();

        foreach (Setor setor in Enum.GetValues<Setor>())
        {
            resultado[setor] = _areas.Count(a => a.Setor == setor);
        }

        return resultado;
    }

    // Converte o texto para minúsculas e remove os acentos.
    private static string Normalizar(string texto)
    {
        var decomposto = texto.Trim().ToLowerInvariant().Normalize(NormalizationForm.FormD);
        var resultado = new StringBuilder();

        foreach (var c in decomposto)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
                resultado.Append(c);
        }

        return resultado.ToString();
    }

    // Cadastra e salva as áreas iniciais caso não existam dados.
    private void PopularDadosIniciais()
    {
        var iniciais = new[]
        {
            new AreaAplicacao
            {
                Nome = "Radioterapia",
                Setor = Setor.Saude,
                Descricao = "Usa feixes de radiação direcionados para destruir células de tumores, poupando ao máximo o tecido saudável.",
                Curiosidade = "Milhões de pacientes com câncer no mundo são tratados com radioterapia a cada ano."
            },
            new AreaAplicacao
            {
                Nome = "Medicina Nuclear",
                Setor = Setor.Saude,
                Descricao = "Aplica pequenas quantidades de material radioativo para gerar imagens do funcionamento dos órgãos e diagnosticar doenças.",
                Curiosidade = "Exames como a cintilografia mostram o órgão funcionando, não apenas sua forma."
            },
            new AreaAplicacao
            {
                Nome = "Irradiação de Alimentos",
                Setor = Setor.Agricultura,
                Descricao = "Expõe os alimentos a radiação controlada para eliminar bactérias e insetos e aumentar o tempo de prateleira.",
                Curiosidade = "O alimento irradiado não fica radioativo, assim como a bagagem não fica após o raio-X do aeroporto."
            },
            new AreaAplicacao
            {
                Nome = "Gamagrafia Industrial",
                Setor = Setor.Industria,
                Descricao = "Técnica que usa radiação para inspecionar soldas e tubulações por dentro, sem precisar cortar ou desmontar a peça.",
                Curiosidade = "É como um raio-X de gasodutos e peças de avião para achar falhas invisíveis."
            },
            new AreaAplicacao
            {
                Nome = "Programa Nuclear da Marinha",
                Setor = Setor.Energia,
                Descricao = "Desenvolve a tecnologia de propulsão nuclear para submarinos, que geram a própria energia e ficam muito tempo submersos.",
                Curiosidade = "Um submarino nuclear pode operar por longos períodos sem precisar reabastecer."
            }
        };

        foreach (var area in iniciais)
        {
            area.Id = _areas.Count + 1;
            _areas.Add(area);
        }

        _repositorio.Salvar(_areas);
    }
}
