extends Node2D

# --- VARIÁVEIS DO JOGO ---
var simulacao_ativa: bool = false
var tempo_restante: float = 60.0 # O desafio de 1 minuto!
var comporta_aberta: bool = false # MUDANÇA: Apenas Aberta ou Fechada
var nivel_agua: float = 50.0
var tempo_na_faixa: float = 0.0 # Segundos com a água na faixa ideal (usado na pontuação)

# --- VARIÁVEIS DA IA (Q-LEARNING) ---
# A tabela Q não é salva: cada partida começa do zero (todos os valores Q em 0)
var q_table: Dictionary = {}
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
	print("\n===== FASE HIDRELÉTRICA: TABELA Q INICIAL =====")
	print(texto_tabela())
	# Começa com tudo desligado
	particulas_chuva.emitting = false
	particulas_comportas.emitting = false
	filtro_clima.color.a = 0.0
	
	var passos_tutorial = [
		"Você sabia? A água da represa passa pela turbina e faz ela girar! Assim, produzimos energia elétrica!",
		"O robô aprendiz vai escolher o tempo: sol, chuva ou tempestade! Cada um muda a quantidade de água da represa!",
		"Olhe a barra azul! Ela mostra a quantidade de água! Mantenha a água na faixa verde por um minuto!",
		"A água está subindo demais? Clique em ABRIR COMPORTA ou aperte a tecla A para deixar a água sair!",
		"A água está baixando demais? Clique em FECHAR COMPORTA ou aperte a tecla F para guardar a água!"
	]
	var tutorial_apareceu = await GameManager.exibir_tutorial("hidreletrica", "Usina da Água", passos_tutorial)

	if tutorial_apareceu:
		GameManager.tiko_diz.emit("Chegamos à usina da água! Aqui, precisamos cuidar da água da represa! O robô aprendiz vai mudar o tempo!")
	else:
		GameManager.tiko_diz.emit("Vamos tentar novamente! Fique de olho na barra azul! Ela mostra a quantidade de água!")
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
	# Fim de jogo é um estado terminal: não existe futuro depois dele
	if nivel_agua >= 100.0:
		recompensar_ia(-20.0, true) # Punição à IA por criar uma situação injogável
		perder_fase("Ops! A represa ficou cheia demais e a água transbordou! Na próxima, abra a comporta um pouco antes!")
	elif nivel_agua <= 0.0:
		recompensar_ia(-20.0, true) # Punição à IA
		perder_fase("Ah, não! A água da represa acabou e a turbina parou! Na próxima, feche a comporta um pouco antes!")

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
		# EMPATE: sorteia entre as ações com o maior valor Q (não favorece nenhum clima)
		var max_q = maior_q(ultimo_estado_ia)
		var empatadas = []
		for acao in q_table[ultimo_estado_ia]:
			if q_table[ultimo_estado_ia][acao] == max_q:
				empatadas.append(acao)
		ultima_acao_ia = empatadas[randi() % empatadas.size()]
	print("[IA] estado %s -> escolheu %s" % [NOMES_ESTADOS[ultimo_estado_ia], NOMES_CLIMAS[ultima_acao_ia]])

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

# terminal = true quando o jogo acabou (água transbordou ou secou): aí o futuro vale 0
func recompensar_ia(recompensa: float, terminal: bool = false):
	var novo_estado = obter_estado()

	if not q_table.has(novo_estado):
		q_table[novo_estado] = {0: 0.0, 1: 0.0, 2: 0.0}

	var max_q_novo = 0.0 if terminal else maior_q(novo_estado)

	# Atualiza a tabela matemática do Q-Learning
	var valor_antigo = q_table[ultimo_estado_ia][ultima_acao_ia]
	var valor_novo = valor_antigo + alpha * (recompensa + gamma * max_q_novo - valor_antigo)
	q_table[ultimo_estado_ia][ultima_acao_ia] = valor_novo
	print("[IA] (%s, %s, r=%.0f, %s)  Q: %.2f -> %.2f" % [NOMES_ESTADOS[ultimo_estado_ia], NOMES_CLIMAS[ultima_acao_ia], recompensa, "FIM" if terminal else NOMES_ESTADOS[novo_estado], valor_antigo, valor_novo])

func maior_q(estado: String) -> float:
	var maior = -INF
	for valor in q_table[estado].values():
		maior = max(maior, valor)
	return maior

# ==========================================
# TABELA Q NO TERMINAL DO GODOT (aba Saída)
# ==========================================
const NOMES_CLIMAS = {0: "Sol", 1: "Chuva", 2: "Tempestade"}
const NOMES_ESTADOS = {
	"0_0": "água baixa + comporta fechada", "0_1": "água baixa + comporta aberta",
	"1_0": "água ideal + comporta fechada", "1_1": "água ideal + comporta aberta",
	"2_0": "água alta + comporta fechada", "2_1": "água alta + comporta aberta",
}

func texto_tabela() -> String:
	if q_table.is_empty():
		return "(tabela vazia: todos os valores Q começam em 0)"
	var linhas = ["estado                        |    Sol |  Chuva | Tempestade"]
	var estados = q_table.keys()
	estados.sort()
	for estado in estados:
		var q = q_table[estado]
		linhas.append("%-29s | %6.2f | %6.2f | %10.2f" % [NOMES_ESTADOS[estado], q[0], q[1], q[2]])
	return "\n".join(linhas)

func aplicar_efeitos_clima():
	if nivel_chuva == 0: # SOL
		particulas_chuva.emitting = false
		filtro_clima.color.a = 0.0 
		GameManager.tiko_diz.emit("O sol apareceu! Agora a água da represa sobe bem devagar!")
	elif nivel_chuva == 1: # CHUVA
		particulas_chuva.emitting = true
		particulas_chuva.amount = 100
		filtro_clima.color.a = 0.3 
		GameManager.tiko_diz.emit("Começou a chover! Olhe só! A água da represa está subindo!")
	elif nivel_chuva == 2: # TEMPESTADE
		particulas_chuva.emitting = true
		particulas_chuva.amount = 300
		filtro_clima.color.a = 0.6 
		GameManager.tiko_diz.emit("Cuidado! Uma tempestade! A água está subindo muito rápido!")

# ==========================================
# BOTÕES E INTERAÇÃO DA COMPORTA ÚNICA
# ==========================================
func _on_botao_abrir_pressed():
	if simulacao_ativa and not comporta_aberta:
		comporta_aberta = true
		particulas_comportas.emitting = true 
		particulas_comportas.amount = 150 
		atualizar_botoes_comporta()
		GameManager.tiko_diz.emit("Comporta aberta! A água está saindo e fazendo a turbina girar!")

func _on_botao_fechar_pressed():
	if simulacao_ativa and comporta_aberta:
		comporta_aberta = false
		particulas_comportas.emitting = false
		atualizar_botoes_comporta()
		GameManager.tiko_diz.emit("Comporta fechada! Agora a água fica guardada na represa!")

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
	# A última escolha de clima também recebe a sua recompensa antes de acabar
	avaliar_e_aprender()
	print("\n===== FASE HIDRELÉTRICA: TABELA Q FINAL =====")
	print(texto_tabela())
	particulas_chuva.emitting = false
	filtro_clima.color.a = 0.0
	particulas_comportas.emitting = false
	
	# PONTUAÇÃO: porcentagem do minuto em que a água ficou na faixa ideal
	var pontuacao = (tempo_na_faixa / 60.0) * 100.0
	GameManager.registrar_pontuacao("hidreletrica", pontuacao)

	if GameManager.modo_continuo:
		GameManager.tiko_diz.emit("Viva! Conseguimos ligar as três usinas! Agora toda a cidade tem energia! Você é um verdadeiro Guardião da Energia!")
	else:
		GameManager.tiko_diz.emit("Parabéns! Você ligou a usina da água! Agora as ruas da cidade têm energia!")
	await GameManager.tiko_terminou_falar
	
	# Sempre mostra vitória aqui por ser o final de tudo ou o final da fase isolada
	GameManager.mostrar_vitoria.emit()
	
func perder_fase(motivo: String):
	simulacao_ativa = false
	print("\n===== FASE HIDRELÉTRICA: TABELA Q FINAL (perdeu) =====")
	print(texto_tabela())
	GameManager.tiko_diz.emit(motivo)
	await GameManager.tiko_terminou_falar
	get_tree().reload_current_scene()
