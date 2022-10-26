%lang starknet

from contracts.mechs import MechState
from contracts.atoms import AtomState

//
// Standard for events generation of Frame
//

@event
func new_simulation(
    solver: felt,
    mechs_len: felt,
    mechs: MechState*,
    atoms_len: felt,
    atoms: AtomState*,
    instructions_sets_len: felt,
    instructions_sets: felt*,
    instructions_len: felt,
    instructions: felt*,
    cost_accumulated: felt,
) {
}

@event
func frame(
    mechs_len: felt, mechs: MechState*, atoms_len: felt, atoms: AtomState*, cost_accumulated: felt
) {
}
