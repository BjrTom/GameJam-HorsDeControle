extends Control

var card_names = []
var card_values = []
var card_images = {}

var playerScore = 0
var dealerScore = 0
var playerCards = []
var dealerCards = []

var cardsShuffled = {}

var ace_found
var dollars = 10
var bet = 0

func endRound():
	$DollarsInt.text = (str(dollars) + '$')
	$Buttons/VBoxContainer/Hit.disabled = true
	$Buttons/VBoxContainer/Stand.disabled = true
	$Buttons/VBoxContainer/OptimalMove.disabled = true
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
	checkBet()

func newRound():
	
	$AllBet.visible = false
	$BetButton.disabled = false
	
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
	
	$Buttons/VBoxContainer/Hit.disabled = false
	$Buttons/VBoxContainer/Stand.disabled = false
	$Buttons/VBoxContainer/OptimalMove.disabled = false

	if playerScore == 21:
		playerWin(true)

# Called when the node enters the scene tree for the first time.
func _ready():
	$Replay.visible = false
	$WinnerText.visible = false
	$PlayerHitMarker.visible = false
	$DealerHitMarker.visible = false
	$PlayerBustMarker.visible = false
	
	$Buttons/VBoxContainer/Hit.disabled = true
	$Buttons/VBoxContainer/Stand.disabled = true
	$Buttons/VBoxContainer/OptimalMove.disabled = true

	get_tree().root.content_scale_factor
	checkBet()
	$DollarsInt.text = (str(dollars) + '$')
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$ProgressBar.value += 0.25
	
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
			$PlayerHitMarker.visible = false
			playerLose()


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
		playerLose()
	else:  # Tie
		playerDraw()
	
	
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


func updateText():
	# Update the labels displayed on screen for the dealer and player scores.
	$DealerScore.text = str(dealerScore)
	$PlayerScore.text = str(playerScore)


func playerLose():
	if (dollars == 0):
		get_tree().change_scene_to_file("res://Menu/scenes/menus/main_menu/main_menu.tscn")
	endRound()
	# newRound()
	
	
func playerWin(blackjack=false):
	dollars += (bet * 2)
	# Player has won: display text (already set if not blackjack),
	# display buttons and ask to play again
	if blackjack:
		$WinnerText.text = "BLACKJACK"
	endRound()
	# newRound()
	
	
func playerDraw():
	dollars += bet
	# Nobody wins: display white text, disable buttons and ask to play again
	endRound()



func _on_exit_pressed():
	get_tree().change_scene_to_file("res://Menu/scenes/menus/main_menu/main_menu.tscn")


func _on_replay_pressed():
	get_tree().change_scene_to_file("res://gameplay-scene/game.tscn")


func _on_button_pressed():
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

func playerHasAce(cards):
	for card in cards:
		if card[0] == 11:
			return true
	return false

func checkBet():
	
	#$AllBet/one_dollars.disabled = true if ((dollars - bet) < 1) else false
	#$AllBet/ten_dollars.disabled = true if ((dollars - bet) < 10) else false
	#$AllBet/fifty_dollars_dollars.disabled = true if ((dollars - bet) < 50) else false
	if ((dollars - bet) < 1):
		$AllBet/one_dollars.disabled = true
	else:
		$AllBet/one_dollars.disabled = false
	if ((dollars - bet) < 10):
		$AllBet/ten_dollars.disabled = true
	else:
		$AllBet/ten_dollars.disabled = false
	if ((dollars - bet) < 50):
		$AllBet/fifty_dollars.disabled = true
	else:
		$AllBet/fifty_dollars.disabled = false

func _on_bet_dollars_pressed(new_bet: int) -> void:
	if (dollars < bet):
		return
	bet += new_bet
	checkBet()
	$DollarsInt.text = (str(dollars) + '$' + " | Bet -> " + str(bet))

func _on_bet_button_pressed() -> void:
	dollars -= bet
	$DollarsInt.text = str(dollars) + '$'
	newRound()
