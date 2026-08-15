extends Node
class_name LogicReceiverComponent

@export var processor: ProcessorComponent

var is_logic_transmitter: bool = false
var logic_receiver_component = self
var my_logic_grid
var connected_logic_nodes: Array = []
