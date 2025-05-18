extends Control

#/* -------------------------------------------------------------------------- */
#/*                                 Variables                                  */
#/* -------------------------------------------------------------------------- */

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
	$PlayerHitMarker.visible = false
	$DealerHitMarker.visible = false
	$PlayerBustMarker.visible = false
	
	$Buttons/VBoxContainer/Hit.disabled = true
	$Buttons/VBoxContainer/Stand.disabled = true
	
	fillArray()
	get_tree().root.content_scale_factor
	checkBet()
	display_chips()
	$DollarsInt.text = (str(dollars) + '$')

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if ($DrunkLevel.value >= 0 and $DrunkLevel.value < 250):
		handleAnimation("sober")
	if ($DrunkLevel.value >= 250 and $DrunkLevel.value < 500):
		handleAnimation("tipsy")
	if ($DrunkLevel.value >= 500 and $DrunkLevel.value < 750):
		handleAnimation("hiccup")
	if ($DrunkLevel.value >= 750):
		handleAnimation("drunk")
	#$DrunkLevel.value += 0.25

#/* -------------------------------------------------------------------------- */
#/*                              Buttons Function                              */
#/* -------------------------------------------------------------------------- */

# Called when hit button is pressed
func _on_hit_pressed():
	$PlayerHitMarker.visible = true
	generate_card("player")
	# Play "hit!" animation
	$AnimationPlayer.play("HitAnimationP")
	updateText()
	if playerScore == 21:
		_on_stand_pressed()  # Player auto-stands on 21
	elif playerScore > 21:
		check_aces()  # Check to see if any 11-aces can convert to 1-aces
		if playerScore > 21:  # Score still surpasses 21
			$PlayerBustMarker.visible = true
			$AnimationPlayer.play("BustAnimation")
			#$PlayerHitMarker.visible = false
			playerLose()
			return
	$Buttons/VBoxContainer/Hit.disabled = false
	$Buttons/VBoxContainer/Stand.disabled = false

# Called when stand button is pressed
func _on_stand_pressed():
	# Flip dealer's first card, dealer keeps hitting until score is above 16 or player's score
	$Buttons/VBoxContainer/Hit.disabled = true
	$Buttons/VBoxContainer/Stand.disabled = true
	$Buttons/VBoxContainer/OptimalMove.disabled = true
	$DealerHitMarker.visible = true
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
	get_tree().change_scene_to_file("res://Menu/scenes/menus/main_menu/main_menu.tscn")

# Called when dollars button is pressed
func _on_bet_dollars_pressed(new_bet: int) -> void:
	if (new_bet == 0 or dollars <= 0 or dollars < new_bet):
		return
	bet += new_bet
	dollars -= new_bet
	checkBet()
	display_chips()
	$DollarsInt.text = (str(dollars) + '$')

# Called when bet button is pressed
func _on_bet_button_pressed() -> void:
	$DollarsInt.text = str(dollars) + '$'
	display_chips()
	newRound()

#/* -------------------------------------------------------------------------- */
#/*                               Round Function                               */
#/* -------------------------------------------------------------------------- */

func endRound():
	$DollarsInt.text = (str(dollars) + '$')
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
	$BetButton.disabled = false
	bet = 0
	display_chips()
	checkBet()
	if $PatienceLevel.value == 6:
		chooseAction()
		$PatienceLevel.value = 0

func newRound():
	
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
	else:
		$Buttons/VBoxContainer/Hit.disabled = false
		$Buttons/VBoxContainer/Stand.disabled = false

	if playerScore == 21:
		playerWin(true)

func chooseBet():
	var value: int = $DrunkLevel.value - 1
	$Debug.text = str(value)
	var dollar_value = [1, 10, 100]
	var values = []
	
	for i in nb[value]:
		level[value].shuffle()
		print(level)
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
	if blackjack:
		$DealerBlackJack.visible = true
		$AnimationPlayer.play("BlackJackAnimationD")
		$PatienceLevel.value += 1
	$PatienceLevel.value += 1
	if (dollars == 0):
		get_tree().change_scene_to_file("res://Menu/scenes/menus/main_menu/main_menu.tscn")
	endRound()

func playerWin(blackjack=false):
	dollars += (bet * 2)
	# Player has won: display text (already set if not blackjack),
	# display buttons and ask to play again
	if blackjack:
		$PlayerBlackJack.visible = true
		$AnimationPlayer.play("BlackJackAnimationP")
		$DrunkLevel.value += 1
	$DrunkLevel.value += 1
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
	var level: int = ceil($DrunkLevel.value / 2) - 1
	doAction = true
	$Debug.text = actionTab[level][1]
	action = actionTab[level][1]
	await call(actionTab[level][0])
	$PatienceLevel.value = 0

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
	var chip_one = "res://assets/images/chips1.png"
	var chip_ten = "res://assets/images/chips10.png"
	var chip_hundred = "res://assets/images/chips100.png"
	clear_chips()
	amount = load_chipsize(amount, $Chips/Chips100stack, 100, chip_hundred)
	amount = load_chipsize(amount, $Chips/Chips10stack, 10, chip_ten)
	amount = load_chipsize(amount, $Chips/Chips1stack, 1, chip_one)

	betAmount = load_chipsize(betAmount, $Chips/Chips100stackBet, 100, chip_hundred)
	betAmount = load_chipsize(betAmount, $Chips/Chips10stackBet, 10, chip_ten)
	betAmount = load_chipsize(betAmount, $Chips/Chips1stackBet, 1, chip_one)

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
