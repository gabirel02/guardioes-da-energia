extends Node2D

@onready var camada_ajuda = $CamadaAjuda
@onready var texto_energia = $TextoEnergia
@onready var fundo_mudo = $CamadaBotoes/BotaoSom/FundoMudo
@onready var texto_mudo = $CamadaBotoes/BotaoSom/TextoMudo
@onready var painel_volume = $CamadaBotoes/PainelVolume
@onready var slider_volume = $CamadaBotoes/PainelVolume/SliderVolume
@onready var camada_creditos = $CamadaCreditos

# Logo oficial da UTFPR (exigido pelo COAPI na tela inicial). Basta colocar o arquivo neste caminho.
const CAMINHO_LOGO_UTFPR = "res://assets/logos/logo_utfpr.png"

var cortina: ColorRect

func _ready():
	# Ao voltar para o menu, os tutoriais aparecem de novo na próxima partida
	GameManager.tutoriais_vistos.clear()
	GameManager.zerar_pontuacao()

	# "Energia:" mostra toda a energia gerada desde que o jogo foi aberto
	texto_energia.text = str(int(GameManager.energia_sessao))

	camada_ajuda.hide()
	camada_creditos.hide()
	_ajustar_botoes_para_web()
	_carregar_logo_utfpr()
	_atualizar_botao_som()
	_criar_cortina()
	_abrir_cortina()
	Audio.falar_numeros([Audio.FALA_MENU]) # "Olá, Guardião! ..."

# --- BOTÃO "SOM" (canto superior esquerdo, ao lado de Ajuda) ---
# Abre/fecha um painel com uma barra de volume, parecido com o mixer de som do Windows
func _on_botao_som_pressed():
	if painel_volume.visible:
		painel_volume.hide()
		return
	slider_volume.value = Audio.volume_geral * 100.0
	painel_volume.show()

func _on_slider_volume_value_changed(valor: float):
	Audio.definir_volume(valor / 100.0)
	_atualizar_botao_som()

# Clicar fora do painel de volume fecha o painel.
# O clique continua valendo para o que estiver embaixo (ex: clicar em uma usina já abre a fase).
func _input(event):
	if not painel_volume.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		var no_painel = painel_volume.get_global_rect().has_point(event.position)
		var no_botao = $CamadaBotoes/BotaoSom.get_global_rect().has_point(event.position) # o botão já abre/fecha sozinho
		if not no_painel and not no_botao:
			painel_volume.hide()

func _atualizar_botao_som():
	fundo_mudo.visible = not Audio.som_ligado
	texto_mudo.visible = not Audio.som_ligado

# --- BOTÃO "VAMOS JOGAR!" (modo contínuo, começa pela Solar) ---
func _on_botao_jogar_pressed():
	GameManager.modo_continuo = true
	iniciar_jogo("res://cenas/fase_solar.tscn")

# --- ÍCONES DE CADA FASE (vai direto só para aquela fase) ---
func _on_btn_solar_pressed():
	GameManager.modo_continuo = false
	iniciar_jogo("res://cenas/fase_solar.tscn")

func _on_btn_eolica_pressed():
	GameManager.modo_continuo = false
	iniciar_jogo("res://cenas/fase_eolica.tscn")

func _on_btn_hidro_pressed():
	GameManager.modo_continuo = false
	iniciar_jogo("res://cenas/fase_hidreletrica.tscn")

# --- BOTÃO "AJUDA" (canto superior esquerdo) ---
func _on_botao_ajuda_pressed():
	painel_volume.hide()
	camada_ajuda.show()

func _on_btn_fechar_ajuda_pressed():
	camada_ajuda.hide()

# --- BOTÃO "SAIR" (canto superior direito, desenhado na imagem de fundo) ---
# Só existe na versão desktop: no navegador o jogo não pode fechar a aba.
func _on_botao_sair_pressed():
	get_tree().quit()

# Na versão web, esconde o Sair e coloca o botão Créditos em cima do "Sair" desenhado no fundo
func _ajustar_botoes_para_web():
	if not OS.has_feature("web"):
		return
	var botao_creditos = $CamadaBotoes/BotaoCreditos
	$CamadaBotoes/BotaoSair.hide()
	botao_creditos.position = Vector2(1128, 20)
	botao_creditos.size = Vector2(144, 94)
	botao_creditos.add_theme_font_size_override("font_size", 25)

# --- BOTÃO "CRÉDITOS" (abaixo do botão Sair; na web, no lugar dele) ---
func _on_botao_creditos_pressed():
	painel_volume.hide()
	camada_creditos.show()

func _on_btn_fechar_creditos_pressed():
	camada_creditos.hide()

# Coloca o logo da UTFPR no menu e nos créditos.
# Enquanto o arquivo não existir, aparece o texto "LOGO UTFPR" no lugar.
func _carregar_logo_utfpr():
	if not ResourceLoader.exists(CAMINHO_LOGO_UTFPR):
		return
	var logo = load(CAMINHO_LOGO_UTFPR)
	for caixa in [$LogoMenu, $CamadaCreditos/PainelCreditos/LogoUTFPR]:
		caixa.get_node("Imagem").texture = logo
		caixa.get_node("Provisorio").hide()

# Esc também fecha a ajuda e os créditos
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		camada_ajuda.hide()
		camada_creditos.hide()

# --- FUNÇÃO DE TRANSIÇÃO ---
func iniciar_jogo(caminho_fase: String):
	# Guarda a escolha no GameManager
	GameManager.fase_inicial_escolhida = caminho_fase
	Audio.parar_voz()
	await _fechar_cortina()
	# Carrega a Cena Principal (que contém o Tiko e os controles)
	get_tree().change_scene_to_file("res://cenas/cena_principal.tscn")

# ==========================================
# TRANSIÇÃO (FADE) — a mesma cortina azul-escura da Cena Principal
# ==========================================
func _criar_cortina():
	var camada = CanvasLayer.new()
	camada.layer = 10
	add_child(camada)
	cortina = ColorRect.new()
	cortina.color = Color(0.05, 0.25, 0.45, 1)
	cortina.size = Vector2(1280, 1000)
	cortina.mouse_filter = Control.MOUSE_FILTER_STOP
	camada.add_child(cortina)

func _abrir_cortina():
	var tween = create_tween()
	tween.tween_property(cortina, "color:a", 0.0, 0.4)
	await tween.finished
	cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _fechar_cortina():
	cortina.mouse_filter = Control.MOUSE_FILTER_STOP # Bloqueia cliques durante a troca
	var tween = create_tween()
	tween.tween_property(cortina, "color:a", 1.0, 0.4)
	await tween.finished
