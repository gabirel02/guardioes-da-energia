extends Node

# ==========================================================
# EXPERIMENTO DA IA DA FASE SOLAR (não faz parte do jogo)
# Abra cenas/experimento_solar.tscn e aperte F6. O resultado aparece
# no terminal (Saída) e é salvo em docs/experimento_solar_*.
#
# Para cada quantidade de episódios, treina 30 IAs DO ZERO (execuções)
# e testa cada uma com ε = 0 em posições do sol que ela não viu no treino.
# Usa o MESMO agente do jogo (agente_q_solar.gd), sem o jogador.
# ==========================================================

const EPISODIOS = [0, 30, 50, 100, 150, 200, 250]
const EXECUCOES = 30
const TESTES_POR_EXECUCAO = 100
const PENALIDADES = [0.0, 2.0, 5.0, 10.0]
const EPISODIOS_TESTE_PENALIDADE = 100

var casos_de_teste: Array = []
var relatorio: PackedStringArray = []

func _ready():
	gerar_casos_de_teste()

	escrever("EXPERIMENTO Q-LEARNING - FASE SOLAR")
	escrever("α = 0.2 | γ = 0.9 | ε = 0.2 (treino), 0 (teste) | máx. %d passos por episódio" % AgenteQSolar.new().max_passos)
	escrever("%d execuções por linha | %d posições de teste por execução\n" % [EXECUCOES, TESTES_POR_EXECUCAO])

	# 1. QUANTIDADE DE EPISÓDIOS
	var csv = ["episodios,execucoes,taxa_sucesso_media,desvio_taxa,erro_medio_graus,movimentos_medios,movimentos_minimos_medios"]
	escrever("TABELA 1 - Quantidade de episódios (penalidade de movimento = 2)")
	escrever("episódios | execuções | taxa de sucesso | erro médio | movimentos médios | mínimo possível")
	for n in EPISODIOS:
		var r = rodar_configuracao(n, 2.0)
		escrever("%9d | %9d | %6.1f%% ± %4.1f | %8.2f° | %17.2f | %15.2f" % [n, EXECUCOES, r["taxa"], r["desvio"], r["erro"], r["movimentos"], r["minimos"]])
		csv.append("%d,%d,%.2f,%.2f,%.2f,%.2f,%.2f" % [n, EXECUCOES, r["taxa"], r["desvio"], r["erro"], r["movimentos"], r["minimos"]])
	salvar("res://docs/experimento_solar_episodios.csv", "\n".join(csv))

	# 2. PENALIDADE DE MOVIMENTO (por que 2? por que não 10?)
	csv = ["penalidade,episodios,execucoes,taxa_sucesso_media,desvio_taxa,erro_medio_graus,movimentos_medios,movimentos_minimos_medios"]
	escrever("\nTABELA 2 - Penalidade por girar (%d episódios)" % EPISODIOS_TESTE_PENALIDADE)
	escrever("penalidade | taxa de sucesso | erro médio | movimentos médios | mínimo possível")
	for pen in PENALIDADES:
		var r = rodar_configuracao(EPISODIOS_TESTE_PENALIDADE, pen)
		escrever("%10.0f | %6.1f%% ± %4.1f | %8.2f° | %17.2f | %15.2f" % [pen, r["taxa"], r["desvio"], r["erro"], r["movimentos"], r["minimos"]])
		csv.append("%.0f,%d,%d,%.2f,%.2f,%.2f,%.2f,%.2f" % [pen, EPISODIOS_TESTE_PENALIDADE, EXECUCOES, r["taxa"], r["desvio"], r["erro"], r["movimentos"], r["minimos"]])
	salvar("res://docs/experimento_solar_penalidade.csv", "\n".join(csv))

	# 3. ACOMPANHANDO A TABELA Q de uma IA durante o treino
	escrever("\nTABELA 3 - Evolução da tabela Q de uma IA (semente fixa)")
	var agente = AgenteQSolar.new()
	agente.rng.seed = 42
	var treinados = 0
	for n in EPISODIOS:
		agente.treinar(n - treinados)
		treinados = n
		escrever("\n--- Depois de %d episódios ---" % n)
		escrever(agente.texto_tabela())

	salvar("res://docs/experimento_solar_resultados.txt", "\n".join(relatorio))
	get_tree().quit()

# Posições de teste fixas (semente própria), iguais para todas as configurações.
# O sol é um número real sorteado: nunca é exatamente uma posição do treino.
func gerar_casos_de_teste():
	var rng = RandomNumberGenerator.new()
	rng.seed = 2024
	var auxiliar = AgenteQSolar.new()
	while casos_de_teste.size() < TESTES_POR_EXECUCAO:
		var sol = rng.randf_range(AgenteQSolar.SOL_MIN, AgenteQSolar.SOL_MAX)
		var painel = AgenteQSolar.PAINEL_INICIAL + AgenteQSolar.PASSO_GRAUS * rng.randi_range(-4, 7)
		var estado = auxiliar.obter_estado(sol, painel)
		if auxiliar.e_terminal(estado):
			continue # Já começaria alinhado
		casos_de_teste.append({"sol": sol, "painel": painel, "minimo": abs(estado) / 15})

func rodar_configuracao(episodios: int, penalidade: float) -> Dictionary:
	var taxas = []
	var soma_erro = 0.0
	var soma_mov = 0.0
	var soma_min = 0.0
	for execucao in range(EXECUCOES):
		var agente = AgenteQSolar.new()
		agente.rng.seed = 1000 + execucao # Reproduzível: mesma execução, mesmo resultado
		agente.penalidade_movimento = penalidade
		agente.treinar(episodios)

		var sucessos = 0
		for caso in casos_de_teste:
			var t = agente.testar(caso["sol"], caso["painel"])
			if t["sucesso"]:
				sucessos += 1
			soma_erro += t["erro_graus"]
			soma_mov += t["movimentos"]
			soma_min += caso["minimo"]
		taxas.append(100.0 * sucessos / casos_de_teste.size())

	var total = float(EXECUCOES * casos_de_teste.size())
	var media = 0.0
	for t in taxas:
		media += t
	media /= taxas.size()
	var variancia = 0.0
	for t in taxas:
		variancia += pow(t - media, 2)
	return {
		"taxa": media,
		"desvio": sqrt(variancia / taxas.size()),
		"erro": soma_erro / total,
		"movimentos": soma_mov / total,
		"minimos": soma_min / total,
	}

func escrever(texto: String):
	print(texto)
	relatorio.append(texto)

func salvar(caminho: String, conteudo: String):
	var arquivo = FileAccess.open(caminho, FileAccess.WRITE)
	if arquivo == null:
		push_warning("Não consegui salvar " + caminho)
		return
	arquivo.store_string(conteudo)
