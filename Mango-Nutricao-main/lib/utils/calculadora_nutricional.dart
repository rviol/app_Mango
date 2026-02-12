
class CalculadoraNutricional {
  // Retorna a classificação baseada no valor e no gênero
  static String classificar(String tipo, double valor, String genero) {
    bool isFeminino = genero == 'Feminino';

    switch (tipo) {
      case 'IMC':
        if (valor < 18.5) return 'Abaixo';
        if (valor >= 25.0) return 'Acima';
        return 'Ideal';

      case 'Gordura':
        if (isFeminino) {
          if (valor < 18) return 'Abaixo';
          if (valor > 28) return 'Acima';
          return 'Ideal';
        } else {
          if (valor < 10) return 'Abaixo';
          if (valor > 20) return 'Acima';
          return 'Ideal';
        }

      case 'RCQ': // Relação Cintura-Quadril
        if (isFeminino) {
          if (valor < 0.70) return 'Abaixo';
          if (valor > 0.85) return 'Acima';
          return 'Ideal';
        } else {
          if (valor < 0.80) return 'Abaixo';
          if (valor > 0.95) return 'Acima';
          return 'Ideal';
        }

      case 'CMB': // Circunferência Muscular do Braço
        if (isFeminino) {
          if (valor < 20) return 'Abaixo';
          if (valor > 29) return 'Acima';
          return 'Ideal';
        } else {
          if (valor < 23) return 'Abaixo';
          if (valor > 34) return 'Acima';
          return 'Ideal';
        }

        case 'MassaGorda': 
         if (valor < 5) return 'Abaixo';
         if (valor > 30) return 'Acima';
         return 'Ideal';

      default:
        return 'Ideal';
    }
  }
}