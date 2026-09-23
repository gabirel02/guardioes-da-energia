extends TextureRect

# O pivot_offset de cada painel fica no centro dele (definido na cena), e o centro
# do painel fica em cima dos suportes da base. Assim ele gira sem sair da base.

# Variaveis para os limites
var limite_esquerdo = -80
var limite_direito = 80

func girar_esquerda():
	# Só gira se ainda não bateu no limite esquerdo
	if rotation_degrees > limite_esquerdo:
		rotation_degrees -= 15

func girar_direita():
	# Só gira se ainda não bateu no limite direito
	if rotation_degrees < limite_direito:
		rotation_degrees += 15
