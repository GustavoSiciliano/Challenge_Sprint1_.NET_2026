using System.ComponentModel.DataAnnotations;

namespace ProTons.Models;

// Representa uma área de aplicação do projeto.
public class AreaAplicacao
{
    public int Id { get; set; }

    [Required(ErrorMessage = "O nome é obrigatório.")]
    [StringLength(60, MinimumLength = 3, ErrorMessage = "O nome deve ter de 3 a 60 caracteres.")]
    [RegularExpression(@"^(?=.*\p{L})[\p{L}\p{N}\s\-'().,]+$", ErrorMessage = "O nome deve conter ao menos uma letra e apenas letras, números e pontuação simples.")]
    public string Nome { get; set; } = string.Empty;

    [EnumDataType(typeof(Setor), ErrorMessage = "Setor inválido.")]
    public Setor Setor { get; set; }

    [Required(ErrorMessage = "A descrição é obrigatória.")]
    [StringLength(500, MinimumLength = 20, ErrorMessage = "A descrição deve ter de 20 a 500 caracteres.")]
    public string Descricao { get; set; } = string.Empty;

    [Required(ErrorMessage = "A curiosidade é obrigatória.")]
    [StringLength(300, MinimumLength = 10, ErrorMessage = "A curiosidade deve ter de 10 a 300 caracteres.")]
    public string Curiosidade { get; set; } = string.Empty;

    public DateTime DataCadastro { get; set; } = DateTime.Now;
}
