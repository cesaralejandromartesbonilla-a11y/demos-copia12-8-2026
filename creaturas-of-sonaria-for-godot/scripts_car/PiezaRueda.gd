extends PiezaTransmision
class_name PiezaRueda

## Igual que Engranaje: hereda todo de PiezaTransmision. 'radio' no se usa
## todavía en el MVP (no hay conversión a velocidad lineal real, la rueda
## solo gira) — queda preparado para cuando el larguero tenga que moverse
## de verdad contra el piso.

@export var radio: float = 0.35
