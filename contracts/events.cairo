%lang starknet

//
// Standard for events generation of Frame
//

@event
func Check(value: felt) {
}

@event
func CheckArr(value_len: felt, value: felt*) {
}
