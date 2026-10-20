using System.ComponentModel.DataAnnotations;
using ProTons.Data;
using ProTons.Models;
using ProTons.Services;

Console.OutputEncoding = System.Text.Encoding.UTF8;

// Local do JSON
var caminho = Environment.GetEnvironmentVariable("PROTONS_DATA_FILE") ?? AreaRepositorioJson.CaminhoPadrao();

AreaService servico;
try
{
    servico = new AreaService(new AreaRepositorioJson(caminho));
}
catch (Exception ex)
{
    Console.WriteLine($"Não foi possível abrir a base de dados: {ex.Message}");
    return;
}

Console.WriteLine("Bem-vindo ao Pró-Tons! Aqui o átomo mostra o seu lado bom.");
Console.WriteLine($"Dados em: {caminho}");

while (true)
{
    Console.WriteLine();
    Console.WriteLine("=== Pró-Tons | Biblioteca de Curiosidades Nucleares ===");
    Console.WriteLine("1 - Cadastrar área de aplicação");
    Console.WriteLine("2 - Listar todas");
    Console.WriteLine("3 - Buscar por setor");
    Console.WriteLine("4 - Buscar por nome");
    Console.WriteLine("5 - Buscar por código");
    Console.WriteLine("6 - Resumo por setor");
    Console.WriteLine("0 - Sair");
    Console.Write("Opção: ");

    var opcao = Console.ReadLine()?.Trim();
    if (opcao == null || opcao == "0") break;

    // Qualquer erro vira mensagem e o menu continua
    try
    {
        switch (opcao)
        {
            case "1": Cadastrar(); break;
            case "2": Exibir(servico.ListarTodas()); break;
            case "3": BuscarPorSetor(); break;
            case "4":
                Console.Write("Nome (ou parte): ");
                Exibir(servico.BuscarPorNome(Console.ReadLine() ?? ""));
                break;
            case "5": BuscarPorCodigo(); break;
            case "6": ExibirResumo(); break;
            default: Console.WriteLine("Opção inválida. Digite um número de 0 a 6."); break;
        }
    }
    catch (OperationCanceledException)
    {
        Console.WriteLine("Operação cancelada. Voltando ao menu.");
    }
    catch (ValidationException ex)
    {
        Console.WriteLine($"[Validação] {ex.Message}");
    }
    catch (RegraNegocioException ex)
    {
        Console.WriteLine($"[Regra de negócio] {ex.Message}");
    }
    catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException)
    {
        Console.WriteLine($"[Arquivo] Falha ao gravar/ler os dados: {ex.Message}");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[Erro inesperado] {ex.Message}");
    }
}

Console.WriteLine("Até logo!");

const string Cancelar = "/cancelar";

// Lê a entrada e cancela a operação se o usuário digitar /cancelar ou encerrar a entrada.
string LerLinha()
{
    var entrada = Console.ReadLine();

    if (entrada == null)
        throw new OperationCanceledException();

    entrada = entrada.Trim();

    if (entrada.Equals(Cancelar, StringComparison.OrdinalIgnoreCase))
        throw new OperationCanceledException();

    return entrada;
}

// Solicita um setor válido e retorna sua enumeração.
Setor LerSetor()
{
    Console.WriteLine("Setores: " + string.Join(", ", Enum.GetValues<Setor>().Select(s => $"{(int)s}={s.Rotulo()}")));

    while (true)
    {
        Console.Write("Número do setor: ");
        var entrada = LerLinha();

        if (int.TryParse(entrada, out var numero) && Enum.IsDefined(typeof(Setor), numero))
            return (Setor)numero;

        Console.WriteLine("  Setor inválido. Escolha um número da lista. Tente novamente.");
    }
}

// Solicita um campo até que ele passe pelas validações da entidade.
string LerCampo(string pergunta, string propriedade)
{
    while (true)
    {
        Console.Write(pergunta);
        var entrada = LerLinha();

        var valor = propriedade == nameof(AreaAplicacao.Nome) ? AreaService.NormalizarEspacos(entrada) : entrada;
        var erro = AreaService.ValidarCampo(propriedade, valor);

        if (erro == null)
            return valor;

        Console.WriteLine($"  {erro} Tente novamente.");
    }
}

// Solicita os dados de uma área, cadastra e exibe a confirmação.
void Cadastrar()
{
    Console.WriteLine($"(digite {Cancelar} a qualquer momento para voltar ao menu)");

    var area = new AreaAplicacao();

    area.Nome = LerCampo("Nome (3 a 60 caracteres): ", nameof(AreaAplicacao.Nome));
    area.Setor = LerSetor();
    area.Descricao = LerCampo("Descrição (20 a 500 caracteres): ", nameof(AreaAplicacao.Descricao));
    area.Curiosidade = LerCampo("Curiosidade (10 a 300 caracteres): ", nameof(AreaAplicacao.Curiosidade));

    var salva = servico.Cadastrar(area);
    Console.WriteLine($"Área \"{salva.Nome}\" cadastrada com o código {salva.Id}.");
    Console.WriteLine($"Salva em: {caminho}");
}

// Busca e exibe as áreas do setor escolhido.
void BuscarPorSetor()
{
    Exibir(servico.BuscarPorSetor(LerSetor()));
}

// Busca e exibe uma área pelo código informado.
void BuscarPorCodigo()
{
    Console.Write("Código: ");

    if (!int.TryParse(Console.ReadLine()?.Trim(), out var id) || id <= 0)
        throw new ValidationException("Código inválido. Informe um número inteiro positivo.");

    var area = servico.BuscarPorId(id);
    Exibir(area == null ? Array.Empty<AreaAplicacao>() : new[] { area });
}

// Exibe a quantidade de áreas cadastradas em cada setor.
void ExibirResumo()
{
    Console.WriteLine();

    foreach (var (setor, total) in servico.ContarPorSetor())
        Console.WriteLine($"{setor.Rotulo(),-12} {total} área(s)");
}

// Exibe os dados das áreas encontradas ou informa quando não há resultados.
void Exibir(IReadOnlyList<AreaAplicacao> areas)
{
    if (areas.Count == 0)
    {
        Console.WriteLine("Nenhum registro encontrado.");
        return;
    }

    foreach (var a in areas)
    {
        Console.WriteLine();
        Console.WriteLine($"[{a.Id}] {a.Nome}  ({a.Setor.Rotulo()})  - cadastrada em {a.DataCadastro:dd/MM/yyyy}");
        Console.WriteLine($"    {a.Descricao}");
        Console.WriteLine($"    Curiosidade: {a.Curiosidade}");
    }

    Console.WriteLine($"\n{areas.Count} registro(s).");
}