class_name AgenteQSolar
extends RefCounted

# ==========================================================
# AGENTE Q-LEARNING DA FASE SOLAR
# Aqui fica SÓ o algoritmo: estado, ações, recompensa, escolha da ação,
# transição para o próximo estado e atualização da tabela Q.
# As regras do jogo (limpeza, nota do jogador, rodadas, animações)
# ficam em fase_solar.gd. O experimento (experimento_solar.gd) usa
# este mesmo arquivo, então o que é testado é exatamente o que roda no jogo.
# ==========================================================

# AÇÕES: girar -15°, ficar parado ou girar +15° (os mesmos passos do jogador)
const ACOES = [-15, 0, 15]
const PASSO_GRAUS = 15.0

# Limites do painel na cena: começa em -20° e gira de 15 em 15 (painel_solar.gd)
const PAINEL_INICIAL = -20.0
const PAINEL_MIN = -80.0
const PAINEL_MAX = 85.0
# Faixa de ângulos em que o sol aparece em relação ao painel
const SOL_MIN = -85.0
const SOL_MAX = 85.0

# Parâmetros do Q-Learning
var alpha: float = 0.2   # Taxa de aprendizado
var gamma: float = 0.9   # Quanto o futuro vale
var epsilon: float = 0.2 # Chance de explorar (ação aleatória) durante o TREINO

# Recompensa
var recompensa_alinhado: float = 100.0 # Chegou no erro 0
var penalidade_movimento: float = 2.0  # Custo de girar (ação diferente de 0)

# Um episódio termina quando alinha (erro 0) ou quando acabam os passos
var max_passos: int = 15

# Tabela Q: { estado: { -15: Q, 0: Q, 15: Q } }. Todo valor começa em 0.
var q_table: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _init():
	rng.randomize()

# ----------------------------------------------------------
# ESTADO: diferença entre o sol e o painel, arredondada de 15 em 15 graus.
# Ex.: +30 = o sol está 30° "à frente" do painel. 0 = alinhado.
# ----------------------------------------------------------
func obter_estado(ang_sol: float, ang_painel: float) -> int:
	var diff = wrapf(ang_sol - ang_painel, -180.0, 180.0)
	return int(round(diff / PASSO_GRAUS) * PASSO_GRAUS)

# O estado 0 é o objetivo (terminal): o episódio acaba ali
func e_terminal(estado: int) -> bool:
	return estado == 0

# Valores Q de um estado. Estado nunca visto começa com tudo em 0.
func valores_q(estado: int) -> Dictionary:
	if not q_table.has(estado):
		q_table[estado] = {-15: 0.0, 0: 0.0, 15: 0.0}
	return q_table[estado]

func maior_q(estado: int) -> float:
	var maior = -INF
	for valor in valores_q(estado).values():
		maior = max(maior, valor)
	return maior

# ----------------------------------------------------------
# ESCOLHA DA AÇÃO (ε-greedy)
# explorar = true  -> treino: com chance ε escolhe uma ação aleatória
# explorar = false -> teste/demonstração: ε = 0, sempre a melhor ação
# EMPATE: no treino sorteia entre as empatadas; no teste prefere ficar parado (0)
# ----------------------------------------------------------
func escolher_acao(estado: int, explorar: bool) -> int:
	if e_terminal(estado):
		return 0 # Já está alinhado

	if explorar and rng.randf() < epsilon:
		return ACOES[rng.randi() % ACOES.size()]

	var q = valores_q(estado)
	var melhor_valor = maior_q(estado)
	var empatadas = []
	for acao in ACOES:
		if q[acao] == melhor_valor:
			empatadas.append(acao)

	if not explorar and empatadas.has(0):
		return 0
	return empatadas[rng.randi() % empatadas.size()]

# ----------------------------------------------------------
# TRANSIÇÃO: aplica a ação no painel. No limite da base o painel não gira.
# ----------------------------------------------------------
func transicao(ang_painel: float, acao: int) -> float:
	var novo = ang_painel + acao
	if novo < PAINEL_MIN or novo > PAINEL_MAX:
		return ang_painel
	return novo

# ----------------------------------------------------------
# RECOMPENSA (calculada com o erro do NOVO estado)
#   +100            se o erro ficou 0 (alinhou)
#   -(erro) - 2     se girou (ação diferente de 0)
#   -(erro)         se ficou parado (ação 0)
# ----------------------------------------------------------
func calcular_recompensa(novo_estado: int, acao: int) -> float:
	if e_terminal(novo_estado):
		return recompensa_alinhado
	var erro = abs(novo_estado)
	if acao != 0:
		return -erro - penalidade_movimento
	return -erro

# ----------------------------------------------------------
# ATUALIZAÇÃO DA TABELA Q
#   Q(s,a) <- Q(s,a) + α · [ r + γ · max Q(s',·) - Q(s,a) ]
# Se s' é terminal (alinhou), não existe futuro: o alvo é só r.
# Devolve os números da conta para mostrar no terminal.
# ----------------------------------------------------------
func atualizar(estado: int, acao: int, recompensa: float, novo_estado: int) -> Dictionary:
	var q_antigo = valores_q(estado)[acao]
	var futuro = 0.0 if e_terminal(novo_estado) else maior_q(novo_estado)
	var alvo = recompensa + gamma * futuro
	var q_novo = q_antigo + alpha * (alvo - q_antigo)
	valores_q(estado)[acao] = q_novo
	return {"q_antigo": q_antigo, "futuro": futuro, "alvo": alvo, "q_novo": q_novo}

# ----------------------------------------------------------
# UM PASSO COMPLETO DO CICLO:
# estado atual -> ação escolhida -> novo estado -> recompensa -> atualiza Q
# ----------------------------------------------------------
func passo(ang_sol: float, ang_painel: float, explorar: bool) -> Dictionary:
	var estado = obter_estado(ang_sol, ang_painel)
	var acao = escolher_acao(estado, explorar)
	var novo_painel = transicao(ang_painel, acao)
	var novo_estado = obter_estado(ang_sol, novo_painel)
	var recompensa = calcular_recompensa(novo_estado, acao)
	atualizar(estado, acao, recompensa, novo_estado)
	return {"painel": novo_painel, "estado": novo_estado, "acao": acao}

# ----------------------------------------------------------
# TREINO: episódios sozinho, explorando (ε-greedy)
# ----------------------------------------------------------
func treinar_episodio():
	var ang_sol = rng.randf_range(SOL_MIN, SOL_MAX)
	var ang_painel = posicao_aleatoria_painel()
	# Começar já alinhado não ensina nada: sorteia de novo
	while e_terminal(obter_estado(ang_sol, ang_painel)):
		ang_painel = posicao_aleatoria_painel()

	for i in range(max_passos):
		var resultado = passo(ang_sol, ang_painel, true)
		ang_painel = resultado["painel"]
		if e_terminal(resultado["estado"]):
			break

func treinar(quantidade_episodios: int):
	for i in range(quantidade_episodios):
		treinar_episodio()

# Posições que o painel pode ter no jogo: -80, -65, ..., 70, 85
func posicao_aleatoria_painel() -> float:
	return PAINEL_INICIAL + PASSO_GRAUS * rng.randi_range(-4, 7)

# ----------------------------------------------------------
# TESTE: ε = 0, sem aprender. Mostra só o que a IA já sabe.
# Para quando alinha, quando decide ficar parada ou quando acabam os passos.
# ----------------------------------------------------------
func testar(ang_sol: float, ang_painel: float) -> Dictionary:
	var movimentos = 0
	for i in range(max_passos):
		var estado = obter_estado(ang_sol, ang_painel)
		if e_terminal(estado):
			break
		var acao = escolher_acao(estado, false)
		if acao == 0:
			break # Decidiu ficar parada sem estar alinhada
		ang_painel = transicao(ang_painel, acao)
		movimentos += 1

	var estado_final = obter_estado(ang_sol, ang_painel)
	return {
		"sucesso": e_terminal(estado_final),
		"erro_graus": abs(wrapf(ang_sol - ang_painel, -180.0, 180.0)),
		"movimentos": movimentos,
	}

# ----------------------------------------------------------
# TABELA Q EM TEXTO (para o terminal do Godot e para o relatório)
# ----------------------------------------------------------
func texto_tabela() -> String:
	if q_table.is_empty():
		return "(tabela vazia: todos os valores Q começam em 0)"
	var estados = q_table.keys()
	estados.sort()
	var linhas = ["estado |    Q(-15) |     Q(0) |   Q(+15) | melhor ação"]
	for estado in estados:
		var q = q_table[estado]
		var melhor = "-" if e_terminal(estado) else _nome_acao(escolher_acao(estado, false))
		linhas.append("%6d | %9.2f | %8.2f | %8.2f | %s" % [estado, q[-15], q[0], q[15], melhor])
	return "\n".join(linhas)

func _nome_acao(acao: int) -> String:
	if acao > 0:
		return "+15"
	return str(acao)
