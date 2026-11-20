extends PetBehavior
## 戳一戳：被点击时随机播一个反应


## 由 DesktopPet 在点击时调用；正在被戳时再点，就换一个反应重新播
func poke() -> void:
	if pet.current == self:
		play_random()
	else:
		request()
