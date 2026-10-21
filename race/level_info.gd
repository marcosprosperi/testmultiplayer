class_name LevelInfo extends Resource

## A level the host can put in the championship (Main's level list)

@export var title := ""
## 1 = easy, 2 = medium, 3 = hard, 4 = extreme
@export_range(1, 4) var difficulty := 1
@export var scene: PackedScene
