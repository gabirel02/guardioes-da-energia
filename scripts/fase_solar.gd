extends Node2D

var sujeiras_restantes = 15
var rodadas_treinamento = 0
var tempo_inicio_rodada: int = 0
var tempo_gasto: float = 0.0
var notas_rodadas: Array = [] # Nota (0 a 100) de cada rodada de alinhamento
var angulos_sol_usados: Array = [] # Posições do sol já usadas (o teste final usa uma nova)

# O Q-Learning fica em agente_q_solar.gd. A tabela Q não é salva:
# cada vez que a fase começa, a IA começa do zero (todos os valores Q em 0).
var agente := AgenteQSolar.new()
# Episódios que a IA treina sozinha depois de cada rodada do jogador
# (provisório: trocar pelo melhor valor do experimento_solar)
const EPISODIOS_POR_RODADA = 100

@export var centro_x: float = 640.0
@export var centro_y: float = 600.0
@export var largura_arco: float = 650.0
@export var altura_arco: float = 550.0

@onready var ceu: TextureRect = $Ceu
@onready var botao_esq = $CamadaBotoes/BarraInferior/GrupoBotoes/BotaoEsquerda
@onready var botao_dir = $CamadaBotoes/BarraInferior/GrupoBotoes/BotaoDireito
@onready var botao_confirmar = $CamadaBotoes/BarraInferior/GrupoBotoes/BotaoConfirmar
@onready var sol = $Sol
@onready var painel = $PainelSolar
@onready var painel_ia_dir: TextureRect = $PainelIA_Dir
@onready var painel_ia_esq: TextureRect = $PainelIA_Esq
@onready var grupo_botoes = $CamadaBotoes/BarraInferior/GrupoBotoes
@onready var painel_contador = $CamadaBotoes/PainelContador
@onready var texto_contador = $CamadaBotoes/PainelContador/TextoContador

const TOTAL_SUJEIRAS = 15
const TOTAL_RODADAS = 3
var alinhamento_ativo: bool = false # Só aceita o teclado enquanto o jogador alinha o painel

# Falas do Tiko (sem áudio por enquanto)
var falas = {
	1: {"texto": "Vamos começar pela usina solar! Os painéis estão sujos! Passe o mouse nas manchas para limpar!"},
	2: {"texto": "Você está indo muito bem! Faltam só duas manchas! Continue assim!"},
	3: {"texto": "Que beleza! Os painéis estão limpinhos! Agora eles podem receber a luz do sol!"},
	4: {"texto": "Agora, vamos virar o painel do meio para o sol! Quando terminar, clique em CONFIRMAR!"},
	5: {"texto": "Quase! Vire mais um pouquinho."},
	6: {"texto": "Muito bem! O robô aprendiz está aprendendo com você! Olha só! O sol mudou de posição!"},
	7: {"texto": "Olha que legal! O sol muda de posição e o robô acompanha, virando os painéis!"},
	8: {"texto": "Agora é a vez do robô aprendiz! Vamos ver se ele consegue virar os painéis sozinho!"}
}

var passos_tutorial = [
	"Você sabia? Os painéis solares recebem a luz do sol e a transformam em energia elétrica!",
	"Primeiro, vamos limpar os painéis! Passe o mouse sobre as manchas até elas desaparecerem!",
	"Agora, clique em GIRAR ou use as setas do teclado para virar o painel do meio em direção ao sol!",
	"Quando o painel estiver virado para o sol, clique em CONFIRMAR ou aperte ENTER!",
	"Preste atenção! O robô aprendiz observa como você joga! Depois, ele vai tentar fazer tudo sozinho!"
]

func _ready():
	print("\n===== FASE SOLAR: TABELA Q INICIAL =====")
	print(agente.texto_tabela())

	# O tempo em que o jogo ficou pausado não conta no cronômetro da rodada
	GameManager.pausa_terminou.connect(func(duracao_ms): tempo_inicio_rodada += duracao_ms)

	# Esconde os botões no começo
	modo_dialogo()

	# Mostra o tutorial antes de a fase começar
	await GameManager.exibir_tutorial("solar", "Usina Solar", passos_tutorial)
	tocar_tiko(1)

func sujeira_removida():
	sujeiras_restantes -= 1
	texto_contador.text = "Manchas limpas: " + str(TOTAL_SUJEIRAS - sujeiras_restantes) + " de " + str(TOTAL_SUJEIRAS)
	if sujeiras_restantes == 2:
		tocar_tiko(2)
	elif sujeiras_restantes <= 0:
		await tocar_tiko(3)
		iniciar_fase_alinhamento()

func iniciar_fase_alinhamento():
	modo_jogo()
	alinhamento_ativo = true
	mudar_posicao_do_sol()
	tocar_tiko(4)

func mudar_posicao_do_sol():
	var angulo_aleatorio = randf_range(20, 160)
	angulos_sol_usados.append(angulo_aleatorio)
	colocar_sol_no_arco(angulo_aleatorio)
	# Inicia o cronômetro para medir o tempo de reação
	tempo_inicio_rodada = Time.get_ticks_msec()
	texto_contador.text = "Sol " + str(rodadas_treinamento + 1) + " de " + str(TOTAL_RODADAS)
	print("\n===== RODADA %d: sol em %.1f° (painel precisa ficar em %.1f°) =====" % [rodadas_treinamento + 1, angulo_aleatorio, angulo_ideal_para(painel)])

# Coloca o centro do sol em cima do arco (0° = direita, 90° = topo, 180° = esquerda)
func colocar_sol_no_arco(angulo_graus: float):
	var radianos = deg_to_rad(angulo_graus)
	var novo_x = centro_x + (cos(radianos) * largura_arco)
	var novo_y = centro_y - (sin(radianos) * altura_arco)
	sol.position = Vector2(novo_x - (sol.size.x / 2), novo_y - (sol.size.y / 2))

# Ângulo que o painel precisa ter para ficar virado para o sol
func angulo_ideal_para(painel_alvo) -> float:
	var centro_do_sol = sol.position + (sol.size / 2)
	var centro_do_painel = painel_alvo.position + (painel_alvo.size / 2)
	return rad_to_deg((centro_do_sol - centro_do_painel).angle()) + 90

# ==========================================
# EXPERIÊNCIAS DO JOGADOR
# Cada clique do jogador vira uma transição (estado, ação, recompensa, novo estado)
# que atualiza a tabela Q com a mesma fórmula do Q-Learning.
# ==========================================
func _on_girar_esquerda():
	jogador_agiu(-15)

func _on_girar_direita():
	jogador_agiu(15)

func jogador_agiu(acao: int):
	if not alinhamento_ativo:
		return
	var ang_sol = angulo_ideal_para(painel)
	var estado = agente.obter_estado(ang_sol, painel.rotation_degrees)
	if acao < 0:
		painel.girar_esquerda()
	elif acao > 0:
		painel.girar_direita()
	var novo_estado = agente.obter_estado(ang_sol, painel.rotation_degrees)
	registrar_experiencia_jogador(estado, acao, novo_estado)

func registrar_experiencia_jogador(estado: int, acao: int, novo_estado: int):
	# No estado 0 (alinhado) o episódio já acabou: não há o que atualizar
	if agente.e_terminal(estado):
		print("[Jogador] estado 0 (já alinhado), ação %+d: sem atualização" % acao)
		return
	var recompensa = agente.calcular_recompensa(novo_estado, acao)
	var conta = agente.atualizar(estado, acao, recompensa, novo_estado)
	print("[Jogador] (%d, %+d, r=%.0f, %d)  Q: %.2f -> %.2f" % [estado, acao, recompensa, novo_estado, conta["q_antigo"], conta["q_novo"]])

func verificar_alinhamento():
	if not alinhamento_ativo:
		return
	# Calcula o tempo que o jogador demorou
	tempo_gasto = (Time.get_ticks_msec() - tempo_inicio_rodada) / 1000.0

	var angulo_ideal = angulo_ideal_para(painel)
	var erro_em_graus = abs(wrapf(painel.rotation_degrees - angulo_ideal, -180.0, 180.0))

	# CONFIRMAR também é uma experiência: o jogador escolheu ficar parado (ação 0)
	var estado = agente.obter_estado(angulo_ideal, painel.rotation_degrees)
	registrar_experiencia_jogador(estado, 0, estado)

	# NOTA DO JOGADOR (só para a pontuação e as estrelas; não mexe no treino da IA)
	# PRECISÃO: as setas giram de 15 em 15 graus, então errar até 7.5° é o melhor possível (100).
	# Depois disso perde pontos até zerar com 67.5° de erro.
	var precisao = clamp(100.0 - (erro_em_graus - 7.5) * (100.0 / 60.0), 0.0, 100.0)
	# TEMPO: os primeiros 15 segundos são livres; depois perde 2 pontos por segundo (no máximo 30)
	var penalidade_tempo = clamp((tempo_gasto - 15.0) * 2.0, 0.0, 30.0)
	var nota = clamp(precisao - penalidade_tempo, 0.0, 100.0)
	notas_rodadas.append(nota)

	# Depois da experiência do jogador, a IA treina sozinha, explorando (ε-greedy)
	agente.treinar(EPISODIOS_POR_RODADA)
	print("--- Tabela Q depois da rodada %d (%d episódios de treino) ---" % [rodadas_treinamento + 1, EPISODIOS_POR_RODADA])
	print(agente.texto_tabela())

	rodadas_treinamento += 1

	if rodadas_treinamento < TOTAL_RODADAS:
		GameManager.tiko_diz.emit("Você fez " + str(round(nota)) + " pontos! " + falas[6]["texto"])
		mudar_posicao_do_sol()
	else:
		iniciar_ia()

func iniciar_ia():
	modo_dialogo()
	alinhamento_ativo = false
	painel_contador.hide()

	# PONTUAÇÃO DA FASE: 10 pontos pela limpeza + até 90 pela média das 3 rodadas
	var media = 0.0
	for nota in notas_rodadas:
		media += nota
	media /= max(1, notas_rodadas.size())
	GameManager.registrar_pontuacao("solar", 10.0 + media * 0.9)

	# 1. TESTE FINAL: sol numa posição nova, ε = 0, a IA vira os painéis sozinha
	await tocar_tiko(8)
	var movimentos = await teste_final()
	if movimentos >= 0:
		GameManager.tiko_diz.emit("Oba! Ele conseguiu! O robô aprendeu e virou os painéis para o sol! Parabéns!")
	else:
		GameManager.tiko_diz.emit("Ops! Ainda não deu certo! Mas tudo bem! Nosso robô precisa aprender um pouquinho mais!")
	await GameManager.tiko_terminou_falar

	# 2. DEMONSTRAÇÃO: o sol atravessa o céu e os 3 painéis seguem
	await tocar_tiko(7)
	var tween = create_tween()
	tween.tween_method(passagem_do_tempo, 20.0, 160.0, 10.0)
	await tween.finished

	if GameManager.modo_continuo:
		GameManager.tiko_diz.emit("Conseguimos! A usina solar está funcionando! As casas já têm energia! Agora vamos para a usina do vento!")
		await GameManager.tiko_terminou_falar
		GameManager.pedir_nova_fase.emit("res://cenas/fase_eolica.tscn")
	else:
		GameManager.tiko_diz.emit("Parabéns! Você conseguiu ligar a usina solar! Agora as casas têm energia!")
		await GameManager.tiko_terminou_falar
		GameManager.mostrar_vitoria.emit()

# ==========================================
# TESTE FINAL
# Devolve o total de movimentos, ou -1 se algum painel não alinhou.
# ==========================================
func teste_final() -> int:
	var paineis = [painel_ia_esq, painel, painel_ia_dir]

	# Os painéis voltam para a posição inicial
	var volta = create_tween().set_parallel()
	for p in paineis:
		volta.tween_property(p, "rotation_degrees", AgenteQSolar.PAINEL_INICIAL, 0.5)
	await volta.finished

	colocar_sol_no_arco(escolher_angulo_novo())
	print("\n===== TESTE FINAL (ε = 0, sem aprender) =====")

	var movimentos = 0
	var ativos = paineis.duplicate()
	for passo in range(agente.max_passos):
		var giro = create_tween().set_parallel()
		var alguem_girou = false
		for p in ativos.duplicate():
			var estado = agente.obter_estado(angulo_ideal_para(p), p.rotation_degrees)
			var acao = agente.escolher_acao(estado, false)
			if acao == 0:
				ativos.erase(p) # Alinhou (ou decidiu ficar parado)
				continue
			var antes = p.rotation_degrees
			if acao < 0:
				p.girar_esquerda()
			else:
				p.girar_direita()
			var depois = p.rotation_degrees
			if depois == antes:
				ativos.erase(p) # Bateu no limite da base
				continue
			p.rotation_degrees = antes
			giro.tween_property(p, "rotation_degrees", depois, 0.3)
			alguem_girou = true
			movimentos += 1
		if not alguem_girou:
			giro.kill()
			break
		await giro.finished
		await get_tree().create_timer(0.2, false).timeout

	var todos_alinharam = true
	for p in paineis:
		var estado = agente.obter_estado(angulo_ideal_para(p), p.rotation_degrees)
		print("%s: estado final %d (erro %.1f°)" % [p.name, estado, abs(wrapf(angulo_ideal_para(p) - p.rotation_degrees, -180.0, 180.0))])
		if not agente.e_terminal(estado):
			todos_alinharam = false
	print("Movimentos: %d | Todos alinharam: %s" % [movimentos, todos_alinharam])
	return movimentos if todos_alinharam else -1

# Sorteia uma posição do sol longe das 3 posições do jogador
# e longe de onde os painéis começam (para a IA ter que girar)
func escolher_angulo_novo() -> float:
	var angulo = 90.0
	for tentativa in range(100):
		angulo = randf_range(20, 160)
		var longe_das_rodadas = true
		for usado in angulos_sol_usados:
			if abs(angulo - usado) < 25.0:
				longe_das_rodadas = false
		colocar_sol_no_arco(angulo)
		var longe_do_inicio = abs(angulo_ideal_para(painel) - AgenteQSolar.PAINEL_INICIAL) >= 40.0
		if longe_das_rodadas and longe_do_inicio:
			break
	return angulo

func passagem_do_tempo(angulo_atual: float):
	# 1. MOVE O SOL SUAVEMENTE
	colocar_sol_no_arco(angulo_atual)

	# 2. O TRUQUE DA TRANSIÇÃO SUAVE
	var progresso_linear = (angulo_atual - 20.0) / 140.0
	var progresso_suave = pow(progresso_linear, 2.5)

	# 3. MUDA A COR DO SOL
	sol.modulate = Color(1.0, 1.0, 0.0).lerp(Color(1.0, 0.55, 0.0), progresso_suave)

	# 4. MUDA A COR DO CÉU E DA GRAMA
	ceu.modulate = Color(1.0, 1.0, 1.0).lerp(Color(0.15, 0.15, 0.35), progresso_suave)

	# 5. MANDA OS PAINÉIS DA IA (E O DO MEIO) SEGUIREM O SOL
	alinhar_painel_ia(painel_ia_esq)
	alinhar_painel_ia(painel)
	alinhar_painel_ia(painel_ia_dir)

func alinhar_painel_ia(painel_alvo):
	var estado_atual = agente.obter_estado(angulo_ideal_para(painel_alvo), painel_alvo.rotation_degrees)
	var acao_escolhida = agente.escolher_acao(estado_atual, false)
	painel_alvo.rotation_degrees += (acao_escolhida * 0.05)

func tocar_tiko(id: int):
	if falas.has(id):
		# Manda a mensagem para a Cena Principal animar o texto
		GameManager.tiko_diz.emit(falas[id]["texto"])
		# Espera o GameManager avisar que terminou de animar
		await GameManager.tiko_terminou_falar

# Teclado: setas giram o painel do meio, Enter (ou Espaço) confirma
func _unhandled_input(event):
	if not alinhamento_ativo:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_LEFT:
				jogador_agiu(-15)
			KEY_RIGHT:
				jogador_agiu(15)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				verificar_alinhamento()

func modo_dialogo():
	grupo_botoes.hide()
	GameManager.mostrar_balao.emit()

func modo_jogo():
	grupo_botoes.show()
	GameManager.esconder_balao.emit()
