extends TextureRect

func _on_mouse_entered():
	# A palavra 'owner' significa o Dono da cena inteira (nossa FaseSolar).
	# A sujeira acessa a FaseSolar e aciona a função que criamos lá!
	owner.sujeira_removida()
	
	# Depois de avisar, ela se destrói
	queue_free()
