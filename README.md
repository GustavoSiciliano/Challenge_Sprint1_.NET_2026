# Pró-Tons — Biblioteca de Curiosidades Nucleares (.NET)

Challenge CTMSP 2026 · Advanced Business Development with .NET · Sprint 1

## Grupo

| Nome | RM | Atuação |
| --- | --- | --- |
| Gustavo de Jesus | RM567926 | Programação em C# e .NET |
| Gustavo Siciliano | RM568419 | Programação em C# e .NET |
| Samuel Keniti | RM567614 | Programação em C# e .NET |
| Manuel Pedro | RM567458 | Programação em C# e .NET |
| Vinicius Morrone | RM566884 | Programação em C# e .NET |

## A solução

**Pró-Tons** é uma plataforma educativa (site + app) que mostra que a energia nuclear vai muito além de bombas e acidentes: ela está na saúde, na agricultura, na indústria, na pesquisa e na geração de energia. O usuário escolhe um perfil (criança, jovem ou adulto), lê conteúdos curtos, tira dúvidas com um assistente de IA e testa o que aprendeu em um quiz com ranking.

## O que foi desenvolvido nesta Sprint

Uma aplicação console que cuida da **biblioteca de curiosidades**: o cadastro e a consulta das áreas de aplicação da tecnologia nuclear que alimentam os cards de conteúdo. O quiz e o ranking ficam na API Java, então as duas funcionalidades são complementares e não se repetem.

| Item | Como foi feito |
| --- | --- |
| Entidade | `AreaAplicacao`: código, nome, setor, descrição, curiosidade e data de cadastro |
| Validações | Nome de 3 a 60 caracteres, com ao menos uma letra; descrição de 20 a 500; curiosidade de 10 a 300; setor dentro da lista (Saúde, Agricultura, Indústria, Pesquisa, Energia) |
| Regras de negócio | (1) o nome é único dentro do mesmo setor, ignorando maiúsculas e acentos; (2) a curiosidade não pode ser igual à descrição |
| Cadastro | Opção 1 do menu. Cada campo é validado assim que é digitado e só ele é perguntado de novo se estiver inválido. Digitar `/cancelar` volta ao menu |
| Consulta | Listar todas, buscar por setor, por nome (parcial, sem acento) e por código; resumo com a quantidade de áreas por setor |
| Tratamento de erros | `try/catch` no menu: erros de validação, de regra de negócio e de arquivo viram mensagens e a aplicação continua rodando. Arquivo JSON corrompido ou sem permissão de gravação é detectado com aviso claro |
| Persistência | Arquivo JSON em `src/ProTons.Console/dados/areas.json`, criado automaticamente na primeira execução com 5 áreas iniciais, mantido entre execuções e gravado de forma segura (arquivo temporário + troca). Se a gravação falhar, o cadastro é desfeito e o programa continua |

## Requisitos do enunciado

| Requisito | Onde está |
| --- | --- |
| Repositório com `.gitignore` | `.gitignore` e `.gitattributes` na raiz |
| README completo | Este arquivo |
| Entidade com atributos coerentes com o tema | `Models/AreaAplicacao.cs` |
| Validação dos atributos | DataAnnotations em `AreaAplicacao.cs`; cada campo é conferido na hora da digitação |
| Pelo menos 1 regra de negócio | `Services/AreaService.cs`, método `Cadastrar` (2 regras) |
| Tratamento de erros com `try/catch`, sem quebrar | `Program.cs` (laço do menu) e `Data/AreaRepositorioJson.cs` |
| Cadastro de novos registros | Menu, opção 1 |
| Listagem de todos os registros | Menu, opção 2 |
| Busca por um critério | Menu, opções 3 (setor), 4 (nome) e 5 (código) |
| Persistência em JSON | `src/ProTons.Console/dados/areas.json` (gerado ao executar) |

## Arquitetura

```
ProTons.sln
src/ProTons.Console/
├── Program.cs                      # menu e interação com o usuário
├── Models/
│   ├── AreaAplicacao.cs            # entidade + validações (DataAnnotations)
│   ├── Setor.cs                    # enum dos setores
│   └── SetorExtensions.cs          # nome do setor com acento para exibição
├── Services/
│   ├── AreaService.cs              # regras de negócio, cadastro e consultas
│   └── RegraNegocioException.cs
├── Data/
│   └── AreaRepositorioJson.cs      # leitura e gravação do JSON
└── dados/
    └── areas.json                  # base em JSON (gerada ao executar, fora do Git)
```

A separação em camadas (interface → serviço → repositório) permite trocar o JSON por Entity Framework Core + Oracle nas próximas sprints mexendo só na pasta `Data`. A entidade espelha a tabela `AREA_APLICACAO` do modelo de dados do grupo.

## Como executar

Requisito: [.NET SDK 8.0](https://dotnet.microsoft.com/download).

```bash
git clone <url-do-repositorio>
cd <pasta-do-repositorio>
dotnet run --project src/ProTons.Console
```

Para apenas compilar: `dotnet build`. No Visual Studio, abra `ProTons.sln` e execute (F5).

**Onde ficam os dados:** em `src/ProTons.Console/dados/areas.json`, pasta do projeto, não importa se o programa foi iniciado pelo `dotnet run`, pelo Visual Studio ou direto pelo executável. O arquivo não vem no repositório: ele é criado na primeira execução, já com 5 áreas iniciais, e fica fora do Git (`.gitignore`). O caminho aparece na tela ao iniciar e após cada cadastro. Para usar outro local, defina a variável de ambiente `PROTONS_DATA_FILE`. Para voltar ao estado inicial, apague o arquivo e execute de novo. Não há senhas nem credenciais no projeto.

**Como conferir a persistência:**

1. Execute e cadastre uma área (opção 1).
2. Saia (opção 0) e abra o arquivo `src/ProTons.Console/dados/areas.json`: o novo registro está lá.
3. Execute de novo e liste (opção 2): a área cadastrada continua na lista.

Trecho do arquivo:

```json
{
  "Id": 1,
  "Nome": "Radioterapia",
  "Setor": "Saude",
  "Descricao": "Usa feixes de radiação direcionados para destruir células de tumores, poupando ao máximo o tecido saudável.",
  "Curiosidade": "Milhões de pacientes com câncer no mundo são tratados com radioterapia a cada ano.",
  "DataCadastro": "..."
}
```

## Exemplo de uso

```
Bem-vindo ao Pró-Tons! Aqui o átomo mostra o seu lado bom.

=== Pró-Tons | Biblioteca de Curiosidades Nucleares ===
1 - Cadastrar área de aplicação
2 - Listar todas
3 - Buscar por setor
4 - Buscar por nome
5 - Buscar por código
6 - Resumo por setor
0 - Sair
Opção: 4
Nome (ou parte): radio

[1] Radioterapia  (Saúde)  - cadastrada em 19/10/2026
    Usa feixes de radiação direcionados para destruir células de tumores...
    Curiosidade: Milhões de pacientes com câncer no mundo são tratados com radioterapia a cada ano.

1 registro(s).
```

Exemplo de validação durante o cadastro (só o campo inválido é perguntado de novo):

```
Opção: 1
(digite /cancelar a qualquer momento para voltar ao menu)
Nome (3 a 60 caracteres):
  O nome é obrigatório. Tente novamente.
Nome (3 a 60 caracteres): Laser Médico
Setores: 1=Saúde, 2=Agricultura, 3=Indústria, 4=Pesquisa, 5=Energia
Número do setor:
```

As regras de negócio são verificadas ao salvar:

```
[Regra de negócio] Já existe a área "Radioterapia" no setor Saúde.
[Regra de negócio] A curiosidade não pode ser igual à descrição.
```

## Como o .NET se aplica à solução do grupo

O .NET é a camada de gestão de conteúdo do Pró-Tons: ele cuida do catálogo de áreas de aplicação e curiosidades que o app e o site exibem, aplicando validação e regras de negócio antes de qualquer dado entrar na base. Com C# fortemente tipado, DataAnnotations e uma estrutura em camadas, a mesma biblioteca pode evoluir de um console para um serviço de administração (Web API ou worker) usando Entity Framework Core com o Oracle do grupo, enquanto a API Java concentra o quiz e o ranking.