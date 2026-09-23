extends Node2D

# --- VARIÁVEIS GERAIS DO JOGO ---
var freio_ativado: bool = false
var energia_gerada: float = 0.0
var dano_turbina: float = 0.0
var dano_acumulado: float = 0.0 # Todo o estrago sofrido na fase (usado na pontuação)

@onready var particulas_vento = $ParticulasVento
@onready var barra_energia = $HUD/BarraEnergia
@onready var barra_dano = $HUD/BarraDano
@onready var btn_freio = $CamadaBotoes/BarraInferior/GrupoBotoes/BotaoFreio
@onready var texto_vento = $CamadaBotoes/BarraInferior/GrupoBotoes/PainelVento/TextoVento

# As 3 turbinas (a do meio é a principal; as dos lados ficam mais ao fundo)
@onready var turbinas = [$TurbinaEsq, $Turbina, $TurbinaDir]
var helices: Array = []
var bases: Array = []
var posicoes_originais_helices: Array = []
# Cada turbina gira num ritmo um pouco diferente, para parecer mais natural
var velocidades_helices = [0.9, 1.0, 1.1]

# O freio pode ser segurado pelo botão ou pela barra de espaço
var freio_pelo_botao: bool = false
var tempo_animacao: float = 0.0

# ==========================================
# VARIÁVEIS DO ALGORITMO GENÉTICO (IA)
# ==========================================
var forca_vento: float = 30.0
var limite_seguro_vento: float = 75.0

var populacao: Array = []
var notas_fitness: Array = []
var tamanho_populacao: int = 4
var tamanho_cromossomo: int = 4 # 4 ventos diferentes por indivíduo
var tempo_por_gene: float = 3.0 # Cada vento dura 3 segundos
var cronometro_gene: float = 0.0

var individuo_atual: int = 0
var gene_atual: int = 0
var geracao_atual: int = 1

# Métricas para a Função de Avaliação (Fitness)
var desempenho_energia: float = 0.0
var desempenho_dano: float = 0.0
var tempo_uso_freio_correto: float = 0.0

var passos_tutorial = [
	"O vento faz a hélice girar. A hélice girando gera energia.",
	"Quando aparecer VENTO FORTE, segure o botão vermelho FREIO ou a barra de ESPAÇO do teclado.",
	"Quando o vento ficar fraco, solte o freio para gerar energia.",
	"Encha a barra verde. Se a barra vermelha encher, a turbina quebra. Menos estrago = mais pontos!"
]

func _ready():
	# O jogo só começa depois do tutorial
	set_process(false)

	barra_energia.value = 0
	barra_dano.value = 0
	for turbina in turbinas:
		var helice = turbina.get_node("HeliceSprite")
		helices.append(helice)
		bases.append(turbina.get_node("BaseSprite"))
		posicoes_originais_helices.append(helice.position)

	btn_freio.button_down.connect(func(): freio_pelo_botao = true)
	btn_freio.button_up.connect(func(): freio_pelo_botao = false)

	var tutorial_apareceu = await GameManager.exibir_tutorial("eolica", "Usina de Vento", passos_tutorial)
	if tutorial_apareceu:
		GameManager.tiko_diz.emit("A IA vai mandar ventos diferentes. Fique de olho!")
	else:
		GameManager.tiko_diz.emit("Vamos tentar de novo! No vento forte, segure o FREIO ou o ESPAÇO.")
	await GameManager.tiko_terminou_falar

	# INICIALIZA A PRIMEIRA GERAÇÃO DO AG
	inicializar_populacao()
	aplicar_gene_atual()
	set_process(true)

func _process(delta: float):
	freio_ativado = freio_pelo_botao or Input.is_physical_key_pressed(KEY_SPACE)
	processar_algoritmo_genetico(delta)
	processar_fisica_do_jogo(delta)

func inicializar_populacao():
	populacao.clear()
	notas_fitness.clear()
	for i in range(tamanho_populacao):
		var cromossomo = []
		for j in range(tamanho_cromossomo):
			cromossomo.append(randf_range(30.0, 100.0)) # Vento aleatório
		populacao.append(cromossomo)
		notas_fitness.append(0.0)

func processar_algoritmo_genetico(delta: float):
	cronometro_gene += delta
	
	# Avalia se o jogador usou o freio na hora certa para dar nota à IA
	if forca_vento > limite_seguro_vento and freio_ativado:
		tempo_uso_freio_correto += delta

	# Troca de Gene (Vento muda a cada 3 segundos)
	if cronometro_gene >= tempo_por_gene:
		cronometro_gene = 0.0
		gene_atual += 1
		
		# Fim do Indivíduo (Testou os 4 ventos)
		if gene_atual >= tamanho_cromossomo:
			avaliar_fitness_individuo()
			gene_atual = 0
			individuo_atual += 1
			
			# Fim da Geração (Testou toda a população)
			if individuo_atual >= tamanho_populacao:
				evoluir_populacao()
				individuo_atual = 0
				geracao_atual += 1
				GameManager.tiko_diz.emit("A IA aprendeu e criou ventos novos!")
		
		aplicar_gene_atual()

func aplicar_gene_atual():
	forca_vento = populacao[individuo_atual][gene_atual]
	atualizar_particulas_vento()
	
	if forca_vento > limite_seguro_vento:
		texto_vento.text = "VENTO FORTE!"
		texto_vento.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1))
		GameManager.tiko_diz.emit("VENTO FORTE! Segure o FREIO ou o ESPAÇO!")
	else:
		texto_vento.text = "VENTO FRACO"
		texto_vento.add_theme_color_override("font_color", Color(0.1, 0.55, 0.1))
		GameManager.tiko_diz.emit("Vento fraco. Solte o freio para gerar energia.")

func avaliar_fitness_individuo():
	var fitness = desempenho_energia + (tempo_uso_freio_correto * 15.0) - (desempenho_dano * 5.0)
	notas_fitness[individuo_atual] = max(0.1, fitness) 
	
	# Reseta as métricas para avaliar o próximo indivíduo
	desempenho_energia = 0.0
	desempenho_dano = 0.0
	tempo_uso_freio_correto = 0.0

func evoluir_populacao():
	# 1. SELEÇÃO (Encontra os 2 melhores indivíduos da geração)
	var melhor_idx = 0
	var segundo_melhor_idx = 0
	for i in range(tamanho_populacao):
		if notas_fitness[i] > notas_fitness[melhor_idx]:
			segundo_melhor_idx = melhor_idx
			melhor_idx = i
		elif notas_fitness[i] > notas_fitness[segundo_melhor_idx] and i != melhor_idx:
			segundo_melhor_idx = i
			
	var pai1 = populacao[melhor_idx]
	var pai2 = populacao[segundo_melhor_idx]
	var nova_populacao = []
	
	# 2. CRUZAMENTO (Crossover) E MUTAÇÃO
	for i in range(tamanho_populacao):
		var novo_cromossomo = []
		for j in range(tamanho_cromossomo):
			# 50% de chance de herdar o gene do Pai 1 ou Pai 2
			var gene_herdado = pai1[j] if randf() > 0.5 else pai2[j]
			
			# MUTAÇÃO: 15% de chance do vento mudar drasticamente
			if randf() <= 0.15:
				gene_herdado = randf_range(30.0, 110.0)
				
			novo_cromossomo.append(gene_herdado)
		nova_populacao.append(novo_cromossomo)
		
	populacao = nova_populacao
	# Zera as notas para a nova geração
	for i in range(tamanho_populacao): notas_fitness[i] = 0.0

func processar_fisica_do_jogo(delta: float):
	var vento_forte = forca_vento > limite_seguro_vento

	if not freio_ativado:
		girar_helices(delta)

		if not vento_forte:
			energia_gerada += (forca_vento * 0.1) * delta
			desempenho_energia += (forca_vento * 0.1) * delta # Pro AG
			barra_energia.value = energia_gerada
			pintar_turbinas(false)
		else:
			dano_turbina += 35.0 * delta
			desempenho_dano += 35.0 * delta # Pro AG
			dano_acumulado += 35.0 * delta # Pra pontuação
			barra_dano.value = dano_turbina
			pintar_turbinas(true)
	else:
		pintar_turbinas(false)

		dano_turbina = max(0, dano_turbina - (15.0 * delta))
		barra_dano.value = dano_turbina

	atualizar_botao_freio(delta, vento_forte)

	if energia_gerada >= 100.0: vencer_fase()
	elif dano_turbina >= 100.0: perder_fase()

func girar_helices(delta: float):
	for i in range(helices.size()):
		helices[i].rotation_degrees += (forca_vento * 4.0 * velocidades_helices[i]) * delta

# Vermelho e tremendo quando está estragando; normal no resto do tempo
func pintar_turbinas(estragando: bool):
	var cor = Color(1, 0.3, 0.3) if estragando else Color(1, 1, 1)
	for i in range(helices.size()):
		helices[i].modulate = cor
		bases[i].modulate = cor
		if estragando:
			helices[i].position = posicoes_originais_helices[i] + Vector2(randf_range(-3, 3), randf_range(-3, 3))
		else:
			helices[i].position = posicoes_originais_helices[i]

func atualizar_botao_freio(delta: float, vento_forte: bool):
	tempo_animacao += delta
	if freio_ativado:
		btn_freio.text = "FREANDO!"
		btn_freio.modulate = Color(0.8, 0.8, 0.8)
		btn_freio.scale = Vector2(0.96, 0.96) # Parece "afundado" também quando usa o espaço
	elif vento_forte:
		# Pisca e pulsa para chamar atenção: é hora de frear!
		var brilho = (sin(tempo_animacao * 10.0) + 1.0) / 2.0
		btn_freio.text = "FREIO"
		btn_freio.modulate = Color(1, 1, 1).lerp(Color(1, 1, 0.3), brilho)
		btn_freio.scale = Vector2.ONE * (1.0 + 0.05 * brilho)
	else:
		btn_freio.text = "FREIO"
		btn_freio.modulate = Color(1, 1, 1)
		btn_freio.scale = Vector2.ONE

func atualizar_particulas_vento():
	particulas_vento.initial_velocity_min = forca_vento * 8.0
	particulas_vento.initial_velocity_max = forca_vento * 18.0
	particulas_vento.amount = max(5, int(forca_vento / 5))

func vencer_fase():
	set_process(false) 
	# PONTUAÇÃO: começa em 100 e perde 1 ponto a cada 4 de estrago sofrido na fase inteira
	# (1 segundo de vento forte sem freio custa cerca de 9 pontos)
	var pontuacao = 100.0 - (dano_acumulado / 4.0)
	GameManager.registrar_pontuacao("eolica", pontuacao)
	
	if GameManager.modo_continuo:
		GameManager.tiko_diz.emit("Muito bem! Agora vamos para a usina de água!")
		await GameManager.tiko_terminou_falar
		GameManager.pedir_nova_fase.emit("res://cenas/fase_hidreletrica.tscn")
	else:
		GameManager.tiko_diz.emit("Muito bem! Você terminou a usina de vento!")
		await GameManager.tiko_terminou_falar
		GameManager.mostrar_vitoria.emit()

func perder_fase():
	set_process(false) 
	GameManager.tiko_diz.emit("Ops! A turbina quebrou. Vamos tentar de novo!")
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()
