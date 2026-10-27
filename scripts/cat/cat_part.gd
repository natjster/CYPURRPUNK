class_name CatPart
extends Resource
## CYPURRPUNK — ONE ACCESSORY CARD for the character creator (a hat, shades, a collar...).
## Every .tres file of this type in res://cat_parts/ shows up in the MY CAT screen by itself.
##
## To make a new accessory (SETUP_GUIDE §11 has the click-by-click version):
##   1. Make a small scene with its meshes (e.g. duplicate scenes/cat_parts/beanie.tscn).
##      Build it around (0, 0, 0) = the slot's anchor point on the cat (see below).
##   2. Duplicate a card in res://cat_parts/ (e.g. beanie.tres), give it a new Id and Name,
##      pick its Slot and drag your scene into Scene.
##
## Slots and where their (0, 0, 0) sits on the cat (CatLook.SLOT_ANCHORS):
##   hat   top of the head          face  in front of the eyes        neck  around the neck
## A cat wears at most one part per slot.

## Short unique name, no spaces (saved in the player's look, e.g. "fedora").
@export var id: String = ""
## Shown in the MY CAT screen.
@export var display_name: String = "THING"
## Which slot it goes in: hat, face or neck (CatLook.SLOTS).
@export_enum("hat", "face", "neck") var slot: String = "hat"
## The accessory's meshes.
@export var scene: PackedScene

@export_group("Fit")
## Nudge it from the slot's anchor point (metres; -Z = towards the cat's nose).
@export var offset: Vector3 = Vector3.ZERO
## Tilt it (degrees).
@export var rotation_degrees: Vector3 = Vector3.ZERO
@export var scale: float = 1.0
