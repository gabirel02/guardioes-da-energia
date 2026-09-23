shader_type canvas_item;

uniform float velocidade = 3.0;
uniform float frequencia = 15.0;
uniform float amplitude = 0.005;

void fragment() {
    // 1. Calcula onde seria o píxel com o efeito da água
    vec2 uv_distorcido = UV;
    uv_distorcido.x += sin(UV.y * frequencia + TIME * velocidade) * amplitude;

    // 2. Lê a cor original e a cor distorcida
    vec4 cor_original = texture(TEXTURE, UV);
    vec4 cor_agua_mexer = texture(TEXTURE, uv_distorcido);

    // 3. Verifica se a cor é predominantemente azul (Água vs Cimento)
    // Se o canal Azul (b) for bem maior que o Vermelho (r), é água!
    float diferenca_azul = cor_original.b - cor_original.r;

    if (diferenca_azul > 0.1) {
        // Se for água, mostra a imagem com movimento
        COLOR = cor_agua_mexer; 
    } else {
        // Se for cimento, mostra a imagem original parada
        COLOR = cor_original; 
    }
}