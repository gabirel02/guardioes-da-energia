extends Node

@onready var contentor = $ContentorDeFase
@onready var tiko_label = $InterfaceTiko/FundoBarra/BalaoFala/Label
@onready var painel_balao = $InterfaceTiko/FundoBarra/BalaoFala
@onready var imagem_tiko = $InterfaceTiko/FundoBarra/Tiko
# --- Variáveis do Pop-up de Vitória ---
@onready var camada_vitoria = $CamadaVitoria
@onready var popup_vitoria = $CamadaVitoria/PopUpVitoria # NOVA VARIÁVEL ADICIONADA
@onready var titulo_vitoria = $CamadaVitoria/PopUpVitoria/Titulo
@onready var label_pontuacao = $CamadaVitoria/PopUpVitoria/LabelPontuacao
@onready var btn_menu = $CamadaVitoria/PopUpVitoria/VBoxContainer/BtnMenu
@onready var btn_sair = $CamadaVitoria/PopUpVitoria/VBoxContainer/BtnSair
# --- Variáveis do Tutorial ---
@onready var camada_tutorial = $CamadaTutorial
@onready var titulo_tutorial = $CamadaTutorial/PainelTutorial/Titulo
@onready var passos_tutorial = $CamadaTutorial/PainelTutorial/Passos
@onready var btn_entendi = $CamadaTutorial/PainelTutorial/BtnEntendi

@onready var container_estrelas = $CamadaVitoria/PopUpVitoria/Estrelas

var fase_atual_node = null
var estrelas: Array = []
var pontuacao_maxima: int = 100
var tween_fala: Tween 

func _ready():
	# --- LÓGICA DO TIKO ---
	GameManager.tiko_diz.connect(_fazer_tiko_falar)
	GameManager.pedir_nova_fase.connect(carregar_fase)
	GameManager.mostrar_balao.connect(func(): painel_balao.show())
	GameManager.esconder_balao.connect(func(): painel_balao.hide())
	
	# --- LÓGICA DA VITÓRIA ---
	camada_vitoria.hide()
	camada_vitoria.process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.mostrar_vitoria.connect(_ao_vencer_fase)
	_criar_estrelas()
	
	# CORREÇÃO 1: Só conecta via código se já não estiver conectado pelo painel do Godot
	if not btn_menu.pressed.is_connected(_on_btn_menu_pressed):
		btn_menu.pressed.connect(_on_btn_menu_pressed)
	if not btn_sair.pressed.is_connected(_on_btn_sair_pressed):
		btn_sair.pressed.connect(_on_btn_sair_pressed)

	# --- LÓGICA DO TUTORIAL ---
	camada_tutorial.hide()
	GameManager.mostrar_tutorial.connect(_abrir_tutorial)
	btn_entendi.pressed.connect(_fechar_tutorial)

	carregar_fase(GameManager.fase_inicial_escolhida)
	iniciar_flutuacao_tiko()

func carregar_fase(caminho: String):
	get_tree().paused = false 
	camada_vitoria.hide() 
	
	if fase_atual_node != null:
		fase_atual_node.queue_free()
		
	var cena = load(caminho)
	if cena:
		fase_atual_node = cena.instantiate()
		contentor.add_child(fase_atual_node)
		GameManager.fase_inicial_escolhida = caminho

func _fazer_tiko_falar(texto: String):
	if tween_fala and tween_fala.is_running():
		tween_fala.kill() 
		
	painel_balao.show()
	tiko_label.text = texto
	tiko_label.visible_ratio = 0.0
	
	tween_fala = create_tween()
	var tempo_digitacao = texto.length() * 0.05
	tween_fala.tween_property(tiko_label, "visible_ratio", 1.0, tempo_digitacao)
	
	await tween_fala.finished
	GameManager.tiko_terminou_falar.emit()

# ==========================================
# ANIMAÇÃO E TELA DE RESULTADOS
# ==========================================
func _ao_vencer_fase():
	get_tree().paused = true
	
	if GameManager.modo_continuo:
		titulo_vitoria.text = "JOGO CONCLUÍDO!"
	else:
		titulo_vitoria.text = "FASE CONCLUÍDA!"
		
	camada_vitoria.show()
	
	# Deixamos o pop-up invisível para o fade-in
	popup_vitoria.modulate.a = 0.0
	
	# Adicionamos o set_pause_mode para a animação rodar mesmo com o jogo pausado!
	var tween_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_fade.tween_property(popup_vitoria, "modulate:a", 1.0, 0.5)
	
	var total = round(GameManager.energia_total_acumulada)
	pontuacao_maxima = GameManager.pontuacao_maxima()

	# Fazemos o mesmo para a animação dos números
	var tween_pontos = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_pontos.tween_method(_animar_pontuacao, 0, int(total), 1.5)

	# Estrelas aparecem uma de cada vez, depois que os números terminam de subir
	var qtd_estrelas = GameManager.calcular_estrelas()
	var tween_estrelas = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_estrelas.tween_interval(1.5)
	for i in range(estrelas.size()):
		var estrela = estrelas[i]
		_pintar_estrela(estrela, i < qtd_estrelas)
		estrela.scale = Vector2.ZERO
		tween_estrelas.tween_property(estrela, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ==========================================
# ESTRELAS DO POP-UP
# ==========================================
func _criar_estrelas():
	for i in range(3):
		# A estrela é feita de duas camadas: a borda (maior) e o miolo (menor)
		var borda = Polygon2D.new()
		borda.polygon = _pontos_estrela(40.0, 18.0)
		var miolo = Polygon2D.new()
		miolo.name = "Miolo"
		miolo.polygon = _pontos_estrela(33.0, 15.0)
		borda.add_child(miolo)

		borda.position = Vector2(230 + i * 90, 45)
		container_estrelas.add_child(borda)
		estrelas.append(borda)

func _pontos_estrela(raio_externo: float, raio_interno: float) -> PackedVector2Array:
	var pontos = PackedVector2Array()
	for i in range(10):
		var raio = raio_externo if i % 2 == 0 else raio_interno
		var angulo = deg_to_rad(-90 + i * 36)
		pontos.append(Vector2(cos(angulo), sin(angulo)) * raio)
	return pontos

func _pintar_estrela(estrela: Polygon2D, ganhou: bool):
	if ganhou:
		estrela.color = Color(0.85, 0.55, 0.0)                    # Borda dourada
		estrela.get_node("Miolo").color = Color(1.0, 0.82, 0.1)   # Amarelo
	else:
		estrela.color = Color(0.6, 0.6, 0.6)                      # Borda cinza
		estrela.get_node("Miolo").color = Color(0.88, 0.88, 0.88) # Cinza claro

# ==========================================
# TUTORIAL DAS FASES
# ==========================================
func _abrir_tutorial(titulo: String, passos: Array):
	titulo_tutorial.text = titulo

	# Numera os passos para ficar fácil de acompanhar
	var texto = ""
	for i in range(passos.size()):
		texto += str(i + 1) + ". " + passos[i]
		if i < passos.size() - 1:
			texto += "\n"
	passos_tutorial.text = texto

	camada_tutorial.show()
	_ajustar_fonte_tutorial()
	_fazer_tiko_falar("Antes de começar, veja como jogar!")

# Começa com fonte 28 e diminui até o texto caber na caixa (nunca menor que 20)
func _ajustar_fonte_tutorial():
	var espacamento = passos_tutorial.get_theme_constant("line_spacing")
	for tamanho in range(28, 19, -1):
		passos_tutorial.add_theme_font_size_override("font_size", tamanho)
		var altura_texto = passos_tutorial.get_line_count() * (passos_tutorial.get_line_height() + espacamento)
		if altura_texto <= passos_tutorial.size.y:
			break

func _fechar_tutorial():
	camada_tutorial.hide()
	GameManager.tutorial_fechado.emit()

func _animar_pontuacao(valor_atual: int):
	label_pontuacao.text = "Você fez " + str(valor_atual) + " de " + str(pontuacao_maxima) + " pontos!"

func _on_btn_menu_pressed():
	get_tree().paused = false
	GameManager.zerar_pontuacao()
	get_tree().change_scene_to_file("res://cenas/cena_inicial.tscn")

func _on_btn_sair_pressed():
	get_tree().quit()
	
func iniciar_flutuacao_tiko():
	var tween_flutuar = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Agora pegamos o position.y diretamente da imagem
	var posicao_original_y = imagem_tiko.position.y
	
	tween_flutuar.tween_property(imagem_tiko, "position:y", posicao_original_y - 10, 1.5)
	tween_flutuar.tween_property(imagem_tiko, "position:y", posicao_original_y + 10, 1.5)
	tween_flutuar.tween_property(imagem_tiko, "position:y", posicao_original_y, 1.5)
