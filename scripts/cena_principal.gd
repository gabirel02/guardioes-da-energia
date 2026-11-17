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
# --- Variáveis da Pausa ---
@onready var camada_pausa = $CamadaPausa
@onready var btn_pausar = $InterfaceTiko/FundoBarra/BtnPausar
@onready var btn_continuar = $CamadaPausa/PainelPausa/VBoxContainer/BtnContinuar
@onready var btn_ver_dicas = $CamadaPausa/PainelPausa/VBoxContainer/BtnVerDicas
@onready var btn_menu_pausa = $CamadaPausa/PainelPausa/VBoxContainer/BtnMenuPausa

@onready var cortina = $CamadaFade/Cortina
@onready var resumo_fases = $CamadaVitoria/PopUpVitoria/ResumoFases
@onready var vbox_vitoria = $CamadaVitoria/PopUpVitoria/VBoxContainer

var pausado_em_ms: int = 0
var abertura_aberta: bool = false
var revendo_dicas: bool = false # true quando o tutorial foi aberto pelo menu de pausa

var fase_atual_node = null
var estrelas: Array = []
var pontuacao_maxima: int = 100
var tween_fala: Tween
var fala_atual: int = 0 # conta as falas, para saber se uma fala foi interrompida por outra

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
	# "Sair do Jogo" só na versão desktop: no navegador o jogo não pode fechar a aba
	btn_sair.pressed.connect(_on_btn_sair_pressed)
	btn_sair.visible = not OS.has_feature("web")

	# --- LÓGICA DO TUTORIAL ---
	camada_tutorial.hide()
	GameManager.mostrar_tutorial.connect(_abrir_tutorial)
	btn_entendi.pressed.connect(_fechar_tutorial)

	# --- LÓGICA DA PAUSA ---
	camada_pausa.hide()
	btn_pausar.pressed.connect(_pausar)
	btn_continuar.pressed.connect(_continuar)
	btn_ver_dicas.pressed.connect(_ver_dicas_de_novo)
	btn_menu_pausa.pressed.connect(_on_btn_menu_pressed)

	iniciar_flutuacao_tiko()

	# No modo "Vamos jogar!" o Tiko conta a história antes da primeira usina
	if GameManager.modo_continuo and GameManager.fase_inicial_escolhida.ends_with("fase_solar.tscn"):
		var abertura = _criar_abertura()
		_abrir_cortina()
		await _contar_abertura(abertura)
	else:
		_abrir_cortina() # A tela aparece aos poucos

	carregar_fase(GameManager.fase_inicial_escolhida)

func carregar_fase(caminho: String):
	get_tree().paused = false
	camada_vitoria.hide()

	if fase_atual_node != null:
		# Troca de fase suave: escurece, troca e clareia (evita cortes bruscos na tela)
		await _fechar_cortina()
		fase_atual_node.queue_free()
		_abrir_cortina()

	var cena = load(caminho)
	if cena:
		fase_atual_node = cena.instantiate()
		contentor.add_child(fase_atual_node)
		GameManager.fase_inicial_escolhida = caminho

# extras: textos que a voz lê logo depois desta fala (ex: passos do tutorial)
func _fazer_tiko_falar(texto: String, extras: Array = []):
	if tween_fala and tween_fala.is_running():
		tween_fala.kill()
	fala_atual += 1
	var minha_fala = fala_atual
	Audio.falar([texto] + extras)

	painel_balao.show()
	tiko_label.text = texto
	_ajustar_fonte(tiko_label, 32, 22) # Falas longas usam uma letra um pouco menor para caber no balão
	tiko_label.visible_ratio = 0.0
	
	# Presa ao balão: a digitação para junto quando o jogo é pausado
	tween_fala = create_tween().bind_node(tiko_label)
	var tempo_digitacao = texto.length() * 0.05
	tween_fala.tween_property(tiko_label, "visible_ratio", 1.0, tempo_digitacao)
	
	await tween_fala.finished
	# Espera a voz terminar antes de avisar a fase (se outra fala começou, quem avisa é ela)
	while Audio.esta_falando() and minha_fala == fala_atual:
		await get_tree().process_frame
	if minha_fala == fala_atual:
		GameManager.tiko_terminou_falar.emit()

# ==========================================
# ANIMAÇÃO E TELA DE RESULTADOS
# ==========================================
func _ao_vencer_fase():
	get_tree().paused = true
	
	if GameManager.modo_continuo:
		titulo_vitoria.text = "A CIDADE TEM LUZ!"
	else:
		titulo_vitoria.text = "USINA LIGADA!"

	# Com mais de uma fase jogada, mostra os pontos e as estrelas de cada uma
	var com_resumo = GameManager.pontuacoes_fases.size() > 1
	_ajustar_tamanho_popup(com_resumo)
	if com_resumo:
		_montar_resumo_fases()

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

	# Depois das estrelas, o Tiko comenta o resultado
	var fala_estrelas = {3: Audio.FALA_TRES_ESTRELAS, 2: Audio.FALA_DUAS_ESTRELAS, 1: Audio.FALA_UMA_ESTRELA}
	tween_estrelas.tween_callback(func(): Audio.falar_numeros([fala_estrelas[qtd_estrelas]]))

# ==========================================
# ESTRELAS DO POP-UP
# ==========================================
func _criar_estrelas():
	for i in range(3):
		var estrela = _nova_estrela(40.0)
		estrela.position = Vector2(230 + i * 90, 45)
		container_estrelas.add_child(estrela)
		estrelas.append(estrela)

# A estrela é feita de duas camadas: a borda (maior) e o miolo (menor)
func _nova_estrela(raio: float) -> Polygon2D:
	var borda = Polygon2D.new()
	borda.polygon = _pontos_estrela(raio, raio * 0.45)
	var miolo = Polygon2D.new()
	miolo.name = "Miolo"
	miolo.polygon = _pontos_estrela(raio * 0.82, raio * 0.37)
	borda.add_child(miolo)
	return borda

# ==========================================
# RESUMO POR FASE (modo "Vamos jogar!")
# ==========================================
const NOMES_FASES = {"solar": "Usina Solar", "eolica": "Usina do Vento", "hidreletrica": "Usina da Água"}

func _montar_resumo_fases():
	for filho in resumo_fases.get_children():
		filho.queue_free()

	var linha = 0
	for id_fase in NOMES_FASES:
		if not GameManager.pontuacoes_fases.has(id_fase):
			continue
		var pontos = GameManager.pontuacoes_fases[id_fase]

		var texto = Label.new()
		texto.text = NOMES_FASES[id_fase] + ": " + str(int(pontos)) + " pontos"
		texto.position = Vector2(0, linha * 50)
		texto.size = Vector2(380, 44)
		texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		texto.add_theme_font_size_override("font_size", 26)
		texto.add_theme_color_override("font_color", Color(0.05, 0.25, 0.45))
		resumo_fases.add_child(texto)

		var qtd = GameManager.estrelas_para(pontos)
		for i in range(3):
			var estrela = _nova_estrela(18.0)
			estrela.position = Vector2(410 + i * 40, linha * 50 + 22)
			_pintar_estrela(estrela, i < qtd)
			resumo_fases.add_child(estrela)
		linha += 1

# No modo "Vamos jogar!" o pop-up cresce para caber o resumo das 3 fases
func _ajustar_tamanho_popup(com_resumo: bool):
	resumo_fases.visible = com_resumo
	var meia_altura = 340.0 if com_resumo else 275.0
	# Na web só há o botão Voltar ao Menu: o pop-up fica 100 px mais baixo
	if not btn_sair.visible:
		meia_altura -= 50.0
	popup_vitoria.offset_top = -meia_altura
	popup_vitoria.offset_bottom = meia_altura
	var topo_botoes = 455.0 if com_resumo else 320.0
	vbox_vitoria.position.y = topo_botoes

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
# ABERTURA: a história que liga as 3 usinas
# Quadros curtos com o Tiko grande e um botão para avançar.
# ==========================================
const QUADROS_ABERTURA = [
	"Olá! Eu sou o Tiko, seu amigo robô! Precisamos da sua ajuda! Nossa cidade ficou sem energia!",
	"As três usinas de energia pararam de funcionar! E agora? Como vamos iluminar a cidade?",
	"Vamos trabalhar juntos para ligar as três usinas: a do sol, a do vento e a da água!",
	"E temos um ajudante especial: o robô aprendiz! Ele vai aprender com você! Preparado para essa aventura?"
]

const COR_TEXTO_ESCURO = Color(0.05, 0.25, 0.45)

func _criar_abertura() -> Dictionary:
	abertura_aberta = true
	var camada = CanvasLayer.new()
	camada.layer = 4
	add_child(camada)

	var fundo = ColorRect.new()
	fundo.color = COR_TEXTO_ESCURO
	fundo.size = Vector2(1280, 1000)
	camada.add_child(fundo)

	# Mesmo painel branco de borda azul do tutorial
	var painel = Panel.new()
	painel.position = Vector2(140, 170)
	painel.size = Vector2(1000, 640)
	painel.add_theme_stylebox_override("panel", $CamadaTutorial/PainelTutorial.get_theme_stylebox("panel"))
	camada.add_child(painel)

	var tiko = TextureRect.new()
	tiko.texture = imagem_tiko.texture
	tiko.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tiko.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tiko.position = Vector2(400, 30)
	tiko.size = Vector2(200, 200)
	painel.add_child(tiko)
	var flutuar = create_tween().bind_node(tiko).set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flutuar.tween_property(tiko, "position:y", 20.0, 1.5)
	flutuar.tween_property(tiko, "position:y", 40.0, 1.5)

	var texto = Label.new()
	texto.position = Vector2(40, 250)
	texto.size = Vector2(920, 200)
	texto.add_theme_font_size_override("font_size", 40)
	texto.add_theme_color_override("font_color", COR_TEXTO_ESCURO)
	texto.add_theme_constant_override("line_spacing", 10)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	painel.add_child(texto)

	# "1 de 4": mostra quanto falta da história
	var contador = Label.new()
	contador.position = Vector2(0, 460)
	contador.size = Vector2(1000, 36)
	contador.add_theme_font_size_override("font_size", 22)
	contador.add_theme_color_override("font_color", Color(0.3, 0.45, 0.6))
	contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	painel.add_child(contador)

	# Botão verde, igual ao "Entendi!" do tutorial
	var botao = Button.new()
	botao.position = Vector2(340, 520)
	botao.size = Vector2(320, 84)
	botao.add_theme_font_size_override("font_size", 40)
	for estado in ["normal", "hover", "pressed"]:
		botao.add_theme_stylebox_override(estado, btn_entendi.get_theme_stylebox(estado))
	botao.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for cor in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		botao.add_theme_color_override(cor, Color(1, 1, 1))
	painel.add_child(botao)

	return {"camada": camada, "texto": texto, "contador": contador, "botao": botao}

func _contar_abertura(abertura: Dictionary):
	var texto: Label = abertura["texto"]
	var botao: Button = abertura["botao"]
	var total = QUADROS_ABERTURA.size()
	for i in range(total):
		texto.text = QUADROS_ABERTURA[i]
		Audio.falar([texto.text])
		_ajustar_fonte(texto, 40, 30)
		abertura["contador"].text = str(i + 1) + " de " + str(total)
		botao.text = "Vamos lá!" if i == total - 1 else "Continuar"
		botao.grab_focus() # Enter ou Espaço também avançam

		# O texto aparece aos poucos, como no balão do Tiko
		texto.visible_ratio = 0.0
		create_tween().bind_node(texto).tween_property(texto, "visible_ratio", 1.0, texto.text.length() * 0.03)
		await botao.pressed

	Audio.parar_voz()
	await _fechar_cortina()
	abertura["camada"].queue_free()
	abertura_aberta = false
	_abrir_cortina()

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
	# O Tiko fala a introdução e depois lê cada passo em voz alta
	if not revendo_dicas:
		_fazer_tiko_falar("Antes de começar, vou mostrar como jogar! Preste atenção nas dicas!", passos)
	else:
		Audio.falar(passos)

# Começa com fonte 28 e diminui até o texto caber na caixa (nunca menor que 20)
func _ajustar_fonte_tutorial():
	_ajustar_fonte(passos_tutorial, 28, 20)

# Diminui a fonte do maior para o menor tamanho até o texto caber na altura do Label.
# A altura é medida direto na fonte (o Label só recalcula as linhas depois, na hora de desenhar).
func _ajustar_fonte(label: Label, maior: int, menor: int):
	var fonte = label.get_theme_font("font")
	var espacamento = label.get_theme_constant("line_spacing")
	var tamanho_final = menor
	for tamanho in range(maior, menor - 1, -1):
		var altura_linha = fonte.get_height(tamanho)
		var altura_bruta = fonte.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, label.size.x, tamanho).y
		var linhas = round(altura_bruta / altura_linha)
		if linhas * (altura_linha + espacamento) <= label.size.y:
			tamanho_final = tamanho
			break
	label.add_theme_font_size_override("font_size", tamanho_final)

func _fechar_tutorial():
	camada_tutorial.hide()
	Audio.parar_voz() # Parou de ler as dicas
	if revendo_dicas:
		# Veio do menu de pausa: volta para ele em vez de avisar a fase
		revendo_dicas = false
		camada_pausa.show()
		return
	GameManager.tutorial_fechado.emit()

# ==========================================
# PAUSA
# ==========================================
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if camada_pausa.visible:
			_continuar()
		elif revendo_dicas:
			_fechar_tutorial()
		else:
			_pausar()

func _pausar():
	# Não pausa em cima do pop-up de vitória (lá o jogo já está parado) nem durante a abertura
	if camada_vitoria.visible or get_tree().paused or abertura_aberta:
		return
	get_tree().paused = true
	pausado_em_ms = Time.get_ticks_msec()
	Audio.pausar_voz(true)
	camada_pausa.show()

func _continuar():
	camada_pausa.hide()
	get_tree().paused = false
	Audio.pausar_voz(false)
	# Avisa as fases quanto tempo ficou pausado (a Solar desconta do cronômetro)
	GameManager.pausa_terminou.emit(Time.get_ticks_msec() - pausado_em_ms)

func _ver_dicas_de_novo():
	# Se o tutorial do começo da fase ainda está aberto, é só voltar para ele
	if camada_tutorial.visible:
		_continuar()
		return
	if GameManager.tutorial_atual.is_empty():
		return
	revendo_dicas = true
	camada_pausa.hide()
	_abrir_tutorial(GameManager.tutorial_atual["titulo"], GameManager.tutorial_atual["passos"])

func _animar_pontuacao(valor_atual: int):
	label_pontuacao.text = "Você fez " + str(valor_atual) + " de " + str(pontuacao_maxima) + " pontos!"

func _on_btn_menu_pressed():
	Audio.parar_voz()
	await _fechar_cortina()
	get_tree().paused = false
	GameManager.zerar_pontuacao()
	get_tree().change_scene_to_file("res://cenas/cena_inicial.tscn")

# ==========================================
# TRANSIÇÃO (FADE)
# A "cortina" é um retângulo azul-escuro por cima de tudo.
# Ela funciona mesmo com o jogo pausado (ex: voltar ao menu pela pausa).
# ==========================================
const DURACAO_FADE = 0.4

func _fechar_cortina():
	cortina.mouse_filter = Control.MOUSE_FILTER_STOP # Bloqueia cliques durante a troca
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(cortina, "color:a", 1.0, DURACAO_FADE)
	await tween.finished

func _abrir_cortina():
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(cortina, "color:a", 0.0, DURACAO_FADE)
	await tween.finished
	cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_btn_sair_pressed():
	get_tree().quit()

func iniciar_flutuacao_tiko():
	var tween_flutuar = create_tween().bind_node(imagem_tiko).set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Agora pegamos o position.y diretamente da imagem
	var posicao_original_y = imagem_tiko.position.y
	
	tween_flutuar.tween_property(imagem_tiko, "position:y", posicao_original_y - 10, 1.5)
	tween_flutuar.tween_property(imagem_tiko, "position:y", posicao_original_y + 10, 1.5)
	tween_flutuar.tween_property(imagem_tiko, "position:y", posicao_original_y, 1.5)
