# Falas do Tiko para gravar

Todas as falas do Tiko que aparecem no jogo, numeradas para gerar a voz. Versão revisada (análise das falas).

**A história:** a cidade do Tiko ficou sem energia porque as 3 usinas pararam. O jogador ajuda o Tiko a ligar uma usina por vez. Cada usina devolve a energia a uma parte da cidade: a solar às **casas**, a do vento à **escola** e a da água às **ruas**. No final, a cidade toda tem energia. O **robô aprendiz** (a IA) acompanha a aventura e aprende com o jogador.

**No jogo:** os áudios estão em `assets/audio/voz/` com o nome `falaNN.mp3`, em que NN é o número da fala (ex: fala 7 = `fala07.mp3`). A música de fundo é `assets/audio/musica_fundo.mp3`.

**Como usar**
1. Copie o texto de cada fala e cole no site de voz (TTSMaker, ElevenLabs etc.).
2. Salve o áudio com o **nome do arquivo** da tabela, sem mudar nada.
3. Coloque todos os arquivos na pasta `assets/audio/voz/` do projeto.

**Dicas de gravação**
- Voz animada, acolhedora e com ritmo moderado. Use sempre a **mesma voz** em todas as falas.
- Nas falas de ação rápida (vento forte, aviso), fale de forma curta e direta.
- Palavras em MAIÚSCULAS (FREIO, ESPAÇO, CONFIRMAR) são nomes de botões e teclas. Leia com uma leve ênfase.
- Formato recomendado: **WAV** ou **OGG**. Se o site só gerar MP3, também funciona.
- Deixe ~0,2 s de silêncio no começo e no fim de cada fala.

---

## 1. Abertura da história (botão VAMOS JOGAR)

| Nº | Nome do arquivo | Fala |
|---|---|---|
| 1 | `abertura_1.ogg` | Olá! Eu sou o Tiko, seu amigo robô! Precisamos da sua ajuda! Nossa cidade ficou sem energia! |
| 2 | `abertura_2.ogg` | As três usinas de energia pararam de funcionar! E agora? Como vamos iluminar a cidade? |
| 3 | `abertura_3.ogg` | Vamos trabalhar juntos para ligar as três usinas: a do sol, a do vento e a da água! |
| 4 | `abertura_4.ogg` | E temos um ajudante especial: o robô aprendiz! Ele vai aprender com você! Preparado para essa aventura? |

## 2. Geral

| Nº | Nome do arquivo | Fala | Quando toca |
|---|---|---|---|
| 5 | `geral_01.ogg` | Antes de começar, vou mostrar como jogar! Preste atenção nas dicas! | Quando o tutorial de uma fase abre |

## 3. Usina Solar

| Nº | Nome do arquivo | Fala | Quando toca |
|---|---|---|---|
| 6 | `solar_01.ogg` | Vamos começar pela usina solar! Os painéis estão sujos! Passe o mouse nas manchas para limpar! | Início da fase |
| 7 | `solar_02.ogg` | Você está indo muito bem! Faltam só duas manchas! Continue assim! | Faltando 2 manchas |
| 8 | `solar_03.ogg` | Que beleza! Os painéis estão limpinhos! Agora eles podem receber a luz do sol! | Todas as manchas limpas |
| 9 | `solar_04.ogg` | Agora, vamos virar o painel do meio para o sol! Quando terminar, clique em CONFIRMAR! | Começo do alinhamento |
| 10 | `solar_05.ogg` | Muito bem! O robô aprendiz está aprendendo com você! Olha só! O sol mudou de posição! | Depois de confirmar o 1º e o 2º sol (veja a observação) |
| 11 | `solar_06.ogg` | Agora é a vez do robô aprendiz! Vamos ver se ele consegue virar os painéis sozinho! | Começo do teste final |
| 12 | `solar_07.ogg` | Oba! Ele conseguiu! O robô aprendeu e virou os painéis para o sol! Parabéns! | Teste final: o robô alinhou |
| 13 | `solar_08.ogg` | Ops! Ainda não deu certo! Mas tudo bem! Nosso robô precisa aprender um pouquinho mais! | Teste final: o robô não alinhou |
| 14 | `solar_09.ogg` | Olha que legal! O sol muda de posição e o robô acompanha, virando os painéis! | Começo da demonstração |
| 15 | `solar_10.ogg` | Conseguimos! A usina solar está funcionando! As casas já têm energia! Agora vamos para a usina do vento! | Fim da fase no modo VAMOS JOGAR |
| 16 | `solar_11.ogg` | Parabéns! Você conseguiu ligar a usina solar! Agora as casas têm energia! | Fim da fase jogada sozinha |

> **Observação (fala 10):** na tela aparece "Você fez **X** pontos!" antes da fala, e o número muda a cada jogada. Como não dá para gravar todos os números, a voz fala só a frase fixa. O número aparece escrito no balão.

## 4. Usina do Vento (Eólica)

| Nº | Nome do arquivo | Fala | Quando toca |
|---|---|---|---|
| 17 | `eolica_01.ogg` | Chegamos à usina do vento! Aqui, o vento ajuda a produzir energia! Mas cuidado com o vento forte! | Início da fase |
| 18 | `eolica_02.ogg` | Vamos tentar outra vez! Quando o vento ficar forte, segure o botão FREIO ou a tecla ESPAÇO! | Recomeço depois de perder |
| 19 | `eolica_03.ogg` | Atenção! Vem vento forte por aí! Prepare o freio! | Aviso antes de cada rajada |
| 20 | `eolica_04.ogg` | Vento forte! Segure o FREIO agora! | Quando a rajada começa |
| 21 | `eolica_05.ogg` | O vento ficou fraco! Pode soltar o FREIO para produzir energia! | Quando a rajada acaba |
| 22 | `eolica_06.ogg` | Olha só! O robô aprendiz preparou novos ventos! Vamos ver como você se sai! | Nova geração do robô (toca **no lugar** da fala 19; a placa "VEM VENTO FORTE!" continua aparecendo) |
| 23 | `eolica_07.ogg` | Oba! A usina do vento está funcionando! A escola já tem energia! Agora vamos para a usina da água! | Fim da fase no modo VAMOS JOGAR |
| 24 | `eolica_08.ogg` | Muito bem! Você conseguiu ligar a usina do vento! Agora a escola tem energia! | Fim da fase jogada sozinha |
| 25 | `eolica_09.ogg` | Ops! O vento estava muito forte e a turbina quebrou! Vamos tentar de novo? | Quando a turbina quebra |

## 5. Usina da Água (Hidrelétrica)

| Nº | Nome do arquivo | Fala | Quando toca |
|---|---|---|---|
| 26 | `hidro_01.ogg` | Chegamos à usina da água! Aqui, precisamos cuidar da água da represa! O robô aprendiz vai mudar o tempo! | Início da fase |
| 27 | `hidro_02.ogg` | Vamos tentar novamente! Fique de olho na barra azul! Ela mostra a quantidade de água! | Recomeço depois de perder |
| 28 | `hidro_03.ogg` | O sol apareceu! Agora a água da represa sobe bem devagar! | O robô escolhe sol |
| 29 | `hidro_04.ogg` | Começou a chover! Olhe só! A água da represa está subindo! | O robô escolhe chuva |
| 30 | `hidro_05.ogg` | Cuidado! Uma tempestade! A água está subindo muito rápido! | O robô escolhe tempestade |
| 31 | `hidro_06.ogg` | Comporta aberta! A água está saindo e fazendo a turbina girar! | Jogador abre a comporta |
| 32 | `hidro_07.ogg` | Comporta fechada! Agora a água fica guardada na represa! | Jogador fecha a comporta |
| 33 | `hidro_08.ogg` | Viva! Conseguimos ligar as três usinas! Agora toda a cidade tem energia! Você é um verdadeiro Guardião da Energia! | Fim do jogo no modo VAMOS JOGAR |
| 34 | `hidro_09.ogg` | Parabéns! Você ligou a usina da água! Agora as ruas da cidade têm energia! | Fim da fase jogada sozinha |
| 35 | `hidro_10.ogg` | Ops! A represa ficou cheia demais e a água transbordou! Na próxima, abra a comporta um pouco antes! | Perdeu: água transbordou |
| 36 | `hidro_11.ogg` | Ah, não! A água da represa acabou e a turbina parou! Na próxima, feche a comporta um pouco antes! | Perdeu: água secou |

---

## 6. Tutoriais (opcional, mas recomendado)

Os passos do tutorial aparecem escritos no painel de dicas. Gravar a narração deles ajuda muito quem tem dificuldade de leitura. A ideia é o Tiko ler o passo enquanto ele aparece.

### Usina Solar

| Nº | Nome do arquivo | Fala |
|---|---|---|
| 37 | `tutorial_solar_1.ogg` | Você sabia? Os painéis solares recebem a luz do sol e a transformam em energia elétrica! |
| 38 | `tutorial_solar_2.ogg` | Primeiro, vamos limpar os painéis! Passe o mouse sobre as manchas até elas desaparecerem! |
| 39 | `tutorial_solar_3.ogg` | Agora, clique em GIRAR ou use as setas do teclado para virar o painel do meio em direção ao sol! |
| 40 | `tutorial_solar_4.ogg` | Quando o painel estiver virado para o sol, clique em CONFIRMAR ou aperte ENTER! |
| 41 | `tutorial_solar_5.ogg` | Preste atenção! O robô aprendiz observa como você joga! Depois, ele vai tentar fazer tudo sozinho! |

### Usina do Vento

| Nº | Nome do arquivo | Fala |
|---|---|---|
| 42 | `tutorial_eolica_1.ogg` | Você sabia? O vento faz as hélices girarem! Assim, a usina produz energia elétrica! |
| 43 | `tutorial_eolica_2.ogg` | O robô aprendiz vai mandar ventos fortes! Antes de cada vento forte, um aviso vai aparecer na tela! |
| 44 | `tutorial_eolica_3.ogg` | Quando aparecer o aviso, prepare-se! Segure o botão vermelho FREIO ou a tecla ESPAÇO! |
| 45 | `tutorial_eolica_4.ogg` | Quando o vento ficar fraco, solte o FREIO! Assim, a turbina volta a produzir energia! |
| 46 | `tutorial_eolica_5.ogg` | Você precisa cuidar da turbina por um minuto e meio! Não deixe a barra vermelha encher, senão a turbina quebra! |

### Usina da Água

| Nº | Nome do arquivo | Fala |
|---|---|---|
| 47 | `tutorial_hidro_1.ogg` | Você sabia? A água da represa passa pela turbina e faz ela girar! Assim, produzimos energia elétrica! |
| 48 | `tutorial_hidro_2.ogg` | O robô aprendiz vai escolher o tempo: sol, chuva ou tempestade! Cada um muda a quantidade de água da represa! |
| 49 | `tutorial_hidro_3.ogg` | Olhe a barra azul! Ela mostra a quantidade de água! Mantenha a água na faixa verde por um minuto! |
| 50 | `tutorial_hidro_4.ogg` | A água está subindo demais? Clique em ABRIR COMPORTA ou aperte a tecla A para deixar a água sair! |
| 51 | `tutorial_hidro_5.ogg` | A água está baixando demais? Clique em FECHAR COMPORTA ou aperte a tecla F para guardar a água! |

---

## 7. Extras (pop-up de vitória e menu)

Falas curtas que dão mais vida ao Tiko. Já estão ligadas no jogo.

| Nº | Nome do arquivo | Fala | Quando toca |
|---|---|---|---|
| 52 | `extra_01.ogg` | Uau! Três estrelas! Você arrasou! É um verdadeiro Guardião da Energia! | Pop-up de vitória com 3 estrelas |
| 53 | `extra_02.ogg` | Muito bem! Duas estrelas! Você está aprendendo cada vez mais! | Pop-up de vitória com 2 estrelas |
| 54 | `extra_03.ogg` | Boa! Você ganhou uma estrela! Que tal tentar outra vez para conquistar mais? | Pop-up de vitória com 1 estrela |
| 55 | `extra_04.ogg` | Olá, Guardião! Nossa cidade precisa de você! Vamos começar essa aventura? | Menu inicial |

---

**Total:** 4 falas da abertura, 32 falas do jogo, 15 falas de tutorial e 4 extras, **55 áudios**.
