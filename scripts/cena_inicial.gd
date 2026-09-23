extends Node2D

func _ready():
	# Ao voltar para o menu, os tutoriais aparecem de novo na próxima partida
	GameManager.tutoriais_vistos.clear()
	GameManager.zerar_pontuacao()

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

# --- BOTÃO "SAIR" (canto superior direito) ---
func _on_botao_sair_pressed():
	get_tree().quit()

# --- FUNÇÃO DE TRANSIÇÃO ---
func iniciar_jogo(caminho_fase: String):
	# Guarda a escolha no GameManager
	GameManager.fase_inicial_escolhida = caminho_fase
	# Carrega a Cena Principal (que contém o Tiko e os controles)
	get_tree().change_scene_to_file("res://cenas/cena_principal.tscn")
