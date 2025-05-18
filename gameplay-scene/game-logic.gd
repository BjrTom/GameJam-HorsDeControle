extends Control

#/* -------------------------------------------------------------------------- */
#/*                                 Variables                                  */
#/* -------------------------------------------------------------------------- */

var goal = 200
var goalList = [200, 500, 1000, 99999999, 20]
var card_names = []
var card_values = []
var card_images = {}
var playerScore = 0
var dealerScore = 0
var playerCards = []
var dealerCards = []
var bet = 0;
var cardsShuffled = {}
var ace_found
var dollars = 10
var autoChangeAnimation = true
var doAction = false
var action = ""
var nb = [2, 3, 4, 2, 2, 3, 3, 5]
var level = [
	[0, 1], # 0 - 2
	[0, 1], # 0 - 3
	[1, 1, 1, 10], # 4 - 40
	[1, 10], # 2 - 20
	[1, 10, 10], # 2 - 10
	[10, 10, 50], # 30 - 150
	[1, 10, 10, 50, 50], # 3 - 150
	[0, 1, 1, 10, 10, 50, 50, 50, 50] # 0 - 250
]
var actionTab = [
		["chooseBet", "optimalMove"], # level 1
		["chooseBet", "randomMove"], # level 2
		["chooseBet", "NotoptimalMove"], # level 3
		["chooseBet", "randomMove"] # level 4
	]

#/* -------------------------------------------------------------------------- */
#/*                              RunTime Function                              */
#/* -------------------------------------------------------------------------- */

# Called when the node enters the scene tree for the first time.
func _ready():
	$Popup/PlayerHitMarker.visible = false
	$Popup/DealerHitMarker.visible = false
	$Popup/PlayerBlackJack.visible = false
	$Popup/DealerBlackJack.visible = false
	$Popup/PlayerBustMarker.visible = false
	
	$BetButton.disabled = true
	$Buttons/VBoxContainer/Hit.disabled = true
	$Buttons/VBoxContainer/Stand.disabled = true
	$Buttons/VBoxContainer/Hit.grab_focus()
	$SFX/RegularMusic.play()
	goal = goalList[Global.diff]
	dollars = Global.startCash
	print(goalList[Global.diff])
	get_tree().root.content_scale_factor
	checkBet()
	display_chips()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if (!autoChangeAnimation):
		return
	if ($DrunkControl/DrunkLevel.value >= 0 and $DrunkControl/DrunkLevel.value < 2):
		handleAnimation("sober")
	if ($DrunkControl/DrunkLevel.value >= 2 and $DrunkControl/DrunkLevel.value < 4):
		handleAnimation("tipsy")
	if ($DrunkControl/DrunkLevel.value >= 4 and $DrunkControl/DrunkLevel.value < 6):
		handleAnimation("hiccup")
	if ($DrunkControl/DrunkLevel.value >= 6):
		handleAnimation("drunk")
	#$DrunkControl/DrunkLevel.value += 0.25

#/* -------------------------------------------------------------------------- */
#/*                              Buttons Function                              */
#/* -------------------------------------------------------------------------- */

# Called when hit button is pressed
func _on_hit_pressed():
	$SFX/Bouton.play()
	generate_card("player")
	# Play "hit!" animation
	$Popup/PlayerHitMarker.visible = true
	$AnimationPlayer.play("HitAnimationP")
	updateText()
	#if playerScore == 21:
		#_on_stand_pressed()  # Player auto-stands on 21
	if playerScore > 21:
		check_aces()  # Check to see if any 11-aces can convert to 1-aces
		if playerScore > 21:  # Score still surpasses 21
			$Popup/PlayerHitMarker.visible = false
			$Popup/PlayerBustMarker.visible = true
			$AnimationPlayer.play("BustAnimation")
			#$PlayerHitMarker.visible = false
			playerLose()
			return
	$Buttons/VBoxContainer/Hit.disabled = false
	$Buttons/VBoxContainer/Stand.disabled = false

# Called when stand button is pressed
func _on_stand_pressed():
	$SFX/Bouton.play()
	# Flip dealer's first card, dealer keeps hitting until score is above 16 or player's score
	$Buttons/VBoxContainer/Hit.disabled = true
	$Buttons/VBoxContainer/Stand.disabled = true
	$Buttons/VBoxContainer/OptimalMove.disabled = true
	$WhoseTurn.text = "Dealer's\nTurn"

	await get_tree().create_timer(0.5).timeout
	var dealer_hand_container = $Cards/Hands/DealerHand

	# Remove the first card from the container (the back of card texture)
	var child_to_remove = dealer_hand_container.get_child(0)
	child_to_remove.queue_free()  # Remove the node from the scene
	
	# Create a new TextureRect node for the card image
	var card = dealerCards[0]
	var card_texture_rect = TextureRect.new()
	var card_texture = ResourceLoader.load(card[1])
	card_texture_rect.texture = card_texture

	# Add the card as a child to the HBoxContainer
	dealer_hand_container.add_child(card_texture_rect)
	dealer_hand_container.move_child(card_texture_rect, 0)
	
	# Add score to dealerScore
	if card[0] == 11 and dealerScore > 10:  # Aces are 1 if score is too high for 11
		dealerScore += 1
	else:
		dealerScore += card[0]
	updateText()
	
	# Dealer hits until score surpasses player or 17
	while dealerScore < playerScore and dealerScore < 17:
		await get_tree().create_timer(1.5).timeout
		# Play "hit!" animation for dealer
		$Popup/DealerHitMarker.visible = true
		$AnimationPlayer.play("HitAnimationD")
		generate_card("dealer")
		updateText()
		
	# Evaluate results
	if dealerScore > 21 or dealerScore < playerScore:  # Dealer bust or dealer less than player
		playerWin()
	elif playerScore < dealerScore and dealerScore <= 21:  # Dealer is between player score and 22
		if (dealerScore == 21): 
			playerLose(true)
		else:
			playerLose()
	else:  # Tie
		playerDraw()

# Called when exit button is pressed
func _on_exit_pressed():
	$SFX/Bouton.play()
	get_tree().change_scene_to_file("res://Menu/scenes/menus/main_menu/main_menu.tscn")

# Called when dollars button is pressed
func _on_bet_dollars_pressed(new_bet: int) -> void:
	if (new_bet == 0 or dollars <= 0 or dollars < new_bet):
		return
	bet += new_bet
	dollars -= new_bet
	$SFX/Chips.play()
	$BetButton.disabled = false
	# use action bool
	if (!action):
		checkBet()
	display_chips()

# Called when bet button is pressed
func _on_bet_button_pressed() -> void:
	$SFX/Bouton.play()
	display_chips()
	newRound()

#/* -------------------------------------------------------------------------- */
#/*                               Round Function                               */
#/* -------------------------------------------------------------------------- */

func endRound():
	$Buttons/VBoxContainer/Hit.disabled = true
	$Buttons/VBoxContainer/Stand.disabled = true
	for i in range(0, $Cards/Hands/PlayerHand.get_child_count()):
		$Cards/Hands/PlayerHand.get_child(i).queue_free()
	playerCards.clear()
	playerScore = 0
	for i in range(0, $Cards/Hands/DealerHand.get_child_count()):
		$Cards/Hands/DealerHand.get_child(i).queue_free()
	dealerCards.clear()
	dealerScore = 0
	$AllBet.visible = true
	$BetButton.disabled = true
	bet = 0
	display_chips()
	checkBet()
	if $AngerControl/PatienceLevel.value == 6:
		chooseAction()
		$AngerControl/PatienceLevel.value = 0
	$Goal.visible = true
	if (dollars >= goal):
		get_tree().change_scene_to_file("res://gameplay-scene/OutroWon/OutroWon.tscn")


func newRound():
	$Goal.visible = false
	$AllBet.visible = false
	$BetButton.disabled = true
	
	updateText()
	create_card_data()

	await get_tree().create_timer(0.5).timeout
	generate_card("player")
	updateText()
	await get_tree().create_timer(0.5).timeout
	generate_card("player")
	updateText()
	# Generate dealers cards; note how first one is true as we want to show the back
	await get_tree().create_timer(0.5).timeout
	generate_card("dealer", true)
	updateText()
	await get_tree().create_timer(0.5).timeout
	generate_card("dealer")
	updateText()
	
	if (doAction):
		await get_tree().create_timer(0.5).timeout
		call(action)
		doAction = false
		await get_tree().create_timer(0.5).timeout
		$DrunkControl/DrunkLevel.value /= 2
		$Sprite2D/AnimationPlayer2.play("blackout")
		$SFX/PanicMusic.stop()
		await get_tree().create_timer(1.6).timeout
		autoChangeAnimation = true;
		$SFX/RegularMusic.play()

	else:
		$Buttons/VBoxContainer/Hit.disabled = false
		$Buttons/VBoxContainer/Stand.disabled = false


func chooseBet():
	var value: int = $DrunkControl/DrunkLevel.value - 1
	var values = []
	
	for i in nb[value]:
		level[value].shuffle()
		values.push_back(level[value][0])
	for temp in values:
		await get_tree().create_timer(0.5).timeout
		_on_bet_dollars_pressed(temp)
	bet += 1 if bet == 0 else 0
	_on_bet_button_pressed()

#/* -------------------------------------------------------------------------- */
#/*                             BlackJack Functions                            */
#/* -------------------------------------------------------------------------- */

func check_aces():
	# If player is over 21 and has any 11-aces, convert them to 1 so they stay under 21
	while playerScore > 21:
		ace_found = false
		for card_index in range(len(playerCards)):
			if playerCards[card_index][0] == 11:  # Ace with value 11
				playerCards[card_index][0] = 1  # Convert ace to 1
				ace_found = true
				break
		if not ace_found:
			break  # No more aces to convert, exit loop
		recalculate_player_score()
		updateText()

func recalculate_player_score():
	playerScore = 0
	for card in playerCards:
		playerScore += card[0]

func create_card_data():
	# Generate card names for ranks 2 to 10
	for rank in range(2, 11):
		for suit in ["clubs", "diamonds", "hearts", "spades"]:
			card_names.append(str(rank) + "_" + suit)
			card_values.append(rank)
	# Generate card names for face cards (jack, queen, king, ace)
	for face_card in ["jack", "queen", "king", "ace"]:
		for suit in ["clubs", "diamonds", "hearts", "spades"]:
			card_names.append(face_card + "_" + suit)
			if face_card != "ace":
				card_values.append(10)
			else:
				card_values.append(11)	
	# Load card values and image paths into the dictionary
	for card in range(len(card_names)):
		card_images[card_names[card]] = [card_values[card], 
			"res://assets/images/cards_pixel/" + card_names[card] + ".png"]
		
	#add the the of card image with key "back"
	card_images["back"] = [0, "res://assets/images/cards_alternatives/card_back_pix.png"]
	
	cardsShuffled = card_names.duplicate()
	cardsShuffled.shuffle()

func generate_card(hand, back=false):
	# Assuming you have already loaded card images into the dictionary as shown in your code
	var random_card

	$SFX/Card.play()
	# If back is true assign card image to back
	if back:
		# We display the back of the card, but a real card needs to be pulled
		# so that it can be shown when the player Stands
		random_card = card_images["back"]
		dealerCards.append(card_images[cardsShuffled.pop_back()])
	else:
		# Get a random card
		var random_card_name = cardsShuffled.pop_back()
		random_card = card_images[random_card_name] 
		# random_card is an array [card value, card image path]

	# Create a new TextureRect node for card
	var card_texture = ResourceLoader.load(random_card[1])
	var card_texture_rect = TextureRect.new()
	card_texture_rect.texture = card_texture
	
	# Get a reference to the existing HBoxContainer
	var card_hand_container
	if hand == "player":
		card_hand_container = $Cards/Hands/PlayerHand
		if random_card[0] == 11 and playerScore > 10:  # Aces are 1 if score is too high for 11
			playerScore += 1
		else:
			playerScore += random_card[0]
		playerCards.append(random_card)
	elif hand == "dealer":
		card_hand_container = $Cards/Hands/DealerHand
		if random_card[0] == 11 and dealerScore > 10:  # Aces are 1 if score is too high for 11
			dealerScore += 1
		else:
			dealerScore += random_card[0]
		dealerCards.append(random_card)
	else:
		return
		
	# Add the card as a child to the HBoxContainer
	card_hand_container.add_child(card_texture_rect)

func playerLose(blackjack=false):
	$Buttons/VBoxContainer/Hit.disabled = true
	$Buttons/VBoxContainer/Stand.disabled = true
	if blackjack:
		$Popup/DealerBlackJack.visible = true
		$AnimationPlayer.play("BlackJackAnimationD")
		$AngerControl/PatienceLevel.value += 1
	$AngerControl/PatienceLevel.value += 1
	$SFX/Lose.play()
	autoChangeAnimation = false;
	$Sprite2D/AnimationPlayer2.play("angry")
	await get_tree().create_timer(1.6).timeout
	autoChangeAnimation = true;
	#$Sprite2D/AnimationPlayer2.play("sober") # Jouer la meilleure animation
	if (dollars <= 0):
		get_tree().change_scene_to_file("res://gameplay-scene/OutroLost/OutroLost.tscn")
	endRound()

func playerWin(blackjack=false):
	$SFX/Win.play()
	dollars += (bet * 2)
	# Player has won: display text (already set if not blackjack),
	# display buttons and ask to play again
	if playerScore == 21:
		$Popup/PlayerBlackJack.visible = true
		$AnimationPlayer.play("BlackJackAnimationP")
		$DrunkControl/DrunkLevel.value += 1
	$DrunkControl/DrunkLevel.value += 1
	endRound()

func playerDraw():
	dollars += bet
	# Nobody wins: display white text, disable buttons and ask to play again
	endRound()

func playerHasAce(cards):
	for card in cards:
		if card[0] == 11:
			return true
	return false

#/* -------------------------------------------------------------------------- */
#/*                               Player Actions                               */
#/* -------------------------------------------------------------------------- */

func chooseAction():
	$AllBet/one_dollars.disabled = true
	$AllBet/ten_dollars.disabled = true
	$AllBet/fifty_dollars.disabled = true
	$Buttons/VBoxContainer/Hit.disabled = true
	$Buttons/VBoxContainer/Stand.disabled = true
	# choose action with drunk level
	autoChangeAnimation = false
	$SFX/RegularMusic.stop()
	$SFX/PanicMusic.play()
	$Sprite2D/AnimationPlayer2.play("angry")
	var curlevel: int = ceil($DrunkControl/DrunkLevel.value / 2) - 1
	doAction = true
	action = actionTab[curlevel][1]
	await call(actionTab[curlevel][0])
	$AngerControl/PatienceLevel.value = 0

func randomMove():
	var rng = RandomNumberGenerator.new()
	var my_random_number = (rng.randi_range(0, 1))
	if my_random_number == 0:
		_on_hit_pressed()
	if my_random_number == 1:
		_on_stand_pressed()

func optimalMove():
	# AI logic to determine optimal move
	
	if len(dealerCards) < 2:  # Player clicked button before dealer cards loaded
		return
	var dealerUpCard = dealerCards[2][0]
	var hasAce = playerHasAce(playerCards)
	
	if hasAce:
		# Handle cases when player has an ace
		if playerScore >= 19:
			_on_stand_pressed()
		elif playerScore == 18 and dealerUpCard <= 8:
			_on_stand_pressed()
		elif playerScore == 18 and dealerUpCard >= 9:
			_on_hit_pressed()
		else:
			_on_hit_pressed()
	else:
		# Handle cases when player does not have an ace
		if playerScore >= 17 and playerScore <= 20:
			_on_stand_pressed()
		elif playerScore >= 13 and playerScore <= 16:
			if dealerUpCard >= 2 and dealerUpCard <= 6:
				_on_stand_pressed()
			else:
				_on_hit_pressed()
		elif playerScore == 12:
			if dealerUpCard >= 4 and dealerUpCard <= 6:
				_on_stand_pressed()
			else:
				_on_hit_pressed()
		elif playerScore >= 4 and playerScore <= 11:
			_on_hit_pressed()
		else:
			_on_stand_pressed()

func NotoptimalMove():
	# AI logic to determine optimal move
	
	if len(dealerCards) < 2:  # Player clicked button before dealer cards loaded
		return
	var dealerUpCard = dealerCards[2][0]
	var hasAce = playerHasAce(playerCards)
	
	if hasAce:
		# Handle cases when player has an ace
		if playerScore >= 19:
			_on_hit_pressed()
		elif playerScore == 18 and dealerUpCard <= 8:
			_on_hit_pressed()
		elif playerScore == 18 and dealerUpCard >= 9:
			_on_stand_pressed()
		else:
			_on_stand_pressed()
	else:
		# Handle cases when player does not have an ace
		if playerScore >= 17 and playerScore <= 20:
			_on_hit_pressed()
		elif playerScore >= 13 and playerScore <= 16:
			if dealerUpCard >= 2 and dealerUpCard <= 6:
				_on_hit_pressed()
			else:
				_on_stand_pressed()
		elif playerScore == 12:
			if dealerUpCard >= 4 and dealerUpCard <= 6:
				_on_hit_pressed()
			else:
				_on_stand_pressed()
		elif playerScore >= 4 and playerScore <= 11:
			_on_stand_pressed()
		else:
			_on_hit_pressed()

#/* -------------------------------------------------------------------------- */
#/*                               Chips Function                               */
#/* -------------------------------------------------------------------------- */

func clear_chips():
	for a in $Chips/Chips1stack.get_children():
		a.queue_free()
	for a in $Chips/Chips10stack.get_children():
		a.queue_free()
	for a in $Chips/Chips100stack.get_children():
		a.queue_free()
	for a in $Chips/Chips1stackBet.get_children():
		a.queue_free()
	for a in $Chips/Chips10stackBet.get_children():
		a.queue_free()
	for a in $Chips/Chips100stackBet.get_children():
		a.queue_free()

func display_chips():
	var amount = dollars if dollars < 1000 else 999
	var betAmount = bet if bet < 1000 else 999
	var chip_one = "res://assets/images/chips/chips1.png"
	var chip_ten = "res://assets/images/chips/chips10.png"
	var chip_hundred = "res://assets/images/chips/chips100.png"
	clear_chips()
	amount = load_chipsize(amount, $Chips/Chips100stack, 100, chip_hundred)
	amount = load_chipsize(amount, $Chips/Chips10stack, 10, chip_ten)
	amount = load_chipsize(amount, $Chips/Chips1stack, 1, chip_one)

	betAmount = load_chipsize(betAmount, $Chips/Chips100stackBet, 100, chip_hundred)
	betAmount = load_chipsize(betAmount, $Chips/Chips10stackBet, 10, chip_ten)
	betAmount = load_chipsize(betAmount, $Chips/Chips1stackBet, 1, chip_one)
	if (Global.diff == Global.DIFFICULTY.ENDLESS):
		$Goal.text = "I\nCAN'T\nSTOP !!!"
	else:
		$Goal.text = "I still need\n" + str(goal - dollars) + "$\nto buy it !"
		

func add_chip(chip: String, stack: VBoxContainer):
	var image = TextureRect.new()
	image.texture = load(chip)
	image.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
	stack.add_child(image)

func load_chipsize(amount: int, chipstack: VBoxContainer, value: int, sprite: String):
	while (amount >= value):
		amount -= value
		add_chip(sprite, chipstack)
	return amount

#/* -------------------------------------------------------------------------- */
#/*                               Misc Functions                               */
#/* -------------------------------------------------------------------------- */

func checkBet():
	if (dollars < 1):
		$AllBet/one_dollars.disabled = true
	else:
		$AllBet/one_dollars.disabled = false
	if (dollars < 10):
		$AllBet/ten_dollars.disabled = true
	else:
		$AllBet/ten_dollars.disabled = false
	if (dollars < 50):
		$AllBet/fifty_dollars.disabled = true
	else:
		$AllBet/fifty_dollars.disabled = false

func handleAnimation(anim: String):
	if ($Sprite2D/AnimationPlayer2.current_animation != anim):
		$Sprite2D/AnimationPlayer2.play(anim)

func updateText():
	# Update the labels displayed on screen for the dealer and player scores.
	$DealerScore.text = str(dealerScore)
	$PlayerScore.text = str(playerScore)
