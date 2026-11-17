extends Node

var energia_total_acumulada: float = 0.0
# Pontos de cada fase terminada nesta partida (ex: {"solar": 85})
var pontuacoes_fases: Dictionary = {}
# Toda a energia gerada desde que o jogo foi aberto (aparece no menu em "Energia:").
# Não é zerada ao voltar ao menu, só quando o jogo é fechado.
var energia_sessao: float = 0.0
var fase_inicial_escolhida: String = "res://cenas/fase_solar.tscn"
var modo_continuo: bool = false
# Guarda quais tutoriais já apareceram (volta a zerar quando o jogador vai ao menu)
var tutoriais_vistos: Dictionary = {}
# Tutorial da fase que está sendo jogada, para o botão "Ver dicas" da pausa
var tutorial_atual: Dictionary = {}
@warning_ignore("unused_signal")
signal tiko_diz(texto: String)
@warning_ignore("unused_signal")
signal tiko_terminou_falar()
@warning_ignore("unused_signal")
signal mostrar_balao()
@warning_ignore("unused_signal")
signal esconder_balao()
@warning_ignore("unused_signal")
signal pedir_nova_fase(caminho_da_cena: String)
@warning_ignore("unused_signal")
signal mostrar_vitoria()
@warning_ignore("unused_signal")
signal mostrar_tutorial(titulo: String, passos: Array)
@warning_ignore("unused_signal")
signal tutorial_fechado()
# Avisa quanto tempo (em milissegundos) o jogo ficou pausado, para as fases descontarem do cronômetro
@warning_ignore("unused_signal")
signal pausa_terminou(duracao_ms: int)

# ==========================================
# MEMÓRIA DA IA
# O que as IAs aprendem fica guardado aqui, na memória do jogo.
# Como o GameManager é um Autoload, ele não é apagado ao trocar de cena:
# as IAs continuam aprendendo entre tentativas e entre fases enquanto o jogo
# estiver aberto. Ao fechar o jogo, tudo é apagado (nada é salvo em arquivo,
# o que também funciona no executável para navegador).
# ==========================================
var memoria_ia: Dictionary = {}

# Devolve a memória de uma IA. Se ela ainda não existe, cria com o valor inicial.
# Dicionários são passados por referência: o que a fase alterar já fica guardado aqui.
func obter_memoria_ia(chave: String, valor_inicial):
	if not memoria_ia.has(chave):
		memoria_ia[chave] = valor_inicial
	return memoria_ia[chave]

func guardar_memoria_ia(chave: String, valor):
	memoria_ia[chave] = valor

# Faz as IAs começarem do zero (útil para apresentar o jogo)
func apagar_memoria_ia():
	memoria_ia.clear()

# ==========================================
# PONTUAÇÃO (cada fase vale de 0 a 100)
# ==========================================
func registrar_pontuacao(id_fase: String, pontos: float):
	pontuacoes_fases[id_fase] = clamp(round(pontos), 0.0, 100.0)
	energia_sessao += pontuacoes_fases[id_fase]

	# O total é a soma das fases jogadas nesta partida
	energia_total_acumulada = 0.0
	for p in pontuacoes_fases.values():
		energia_total_acumulada += p

# Pontuação máxima possível com as fases jogadas (100 por fase)
func pontuacao_maxima() -> int:
	return max(1, pontuacoes_fases.size()) * 100

# 3 estrelas: média de 80 ou mais | 2 estrelas: 50 ou mais | 1 estrela: terminou a fase
func calcular_estrelas() -> int:
	if pontuacoes_fases.is_empty():
		return 1
	return estrelas_para(energia_total_acumulada / pontuacoes_fases.size())

# Estrelas de uma nota de 0 a 100 (usado também no resumo de cada fase)
func estrelas_para(nota: float) -> int:
	if nota >= 80.0:
		return 3
	elif nota >= 50.0:
		return 2
	return 1

func zerar_pontuacao():
	energia_total_acumulada = 0.0
	pontuacoes_fases.clear()

# Mostra o tutorial da fase só na primeira vez e espera o jogador clicar em "Entendi".
# Devolve true se o tutorial apareceu, false se ele já tinha sido visto (ex: recomeço após perder).
func exibir_tutorial(id_fase: String, titulo: String, passos: Array) -> bool:
	tutorial_atual = {"titulo": titulo, "passos": passos}
	if tutoriais_vistos.has(id_fase):
		return false
	tutoriais_vistos[id_fase] = true
	mostrar_tutorial.emit(titulo, passos)
	await tutorial_fechado
	return true
