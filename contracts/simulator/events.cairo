%lang starknet

from contracts.simulator.mechs import MechState
from contracts.simulator.atoms import AtomState
from contracts.simulator.grid import Grid

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
    operators_inputs_len: felt,
    operators_inputs: Grid*,
    operators_outputs_len: felt,
    operators_outputs: Grid*,
    operators_type_len: felt,
    operators_type: felt*,
    static_cost: felt,
) {
}

@event
func end_summary(latency: felt, dynamic_cost: felt) {
}
