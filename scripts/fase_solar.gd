extends Node2D

var sujeiras_restantes = 15 
var rodadas_treinamento = 0
var pontuacao_ia = 0.0
var tempo_inicio_rodada: int = 0
var tempo_gasto: float = 0.0
var q_table = {}
var alpha = 0.2  
var gamma = 0.9  
var epsilon = 0.2 

@export var centro_x: float = 640.0
@export var centro_y: float = 600.0
@export var largura_arco: float = 650.0
@export var altura_arco: float = 550.0

@onready var ceu: TextureRect = $Ceu
@onready var botao_esq = $BarraInferior/GrupoBotoes/BotaoEsquerda
@onready var botao_dir = $BarraInferior/GrupoBotoes/BotaoDireito
@onready var botao_confirmar = $BarraInferior/GrupoBotoes/BotaoConfirmar
@onready var sol = $Sol
@onready var painel = $PainelSolar
@onready var tiko_label: Label = $BarraInferior/BalaoFala/Label
@onready var painel_ia_dir: TextureRect = $PainelIA_Dir
@onready var painel_ia_esq: TextureRect = $PainelIA_Esq
@onready var audio_player: AudioStreamPlayer2D = $AudioPlayer
@onready var grupo_botoes = $BarraInferior/GrupoBotoes
@onready var balao_fala = $BarraInferior/BalaoFala

var linha_arco: Line2D
var erro_da_ia: float = 0.0

var falas = {
	1: {"texto": "Olá, Guardião! Eu sou o Tiko. Passe a mão para limpar o painel.", "audio": preload("res://assets/fala1.mp3")},
	2: {"texto": "Muito bem! Continue limpando.", "audio": preload("res://assets/fala2.mp3")},
	3: {"texto": "Painel limpo! Excelente trabalho. Agora, vamos calibrar o sistema.", "audio": preload("res://assets/fala3.mp3")},
	4: {"texto": "Nova posição do Sol! Use as setas e clique em confirmar.", "audio": preload("res://assets/fala4.mp3")},
	5: {"texto": "Quase lá! Tente ajustar mais um pouquinho.", "audio": preload("res://assets/fala5.mp3")},
	6: {"texto": "Incrível! A IA está aprendendo. Próximo Sol!", "audio": preload("res://assets/fala6.mp3")},
	7: {"texto": "Treino concluído! Veja a IA trabalhando sozinha!", "audio": preload("res://assets/fala7.mp3")}
}

func _ready():
	
	# Esconde os botões no começo
	modo_dialogo()
	tocar_tiko(1)
	
	# Cria a linha vermelha por cima de tudo na tela!
	linha_arco = Line2D.new()
	linha_arco.default_color = Color.RED
	linha_arco.width = 4.0
	add_child(linha_arco) # O add_child garante que ela fique na frente
	
	desenhar_arco()
	
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
	if sujeiras_restantes == 2:
		tocar_tiko(2)
	elif sujeiras_restantes <= 0:
		await tocar_tiko(3)
		iniciar_fase_alinhamento()

func iniciar_fase_alinhamento():
	modo_jogo()
	mudar_posicao_do_sol()

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
	#tiko_label.text = "TIKO: Nova posição do Sol! Alinhe o painel."

func verificar_alinhamento():
	# Calcula o tempo que o jogador demorou (em segundos)
	tempo_gasto = (Time.get_ticks_msec() - tempo_inicio_rodada) / 1000.0
	
	var centro_do_sol = sol.position + (sol.size / 2)
	var centro_do_painel = painel.position + (painel.size / 2)
	var direcao_ao_sol = (centro_do_sol - centro_do_painel).angle()
	var angulo_ideal = rad_to_deg(direcao_ao_sol) + 90 
	
	var erro_em_graus = abs(wrapf(painel.rotation_degrees - angulo_ideal, -180.0, 180.0))
	
	# NOVA RECOMPENSA: Perde nota se errou muito o ângulo E se demorou muito!
	# Ex: Penalidade de 5 pontos por segundo demorado.
	var recompensa = 100.0 - (erro_em_graus / 180.0 * 100.0) - (tempo_gasto * 5.0)
	recompensa = clamp(recompensa, 0.0, 100.0) # Garante que não passe de 100 nem de 0
	
	pontuacao_ia += recompensa
	rodadas_treinamento += 1
	
	if rodadas_treinamento < 3: 
		tiko_label.text = "TIKO: Ganho de " + str(round(recompensa)) + "%! A IA está aprendendo. Próximo sol!"
		mudar_posicao_do_sol()
	else:
		iniciar_ia()
	
	print("Rodada: ", rodadas_treinamento, " | Erro: ", round(erro_em_graus), " graus | Ganho: ", round(recompensa), "%")

func iniciar_ia():
	modo_dialogo()
	var media_aprendizado = clamp(round(pontuacao_ia / 3.0), 0.0, 100.0)
	
	# A CURVA EXPONENCIAL:
	# 100% de Nota -> Multiplicador 1.0 -> 500 episódios (Fica Mestre)
	# 50% de Nota  -> Multiplicador 0.125 -> 62 episódios (Fica Manco)
	# 20% de Nota  -> Multiplicador 0.008 -> 4 episódios (Fica Completamente Burra)
	var multiplicador = pow(media_aprendizado / 100.0, 3.0)
	var episodios_de_treino = int(multiplicador * 500)
	
	# Roda o super loop de aprendizado na hora!
	treinar_qlearning(episodios_de_treino)
	
	tiko_label.text = "TIKO: A IA aprendeu com " + str(media_aprendizado) + "% de precisão! Veja ela trabalhando."
	
	var tween = create_tween()
	tween.tween_method(passagem_do_tempo, 20.0, 160.0, 10.0)

func obter_estado(ang_sol: float, ang_painel: float) -> int:
	# Agrupamos as diferenças em "baldes" de 15 graus para a tabela não ficar gigante
	var diff = wrapf(ang_sol - ang_painel, -180.0, 180.0)
	return int(round(diff / 15.0) * 15)

func escolher_acao(estado: int, explorando: bool) -> int:
	var acoes = [-15, 0, 15]
	
	if not q_table.has(estado):
		q_table[estado] = {-15: 0.0, 0: 0.0, 15: 0.0}
		
	# MODO EXPLORAÇÃO (Durante o Treino Interno)
	if explorando and randf() < epsilon:
		return acoes[randi() % acoes.size()]
		
	# MODO PRÁTICA (Valendo)
	var max_q = -INF
	var melhores_acoes = []
	
	for acao in q_table[estado]:
		var valor_q = q_table[estado][acao]
		if valor_q > max_q:
			max_q = valor_q
			melhores_acoes = [acao] # Encontrou um vencedor claro, reseta a lista
		elif valor_q == max_q:
			melhores_acoes.append(acao) # Deu empate (ex: tudo zero), adiciona na lista
			
	# SEGREDO DA IA CONFUSA: Se houver empate (várias ações com nota 0), ela escolhe aleatório!
	# Isso faz o painel "tremer" tentando adivinhar o lado certo.
	if melhores_acoes.has(0):
		return 0
	else:
		return melhores_acoes[0]

func treinar_qlearning(numero_de_episodios: int):
	# Limpa o cérebro antigo se houver
	q_table.clear() 
	
	for i in range(numero_de_episodios):
		var sol_treino = randf_range(20, 160)
		var painel_treino = randf_range(20, 160)
		
		# A IA tenta alinhar em no máximo 15 passos
		for step in range(15): 
			var estado_atual = obter_estado(sol_treino, painel_treino)
			var acao = escolher_acao(estado_atual, true)
			
			var novo_painel = painel_treino + acao
			var novo_estado = obter_estado(sol_treino, novo_painel)
			
			# A PENALIDADE DA IA (Recompensa): 
			# - Abs do erro de ângulo (pune estar longe)
			# - 10 pontos por ter que se mover (pune o tempo gasto para chegar lá)
			var penalidade_erro = abs(novo_estado)
			var penalidade_tempo = 10.0 if acao != 0 else 0.0
			var recompensa = -penalidade_erro - penalidade_tempo
			
			if not q_table.has(novo_estado):
				q_table[novo_estado] = {-15: 0.0, 0: 0.0, 15: 0.0}
				
			# O coração do Q-Learning (A Fórmula de atualização)
			var max_q_novo = -INF
			for val in q_table[novo_estado].values():
				if val > max_q_novo: max_q_novo = val
				
			q_table[estado_atual][acao] = q_table[estado_atual][acao] + alpha * (recompensa + gamma * max_q_novo - q_table[estado_atual][acao])
			
			painel_treino = novo_painel
			
			# Se acertou em cheio, acaba a rodada
			if penalidade_erro == 0:
				break

func passagem_do_tempo(angulo_atual: float):
	# 1. MOVE O SOL SUAVEMENTE
	var radianos = deg_to_rad(angulo_atual)
	var novo_x = centro_x + (cos(radianos) * largura_arco)
	var novo_y = centro_y - (sin(radianos) * altura_arco)
	sol.position = Vector2(novo_x - (sol.size.x / 2), novo_y - (sol.size.y / 2))
	
	# 2. O TRUQUE DA TRANSIÇÃO SUAVE
	# O progresso normal vai de 0.0 (início) a 1.0 (fim)
	var progresso_linear = (angulo_atual - 20.0) / 140.0 
	
	# Usamos pow() para criar uma "curva". Isso faz a cor mudar bem devagar
	# no começo e acelerar no final, simulando um entardecer real!
	var progresso_suave = pow(progresso_linear, 2.5)
	
	# 3. MUDA A COR DO SOL (De Amarelo Brilhante para Laranja Avermelhado)
	sol.modulate = Color(1.0, 1.0, 0.0).lerp(Color(1.0, 0.55, 0.0), progresso_suave)
	
	# 4. MUDA A COR DO CÉU E DA GRAMA
	# O branco (1, 1, 1) mantém a sua imagem original intacta.
	# O segundo tom cria um "filtro" quente que escurece o azul do céu e a grama.
	ceu.modulate = Color(1.0, 1.0, 1.0).lerp(Color(0.15, 0.15, 0.35), progresso_suave)
	
	# 5. MANDA OS PAINÉIS DA IA SEGUIREM O SOL
	alinhar_painel_ia(painel_ia_esq)
	alinhar_painel_ia(painel_ia_dir)

func alinhar_painel_ia(painel_alvo):
	var centro_do_sol = sol.position + (sol.size / 2)
	var centro_do_painel = painel_alvo.position + (painel_alvo.size / 2)
	
	var direcao_ao_sol = (centro_do_sol - centro_do_painel).angle()
	var angulo_sol_graus = rad_to_deg(direcao_ao_sol) + 90
	
	var estado_atual = obter_estado(angulo_sol_graus, painel_alvo.rotation_degrees)
	
	var acao_escolhida = escolher_acao(estado_atual, false)
	
	# Como a IA agora é decidida, aplicamos uma velocidade constante.
	# O multiplicador 0.05 dita o quão rápido o motor do painel gira.
	painel_alvo.rotation_degrees += (acao_escolhida * 0.05)

func tocar_tiko(id: int):
	if falas.has(id):
		# 1. Coloca o texto completo no balão, mas ESCONDE todas as letras
		tiko_label.text = "TIKO: " + falas[id]["texto"]
		tiko_label.visible_ratio = 0.0 
		
		# 2. Carrega o áudio
		audio_player.stream = falas[id]["audio"]
		
		# 3. Descobre exatamente quantos segundos o áudio tem!
		var duracao_audio = audio_player.stream.get_length()
		
		# 4. Cria a animação de digitação sincronizada
		var tween = create_tween()
		# Opcional: Se quiser que o texto termine de digitar um pouquinho 
		# antes da voz acabar, multiplique a duração por 0.9
		var tempo_digitacao = duracao_audio * 0.9 
		
		# Anima o texto de 0.0 (vazio) para 1.0 (completo) no tempo exato da voz
		tween.tween_property(tiko_label, "visible_ratio", 1.0, tempo_digitacao)
		
		# 5. Toca a voz
		audio_player.play()
		
		# 6. Espera a voz terminar completamente antes de liberar o jogo
		await audio_player.finished

func modo_dialogo():
	grupo_botoes.hide()
	balao_fala.show()

func modo_jogo():
	balao_fala.hide()
	grupo_botoes.show()
