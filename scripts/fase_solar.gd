extends Node2D

var sujeiras_restantes = 5 
var acertos_treinamento = 0

@onready var botao_esq = $BotaoEsquerda
@onready var botao_dir = $BotaoDireito
@onready var sol = $Sol
@onready var painel = $PainelSolar

# Lembre-se de adicionar o botão Confirmar na tela depois!
# @onready var botao_confirmar = $BotaoConfirmar 

func _ready():
	# Esconde os botões no início
	botao_esq.hide()
	botao_dir.hide()
	# botao_confirmar.hide()

func sujeira_removida():
	sujeiras_restantes -= 1
	if sujeiras_restantes <= 0:
		iniciar_fase_alinhamento()

func iniciar_fase_alinhamento():
	# Mostra os botões de girar
	botao_esq.show()
	botao_dir.show()
	# botao_confirmar.show()
	
	# Coloca o sol em um lugar aleatório para começar o treino
	mudar_posicao_do_sol()

func mudar_posicao_do_sol():
	# Move o Sol para uma nova posição no céu
	var novo_x = randf_range(100, 1100)
	var novo_y = randf_range(50, 250)
	sol.position = Vector2(novo_x, novo_y)
	print("Nova posição do Sol! Alinhe o painel.")

func verificar_alinhamento():
	# Calcula para onde o painel deve apontar
	var direcao_ao_sol = (sol.position - painel.position).angle()
	var angulo_em_graus = rad_to_deg(direcao_ao_sol) + 90 
	
	# Verifica se a rotação do painel está próxima ao que precisamos
	if abs(painel.rotation_degrees - angulo_em_graus) < 15:
		acertos_treinamento += 1
		print("Acertou! Lição: ", acertos_treinamento)
		
		if acertos_treinamento < 3:
			mudar_posicao_do_sol()
		else:
			iniciar_ia()
	else:
		print("Quase lá! Ajuste mais um pouco.")

func iniciar_ia():
	botao_esq.hide()
	botao_dir.hide()
	# botao_confirmar.hide()
	print("Treinamento concluído! A IA assumiu o controle.")
