extends Node2D

var sujeiras_restantes = 15 
var rodadas_treinamento = 0
var pontuacao_ia = 0.0
var tempo_inicio_rodada: int = 0
var tempo_gasto: float = 0.0
var notas_rodadas: Array = [] # Nota (0 a 100) de cada rodada de alinhamento
var q_table = {}
var alpha = 0.2  
var gamma = 0.9  
var epsilon = 0.2 

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

var linha_arco: Line2D
var erro_da_ia: float = 0.0

# Falas do Tiko (sem áudio por enquanto)
var falas = {
	1: {"texto": "Oi, eu sou o Tiko! Passe o mouse nas manchas para limpar os 3 painéis."},
	2: {"texto": "Muito bem! Falta pouco!"},
	3: {"texto": "O painel está limpo! Agora vamos virar o painel para o sol."},
	4: {"texto": "Use GIRAR para virar o painel. Depois, clique em CONFIRMAR."},
	5: {"texto": "Quase! Vire mais um pouquinho."},
	6: {"texto": "Muito bem! A IA aprendeu com você. Vamos para o próximo sol!"},
	7: {"texto": "Pronto! Agora veja a IA virar os painéis sozinha!"}
}

var passos_tutorial = [
	"Passe o mouse em cima das manchas para limpar os 3 painéis solares.",
	"Use os botões GIRAR (ou as setas do teclado) para virar o painel do meio para o sol.",
	"Com o painel virado para o sol, clique em CONFIRMAR (ou Enter). Quanto mais certinho, mais pontos!",
	"Você vai fazer isso 3 vezes. A IA aprende com você e depois vira os painéis sozinha!"
]

func _ready():

	# Esconde os botões no começo
	modo_dialogo()

	# Cria a linha vermelha por cima de tudo na tela!
	linha_arco = Line2D.new()
	linha_arco.default_color = Color.RED
	linha_arco.width = 4.0
	add_child(linha_arco) # O add_child garante que ela fique na frente

	#desenhar_arco()

	# Mostra o tutorial antes de a fase começar
	await GameManager.exibir_tutorial("solar", "Usina Solar", passos_tutorial)
	tocar_tiko(1)

func desenhar_arco():
	var pontos = PackedVector2Array()
	# Faz um arco suave de 20 a 160 graus
	for i in range(51):
		var angulo = lerp(20.0, 160.0, float(i) / 50.0)
		var radianos = deg_to_rad(angulo)
		var px = centro_x + (cos(radianos) * largura_arco)
		var py = centro_y - (sin(radianos) * altura_arco)
		pontos.append(Vector2(px, py))
	
	linha_arco.points = pontos

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
	var radianos = deg_to_rad(angulo_aleatorio)
	
	# Calcula a posição matemática da linha vermelha
	var novo_x = centro_x + (cos(radianos) * largura_arco)
	var novo_y = centro_y - (sin(radianos) * altura_arco)
	
	# O TRUQUE: Subtraímos metade da largura e metade da altura 
	# para o "meio" do Sol ficar cravado na linha vermelha!
	sol.position = Vector2(novo_x - (sol.size.x / 2), novo_y - (sol.size.y / 2))	
	# Inicia o cronômetro para medir o tempo de reação
	tempo_inicio_rodada = Time.get_ticks_msec()
	texto_contador.text = "Sol " + str(rodadas_treinamento + 1) + " de " + str(TOTAL_RODADAS)

func verificar_alinhamento():
	# Calcula o tempo que o jogador demorou
	tempo_gasto = (Time.get_ticks_msec() - tempo_inicio_rodada) / 1000.0
	
	var centro_do_sol = sol.position + (sol.size / 2)
	var centro_do_painel = painel.position + (painel.size / 2)
	var direcao_ao_sol = (centro_do_sol - centro_do_painel).angle()
	var angulo_ideal = rad_to_deg(direcao_ao_sol) + 90 
	
	var erro_em_graus = abs(wrapf(painel.rotation_degrees - angulo_ideal, -180.0, 180.0))
	
	# PRECISÃO: as setas giram de 15 em 15 graus, então errar até 7.5° é o melhor possível (100).
	# Depois disso perde pontos até zerar com 67.5° de erro.
	var precisao = clamp(100.0 - (erro_em_graus - 7.5) * (100.0 / 60.0), 0.0, 100.0)

	# TEMPO: os primeiros 15 segundos são livres; depois perde 2 pontos por segundo (no máximo 30)
	var penalidade_tempo = clamp((tempo_gasto - 15.0) * 2.0, 0.0, 30.0)

	var recompensa = clamp(precisao - penalidade_tempo, 0.0, 100.0)
	notas_rodadas.append(recompensa)
	# A IA aprende AGORA com base nesta rodada específica
	aprender_com_rodada(recompensa, angulo_ideal)

	rodadas_treinamento += 1

	if rodadas_treinamento < 3:
		GameManager.tiko_diz.emit("Você fez " + str(round(recompensa)) + " pontos! A IA aprendeu com você. Vamos para o próximo sol!")
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

	GameManager.tiko_diz.emit(falas[7]["texto"])
	await GameManager.tiko_terminou_falar 
	
	var tween = create_tween()
	tween.tween_method(passagem_do_tempo, 20.0, 160.0, 10.0)
	await tween.finished
	
	if GameManager.modo_continuo:
		GameManager.tiko_diz.emit("Muito bem! Agora vamos para a usina de vento!")
		await GameManager.tiko_terminou_falar
		GameManager.pedir_nova_fase.emit("res://cenas/fase_eolica.tscn")
	else:
		GameManager.tiko_diz.emit("Muito bem! Você terminou a usina solar!")
		await GameManager.tiko_terminou_falar
		GameManager.mostrar_vitoria.emit()

func obter_estado(ang_sol: float, ang_painel: float) -> int:
	var diff = wrapf(ang_sol - ang_painel, -180.0, 180.0)
	return int(round(diff / 15.0) * 15)

func escolher_acao(estado: int, explorando: bool) -> int:
	var acoes = [-15, 0, 15]
	
	if not q_table.has(estado):
		q_table[estado] = {-15: 0.0, 0: 0.0, 15: 0.0}
		
	if explorando and randf() < epsilon:
		return acoes[randi() % acoes.size()]
		
	var max_q = -INF
	var melhores_acoes = []
	
	for acao in q_table[estado]:
		var valor_q = q_table[estado][acao]
		if valor_q > max_q:
			max_q = valor_q
			melhores_acoes = [acao] 
		elif valor_q == max_q:
			melhores_acoes.append(acao) 
			
	if melhores_acoes.has(0):
		return 0
	else:
		return melhores_acoes[0]

func aprender_com_rodada(nota_jogador: float, angulo_sol_atual: float):
	var peso = pow(nota_jogador / 100.0, 2.0) 
	var episodios_desta_rodada = int(150 * peso)
	
	for i in range(episodios_desta_rodada):
		var sol_treino = clamp(angulo_sol_atual + randf_range(-30, 30), 20, 160)
		var painel_treino = randf_range(20, 160)
		
		for step in range(15): 
			var estado_atual = obter_estado(sol_treino, painel_treino)
			var acao = escolher_acao(estado_atual, true)
			
			var novo_painel = painel_treino + acao
			var novo_estado = obter_estado(sol_treino, novo_painel)
			
			var penalidade_erro = abs(novo_estado)
			var penalidade_tempo = 10.0 if acao != 0 else 0.0
			var recompensa = -penalidade_erro - penalidade_tempo
			
			if not q_table.has(novo_estado):
				q_table[novo_estado] = {-15: 0.0, 0: 0.0, 15: 0.0}
				
			var max_q_novo = -INF
			for val in q_table[novo_estado].values():
				if val > max_q_novo: max_q_novo = val
				
			q_table[estado_atual][acao] = q_table[estado_atual][acao] + alpha * (recompensa + gamma * max_q_novo - q_table[estado_atual][acao])
			
			painel_treino = novo_painel
			
			if penalidade_erro == 0:
				break

func passagem_do_tempo(angulo_atual: float):
	# 1. MOVE O SOL SUAVEMENTE
	var radianos = deg_to_rad(angulo_atual)
	var novo_x = centro_x + (cos(radianos) * largura_arco)
	var novo_y = centro_y - (sin(radianos) * altura_arco)
	sol.position = Vector2(novo_x - (sol.size.x / 2), novo_y - (sol.size.y / 2))
	
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
	var centro_do_sol = sol.position + (sol.size / 2)
	var centro_do_painel = painel_alvo.position + (painel_alvo.size / 2)
	
	var direcao_ao_sol = (centro_do_sol - centro_do_painel).angle()
	var angulo_sol_graus = rad_to_deg(direcao_ao_sol) + 90
	
	var estado_atual = obter_estado(angulo_sol_graus, painel_alvo.rotation_degrees)
	var acao_escolhida = escolher_acao(estado_atual, false)
	
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
				painel.girar_esquerda()
			KEY_RIGHT:
				painel.girar_direita()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				verificar_alinhamento()

func modo_dialogo():
	grupo_botoes.hide()
	GameManager.mostrar_balao.emit()

func modo_jogo():
	grupo_botoes.show()
	GameManager.esconder_balao.emit()
