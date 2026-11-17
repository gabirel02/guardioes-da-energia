# Relatório provisório – IA da Fase Solar (Q-Learning)

Arquivos:
- `scripts/agente_q_solar.gd` – só o algoritmo Q-Learning
- `scripts/fase_solar.gd` – regras do jogo (limpeza, nota, rodadas, teste final, animação)
- `scripts/experimento_solar.gd` + `cenas/experimento_solar.tscn` – experimento (F6 no Godot)
- Resultados brutos: `docs/experimento_solar_resultados.txt` e os `.csv` desta pasta

---

## 1. O que é Q-Learning e o que é regra do jogo

| Q-Learning (`agente_q_solar.gd`) | Regra do jogo (`fase_solar.gd`) |
|---|---|
| Estado, ações, recompensa | Limpar as manchas |
| Escolha da ação (ε-greedy) | Nota do jogador (precisão + tempo) → só pontuação e estrelas |
| Transição para o próximo estado | 3 rodadas com o sol em posições diferentes |
| Atualização da tabela Q | Teste final e animação do sol atravessando o céu |
| Treino por episódios | Transformar os cliques do jogador em experiências |

**Mudança:** a regra antiga "a nota do jogador decide quantos episódios a IA treina" foi **removida**.
Agora a IA treina sempre o mesmo número de episódios (100 por rodada) e a nota do jogador serve só para a pontuação.

## 2. Ciclo de um passo

```
estado atual  →  ação escolhida  →  novo estado  →  recompensa  →  atualiza Q(estado, ação)
```

No código é a função `passo()` do agente, nessa mesma ordem.

- **Estado:** diferença entre o ângulo do sol e o do painel, arredondada de 15 em 15 graus.
  Ex.: `+30` = o sol está 30° "à frente" do painel. `0` = alinhado (erro menor que 7,5°).
- **Ações:** `-15` (girar para um lado), `0` (ficar parado), `+15` (girar para o outro lado).
- **Transição:** o painel gira a ação escolhida. Se bater no limite da base (-80° ou 85°), não gira.

## 3 e 5. Recompensa (explícita)

Calculada com o erro do **novo** estado:

| Situação | Recompensa |
|---|---|
| O novo estado é 0 (alinhou) | **+100** |
| Girou (ação ≠ 0) e não alinhou | **−erro − 2** |
| Ficou parado (ação = 0) e não alinhou | **−erro** |

Exemplos de várias situações:

| Estado | Ação | Novo estado | Recompensa | Comentário |
|---|---|---|---|---|
| 30 | +15 | 15 | −15 − 2 = **−17** | Chegou mais perto |
| 30 | 0 | 30 | **−30** | Não fez nada |
| 30 | −15 | 45 | −45 − 2 = **−47** | Afastou: pior de todas |
| 15 | +15 | 0 | **+100** | Alinhou: fim do episódio |
| 15 | 0 | 15 | **−15** | |
| 15 | −15 | 30 | −30 − 2 = **−32** | |
| −15 | −15 | 0 | **+100** | Alinhou pelo outro lado |
| 45 (painel no limite 85°) | +15 | 45 | −45 − 2 = **−47** | Bateu no limite, gastou o movimento |

## 4. Por que a penalidade por girar? (experimento)

A penalidade antiga era 10, sem justificativa. Agora é um parâmetro (`penalidade_movimento`) e foi testada
(100 episódios, 30 execuções cada):

| Penalidade | Taxa de sucesso | Erro médio | Movimentos médios |
|---|---|---|---|
| 0 | 83,3% ± 5,4 | 23,16° | 3,49 |
| **2** | **82,3% ± 3,6** | **24,14°** | **3,38** |
| 5 | 81,0% ± 4,3 | 25,55° | 3,36 |
| 10 | 80,0% ± 6,6 | 25,86° | 3,11 |

**Conclusão:** com o prêmio de +100 ao alinhar, a penalidade quase não muda o resultado (as diferenças ficam
dentro do desvio). Penalidades maiores deixam a IA um pouco mais "preguiçosa" (menos movimentos, menos sucesso).
Mantivemos **2**: é pequena o bastante para não atrapalhar e ainda desempata a favor de não girar à toa.

## 6 e 9. Exemplo manual da atualização da tabela Q

Fórmula: **Q(s,a) ← Q(s,a) + α · [ r + γ · maxQ(s') − Q(s,a) ]**, com α = 0,2 e γ = 0,9.
Se s' é o estado 0 (terminal), não há futuro: usa-se **maxQ(s') = 0**.

Tabela começa zerada. Episódio 1 começa no estado 30:

| Passo | Estado | Ação (motivo) | Novo estado | r | maxQ(s') | Conta | Novo Q |
|---|---|---|---|---|---|---|---|
| 1 | 30 | 0 (exploração, 20%) | 30 | −30 | 0 | 0 + 0,2·(−30 + 0,9·0 − 0) | Q(30, 0) = **−6** |
| 2 | 30 | +15 (empate −15/+15, sorteio) | 15 | −17 | 0 | 0 + 0,2·(−17 + 0 − 0) | Q(30,+15) = **−3,4** |
| 3 | 15 | +15 (tudo 0, sorteio) | 0 | +100 | 0 (terminal) | 0 + 0,2·(100 − 0) | Q(15,+15) = **20** |

Fim do episódio (alinhou). Tabela depois do episódio 1:

| Estado | Q(−15) | Q(0) | Q(+15) |
|---|---|---|---|
| 15 | 0 | 0 | **20** |
| 30 | 0 | **−6** | **−3,4** |

Episódio 2 começa de novo no estado 30:
- Pela tabela, a melhor ação em 30 é −15 (Q = 0, ainda não testada). Ela vai para 45, r = −47 →
  Q(30,−15) = 0 + 0,2·(−47 − 0) = **−9,4**. A IA aprende que esse lado é ruim.
- Da próxima vez em 30, a melhor é +15: vai para 15, r = −17, e agora **maxQ(15) = 20** →
  Q(30,+15) = −3,4 + 0,2·(−17 + 0,9·20 − (−3,4)) = −3,4 + 0,2·4,4 = **−2,52**.
  O valor "bom" do estado 15 começa a passar para o estado 30. É isso que o γ faz.

**Para onde os valores vão depois de muito treino** (conta: Q = r + 0,9 · Q do próximo):

| Q | Conta | Valor teórico | Valor no experimento (250 episódios) |
|---|---|---|---|
| Q(15, +15) | 100 | 100 | 100,00 |
| Q(30, +15) | −17 + 0,9·100 | 73 | 73,00 |
| Q(45, +15) | −32 + 0,9·73 | 33,7 | 33,70 |
| Q(60, +15) | −47 + 0,9·33,7 | −16,7 | −16,69 |
| Q(75, +15) | −62 + 0,9·(−16,7) | −77,0 | −77,74 |

Os valores do experimento batem com a conta, o que mostra que a atualização está correta.

## 7. Valor inicial de Q

**0** para todas as ações. Um estado entra na tabela com `{-15: 0, 0: 0, +15: 0}` na primeira vez que aparece.

## 8. Empate

- **No treino:** sorteia entre as ações empatadas (não favorece nenhum lado).
- **No teste / demonstração:** se "ficar parado" está entre as empatadas, fica parado; senão sorteia.
  Por isso, uma IA sem treino (tudo 0) não se mexe: taxa de sucesso 0% na linha de 0 episódios.

## 10. Quando termina um episódio

- **Treino:** quando alinha (estado 0) **ou** depois de **15 passos** (`max_passos`).
  O maior erro possível precisa de 11 movimentos, então 15 dá margem para a exploração.
  Episódios que começariam já alinhados são sorteados de novo.
- **Teste:** quando alinha, quando a IA escolhe ficar parada, ou depois de 15 passos.

## 11 e 12. Relação entre o jogador e a IA

**Antes:** nota do jogador → número de episódios (100 → 150 episódios, 50 → 37, 20 → 6, 0 → 0).
Não fazia parte do Q-Learning e um jogador ruim quase não deixava a IA treinar. **Removido.**

**Agora (jogador fornece experiências):** cada clique do jogador vira uma transição usada na mesma fórmula.

Exemplo: o sol está no estado 30 e o jogador clica em GIRAR para o lado certo:
experiência **(30, +15, −17, 15)** → atualiza Q(30, +15).
Clicar em CONFIRMAR também é uma experiência: a ação "ficar parado" (0) no estado em que o painel está.

Isso **não é imitação**: a IA não copia o jogador. As jogadas dele (boas ou ruins) entram como experiências
comuns, e a IA continua explorando sozinha.

Fluxo da fase:

| Momento | O que acontece |
|---|---|
| Rodada 1 | Sol em uma posição. Cada clique do jogador atualiza a tabela Q. Depois a IA treina **100 episódios** sozinha (ε = 0,2). |
| Rodada 2 | Sol em nova posição. Novas experiências do jogador + 100 episódios. |
| Rodada 3 | Igual à rodada 2. |
| Teste final | Sol numa posição **nova** (longe das 3 anteriores). **ε = 0**, sem aprender: os 3 painéis giram sozinhos, de 15 em 15, até alinhar. O Tiko diz quantos movimentos a IA usou. |
| Demonstração | O sol atravessa o céu e os painéis seguem, usando a tabela Q. |

A tabela Q aparece no **terminal do Godot** (aba Saída): no começo da fase, cada experiência do jogador,
depois de cada rodada e o resultado do teste final. A tabela Q **não é salva**: toda vez que a fase começa,
a IA começa do zero (todos os valores em 0).

## Experimento: quantidade de episódios

Método:
- Para cada quantidade de episódios, **30 execuções**: cada execução é uma IA nova, treinada **do zero**
  (sem jogador), com semente diferente.
- Cada IA é testada com ε = 0 em **100 posições fixas** (sol e painel sorteados com semente própria,
  nunca iguais às do treino).
- **Taxa de sucesso** = testes em que alinhou ÷ total de testes.
- **Erro médio** = diferença final entre o sol e o painel, em graus (mesmo alinhado sobra até 7,5°).
- **Movimentos médios** = giros feitos. **Mínimo possível** = giros necessários no caminho perfeito (média 4,05).

| Episódios | Execuções | Taxa de sucesso | Erro médio | Movimentos médios |
|---|---|---|---|---|
| 0 | 30 | 0,0% ± 0,0 | 60,68° | 0,00 |
| 30 | 30 | 58,7% ± 10,0 | 41,40° | 2,81 |
| 50 | 30 | 67,2% ± 6,9 | 36,83° | 2,79 |
| 100 | 30 | 82,3% ± 3,6 | 24,14° | 3,38 |
| 150 | 30 | 88,4% ± 4,5 | 18,01° | 3,70 |
| 200 | 30 | 92,2% ± 2,8 | 13,94° | 3,83 |
| 250 | 30 | 93,2% ± 2,6 | 12,79° | 3,82 |

**Leitura:**
- Com mais episódios a taxa de sucesso sobe e o erro cai. De 200 para 250 quase não muda: o aprendizado estabiliza perto de 93%.
- Os movimentos ficam abaixo do mínimo porque, quando a IA erra, ela para antes (escolhe ficar parada).
- As falhas acontecem quando o sol está **muito longe** do painel (erro de 90° ou mais): esses estados aparecem
  pouco no treino, então os valores deles aprendem menos.
- No jogo a IA treina 100 por rodada × 3 rodadas = **300 episódios** (mais as experiências do jogador),
  o que fica na faixa de ~93% de sucesso.

A evolução completa da tabela Q de uma IA (0, 30, 50, 100, 150, 200 e 250 episódios) está em
`docs/experimento_solar_resultados.txt`.
