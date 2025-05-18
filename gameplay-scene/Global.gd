extends Node

enum DIFFICULTY {
	EASY,
	NORMAL,
	HARD,
	ENDLESS,
	DEBUG
}

var censor: bool = false
var diff: DIFFICULTY = DIFFICULTY.EASY
var startCash = 10
