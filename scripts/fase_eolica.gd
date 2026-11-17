extends Node2D

# --- VARIÁVEIS GERAIS DO JOGO ---
var freio_ativado: bool = false
var energia_gerada: float = 0.0
var dano_turbina: float = 0.0

# A fase dura um tempo fixo, para dar tempo de passarem várias gerações do AG
const DURACAO_FASE = 90.0
var tempo_restante: float = DURACAO_FASE

@onready var particulas_vento = $ParticulasVento
@onready var particulas_vento_forte = $ParticulasVentoForte
@onready var painel_ia = $HUD/PainelIA
@onready var texto_ia = $HUD/PainelIA/TextoIA
@onready var texto_tempo = $HUD/TextoTempo
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
var geracao_nova: bool = false # true logo depois que a IA cria uma nova geração de rajadas

# ==========================================
# ALGORITMO GENÉTICO (o "robô aprendiz")
# Cada indivíduo é uma RAJADA de vento forte, descrita por 4 genes.
# Os indivíduos NÃO são salvos: toda partida começa com uma população nova,
# e as gerações passam durante a própria partida.
# ==========================================
const LIMITES_GENES = {
	"forca": [80.0, 110.0],  # Força do vento forte (acima de 75 já é forte)
	"aviso": [0.8, 2.5],     # Segundos de aviso ("VEM VENTO FORTE!") antes da rajada
	"duracao": [1.5, 3.0],   # Segundos de vento forte
	"intervalo": [2.0, 3.5], # Segundos de vento fraco depois da rajada
}
const TAMANHO_POPULACAO = 4
const CHANCE_MUTACAO = 0.2   # Chance de cada gene sofrer mutação
const TAMANHO_MUTACAO = 0.25 # A mutação muda o gene em até 25% da faixa dele

# FITNESS "desafio na medida": a melhor rajada é a que o jogador acerta quase tudo, mas não tudo
const ALVO_DESEMPENHO = 0.8
const DANO_REFERENCIA = 40.0 # Dano de ~1 s de vento forte sem freio = erro máximo na rajada

const FORCA_VENTO_FRACO = 50.0
const LIMITE_SEGURO_VENTO = 75.0
const DURACAO_INICIO = 3.0 # Vento fraco no começo, antes da primeira rajada

var populacao: Array = []    # Cada indivíduo: {"forca", "aviso", "duracao", "intervalo"}
var notas_fitness: Array = []
var desempenhos: Array = []  # Desempenho do jogador (0 a 1) em cada indivíduo da geração
var individuo_atual: int = 0
var geracao_atual: int = 1
var forca_vento: float = FORCA_VENTO_FRACO

# Cada indivíduo é testado em 3 etapas: aviso -> rajada -> calmaria
var etapa: String = "inicio"
var cronometro_etapa: float = 0.0

# Medidas do jogador durante o indivíduo atual (usadas no fitness)
var dano_na_rajada: float = 0.0
var tempo_freando_na_calmaria: float = 0.0
var desempenhos_partida: Array = [] # Todos os desempenhos da partida (usados na pontuação)

var passos_tutorial = [
	"Você sabia? O vento faz as hélices girarem! Assim, a usina produz energia elétrica!",
	"O robô aprendiz vai mandar ventos fortes! Antes de cada vento forte, um aviso vai aparecer na tela!",
	"Quando aparecer o aviso, prepare-se! Segure o botão vermelho FREIO ou a tecla ESPAÇO!",
	"Quando o vento ficar fraco, solte o FREIO! Assim, a turbina volta a produzir energia!",
	"Você precisa cuidar da turbina por um minuto e meio! Não deixe a barra vermelha encher, senão a turbina quebra!"
]

func _ready():
	# O jogo só começa depois do tutorial
	set_process(false)

	barra_energia.value = 0
	barra_dano.value = 0
	texto_tempo.text = "TEMPO: faltam " + str(int(DURACAO_FASE)) + " s"
	for turbina in turbinas:
		var helice = turbina.get_node("HeliceSprite")
		helices.append(helice)
		bases.append(turbina.get_node("BaseSprite"))
		posicoes_originais_helices.append(helice.position)

	btn_freio.button_down.connect(func(): freio_pelo_botao = true)
	btn_freio.button_up.connect(func(): freio_pelo_botao = false)

	inicializar_populacao()
	mostrar_geracao_ia(false)

	var tutorial_apareceu = await GameManager.exibir_tutorial("eolica", "Usina do Vento", passos_tutorial)
	if tutorial_apareceu:
		GameManager.tiko_diz.emit("Chegamos à usina do vento! Aqui, o vento ajuda a produzir energia! Mas cuidado com o vento forte!")
	else:
		GameManager.tiko_diz.emit("Vamos tentar outra vez! Quando o vento ficar forte, segure o botão FREIO ou a tecla ESPAÇO!")
	await GameManager.tiko_terminou_falar

	mudar_etapa("inicio")
	set_process(true)

func _process(delta: float):
	freio_ativado = freio_pelo_botao or Input.is_physical_key_pressed(KEY_SPACE)

	tempo_restante -= delta
	texto_tempo.text = "TEMPO: faltam " + str(ceili(max(tempo_restante, 0.0))) + " s"
	if tempo_restante <= 0.0:
		vencer_fase()
		return

	processar_algoritmo_genetico(delta)
	processar_fisica_do_jogo(delta)

# ==========================================
# POPULAÇÃO INICIAL: 4 rajadas com genes sorteados dentro dos limites
# ==========================================
func inicializar_populacao():
	populacao.clear()
	notas_fitness.clear()
	desempenhos.clear()
	for i in range(TAMANHO_POPULACAO):
		var individuo = {}
		for gene in LIMITES_GENES:
			individuo[gene] = randf_range(LIMITES_GENES[gene][0], LIMITES_GENES[gene][1])
		populacao.append(individuo)
		notas_fitness.append(0.0)
		desempenhos.append(0.0)
	print("\n===== FASE EÓLICA: POPULAÇÃO INICIAL (geração 1) =====")
	imprimir_populacao(false)

# ==========================================
# TESTE DE CADA INDIVÍDUO AO VIVO, COM O JOGADOR
# ==========================================
func processar_algoritmo_genetico(delta: float):
	cronometro_etapa += delta
	var individuo = populacao[individuo_atual]

	match etapa:
		"inicio":
			if cronometro_etapa >= DURACAO_INICIO:
				mudar_etapa("aviso")
		"aviso":
			if cronometro_etapa >= individuo["aviso"]:
				mudar_etapa("rajada")
		"rajada":
			if cronometro_etapa >= individuo["duracao"]:
				mudar_etapa("calmaria")
		"calmaria":
			# Freio segurado no vento fraco = energia perdida (conta no desempenho)
			if freio_ativado:
				tempo_freando_na_calmaria += delta
			if cronometro_etapa >= individuo["intervalo"]:
				avaliar_fitness_individuo()
				individuo_atual += 1

				# Fim da geração: testou a população inteira
				if individuo_atual >= TAMANHO_POPULACAO:
					evoluir_populacao()
					individuo_atual = 0
					geracao_atual += 1
					geracao_nova = true # O Tiko avisa junto com o próximo aviso de vento
					mostrar_geracao_ia(true)

				mudar_etapa("aviso")

func mudar_etapa(nova_etapa: String):
	etapa = nova_etapa
	cronometro_etapa = 0.0

	match etapa:
		"inicio":
			forca_vento = FORCA_VENTO_FRACO
			mostrar_vento("VENTO FRACO", Color(0.1, 0.55, 0.1))
		"aviso":
			# Começa um indivíduo novo: zera as medidas do jogador
			dano_na_rajada = 0.0
			tempo_freando_na_calmaria = 0.0
			forca_vento = FORCA_VENTO_FRACO
			mostrar_vento("VEM VENTO FORTE!", Color(0.9, 0.45, 0.0))
			# Quando a IA acabou de criar ventos novos, o Tiko avisa no lugar do aviso falado
			# (a placa "VEM VENTO FORTE!" e o botão piscando continuam avisando o jogador)
			if geracao_nova:
				geracao_nova = false
				GameManager.tiko_diz.emit("Olha só! O robô aprendiz preparou novos ventos! Vamos ver como você se sai!")
			else:
				GameManager.tiko_diz.emit("Atenção! Vem vento forte por aí! Prepare o freio!")
		"rajada":
			forca_vento = populacao[individuo_atual]["forca"]
			mostrar_vento("VENTO FORTE!", Color(0.85, 0.1, 0.1))
			GameManager.tiko_diz.emit("Vento forte! Segure o FREIO agora!")
		"calmaria":
			forca_vento = FORCA_VENTO_FRACO
			mostrar_vento("VENTO FRACO", Color(0.1, 0.55, 0.1))
			GameManager.tiko_diz.emit("O vento ficou fraco! Pode soltar o FREIO para produzir energia!")

	atualizar_particulas_vento()

func mostrar_vento(texto: String, cor: Color):
	texto_vento.text = texto
	texto_vento.add_theme_color_override("font_color", cor)

# Mostra a geração da IA no topo da tela. Com animar = true, o quadro "pula" para chamar atenção.
func mostrar_geracao_ia(animar: bool):
	texto_ia.text = "Robô aprendiz: nível " + str(geracao_atual)
	if animar:
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(painel_ia, "scale", Vector2(1.25, 1.25), 0.2)
		tween.tween_property(painel_ia, "scale", Vector2.ONE, 0.3)

# ==========================================
# FUNÇÃO DE AVALIAÇÃO (FITNESS)
# 1. Desempenho do jogador na rajada (0 a 1):
#    perde até 0,7 pelo estrago na rajada e até 0,3 por frear no vento fraco.
# 2. Fitness = quão perto o desempenho ficou do ALVO (0,8):
#    rajada fácil demais (1,0) ou difícil demais (perto de 0) recebe nota menor.
# ==========================================
func avaliar_fitness_individuo():
	var individuo = populacao[individuo_atual]
	var erro_rajada = clamp(dano_na_rajada / DANO_REFERENCIA, 0.0, 1.0)
	var erro_calmaria = clamp(tempo_freando_na_calmaria / individuo["intervalo"], 0.0, 1.0)
	var desempenho = 1.0 - 0.7 * erro_rajada - 0.3 * erro_calmaria

	var fitness = 1.0 - abs(desempenho - ALVO_DESEMPENHO) / ALVO_DESEMPENHO
	desempenhos[individuo_atual] = desempenho
	notas_fitness[individuo_atual] = max(0.01, fitness)
	desempenhos_partida.append(desempenho)

# ==========================================
# NOVA GERAÇÃO: seleção, elitismo, cruzamento e mutação
# ==========================================
func evoluir_populacao():
	print("\n===== GERAÇÃO %d AVALIADA =====" % geracao_atual)
	imprimir_populacao(true)

	# 1. SELEÇÃO: ordena do maior para o menor fitness e pega os 2 melhores como pais
	var ordem = range(TAMANHO_POPULACAO)
	ordem.sort_custom(func(a, b): return notas_fitness[a] > notas_fitness[b])
	var pai1 = populacao[ordem[0]]
	var pai2 = populacao[ordem[1]]
	print("Pais: indivíduos %d e %d (o %d passa direto: elitismo)" % [ordem[0] + 1, ordem[1] + 1, ordem[0] + 1])

	# 2. ELITISMO: o melhor indivíduo passa igual para a próxima geração
	var nova_populacao = [pai1.duplicate()]

	# 3. CRUZAMENTO (uniforme) E MUTAÇÃO para os outros indivíduos
	while nova_populacao.size() < TAMANHO_POPULACAO:
		var filho = {}
		for gene in LIMITES_GENES:
			# 50% de chance de herdar o gene de cada pai
			var valor = pai1[gene] if randf() < 0.5 else pai2[gene]
			# MUTAÇÃO: muda o gene um pouco, sem sair dos limites
			if randf() < CHANCE_MUTACAO:
				var minimo = LIMITES_GENES[gene][0]
				var maximo = LIMITES_GENES[gene][1]
				valor = clamp(valor + randf_range(-TAMANHO_MUTACAO, TAMANHO_MUTACAO) * (maximo - minimo), minimo, maximo)
			filho[gene] = valor
		nova_populacao.append(filho)

	populacao = nova_populacao
	for i in range(TAMANHO_POPULACAO):
		notas_fitness[i] = 0.0
		desempenhos[i] = 0.0

	print("--- Nova população (geração %d) ---" % (geracao_atual + 1))
	imprimir_populacao(false)

# Tabela da população no terminal do Godot (aba Saída)
func imprimir_populacao(com_notas: bool):
	var cabecalho = "ind | força | aviso (s) | duração (s) | intervalo (s)"
	if com_notas:
		cabecalho += " | desempenho | fitness"
	print(cabecalho)
	for i in range(populacao.size()):
		var ind = populacao[i]
		var linha = "%3d | %5.1f | %9.2f | %11.2f | %13.2f" % [i + 1, ind["forca"], ind["aviso"], ind["duracao"], ind["intervalo"]]
		if com_notas:
			linha += " | %10.2f | %7.2f" % [desempenhos[i], notas_fitness[i]]
		print(linha)

# ==========================================
# FÍSICA DA TURBINA
# ==========================================
func processar_fisica_do_jogo(delta: float):
	var vento_forte = etapa == "rajada"

	if not freio_ativado:
		girar_helices(delta)

		if not vento_forte:
			energia_gerada = min(100.0, energia_gerada + forca_vento * 0.035 * delta)
			dano_turbina = max(0.0, dano_turbina - 5.0 * delta) # A turbina se recupera devagar
			pintar_turbinas(false)
		else:
			# Vento forte sem freio: quanto mais forte a rajada, mais estrago
			var dano = forca_vento * 0.4 * delta
			dano_turbina += dano
			dano_na_rajada += dano # Pro AG
			pintar_turbinas(true)
	else:
		pintar_turbinas(false)
		dano_turbina = max(0.0, dano_turbina - 15.0 * delta)

	barra_energia.value = energia_gerada
	barra_dano.value = dano_turbina
	atualizar_botao_freio(delta, etapa == "aviso" or vento_forte)

	if dano_turbina >= 100.0:
		perder_fase()

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

func atualizar_botao_freio(delta: float, alerta: bool):
	tempo_animacao += delta
	if freio_ativado:
		btn_freio.text = "FREANDO!"
		btn_freio.modulate = Color(0.8, 0.8, 0.8)
		btn_freio.scale = Vector2(0.96, 0.96) # Parece "afundado" também quando usa o espaço
	elif alerta:
		# Pisca e pulsa para chamar atenção: é hora de frear!
		var brilho = (sin(tempo_animacao * 10.0) + 1.0) / 2.0
		btn_freio.text = "FREIO"
		btn_freio.modulate = Color(1, 1, 1).lerp(Color(1, 1, 0.3), brilho)
		btn_freio.scale = Vector2.ONE * (1.0 + 0.05 * brilho)
	else:
		btn_freio.text = "FREIO"
		btn_freio.modulate = Color(1, 1, 1)
		btn_freio.scale = Vector2.ONE

# Os rastros de vento mostram a força do vento atual.
# (O "amount" não é mudado aqui porque isso reinicia as partículas e faz elas piscarem.)
func atualizar_particulas_vento():
	# 0 = vento mais fraco | 1 = vento mais forte possível
	var intensidade = clamp((forca_vento - 30.0) / 80.0, 0.0, 1.0)

	# Camada de fundo: sempre visível, mais rápida e mais forte quanto maior o vento
	particulas_vento.initial_velocity_min = 250.0 + forca_vento * 3.0
	particulas_vento.initial_velocity_max = 320.0 + forca_vento * 4.0
	particulas_vento.color.a = lerp(0.3, 0.75, intensidade)

	# Camada de ventania: só aparece durante a rajada (hora de frear!)
	particulas_vento_forte.emitting = forca_vento > LIMITE_SEGURO_VENTO
	particulas_vento_forte.initial_velocity_min = 500.0 + forca_vento * 4.0
	particulas_vento_forte.initial_velocity_max = 600.0 + forca_vento * 5.0

func vencer_fase():
	set_process(false)
	particulas_vento_forte.emitting = false
	freio_pelo_botao = false

	# PONTUAÇÃO: média do desempenho do jogador em todas as rajadas da partida
	var media = 0.0
	for d in desempenhos_partida:
		media += d
	media /= max(1, desempenhos_partida.size())
	GameManager.registrar_pontuacao("eolica", media * 100.0)
	print("\nFim da fase eólica: %d rajadas, %d gerações, pontuação %d" % [desempenhos_partida.size(), geracao_atual, round(media * 100.0)])

	if GameManager.modo_continuo:
		GameManager.tiko_diz.emit("Oba! A usina do vento está funcionando! A escola já tem energia! Agora vamos para a usina da água!")
		await GameManager.tiko_terminou_falar
		GameManager.pedir_nova_fase.emit("res://cenas/fase_hidreletrica.tscn")
	else:
		GameManager.tiko_diz.emit("Muito bem! Você conseguiu ligar a usina do vento! Agora a escola tem energia!")
		await GameManager.tiko_terminou_falar
		GameManager.mostrar_vitoria.emit()

func perder_fase():
	set_process(false)
	GameManager.tiko_diz.emit("Ops! O vento estava muito forte e a turbina quebrou! Vamos tentar de novo?")
	await get_tree().create_timer(3.0, false).timeout # false = o timer para durante a pausa
	get_tree().reload_current_scene()
