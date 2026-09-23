extends Node2D

# --- VARIÁVEIS DO JOGO ---
var simulacao_ativa: bool = false
var tempo_restante: float = 60.0 # O desafio de 1 minuto!
var comporta_aberta: bool = false # MUDANÇA: Apenas Aberta ou Fechada
var nivel_agua: float = 50.0
var tempo_na_faixa: float = 0.0 # Segundos com a água na faixa ideal (usado na pontuação)

# --- VARIÁVEIS DA IA (Q-LEARNING) ---
var q_table = {}
var alpha = 0.1
var gamma = 0.9
var epsilon = 0.2

var ultimo_estado_ia: String = ""
var ultima_acao_ia: int = -1
var tempo_para_ia_pensar: float = 5.0 # A IA avalia o clima a cada 5 segundos

# O clima atual: 0 = Sol, 1 = Chuva Normal, 2 = Tempestade
var nivel_chuva: int = 1 

# --- REFERÊNCIAS VISUAIS ---
@onready var barra_agua = $HUD/BarraAgua
@onready var barra_energia = $HUD/BarraEnergia
@onready var particulas_chuva = $ParticulasChuva
@onready var particulas_comportas = $ParticulasComportas
@onready var filtro_clima = $FiltroClima
@onready var texto_tempo = $HUD/TextoTempo
@onready var btn_abrir = $CamadaBotoes/BarraInferior/GrupoBotoes/BotaoAbrir
@onready var btn_fechar = $CamadaBotoes/BarraInferior/GrupoBotoes/BotaoFechar
@onready var texto_comporta = $CamadaBotoes/BarraInferior/GrupoBotoes/PainelComporta/TextoComporta

const COR_AGUA_OK = Color(0.10980392, 0.6392157, 0.9254902)
const COR_AGUA_PERIGO = Color(1.0, 0.45, 0.1)

func _ready():
	# Começa com tudo desligado
	particulas_chuva.emitting = false
	particulas_comportas.emitting = false
	filtro_clima.color.a = 0.0
	
	var passos_tutorial = [
		"A chuva enche o reservatório. A barra azul mostra quanta água tem.",
		"Se a água subir demais, clique em Abrir Comporta (ou tecla A). A água sai e gira a turbina.",
		"Se a água descer demais, clique em Fechar Comporta (ou tecla F) para guardar água.",
		"Cuide da usina por 1 minuto. Quanto mais tempo a água ficar na faixa verde IDEAL, mais pontos!"
	]
	var tutorial_apareceu = await GameManager.exibir_tutorial("hidreletrica", "Usina de Água", passos_tutorial)

	if tutorial_apareceu:
		GameManager.tiko_diz.emit("A IA vai mudar o tempo: sol, chuva ou tempestade. Começou!")
	else:
		GameManager.tiko_diz.emit("Vamos tentar de novo! Olhe sempre a barra azul.")
	await GameManager.tiko_terminou_falar
	
	iniciar_simulacao()

func iniciar_simulacao():
	simulacao_ativa = true
	ia_decide_clima() # IA toma a sua primeira decisão logo no início

func _process(delta):
	if not simulacao_ativa:
		return

	# --- 1. CRONÓMETRO ---
	tempo_restante -= delta
	if tempo_restante <= 0:
		ganhar_fase()
		return

	# --- 2. CICLO DE APRENDIZAGEM DA IA ---
	tempo_para_ia_pensar -= delta
	if tempo_para_ia_pensar <= 0:
		tempo_para_ia_pensar = 5.0
		avaliar_e_aprender() # A IA vê se a ação anterior foi boa e recebe pontos
		ia_decide_clima()    # A IA escolhe o próximo clima

	# --- 3. FÍSICA DA ÁGUA ---
	var entrada_agua = 0.0
	if nivel_chuva == 0: entrada_agua = 2.0     # Sol enche pouco
	elif nivel_chuva == 1: entrada_agua = 6.0   # Chuva normal
	elif nivel_chuva == 2: entrada_agua = 14.0  # Tempestade enche violentamente

	nivel_agua += entrada_agua * delta
	
	if comporta_aberta:
		nivel_agua -= 9.0 * delta # A água sai quando a comporta está aberta
		
	nivel_agua = clamp(nivel_agua, 0.0, 100.0)
	
	# Conta o tempo em que a água ficou na faixa ideal (entre 30 e 70)
	if nivel_agua >= 30.0 and nivel_agua <= 70.0:
		tempo_na_faixa += delta
	
	# --- 4. ATUALIZA BARRAS ---
	barra_agua.value = nivel_agua
	barra_energia.value = ((60.0 - tempo_restante) / 60.0) * 100.0
	texto_tempo.text = "TEMPO: faltam " + str(ceili(tempo_restante)) + " s"

	# A água fica laranja quando sai da faixa ideal, para chamar atenção
	var dentro_da_faixa = nivel_agua >= 30.0 and nivel_agua <= 70.0
	barra_agua.get_theme_stylebox("fill").bg_color = COR_AGUA_OK if dentro_da_faixa else COR_AGUA_PERIGO
	
	# --- 5. CONDIÇÕES DE DERROTA ---
	if nivel_agua >= 100.0:
		recompensar_ia(-20.0) # Punição à IA por criar uma situação injogável
		perder_fase("Ops! A água transbordou. Da próxima vez, abra a comporta antes.")
	elif nivel_agua <= 0.0:
		recompensar_ia(-20.0) # Punição à IA
		perder_fase("Ops! A água acabou e a turbina parou. Da próxima vez, feche a comporta antes.")

# ==========================================
# CÉREBRO Q-LEARNING
# ==========================================
func obter_estado() -> String:
	# Define a categoria da água
	var cat_agua = 1 # 1 = Ideal (entre 30 e 70)
	if nivel_agua < 30.0: cat_agua = 0     # 0 = Água Baixa
	elif nivel_agua > 70.0: cat_agua = 2   # 2 = Água Alta
	
	# Define a categoria da comporta
	var cat_comporta = 1 if comporta_aberta else 0
	
	# Retorna a string do Estado (ex: "2_0" -> Água Alta e Comporta Fechada)
	return str(cat_agua) + "_" + str(cat_comporta)

func ia_decide_clima():
	ultimo_estado_ia = obter_estado()
	
	# Se a IA nunca viu este estado, cria a linha na Q-Table
	if not q_table.has(ultimo_estado_ia):
		q_table[ultimo_estado_ia] = {0: 0.0, 1: 0.0, 2: 0.0}
		
	# Epsilon-Greedy (Explorar vs Exploitar)
	if randf() < epsilon:
		ultima_acao_ia = randi() % 3 # Escolhe Sol, Chuva ou Tempestade à sorte
	else:
		var max_q = -INF
		var melhor_acao = 1
		for acao in q_table[ultimo_estado_ia]:
			if q_table[ultimo_estado_ia][acao] > max_q:
				max_q = q_table[ultimo_estado_ia][acao]
				melhor_acao = acao
		ultima_acao_ia = melhor_acao
		
	nivel_chuva = ultima_acao_ia
	aplicar_efeitos_clima()

func avaliar_e_aprender():
	if ultimo_estado_ia == "": return
	
	var recompensa = 0.0
	
	# O objetivo da IA é que o jogo seja educativo e acessível
	if nivel_agua >= 30.0 and nivel_agua <= 70.0:
		recompensa = 10.0 # Biscoito! O clima ajudou o jogador a equilibrar a água.
	else:
		recompensa = -5.0 # Castigo! A água está em perigo.
		
	recompensar_ia(recompensa)

func recompensar_ia(recompensa: float):
	var novo_estado = obter_estado()
	
	if not q_table.has(novo_estado):
		q_table[novo_estado] = {0: 0.0, 1: 0.0, 2: 0.0}
		
	var max_q_novo = -INF
	for acao in q_table[novo_estado]:
		if q_table[novo_estado][acao] > max_q_novo:
			max_q_novo = q_table[novo_estado][acao]
			
	# Atualiza a tabela matemática do Q-Learning
	var valor_antigo = q_table[ultimo_estado_ia][ultima_acao_ia]
	q_table[ultimo_estado_ia][ultima_acao_ia] = valor_antigo + alpha * (recompensa + gamma * max_q_novo - valor_antigo)

func aplicar_efeitos_clima():
	if nivel_chuva == 0: # SOL
		particulas_chuva.emitting = false
		filtro_clima.color.a = 0.0 
		GameManager.tiko_diz.emit("Fez sol! A água vai subir devagar.")
	elif nivel_chuva == 1: # CHUVA
		particulas_chuva.emitting = true
		particulas_chuva.amount = 100
		filtro_clima.color.a = 0.3 
		GameManager.tiko_diz.emit("Está chovendo. A água vai subir.")
	elif nivel_chuva == 2: # TEMPESTADE
		particulas_chuva.emitting = true
		particulas_chuva.amount = 300
		filtro_clima.color.a = 0.6 
		GameManager.tiko_diz.emit("Tempestade! A água vai subir muito rápido. Cuidado!")

# ==========================================
# BOTÕES E INTERAÇÃO DA COMPORTA ÚNICA
# ==========================================
func _on_botao_abrir_pressed():
	if simulacao_ativa and not comporta_aberta:
		comporta_aberta = true
		particulas_comportas.emitting = true 
		particulas_comportas.amount = 150 
		atualizar_botoes_comporta()
		GameManager.tiko_diz.emit("Comporta aberta! A água está saindo e girando a turbina.")

func _on_botao_fechar_pressed():
	if simulacao_ativa and comporta_aberta:
		comporta_aberta = false
		particulas_comportas.emitting = false
		atualizar_botoes_comporta()
		GameManager.tiko_diz.emit("Comporta fechada! A água está sendo guardada.")

# Teclado: A abre e F fecha a comporta
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_A:
			_on_botao_abrir_pressed()
		elif event.physical_keycode == KEY_F:
			_on_botao_fechar_pressed()

# Só o botão da ação possível fica aceso; o outro fica cinza
func atualizar_botoes_comporta():
	btn_abrir.disabled = comporta_aberta
	btn_fechar.disabled = not comporta_aberta
	texto_comporta.text = "Comporta\nABERTA" if comporta_aberta else "Comporta\nFECHADA"

# ==========================================
# FIM DE JOGO
# ==========================================
func ganhar_fase():
	simulacao_ativa = false
	particulas_chuva.emitting = false
	filtro_clima.color.a = 0.0
	particulas_comportas.emitting = false
	
	# PONTUAÇÃO: porcentagem do minuto em que a água ficou na faixa ideal
	var pontuacao = (tempo_na_faixa / 60.0) * 100.0
	GameManager.registrar_pontuacao("hidreletrica", pontuacao)

	GameManager.tiko_diz.emit("Parabéns! Você cuidou da usina e gerou energia limpa!")
	await GameManager.tiko_terminou_falar
	
	# Sempre mostra vitória aqui por ser o final de tudo ou o final da fase isolada
	GameManager.mostrar_vitoria.emit()
	
func perder_fase(motivo: String):
	simulacao_ativa = false
	GameManager.tiko_diz.emit(motivo)
	await GameManager.tiko_terminou_falar
	get_tree().reload_current_scene()
