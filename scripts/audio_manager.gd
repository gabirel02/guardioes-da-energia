extends Node

# ==========================================
# ÁUDIO DO JOGO (Autoload "Audio")
# Toca a voz do Tiko e a música de fundo.
# - Cada fala tem um arquivo: assets/audio/voz/falaNN.mp3 (mesma numeração de docs/falas_tiko.md).
# - A fala é encontrada pelo texto que aparece no balão, então as fases não precisam mudar nada.
# - Enquanto o Tiko fala, a música abaixa para a voz ficar clara.
# ==========================================

const CAMINHO_VOZ = "res://assets/audio/voz/fala%02d.mp3"
const CAMINHO_MUSICA = "res://assets/audio/musica_fundo.mp3"

const VOLUME_VOZ = 0.0             # em decibéis, no volume máximo (100%)
const VOLUME_MUSICA = -16.0        # música normal, no volume máximo (100%)
const VOLUME_MUSICA_COM_VOZ = -26.0 # música mais baixa enquanto o Tiko fala, no volume máximo (100%)
const PAUSA_ENTRE_FALAS = 0.4      # silêncio entre falas seguidas (ex: passos do tutorial)
const VOLUME_MUDO_DB = -80.0       # abaixo disso o Godot já considera silêncio total

# Falas extras, tocadas pelo número
const FALA_TRES_ESTRELAS = 52
const FALA_DUAS_ESTRELAS = 53
const FALA_UMA_ESTRELA = 54
const FALA_MENU = 55

# Texto de cada fala -> número do arquivo
const FALAS = {
	"Olá! Eu sou o Tiko, seu amigo robô! Precisamos da sua ajuda! Nossa cidade ficou sem energia!": 1,
	"As três usinas de energia pararam de funcionar! E agora? Como vamos iluminar a cidade?": 2,
	"Vamos trabalhar juntos para ligar as três usinas: a do sol, a do vento e a da água!": 3,
	"E temos um ajudante especial: o robô aprendiz! Ele vai aprender com você! Preparado para essa aventura?": 4,
	"Antes de começar, vou mostrar como jogar! Preste atenção nas dicas!": 5,
	"Vamos começar pela usina solar! Os painéis estão sujos! Passe o mouse nas manchas para limpar!": 6,
	"Você está indo muito bem! Faltam só duas manchas! Continue assim!": 7,
	"Que beleza! Os painéis estão limpinhos! Agora eles podem receber a luz do sol!": 8,
	"Agora, vamos virar o painel do meio para o sol! Quando terminar, clique em CONFIRMAR!": 9,
	"Muito bem! O robô aprendiz está aprendendo com você! Olha só! O sol mudou de posição!": 10,
	"Agora é a vez do robô aprendiz! Vamos ver se ele consegue virar os painéis sozinho!": 11,
	"Oba! Ele conseguiu! O robô aprendeu e virou os painéis para o sol! Parabéns!": 12,
	"Ops! Ainda não deu certo! Mas tudo bem! Nosso robô precisa aprender um pouquinho mais!": 13,
	"Olha que legal! O sol muda de posição e o robô acompanha, virando os painéis!": 14,
	"Conseguimos! A usina solar está funcionando! As casas já têm energia! Agora vamos para a usina do vento!": 15,
	"Parabéns! Você conseguiu ligar a usina solar! Agora as casas têm energia!": 16,
	"Chegamos à usina do vento! Aqui, o vento ajuda a produzir energia! Mas cuidado com o vento forte!": 17,
	"Vamos tentar outra vez! Quando o vento ficar forte, segure o botão FREIO ou a tecla ESPAÇO!": 18,
	"Atenção! Vem vento forte por aí! Prepare o freio!": 19,
	"Vento forte! Segure o FREIO agora!": 20,
	"O vento ficou fraco! Pode soltar o FREIO para produzir energia!": 21,
	"Olha só! O robô aprendiz preparou novos ventos! Vamos ver como você se sai!": 22,
	"Oba! A usina do vento está funcionando! A escola já tem energia! Agora vamos para a usina da água!": 23,
	"Muito bem! Você conseguiu ligar a usina do vento! Agora a escola tem energia!": 24,
	"Ops! O vento estava muito forte e a turbina quebrou! Vamos tentar de novo?": 25,
	"Chegamos à usina da água! Aqui, precisamos cuidar da água da represa! O robô aprendiz vai mudar o tempo!": 26,
	"Vamos tentar novamente! Fique de olho na barra azul! Ela mostra a quantidade de água!": 27,
	"O sol apareceu! Agora a água da represa sobe bem devagar!": 28,
	"Começou a chover! Olhe só! A água da represa está subindo!": 29,
	"Cuidado! Uma tempestade! A água está subindo muito rápido!": 30,
	"Comporta aberta! A água está saindo e fazendo a turbina girar!": 31,
	"Comporta fechada! Agora a água fica guardada na represa!": 32,
	"Viva! Conseguimos ligar as três usinas! Agora toda a cidade tem energia! Você é um verdadeiro Guardião da Energia!": 33,
	"Parabéns! Você ligou a usina da água! Agora as ruas da cidade têm energia!": 34,
	"Ops! A represa ficou cheia demais e a água transbordou! Na próxima, abra a comporta um pouco antes!": 35,
	"Ah, não! A água da represa acabou e a turbina parou! Na próxima, feche a comporta um pouco antes!": 36,
	"Você sabia? Os painéis solares recebem a luz do sol e a transformam em energia elétrica!": 37,
	"Primeiro, vamos limpar os painéis! Passe o mouse sobre as manchas até elas desaparecerem!": 38,
	"Agora, clique em GIRAR ou use as setas do teclado para virar o painel do meio em direção ao sol!": 39,
	"Quando o painel estiver virado para o sol, clique em CONFIRMAR ou aperte ENTER!": 40,
	"Preste atenção! O robô aprendiz observa como você joga! Depois, ele vai tentar fazer tudo sozinho!": 41,
	"Você sabia? O vento faz as hélices girarem! Assim, a usina produz energia elétrica!": 42,
	"O robô aprendiz vai mandar ventos fortes! Antes de cada vento forte, um aviso vai aparecer na tela!": 43,
	"Quando aparecer o aviso, prepare-se! Segure o botão vermelho FREIO ou a tecla ESPAÇO!": 44,
	"Quando o vento ficar fraco, solte o FREIO! Assim, a turbina volta a produzir energia!": 45,
	"Você precisa cuidar da turbina por um minuto e meio! Não deixe a barra vermelha encher, senão a turbina quebra!": 46,
	"Você sabia? A água da represa passa pela turbina e faz ela girar! Assim, produzimos energia elétrica!": 47,
	"O robô aprendiz vai escolher o tempo: sol, chuva ou tempestade! Cada um muda a quantidade de água da represa!": 48,
	"Olhe a barra azul! Ela mostra a quantidade de água! Mantenha a água na faixa verde por um minuto!": 49,
	"A água está subindo demais? Clique em ABRIR COMPORTA ou aperte a tecla A para deixar a água sair!": 50,
	"A água está baixando demais? Clique em FECHAR COMPORTA ou aperte a tecla F para guardar a água!": 51,
	"Uau! Três estrelas! Você arrasou! É um verdadeiro Guardião da Energia!": 52,
	"Muito bem! Duas estrelas! Você está aprendendo cada vez mais!": 53,
	"Boa! Você ganhou uma estrela! Que tal tentar outra vez para conquistar mais?": 54,
	"Olá, Guardião! Nossa cidade precisa de você! Vamos começar essa aventura?": 55,
}

var musica: AudioStreamPlayer
var voz: AudioStreamPlayer
var fila: Array = []      # números das próximas falas
var sequencia: int = 0    # muda sempre que a voz é interrompida
var tween_musica: Tween
var musica_abaixada: bool = false # true enquanto o Tiko está falando
# Volume geral, de 0.0 (mudo) a 1.0 (máximo). Começa no máximo.
# Não é salvo em arquivo (o jogo web não salva nada): volta ao máximo ao reabrir.
var volume_geral: float = 1.0

# Continua existindo para quem só precisa saber se está mudo ou não
var som_ligado: bool:
	get: return volume_geral > 0.0

func _ready():
	# Continua funcionando com o jogo pausado (pop-up de vitória, dicas da pausa)
	process_mode = Node.PROCESS_MODE_ALWAYS

	musica = AudioStreamPlayer.new()
	musica.volume_db = _com_volume_geral(VOLUME_MUSICA)
	add_child(musica)
	var stream_musica = load(CAMINHO_MUSICA)
	if stream_musica is AudioStreamMP3:
		stream_musica.loop = true # repete sem parar
	musica.stream = stream_musica
	musica.play()

	voz = AudioStreamPlayer.new()
	voz.volume_db = _com_volume_geral(VOLUME_VOZ)
	add_child(voz)
	voz.finished.connect(_ao_terminar_fala)

# Número da fala de um texto (0 se não tiver áudio)
func numero_da_fala(texto: String) -> int:
	if FALAS.has(texto):
		return FALAS[texto]
	# Textos com partes que mudam, ex: "Você fez 85 pontos! " + fala
	for chave in FALAS:
		if texto.ends_with(chave):
			return FALAS[chave]
	return 0

# Fala um ou mais textos, um depois do outro (interrompe o que estava tocando)
func falar(textos: Array):
	var numeros = []
	for texto in textos:
		var numero = numero_da_fala(texto)
		if numero > 0:
			numeros.append(numero)
	falar_numeros(numeros)

func falar_numeros(numeros: Array):
	parar_voz()
	fila = numeros.duplicate()
	_tocar_proxima()

func parar_voz():
	sequencia += 1
	fila.clear()
	voz.stop()
	voz.stream_paused = false
	_abaixar_musica(false)

# Usado pela pausa: a voz para no meio e continua de onde parou
func pausar_voz(pausar: bool):
	voz.stream_paused = pausar

func esta_falando() -> bool:
	return voz.playing or voz.stream_paused or not fila.is_empty()

func _tocar_proxima():
	while not fila.is_empty():
		var stream = load(CAMINHO_VOZ % fila.pop_front())
		if stream:
			voz.stream = stream
			voz.stream_paused = false
			voz.play()
			_abaixar_musica(true)
			return
	_abaixar_musica(false)

func _ao_terminar_fala():
	if fila.is_empty():
		_abaixar_musica(false)
		return
	# Pequena pausa antes da próxima fala da fila
	var minha_sequencia = sequencia
	await get_tree().create_timer(PAUSA_ENTRE_FALAS, true).timeout
	if minha_sequencia == sequencia:
		_tocar_proxima()

func _abaixar_musica(abaixar: bool):
	musica_abaixada = abaixar
	if volume_geral <= 0.0:
		return # já está mudo, não precisa animar o volume
	if tween_musica:
		tween_musica.kill()
	var alvo = VOLUME_MUSICA_COM_VOZ if abaixar else VOLUME_MUSICA
	tween_musica = create_tween()
	tween_musica.tween_property(musica, "volume_db", _com_volume_geral(alvo), 0.3)

# ==========================================
# CONTROLE DE VOLUME (barra do botão "Som")
# ==========================================
# Converte um volume "no máximo" (100%) para o volume real, de acordo com a barra.
# Em vez de só somar decibéis, aplica o volume_geral como um multiplicador do volume (0 a 1),
# assim a barra se comporta como o controle de volume do Windows.
func _com_volume_geral(volume_db_no_maximo: float) -> float:
	if volume_geral <= 0.0:
		return VOLUME_MUDO_DB
	return volume_db_no_maximo + linear_to_db(volume_geral)

# Chamada pela barra deslizante. volume vai de 0.0 (mudo) a 1.0 (máximo)
func definir_volume(volume: float):
	volume_geral = clamp(volume, 0.0, 1.0)
	if tween_musica:
		tween_musica.kill()
	musica.volume_db = _com_volume_geral(VOLUME_MUSICA_COM_VOZ if musica_abaixada else VOLUME_MUSICA)
	voz.volume_db = _com_volume_geral(VOLUME_VOZ)
