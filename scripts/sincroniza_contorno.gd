extends Polygon2D

func _ready():
	# 1. Encontra o nó Line2D que é meu filho
	var contour_line = get_node("Borda_Pa1")
	
	# 2. SEGREDO: Copia todos os meus pontos desenhados para a linha
	contour_line.points = polygon
